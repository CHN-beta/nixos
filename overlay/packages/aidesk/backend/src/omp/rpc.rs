//! `omp --mode rpc-ui` process management + the live agent session registry.
//!
//! Transport: newline-delimited JSON over stdin/stdout. Commands carry a `wN`
//! id and are answered by `{"type":"response","id":...}` frames; every other
//! frame is an agent event. Protocol v2 (negotiated when the ready frame
//! advertises it) reassembles oversized outbound frames from `rpc_chunk`
//! sequences. Commands written to stdin are always single lines.

use crate::state::SharedState;
use crate::util::{now_ms, path_key, same_path};
use base64::Engine;
use serde_json::{json, Map, Value};
use std::collections::{HashMap, HashSet};
use std::sync::atomic::{AtomicBool, AtomicI64, AtomicU64, Ordering};
use std::sync::{Arc, LazyLock, Mutex, RwLock};
use std::time::Duration;
use tokio::io::{AsyncBufReadExt, AsyncWriteExt, BufReader};
use tokio::process::{ChildStdin, Command};
use tokio::sync::{broadcast, mpsc, oneshot, watch};

const READY_TIMEOUT: Duration = Duration::from_secs(120);
const PROMPT_ACK_TIMEOUT: Duration = Duration::from_secs(30);
const GET_STATE_TIMEOUT: Duration = Duration::from_secs(5);
const GENERATE_TITLE_TIMEOUT: Duration = Duration::from_secs(60);
const MAX_RPC_FRAME_BYTES: usize = 1024 * 1024;
const MAX_RPC_REASSEMBLED_BYTES: usize = 64 * 1024 * 1024;
const RPC_CHUNK_PAYLOAD_BYTES: usize = 256 * 1024;
const MAX_INBOUND_COMMAND_BYTES: usize = 32 * 1024 * 1024;

/// A session with no web UI attached is torn down after this long, so closing
/// a tab does not pin an `omp` child (and its model slot) for the full idle
/// window. 120s stays above the client's capped SSE reconnect backoff.
const DISCONNECT_DESTROY_MS: f64 = 120_000.0;
/// Backstop for a session that keeps receiving frames but is never used.
const IDLE_DESTROY_MS: f64 = 600_000.0;
/// How often the reaper re-evaluates registered sessions.
const REAPER_INTERVAL: Duration = Duration::from_secs(5);
/// Preset tool set that means "everything": spawn without `--tools`.
const PRESET_FULL: &[&str] = &["bash", "read", "edit", "write", "grep", "find", "ls"];

#[derive(Debug, Clone)]
pub struct RpcError {
    pub message: String,
    pub code: Option<String>,
}

impl RpcError {
    pub fn new(message: impl Into<String>, code: Option<&str>) -> Self {
        Self {
            message: message.into(),
            code: code.map(|code| code.to_string()),
        }
    }

    pub fn plain(message: impl Into<String>) -> Self {
        Self::new(message, None)
    }
}

impl std::fmt::Display for RpcError {
    fn fmt(&self, formatter: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        formatter.write_str(&self.message)
    }
}

#[derive(Debug, Clone)]
pub struct ProcessExit {
    pub code: Option<i32>,
    pub signal: Option<String>,
    pub stderr_tail: String,
}

struct PendingChunks {
    chunk_id: String,
    count: usize,
    byte_length: usize,
    next_index: usize,
    chunks: Vec<Vec<u8>>,
    received: usize,
}

#[derive(Default)]
struct FrameDecoder {
    pending: Option<PendingChunks>,
}

fn decode_base64(value: &Value) -> Result<Vec<u8>, String> {
    let text = value
        .as_str()
        .ok_or_else(|| "invalid RPC chunk data".to_string())?;
    if text.is_empty() {
        return Err("invalid RPC chunk data".into());
    }
    base64::engine::general_purpose::STANDARD
        .decode(text)
        .map_err(|_| "invalid RPC chunk data".to_string())
}

impl FrameDecoder {
    fn push(&mut self, value: Value) -> Result<Option<Value>, String> {
        let is_chunk = value.get("type").and_then(Value::as_str) == Some("rpc_chunk");
        if !is_chunk {
            if self.pending.is_some() {
                return Err("RPC chunk sequence interrupted".into());
            }
            if value.get("type").and_then(Value::as_str).is_none() {
                return Err("RPC frame must be an object".into());
            }
            return Ok(Some(value));
        }
        let object = value.as_object().ok_or("invalid RPC chunk")?;
        let chunk_id = object
            .get("chunkId")
            .and_then(Value::as_str)
            .ok_or("invalid RPC chunk metadata")?
            .to_string();
        let index = object
            .get("index")
            .and_then(Value::as_u64)
            .ok_or("invalid RPC chunk metadata")? as usize;
        let count = object
            .get("count")
            .and_then(Value::as_u64)
            .ok_or("invalid RPC chunk metadata")? as usize;
        let byte_length = object
            .get("byteLength")
            .and_then(Value::as_u64)
            .ok_or("invalid RPC chunk metadata")? as usize;
        if chunk_id.is_empty()
            || chunk_id.len() > 128
            || count < 2
            || count > MAX_RPC_REASSEMBLED_BYTES / RPC_CHUNK_PAYLOAD_BYTES
            || index >= count
            || byte_length < MAX_RPC_FRAME_BYTES
            || byte_length > MAX_RPC_REASSEMBLED_BYTES
        {
            return Err("invalid RPC chunk metadata".into());
        }
        let bytes = decode_base64(object.get("data").unwrap_or(&Value::Null))?;
        if bytes.len() > RPC_CHUNK_PAYLOAD_BYTES {
            return Err("RPC chunk payload exceeds the transport limit".into());
        }
        if self.pending.is_none() {
            if index != 0 {
                return Err("RPC chunk sequence must start at index 0".into());
            }
            self.pending = Some(PendingChunks {
                chunk_id: chunk_id.clone(),
                count,
                byte_length,
                next_index: 0,
                chunks: Vec::new(),
                received: 0,
            });
        }
        let pending = self.pending.as_mut().unwrap();
        if pending.chunk_id != chunk_id
            || pending.count != count
            || pending.byte_length != byte_length
            || pending.next_index != index
        {
            return Err("RPC chunk sequence mismatch".into());
        }
        pending.chunks.push(bytes.clone());
        pending.received += bytes.len();
        pending.next_index += 1;
        if pending.received > pending.byte_length {
            return Err("RPC chunk sequence exceeds declared length".into());
        }
        if pending.next_index < pending.count {
            return Ok(None);
        }
        if pending.received != pending.byte_length {
            return Err("RPC chunk sequence length mismatch".into());
        }
        let pending = self.pending.take().unwrap();
        let mut combined = Vec::with_capacity(pending.byte_length);
        for chunk in pending.chunks {
            combined.extend(chunk);
        }
        let text =
            String::from_utf8(combined).map_err(|_| "RPC chunk is not valid UTF-8".to_string())?;
        let frame: Value =
            serde_json::from_str(&text).map_err(|_| "RPC chunk is not valid JSON".to_string())?;
        if frame.get("type").and_then(Value::as_str).is_none() {
            return Err("RPC frame must be an object".into());
        }
        Ok(Some(frame))
    }
}

pub struct RpcProcess {
    pub cwd: String,
    pid: u32,
    stdin: Arc<tokio::sync::Mutex<Option<ChildStdin>>>,
    pending: Mutex<HashMap<String, oneshot::Sender<Result<Value, RpcError>>>>,
    next_id: AtomicU64,
    ready_tx: Mutex<Option<oneshot::Sender<Value>>>,
    ready_rx: Mutex<Option<oneshot::Receiver<Value>>>,
    frame_sinks: Mutex<Vec<mpsc::UnboundedSender<Value>>>,
    protocol: AtomicI64,
    exited: AtomicBool,
    exit_watch: watch::Sender<Option<ProcessExit>>,
    stderr_tail: Mutex<String>,
}

impl RpcProcess {
    /// Spawn `omp --mode rpc-ui --cwd <cwd> [extra args]`.
    pub fn spawn(
        omp_bin: &str,
        cwd: &str,
        extra_args: &[String],
        env: &[(String, String)],
    ) -> Result<Arc<Self>, RpcError> {
        let mut command = Command::new(omp_bin);
        command
            .arg("--mode")
            .arg("rpc-ui")
            .arg("--cwd")
            .arg(cwd)
            .args(extra_args)
            .current_dir(cwd)
            .env_remove("OMP_PROFILE")
            .env_remove("PI_PROFILE")
            .stdin(std::process::Stdio::piped())
            .stdout(std::process::Stdio::piped())
            .stderr(std::process::Stdio::piped())
            .kill_on_drop(false);
        for (name, value) in env {
            command.env(name, value);
        }
        // Own process group so dispose() can signal the whole tree.
        command.process_group(0);
        let mut child = command
            .spawn()
            .map_err(|error| RpcError::plain(format!("Failed to start omp: {}", error)))?;
        let pid = child.id().unwrap_or(0);
        let stdin = child.stdin.take();
        let stdout = child.stdout.take();
        let stderr = child.stderr.take();
        let (ready_tx, ready_rx) = oneshot::channel();
        let (exit_watch, _) = watch::channel(None);
        let process = Arc::new(Self {
            cwd: cwd.to_string(),
            pid,
            stdin: Arc::new(tokio::sync::Mutex::new(stdin)),
            pending: Mutex::new(HashMap::new()),
            next_id: AtomicU64::new(1),
            ready_tx: Mutex::new(Some(ready_tx)),
            ready_rx: Mutex::new(Some(ready_rx)),
            frame_sinks: Mutex::new(Vec::new()),
            protocol: AtomicI64::new(1),
            exited: AtomicBool::new(false),
            exit_watch,
            stderr_tail: Mutex::new(String::new()),
        });

        if let Some(stdout) = stdout {
            let reader = process.clone();
            tokio::spawn(async move {
                let mut lines = BufReader::new(stdout).lines();
                let mut decoder = FrameDecoder::default();
                while let Ok(Some(line)) = lines.next_line().await {
                    let trimmed = line.trim();
                    if trimmed.is_empty() {
                        continue;
                    }
                    let Ok(parsed) = serde_json::from_str::<Value>(trimmed) else {
                        continue;
                    };
                    let is_chunk = parsed.get("type").and_then(Value::as_str) == Some("rpc_chunk");
                    if is_chunk && reader.protocol.load(Ordering::Relaxed) != 2 {
                        reader.push_stderr(
                            "\nRPC protocol error: RPC chunk received before protocol negotiation",
                        );
                        reader.dispose(Duration::from_millis(0)).await;
                        return;
                    }
                    let frame = match decoder.push(parsed) {
                        Ok(Some(frame)) => frame,
                        Ok(None) => continue,
                        Err(error) => {
                            reader.push_stderr(&format!("\nRPC protocol error: {}", error));
                            reader.dispose(Duration::from_millis(0)).await;
                            return;
                        }
                    };
                    reader.dispatch_frame(frame);
                }
            });
        }
        if let Some(stderr) = stderr {
            let reader = process.clone();
            tokio::spawn(async move {
                let mut lines = BufReader::new(stderr).lines();
                while let Ok(Some(line)) = lines.next_line().await {
                    reader.push_stderr(&format!("\n{}", line));
                }
            });
        }
        let waiter = process.clone();
        tokio::spawn(async move {
            let status = child.wait().await;
            let (code, signal) = match status {
                Ok(status) => {
                    use std::os::unix::process::ExitStatusExt;
                    (
                        status.code(),
                        status.signal().map(|signal| signal.to_string()),
                    )
                }
                Err(_) => (None, None),
            };
            waiter.finalize(code, signal);
        });
        Ok(process)
    }

    fn push_stderr(&self, text: &str) {
        if let Ok(mut tail) = self.stderr_tail.lock() {
            tail.push_str(text);
            if tail.len() > 8192 {
                let keep = tail.len() - 8192;
                *tail = tail[keep..].to_string();
            }
        }
    }

    pub fn stderr_tail(&self) -> String {
        self.stderr_tail
            .lock()
            .map(|tail| tail.clone())
            .unwrap_or_default()
    }

    fn dispatch_frame(&self, frame: Value) {
        match frame.get("type").and_then(Value::as_str) {
            Some("ready") => {
                if let Ok(mut slot) = self.ready_tx.lock() {
                    if let Some(sender) = slot.take() {
                        let _ = sender.send(frame);
                    }
                }
            }
            Some("response") => self.handle_response(frame),
            _ => self.broadcast_frame(frame),
        }
    }

    fn broadcast_frame(&self, frame: Value) {
        if let Ok(mut sinks) = self.frame_sinks.lock() {
            sinks.retain(|sink| sink.send(frame.clone()).is_ok());
        }
    }

    fn handle_response(&self, response: Value) {
        let id = response
            .get("id")
            .and_then(Value::as_str)
            .map(|id| id.to_string());
        let entry = id
            .as_ref()
            .and_then(|id| self.pending.lock().ok()?.remove(id));
        match entry {
            None => self.broadcast_frame(response),
            Some(sender) => {
                if response.get("success").and_then(Value::as_bool) == Some(true) {
                    let _ = sender.send(Ok(response.get("data").cloned().unwrap_or(Value::Null)));
                } else {
                    let message = response
                        .get("error")
                        .and_then(Value::as_str)
                        .unwrap_or("RPC command failed")
                        .to_string();
                    let code = response.get("code").and_then(Value::as_str);
                    let _ = sender.send(Err(RpcError::new(message, code)));
                }
            }
        }
    }

