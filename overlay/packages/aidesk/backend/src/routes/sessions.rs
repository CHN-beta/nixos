//! `/api/sessions/*` — listing, parsing, context, rename/delete, archive.

use crate::omp::archive;
use crate::omp::rpc;
use crate::omp::session_files;
use crate::omp::session_reader::{self, ContextOptions, HistoryCursor};
use crate::omp::subagents;
use crate::routes::{body_json, json_ok, query, session_not_found};
use crate::state::SharedState;
use crate::util::{coded_error, iso_from_ms, now_ms, path_key};
use axum::extract::{Path as AxumPath, State};
use axum::http::{header, HeaderMap, HeaderValue, StatusCode, Uri};
use axum::response::{IntoResponse, Response};
use serde_json::{json, Map, Value};
use sha1::{Digest, Sha1};
use std::path::Path;

fn session_file_too_large() -> Response {
    coded_error(
        StatusCode::PAYLOAD_TOO_LARGE,
        "Session file is too large to open in AIDesk",
        "session_file_too_large",
    )
}

fn malformed_session() -> Response {
    coded_error(
        StatusCode::NOT_FOUND,
        "Session file is missing or malformed",
        "session_file_malformed",
    )
}

// ============================================================================
// List
// ============================================================================

pub async fn sessions_list(State(state): State<SharedState>, headers: HeaderMap) -> Response {
    let sessions = session_reader::list_all_sessions(&state.cfg);
    let running = rpc::running_sessions();
    let running_ids = rpc::running_session_ids();
    let body = json!({
        "sessions": sessions,
        "runningSessionIds": running_ids,
        "runningSessions": running,
    });
    let body_json = serde_json::to_string(&body).unwrap_or_default();
    let etag = format!(
        "\"{}\"",
        &format!("{:x}", Sha1::digest(body_json.as_bytes()))[..16]
    );
    let mut response = if headers
        .get(header::IF_NONE_MATCH)
        .and_then(|value| value.to_str().ok())
        == Some(etag.as_str())
    {
        Response::builder()
            .status(StatusCode::NOT_MODIFIED)
            .body(axum::body::Body::empty())
            .unwrap_or_else(|_| StatusCode::NOT_MODIFIED.into_response())
    } else {
        Response::builder()
            .status(StatusCode::OK)
            .header(header::CONTENT_TYPE, "application/json")
            .body(axum::body::Body::from(body_json))
            .unwrap_or_else(|_| StatusCode::INTERNAL_SERVER_ERROR.into_response())
    };
    let response_headers = response.headers_mut();
    if let Ok(value) = HeaderValue::from_str(&etag) {
        response_headers.insert(header::ETAG, value);
    }
    response_headers.insert(header::CACHE_CONTROL, HeaderValue::from_static("no-store"));
    response_headers.insert(header::VARY, HeaderValue::from_static("Cookie"));
    response
}

// ============================================================================
// Detail / rename / delete
// ============================================================================

pub async fn session_get(
    State(state): State<SharedState>,
    AxumPath(id): AxumPath<String>,
    uri: Uri,
) -> Response {
    let query = query(&uri);
    let Some(path) = session_reader::resolve_session_path(&state.cfg, &id) else {
        return session_not_found();
    };
    let Some(header) = session_files::read_session_header(&path) else {
        let loaded = session_files::load_session_file(&path, None);
        if loaded.too_large {
            return session_file_too_large();
        }
        return malformed_session();
    };
    let defer_thinking = query.has("deferThinking");
    let defer_media = query.has("deferMedia");
    let detail = match session_reader::session_detail(
        &state.cfg,
        &path,
        &header,
        defer_thinking,
        defer_media,
    ) {
        Ok(detail) => detail,
        Err(_) => return session_file_too_large(),
    };
    let mut payload = Map::new();
    payload.insert("sessionId".into(), Value::String(id.clone()));
    payload.insert(
        "filePath".into(),
        Value::String(path.to_string_lossy().into_owned()),
    );
    payload.insert("info".into(), detail.info);
    payload.insert(
        "leafId".into(),
        detail.leaf_id.map(Value::String).unwrap_or(Value::Null),
    );
    payload.insert("tree".into(), Value::Array(detail.tree));
    payload.insert("context".into(), detail.context);
    if query.has("includeState") {
        let agent = match rpc::get_session(&id) {
            Some(session) if session.is_alive() => {
                match session.send(json!({ "type": "get_state" })).await {
                    Ok(state_value) => json!({ "running": true, "state": state_value }),
                    Err(_) => json!({ "running": false }),
                }
            }
            _ => json!({ "running": false }),
        };
        payload.insert("agent".into(), agent);
    }
    json_ok(Value::Object(payload))
}

