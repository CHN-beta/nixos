//! `/api/terminal` — native PTY lifecycle and SSE output stream.

use crate::routes::{body_json, query};
use crate::state::SharedState;
use crate::util::coded_error;
use axum::extract::{Path as AxumPath, State};
use axum::http::{StatusCode, Uri};
use axum::response::Response;
use serde_json::{json, Value};

fn not_found() -> Response {
    coded_error(
        StatusCode::NOT_FOUND,
        "Terminal session not found",
        "not_found",
    )
}

pub async fn terminal_list(State(state): State<SharedState>) -> Response {
    crate::routes::json_ok(json!({ "terminals": state.terminals.list() }))
}

pub async fn terminal_create(
    State(state): State<SharedState>,
    request: axum::extract::Request,
) -> Response {
    let body = body_json(request, 256 * 1024).await.unwrap_or(Value::Null);
    let target_cwd = body
        .get("cwd")
        .and_then(Value::as_str)
        .map(|s| s.to_string());
    if let Some(cwd) = &target_cwd {
        if !state.is_path_allowed(std::path::Path::new(cwd)) {
            return coded_error(
                StatusCode::FORBIDDEN,
                "Working directory access denied",
                "access_denied",
            );
        }
    }
    let cols = body
        .get("cols")
        .and_then(Value::as_u64)
        .unwrap_or(80)
        .clamp(1, 1000) as u16;
    let rows = body
        .get("rows")
        .and_then(Value::as_u64)
        .unwrap_or(24)
        .clamp(1, 1000) as u16;
    let shell = body.get("shell").and_then(Value::as_str);
    match state
        .terminals
        .create(target_cwd.as_deref(), cols, rows, shell)
    {
        Ok(session) => crate::routes::json_ok(json!({ "terminal": session.info() })),
        Err(error) => crate::util::api_error(error, StatusCode::INTERNAL_SERVER_ERROR),
    }
}

pub async fn terminal_get(
    State(state): State<SharedState>,
    AxumPath(id): AxumPath<String>,
) -> Response {
    match state.terminals.get(&id) {
        Some(session) => crate::routes::json_ok(json!({ "terminal": session.info() })),
        None => not_found(),
    }
}

pub async fn terminal_delete(
    State(state): State<SharedState>,
    AxumPath(id): AxumPath<String>,
) -> Response {
    crate::routes::json_ok(json!({ "success": state.terminals.kill(&id) }))
}

pub async fn terminal_input(
    State(state): State<SharedState>,
    AxumPath(id): AxumPath<String>,
    request: axum::extract::Request,
) -> Response {
    let Some(session) = state.terminals.get(&id) else {
        return not_found();
    };
    let body = match body_json(request, 1024 * 1024).await {
        Ok(body) => body,
        Err(_) => {
            return coded_error(
                StatusCode::BAD_REQUEST,
                "Invalid JSON request body",
                "invalid_json",
            )
        }
    };
    let Some(data) = body.get("data").and_then(Value::as_str) else {
        return coded_error(
            StatusCode::BAD_REQUEST,
            "data must be a string",
            "invalid_data",
        );
    };
    let data = data.to_string();
    // The fd is non-blocking but a full PTY buffer needs poll(); keep that
    // wait off the Tokio worker threads.
    let success = tokio::task::spawn_blocking(move || session.write_input(&data))
        .await
        .unwrap_or(false);
    crate::routes::json_ok(json!({ "success": success }))
}

pub async fn terminal_resize(
    State(state): State<SharedState>,
    AxumPath(id): AxumPath<String>,
    request: axum::extract::Request,
) -> Response {
    let Some(session) = state.terminals.get(&id) else {
        return not_found();
    };
    let body = body_json(request, 256 * 1024).await.unwrap_or(Value::Null);
    let cols = body
        .get("cols")
        .and_then(Value::as_u64)
        .map(|value| value as u16)
        .unwrap_or_else(|| session.info().cols);
    let rows = body
        .get("rows")
        .and_then(Value::as_u64)
        .map(|value| value as u16)
        .unwrap_or_else(|| session.info().rows);
    let resized = session.resize(cols, rows);
    crate::routes::json_ok(json!({ "success": resized, "cols": cols, "rows": rows }))
}

pub async fn terminal_stream(
    State(state): State<SharedState>,
    AxumPath(id): AxumPath<String>,
    uri: Uri,
) -> Response {
    let Some(session) = state.terminals.get(&id) else {
        return not_found();
    };
    let query = query(&uri);
    let skip_history =
        query.get("skip_history") == Some("1") || query.get("skipHistory") == Some("1");
    let since = query.get("offset").and_then(|value| value.parse::<u64>().ok());
    // History and the live subscription are captured atomically, so a chunk
    // can never be replayed from the buffer *and* delivered as a live event.
    let snapshot = session.snapshot();
    let mut events = snapshot.events;
    let (history, history_start) = if skip_history {
        (String::new(), snapshot.end_offset)
    } else {
        match since {
            // Already caught up: nothing to replay.
            Some(offset) if offset >= snapshot.end_offset => (String::new(), snapshot.end_offset),
            // Caller's offset predates the ring buffer: replay everything.
            Some(offset) if offset > snapshot.start_offset => {
                let skip = (offset - snapshot.start_offset) as usize;
                match snapshot.history.get(skip..) {
                    Some(rest) => (rest.to_string(), offset),
                    None => (snapshot.history.clone(), snapshot.start_offset),
                }
            }
            _ => (snapshot.history.clone(), snapshot.start_offset),
        }
    };
    let (sse, response) = crate::sse::channel(256);
    if !history.is_empty() {
        sse.data(&json!({
            "type": "output",
            "data": history,
            "startOffset": history_start,
            "offset": snapshot.end_offset,
        }))
        .await;
    }
    if session.is_exited() {
        sse.data(&json!({ "type": "exit", "code": session.exit_code() }))
            .await;
        return response;
    }
    tokio::spawn(async move {
        let mut heartbeat = tokio::time::interval_at(
            tokio::time::Instant::now() + std::time::Duration::from_secs(15),
            std::time::Duration::from_secs(15),
        );
        heartbeat.set_missed_tick_behavior(tokio::time::MissedTickBehavior::Delay);
        loop {
            tokio::select! {
                event = events.recv() => {
                    match event {
                        Ok(crate::omp::terminal::TerminalEvent::Output { data, start, end }) => {
                            if !sse
                                .data(&json!({
                                    "type": "output",
                                    "data": data,
                                    "startOffset": start,
                                    "offset": end,
                                }))
                                .await
                            {
                                break;
                            }
                        }
                        Ok(crate::omp::terminal::TerminalEvent::Exit(code)) => {
                            sse.data(&json!({ "type": "exit", "code": code })).await;
                            break;
                        }
                        Err(tokio::sync::broadcast::error::RecvError::Lagged(_)) => continue,
                        Err(_) => break,
                    }
                }
                _ = heartbeat.tick() => {
                    if !sse.ping().await { break; }
                }
            }
        }
    });
    response
}

#[allow(dead_code)]
fn _unused(_: Uri) -> String {
    query(&Uri::from_static("/"))
        .get("x")
        .unwrap_or("")
        .to_string()
}
