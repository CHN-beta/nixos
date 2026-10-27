//! On-disk subagent roster + transcript paging.
//!
//! omp writes each subagent's transcript to the parent session's sibling
//! artifacts directory (`<session-dir>/<subagent-id>.jsonl`, plus `<id>.md`
//! outputs). The parent's task toolResult details persist progress/results
//! snapshots, so the roster is recoverable after a reload without a live RPC.

use crate::config::Config;
use crate::omp::session_reader::entry_to_ui_message;
use crate::util::path_key;
use serde_json::{json, Map, Value};
use std::collections::{HashMap, HashSet};
use std::path::{Path, PathBuf};

pub const MAX_SUBAGENT_TRANSCRIPT_BYTES: u64 = 16 * 1024 * 1024;
pub const SUBAGENT_TRANSCRIPT_PAGE_BYTES: u64 = 256 * 1024;
pub const MAX_SUBAGENT_COMPLETION_BYTES: u64 = 1024 * 1024;

pub fn is_valid_subagent_id(id: &str) -> bool {
    if id.is_empty() || id.len() > 100 {
        return false;
    }
    id.split('.').all(|segment| {
        !segment.is_empty()
            && segment
                .bytes()
                .all(|b| b.is_ascii_alphanumeric() || b == b'_' || b == b'-')
    })
}

pub fn sibling_dir_for_session(session_file: &Path) -> PathBuf {
    let text = session_file.to_string_lossy();
    PathBuf::from(text.trim_end_matches(".jsonl"))
}

pub fn subagent_transcript_path(session_file: &Path, subagent_id: &str) -> PathBuf {
    sibling_dir_for_session(session_file).join(format!("{}.jsonl", subagent_id))
}

/// Resolve an artifact inside the sibling dir, confining symlinks to it.
pub fn resolve_subagent_artifact(
    session_file: &Path,
    subagent_id: &str,
    extension: &str,
) -> Option<PathBuf> {
    let real_dir = std::fs::canonicalize(sibling_dir_for_session(session_file)).ok()?;
    let candidate = real_dir.join(format!("{}{}", subagent_id, extension));
    let real_candidate = std::fs::canonicalize(&candidate).ok()?;
    if real_candidate.parent()? != real_dir.as_path() {
        return None;
    }
    if !real_candidate.is_file() {
        return None;
    }
    Some(real_candidate)
}

fn as_string(value: Option<&Value>) -> Option<String> {
    value.and_then(Value::as_str).map(|s| s.to_string())
}

fn as_number(value: Option<&Value>) -> Option<f64> {
    value.and_then(Value::as_f64).filter(|v| v.is_finite())
}

fn progress_status(status: Option<&str>) -> &'static str {
    match status {
        Some("completed") => "completed",
        Some("failed") => "failed",
        Some("aborted") => "aborted",
        _ => "started",
    }
}

fn result_status(value: &Map<String, Value>) -> &'static str {
    if value.get("aborted").and_then(Value::as_bool) == Some(true) {
        return "aborted";
    }
    if value
        .get("error")
        .and_then(Value::as_str)
        .map(|s| !s.is_empty())
        .unwrap_or(false)
    {
        return "failed";
    }
    if let Some(exit_code) = value.get("exitCode").and_then(Value::as_i64) {
        return if exit_code == 0 {
            "completed"
        } else {
            "failed"
        };
    }
    "started"
}

fn transcript_model(file: &Path) -> Option<String> {
    use std::io::Read;
    let mut buffer = [0u8; 8192];
    let mut handle = std::fs::File::open(file).ok()?;
    let read = handle.read(&mut buffer).ok()?;
    let head = String::from_utf8_lossy(&buffer[..read]);
    let complete = match head.rfind('\n') {
        Some(index) => &head[..=index],
        None => return None,
    };
    let mut model: Option<String> = None;
    let mut thinking: Option<String> = None;
    for entry in crate::omp::session_files::parse_jsonl_lenient(complete) {
        match entry.get("type").and_then(Value::as_str) {
            Some("model_change") => {
                if let Some(value) = entry.get("model").and_then(Value::as_str) {
                    model = Some(value.to_string());
                }
            }
            Some("thinking_level_change") => {
                if let Some(value) = entry.get("thinkingLevel").and_then(Value::as_str) {
                    thinking = Some(value.to_string());
                }
            }
            _ => {}
        }
    }
    model.map(|model| match thinking {
        Some(thinking) if !thinking.is_empty() => format!("{}:{}", model, thinking),
        _ => model,
    })
}

