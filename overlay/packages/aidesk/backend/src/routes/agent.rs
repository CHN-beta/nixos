//! `/api/agent/*` — live RPC sessions, SSE streams and bash-output serving.

use crate::omp::rpc;
use crate::omp::session_files;
use crate::omp::session_reader;
use crate::routes::{body_json, json_ok, query};
use crate::state::SharedState;
use crate::util::{coded_error, path_key};
use axum::extract::{Path as AxumPath, State};
use axum::http::{StatusCode, Uri};
use axum::response::{IntoResponse, Response};
use serde_json::{json, Map, Value};
use std::path::{Path, PathBuf};

const MAX_AGENT_COMMAND_REQUEST_BYTES: usize = 8 * 1024 * 1024;
const MAX_INLINE_BASH_OUTPUT_BYTES: u64 = 5 * 1024 * 1024;

fn command_error(error: rpc::RpcError) -> Response {
    crate::util::json_status(
        StatusCode::BAD_REQUEST,
        json!({ "error": error.message, "code": error.code.unwrap_or_else(|| "rpc_command_failed".into()) }),
    )
}

fn no_spawn_reply(command_type: &str) -> Option<Value> {
    match command_type {
        "predict_word" => Some(json!({ "suffix": Value::Null })),
        "predict_word_feedback" => Some(Value::Null),
        "get_btw_history" => Some(json!({ "records": [] })),
        "btw_cancel" => Some(json!({ "cancelled": false })),
        _ => None,
    }
}

fn is_live_only(command_type: &str) -> bool {
    matches!(
        command_type,
        "get_skill_diagnostics" | "set_skill_startup_diagnostics"
    )
}

// ============================================================================
// New session
// ============================================================================

pub async fn agent_new(
    State(state): State<SharedState>,
    request: axum::extract::Request,
) -> Response {
    let body = match body_json(request, MAX_AGENT_COMMAND_REQUEST_BYTES).await {
        Ok(body) => body,
        Err(response) => return response,
    };
    let cwd = body.get("cwd").and_then(Value::as_str).unwrap_or("");
    if cwd.is_empty() {
        return coded_error(StatusCode::BAD_REQUEST, "cwd is required", "cwd_required");
    }
    if !Path::new(cwd).exists() {
        return coded_error(
            StatusCode::BAD_REQUEST,
            &format!("Directory does not exist: {}", cwd),
            "directory_not_found",
        );
    }
    let Some(mut command) = body.as_object().cloned() else {
        return coded_error(
            StatusCode::BAD_REQUEST,
            "Invalid JSON request body",
            "invalid_json",
        );
    };
    let provider = command
        .get("provider")
        .and_then(Value::as_str)
        .map(|s| s.to_string());
    let model_id = command
        .get("modelId")
        .and_then(Value::as_str)
        .map(|s| s.to_string());
    let thinking_level = command
        .get("thinkingLevel")
        .and_then(Value::as_str)
        .map(|s| s.to_string());
    let advisor = command.get("advisor").and_then(Value::as_bool) == Some(true);
    let tool_names: Option<Vec<String>> =
        command
            .get("toolNames")
            .and_then(Value::as_array)
            .map(|items| {
                items
                    .iter()
                    .filter_map(Value::as_str)
                    .map(|s| s.to_string())
                    .collect()
            });
    for key in [
        "cwd",
        "provider",
        "modelId",
        "toolNames",
        "thinkingLevel",
        "advisor",
        "sessionId",
    ] {
        command.remove(key);
    }
    let Some(command_type) = command
        .get("type")
        .and_then(Value::as_str)
        .map(|s| s.to_string())
        .filter(|s| !s.trim().is_empty())
    else {
        return coded_error(
            StatusCode::BAD_REQUEST,
            "command type is required",
            "command_type_required",
        );
    };

    let temp_key = format!("__new__{}", uuid::Uuid::new_v4());
    let (session, real_session_id) = match rpc::start_rpc_session(
        state.clone(),
        &temp_key,
        "",
        cwd,
        tool_names.as_deref(),
        advisor,
        None,
    )
    .await
    {
        Ok(result) => result,
        Err(error) => return command_error(error),
    };
    state.allow_root(Path::new(cwd));
    rpc::notify_sessions_changed(vec![real_session_id.clone()]);

    let mut result = Ok(Value::Null);
    if let (Some(provider), Some(model_id)) = (provider, model_id) {
        result = session
            .send(json!({ "type": "set_model", "provider": provider, "modelId": model_id }))
            .await;
    }
    if result.is_ok() {
        if let Some(level) = thinking_level {
            result = session
                .send(json!({ "type": "set_thinking_level", "level": level }))
                .await;
        }
    }
    if result.is_ok() {
        if command_type == "ensure_session" {
            return json_ok(
                json!({ "success": true, "sessionId": real_session_id, "data": Value::Null }),
            );
        }
        result = session.send(Value::Object(command)).await;
    }
    match result {
        Ok(data) => json_ok(json!({ "success": true, "sessionId": real_session_id, "data": data })),
        Err(error) => {
            session.destroy_and_wait().await;
            command_error(error)
        }
    }
}

