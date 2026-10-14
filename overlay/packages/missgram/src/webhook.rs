use crate::misskey::{Content, Job};
use axum::{
    Router,
    body::Bytes,
    extract::State,
    http::{HeaderMap, StatusCode},
    routing::post,
};
use tokio::sync::mpsc;
use tracing::warn;

#[derive(Clone)]
struct StateData {
    secret: std::sync::Arc<str>,
    sender: mpsc::Sender<Job>,
}

pub fn router(secret: String, sender: mpsc::Sender<Job>) -> Router {
    Router::new()
        .route("/", post(handle))
        .with_state(StateData {
            secret: secret.into(),
            sender,
        })
}

async fn handle(
    State(state): State<StateData>,
    headers: HeaderMap,
    body: Bytes,
) -> Result<&'static str, StatusCode> {
    if headers
        .get("x-misskey-hook-secret")
        .and_then(|value| value.to_str().ok())
        != Some(state.secret.as_ref())
    {
        return Err(StatusCode::UNAUTHORIZED);
    }
    let content: Content = serde_json::from_slice(&body).map_err(|_| StatusCode::BAD_REQUEST)?;
    let Some(job) = content.into_job().map_err(|error| {
        warn!(%error, "Invalid Misskey event");
        StatusCode::BAD_REQUEST
    })?
    else {
        return Ok("OK");
    };
    state.sender.try_send(job).map_err(|error| match error {
        mpsc::error::TrySendError::Full(_) => StatusCode::SERVICE_UNAVAILABLE,
        mpsc::error::TrySendError::Closed(_) => StatusCode::SERVICE_UNAVAILABLE,
    })?;
    Ok("OK")
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[tokio::test]
    async fn webhook_authentication_filtering_and_backpressure() {
        let (sender, mut receiver) = mpsc::channel(1);
        let listener = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
        let url = format!("http://{}", listener.local_addr().unwrap());
        let task = tokio::spawn(async move {
            axum::serve(listener, router("secret".into(), sender))
                .await
                .unwrap();
        });
        let client = reqwest::Client::new();
        assert_eq!(
            client.post(&url).body("{}").send().await.unwrap().status(),
            401
        );
        assert_eq!(
            client
                .post(&url)
                .header("x-misskey-hook-secret", "secret")
                .body("not json")
                .send()
                .await
                .unwrap()
                .status(),
            400
        );
        let payload = json!({"type":"note", "server":"https://example.org", "body":{"note":{"id":"n", "text":"hello", "visibility":"public"}}});
        let send = |payload| {
            client
                .post(&url)
                .header("x-misskey-hook-secret", "secret")
                .json(&payload)
                .send()
        };
        let mut ignored = payload.clone();
        ignored["body"]["note"]["localOnly"] = json!(true);
        assert_eq!(send(ignored).await.unwrap().status(), 200);
        assert!(receiver.try_recv().is_err());
        assert_eq!(send(payload.clone()).await.unwrap().status(), 200);
        assert_eq!(send(payload).await.unwrap().status(), 503);
        assert_eq!(receiver.recv().await.unwrap().note.id, "n");
        task.abort();
        let _ = task.await;
    }
}