pub async fn session_patch(
    State(state): State<SharedState>,
    AxumPath(id): AxumPath<String>,
    request: axum::extract::Request,
) -> Response {
    let body = match body_json(request, 64 * 1024).await {
        Ok(body) => body,
        Err(response) => return response,
    };
    let name = body
        .get("name")
        .and_then(Value::as_str)
        .map(str::trim)
        .unwrap_or("");
    if name.is_empty() {
        return coded_error(
            StatusCode::BAD_REQUEST,
            "name is required",
            "session_name_required",
        );
    }
    let mut renamed = false;
    if let Some(session) = rpc::get_session(&id) {
        if session.is_alive() {
            if session
                .send(json!({ "type": "set_session_name", "name": name }))
                .await
                .is_ok()
            {
                renamed = true;
            }
        }
    }
    if !renamed {
        let Some(path) = session_reader::resolve_session_path(&state.cfg, &id) else {
            return session_not_found();
        };
        if !session_files::set_session_title(&path, name, "user") {
            return coded_error(
                StatusCode::INTERNAL_SERVER_ERROR,
                "Could not rename session",
                "session_rename_failed",
            );
        }
    }
    state.invalidate_session_roots();
    rpc::notify_sessions_changed(vec![id]);
    json_ok(json!({ "ok": true }))
}

fn sessions_directory(path: &Path) -> Vec<std::path::PathBuf> {
    let Some(dir) = path.parent() else {
        return Vec::new();
    };
    let Ok(entries) = std::fs::read_dir(dir) else {
        return Vec::new();
    };
    entries
        .flatten()
        .map(|entry| entry.path())
        .filter(|path| path.to_string_lossy().ends_with(".jsonl"))
        .collect()
}