const PROGRESS_KEYS: &[&str] = &[
    "index",
    "agent",
    "agentSource",
    "task",
    "assignment",
    "description",
    "lastIntent",
    "currentTool",
    "currentToolArgs",
    "currentToolStartMs",
    "recentTools",
    "recentOutput",
    "toolCount",
    "requests",
    "tokens",
    "contextTokens",
    "contextWindow",
    "cost",
    "durationMs",
    "modelOverride",
    "modelRole",
    "resolvedModel",
    "resolvedModelIsFallback",
    "retryFailure",
];

fn copy_progress_fields(raw: &Map<String, Value>) -> Map<String, Value> {
    let mut out = Map::new();
    for key in PROGRESS_KEYS {
        if let Some(value) = raw.get(*key) {
            out.insert((*key).to_string(), value.clone());
        }
    }
    if raw.contains_key("retryFailure") {
        match crate::omp::session_reader::task_result_retry_failure(
            raw.get("retryFailure").unwrap_or(&Value::Null),
        ) {
            Some(value) => {
                out.insert("retryFailure".into(), value);
            }
            None => {
                out.remove("retryFailure");
            }
        }
    }
    out
}

/// Recover the subagent roster from a parent session's task toolResults.
pub fn extract_subagent_history(path: &Path) -> Vec<Value> {
    let entries = crate::omp::session_files::load_session_file(path, None).entries;
    let mut by_id: HashMap<String, Map<String, Value>> = HashMap::new();
    let mut order: Vec<String> = Vec::new();
    let mut call_order: HashMap<String, usize> = HashMap::new();
    for entry in &entries {
        if entry.get("type").and_then(Value::as_str) != Some("message") {
            continue;
        }
        let Some(message) = entry.get("message").and_then(Value::as_object) else {
            continue;
        };
        if message.get("role").and_then(Value::as_str) != Some("assistant") {
            continue;
        }
        if let Some(content) = message.get("content").and_then(Value::as_array) {
            for block in content {
                if block.get("type").and_then(Value::as_str) != Some("toolCall") {
                    continue;
                }
                let name = block
                    .get("name")
                    .and_then(Value::as_str)
                    .or_else(|| block.get("toolName").and_then(Value::as_str));
                if name != Some("task") {
                    continue;
                }
                if let Some(call_id) = block
                    .get("id")
                    .and_then(Value::as_str)
                    .or_else(|| block.get("toolCallId").and_then(Value::as_str))
                {
                    let next = call_order.len();
                    call_order.entry(call_id.to_string()).or_insert(next);
                }
            }
        }
    }

    let mut batch_seq: isize;
    let mut unannounced: usize = 0;
    let mut batch_by_id: HashMap<String, isize> = HashMap::new();
    let mut detached: HashSet<String> = HashSet::new();

    let upsert = |entry: Map<String, Value>,
                  by_id: &mut HashMap<String, Map<String, Value>>,
                  order: &mut Vec<String>,
                  batch_by_id: &mut HashMap<String, isize>,
                  batch_seq: isize,
                  ignore_terminal: bool| {
        let Some(id) = entry
            .get("id")
            .and_then(Value::as_str)
            .map(|s| s.to_string())
        else {
            return;
        };
        if !is_valid_subagent_id(&id) {
            return;
        }
        match by_id.get_mut(&id) {
            None => {
                batch_by_id.insert(id.clone(), batch_seq);
                order.push(id.clone());
                by_id.insert(id, entry);
            }
            Some(existing) => {
                let terminal = matches!(
                    existing.get("status").and_then(Value::as_str),
                    Some("completed") | Some("failed") | Some("aborted")
                );
                if terminal && !ignore_terminal {
                    return;
                }
                let preserved = *batch_by_id.get(&id).unwrap_or(&batch_seq);
                for (key, value) in entry.iter() {
                    if key == "batchSeq" {
                        continue;
                    }
                    existing.insert(key.clone(), value.clone());
                }
                if !existing.contains_key("result") {
                    if let Some(result) = entry.get("result") {
                        existing.insert("result".into(), result.clone());
                    }
                }
                batch_by_id.insert(id, preserved);
            }
        }
    };

    for entry in &entries {
        if entry.get("type").and_then(Value::as_str) != Some("message") {
            continue;
        }
        let Some(message) = entry.get("message").and_then(Value::as_object) else {
            continue;
        };
        if message.get("role").and_then(Value::as_str) != Some("toolResult")
            || message.get("toolName").and_then(Value::as_str) != Some("task")
        {
            continue;
        }
        let tool_call_id = message
            .get("toolCallId")
            .and_then(Value::as_str)
            .map(|s| s.to_string());
        batch_seq = tool_call_id
            .as_ref()
            .and_then(|id| call_order.get(id).copied())
            .map(|value| value as isize)
            .unwrap_or_else(|| {
                let value = call_order.len() as isize + unannounced as isize;
                unannounced += 1;
                value
            });
        let details = message.get("details").and_then(Value::as_object);
        let progress = details
            .and_then(|d| d.get("progress"))
            .and_then(Value::as_array)
            .cloned()
            .unwrap_or_default();
        let results = details
            .and_then(|d| d.get("results"))
            .and_then(Value::as_array)
            .cloned()
            .unwrap_or_default();
        let async_info = details
            .and_then(|d| d.get("async"))
            .and_then(Value::as_object);
        if let Some(job_id) = async_info
            .and_then(|info| info.get("jobId"))
            .and_then(Value::as_str)
        {
            detached.insert(job_id.to_string());
        }

        for raw in progress {
            let Some(raw) = raw.as_object() else { continue };
            let Some(id) = raw.get("id").and_then(Value::as_str) else {
                continue;
            };
            let mut record = copy_progress_fields(raw);
            record.insert("id".into(), Value::String(id.to_string()));
            record.insert(
                "agent".into(),
                Value::String(
                    raw.get("agent")
                        .and_then(Value::as_str)
                        .unwrap_or("subagent")
                        .to_string(),
                ),
            );
            record.insert(
                "status".into(),
                Value::String(
                    progress_status(raw.get("status").and_then(Value::as_str)).to_string(),
                ),
            );
            record.insert(
                "index".into(),
                Value::from(as_number(raw.get("index")).unwrap_or(0.0) as i64),
            );
            if let Some(tool_call_id) = &tool_call_id {
                record.insert(
                    "parentToolCallId".into(),
                    Value::String(tool_call_id.clone()),
                );
            }
            record.insert("transcriptAvailable".into(), Value::Bool(false));
            upsert(
                record,
                &mut by_id,
                &mut order,
                &mut batch_by_id,
                batch_seq,
                false,
            );
        }

        for raw in results {
            let Some(raw) = raw.as_object() else { continue };
            let Some(id) = raw.get("id").and_then(Value::as_str) else {
                continue;
            };
            let prior = by_id.get(id).cloned().unwrap_or_default();
            let mut record = Map::new();
            record.insert("id".into(), Value::String(id.to_string()));
            record.insert(
                "agent".into(),
                Value::String(
                    as_string(raw.get("agent"))
                        .or_else(|| as_string(prior.get("agent")))
                        .unwrap_or_else(|| "subagent".to_string()),
                ),
            );
            for key in [
                "agentSource",
                "task",
                "assignment",
                "description",
                "lastIntent",
                "modelRole",
                "resolvedModel",
                "modelOverride",
                "toolCount",
                "requests",
                "tokens",
                "contextTokens",
                "contextWindow",
                "durationMs",
            ] {
                if let Some(value) = raw.get(key).or_else(|| prior.get(key)) {
                    record.insert(key.to_string(), value.clone());
                }
            }
            record.insert(
                "status".into(),
                Value::String(result_status(raw).to_string()),
            );
            record.insert(
                "index".into(),
                Value::from(
                    as_number(raw.get("index"))
                        .map(|v| v as i64)
                        .unwrap_or_else(|| {
                            as_number(prior.get("index")).map(|v| v as i64).unwrap_or(0)
                        }),
                ),
            );
            if let Some(tool_call_id) = &tool_call_id {
                record.insert(
                    "parentToolCallId".into(),
                    Value::String(tool_call_id.clone()),
                );
            }
            let mut result = Map::new();
            for key in [
                "exitCode",
                "truncated",
                "error",
                "aborted",
                "abortReason",
                "outputPath",
                "patchPath",
                "branchName",
            ] {
                if let Some(value) = raw.get(key) {
                    result.insert(key.to_string(), value.clone());
                }
            }
            let cost = raw
                .get("cost")
                .and_then(Value::as_f64)
                .filter(|value| value.is_finite())
                .or_else(|| crate::omp::session_reader::task_result_usage_cost(raw));
            if let Some(cost) = cost {
                result.insert("cost".into(), Value::from(cost));
            }
            if let Some(retry_failure) = crate::omp::session_reader::task_result_retry_failure(
                raw.get("retryFailure").unwrap_or(&Value::Null),
            ) {
                result.insert("retryFailure".into(), retry_failure);
            }
            if let Some(structured_output) =
                crate::omp::session_reader::task_result_structured_output(
                    raw.get("structuredOutput").unwrap_or(&Value::Null),
                )
            {
                result.insert("structuredOutput".into(), structured_output);
            }
            if !result.is_empty() {
                record.insert("result".into(), Value::Object(result));
            }
            record.insert("transcriptAvailable".into(), Value::Bool(false));
            upsert(
                record,
                &mut by_id,
                &mut order,
                &mut batch_by_id,
                batch_seq,
                true,
            );
        }

        if let Some(info) = async_info {
            if let Some(job_id) = info.get("jobId").and_then(Value::as_str) {
                if !by_id.contains_key(job_id) {
                    let state = info.get("state").and_then(Value::as_str).unwrap_or("");
                    let status = match state {
                        "completed" => "completed",
                        "failed" => "failed",
                        _ => "started",
                    };
                    let mut record = Map::new();
                    record.insert("id".into(), Value::String(job_id.to_string()));
                    record.insert("agent".into(), Value::String("task".into()));
                    record.insert("status".into(), Value::String(status.into()));
                    record.insert("index".into(), Value::from(by_id.len() as i64));
                    if let Some(tool_call_id) = &tool_call_id {
                        record.insert(
                            "parentToolCallId".into(),
                            Value::String(tool_call_id.clone()),
                        );
                    }
                    record.insert("transcriptAvailable".into(), Value::Bool(false));
                    upsert(
                        record,
                        &mut by_id,
                        &mut order,
                        &mut batch_by_id,
                        batch_seq,
                        true,
                    );
                }
            }
        }
    }

    let dir = sibling_dir_for_session(path);
    let mut roster = Vec::new();
    for id in order {
        let Some(mut entry) = by_id.remove(&id) else {
            continue;
        };
        entry.insert(
            "batchSeq".into(),
            Value::from(*batch_by_id.get(&id).unwrap_or(&0)),
        );
        if detached.contains(&id) {
            entry.insert("detached".into(), Value::Bool(true));
        }
        if is_valid_subagent_id(&id) {
            let candidate = dir.join(format!("{}.jsonl", id));
            if candidate.exists() {
                entry.insert(
                    "sessionFile".into(),
                    Value::String(candidate.to_string_lossy().into_owned()),
                );
                entry.insert("transcriptAvailable".into(), Value::Bool(true));
                if !entry.contains_key("resolvedModel") {
                    if let Some(model) = transcript_model(&candidate) {
                        entry.insert("resolvedModel".into(), Value::String(model));
                    }
                }
            }
        }
        roster.push(Value::Object(entry));
    }
    roster.sort_by(|a, b| {
        let seq = |v: &Value| v.get("batchSeq").and_then(Value::as_i64).unwrap_or(0);
        let index = |v: &Value| v.get("index").and_then(Value::as_i64).unwrap_or(0);
        let id = |v: &Value| {
            v.get("id")
                .and_then(Value::as_str)
                .unwrap_or("")
                .to_string()
        };
        seq(a)
            .cmp(&seq(b))
            .then(index(a).cmp(&index(b)))
            .then(id(a).cmp(&id(b)))
    });
    roster
}