// ============================================================================
// Existing session
// ============================================================================

pub async fn agent_get(
    State(_state): State<SharedState>,
    AxumPath(id): AxumPath<String>,
) -> Response {
    let Some(session) = rpc::get_session(&id) else {
        return json_ok(json!({ "running": false }));
    };
    if !session.is_alive() {
        return json_ok(json!({ "running": false }));
    }
    match session.send(json!({ "type": "get_state" })).await {
        Ok(state) => json_ok(json!({ "running": true, "state": state })),
        Err(error) if error.code.as_deref() == Some("session_unresponsive") => {
            json_ok(json!({ "running": false, "recovered": true }))
        }
        Err(error) => command_error(error),
    }
}

pub async fn agent_post(
    State(state): State<SharedState>,
    AxumPath(id): AxumPath<String>,
    uri: Uri,
    request: axum::extract::Request,
) -> Response {
    let body = match body_json(request, MAX_AGENT_COMMAND_REQUEST_BYTES).await {
        Ok(body) => body,
        Err(response) => return response,
    };
    let Some(command_type) = body
        .get("type")
        .and_then(Value::as_str)
        .map(|s| s.to_string())
        .filter(|s| !s.trim().is_empty())
    else {
        return coded_error(
            StatusCode::BAD_REQUEST,
            "command type is required",
            "command_type_required",
        );
    };
    let query = query(&uri);
    let advisor = query.get("advisor") == Some("1");

    if let Some(existing) = rpc::get_session(&id) {
        if existing.is_alive() {
            if no_spawn_reply(&command_type).is_some()
                || is_live_only(&command_type)
                || existing.advisor_spawned == advisor
                || existing.is_running()
            {
                return match existing.send(body).await {
                    Ok(data) => json_ok(json!({ "success": true, "data": data })),
                    Err(error) => command_error(error),
                };
            }
            existing.destroy_and_wait().await;
        }
    }
    if let Some(reply) = no_spawn_reply(&command_type) {
        return json_ok(json!({ "success": true, "data": reply }));
    }
    if is_live_only(&command_type) {
        return coded_error(
            StatusCode::CONFLICT,
            "Skill diagnostics require a running session",
            "skill_diagnostics_unavailable",
        );
    }
    let Some(path) = session_reader::resolve_session_path(&state.cfg, &id) else {
        return crate::routes::session_not_found();
    };
    let header = session_files::read_session_header(&path);
    let recorded = header
        .as_ref()
        .and_then(|header| header.get("cwd"))
        .and_then(Value::as_str)
        .map(|s| s.to_string());
    let cwd = rpc::resolve_spawn_cwd(recorded.as_deref());
    let (session, _) = match rpc::start_rpc_session(
        state.clone(),
        &id,
        &path.to_string_lossy(),
        &cwd,
        None,
        advisor,
        recorded,
    )
    .await
    {
        Ok(result) => result,
        Err(error) => return command_error(error),
    };
    match session.send(body).await {
        Ok(data) => json_ok(json!({ "success": true, "data": data })),
        Err(error) => command_error(error),
    }
}