pub async fn session_delete(
    State(state): State<SharedState>,
    AxumPath(id): AxumPath<String>,
) -> Response {
    let Some(path) = session_reader::resolve_session_path(&state.cfg, &id) else {
        return session_not_found();
    };
    let header = session_files::read_session_header(&path);
    let deleted_id = header
        .as_ref()
        .and_then(|header| header.get("id"))
        .and_then(Value::as_str)
        .map(|s| s.to_string())
        .unwrap_or_else(|| id.clone());
    let parent_session = header
        .as_ref()
        .and_then(|header| header.get("parentSession"))
        .and_then(Value::as_str)
        .map(|s| s.to_string());

    let mut grandparent_path: Option<String> = None;
    let mut grandparent_id: Option<String> = None;
    if let Some(parent) = &parent_session {
        if let Some(id_for_path) =
            session_reader::resolve_session_id_by_path(&state.cfg, Path::new(parent))
        {
            // Children linked by path must point at the parent's real file, not
            // at whatever spelling the header happened to carry.
            let resolved_path = session_reader::resolve_session_path(&state.cfg, &id_for_path);
            grandparent_path = Some(
                resolved_path
                    .as_deref()
                    .map(|path_for_id| path_for_id.to_string_lossy().into_owned())
                    .unwrap_or_else(|| parent.clone()),
            );
            grandparent_id = Some(id_for_path);
        } else if session_reader::resolve_session_path(&state.cfg, parent).is_some() {
            grandparent_path = Some(parent.clone());
            grandparent_id = Some(parent.clone());
        }
    }

    let target_key = path_key(&path);
    let mut skipped_children: Vec<Value> = Vec::new();
    for child_path in sessions_directory(&path) {
        if path_key(&child_path) == target_key {
            continue;
        }
        let Ok(meta) = std::fs::metadata(&child_path) else {
            continue;
        };
        if meta.len() > session_files::MAX_SESSION_LOAD_BYTES {
            let child_id = session_files::read_session_header(&child_path)
                .and_then(|header| {
                    header
                        .get("id")
                        .and_then(Value::as_str)
                        .map(|s| s.to_string())
                })
                .unwrap_or_else(|| session_files::session_path_key(&child_path));
            skipped_children.push(json!({ "id": child_id, "reason": "session_child_too_large" }));
            continue;
        }
        let Some(child_header) = session_files::read_session_header(&child_path) else {
            continue;
        };
        let Some(child_parent) = child_header.get("parentSession").and_then(Value::as_str) else {
            continue;
        };
        let linked_by_path = path_key(Path::new(child_parent)) == target_key;
        if !linked_by_path && child_parent != deleted_id {
            continue;
        }
        let child_id = child_header
            .get("id")
            .and_then(Value::as_str)
            .unwrap_or("")
            .to_string();
        if !child_id.is_empty() {
            if let Some(session) = rpc::get_session(&child_id) {
                if session.is_alive() {
                    skipped_children
                        .push(json!({ "id": child_id, "reason": "session_child_live" }));
                    continue;
                }
            }
        }
        let Ok(content) = std::fs::read_to_string(&child_path) else {
            continue;
        };
        let mut lines: Vec<String> = content.split('\n').map(|line| line.to_string()).collect();
        let header_index = lines
            .iter()
            .position(|line| !line.trim().is_empty())
            .unwrap_or(0);
        let header_index = if lines
            .get(header_index)
            .map(|line| session_files::parse_title_slot_line(line.trim()).is_some())
            .unwrap_or(false)
        {
            header_index + 1
        } else {
            header_index
        };
        let Some(line) = lines.get(header_index) else {
            continue;
        };
        let Ok(mut child_header) = serde_json::from_str::<Value>(line.trim()) else {
            continue;
        };
        let replacement = if linked_by_path {
            grandparent_path.clone().or_else(|| parent_session.clone())
        } else {
            grandparent_id.clone().or_else(|| parent_session.clone())
        };
        match replacement {
            Some(value) => {
                if let Some(object) = child_header.as_object_mut() {
                    object.insert("parentSession".into(), Value::String(value));
                }
            }
            None => {
                if let Some(object) = child_header.as_object_mut() {
                    object.remove("parentSession");
                }
            }
        }
        lines[header_index] = serde_json::to_string(&child_header).unwrap_or_default();
        if session_files::write_session_file_atomic(&child_path, &lines.join("\n")).is_err() {
            skipped_children.push(json!({
                "id": if child_id.is_empty() { session_files::session_path_key(&child_path) } else { child_id },
                "reason": "session_child_rewrite_failed",
            }));
        }
    }

    if let Some(session) = rpc::get_session(&id) {
        session.destroy_and_wait().await;
    }
    rpc::clear_exited_session(&id);
    let delete_result = session_files::delete_session_file_with_artifacts(&path);
    if let Err(error) = delete_result {
        return crypto_error(error.to_string());
    }
    state.invalidate_session_roots();
    rpc::notify_sessions_changed(vec![deleted_id.clone(), id.clone()]);
    let mut payload = Map::new();
    payload.insert("ok".into(), Value::Bool(true));
    if !skipped_children.is_empty() {
        payload.insert("skippedChildren".into(), Value::Array(skipped_children));
    }
    json_ok(Value::Object(payload))
}

fn crypto_error(message: String) -> Response {
    crate::util::api_error(message, StatusCode::INTERNAL_SERVER_ERROR)
}

// ============================================================================
// Context (boundary / sync / full)
// ============================================================================