/// Byte-window transcript paging, mirroring `readSubagentTranscriptPage`.
pub fn read_subagent_transcript_page(cfg: &Config, path: &Path, from_byte: u64) -> Value {
    let mut start = from_byte;
    let mut reset = false;
    let size = match std::fs::metadata(path) {
        Ok(meta) => meta.len(),
        Err(_) => {
            return json!({
                "sessionFile": path.to_string_lossy(),
                "fromByte": start,
                "nextByte": start,
                "reset": false,
                "messages": [],
            })
        }
    };
    if start > size {
        start = 0;
        reset = true;
    }
    if size > MAX_SUBAGENT_TRANSCRIPT_BYTES {
        return json!({
            "sessionFile": path.to_string_lossy(),
            "fromByte": start,
            "nextByte": start,
            "reset": reset,
            "messages": [],
            "error": "Subagent transcript exceeds the readable size limit",
        });
    }
    let end = size.min(start + SUBAGENT_TRANSCRIPT_PAGE_BYTES);
    let window = match read_window(path, start, end) {
        Ok(window) => window,
        Err(_) => {
            return json!({
                "sessionFile": path.to_string_lossy(),
                "fromByte": start,
                "nextByte": start,
                "reset": reset,
                "messages": [],
            })
        }
    };
    let complete = match window.rfind('\n') {
        Some(index) => &window[..=index],
        None => "",
    };
    let entries = crate::omp::session_files::parse_jsonl_lenient(complete);
    let messages: Vec<Value> = entries
        .iter()
        .filter_map(|entry| entry_to_ui_message(cfg, entry, false, false))
        .collect();
    let mut next_byte = start + complete.len() as u64;
    if next_byte == start && end < size {
        next_byte = end;
    }
    json!({
        "sessionFile": path.to_string_lossy(),
        "fromByte": start,
        "nextByte": next_byte,
        "reset": reset,
        "messages": messages,
        "totalBytes": size,
    })
}