    fn finalize(&self, code: Option<i32>, signal: Option<String>) {
        if self.exited.swap(true, Ordering::SeqCst) {
            return;
        }
        let tail = self.stderr_tail();
        let exit = ProcessExit {
            code,
            signal: signal.clone(),
            stderr_tail: tail.clone(),
        };
        if let Ok(mut pending) = self.pending.lock() {
            let detail = format!(
                "omp exited (code {}, signal {}){}",
                code.map(|c| c.to_string()).unwrap_or_else(|| "null".into()),
                signal.clone().unwrap_or_else(|| "none".into()),
                if tail.is_empty() {
                    String::new()
                } else {
                    format!(
                        ": {}",
                        tail.chars()
                            .rev()
                            .take(500)
                            .collect::<String>()
                            .chars()
                            .rev()
                            .collect::<String>()
                    )
                }
            );
            for (_, sender) in pending.drain() {
                let _ = sender.send(Err(RpcError::plain(detail.clone())));
            }
        }
        if let Ok(mut slot) = self.ready_tx.lock() {
            slot.take();
        }
        self.broadcast_frame(json!({
            "type": "__process_exit",
            "code": code,
            "signal": signal,
            "detail": tail.lines().last().unwrap_or("").to_string(),
        }));
        let _ = self.exit_watch.send(Some(exit));
        if let Ok(mut sinks) = self.frame_sinks.lock() {
            sinks.clear();
        }
    }

    pub fn is_alive(&self) -> bool {
        !self.exited.load(Ordering::SeqCst)
    }

    pub fn subscribe(&self) -> mpsc::UnboundedReceiver<Value> {
        let (tx, rx) = mpsc::unbounded_channel();
        if let Ok(mut sinks) = self.frame_sinks.lock() {
            sinks.push(tx);
        }
        rx
    }

    pub async fn wait_ready(&self, timeout: Duration) -> Result<Value, RpcError> {
        let receiver = self.ready_rx.lock().ok().and_then(|mut slot| slot.take());
        let Some(receiver) = receiver else {
            return Err(RpcError::plain("omp RPC ready already awaited"));
        };
        match tokio::time::timeout(timeout, receiver).await {
            Ok(Ok(frame)) => Ok(frame),
            Ok(Err(_)) => Err(RpcError::plain("omp RPC process exited before ready")),
            Err(_) => Err(RpcError::plain(format!(
                "omp RPC ready timeout after {}ms",
                timeout.as_millis()
            ))),
        }
    }

    pub async fn negotiate_protocol(&self, ready: &Value) -> Result<i64, RpcError> {
        let supports_two = ready
            .get("supportedProtocolVersions")
            .and_then(Value::as_array)
            .map(|versions| versions.iter().any(|v| v.as_i64() == Some(2)))
            .unwrap_or(false);
        if !supports_two {
            return Ok(self.protocol.load(Ordering::Relaxed));
        }
        let response = self
            .send_command(
                json!({ "type": "negotiate_protocol", "protocolVersion": 2 }),
                Some(Duration::from_secs(30)),
            )
            .await?;
        if response.get("protocolVersion").and_then(Value::as_i64) != Some(2) {
            return Err(RpcError::plain("OMP rejected RPC protocol v2 negotiation"));
        }
        self.protocol.store(2, Ordering::Relaxed);
        Ok(2)
    }

    async fn write_line(&self, line: String) -> Result<(), RpcError> {
        if !self.is_alive() {
            return Err(RpcError::plain("omp RPC process has exited"));
        }
        let mut guard = self.stdin.lock().await;
        let Some(stdin) = guard.as_mut() else {
            return Err(RpcError::plain("RPC process is not running"));
        };
        stdin
            .write_all(line.as_bytes())
            .await
            .map_err(|error| RpcError::plain(error.to_string()))?;
        stdin
            .flush()
            .await
            .map_err(|error| RpcError::plain(error.to_string()))
    }

    pub async fn send_command(
        &self,
        command: Value,
        timeout: Option<Duration>,
    ) -> Result<Value, RpcError> {
        if !self.is_alive() {
            return Err(RpcError::plain("omp RPC process has exited"));
        }
        let id = format!("w{}", self.next_id.fetch_add(1, Ordering::SeqCst));
        let (tx, rx) = oneshot::channel();
        if let Ok(mut pending) = self.pending.lock() {
            pending.insert(id.clone(), tx);
        }
        let mut object = command.as_object().cloned().unwrap_or_default();
        object.insert("id".into(), Value::String(id.clone()));
        let json_text = Value::Object(object).to_string();
        if json_text.len() + 1 > MAX_INBOUND_COMMAND_BYTES {
            self.remove_pending(&id);
            return Err(RpcError::plain(format!(
                "RPC command exceeds the {}-byte inbound transport limit",
                MAX_INBOUND_COMMAND_BYTES
            )));
        }
        if let Err(error) = self.write_line(format!("{}\n", json_text)).await {
            self.remove_pending(&id);
            return Err(error);
        }
        let result = match timeout {
            Some(duration) => match tokio::time::timeout(duration, rx).await {
                Ok(result) => result,
                Err(_) => {
                    self.remove_pending(&id);
                    return Err(RpcError::new(
                        format!("RPC command timed out after {}ms", duration.as_millis()),
                        Some("rpc_timeout"),
                    ));
                }
            },
            None => rx.await,
        };
        match result {
            Ok(value) => value,
            Err(_) => Err(RpcError::plain("omp RPC process exited")),
        }
    }

    fn remove_pending(&self, id: &str) {
        if let Ok(mut pending) = self.pending.lock() {
            pending.remove(id);
        }
    }

    pub fn send_frame(&self, frame: Value) {
        if !self.is_alive() {
            return;
        }
        let text = frame.to_string();
        if text.len() + 1 > MAX_INBOUND_COMMAND_BYTES {
            return;
        }
        let stdin = self.stdin.clone();
        // Fire-and-forget: the write is queued on the runtime.
        tokio::spawn(async move {
            let mut guard = stdin.lock().await;
            if let Some(stdin) = guard.as_mut() {
                let _ = stdin.write_all(format!("{}\n", text).as_bytes()).await;
                let _ = stdin.flush().await;
            }
        });
    }

    pub fn exit_signal(&self) -> watch::Receiver<Option<ProcessExit>> {
        self.exit_watch.subscribe()
    }

    pub async fn dispose(&self, grace: Duration) {
        if !self.is_alive() {
            return;
        }
        // Closing stdin makes omp exit on EOF. Give it the grace window to
        // flush session state before escalating to signals.
        {
            let mut guard = self.stdin.lock().await;
            guard.take();
        }
        let mut watch = self.exit_watch.subscribe();
        let clean_exit = Duration::from_millis(grace.as_millis().max(10) as u64);
        if tokio::time::timeout(clean_exit, wait_for_exit(&mut watch))
            .await
            .is_ok()
        {
            return;
        }
        if !self.is_alive() || self.pid == 0 {
            return;
        }
        unsafe {
            libc::kill(-(self.pid as i32), libc::SIGTERM);
        }
        if tokio::time::timeout(Duration::from_secs(2), wait_for_exit(&mut watch))
            .await
            .is_ok()
        {
            return;
        }
        unsafe {
            libc::kill(-(self.pid as i32), libc::SIGKILL);
        }
        let _ = tokio::time::timeout(Duration::from_secs(1), wait_for_exit(&mut watch)).await;
    }
}

async fn wait_for_exit(watch: &mut watch::Receiver<Option<ProcessExit>>) {
    loop {
        if watch.borrow().is_some() {
            return;
        }
        if watch.changed().await.is_err() {
            return;
        }
    }
}

// ============================================================================
// Live stream state
// ============================================================================

#[derive(Default)]
struct LiveState {
    prompt_running: bool,
    streaming: bool,
    compacting: bool,
    bash_running: bool,
    response_observed: bool,
    streaming_message: Option<Value>,
    tool_events: Vec<(String, Value)>,
    sequence: u64,
    awaiting_agent_start: bool,
    awaiting_deadline_ms: f64,
    prompt_dispatch_pending: u32,
}

struct Listener {
    id: String,
    tx: mpsc::UnboundedSender<Value>,
}

pub struct AgentSession {
    pub cwd: String,
    pub recorded_cwd: Option<String>,
    pub advisor_spawned: bool,
    state: SharedState,
    session_id: Mutex<String>,
    session_file: Mutex<String>,
    session_name: Mutex<Option<String>>,
    process: RwLock<Arc<RpcProcess>>,
    live: Mutex<LiveState>,
    alive: AtomicBool,
    exit_emitted: AtomicBool,
    restarting: AtomicBool,
    stream_id: Mutex<String>,
    listeners: Mutex<Vec<Listener>>,
    pending_ui: Mutex<HashMap<String, Value>>,
    host_tool_names: Mutex<HashSet<String>>,
    pending_host_tools: Mutex<HashMap<String, Value>>,
    host_uri_schemes: Mutex<HashMap<String, bool>>,
    pending_host_uris: Mutex<HashMap<String, Value>>,
    extension_statuses: Mutex<Map<String, Value>>,
    extension_widgets: Mutex<Map<String, Value>>,
    fast_mode: AtomicBool,
    generate_title_unsupported: AtomicBool,
    /// Last time the session was used (frame, command, or listener).
    last_activity_ms: AtomicI64,
    /// Earliest instant the disconnected-session reaper may destroy it.
    reap_deadline_ms: AtomicI64,
    /// In-flight `send()` calls: never dispose a child under a command that is
    /// still awaiting its response.
    pending_commands: AtomicU64,
    /// The start/restart handshake is in flight.
    handshaking: AtomicBool,
    /// Serializes destroy so concurrent callers wait for the dispose.
    destroy_lock: tokio::sync::Mutex<()>,
}

/// Keeps the reaper away while a route command awaits its response.
struct PendingCommand<'a> {
    session: &'a AgentSession,
}

impl Drop for PendingCommand<'_> {
    fn drop(&mut self) {
        self.session.pending_commands.fetch_sub(1, Ordering::SeqCst);
    }
}

impl AgentSession {
    fn new(
        state: SharedState,
        process: Arc<RpcProcess>,
        cwd: &str,
        recorded_cwd: Option<String>,
        advisor: bool,
    ) -> Arc<Self> {
        let now = now_ms() as i64;
        let session = Arc::new(Self {
            cwd: cwd.to_string(),
            recorded_cwd,
            advisor_spawned: advisor,
            state,
            session_id: Mutex::new(String::new()),
            session_file: Mutex::new(String::new()),
            session_name: Mutex::new(None),
            process: RwLock::new(process),
            live: Mutex::new(LiveState::default()),
            alive: AtomicBool::new(true),
            exit_emitted: AtomicBool::new(false),
            restarting: AtomicBool::new(false),
            stream_id: Mutex::new(uuid::Uuid::new_v4().to_string()),
            listeners: Mutex::new(Vec::new()),
            pending_ui: Mutex::new(HashMap::new()),
            host_tool_names: Mutex::new(HashSet::new()),
            pending_host_tools: Mutex::new(HashMap::new()),
            host_uri_schemes: Mutex::new(HashMap::new()),
            pending_host_uris: Mutex::new(HashMap::new()),
            extension_statuses: Mutex::new(Map::new()),
            extension_widgets: Mutex::new(Map::new()),
            fast_mode: AtomicBool::new(false),
            generate_title_unsupported: AtomicBool::new(false),
            last_activity_ms: AtomicI64::new(now),
            reap_deadline_ms: AtomicI64::new(now + DISCONNECT_DESTROY_MS as i64),
            pending_commands: AtomicU64::new(0),
            handshaking: AtomicBool::new(true),
            destroy_lock: tokio::sync::Mutex::new(()),
        });
        ensure_session_reaper();
        session
    }

    /// Record activity and push the disconnected-session deadline forward.
    fn note_activity(&self) {
        let now = now_ms() as i64;
        self.last_activity_ms.store(now, Ordering::Relaxed);
        self.reap_deadline_ms
            .store(now + DISCONNECT_DESTROY_MS as i64, Ordering::Relaxed);
    }