pub async fn session_context(
    State(state): State<SharedState>,
    AxumPath(id): AxumPath<String>,
    uri: Uri,
) -> Response {
    let query = query(&uri);
    let defer_thinking = query.has("deferThinking");
    let defer_media = query.has("deferMedia");
    let include_pre_compaction = query.has("includePreCompaction");
    let leaf_id = query
        .get("leafId")
        .filter(|value| !value.is_empty())
        .map(|s| s.to_string());
    let boundary = query.get("boundary");
    if boundary.is_some() {
        if boundary != Some("1") || query.count("boundary") != 1 {
            return coded_error(
                StatusCode::BAD_REQUEST,
                "Invalid boundary mode",
                "invalid_boundary",
            );
        }
        if ["sync", "leafId", "includePreCompaction", "cursor", "limit"]
            .iter()
            .any(|option| query.has(option))
        {
            return coded_error(
                StatusCode::BAD_REQUEST,
                "Boundary mode requires the current active context",
                "invalid_boundary_options",
            );
        }
    }
    let sync = query.get("sync");
    if let Some(sync) = sync {
        if sync != "1" {
            return coded_error(StatusCode::BAD_REQUEST, "Invalid sync mode", "invalid_sync");
        }
    }
    let mut cursor: Option<HistoryCursor> = None;
    let mut limit = session_reader::MAX_SYNC_MESSAGES;
    if sync == Some("1") {
        match session_reader::parse_history_cursor(query.get("cursor")) {
            Ok(parsed) => cursor = parsed,
            Err(_) => {
                return coded_error(
                    StatusCode::BAD_REQUEST,
                    "Invalid history cursor",
                    "invalid_sync_cursor",
                )
            }
        }
        if let Some(raw_limit) = query.get("limit") {
            let parsed: Result<usize, _> = raw_limit.parse();
            match parsed {
                Ok(value) if value >= 1 && value <= session_reader::MAX_SYNC_MESSAGES => {
                    limit = value
                }
                _ => {
                    return coded_error(
                        StatusCode::BAD_REQUEST,
                        "Invalid history page limit",
                        "invalid_sync_limit",
                    )
                }
            }
        }
    }

    let Some(path) = session_reader::resolve_session_path(&state.cfg, &id) else {
        // A live wrapper may still own a brand-new session whose file has not
        // been written yet.
        let live = rpc::get_session(&id);
        if let Some(session) = live {
            if session.is_alive() && !std::path::Path::new(&session.session_file()).exists() {
                if boundary == Some("1") {
                    return crate::routes::apply_headers(
                        json_ok(json!({ "entryIds": [] })),
                        &[("Cache-Control", "no-store".into())],
                    );
                }
                if sync == Some("1")
                    && cursor
                        .as_ref()
                        .and_then(|cursor| cursor.last_entry_id.as_ref())
                        .is_none()
                    && leaf_id.is_none()
                {
                    let page = session_reader::history_page(
                        &state.cfg,
                        &[],
                        cursor.as_ref(),
                        limit,
                        None,
                        ContextOptions::default(),
                    );
                    let payload = json!({
                        "mode": page.mode,
                        "baseEntryId": page.base_entry_id,
                        "context": page.context,
                        "cursor": { "firstEntryId": page.cursor.first_entry_id, "lastEntryId": page.cursor.last_entry_id },
                        "hasMore": page.has_more,
                        "sessionId": id,
                        "leafId": Value::Null,
                        "live": session.stream_snapshot(),
                    });
                    return crate::routes::apply_headers(
                        json_ok(payload),
                        &[("Cache-Control", "no-store".into())],
                    );
                }
            }
        }
        return session_not_found();
    };

    let Some(header) = session_files::read_session_header(&path) else {
        let loaded = session_files::load_session_file(&path, None);
        if loaded.too_large {
            return session_file_too_large();
        }
        return malformed_session();
    };
    let _ = header;

    if boundary == Some("1") {
        return match session_reader::context_boundary(&state.cfg, &path) {
            Ok(boundary) => crate::routes::apply_headers(
                json_ok(boundary),
                &[("Cache-Control", "no-store".into())],
            ),
            Err(_) => session_file_too_large(),
        };
    }

    if sync == Some("1") {
        // Display entries resolve `blob:sha256:` images and mirror the
        // non-sync path; raw entries would send unusable image refs.
        let entries = match session_reader::load_display_entries(&state.cfg, &path, defer_media) {
            Ok(entries) => entries,
            Err(_) => return session_file_too_large(),
        };
        let page = session_reader::history_page(
            &state.cfg,
            &entries,
            cursor.as_ref(),
            limit,
            leaf_id.as_deref(),
            ContextOptions {
                defer_thinking,
                defer_media,
                include_pre_compaction,
            },
        );
        let tip_id = entries
            .last()
            .and_then(|entry| entry.get("id"))
            .and_then(Value::as_str)
            .map(|id| id.to_string());
        let live = rpc::get_session(&id).filter(|session| {
            session.is_alive() && (leaf_id.is_none() || (tip_id.is_some() && leaf_id == tip_id))
        });
        let payload = json!({
            "mode": page.mode,
            "baseEntryId": page.base_entry_id,
            "context": page.context,
            "cursor": { "firstEntryId": page.cursor.first_entry_id, "lastEntryId": page.cursor.last_entry_id },
            "hasMore": page.has_more,
            "sessionId": id,
            "leafId": page.leaf_id,
            "live": live.map(|session| session.stream_snapshot()).unwrap_or(Value::Null),
        });
        return crate::routes::apply_headers(
            json_ok(payload),
            &[("Cache-Control", "no-store".into())],
        );
    }

    match session_reader::load_display_entries(&state.cfg, &path, defer_media) {
        Ok(entries) => {
            let context = session_reader::build_session_context(
                &state.cfg,
                &entries,
                leaf_id.as_deref(),
                ContextOptions {
                    defer_thinking,
                    defer_media,
                    include_pre_compaction,
                },
            );
            json_ok(json!({ "context": context }))
        }
        Err(_) => session_file_too_large(),
    }
}

