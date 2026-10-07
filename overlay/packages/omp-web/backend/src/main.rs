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
use tokio::sync::{broadcast, mpsc, Mutex, Notify, RwLock};
use tracing::{error, info};

/// Number of transcript frames kept per session so a browser tab can reload (or
/// a second tab can attach) without losing the visible conversation. Frames are
/// retained in both directions: prompts the browser sent and the agent's
/// replies.
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
    /// The sequence number orders this stream against the replay window.
    event_tx: broadcast::Sender<(u64, String)>,
    /// Tail of the transcript, replayed to websockets that attach late.
    transcript: Arc<Mutex<Transcript>>,
    /// Identity the agent assigned to this session during the handshake.
    agent_session: Arc<AgentSession>,
    supervisor: tokio::task::AbortHandle,
}

/// Ordered frames retained for websockets that attach late.
///
/// A reloaded tab (or a second tab) has to rebuild the conversation from this
/// window, so it holds both directions: what the operator sent and what the
/// agent answered. The agent only ever reports its own side, hence the browser
/// frames recorded in `handle_ws`.
struct Transcript {
    next_sequence: u64,
    frames: VecDeque<(u64, String)>,
}

impl Transcript {
    fn new() -> Self {
        Self {
            next_sequence: 0,
            frames: VecDeque::with_capacity(BUFFER_CAPACITY),
        }
    }

    /// Appends a frame and stamps it with the next sequence number.
    fn record(&mut self, frame: String) -> u64 {
        self.next_sequence += 1;
        self.frames.push_back((self.next_sequence, frame));
        if self.frames.len() > BUFFER_CAPACITY {
            self.frames.pop_front();
        }
        self.next_sequence
    }

    fn snapshot(&self) -> Vec<(u64, String)> {
        self.frames.iter().cloned().collect()
    }

    /// Frames the cursor has not seen, used to recover a lagged subscriber.
    fn since(&self, cursor: u64) -> Vec<(u64, String)> {
        self.frames
            .iter()
            .filter(|(sequence, _)| *sequence > cursor)
            .cloned()
            .collect()
    }
}

/// The `sessionId` an `omp acp` child returns from `session/new`.
///
/// The browser speaks a session-less dialect — it never sees the handshake — so
/// every `session/*` request it sends is stamped with this id on the way to the
/// child, which rejects any request naming a session it does not know.
#[derive(Default)]
struct AgentSession {
    id: Mutex<Option<String>>,
    assigned: Notify,
}

impl AgentSession {
    /// Resolves once the handshake completed: a browser may send its first
    /// request before the child has answered `session/new`.
    async fn required(&self) -> String {
        loop {
            let assigned = self.assigned.notified();
            if let Some(id) = self.id.lock().await.clone() {
                return id;
            }
            assigned.await;
        }
    }

    async fn assign(&self, id: String) {
        *self.id.lock().await = Some(id);
        self.assigned.notify_waiters();
    }
}

/// Request ids the gateway uses for the handshake it performs itself.
const INITIALIZE_REQUEST_ID: u64 = 1;
const NEW_SESSION_REQUEST_ID: u64 = 2;

/// The answer to `session/new` carries the id the agent assigned.
fn assigned_session_id(frame: &str) -> Option<String> {
    let response: serde_json::Value = serde_json::from_str(frame).ok()?;
    if response.get("id")?.as_u64()? != NEW_SESSION_REQUEST_ID {
        return None;
    }
    Some(response.get("result")?.get("sessionId")?.as_str()?.to_string())
}

/// Stamp the agent-assigned session id onto a browser-originated request.
///
/// `session/new` creates the session, so it is the one method that must not
/// carry one; anything that is not JSON, or already names a session, is
/// forwarded untouched.
async fn stamped_session_id(request: &str, agent_session: &AgentSession) -> String {
    let mut value: serde_json::Value = match serde_json::from_str(request) {
        Ok(value) => value,
        Err(_) => return request.to_string(),
    };
    let stamps = value
        .get("method")
        .and_then(|method| method.as_str())
        .is_some_and(|method| method.starts_with("session/") && method != "session/new");
    if !stamps || value.pointer("/params/sessionId").is_some() {
        return request.to_string();
    }

    // A child that never answers `session/new` must not hang the browser: the
    // unstamped request reaches the agent, which reports the protocol error.
    let session_id = match tokio::time::timeout(
        std::time::Duration::from_secs(15),
        agent_session.required(),
    )
    .await
    {
        Ok(session_id) => session_id,
        Err(_) => return request.to_string(),
    };

    match value.get_mut("params") {
        Some(serde_json::Value::Object(params)) => {
            params.insert("sessionId".to_string(), session_id.into());
        }
        _ => return request.to_string(),
    }
    serde_json::to_string(&value).unwrap_or_else(|_| request.to_string())
}

/// Gateway-private notification carrying a prompt the browser submitted.
///
/// The SPA renders operator messages from this echo rather than optimistically,
/// which is what makes the transcript after a reload identical to the live one.
/// It is deliberately not an ACP method: the frame never reaches the child,
/// it only travels back out to browsers.
fn prompt_frame(text: &str) -> String {
    serde_json::json!({
        "jsonrpc": "2.0",
        "method": "web/prompt",
        "params": { "text": text },
    })
    .to_string()
}

/// Same, for the answer the browser gave to `session/request_permission`: a
/// replayed transcript must not offer to answer the same request twice.
fn permission_response_frame(request_id: &serde_json::Value) -> String {
    serde_json::json!({
        "jsonrpc": "2.0",
        "method": "web/permission_response",
        "params": { "id": request_id },
    })
    .to_string()
}