    fn begin_command(&self) -> PendingCommand<'_> {
        self.pending_commands.fetch_add(1, Ordering::SeqCst);
        PendingCommand { session: self }
    }

    pub fn session_id(&self) -> String {
        self.session_id
            .lock()
            .map(|id| id.clone())
            .unwrap_or_default()
    }

    pub fn session_file(&self) -> String {
        self.session_file
            .lock()
            .map(|file| file.clone())
            .unwrap_or_default()
    }

    fn process(&self) -> Arc<RpcProcess> {
        self.process.read().unwrap().clone()
    }

    pub fn is_alive(&self) -> bool {
        self.alive.load(Ordering::SeqCst) && self.process().is_alive()
    }

    pub fn is_running(&self) -> bool {
        if !self.is_alive() {
            return false;
        }
        self.live
            .lock()
            .map(|live| {
                live.prompt_running || live.streaming || live.compacting || live.bash_running
            })
            .unwrap_or(false)
    }

    /// Last time the session saw a frame, command or listener.
    pub fn last_activity_ms(&self) -> i64 {
        self.last_activity_ms.load(Ordering::Relaxed)
    }

    /// A timeout has expired and nothing is in flight, so the reaper *may*
    /// destroy the child. Explicit lifecycle actions (delete, archive, restart,
    /// shutdown) bypass this check.
    fn timed_out(&self, now: i64) -> bool {
        if self.handshaking.load(Ordering::SeqCst)
            || self.pending_commands.load(Ordering::SeqCst) > 0
            || self.is_running()
            || self.has_subscribers()
        {
            return false;
        }
        let disconnected = now >= self.reap_deadline_ms.load(Ordering::Relaxed);
        let idle = now - self.last_activity_ms() > IDLE_DESTROY_MS as i64;
        disconnected || idle
    }

    fn set_session_identity(&self, id: &str, file: &str) {
        if let Ok(mut slot) = self.session_id.lock() {
            *slot = id.to_string();
        }
        if let Ok(mut slot) = self.session_file.lock() {
            *slot = file.to_string();
        }
    }

    fn apply_state(&self, state: &Value) {
        let id = state.get("sessionId").and_then(Value::as_str).unwrap_or("");
        let file = state
            .get("sessionFile")
            .and_then(Value::as_str)
            .unwrap_or("");
        let previous_id = self.session_id();
        if !id.is_empty() {
            self.set_session_identity(id, file);
            if !previous_id.is_empty() && previous_id != id {
                rebind_registry_key(&previous_id, id, self);
            }
        }
        if let Some(name) = state.get("sessionName").and_then(Value::as_str) {
            if let Ok(mut slot) = self.session_name.lock() {
                *slot = Some(name.to_string());
            }
        }
        if let Ok(mut live) = self.live.lock() {
            live.streaming = state
                .get("isStreaming")
                .and_then(Value::as_bool)
                .unwrap_or(false);
            live.compacting = state
                .get("isCompacting")
                .and_then(Value::as_bool)
                .unwrap_or(false);
            live.sequence += 1;
        }
        if let Some(enabled) = state.get("fastModeEnabled").and_then(Value::as_bool) {
            self.fast_mode.store(enabled, Ordering::Relaxed);
        }
    }

    fn emit(&self, mut event: Value) {
        if event.get("type").and_then(Value::as_str) == Some("__process_exit") {
            return;
        }
        self.note_activity();
        event = crate::omp::media::event_with_tool_result_image_urls(&self.state, event);
        let stream_id = self
            .stream_id
            .lock()
            .map(|id| id.clone())
            .unwrap_or_default();
        if let Some(object) = event.as_object_mut() {
            object.remove("web");
            let kind = object
                .get("type")
                .and_then(Value::as_str)
                .unwrap_or("")
                .to_string();
            let mut live = match self.live.lock() {
                Ok(live) => live,
                Err(_) => return,
            };
            match kind.as_str() {
                "agent_start" => {
                    live.response_observed = false;
                    live.streaming_message = None;
                    live.tool_events.clear();
                    live.sequence += 1;
                }
                "agent_end" => {
                    if event.get("isTerminal").and_then(Value::as_bool) != Some(false) {
                        live.streaming = false;
                        live.prompt_running = false;
                        live.compacting = false;
                        live.streaming_message = None;
                        live.tool_events.clear();
                        live.sequence += 1;
                    }
                }
                "prompt_error" | "prompt_result" => {
                    live.streaming = false;
                    live.prompt_running = false;
                    live.compacting = false;
                    live.streaming_message = None;
                    live.tool_events.clear();
                    live.sequence += 1;
                }
                "message_start" | "message_update" => {
                    if let Some(message) = event.get("message") {
                        if message.get("role").and_then(Value::as_str) != Some("user") {
                            live.streaming_message = Some(message.clone());
                        }
                        if live.prompt_running && has_visible_assistant_content(message) {
                            live.response_observed = true;
                        }
                    }
                }
                "message_end" => {
                    if let Some(message) = event.get("message") {
                        if live.prompt_running && has_visible_assistant_content(message) {
                            live.response_observed = true;
                        }
                        if message.get("role").and_then(Value::as_str)
                            == live
                                .streaming_message
                                .as_ref()
                                .and_then(|m| m.get("role"))
                                .and_then(Value::as_str)
                        {
                            live.streaming_message = None;
                        }
                        if message.get("role").and_then(Value::as_str) == Some("toolResult") {
                            if let Some(call_id) = message.get("toolCallId").and_then(Value::as_str)
                            {
                                live.tool_events.retain(|(id, _)| id != call_id);
                            }
                        }
                    }
                }
                "tool_execution_start" | "tool_execution_update" => {
                    if let Some(call_id) = event.get("toolCallId").and_then(Value::as_str) {
                        let call_id = call_id.to_string();
                        match live.tool_events.iter_mut().find(|(id, _)| *id == call_id) {
                            // Updates carry partial output: merge into the start
                            // frame instead of replacing (and losing) it.
                            Some((_, existing)) => merge_event(existing, &event),
                            None => live.tool_events.push((call_id, event.clone())),
                        }
                    }
                }
                "tool_execution_end" => {
                    if let Some(call_id) = event.get("toolCallId").and_then(Value::as_str) {
                        live.tool_events.retain(|(id, _)| id != call_id);
                    }
                }
                _ => {}
            }
            live.sequence += 1;
            let sequence = live.sequence;
            if let Some(object) = event.as_object_mut() {
                object.insert(
                    "web".into(),
                    json!({ "streamId": stream_id, "sequence": sequence }),
                );
            }
        }
        if let Ok(mut listeners) = self.listeners.lock() {
            listeners.retain(|listener| listener.tx.send(event.clone()).is_ok());
        }
    }

    fn handle_frame(&self, frame: Value) {
        self.note_activity();
        match frame.get("type").and_then(Value::as_str).unwrap_or("") {
            "agent_start" => {
                if let Ok(mut live) = self.live.lock() {
                    live.prompt_running = true;
                    live.streaming = true;
                    live.awaiting_agent_start = false;
                    live.awaiting_deadline_ms = 0.0;
                }
                self.invalidate_session_lists();
                notify_running_change(true);
            }
            "agent_end" => {
                if frame.get("isTerminal").and_then(Value::as_bool) != Some(false) {
                    let observed = self
                        .live
                        .lock()
                        .map(|live| live.response_observed)
                        .unwrap_or(false);
                    if let Ok(mut live) = self.live.lock() {
                        live.streaming = false;
                        live.prompt_running = false;
                        live.awaiting_agent_start = false;
                    }
                    if observed {
                        self.record_notification("completed", None);
                    }
                    self.invalidate_session_lists();
                }
            }
            "session_settled" => {}
            "prompt_result" => {
                if let Ok(mut live) = self.live.lock() {
                    live.prompt_running = false;
                    live.awaiting_agent_start = false;
                    live.awaiting_deadline_ms = 0.0;
                }
            }
            "auto_compaction_start" => {
                if let Ok(mut live) = self.live.lock() {
                    live.compacting = true;
                }
            }
            "auto_compaction_end" => {
                if let Ok(mut live) = self.live.lock() {
                    live.compacting = false;
                }
                self.invalidate_session_lists();
            }
            "session_info_update" => {
                if let Some(title) = frame.get("title").and_then(Value::as_str) {
                    if let Ok(mut name) = self.session_name.lock() {
                        *name = Some(title.to_string());
                    }
                }
                self.invalidate_session_lists();
                notify_running_change(true);
            }
            "response" => {
                if frame.get("success").and_then(Value::as_bool) == Some(false) {
                    let command = frame.get("command").and_then(Value::as_str).unwrap_or("");
                    let prompt_failure = command == "prompt"
                        || (command.is_empty()
                            && self
                                .live
                                .lock()
                                .map(|live| live.prompt_running || live.streaming)
                                .unwrap_or(false));
                    let detail = frame
                        .get("error")
                        .and_then(Value::as_str)
                        .or_else(|| frame.get("message").and_then(Value::as_str))
                        .unwrap_or("RPC command failed")
                        .to_string();
                    if prompt_failure {
                        if let Ok(mut live) = self.live.lock() {
                            live.prompt_running = false;
                            live.awaiting_agent_start = false;
                        }
                        self.record_notification("error", Some(&detail));
                        self.emit(json!({
                            "type": "prompt_error",
                            "errorMessage": detail,
                            "error": frame.get("error").cloned().unwrap_or(Value::Null),
                            "command": frame.get("command").cloned().unwrap_or(Value::Null),
                        }));
                        notify_running_change(false);
                        return;
                    }
                    self.emit(json!({
                        "type": "error",
                        "error": frame.get("error").cloned().unwrap_or(Value::Null),
                        "message": detail,
                        "command": frame.get("command").cloned().unwrap_or(Value::Null),
                    }));
                    notify_running_change(false);
                    return;
                }
            }
            "extension_ui_request" => {
                let method = frame.get("method").and_then(Value::as_str).unwrap_or("");
                let id = frame.get("id").and_then(Value::as_str).unwrap_or("");
                if method == "cancel" {
                    if let Some(target) = frame.get("targetId").and_then(Value::as_str) {
                        if let Ok(mut pending) = self.pending_ui.lock() {
                            pending.remove(target);
                        }
                    }
                } else if matches!(method, "select" | "confirm" | "input" | "editor" | "ask")
                    && !id.is_empty()
                {
                    if let Ok(mut pending) = self.pending_ui.lock() {
                        pending.insert(id.to_string(), frame.clone());
                    }
                } else if method == "setStatus" {
                    if let Some(key) = frame.get("statusKey").and_then(Value::as_str) {
                        if let Ok(mut statuses) = self.extension_statuses.lock() {
                            match frame.get("statusText").and_then(Value::as_str) {
                                Some(text) => {
                                    statuses
                                        .insert(key.to_string(), Value::String(text.to_string()));
                                }
                                None => {
                                    statuses.remove(key);
                                }
                            }
                        }
                    }
                } else if method == "setWidget" {
                    if let Some(key) = frame.get("widgetKey").and_then(Value::as_str) {
                        if let Ok(mut widgets) = self.extension_widgets.lock() {
                            match frame.get("widgetLines") {
                                Some(lines) => {
                                    widgets.insert(
                                        key.to_string(),
                                        json!({
                                            "key": key,
                                            "lines": lines.clone(),
                                            "placement": frame
                                                .get("widgetPlacement")
                                                .and_then(Value::as_str)
                                                .unwrap_or("aboveEditor"),
                                        }),
                                    );
                                }
                                None => {
                                    widgets.remove(key);
                                }
                            }
                        }
                    }
                }
            }
            "host_tool_call" => {
                let id = frame
                    .get("id")
                    .and_then(Value::as_str)
                    .unwrap_or("")
                    .to_string();
                let tool_name = frame
                    .get("toolName")
                    .and_then(Value::as_str)
                    .unwrap_or("")
                    .to_string();
                let registered = self
                    .host_tool_names
                    .lock()
                    .map(|names| names.contains(&tool_name))
                    .unwrap_or(false);
                let has_listeners = self
                    .listeners
                    .lock()
                    .map(|listeners| !listeners.is_empty())
                    .unwrap_or(false);
                if !id.is_empty() && registered && has_listeners {
                    if let Ok(mut pending) = self.pending_host_tools.lock() {
                        pending.insert(id, frame.clone());
                    }
                    self.emit(frame);
                } else if !id.is_empty() && registered && HOST_TOOL_TX.receiver_count() > 0 {
                    // No tab watches this session: hand the call to any open
                    // tab, which answers through POST /api/agent/{id}.
                    if let Ok(mut pending) = self.pending_host_tools.lock() {
                        pending.insert(id.clone(), frame.clone());
                    }
                    let arguments = frame
                        .get("arguments")
                        .and_then(Value::as_object)
                        .cloned()
                        .unwrap_or_default();
                    publish_host_tool(json!({
                        "sessionId": self.session_id(),
                        "id": id,
                        "toolName": tool_name,
                        "arguments": Value::Object(arguments),
                    }));
                } else {
                    self.reject_unexpected_host_tool(&frame);
                }
                return;
            }
            "host_tool_cancel" => {
                if let Some(target) = frame.get("targetId").and_then(Value::as_str) {
                    if let Ok(mut pending) = self.pending_host_tools.lock() {
                        pending.remove(target);
                    }
                }
            }
            "host_uri_request" => {
                let id = frame.get("id").and_then(Value::as_str).unwrap_or("");
                let url = frame.get("url").and_then(Value::as_str).unwrap_or("");
                let scheme = url.split(':').next().unwrap_or("");
                let operation = if frame.get("operation").and_then(Value::as_str) == Some("write") {
                    "write"
                } else {
                    "read"
                };
                let registered = self
                    .host_uri_schemes
                    .lock()
                    .map(|schemes| {
                        schemes
                            .get(scheme)
                            .map(|writable| operation != "write" || *writable)
                            .unwrap_or(false)
                    })
                    .unwrap_or(false);
                let has_listeners = self
                    .listeners
                    .lock()
                    .map(|listeners| !listeners.is_empty())
                    .unwrap_or(false);
                if !id.is_empty() && registered && has_listeners {
                    if let Ok(mut pending) = self.pending_host_uris.lock() {
                        pending.insert(id.to_string(), frame.clone());
                    }
                    self.emit(frame);
                } else {
                    self.process().send_frame(json!({
                        "type": "host_uri_result",
                        "id": id,
                        "isError": true,
                        "error": format!("URI scheme \"{}\" is not registered by AIDesk", scheme),
                    }));
                }
                return;
            }
            "host_uri_cancel" => {
                if let Some(target) = frame.get("targetId").and_then(Value::as_str) {
                    if let Ok(mut pending) = self.pending_host_uris.lock() {
                        pending.remove(target);
                    }
                }
            }
            _ => {}
        }
        self.emit(frame);
        notify_running_change(false);
    }

    fn reject_unexpected_host_tool(&self, frame: &Value) {
        let id = frame.get("id").and_then(Value::as_str).unwrap_or("");
        if id.is_empty() {
            return;
        }
        let tool_name = frame
            .get("toolName")
            .and_then(Value::as_str)
            .unwrap_or("unknown");
        self.process().send_frame(json!({
            "type": "host_tool_result",
            "id": id,
            "isError": true,
            "result": { "content": [{
                "type": "text",
                "text": format!("Host tool \"{}\" is not available in AIDesk. Use OMP's built-in tools within the selected workspace.", tool_name),
            }] },
        }));
        self.emit(json!({
            "type": "notice",
            "level": "warning",
            "message": format!("Rejected unavailable host tool: {}", tool_name),
        }));
    }

    fn reject_pending_host_tools(&self, message: &str) {
        if let Ok(mut pending) = self.pending_host_tools.lock() {
            for (id, _) in pending.drain() {
                self.process().send_frame(json!({
                    "type": "host_tool_result",
                    "id": id,
                    "isError": true,
                    "result": { "content": [{ "type": "text", "text": message }] },
                }));
            }
        }
    }

    fn reject_pending_host_uris(&self, message: &str) {
        if let Ok(mut pending) = self.pending_host_uris.lock() {
            for (id, _) in pending.drain() {
                self.process().send_frame(json!({
                    "type": "host_uri_result",
                    "id": id,
                    "isError": true,
                    "error": message,
                }));
            }
        }
    }

    pub fn add_listener(&self) -> (String, mpsc::UnboundedReceiver<Value>, Value) {
        let id = uuid::Uuid::new_v4().to_string();
        let (tx, rx) = mpsc::unbounded_channel();
        self.note_activity();
        // Snapshot the cursor before replaying pending dialogs: the SSE
        // `connected` frame uses it, so sequences stay monotonic.
        let cursor = self
            .stream_snapshot()
            .get("cursor")
            .cloned()
            .unwrap_or(Value::Null);
        let pending_events: Vec<Value> = self
            .pending_ui
            .lock()
            .map(|pending| pending.values().cloned().collect())
            .unwrap_or_default();
        let sequence_event = |tx: &mpsc::UnboundedSender<Value>, event: Value| {
            let mut event = event;
            let stream_id = self
                .stream_id
                .lock()
                .map(|id| id.clone())
                .unwrap_or_default();
            let mut live = match self.live.lock() {
                Ok(live) => live,
                Err(_) => return,
            };
            live.sequence += 1;
            if let Some(object) = event.as_object_mut() {
                object.insert(
                    "web".into(),
                    json!({ "streamId": stream_id, "sequence": live.sequence }),
                );
            }
            let _ = tx.send(event);
        };
        for event in pending_events {
            sequence_event(&tx, event);
        }
        if let Ok(mut listeners) = self.listeners.lock() {
            listeners.push(Listener { id: id.clone(), tx });
        }
        (id, rx, cursor)
    }

    pub fn remove_listener(&self, id: &str) {
        let remaining = {
            let mut listeners = match self.listeners.lock() {
                Ok(listeners) => listeners,
                Err(_) => return,
            };
            listeners.retain(|listener| listener.id != id);
            listeners.len()
        };
        if remaining == 0 {
            self.reject_pending_host_tools(
                "The web UI disconnected while the agent was waiting for this host tool",
            );
            self.reject_pending_host_uris(
                "The web UI disconnected while the agent was waiting for this URI request",
            );
            // Last tab left: start (not extend) the reap clock.
            let now = now_ms() as i64;
            self.reap_deadline_ms
                .store(now + DISCONNECT_DESTROY_MS as i64, Ordering::Relaxed);
        }
    }

    pub fn has_subscribers(&self) -> bool {
        self.listeners
            .lock()
            .map(|listeners| !listeners.is_empty())
            .unwrap_or(false)
    }

    pub fn stream_snapshot(&self) -> Value {
        let stream_id = self
            .stream_id
            .lock()
            .map(|id| id.clone())
            .unwrap_or_default();
        let live = match self.live.lock() {
            Ok(live) => live,
            Err(_) => return Value::Null,
        };
        json!({
            "cursor": { "streamId": stream_id, "sequence": live.sequence },
            "isStreaming": live.streaming,
            "isPromptRunning": live.prompt_running,
            "isCompacting": live.compacting,
            "streamingMessage": live.streaming_message,
            "toolEvents": live.tool_events.iter().map(|(_, event)| event.clone()).collect::<Vec<_>>(),
            "responseObserved": live.response_observed,
        })
    }

    fn invalidate_session_lists(&self) {
        let file = self.session_file();
        let id = self.session_id();
        if !id.is_empty() {
            notify_sessions_changed(vec![id]);
        }
        if !file.is_empty() {
            self.state.invalidate_session_roots();
        }
    }

    fn record_notification(&self, kind: &str, detail: Option<&str>) {
        let id = self.session_id();
        if id.is_empty() {
            return;
        }
        let name = self.session_name.lock().ok().and_then(|name| name.clone());
        crate::routes::notifications::record_session_notification(
            &self.state.cfg,
            &id,
            name.as_deref(),
            kind,
            detail,
        );
    }

    pub fn build_web_state(&self, state: Value) -> Value {
        self.apply_state(&state);
        let live = self
            .live
            .lock()
            .map(|live| (live.prompt_running, live.streaming))
            .unwrap_or((false, false));
        let mut output = Map::new();
        output.insert(
            "sessionId".into(),
            state.get("sessionId").cloned().unwrap_or(Value::Null),
        );
        output.insert(
            "sessionFile".into(),
            state.get("sessionFile").cloned().unwrap_or(Value::Null),
        );
        output.insert(
            "sessionName".into(),
            state.get("sessionName").cloned().unwrap_or(Value::Null),
        );
        output.insert(
            "isStreaming".into(),
            state
                .get("isStreaming")
                .cloned()
                .unwrap_or(Value::Bool(false)),
        );
        output.insert("isPromptRunning".into(), Value::Bool(live.0));
        output.insert(
            "isBashRunning".into(),
            Value::Bool(self.live.lock().map(|l| l.bash_running).unwrap_or(false)),
        );
        output.insert(
            "responseObserved".into(),
            Value::Bool(
                self.live
                    .lock()
                    .map(|l| l.response_observed)
                    .unwrap_or(false),
            ),
        );
        output.insert(
            "isCompacting".into(),
            state
                .get("isCompacting")
                .cloned()
                .unwrap_or(Value::Bool(false)),
        );
        for key in [
            "autoCompactionEnabled",
            "autoRetryEnabled",
            "interruptMode",
            "steeringMode",
            "followUpMode",
            "messageCount",
            "queuedMessageCount",
            "tokensPerSecond",
            "contextUsage",
            "thinkingLevel",
            "fastModeActive",
            "slowModeSupported",
            "slowModeEnabled",
            "slowModeScope",
            "usageLimit",
            "todoPhases",
            "skillDiagnostics",
        ] {
            if let Some(value) = state.get(key) {
                output.insert(key.into(), value.clone());
            }
        }
        if let Some(model) = state.get("model") {
            let mut mapped = Map::new();
            for key in ["id", "provider", "name", "reasoning"] {
                if let Some(value) = model.get(key) {
                    mapped.insert(key.into(), value.clone());
                }
            }
            if let Some(efforts) = model.get("thinking").and_then(|t| t.get("efforts")) {
                mapped.insert("thinking".into(), json!({ "efforts": efforts }));
            }
            output.insert("model".into(), Value::Object(mapped));
        }
        output.insert(
            "queuedMessages".into(),
            state
                .get("queuedMessages")
                .cloned()
                .unwrap_or_else(|| json!({ "steering": [], "followUp": [] })),
        );
        output.insert(
            "systemPrompt".into(),
            match state.get("systemPrompt") {
                Some(Value::Array(lines)) => Value::String(
                    lines
                        .iter()
                        .filter_map(Value::as_str)
                        .collect::<Vec<_>>()
                        .join("\n\n"),
                ),
                Some(Value::String(text)) => Value::String(text.clone()),
                _ => Value::String(String::new()),
            },
        );
        output.insert(
            "fastModeEnabled".into(),
            state
                .get("fastModeEnabled")
                .or_else(|| state.get("fastMode"))
                .cloned()
                .unwrap_or(Value::Bool(self.fast_mode.load(Ordering::Relaxed))),
        );
        // Extension chrome is tracked from `setStatus`/`setWidget` frames so a
        // get_state snapshot never wipes a live status line or widget.
        let statuses: Vec<Value> = self
            .extension_statuses
            .lock()
            .map(|statuses| {
                statuses
                    .iter()
                    .map(|(key, text)| json!({ "key": key, "text": text }))
                    .collect()
            })
            .unwrap_or_default();
        let widgets: Vec<Value> = self
            .extension_widgets
            .lock()
            .map(|widgets| widgets.values().cloned().collect())
            .unwrap_or_default();
        output.insert("extensionStatuses".into(), Value::Array(statuses));
        output.insert("extensionWidgets".into(), Value::Array(widgets));
        Value::Object(output)
    }

    async fn get_state_with_timeout(&self) -> Result<Value, RpcError> {
        let _pending = self.begin_command();
        self.note_activity();
        self.process()
            .send_command(json!({ "type": "get_state" }), Some(GET_STATE_TIMEOUT))
            .await
    }

    pub async fn generate_title(&self) -> Result<Option<String>, RpcError> {
        let _pending = self.begin_command();
        self.note_activity();
        if self.restarting.load(Ordering::SeqCst) {
            return Err(RpcError::new(
                "This session is restarting — retry in a moment.",
                Some("session_restarting"),
            ));
        }
        if !self.is_alive() {
            return Err(RpcError::plain("Session is no longer running"));
        }
        if !self.generate_title_unsupported.load(Ordering::SeqCst) {
            match self
                .process()
                .send_command(
                    json!({ "type": "generate_title" }),
                    Some(GENERATE_TITLE_TIMEOUT),
                )
                .await
            {
                Ok(result) => {
                    let title = title_from_result(&result)
                        .or_else(|| self.session_name.lock().ok().and_then(|name| name.clone()));
                    if let Some(title) = &title {
                        if let Ok(mut name) = self.session_name.lock() {
                            *name = Some(title.clone());
                        }
                        self.invalidate_session_lists();
                    }
                    return Ok(title);
                }
                Err(error) => {
                    if !error.message.contains("Unknown command") {
                        return Err(error);
                    }
                    self.generate_title_unsupported
                        .store(true, Ordering::SeqCst);
                }
            }
        }
        if self.is_running() {
            return Ok(None);
        }
        let before = self
            .get_state_with_timeout()
            .await
            .ok()
            .and_then(|state| {
                state
                    .get("sessionName")
                    .and_then(Value::as_str)
                    .map(|s| s.to_string())
            })
            .unwrap_or_default();
        self.send(json!({ "type": "prompt", "message": "/rename" }))
            .await?;
        let deadline = now_ms() + 20_000.0;
        loop {
            let title = self.get_state_with_timeout().await.ok().and_then(|state| {
                state
                    .get("sessionName")
                    .and_then(Value::as_str)
                    .map(|s| s.to_string())
            });
            if let Some(title) = title {
                if !title.is_empty() && title != before {
                    if let Ok(mut name) = self.session_name.lock() {
                        *name = Some(title.clone());
                    }
                    self.invalidate_session_lists();
                    return Ok(Some(title));
                }
            }
            if now_ms() >= deadline || !self.is_alive() {
                return Ok(None);
            }
            tokio::time::sleep(Duration::from_millis(500)).await;
        }
    }

    /// Send one RPC command with the same command surface as the Next.js
    /// implementation (fork→branch, get_commands→get_available_commands, …).
    pub async fn send(&self, command: Value) -> Result<Value, RpcError> {
        let _pending = self.begin_command();
        self.note_activity();
        if self.restarting.load(Ordering::SeqCst) {
            return Err(RpcError::new(
                "This session is restarting — retry in a moment.",
                Some("session_restarting"),
            ));
        }
        if !self.is_alive() {
            return Err(RpcError::plain("Session is no longer running"));
        }
        let command_type = command
            .get("type")
            .and_then(Value::as_str)
            .ok_or_else(|| RpcError::plain("command type is required"))?
            .to_string();
        match command_type.as_str() {
            "prompt" => {
                // A `!!` shell command owns the session until it exits; omp
                // rejects a prompt then. Degrade into omp's follow-up queue so
                // the message is delivered when the shell command finishes.
                if self
                    .live
                    .lock()
                    .map(|live| live.bash_running)
                    .unwrap_or(false)
                {
                    return self.queue_while_shell_running(&command).await;
                }
                let streaming_behavior = command.get("streamingBehavior").and_then(Value::as_str);
                if streaming_behavior.is_none() {
                    if let Ok(mut live) = self.live.lock() {
                        live.response_observed = false;
                        if !(live.prompt_running || live.streaming) {
                            live.streaming_message = None;
                            live.tool_events.clear();
                        }
                        live.sequence += 1;
                        live.prompt_running = true;
                        live.prompt_dispatch_pending += 1;
                        live.awaiting_agent_start = false;
                        live.awaiting_deadline_ms = 0.0;
                    }
                    notify_running_change(false);
                }
                let mut frame = Map::new();
                frame.insert("type".into(), Value::String("prompt".into()));
                if let Some(message) = command.get("message") {
                    frame.insert("message".into(), message.clone());
                }
                if let Some(images) = command.get("images").and_then(Value::as_array) {
                    if !images.is_empty() {
                        frame.insert("images".into(), Value::Array(images.clone()));
                    }
                }
                if let Some(behavior) = streaming_behavior {
                    frame.insert(
                        "streamingBehavior".into(),
                        Value::String(behavior.to_string()),
                    );
                }
                let result = self
                    .process()
                    .send_command(Value::Object(frame), Some(PROMPT_ACK_TIMEOUT))
                    .await;
                if streaming_behavior.is_none() {
                    if let Ok(mut live) = self.live.lock() {
                        live.prompt_dispatch_pending =
                            live.prompt_dispatch_pending.saturating_sub(1);
                    }
                }
                match result {
                    Ok(ack) => {
                        let agent_invoked = ack.get("agentInvoked").and_then(Value::as_bool);
                        if streaming_behavior.is_none() {
                            if agent_invoked == Some(false) {
                                if let Ok(mut live) = self.live.lock() {
                                    live.prompt_running = false;
                                    live.awaiting_agent_start = false;
                                }
                                self.emit(
                                    json!({ "type": "prompt_result", "agentInvoked": false }),
                                );
                                notify_running_change(false);
                            } else {
                                if let Ok(mut live) = self.live.lock() {
                                    live.awaiting_agent_start = true;
                                    live.awaiting_deadline_ms = now_ms() + 10_000.0;
                                }
                            }
                        }
                        Ok(Value::Null)
                    }
                    Err(error) => {
                        if let Ok(mut live) = self.live.lock() {
                            live.prompt_running = false;
                            live.streaming = false;
                            live.awaiting_agent_start = false;
                            live.streaming_message = None;
                            live.tool_events.clear();
                        }
                        notify_running_change(false);
                        if error.code.as_deref() == Some("rpc_timeout") {
                            self.destroy_and_wait().await;
                            return Err(RpcError::new(
                                "The OMP session stopped responding and was reset.",
                                Some("session_unresponsive"),
                            ));
                        }
                        Err(error)
                    }
                }
            }
            "steer" | "follow_up" => {
                // There is no live turn to steer while a `!!` shell command
                // runs, so a steer joins the follow-up queue like a prompt.
                if command_type == "steer"
                    && self
                        .live
                        .lock()
                        .map(|live| live.bash_running)
                        .unwrap_or(false)
                {
                    return self.queue_while_shell_running(&command).await;
                }
                let mut frame = Map::new();
                frame.insert("type".into(), Value::String(command_type.clone()));
                if let Some(message) = command.get("message") {
                    frame.insert("message".into(), message.clone());
                }
                if let Some(images) = command.get("images") {
                    frame.insert("images".into(), images.clone());
                }
                self.process()
                    .send_command(Value::Object(frame), None)
                    .await?;
                Ok(Value::Null)
            }
            "remove_queued_message" | "promote_queued_message" => {
                let result = self
                    .process()
                    .send_command(command.clone(), Some(GET_STATE_TIMEOUT))
                    .await?;
                Ok(result)
            }
            "abort" | "abort_and_restore_queue" => {
                if let Ok(mut live) = self.live.lock() {
                    live.response_observed = false;
                }
                let result = self.process().send_command(command.clone(), None).await?;
                if let Ok(mut live) = self.live.lock() {
                    live.prompt_running = false;
                    live.awaiting_agent_start = false;
                    live.streaming_message = None;
                    live.tool_events.clear();
                }
                notify_running_change(false);
                if command_type == "abort" {
                    Ok(Value::Null)
                } else {
                    Ok(result)
                }
            }
            "get_state" => match self
                .process()
                .send_command(json!({ "type": "get_state" }), Some(GET_STATE_TIMEOUT))
                .await
            {
                Ok(state) => Ok(self.build_web_state(state)),
                Err(error) => {
                    if error.code.as_deref() == Some("rpc_timeout") {
                        self.destroy_and_wait().await;
                        return Err(RpcError::new(
                            "The OMP session stopped responding and was reset.",
                            Some("session_unresponsive"),
                        ));
                    }
                    Err(error)
                }
            },
            "get_skill_diagnostics" => {
                let result = self
                    .process()
                    .send_command(
                        json!({ "type": "get_skill_diagnostics" }),
                        Some(GET_STATE_TIMEOUT),
                    )
                    .await?;
                Ok(result)
            }
            "set_skill_startup_diagnostics" => {
                let enabled = command
                    .get("enabled")
                    .and_then(Value::as_bool)
                    .ok_or_else(|| {
                        RpcError::new(
                            "enabled must be a boolean",
                            Some("invalid_skill_startup_diagnostics"),
                        )
                    })?;
                let result = self
                    .process()
                    .send_command(
                        json!({ "type": "set_skill_startup_diagnostics", "enabled": enabled }),
                        Some(GET_STATE_TIMEOUT),
                    )
                    .await?;
                Ok(result)
            }
            "set_model" => {
                let result = self.process().send_command(command.clone(), None).await?;
                let mut out = Map::new();
                out.insert(
                    "id".into(),
                    result.get("id").cloned().unwrap_or(Value::Null),
                );
                out.insert(
                    "provider".into(),
                    result.get("provider").cloned().unwrap_or(Value::Null),
                );
                self.invalidate_session_lists();
                Ok(Value::Object(out))
            }
            "set_fast_mode" => {
                let enabled = command.get("enabled").and_then(Value::as_bool) == Some(true);
                let result = self
                    .process()
                    .send_command(json!({ "type": "set_fast_mode", "enabled": enabled }), None)
                    .await?;
                let active = result
                    .get("active")
                    .and_then(Value::as_bool)
                    .unwrap_or(false);
                let effective = result
                    .get("enabled")
                    .and_then(Value::as_bool)
                    .unwrap_or(enabled);
                self.fast_mode.store(effective, Ordering::Relaxed);
                Ok(json!({ "enabled": effective, "active": active }))
            }
            "set_slow_mode" => {
                let enabled = command.get("enabled").and_then(Value::as_bool) == Some(true);
                let result = self
                    .process()
                    .send_command(json!({ "type": "set_slow_mode", "enabled": enabled }), None)
                    .await?;
                Ok(json!({
                    "enabled": result.get("enabled").and_then(Value::as_bool).unwrap_or(enabled),
                }))
            }
            "fork" => {
                if self.live.lock().map(|l| l.bash_running).unwrap_or(false) {
                    return Err(RpcError::plain(
                        "Cannot fork while a shell command is running",
                    ));
                }
                let entry_id = command.get("entryId").cloned().unwrap_or(Value::Null);
                let result = self
                    .process()
                    .send_command(json!({ "type": "branch", "entryId": entry_id }), None)
                    .await?;
                if result.get("cancelled").and_then(Value::as_bool) == Some(true) {
                    return Ok(json!({ "cancelled": true }));
                }
                let new_session_id = self.refresh_identity().await?;
                Ok(json!({
                    "cancelled": false,
                    "newSessionId": new_session_id,
                    "text": result.get("text").cloned().unwrap_or(Value::Null),
                }))
            }
            "new_session" | "switch_session" => {
                let result = self.process().send_command(command.clone(), None).await?;
                if result.get("cancelled").and_then(Value::as_bool) != Some(true) {
                    let new_session_id = self.refresh_identity().await?;
                    return Ok(json!({ "cancelled": false, "newSessionId": new_session_id }));
                }
                Ok(result)
            }
            "compact" => {
                let mut frame = Map::new();
                frame.insert("type".into(), Value::String("compact".into()));
                if let Some(instructions) = command.get("customInstructions") {
                    frame.insert("customInstructions".into(), instructions.clone());
                }
                if let Ok(mut live) = self.live.lock() {
                    live.compacting = true;
                    live.sequence += 1;
                }
                notify_running_change(false);
                let result = self
                    .process()
                    .send_command(Value::Object(frame), None)
                    .await;
                if let Ok(mut live) = self.live.lock() {
                    live.compacting = false;
                    live.sequence += 1;
                }
                self.invalidate_session_lists();
                result
            }
            "abort_compaction" => {
                let result = self
                    .process()
                    .send_command(json!({ "type": "abort" }), None)
                    .await?;
                notify_running_change(false);
                let _ = result;
                Ok(Value::Null)
            }
            "set_session_name" => {
                let name = command
                    .get("name")
                    .and_then(Value::as_str)
                    .map(str::trim)
                    .filter(|name| !name.is_empty())
                    .ok_or_else(|| RpcError::plain("Session name cannot be empty"))?
                    .to_string();
                self.process()
                    .send_command(json!({ "type": "set_session_name", "name": name }), None)
                    .await?;
                if let Ok(mut slot) = self.session_name.lock() {
                    *slot = Some(name);
                }
                self.invalidate_session_lists();
                Ok(Value::Null)
            }
            "get_session_stats" => {
                let stats = self
                    .process()
                    .send_command(json!({ "type": "get_session_stats" }), None)
                    .await?;
                let mut object = stats.as_object().cloned().unwrap_or_default();
                object.insert(
                    "sessionName".into(),
                    self.session_name
                        .lock()
                        .ok()
                        .and_then(|name| name.clone())
                        .map(Value::String)
                        .unwrap_or(Value::Null),
                );
                Ok(Value::Object(object))
            }
            "get_last_assistant_text" => {
                let data = self
                    .process()
                    .send_command(json!({ "type": "get_last_assistant_text" }), None)
                    .await?;
                Ok(json!({ "text": data.get("text").and_then(Value::as_str).unwrap_or("") }))
            }
            "get_commands" => {
                let data = self
                    .process()
                    .send_command(json!({ "type": "get_available_commands" }), None)
                    .await?;
                Ok(data)
            }
            "reload" => {
                self.restart().await?;
                Ok(json!({ "success": true }))
            }
            "extension_ui_response" => {
                let id = command.get("id").and_then(Value::as_str).unwrap_or("");
                let mut frame = command.clone();
                if let Some(object) = frame.as_object_mut() {
                    object.insert("type".into(), Value::String("extension_ui_response".into()));
                }
                let was_pending = self
                    .pending_ui
                    .lock()
                    .map(|mut pending| pending.remove(id).is_some())
                    .unwrap_or(false);
                self.process().send_frame(frame);
                if was_pending {
                    self.emit(json!({
                        "type": "extension_ui_request",
                        "id": format!("cancel:{}", id),
                        "method": "cancel",
                        "targetId": id,
                    }));
                }
                Ok(Value::Null)
            }
            "bash" => {
                if command.get("excludeFromContext").and_then(Value::as_bool) == Some(true) {
                    return Err(RpcError::new(
                        "Shell commands cannot be excluded from context over the omp RPC protocol",
                        Some("bash_exclude_unsupported"),
                    ));
                }
                if self.is_running() {
                    return Err(RpcError::plain(
                        "Cannot run a shell command while the session is busy",
                    ));
                }
                if let Ok(mut live) = self.live.lock() {
                    live.bash_running = true;
                }
                notify_running_change(false);
                let result = self
                    .process()
                    .send_command(
                        json!({ "type": "bash", "command": command.get("command").cloned().unwrap_or(Value::Null) }),
                        None,
                    )
                    .await;
                if let Ok(mut live) = self.live.lock() {
                    live.bash_running = false;
                }
                self.invalidate_session_lists();
                notify_running_change(false);
                result
            }
            "set_host_tools" => {
                let tools = command
                    .get("tools")
                    .and_then(Value::as_array)
                    .cloned()
                    .unwrap_or_default()
                    .into_iter()
                    .filter(|tool| {
                        tool.get("name")
                            .and_then(Value::as_str)
                            .map(|name| !name.is_empty())
                            .unwrap_or(false)
                    })
                    .collect::<Vec<_>>();
                if let Ok(mut names) = self.host_tool_names.lock() {
                    *names = tools
                        .iter()
                        .filter_map(|tool| {
                            tool.get("name")
                                .and_then(Value::as_str)
                                .map(|s| s.to_string())
                        })
                        .collect();
                }
                self.process()
                    .send_command(json!({ "type": "set_host_tools", "tools": tools }), None)
                    .await?;
                Ok(Value::Null)
            }
            "host_tool_result" => {
                if let Some(id) = command.get("id").and_then(Value::as_str) {
                    if let Ok(mut pending) = self.pending_host_tools.lock() {
                        pending.remove(id);
                    }
                }
                self.process().send_frame(command.clone());
                Ok(Value::Null)
            }
            "set_host_uri_schemes" => {
                let schemes = command
                    .get("schemes")
                    .and_then(Value::as_array)
                    .cloned()
                    .unwrap_or_default();
                if let Ok(mut map) = self.host_uri_schemes.lock() {
                    map.clear();
                    for entry in &schemes {
                        if let Some(scheme) = entry.get("scheme").and_then(Value::as_str) {
                            if !scheme.is_empty() {
                                map.insert(
                                    scheme.to_string(),
                                    entry.get("writable").and_then(Value::as_bool) == Some(true),
                                );
                            }
                        }
                    }
                }
                self.process()
                    .send_command(
                        json!({ "type": "set_host_uri_schemes", "schemes": schemes }),
                        None,
                    )
                    .await?;
                Ok(Value::Null)
            }
            "host_uri_result" => {
                if let Some(id) = command.get("id").and_then(Value::as_str) {
                    if let Ok(mut pending) = self.pending_host_uris.lock() {
                        pending.remove(id);
                    }
                }
                self.process().send_frame(command.clone());
                Ok(Value::Null)
            }
            other => {
                if is_passthrough_command(other) {
                    if other == "abort_and_prompt" {
                        if let Ok(mut live) = self.live.lock() {
                            live.response_observed = false;
                            live.sequence += 1;
                        }
                    }
                    let timeout = if other == "predict_word" {
                        Some(Duration::from_secs(125))
                    } else {
                        None
                    };
                    let result = self
                        .process()
                        .send_command(command.clone(), timeout)
                        .await?;
                    if other == "set_thinking_level" {
                        self.invalidate_session_lists();
                    }
                    return Ok(result);
                }
                if let Some(message) = unsupported_command_message(other) {
                    return Err(RpcError::new(message, Some("unsupported")));
                }
                Err(RpcError::plain(format!("Unsupported command: {}", other)))
            }
        }
    }

    /// Forward a prompt/steer as omp's `follow_up` while the session's own
    /// shell command owns the child. The queue stays omp-owned, and the reply
    /// tells the client the message was queued rather than steered.
    async fn queue_while_shell_running(&self, command: &Value) -> Result<Value, RpcError> {
        let mut frame = Map::new();
        frame.insert("type".into(), Value::String("follow_up".into()));
        if let Some(message) = command.get("message") {
            frame.insert("message".into(), message.clone());
        }
        if let Some(images) = command.get("images").and_then(Value::as_array) {
            if !images.is_empty() {
                frame.insert("images".into(), Value::Array(images.clone()));
            }
        }
        self.process()
            .send_command(Value::Object(frame), None)
            .await?;
        Ok(json!({ "queued": true, "queue": "followUp", "reason": "shellRunning" }))
    }

    async fn refresh_identity(&self) -> Result<String, RpcError> {
        let state = self.get_state_with_timeout().await?;
        let old_id = self.session_id();
        self.apply_state(&state);
        let new_id = self.session_id();
        if !old_id.is_empty() && old_id != new_id {
            rebind_registry_key(&old_id, &new_id, self);
        }
        self.invalidate_session_lists();
        Ok(new_id)
    }

    async fn restart(&self) -> Result<(), RpcError> {
        if self.restarting.swap(true, Ordering::SeqCst) {
            return Err(RpcError::new(
                "This session is restarting — retry in a moment.",
                Some("session_restarting"),
            ));
        }
        let result = self.restart_inner().await;
        self.restarting.store(false, Ordering::SeqCst);
        result
    }

    async fn restart_inner(&self) -> Result<(), RpcError> {
        let session_file = self.session_file();
        let resumable = !session_file.is_empty() && std::path::Path::new(&session_file).exists();
        let launch_config = crate::omp::projects::launch_config_for_cwd(&self.state.cfg, &self.cwd);
        let extra_args = build_session_spawn_args(
            if resumable { &session_file } else { "" },
            None,
            self.advisor_spawned,
            launch_config.as_ref(),
        );
        let env = crate::omp::settings::agent_env_overrides(&self.state.cfg);
        let old = self.process();
        if let Ok(mut live) = self.live.lock() {
            live.streaming = false;
            live.prompt_running = false;
            live.compacting = false;
            live.streaming_message = None;
            live.tool_events.clear();
            *live = LiveState::default();
        }
        if let Ok(mut statuses) = self.extension_statuses.lock() {
            statuses.clear();
        }
        if let Ok(mut widgets) = self.extension_widgets.lock() {
            widgets.clear();
        }
        let _ = self
            .stream_id
            .lock()
            .map(|mut id| *id = uuid::Uuid::new_v4().to_string());
        old.dispose(Duration::from_secs(5)).await;
        let bin = self.state.cfg.omp_bin_string();
        let process = RpcProcess::spawn(&bin, &self.cwd, &extra_args, &env)?;
        *self.process.write().unwrap() = process.clone();
        self.exit_emitted.store(false, Ordering::SeqCst);
        self.alive.store(true, Ordering::SeqCst);
        self.handshaking.store(true, Ordering::SeqCst);
        if let Some(session) = self.clone_arc() {
            session.attach_process(&process);
        }
        let handshake = async {
            let ready = process.wait_ready(READY_TIMEOUT).await?;
            process.negotiate_protocol(&ready).await?;
            let _ = process
                .send_command(
                    json!({ "type": "set_subagent_subscription", "level": "events" }),
                    None,
                )
                .await;
            let _ = process
                .send_command(
                    json!({ "type": "set_ask_dialog", "enabled": true }),
                    Some(GET_STATE_TIMEOUT),
                )
                .await;
            let state = process
                .send_command(json!({ "type": "get_state" }), Some(GET_STATE_TIMEOUT))
                .await?;
            self.apply_state(&state);
            Ok::<(), RpcError>(())
        }
        .await;
        self.handshaking.store(false, Ordering::SeqCst);
        if let Err(error) = handshake {
            // The replacement never became usable: leave no dead wrapper
            // routable, and let the next request spawn a fresh child.
            process.dispose(Duration::from_secs(1)).await;
            self.alive.store(false, Ordering::SeqCst);
            remove_from_registry(self);
            notify_running_change(true);
            return Err(error);
        }
        if !resumable
            && !self.session_file().is_empty()
            && std::path::Path::new(&self.session_file()).exists()
        {
            let _ = process
                .send_command(json!({ "type": "new_session" }), None)
                .await;
            if let Ok(state) = process
                .send_command(json!({ "type": "get_state" }), Some(GET_STATE_TIMEOUT))
                .await
            {
                self.apply_state(&state);
            }
        }
        notify_running_change(true);
        Ok(())
    }

    /// Subscribe the session to a fresh child's frames and exit signal.
    fn attach_process(self: &Arc<Self>, process: &Arc<RpcProcess>) {
        let session = self.clone();
        let mut frames = process.subscribe();
        let session_for_frames = session.clone();
        tokio::spawn(async move {
            while let Some(frame) = frames.recv().await {
                if frame.get("type").and_then(Value::as_str) == Some("__process_exit") {
                    continue;
                }
                session_for_frames.handle_frame(frame);
            }
        });
        let mut exit_rx = process.exit_signal();
        tokio::spawn(async move {
            loop {
                if exit_rx.borrow().is_some() {
                    break;
                }
                if exit_rx.changed().await.is_err() {
                    break;
                }
            }
            if let Some(exit) = exit_rx.borrow().clone() {
                session.handle_process_exit(exit);
            }
        });
    }

    fn clone_arc(&self) -> Option<Arc<Self>> {
        REGISTRY.lock().ok().and_then(|registry| {
            registry
                .values()
                .find(|session| std::ptr::eq(session.as_ref(), self))
                .cloned()
        })
    }

    pub async fn destroy_and_wait(&self) {
        // Concurrent callers (delete + reaper + route) must all wait for the
        // dispose; the second one that enters after it finished returns at once.
        let _guard = self.destroy_lock.lock().await;
        if !self.alive.swap(false, Ordering::SeqCst) {
            return;
        }
        self.handshaking.store(false, Ordering::SeqCst);
        if let Ok(mut live) = self.live.lock() {
            *live = LiveState::default();
        }
        let process = self.process();
        process.dispose(Duration::from_secs(5)).await;
        self.reject_pending_host_tools(
            "The session was closed while the agent was waiting for this host tool",
        );
        self.reject_pending_host_uris(
            "The session was closed while the agent was waiting for this URI request",
        );
        remove_from_registry(self);
        if let Ok(mut listeners) = self.listeners.lock() {
            listeners.clear();
        }
        notify_running_change(false);
    }

    fn handle_process_exit(&self, exit: ProcessExit) {
        if !self.is_alive() || self.exit_emitted.swap(true, Ordering::SeqCst) {
            return;
        }
        let detail = exit
            .stderr_tail
            .trim()
            .lines()
            .last()
            .unwrap_or("")
            .chars()
            .rev()
            .take(500)
            .collect::<String>()
            .chars()
            .rev()
            .collect::<String>();
        let status = match &exit.signal {
            Some(signal) => format!("signal {}", signal),
            None => format!(
                "code {}",
                exit.code
                    .map(|c| c.to_string())
                    .unwrap_or_else(|| "null".into())
            ),
        };
        let was_running = self
            .live
            .lock()
            .map(|live| live.streaming || live.prompt_running)
            .unwrap_or(false);
        if was_running {
            self.record_notification("error", Some(&format!("Process exited ({})", status)));
        }
        let id = self.session_id();
        if !id.is_empty() {
            if let Ok(mut exited) = EXITED.lock() {
                exited.insert(
                    id.clone(),
                    json!({
                        "id": id,
                        "cwd": self.cwd,
                        "at": now_ms(),
                        "code": exit.code,
                        "signal": exit.signal,
                        "detail": detail,
                    }),
                );
            }
        }
        self.emit(json!({
            "type": "notice",
            "level": "error",
            "message": format!(
                "The omp process for this session exited unexpectedly ({}){}",
                status,
                if detail.is_empty() { ".".to_string() } else { format!(": {}", detail) }
            ),
        }));
        let was_running = self
            .live
            .lock()
            .map(|live| live.streaming || live.prompt_running)
            .unwrap_or(false);
        if was_running {
            self.emit(json!({ "type": "agent_end", "isTerminal": true, "messages": [] }));
        }
        self.alive.store(false, Ordering::SeqCst);
        remove_from_registry(self);
        notify_running_change(true);
    }
}