// ============================================================================
// State / thinking / subagents
// ============================================================================

pub async fn session_state(
    State(state): State<SharedState>,
    AxumPath(id): AxumPath<String>,
) -> Response {
    if let Some(session) = rpc::get_session(&id) {
        if session.is_alive() {
            return match session.send(json!({ "type": "get_state" })).await {
                Ok(state_value) => json_ok(json!({ "running": true, "state": state_value })),
                Err(error) if error.code.as_deref() == Some("session_unresponsive") => {
                    json_ok(json!({ "running": false, "recovered": true }))
                }
                Err(error) => (
                    StatusCode::BAD_REQUEST,
                    axum::Json(json!({ "error": error.message, "code": error.code })),
                )
                    .into_response(),
            };
        }
    }
    if let Some(exited) = rpc::get_exited_session(&id) {
        return json_ok(json!({ "running": false, "exited": exited }));
    }
    if session_reader::resolve_session_path(&state.cfg, &id).is_none() {
        return session_not_found();
    }
    json_ok(json!({ "running": false }))
}

pub async fn session_thinking(
    State(state): State<SharedState>,
    AxumPath((id, entry_id)): AxumPath<(String, String)>,
    uri: Uri,
) -> Response {
    let query = query(&uri);
    let block_index = match query
        .get("blockIndex")
        .and_then(|value| value.parse::<usize>().ok())
    {
        Some(value) => value,
        None => {
            return coded_error(
                StatusCode::BAD_REQUEST,
                "Valid blockIndex is required",
                "invalid_block_index",
            )
        }
    };
    let Some(path) = session_reader::resolve_session_path(&state.cfg, &id) else {
        return session_not_found();
    };
    let entries = session_files::load_session_file(&path, None).entries;
    let Some(entry) = entries
        .iter()
        .find(|entry| entry.get("id").and_then(Value::as_str) == Some(entry_id.as_str()))
    else {
        return coded_error(
            StatusCode::NOT_FOUND,
            "Assistant message not found",
            "assistant_message_not_found",
        );
    };
    let is_assistant = entry.get("type").and_then(Value::as_str) == Some("message")
        && entry
            .get("message")
            .and_then(|message| message.get("role"))
            .and_then(Value::as_str)
            == Some("assistant");
    if !is_assistant {
        return coded_error(
            StatusCode::NOT_FOUND,
            "Assistant message not found",
            "assistant_message_not_found",
        );
    }
    let block = entry
        .get("message")
        .and_then(|message| message.get("content"))
        .and_then(Value::as_array)
        .and_then(|blocks| blocks.get(block_index));
    let Some(block) =
        block.filter(|block| block.get("type").and_then(Value::as_str) == Some("thinking"))
    else {
        return coded_error(
            StatusCode::NOT_FOUND,
            "Thinking block not found",
            "thinking_block_not_found",
        );
    };
    json_ok(
        json!({ "thinking": block.get("thinking").cloned().unwrap_or(Value::String(String::new())) }),
    )
}