fn read_window(path: &Path, start: u64, end: u64) -> std::io::Result<String> {
    use std::io::{Read, Seek, SeekFrom};
    let mut file = std::fs::File::open(path)?;
    file.seek(SeekFrom::Start(start))?;
    let mut buffer = vec![0u8; (end - start) as usize];
    let mut read = 0usize;
    while read < buffer.len() {
        let count = file.read(&mut buffer[read..])?;
        if count == 0 {
            break;
        }
        read += count;
    }
    Ok(String::from_utf8_lossy(&buffer[..read]).into_owned())
}

/// Read a subagent's final `<id>.md` output (bounded, UTF-8 safe).
pub fn read_completion_artifact(path: &Path) -> Option<Value> {
    let meta = std::fs::metadata(path).ok()?;
    if meta.len() == 0 {
        return None;
    }
    let truncated = meta.len() > MAX_SUBAGENT_COMPLETION_BYTES;
    let read = meta.len().min(MAX_SUBAGENT_COMPLETION_BYTES);
    let bytes = read_window(path, 0, read).ok()?;
    let mut owned = bytes.into_bytes();
    // Trim a trailing incomplete UTF-8 sequence.
    while !owned.is_empty() && std::str::from_utf8(&owned).is_err() {
        owned.pop();
    }
    Some(json!({
        "completion": String::from_utf8_lossy(&owned).into_owned(),
        "truncated": truncated,
    }))
}

pub fn path_is_sibling(path: &Path, root: &Path) -> bool {
    path_key(path)
        .rsplit_once('/')
        .map(|(dir, _)| dir == path_key(root))
        .unwrap_or(false)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn subagent_ids_are_bounded_and_grammatical() {
        assert!(is_valid_subagent_id("SwiftOtter"));
        assert!(is_valid_subagent_id("Parent.Child_2-x"));
        assert!(!is_valid_subagent_id(""));
        assert!(!is_valid_subagent_id("../escape"));
        assert!(!is_valid_subagent_id("a..b"));
        assert!(!is_valid_subagent_id(&"a".repeat(101)));
    }
}