fn title_from_result(result: &Value) -> Option<String> {
    let value = result.as_str().map(|s| s.to_string()).or_else(|| {
        ["title", "name", "sessionName"].iter().find_map(|key| {
            result
                .get(*key)
                .and_then(Value::as_str)
                .map(|s| s.to_string())
        })
    })?;
    let trimmed = value.trim();
    if trimmed.is_empty() {
        None
    } else {
        Some(trimmed.chars().take(200).collect())
    }
}

/// Merge a tool-execution update into its start frame, keeping earlier fields
/// and letting the newest phase win (matching the reference spread merge).
fn merge_event(existing: &mut Value, incoming: &Value) {
    match (existing.as_object_mut(), incoming.as_object()) {
        (Some(target), Some(source)) => {
            for (key, value) in source {
                target.insert(key.clone(), value.clone());
            }
            if let Some(kind) = source.get("type") {
                target.insert("type".into(), kind.clone());
            }
            if let Some(call_id) = source.get("toolCallId") {
                target.insert("toolCallId".into(), call_id.clone());
            }
        }
        _ => *existing = incoming.clone(),
    }
}

fn has_visible_assistant_content(message: &Value) -> bool {
    if message.get("role").and_then(Value::as_str) != Some("assistant") {
        return false;
    }
    match message.get("content") {
        Some(Value::String(text)) => !text.trim().is_empty(),
        Some(Value::Array(blocks)) => {
            blocks
                .iter()
                .any(|block| match block.get("type").and_then(Value::as_str) {
                    Some("text") => block
                        .get("text")
                        .and_then(Value::as_str)
                        .map(|text| !text.trim().is_empty())
                        .unwrap_or(false),
                    Some("image") => true,
                    _ => false,
                })
        }
        _ => false,
    }
}