pub async fn session_subagents(
    State(state): State<SharedState>,
    AxumPath(id): AxumPath<String>,
) -> Response {
    let Some(path) = session_reader::resolve_session_path(&state.cfg, &id) else {
        if let Some(session) = rpc::get_session(&id) {
            if session.is_alive() {
                return json_ok(json!({ "subagents": [] }));
            }
        }
        return session_not_found();
    };
    let roster = subagents::extract_subagent_history(&path);
    json_ok(json!({ "subagents": roster }))
}

pub async fn session_subagent(
    State(state): State<SharedState>,
    AxumPath((id, subagent_id)): AxumPath<(String, String)>,
    uri: Uri,
) -> Response {
    if !subagents::is_valid_subagent_id(&subagent_id) {
        return coded_error(
            StatusCode::BAD_REQUEST,
            "Invalid subagent id",
            "invalid_subagent_id",
        );
    }
    let Some(path) = session_reader::resolve_session_path(&state.cfg, &id) else {
        return session_not_found();
    };
    let query = query(&uri);
    if query.get("mode") == Some("completion") {
        let Some(resolved) = subagents::resolve_subagent_artifact(&path, &subagent_id, ".md")
        else {
            return coded_error(
                StatusCode::NOT_FOUND,
                "Subagent completion not found",
                "transcript_not_found",
            );
        };
        let completion = subagents::read_completion_artifact(&resolved);
        let (text, truncated) = match completion {
            Some(value) => (
                value.get("completion").cloned().unwrap_or(Value::Null),
                value
                    .get("truncated")
                    .and_then(Value::as_bool)
                    .unwrap_or(false),
            ),
            None => (Value::Null, false),
        };
        return json_ok(json!({
            "sessionFile": subagents::subagent_transcript_path(&path, &subagent_id).to_string_lossy(),
            "completion": text,
            "truncated": truncated,
        }));
    }
    let Some(resolved) = subagents::resolve_subagent_artifact(&path, &subagent_id, ".jsonl") else {
        return coded_error(
            StatusCode::NOT_FOUND,
            "Subagent transcript not found",
            "transcript_not_found",
        );
    };
    let from_byte = query
        .get("fromByte")
        .and_then(|value| value.parse::<u64>().ok())
        .unwrap_or(0);
    let page = subagents::read_subagent_transcript_page(&state.cfg, &resolved, from_byte);
    json_ok(page)
}

// ============================================================================
// Export / auto-name / archive
// ============================================================================

fn content_disposition(name: &str, inline: bool) -> String {
    crate::util::content_disposition(name, inline)
}

