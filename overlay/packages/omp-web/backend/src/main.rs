use std::collections::{HashMap, VecDeque};
use std::net::{IpAddr, Ipv4Addr, SocketAddr};
use std::path::PathBuf;
use std::process::Stdio;
use std::sync::Arc;

use axum::extract::ws::{Message, WebSocket, WebSocketUpgrade};
use axum::extract::{Path as AxumPath, State};
use axum::http::StatusCode;
use axum::response::IntoResponse;
use axum::routing::{delete, get};
use axum::{Json, Router};
use futures::{SinkExt, StreamExt};
use serde::{Deserialize, Serialize};
use tokio::io::{AsyncBufReadExt, AsyncWriteExt, BufReader};
use tokio::process::Command;
use tokio::sync::{broadcast, mpsc, Mutex, RwLock};
use tracing::{error, info};

/// Number of ACP messages kept per session so a browser tab can reload (or a
/// second tab can attach) without losing the visible transcript.
const BUFFER_CAPACITY: usize = 512;

/// The SPA and the REST/websocket surface are published by nginx on the same
/// origin, so the backend only ever listens on loopback. nginx must proxy
/// `/api` to exactly this address.
const LISTEN_ADDR: SocketAddr = SocketAddr::new(IpAddr::V4(Ipv4Addr::LOCALHOST), 30141);

#[derive(Clone)]
struct AppState {
    sessions: Sessions,
}

type Sessions = Arc<RwLock<HashMap<String, Arc<Session>>>>;

struct Session {
    id: String,
    cwd: PathBuf,
    created_at: std::time::SystemTime,
    /// ACP requests from the browser to the `omp acp` child.
    stdin_tx: mpsc::Sender<String>,
    /// ACP messages from the child, fanned out to every attached websocket.
    event_tx: broadcast::Sender<String>,
    buffer: Arc<Mutex<VecDeque<String>>>,
    supervisor: tokio::task::AbortHandle,
}

#[derive(Serialize)]
struct SessionInfo {
    id: String,
    cwd: String,
    created_at_secs: u64,
}

#[derive(Deserialize)]
struct CreateSessionRequest {
    cwd: Option<String>,
}

#[derive(Serialize)]
struct CreateSessionResponse {
    id: String,
    cwd: String,
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "omp_web=info".into()),
        )
        .init();

    let state = AppState {
        sessions: Arc::new(RwLock::new(HashMap::new())),
    };

    // Only the REST/websocket surface lives here; the SPA is served by nginx.
    let app = Router::new()
        .route("/api/sessions", get(list_sessions).post(create_session))
        .route("/api/sessions/{id}", delete(delete_session))
        .route("/api/sessions/{id}/ws", get(ws_handler))
        .with_state(state);

    info!("omp-web backend listening on http://{}", LISTEN_ADDR);

    let listener = tokio::net::TcpListener::bind(LISTEN_ADDR).await?;
    axum::serve(listener, app).await?;

    Ok(())
}

async fn list_sessions(State(state): State<AppState>) -> Json<Vec<SessionInfo>> {
    let sessions = state.sessions.read().await;
    let mut list: Vec<SessionInfo> = sessions
        .values()
        .map(|s| SessionInfo {
            id: s.id.clone(),
            cwd: s.cwd.to_string_lossy().to_string(),
            created_at_secs: s
                .created_at
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap_or_default()
                .as_secs(),
        })
        .collect();
    list.sort_by(|a, b| b.created_at_secs.cmp(&a.created_at_secs));
    Json(list)
}