fn is_passthrough_command(command: &str) -> bool {
    matches!(
        command,
        "abort"
            | "abort_and_prompt"
            | "set_thinking_level"
            | "cycle_thinking_level"
            | "cycle_model"
            | "get_available_models"
            | "set_auto_compaction"
            | "set_auto_retry"
            | "abort_retry"
            | "abort_bash"
            | "set_todos"
            | "set_steering_mode"
            | "set_follow_up_mode"
            | "set_interrupt_mode"
            | "get_branch_messages"
            | "get_messages"
            | "get_messages_page"
            | "export_html"
            | "handoff"
            | "get_subagents"
            | "get_subagent_messages"
            | "set_subagent_subscription"
            | "get_login_providers"
            | "login"
            | "predict_word"
            | "predict_word_feedback"
            | "btw"
            | "btw_cancel"
            | "get_btw_history"
    )
}

fn unsupported_command_message(command: &str) -> Option<&'static str> {
    match command {
        "navigate_tree" => Some("Branch navigation is not supported over the omp RPC protocol"),
        "clear_queue" => Some("Recalling queued messages is not supported over the omp RPC protocol"),
        "get_tools" => Some("Per-session tool listing is not supported over the omp RPC protocol"),
        "set_tools" => Some("Changing tools on a running session is not supported over the omp RPC protocol; tool presets apply to new sessions"),
        "extension_ui_input" => Some("Extension custom UI is not supported over the omp RPC protocol"),
        _ => None,
    }
}