pub async fn session_export(
    State(state): State<SharedState>,
    AxumPath(id): AxumPath<String>,
    uri: Uri,
) -> Response {
    let query = query(&uri);
    let inline = query.get("inline") == Some("1");
    let Some(path) = session_reader::resolve_session_path(&state.cfg, &id) else {
        return session_not_found();
    };
    let Some(bin) = &state.cfg.omp_bin else {
        return coded_error(
            StatusCode::INTERNAL_SERVER_ERROR,
            "omp binary not found. Install oh-my-pi or set OMP_WEB_OMP_BIN.",
            "omp_not_found",
        );
    };
    let temp_dir = std::env::temp_dir().join("omp-web-export");
    let _ = std::fs::create_dir_all(&temp_dir);
    let output_path = temp_dir.join(format!("{}.html", uuid::Uuid::new_v4()));
    let session_base = path
        .file_stem()
        .map(|stem| stem.to_string_lossy().into_owned())
        .unwrap_or_else(|| id.clone());
    let file_name = format!("omp-session-{}.html", session_base);
    let output = tokio::process::Command::new(bin)
        .arg("--export")
        .arg(&path)
        .arg(&output_path)
        .current_dir(std::env::temp_dir())
        .output()
        .await;
    let result = match output {
        Ok(output) if output.status.success() => std::fs::read_to_string(&output_path),
        Ok(output) => Err(std::io::Error::other(
            String::from_utf8_lossy(&output.stderr).trim().to_string(),
        )),
        Err(error) => Err(error),
    };
    let _ = std::fs::remove_file(&output_path);
    match result {
        Ok(html) => Response::builder()
            .status(StatusCode::OK)
            .header(header::CONTENT_TYPE, "text/html; charset=utf-8")
            .header(
                header::CONTENT_DISPOSITION,
                content_disposition(&file_name, inline),
            )
            .header(header::CACHE_CONTROL, "no-cache")
            .body(axum::body::Body::from(html))
            .unwrap_or_else(|_| StatusCode::INTERNAL_SERVER_ERROR.into_response()),
        Err(error) => crate::util::api_error(error, StatusCode::INTERNAL_SERVER_ERROR),
    }
}

fn sanitize_title(value: Option<&str>) -> Option<String> {
    let value = value?;
    let first_line = value.lines().next().unwrap_or("");
    let stripped: String = first_line
        .chars()
        .map(|c| if c.is_control() { ' ' } else { c })
        .collect();
    let normalized = stripped.split_whitespace().collect::<Vec<_>>().join(" ");
    if normalized.is_empty() {
        None
    } else {
        Some(normalized)
    }
}

fn derive_title(first_message: &str) -> Option<String> {
    if first_message.is_empty() || first_message == "(no messages)" {
        return None;
    }
    let sanitized = sanitize_title(Some(first_message))?;
    if !sanitized.chars().any(|c| c.is_alphanumeric()) {
        return None;
    }
    let chars: Vec<char> = sanitized.chars().collect();
    if chars.len() <= 60 {
        Some(sanitized)
    } else {
        Some(format!(
            "{}…",
            chars[..60].iter().collect::<String>().trim_end()
        ))
    }
}

pub async fn session_auto_name(
    State(state): State<SharedState>,
    AxumPath(id): AxumPath<String>,
) -> Response {
    let mut live = rpc::get_session(&id).filter(|session| session.is_alive());
    if live.is_none() {
        let Some(path) = session_reader::resolve_session_path(&state.cfg, &id) else {
            return session_not_found();
        };
        let header = session_files::read_session_header(&path);
        let recorded = header
            .as_ref()
            .and_then(|header| header.get("cwd"))
            .and_then(Value::as_str)
            .map(|cwd| cwd.to_string());
        let cwd = rpc::resolve_spawn_cwd(recorded.as_deref());
        if let Ok((session, _)) = rpc::start_rpc_session(
            state.clone(),
            &id,
            &path.to_string_lossy(),
            &cwd,
            None,
            false,
            recorded,
        )
        .await
        {
            live = Some(session);
        }
    }

    if let Some(session) = &live {
        match session.generate_title().await {
            Ok(Some(title)) => {
                if let Some(title) = sanitize_title(Some(&title)) {
                    return json_ok(
                        json!({ "title": title, "generated": true, "usage": Value::Null }),
                    );
                }
            }
            Ok(None) => {}
            Err(error) => {
                if let Some(code) = error.code {
                    return json_status(
                        StatusCode::CONFLICT,
                        json!({ "error": error.message, "code": code }),
                    );
                }
            }
        }
    }

    let Some(path) = session_reader::resolve_session_path(&state.cfg, &id) else {
        return session_not_found();
    };
    let info = session_files::scan_session_info(&path, false);
    let stored = info
        .as_ref()
        .and_then(|info| sanitize_title(info.title.as_deref()));
    if let Some(title) = stored {
        return json_ok(json!({ "title": title, "generated": false, "usage": Value::Null }));
    }
    let Some(derived) = info
        .as_ref()
        .and_then(|info| derive_title(&info.first_message))
    else {
        return json_status(
            StatusCode::CONFLICT,
            json!({ "error": "The session has no user messages to name", "code": "session_no_messages_to_name" }),
        );
    };
    let mut saved = false;
    if let Some(session) = &live {
        if session.is_alive()
            && session
                .send(json!({ "type": "set_session_name", "name": derived }))
                .await
                .is_ok()
        {
            saved = true;
        }
    }
    if !saved {
        session_files::set_session_title(&path, &derived, "auto");
    }
    state.invalidate_session_roots();
    rpc::notify_sessions_changed(vec![id]);
    json_ok(json!({ "title": derived, "generated": false, "usage": Value::Null }))
}