// ============================================================================
// SSE streams
// ============================================================================

pub async fn agent_events(
    State(_state): State<SharedState>,
    AxumPath(id): AxumPath<String>,
) -> Response {
    let Some(session) = rpc::get_session(&id).filter(|session| session.is_alive()) else {
        return Response::builder()
            .status(StatusCode::CONFLICT)
            .body(axum::body::Body::from("Session is not managed by AIDesk"))
            .unwrap_or_else(|_| StatusCode::CONFLICT.into_response());
    };
    let (listener_id, mut rx, cursor) = session.add_listener();
    let (sse, response) = crate::sse::channel(1024);
    // The cursor is captured before pending-UI replay allocates sequences, so
    // `connected` never jumps ahead of the frames that follow it.
    sse.data(&json!({ "type": "connected", "sessionId": id, "web": cursor }))
        .await;
    let session_for_task = session.clone();
    tokio::spawn(async move {
        let mut heartbeat = tokio::time::interval_at(
            tokio::time::Instant::now() + std::time::Duration::from_secs(30),
            std::time::Duration::from_secs(30),
        );
        heartbeat.set_missed_tick_behavior(tokio::time::MissedTickBehavior::Delay);
        loop {
            tokio::select! {
                event = rx.recv() => {
                    match event {
                        Some(event) => {
                            if !sse.data(&event).await { break; }
                        }
                        None => break,
                    }
                }
                _ = heartbeat.tick() => {
                    if !sse.heartbeat().await { break; }
                }
            }
        }
        session_for_task.remove_listener(&listener_id);
    });
    response
}

fn running_payload() -> Value {
    json!({
        "type": "running",
        "runningSessionIds": rpc::running_session_ids(),
        "runningSessions": rpc::running_sessions(),
        "exitedSessions": rpc::exited_sessions(),
    })
}

pub async fn agent_running_events(State(_state): State<SharedState>) -> Response {
    let mut rx = rpc::subscribe_running();
    let mut notifications = crate::routes::notifications::subscribe_notifications();
    let (sse, response) = crate::sse::channel(512);
    sse.data(&running_payload()).await;
    tokio::spawn(async move {
        let mut heartbeat = tokio::time::interval_at(
            tokio::time::Instant::now() + std::time::Duration::from_secs(30),
            std::time::Duration::from_secs(30),
        );
        heartbeat.set_missed_tick_behavior(tokio::time::MissedTickBehavior::Delay);
        loop {
            tokio::select! {
                event = rx.recv() => {
                    match event {
                        Ok(event) => {
                            if !sse.data(&event).await { break; }
                        }
                        Err(tokio::sync::broadcast::error::RecvError::Lagged(_)) => continue,
                        Err(_) => break,
                    }
                }
                notification = notifications.recv() => {
                    match notification {
                        Ok(frame) => {
                            if !sse.data(&frame).await { break; }
                        }
                        Err(tokio::sync::broadcast::error::RecvError::Lagged(_)) => continue,
                        Err(_) => continue,
                    }
                }
                _ = heartbeat.tick() => {
                    if !sse.heartbeat().await { break; }
                }
            }
        }
    });
    response
}

pub async fn agent_host_tools_events(State(_state): State<SharedState>) -> Response {
    let mut rx = rpc::subscribe_host_tools();
    let (sse, response) = crate::sse::channel(256);
    tokio::spawn(async move {
        let mut heartbeat = tokio::time::interval_at(
            tokio::time::Instant::now() + std::time::Duration::from_secs(30),
            std::time::Duration::from_secs(30),
        );
        heartbeat.set_missed_tick_behavior(tokio::time::MissedTickBehavior::Delay);
        loop {
            tokio::select! {
                event = rx.recv() => {
                    match event {
                        Ok(call) => {
                            let mut frame = call.as_object().cloned().unwrap_or_default();
                            frame.insert("type".into(), Value::String("host_tool_call".into()));
                            if !sse.data(&Value::Object(frame)).await { break; }
                        }
                        Err(tokio::sync::broadcast::error::RecvError::Lagged(_)) => continue,
                        Err(_) => break,
                    }
                }
                _ = heartbeat.tick() => {
                    if !sse.heartbeat().await { break; }
                }
            }
        }
    });
    response
}