/// Extra CLI args for `omp --mode rpc-ui`.
pub fn build_session_spawn_args(
    session_file: &str,
    tool_names: Option<&[String]>,
    advisor: bool,
    launch_config: Option<&Value>,
) -> Vec<String> {
    let mut args = Vec::new();
    if !session_file.is_empty() {
        args.push("--resume".into());
        args.push(session_file.into());
    } else if let Some(tool_names) = tool_names {
        let preset_key = tool_names
            .iter()
            .map(|name| name.to_ascii_lowercase())
            .collect::<Vec<_>>()
            .into_iter()
            .collect::<std::collections::BTreeSet<_>>()
            .into_iter()
            .collect::<Vec<_>>()
            .join(",");
        let full_key = {
            let mut names = PRESET_FULL
                .iter()
                .map(|name| name.to_ascii_lowercase())
                .collect::<Vec<_>>();
            names.sort();
            names.join(",")
        };
        if tool_names.is_empty() {
            args.push("--no-tools".into());
        } else if preset_key == full_key {
            // "Full" means everything: leave omp's complete default toolset
            // intact instead of restricting it to the smaller preset list.
        } else {
            let mapped: Vec<String> = tool_names
                .iter()
                .filter_map(|name| {
                    let lower = name.to_ascii_lowercase();
                    if lower == "ls" {
                        return None;
                    }
                    Some(match lower.as_str() {
                        "find" => "glob".to_string(),
                        "search" => "grep".to_string(),
                        _ => lower,
                    })
                })
                .collect();
            if !mapped.is_empty() {
                args.push("--tools".into());
                args.push(mapped.join(","));
            }
        }
    }
    let launch_advisor = launch_config
        .and_then(|config| config.get("advisor"))
        .and_then(Value::as_bool)
        == Some(true);
    if advisor || launch_advisor {
        args.push("--advisor".into());
    }
    // Defense in depth: the registry is hand-editable, so re-strip reserved
    // args and dash-leading profiles at the spawn boundary.
    if let Some(config) = launch_config {
        if let Some(profile) = config.get("profile").and_then(Value::as_str) {
            if !profile.is_empty() && !profile.starts_with('-') {
                args.push("--profile".into());
                args.push(profile.to_string());
            }
        }
        if let Some(extra) = config.get("extraArgs").and_then(Value::as_array) {
            for arg in extra {
                if let Some(arg) = arg.as_str() {
                    if !arg.is_empty() && !crate::omp::projects::is_reserved_launch_arg(arg) {
                        args.push(arg.to_string());
                    }
                }
            }
        }
    }
    args
}