pub async fn session_archive(
    State(state): State<SharedState>,
    AxumPath(id): AxumPath<String>,
) -> Response {
    let Some(path) = session_reader::resolve_session_path(&state.cfg, &id) else {
        return session_not_found();
    };
    let has_children = session_reader::list_all_sessions(&state.cfg)
        .iter()
        .any(|session| session.parent_session_id.as_deref() == Some(id.as_str()));
    if has_children {
        return json_status(
            StatusCode::CONFLICT,
            json!({
                "error": "Archive child sessions before archiving this session",
                "code": "session_has_children",
            }),
        );
    }
    if let Some(session) = rpc::get_session(&id) {
        session.destroy_and_wait().await;
    }
    match session_files::archive_session_file_with_artifacts(
        &state.cfg.sessions_dir,
        &state.cfg.archive_dir,
        &path,
    ) {
        Ok(archived_path) => {
            rpc::clear_exited_session(&id);
            state.invalidate_session_roots();
            rpc::notify_sessions_changed(vec![id.clone()]);
            json_ok(json!({
                "ok": true,
                "archived": true,
                "archivedPath": archived_path.to_string_lossy(),
            }))
        }
        Err(error) => json_status(
            StatusCode::INTERNAL_SERVER_ERROR,
            json!({ "error": error, "code": "session_archive_failed" }),
        ),
    }
}

pub async fn sessions_archive_list(State(state): State<SharedState>) -> Response {
    let archives = archive::list_archived_sessions(&state.cfg);
    crate::routes::apply_headers(
        json_ok(json!({ "archives": archives })),
        &[("Cache-Control", "no-store".into())],
    )
}

pub async fn sessions_archive_restore(
    State(state): State<SharedState>,
    request: axum::extract::Request,
) -> Response {
    let body = match body_json(request, 64 * 1024).await {
        Ok(body) => body,
        Err(_) => {
            return coded_error(
                StatusCode::BAD_REQUEST,
                "Archive key is required",
                "archive_key_required",
            )
        }
    };
    let key = body
        .get("key")
        .and_then(Value::as_str)
        .map(str::trim)
        .unwrap_or("");
    if key.is_empty() {
        return coded_error(
            StatusCode::BAD_REQUEST,
            "Archive key is required",
            "archive_key_required",
        );
    }
    match archive::restore_archived_session(&state.cfg, key) {
        Ok(session_id) => {
            state.invalidate_session_roots();
            rpc::notify_sessions_changed(vec![session_id.clone()]);
            json_ok(json!({ "ok": true, "sessionId": session_id }))
        }
        Err((status, message)) => json_status(
            StatusCode::from_u16(status).unwrap_or(StatusCode::INTERNAL_SERVER_ERROR),
            json!({ "error": message, "code": "archive_restore_failed" }),
        ),
    }
}

fn json_status(status: StatusCode, value: Value) -> Response {
    crate::util::json_status(status, value)
}

#[allow(dead_code)]
fn _unused(_: String, _: &HeaderMap) -> String {
    iso_from_ms(now_ms())
}