/// The frames a browser sends that belong in the transcript.
///
/// Only the agent's own frames reach the websockets otherwise, so a tab that
/// reloads (or a second tab that attaches) would replay answers whose prompts
/// are missing.
fn browser_transcript_frame(request: &str) -> Option<String> {
    let value: serde_json::Value = serde_json::from_str(request).ok()?;
    match value.get("method").and_then(|method| method.as_str()) {
        Some("session/prompt") => {
            let text: String = value
                .pointer("/params/prompt")?
                .as_array()?
                .iter()
                .filter(|block| block.get("type").and_then(|kind| kind.as_str()) == Some("text"))
                .filter_map(|block| block.get("text").and_then(|text| text.as_str()))
                .collect();
            (!text.is_empty()).then(|| prompt_frame(&text))
        }
        // A JSON-RPC response: `session/request_permission` is the only request
        // the browser ever answers.
        None if value.get("id").is_some()
            && (value.get("result").is_some() || value.get("error").is_some()) =>
        {
            Some(permission_response_frame(value.get("id")?))
        }
        _ => None,
    }
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
    let (event_tx, _) = broadcast::channel::<(u64, String)>(BUFFER_CAPACITY);
    let transcript = Arc::new(Mutex::new(Transcript::new()));
    let agent_session = Arc::new(AgentSession::default());

    let sessions = state.sessions.clone();
    let supervisor_id = session_id.clone();
    let supervisor_cwd = canonical_cwd.to_string_lossy().to_string();
    let transcript_handle = transcript.clone();
    let event_tx_handle = event_tx.clone();
    let agent_session_handle = agent_session.clone();
    let stdin_tx_handle = stdin_tx.clone();

    let supervisor = tokio::spawn(async move {
        let mut reader = BufReader::new(child_stdout).lines();

        // Pump browser-originated ACP requests into the child's stdin. Ends once
        // every sender is gone, so the child sees EOF.
        let writer_id = supervisor_id.clone();
        let agent_session_for_writer = agent_session_handle.clone();
        let write_task = tokio::spawn(async move {
            let mut writer = child_stdin;
            while let Some(msg) = stdin_rx.recv().await {
                let trimmed = msg.trim();
                if trimmed.is_empty() {
                    continue;
                }
                let frame = stamped_session_id(trimmed, &agent_session_for_writer).await;
                if let Err(e) = writer.write_all(format!("{}\n", frame).as_bytes()).await {
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
                "id": INITIALIZE_REQUEST_ID,
                "method": "initialize",
                "params": { "protocolVersion": 1, "clientCapabilities": {} }
            }),
            serde_json::json!({
                "jsonrpc": "2.0",
                "id": NEW_SESSION_REQUEST_ID,
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
            // Learn the id the agent assigned before any request that needs it
            // can be stamped; the frame itself stays in the transcript either
            // way.
            if let Some(agent_id) = assigned_session_id(trimmed) {
                info!("[{}] ACP session {}", supervisor_id, agent_id);
                agent_session_handle.assign(agent_id).await;
            }
            let sequence = transcript_handle.lock().await.record(trimmed.to_string());
            let _ = event_tx_handle.send((sequence, trimmed.to_string()));
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
        transcript,
        agent_session,
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

    // Subscribe before snapshotting: the replay window and the live stream then
    // overlap by construction, and the sequence numbers drop that overlap, so a
    // client attaching mid-turn sees every frame exactly once.
    let mut event_rx = session.event_tx.subscribe();
    let replay: Vec<(u64, String)> = session.transcript.lock().await.snapshot();
    let mut cursor = 0u64;
    for (sequence, msg) in replay {
        if ws_sender.send(Message::Text(msg.into())).await.is_err() {
            return;
        }
        cursor = sequence;
    }

    let stdin_tx = session.stdin_tx.clone();
    let transcript = session.transcript.clone();
    let replay_transcript = transcript.clone();
    let event_tx = session.event_tx.clone();
    let sess_id = session.id.clone();

    let mut send_task = tokio::spawn(async move {
        loop {
            match event_rx.recv().await {
                Ok((sequence, msg)) => {
                    // Already covered by the replay above.
                    if sequence <= cursor {
                        continue;
                    }
                    cursor = sequence;
                    if ws_sender.send(Message::Text(msg.into())).await.is_err() {
                        break;
                    }
                }
                // This socket fell behind the broadcast; recover the gap from
                // the retained window instead of dropping the client.
                Err(broadcast::error::RecvError::Lagged(_)) => {
                    let missed: Vec<(u64, String)> = replay_transcript.lock().await.since(cursor);
                    for (sequence, msg) in missed {
                        cursor = sequence;
                        if ws_sender.send(Message::Text(msg.into())).await.is_err() {
                            return;
                        }
                    }
                }
                Err(broadcast::error::RecvError::Closed) => break,
            }
        }
    });

    let recv_id = sess_id.clone();
    let mut recv_task = tokio::spawn(async move {
        while let Some(Ok(msg)) = ws_receiver.next().await {
            match msg {
                Message::Text(text) => {
                    let request = text.to_string();
                    // Recorded before the request is forwarded: the operator's
                    // own message belongs in the transcript even if the child
                    // never accepts it.
                    if let Some(frame) = browser_transcript_frame(&request) {
                        let sequence = transcript.lock().await.record(frame.clone());
                        let _ = event_tx.send((sequence, frame));
                    }
                    if stdin_tx.send(request).await.is_err() {
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