// ============================================================================
// Session registry + broadcasters
// ============================================================================

static REGISTRY: LazyLock<Mutex<HashMap<String, Arc<AgentSession>>>> =
    LazyLock::new(|| Mutex::new(HashMap::new()));
static START_LOCKS: LazyLock<Mutex<HashMap<String, Arc<tokio::sync::Mutex<()>>>>> =
    LazyLock::new(|| Mutex::new(HashMap::new()));
static EXITED: LazyLock<Mutex<HashMap<String, Value>>> =
    LazyLock::new(|| Mutex::new(HashMap::new()));
static RUNNING_TX: LazyLock<broadcast::Sender<Value>> = LazyLock::new(|| broadcast::channel(512).0);
static HOST_TOOL_TX: LazyLock<broadcast::Sender<Value>> =
    LazyLock::new(|| broadcast::channel(512).0);
static LAST_RUNNING: LazyLock<Mutex<String>> =
    LazyLock::new(|| Mutex::new(String::from("[[],[]]")));

fn remove_from_registry(session: &AgentSession) {
    if let Ok(mut registry) = REGISTRY.lock() {
        registry.retain(|_, candidate| !std::ptr::eq(candidate.as_ref(), session));
    }
}

fn rebind_registry_key(old_id: &str, new_id: &str, session: &AgentSession) {
    if old_id == new_id {
        return;
    }
    if let Ok(mut registry) = REGISTRY.lock() {
        let owned = registry
            .get(old_id)
            .filter(|candidate| std::ptr::eq(candidate.as_ref(), session))
            .cloned();
        if let Some(arc) = owned {
            // The conversation moved (branch/new_session/switch_session): the
            // old id must not stay routable, or a stale tab would keep talking
            // to a session that now belongs to a different branch.
            registry.remove(old_id);
            registry.insert(new_id.to_string(), arc);
        }
    }
}

static REAPER_STARTED: AtomicBool = AtomicBool::new(false);

fn ensure_session_reaper() {
    if REAPER_STARTED.swap(true, Ordering::SeqCst) {
        return;
    }
    tokio::spawn(async move {
        loop {
            tokio::time::sleep(REAPER_INTERVAL).await;
            reap_registered_sessions().await;
        }
    });
}

/// One registry-visible session as the timeout reaper sees it.
#[derive(Debug, Clone, Copy)]
struct ReapCandidate {
    /// Unique `Arc` identity: several registry keys can alias one session.
    pointer: usize,
    /// A disconnect/idle timeout expired and nothing is in flight.
    timed_out: bool,
    /// `last_activity_ms`; the freshest session wins the one-session reprieve.
    last_activity_ms: i64,
}

/// Session pointers the timeout reaper may destroy.
///
/// The service must always keep at least one live session, so when every live
/// session has timed out only the most recently active one survives. Sessions
/// still inside their timeout window already satisfy that floor, so every
/// timed-out session may go.
fn select_reap_targets(candidates: &[ReapCandidate]) -> Vec<usize> {
    let mut targets: Vec<&ReapCandidate> = candidates.iter().filter(|c| c.timed_out).collect();
    if candidates.len() == targets.len() {
        // Every live session is stale: sort ascending by activity and let the
        // tail — the most recently used session — keep running.
        targets.sort_by_key(|candidate| candidate.last_activity_ms);
        targets.pop();
    }
    targets
        .into_iter()
        .map(|candidate| candidate.pointer)
        .collect()
}

/// Destroy sessions nobody is watching: 120s after the last tab left, or after
/// 10 minutes without use. Mirrors `ompweb/lib/rpc-manager.ts`, except that the
/// last live session is never reaped so a returning tab finds a warm process
/// instead of paying a cold start.
async fn reap_registered_sessions() {
    let sessions: Vec<Arc<AgentSession>> = match REGISTRY.lock() {
        Ok(registry) => {
            let mut seen: HashSet<usize> = HashSet::new();
            registry
                .values()
                .filter(|session| seen.insert(Arc::as_ptr(session) as usize))
                .cloned()
                .collect()
        }
        Err(_) => return,
    };
    let now = now_ms() as i64;
    let candidates: Vec<ReapCandidate> = sessions
        .iter()
        .filter(|session| session.is_alive())
        .map(|session| ReapCandidate {
            pointer: Arc::as_ptr(session) as usize,
            timed_out: session.timed_out(now),
            last_activity_ms: session.last_activity_ms(),
        })
        .collect();
    let doomed: HashSet<usize> = select_reap_targets(&candidates).into_iter().collect();
    for session in sessions {
        if doomed.contains(&(Arc::as_ptr(&session) as usize)) {
            session.destroy_and_wait().await;
        }
    }
}

pub fn get_session(id: &str) -> Option<Arc<AgentSession>> {
    REGISTRY.lock().ok()?.get(id).cloned()
}

pub fn get_exited_session(id: &str) -> Option<Value> {
    EXITED.lock().ok()?.get(id).cloned()
}

pub fn clear_exited_session(id: &str) -> bool {
    let cleared = EXITED
        .lock()
        .map(|mut exited| exited.remove(id).is_some())
        .unwrap_or(false);
    if cleared {
        notify_running_change(false);
    }
    cleared
}

pub fn running_sessions() -> Vec<Value> {
    let registry = match REGISTRY.lock() {
        Ok(registry) => registry,
        Err(_) => return Vec::new(),
    };
    let mut seen = HashSet::new();
    let mut sessions = Vec::new();
    for (key, session) in registry.iter() {
        if !session.is_running() {
            continue;
        }
        let id = if session.session_id().is_empty() {
            key.clone()
        } else {
            session.session_id()
        };
        if seen.insert(id.clone()) {
            sessions.push(json!({ "id": id, "cwd": session.cwd }));
        }
    }
    sessions
}

pub fn running_session_ids() -> Vec<String> {
    running_sessions()
        .into_iter()
        .filter_map(|session| {
            session
                .get("id")
                .and_then(Value::as_str)
                .map(|s| s.to_string())
        })
        .collect()
}

pub fn exited_sessions() -> Vec<Value> {
    EXITED
        .lock()
        .map(|exited| exited.values().cloned().collect())
        .unwrap_or_default()
}

pub fn notify_running_change(refresh_session_list: bool) {
    let running = running_sessions();
    let exited = exited_sessions();
    let mut ids: Vec<String> = running
        .iter()
        .filter_map(|session| {
            session
                .get("id")
                .and_then(Value::as_str)
                .map(|s| s.to_string())
        })
        .collect();
    ids.sort();
    let snapshot = format!(
        "{}{}",
        serde_json::to_string(&running).unwrap_or_default(),
        serde_json::to_string(&exited).unwrap_or_default()
    );
    if let Ok(mut last) = LAST_RUNNING.lock() {
        if *last == snapshot && !refresh_session_list {
            return;
        }
        *last = snapshot;
    }
    let _ = RUNNING_TX.send(json!({
        "type": "running",
        "runningSessionIds": ids,
        "runningSessions": running,
        "exitedSessions": exited,
        "refreshSessionList": refresh_session_list,
    }));
}

pub fn notify_sessions_changed(session_ids: Vec<String>) {
    let _ = RUNNING_TX.send(json!({
        "type": "sessions-changed",
        "sessionIds": session_ids,
        "refreshSessionList": true,
    }));
}

pub fn subscribe_running() -> broadcast::Receiver<Value> {
    RUNNING_TX.subscribe()
}

pub fn subscribe_host_tools() -> broadcast::Receiver<Value> {
    HOST_TOOL_TX.subscribe()
}

pub fn publish_host_tool(call: Value) {
    let _ = HOST_TOOL_TX.send(call);
}

/// Resolve a spawn cwd (falls back to the server cwd, then $HOME).
pub fn resolve_spawn_cwd(recorded: Option<&str>) -> String {
    if let Some(recorded) = recorded {
        if std::path::Path::new(recorded).exists() {
            return recorded.to_string();
        }
    }
    if let Ok(cwd) = std::env::current_dir() {
        if cwd.exists() {
            return cwd.to_string_lossy().into_owned();
        }
    }
    std::env::var("HOME").unwrap_or_else(|_| "/".into())
}

/// Handshake shared by the initial spawn and restart: wait for ready,
/// negotiate the protocol, configure subscriptions, and adopt the child state.
async fn perform_handshake(
    session: &AgentSession,
    process: &Arc<RpcProcess>,
    session_file: &str,
) -> Result<(), RpcError> {
    session.handshaking.store(true, Ordering::SeqCst);
    let resume_requested = !session_file.is_empty() && std::path::Path::new(session_file).exists();
    let result = async {
        let ready = process.wait_ready(READY_TIMEOUT).await?;
        process.negotiate_protocol(&ready).await?;
        let _ = process
            .send_command(
                json!({ "type": "set_subagent_subscription", "level": "events" }),
                None,
            )
            .await;
        let _ = process
            .send_command(
                json!({ "type": "set_ask_dialog", "enabled": true }),
                Some(GET_STATE_TIMEOUT),
            )
            .await;
        let state_value = process
            .send_command(json!({ "type": "get_state" }), Some(GET_STATE_TIMEOUT))
            .await?;
        session.apply_state(&state_value);
        // A fresh spawn must never land in an existing conversation: a child
        // reporting a session file that already exists resumed something.
        if !resume_requested {
            let reported = session.session_file();
            if !reported.is_empty() && std::path::Path::new(&reported).exists() {
                let _ = process
                    .send_command(json!({ "type": "new_session" }), None)
                    .await;
                if let Ok(state_value) = process
                    .send_command(json!({ "type": "get_state" }), Some(GET_STATE_TIMEOUT))
                    .await
                {
                    session.apply_state(&state_value);
                }
            }
        }
        Ok::<(), RpcError>(())
    }
    .await;
    session.handshaking.store(false, Ordering::SeqCst);
    result
}

/// Drop a start lock once no other caller is waiting on it.
fn release_start_lock(key: &str, lock: &Arc<tokio::sync::Mutex<()>>) {
    if let Ok(mut locks) = START_LOCKS.lock() {
        let removable = locks
            .get(key)
            .map(|entry| Arc::ptr_eq(entry, lock) && Arc::strong_count(entry) <= 2)
            .unwrap_or(false);
        if removable {
            locks.remove(key);
        }
    }
}