// ============================================================================
// bash-output
// ============================================================================

fn resolve_bash_output_path(path: &str, temp_root: &Path) -> Option<PathBuf> {
    let resolved = crate::util::absolute_path(Path::new(path));
    let parent = resolved.parent()?;
    let real_parent = std::fs::canonicalize(parent).ok()?;
    let real_root = std::fs::canonicalize(temp_root).ok()?;
    if real_parent != real_root {
        return None;
    }
    let name = resolved.file_name()?.to_string_lossy().into_owned();
    if !name.starts_with("pi-bash-") || !name.ends_with(".log") {
        return None;
    }
    if !name["pi-bash-".len()..name.len() - 4]
        .bytes()
        .all(|b| b.is_ascii_alphanumeric() || b == b'_' || b == b'-')
    {
        return None;
    }
    Some(resolved)
}

pub async fn agent_bash_output(
    State(state): State<SharedState>,
    AxumPath(id): AxumPath<String>,
    uri: Uri,
) -> Response {
    let query = query(&uri);
    let Some(path) = query.get("path") else {
        return crate::util::json_status(
            StatusCode::BAD_REQUEST,
            json!({ "error": "path required" }),
        );
    };
    let download = query.get("download") == Some("1");
    let Some(resolved) = resolve_bash_output_path(path, &std::env::temp_dir()) else {
        return crate::util::json_status(
            StatusCode::BAD_REQUEST,
            json!({ "error": "invalid path" }),
        );
    };
    if !session_reader::is_bash_output_referenced_by_session(&state.cfg, &resolved, Some(&id)) {
        return crate::util::json_status(StatusCode::FORBIDDEN, json!({ "error": "forbidden" }));
    }
    let meta = match std::fs::symlink_metadata(&resolved) {
        Ok(meta) if meta.is_file() && !meta.file_type().is_symlink() => meta,
        _ => {
            return crate::util::json_status(
                StatusCode::NOT_FOUND,
                json!({ "error": "full output unavailable" }),
            )
        }
    };
    if download {
        let file = match tokio::fs::File::open(&resolved).await {
            Ok(file) => file,
            Err(_) => {
                return crate::util::json_status(
                    StatusCode::NOT_FOUND,
                    json!({ "error": "full output unavailable" }),
                )
            }
        };
        return Response::builder()
            .status(StatusCode::OK)
            .header("Content-Type", "text/plain; charset=utf-8")
            .header(
                "Content-Disposition",
                "attachment; filename=\"bash-output.log\"",
            )
            .header("Cache-Control", "no-store")
            .body(axum::body::Body::from_stream(
                tokio_util::io::ReaderStream::new(file),
            ))
            .unwrap_or_else(|_| StatusCode::INTERNAL_SERVER_ERROR.into_response());
    }
    if meta.len() > MAX_INLINE_BASH_OUTPUT_BYTES {
        return crate::util::json_status(
            StatusCode::PAYLOAD_TOO_LARGE,
            json!({
                "error": format!("Full output is too large to display (limit {} bytes)", MAX_INLINE_BASH_OUTPUT_BYTES),
                "data": { "size": meta.len(), "maxBytes": MAX_INLINE_BASH_OUTPUT_BYTES },
            }),
        );
    }
    match std::fs::read(&resolved) {
        Ok(bytes) => json_ok(json!({
            "success": true,
            "data": { "output": String::from_utf8_lossy(&bytes) },
        })),
        Err(_) => crate::util::json_status(
            StatusCode::NOT_FOUND,
            json!({ "error": "full output unavailable" }),
        ),
    }
}

#[allow(dead_code)]
fn _unused(_: &Map<String, Value>, _: String) -> String {
    path_key(Path::new("/"))
}