async fn create_session(
    State(state): State<AppState>,
    Json(payload): Json<CreateSessionRequest>,
) -> Result<Json<CreateSessionResponse>, (StatusCode, String)> {
    let raw_cwd = payload
        .cwd
        .unwrap_or_else(|| std::env::var("HOME").unwrap_or_else(|_| "/".to_string()));

    let canonical_cwd = PathBuf::from(&raw_cwd).canonicalize().map_err(|e| {
        (
            StatusCode::BAD_REQUEST,
            format!("Invalid working directory '{}': {}", raw_cwd, e),
        )
    })?;

    if !canonical_cwd.is_dir() {
        return Err((
            StatusCode::BAD_REQUEST,
            format!("Path '{}' is not a directory", canonical_cwd.display()),
        ));
    }

    let session_id = uuid::Uuid::new_v4().to_string();
    info!(
        "Spawning omp acp session {} with CWD: {}",
        session_id,
        canonical_cwd.display()
    );

    let mut child = Command::new("omp")
        .arg("acp")
        .current_dir(&canonical_cwd)
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::inherit())
        .kill_on_drop(true)
        .spawn()
        .map_err(|e| {
            error!("Failed to spawn omp acp: {}", e);
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                format!("Failed to execute 'omp acp': {}", e),
            )
        })?;

    let child_stdin = child.stdin.take().ok_or_else(|| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            "Failed to open child stdin".to_string(),
        )
    })?;
    let child_stdout = child.stdout.take().ok_or_else(|| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            "Failed to open child stdout".to_string(),
        )
    })?;

    let (stdin_tx, mut stdin_rx) = mpsc::channel::<String>(128);
    let (event_tx, _) = broadcast::channel::<String>(BUFFER_CAPACITY);
    let buffer = Arc::new(Mutex::new(VecDeque::with_capacity(BUFFER_CAPACITY)));

    let sessions = state.sessions.clone();
    let supervisor_id = session_id.clone();
    let supervisor_cwd = canonical_cwd.to_string_lossy().to_string();
    let buffer_handle = buffer.clone();
    let event_tx_handle = event_tx.clone();
    let stdin_tx_handle = stdin_tx.clone();

    let supervisor = tokio::spawn(async move {
        let mut reader = BufReader::new(child_stdout).lines();

        // Pump browser-originated ACP requests into the child's stdin. Ends once
        // every sender is gone, so the child sees EOF.
        let writer_id = supervisor_id.clone();
        let write_task = tokio::spawn(async move {
            let mut writer = child_stdin;
            while let Some(msg) = stdin_rx.recv().await {
                let trimmed = msg.trim();
                if trimmed.is_empty() {
                    continue;
                }
                if let Err(e) = writer.write_all(format!("{}\n", trimmed).as_bytes()).await {
                    error!("[{}] Error writing to omp stdin: {}", writer_id, e);
                    break;
                }
                if let Err(e) = writer.flush().await {
                    error!("[{}] Error flushing omp stdin: {}", writer_id, e);
                    break;
                }
            }
        });

        // The child speaks ACP only after `initialize` + `session/new`; the
        // session is bound to the working directory the browser asked for.
        for request in [
            serde_json::json!({
                "jsonrpc": "2.0",
                "id": 1,
                "method": "initialize",
                "params": { "protocolVersion": 1, "clientCapabilities": {} }
            }),
            serde_json::json!({
                "jsonrpc": "2.0",
                "id": 2,
                "method": "session/new",
                "params": { "cwd": supervisor_cwd, "mcpServers": [] }
            }),
        ] {
            let _ = stdin_tx_handle.send(request.to_string()).await;
        }

        loop {
            let line = match reader.next_line().await {
                Ok(Some(line)) => line,
                Ok(None) => break,
                Err(e) => {
                    error!("[{}] Error reading omp stdout: {}", supervisor_id, e);
                    break;
                }
            };
            let trimmed = line.trim();
            if trimmed.is_empty() {
                continue;
            }
            {
                let mut buf = buffer_handle.lock().await;
                if buf.len() >= BUFFER_CAPACITY {
                    buf.pop_front();
                }
                buf.push_back(trimmed.to_string());
            }
            let _ = event_tx_handle.send(trimmed.to_string());
        }

        info!("[{}] omp acp exited", supervisor_id);
        write_task.abort();
        let _ = child.kill().await;
        // A session whose agent is gone must not linger in the session list.
        sessions.write().await.remove(&supervisor_id);
    });

    let session = Arc::new(Session {
        id: session_id.clone(),
        cwd: canonical_cwd.clone(),
        created_at: std::time::SystemTime::now(),
        stdin_tx,
        event_tx,
        buffer,
        supervisor: supervisor.abort_handle(),
    });

    state.sessions.write().await.insert(session_id.clone(), session);

    Ok(Json(CreateSessionResponse {
        id: session_id,
        cwd: canonical_cwd.to_string_lossy().to_string(),
    }))
}

async fn delete_session(
    State(state): State<AppState>,
    AxumPath(id): AxumPath<String>,
) -> impl IntoResponse {
    let session = state.sessions.write().await.remove(&id);
    match session {
        Some(s) => {
            info!("Terminating session {}", id);
            // Dropping the supervisor drops the child, and `kill_on_drop` kills it.
            s.supervisor.abort();
            StatusCode::NO_CONTENT
        }
        None => StatusCode::NOT_FOUND,
    }
}

async fn ws_handler(
    State(state): State<AppState>,
    AxumPath(id): AxumPath<String>,
    ws: WebSocketUpgrade,
) -> impl IntoResponse {
    let session = state.sessions.read().await.get(&id).cloned();
    match session {
        Some(s) => ws.on_upgrade(move |socket| handle_ws(socket, s)),
        None => (StatusCode::NOT_FOUND, "Session not found").into_response(),
    }
}

async fn handle_ws(socket: WebSocket, session: Arc<Session>) {
    let (mut ws_sender, mut ws_receiver) = socket.split();

    // Replay what this session has already produced so a reload attaches mid-stream.
    {
        let buf = session.buffer.lock().await;
        for msg in buf.iter() {
            if ws_sender.send(Message::Text(msg.clone().into())).await.is_err() {
                return;
            }
        }
    }

    let mut event_rx = session.event_tx.subscribe();
    let stdin_tx = session.stdin_tx.clone();
    let sess_id = session.id.clone();

    let mut send_task = tokio::spawn(async move {
        while let Ok(msg) = event_rx.recv().await {
            if ws_sender.send(Message::Text(msg.into())).await.is_err() {
                break;
            }
        }
    });

    let recv_id = sess_id.clone();
    let mut recv_task = tokio::spawn(async move {
        while let Some(Ok(msg)) = ws_receiver.next().await {
            match msg {
                Message::Text(text) => {
                    if stdin_tx.send(text.to_string()).await.is_err() {
                        break;
                    }
                }
                Message::Close(_) => break,
                _ => {}
            }
        }
        info!("[{}] WebSocket client disconnected", recv_id);
    });

    tokio::select! {
        _ = &mut send_task => recv_task.abort(),
        _ = &mut recv_task => send_task.abort(),
    }
}