/// Get or create the RPC process for a session id.
pub async fn start_rpc_session(
    state: SharedState,
    key: &str,
    session_file: &str,
    cwd: &str,
    tool_names: Option<&[String]>,
    advisor: bool,
    recorded_cwd: Option<String>,
) -> Result<(Arc<AgentSession>, String), RpcError> {
    let launch_config = crate::omp::projects::launch_config_for_cwd(&state.cfg, cwd);
    // Workspace launch configs can force --advisor; the wrapper identity must
    // compare the effective value or a forced child respawns on every request.
    let advisor = advisor
        || launch_config
            .as_ref()
            .and_then(|config| config.get("advisor"))
            .and_then(Value::as_bool)
            == Some(true);
    if let Some(existing) = get_session(key) {
        if existing.is_alive() {
            if existing.advisor_spawned == advisor || existing.is_running() {
                return Ok((existing.clone(), key.to_string()));
            }
            existing.destroy_and_wait().await;
        }
    }
    if !session_file.is_empty() {
        let target = std::path::Path::new(session_file);
        let alias = REGISTRY.lock().ok().and_then(|registry| {
            registry
                .values()
                .find(|session| {
                    session.is_alive()
                        && !session.session_file().is_empty()
                        && same_path(std::path::Path::new(&session.session_file()), target)
                })
                .cloned()
        });
        if let Some(existing) = alias {
            if let Ok(mut registry) = REGISTRY.lock() {
                registry.insert(key.to_string(), existing.clone());
            }
            return Ok((existing, key.to_string()));
        }
    }

    let lock = {
        let mut locks = START_LOCKS
            .lock()
            .map_err(|_| RpcError::plain("start lock poisoned"))?;
        locks
            .entry(key.to_string())
            .or_insert_with(|| Arc::new(tokio::sync::Mutex::new(())))
            .clone()
    };
    let result = {
        let _guard = lock.lock().await;

        if let Some(existing) = get_session(key) {
            if existing.is_alive() {
                return Ok((existing.clone(), existing.session_id()));
            }
        }

        let bin = state.cfg.omp_bin_string();
        let extra_args =
            build_session_spawn_args(session_file, tool_names, advisor, launch_config.as_ref());
        let env = crate::omp::settings::agent_env_overrides(&state.cfg);
        let process = RpcProcess::spawn(&bin, cwd, &extra_args, &env)?;
        let session = AgentSession::new(state, process.clone(), cwd, recorded_cwd, advisor);
        let initial_id = if session_file.is_empty() {
            String::new()
        } else {
            key.to_string()
        };
        session.set_session_identity(&initial_id, session_file);
        session.attach_process(&process);

        if let Err(error) = perform_handshake(&session, &process, session_file).await {
            session.destroy_and_wait().await;
            return Err(error);
        }

        let real_id = session.session_id();
        let real_id = if real_id.is_empty() {
            key.to_string()
        } else {
            real_id
        };
        if let Ok(mut registry) = REGISTRY.lock() {
            registry.insert(real_id.clone(), session.clone());
            if real_id != key {
                registry.insert(key.to_string(), session.clone());
            }
        }
        clear_exited_session(key);
        clear_exited_session(&real_id);
        notify_running_change(true);
        Ok((session, real_id))
    };
    release_start_lock(key, &lock);
    result
}

/// Start the most recently active session right after boot, so the first tab
/// attaches to a warm `omp` child instead of paying a cold start. The reaper's
/// one-session floor keeps that process alive afterwards.
///
/// Returns the started session id, or `None` when there is nothing to warm
/// (no session, no session whose cwd still exists) or the spawn failed — a
/// failed warmup must never take the server down.
pub async fn warm_last_session(state: SharedState) -> Option<String> {
    if REGISTRY
        .lock()
        .map(|registry| !registry.is_empty())
        .unwrap_or(true)
    {
        return None;
    }
    let latest = crate::omp::session_reader::latest_launchable_session(&state.cfg)?;
    state.allow_root(std::path::Path::new(&latest.cwd));
    match start_rpc_session(
        state,
        &latest.id,
        &latest.path,
        &latest.cwd,
        None,
        false,
        Some(latest.cwd.clone()),
    )
    .await
    {
        Ok((_, real_id)) => {
            eprintln!("[aidesk] prewarmed session {}", real_id);
            Some(real_id)
        }
        Err(error) => {
            eprintln!(
                "[aidesk] could not prewarm session {}: {}",
                latest.id, error.message
            );
            None
        }
    }
}

/// Command error body shared by the agent routes.
pub fn command_error_response(error: RpcError) -> (u16, Value) {
    (
        400,
        json!({ "error": error.message, "code": error.code.unwrap_or_else(|| "rpc_command_failed".into()) }),
    )
}

// ============================================================================
// Shared short-lived utility RPC process (registry/auth/model queries)
// ============================================================================

static UTILITY: LazyLock<tokio::sync::Mutex<Option<Arc<RpcProcess>>>> =
    LazyLock::new(|| tokio::sync::Mutex::new(None));
static UTILITY_LAST_USED: AtomicI64 = AtomicI64::new(0);
static UTILITY_KILLER_RUNNING: AtomicBool = AtomicBool::new(false);
const UTILITY_IDLE_KILL_MS: i64 = 300_000;

fn start_utility_idle_killer() {
    if UTILITY_KILLER_RUNNING.swap(true, Ordering::SeqCst) {
        return;
    }
    tokio::spawn(async move {
        loop {
            tokio::time::sleep(Duration::from_secs(30)).await;
            let idle =
                now_ms() as i64 - UTILITY_LAST_USED.load(Ordering::Relaxed) > UTILITY_IDLE_KILL_MS;
            if !idle {
                continue;
            }
            let mut guard = UTILITY.lock().await;
            if let Some(process) = guard.take() {
                process.dispose(Duration::from_secs(5)).await;
            }
            UTILITY_KILLER_RUNNING.store(false, Ordering::SeqCst);
            break;
        }
    });
}

/// Run one command on the shared utility process (lazy start, serialized,
/// idle-killed). These sessions use `--no-session` and are never user sessions.
pub async fn run_utility_command(
    state: &SharedState,
    command: Value,
    timeout: Duration,
) -> Result<Value, RpcError> {
    let mut guard = UTILITY.lock().await;
    let alive = guard
        .as_ref()
        .map(|process| process.is_alive())
        .unwrap_or(false);
    if !alive {
        if let Some(process) = guard.take() {
            process.dispose(Duration::from_millis(0)).await;
        }
        let bin = state.cfg.omp_bin_string();
        let cwd = state.cfg.home.to_string_lossy().into_owned();
        let extra = ["--no-session", "--no-skills", "--no-lsp"]
            .iter()
            .map(|arg| arg.to_string())
            .collect::<Vec<_>>();
        let env = crate::omp::settings::agent_env_overrides(&state.cfg);
        let process = RpcProcess::spawn(&bin, &cwd, &extra, &env)?;
        match process.wait_ready(READY_TIMEOUT).await {
            Ok(ready) => {
                if let Err(error) = process.negotiate_protocol(&ready).await {
                    process.dispose(Duration::from_millis(0)).await;
                    return Err(error);
                }
            }
            Err(error) => {
                process.dispose(Duration::from_millis(0)).await;
                return Err(error);
            }
        }
        *guard = Some(process);
        start_utility_idle_killer();
    }
    let process = guard.as_ref().unwrap().clone();
    let result = process.send_command(command, Some(timeout)).await;
    UTILITY_LAST_USED.store(now_ms() as i64, Ordering::Relaxed);
    result
}

/// Tear down the utility process (after models.yml or config writes). Awaiting
/// this guarantees the old child exited before the next `get_available_models`.
pub async fn dispose_utility_rpc() {
    let mut guard = UTILITY.lock().await;
    if let Some(process) = guard.take() {
        process.dispose(Duration::from_secs(5)).await;
    }
}

/// Dispose every live session child and the utility process (server shutdown).
pub async fn shutdown_all() {
    let sessions: Vec<Arc<AgentSession>> = REGISTRY
        .lock()
        .map(|registry| registry.values().cloned().collect())
        .unwrap_or_default();
    let mut seen: Vec<usize> = Vec::new();
    for session in sessions {
        let pointer = Arc::as_ptr(&session) as usize;
        if seen.contains(&pointer) {
            continue;
        }
        seen.push(pointer);
        session.destroy_and_wait().await;
    }
    let mut guard = UTILITY.lock().await;
    if let Some(process) = guard.take() {
        process.dispose(Duration::from_secs(5)).await;
    }
}

pub fn mark_shutting_down() {
    if let Ok(registry) = REGISTRY.lock() {
        for session in registry.values() {
            session.alive.store(false, Ordering::SeqCst);
        }
    }
}

pub fn session_path_from_cwd(cwd: &str) -> String {
    let _ = path_key(std::path::Path::new(cwd));
    cwd.to_string()
}

pub fn session_file_exists(path: &str) -> bool {
    !path.is_empty() && std::path::Path::new(path).exists()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn spawn_args_resume_and_advisor() {
        let args = build_session_spawn_args("/tmp/s.jsonl", None, true, None);
        assert_eq!(args, vec!["--resume", "/tmp/s.jsonl", "--advisor"]);
    }

    #[test]
    fn spawn_args_translate_tool_presets() {
        let tools = vec![
            "find".to_string(),
            "search".to_string(),
            "ls".to_string(),
            "read".to_string(),
        ];
        let args = build_session_spawn_args("", Some(&tools), false, None);
        assert_eq!(args, vec!["--tools", "glob,grep,read"]);
        let empty: Vec<String> = Vec::new();
        assert_eq!(
            build_session_spawn_args("", Some(&empty), false, None),
            vec!["--no-tools"]
        );
        // The "full" preset must leave omp's complete default toolset alone.
        let full = PRESET_FULL
            .iter()
            .map(|name| name.to_string())
            .collect::<Vec<_>>();
        assert!(build_session_spawn_args("", Some(&full), false, None).is_empty());
    }

    #[test]
    fn spawn_args_apply_launch_config() {
        let config = json!({ "profile": "work", "advisor": true, "extraArgs": ["--yolo"] });
        let args = build_session_spawn_args("", None, false, Some(&config));
        assert_eq!(args, vec!["--advisor", "--profile", "work", "--yolo"]);
    }

    #[test]
    fn frame_decoder_reassembles_chunks() {
        let payload =
            json!({ "type": "event", "value": "x".repeat(MAX_RPC_FRAME_BYTES + 100) }).to_string();
        let bytes = payload.as_bytes();
        let chunk_size = RPC_CHUNK_PAYLOAD_BYTES;
        let count = (bytes.len() + chunk_size - 1) / chunk_size;
        let mut decoder = FrameDecoder::default();
        let mut last = None;
        for index in 0..count {
            let end = ((index + 1) * chunk_size).min(bytes.len());
            let part = &bytes[index * chunk_size..end];
            let chunk = json!({
                "type": "rpc_chunk",
                "chunkId": "c1",
                "index": index,
                "count": count,
                "byteLength": bytes.len(),
                "data": base64::engine::general_purpose::STANDARD.encode(part),
            });
            last = decoder.push(chunk).unwrap();
        }
        assert_eq!(
            last.unwrap()["value"].as_str().unwrap().len(),
            MAX_RPC_FRAME_BYTES + 100
        );
    }

    #[test]
    fn visibility_requires_real_content() {
        assert!(!has_visible_assistant_content(
            &json!({ "role": "assistant", "content": [] })
        ));
        assert!(has_visible_assistant_content(&json!({
            "role": "assistant",
            "content": [{ "type": "text", "text": "hi" }]
        })));
    }

    fn candidate(pointer: usize, timed_out: bool, last_activity_ms: i64) -> ReapCandidate {
        ReapCandidate {
            pointer,
            timed_out,
            last_activity_ms,
        }
    }

    #[test]
    fn reaper_keeps_the_last_session_past_both_timeouts() {
        // Disconnect (120s) and idle (600s) windows both elapsed: the service
        // must still keep one session running.
        let candidates = vec![candidate(7, true, 0)];
        assert!(select_reap_targets(&candidates).is_empty());
    }

    #[test]
    fn reaper_keeps_the_most_recently_active_of_several_timed_out_sessions() {
        let candidates = vec![
            candidate(1, true, 1_000),
            candidate(2, true, 3_000),
            candidate(3, true, 2_000),
        ];
        let mut reaped = select_reap_targets(&candidates);
        reaped.sort();
        assert_eq!(reaped, vec![1, 3]);
        assert!(!reaped.contains(&2), "the freshest session must survive");
    }

    #[test]
    fn reaper_reaps_every_timed_out_session_while_one_is_still_fresh() {
        // A session inside its timeout window already satisfies the floor, so
        // stale siblings are not spared.
        let candidates = vec![
            candidate(1, true, 1_000),
            candidate(2, true, 2_000),
            candidate(3, false, 3_000),
        ];
        let mut reaped = select_reap_targets(&candidates);
        reaped.sort();
        assert_eq!(reaped, vec![1, 2]);
    }

    #[test]
    fn reaper_skips_sessions_that_are_not_timed_out() {
        assert!(select_reap_targets(&[]).is_empty());
        assert!(select_reap_targets(&[candidate(1, false, 0), candidate(2, false, 10)]).is_empty());
    }
}
