//! Manual Server-Sent Events plumbing.
//!
//! Frames are written verbatim (axum's `Sse` type inserts its own spacing), so
//! the wire format matches the Next.js implementation exactly:
//! `event: <name>\ndata: <json>\n\n` and `: \n\n` style heartbeats.

use axum::body::Body;
use axum::response::Response;
use bytes::Bytes;
use serde_json::Value;
use std::time::Duration;
use tokio::sync::mpsc;
use tokio_stream::wrappers::ReceiverStream;

/// How long a frame may wait for room in the channel before the stream is
/// considered stalled (a full channel is backpressure, not a disconnect).
const SEND_TIMEOUT: Duration = Duration::from_secs(15);

#[derive(Clone)]
pub struct SseSender {
    tx: mpsc::Sender<Result<Bytes, std::io::Error>>,
}

impl SseSender {
    /// Send one JSON payload as a default (unnamed) SSE event.
    pub async fn data(&self, value: &Value) -> bool {
        let payload = format!("data: {}\n\n", value);
        self.raw(payload).await
    }

    /// Send a named event with a JSON payload.
    pub async fn event(&self, event: &str, value: &Value) -> bool {
        let payload = format!("event: {}\ndata: {}\n\n", event, value);
        self.raw(payload).await
    }

    /// Enqueue one frame. A full channel means the client is behind: wait for
    /// room (bounded) instead of treating it as a disconnect, because a fast
    /// token burst must never truncate a live turn. Only a closed receiver or
    /// a genuinely stalled consumer ends the stream.
    pub async fn raw(&self, payload: impl Into<String>) -> bool {
        let item: Result<Bytes, std::io::Error> = Ok(Bytes::from(payload.into()));
        match self.tx.try_send(item) {
            Ok(()) => true,
            Err(mpsc::error::TrySendError::Closed(_)) => false,
            Err(mpsc::error::TrySendError::Full(item)) => {
                matches!(
                    tokio::time::timeout(SEND_TIMEOUT, self.tx.send(item)).await,
                    Ok(Ok(()))
                )
            }
        }
    }

    /// SSE comment frame used as a heartbeat.
    pub async fn heartbeat(&self) -> bool {
        self.raw(":\n\n").await
    }

    pub fn is_closed(&self) -> bool {
        self.tx.is_closed()
    }
}

pub fn channel(capacity: usize) -> (SseSender, Response) {
    let (tx, rx) = mpsc::channel::<Result<Bytes, std::io::Error>>(capacity);
    let stream = ReceiverStream::new(rx);
    let body = Body::from_stream(stream);
    let response = Response::builder()
        .header("Content-Type", "text/event-stream; charset=utf-8")
        .header("Cache-Control", "no-cache, no-transform")
        .header("Connection", "keep-alive")
        .body(body)
        .expect("valid SSE response");
    (SseSender { tx }, response)
}
