//! Tool-result image handling: content-addressed media URLs.

use crate::state::SharedState;
use crate::util::now_ms;
use base64::Engine;
use serde_json::{json, Map, Value};
use sha2::{Digest, Sha256};
use std::path::Path;

pub const BLOB_PREFIX: &str = "blob:sha256:";

/// Store a base64 image under its content address (sha256) and return the hash.
pub fn store_inline_image(state: &SharedState, base64_data: &str) -> Option<String> {
    let bytes = base64::engine::general_purpose::STANDARD
        .decode(base64_data)
        .ok()?;
    let hash = format!("{:x}", Sha256::digest(&bytes));
    let media_path = state.cfg.media_dir().join(&hash);
    let blob_path = state.cfg.blobs_dir.join(&hash);
    let size_matches = |path: &Path| -> bool {
        std::fs::metadata(path)
            .map(|meta| meta.len() as usize == bytes.len())
            .unwrap_or(false)
    };
    // omp writes blobs in place; keep our own copy unless its blob is complete.
    if !size_matches(&blob_path) && !size_matches(&media_path) {
        let _ = crate::util::atomic_write(&media_path, &bytes);
    }
    Some(hash)
}

fn image_mime(bytes: &[u8]) -> Option<&'static str> {
    if bytes.starts_with(&[0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]) {
        return Some("image/png");
    }
    if bytes.starts_with(&[0xff, 0xd8, 0xff]) {
        return Some("image/jpeg");
    }
    if bytes.starts_with(b"GIF8") {
        return Some("image/gif");
    }
    if bytes.len() > 12 && bytes.starts_with(b"RIFF") && &bytes[8..12] == b"WEBP" {
        return Some("image/webp");
    }
    None
}

/// File for a hash: omp's blob when complete, else AIDesk's copy.
pub fn media_file_path(state: &SharedState, hash: &str) -> Option<std::path::PathBuf> {
    if hash.len() != 64
        || !hash
            .bytes()
            .all(|b| b.is_ascii_hexdigit() && !b.is_ascii_uppercase())
    {
        return None;
    }
    let blob = state.cfg.blobs_dir.join(hash);
    let copy = state.cfg.media_dir().join(hash);
    let blob_size = std::fs::metadata(&blob).ok().map(|meta| meta.len());
    let copy_size = std::fs::metadata(&copy).ok().map(|meta| meta.len());
    match (blob_size, copy_size) {
        (Some(blob_size), Some(copy_size)) => {
            if blob_size == copy_size {
                Some(blob)
            } else {
                Some(copy)
            }
        }
        (Some(_), None) => Some(blob),
        (None, Some(_)) => Some(copy),
        (None, None) => None,
    }
}

pub fn media_mime(bytes: &[u8]) -> Option<&'static str> {
    image_mime(bytes)
}

pub fn existing_thumbnail(state: &SharedState, hash: &str) -> Option<std::path::PathBuf> {
    if hash.len() != 64 {
        return None;
    }
    let thumb = state.cfg.media_dir().join(format!("{}.thumb.webp", hash));
    thumb.exists().then_some(thumb)
}

fn image_block_as_url(state: &SharedState, block: &mut Map<String, Value>) {
    if block.get("type").and_then(Value::as_str) != Some("image") {
        return;
    }
    let data = block
        .get("data")
        .and_then(Value::as_str)
        .map(|s| s.to_string())
        .or_else(|| {
            block
                .get("source")
                .and_then(|source| source.get("data"))
                .and_then(Value::as_str)
                .map(|s| s.to_string())
        });
    let Some(data) = data else { return };
    if data.is_empty() {
        return;
    }
    let mime_type = block
        .get("mimeType")
        .and_then(Value::as_str)
        .map(|s| s.to_string())
        .or_else(|| {
            block
                .get("source")
                .and_then(|source| source.get("media_type"))
                .and_then(Value::as_str)
                .map(|s| s.to_string())
        });
    let hash = if let Some(hash) = data.strip_prefix(BLOB_PREFIX) {
        if hash.len() != 64 {
            return;
        }
        if media_file_path(state, hash).is_none() {
            let mut replacement = Map::new();
            replacement.insert("type".into(), Value::String("text".into()));
            replacement.insert(
                "text".into(),
                Value::String(format!(
                    "[image unavailable: blob {}… not found]",
                    &hash[..12]
                )),
            );
            *block = replacement;
            return;
        }
        hash.to_string()
    } else {
        match store_inline_image(state, &data) {
            Some(hash) => hash,
            None => return,
        }
    };
    let mut replacement = Map::new();
    replacement.insert("type".into(), Value::String("image".into()));
    if let Some(mime_type) = mime_type {
        replacement.insert("mimeType".into(), Value::String(mime_type));
    }
    replacement.insert("url".into(), Value::String(format!("/api/media/{}", hash)));
    *block = replacement;
}

/// Replace every image block inside a tool-result `content` array with a URL.
pub fn tool_result_content_as_urls(state: &SharedState, content: &Value) -> Value {
    let Some(items) = content.as_array() else {
        return content.clone();
    };
    if !items
        .iter()
        .any(|block| block.get("type").and_then(Value::as_str) == Some("image"))
    {
        return content.clone();
    }
    Value::Array(
        items
            .iter()
            .map(|block| {
                let mut block = block.clone();
                if let Some(object) = block.as_object_mut() {
                    if object.get("type").and_then(Value::as_str) == Some("image") {
                        image_block_as_url(state, object);
                    }
                }
                block
            })
            .collect(),
    )
}

fn with_content_as_urls(state: &SharedState, value: &Value) -> Value {
    let Some(object) = value.as_object() else {
        return value.clone();
    };
    let Some(content) = object.get("content") else {
        return value.clone();
    };
    let mapped = tool_result_content_as_urls(state, content);
    if mapped == *content {
        return value.clone();
    }
    let mut out = object.clone();
    out.insert("content".into(), mapped);
    Value::Object(out)
}

fn tool_result_message_as_urls(state: &SharedState, message: &Value) -> Value {
    if message.get("role").and_then(Value::as_str) == Some("toolResult") {
        with_content_as_urls(state, message)
    } else {
        message.clone()
    }
}

fn map_messages(state: &SharedState, value: &Value) -> Value {
    let Some(messages) = value.as_array() else {
        return value.clone();
    };
    let mut changed = false;
    let mapped: Vec<Value> = messages
        .iter()
        .map(|message| {
            let mapped = tool_result_message_as_urls(state, message);
            if mapped != *message {
                changed = true;
            }
            mapped
        })
        .collect();
    if changed {
        Value::Array(mapped)
    } else {
        value.clone()
    }
}

/// An agent event with its tool-result images as media URLs.
pub fn event_with_tool_result_image_urls(state: &SharedState, event: Value) -> Value {
    let Some(object) = event.as_object() else {
        return event;
    };
    let Some(kind) = object.get("type").and_then(Value::as_str) else {
        return event;
    };
    let swap = |key: &str, value: Value| -> Value {
        let mut out = object.clone();
        out.insert(key.to_string(), value);
        Value::Object(out)
    };
    match kind {
        "tool_execution_update" => {
            if let Some(partial) = object.get("partialResult") {
                let mapped = with_content_as_urls(state, partial);
                if mapped != *partial {
                    return swap("partialResult", mapped);
                }
            }
            event
        }
        "tool_execution_end" => {
            if let Some(result) = object.get("result") {
                let mapped = with_content_as_urls(state, result);
                if mapped != *result {
                    return swap("result", mapped);
                }
            }
            event
        }
        "message_start" | "message_end" => {
            if let Some(message) = object.get("message") {
                let mapped = tool_result_message_as_urls(state, message);
                if mapped != *message {
                    return swap("message", mapped);
                }
            }
            event
        }
        "turn_end" => {
            if let Some(results) = object.get("toolResults") {
                let mapped = map_messages(state, results);
                if mapped != *results {
                    return swap("toolResults", mapped);
                }
            }
            event
        }
        "agent_end" => {
            if let Some(messages) = object.get("messages") {
                let mapped = map_messages(state, messages);
                if mapped != *messages {
                    return swap("messages", mapped);
                }
            }
            event
        }
        "subagent_event" => {
            if let Some(payload) = object.get("payload").and_then(Value::as_object) {
                if let Some(inner) = payload.get("event").filter(|event| event.is_object()) {
                    let mapped = event_with_tool_result_image_urls(state, inner.clone());
                    if mapped != *inner {
                        let mut payload = payload.clone();
                        payload.insert("event".into(), mapped);
                        return swap("payload", Value::Object(payload));
                    }
                }
            }
            event
        }
        _ => event,
    }
}

/// Sweep stale AIDesk media copies (daily): drop copies omp now stores as
/// complete blobs and anything older than 30 days.
pub fn sweep_media_cache(state: &SharedState) {
    use std::sync::LazyLock;
    use std::sync::Mutex;
    static LAST_SWEEP: LazyLock<Mutex<f64>> = LazyLock::new(|| Mutex::new(0.0));
    let now = now_ms();
    if let Ok(mut last) = LAST_SWEEP.lock() {
        if now - *last < 24.0 * 60.0 * 60.0 * 1000.0 {
            return;
        }
        *last = now;
    }
    let dir = state.cfg.media_dir();
    let Ok(entries) = std::fs::read_dir(&dir) else {
        return;
    };
    for entry in entries.flatten() {
        let name = entry.file_name().to_string_lossy().into_owned();
        let Ok(meta) = entry.metadata() else { continue };
        let has_blob = name.len() == 64
            && std::fs::metadata(state.cfg.blobs_dir.join(&name))
                .map(|blob| blob.len() == meta.len())
                .unwrap_or(false);
        let expired = crate::util::mtime_ms(&meta) + 30.0 * 24.0 * 60.0 * 60.0 * 1000.0 < now;
        if has_blob || expired {
            let _ = std::fs::remove_file(entry.path());
        }
    }
}

pub fn media_payload(
    state: &SharedState,
    hash: &str,
    thumb: bool,
) -> Option<(Vec<u8>, &'static str, bool)> {
    if thumb {
        if let Some(path) = existing_thumbnail(state, hash) {
            if let Ok(bytes) = std::fs::read(&path) {
                return Some((bytes, "image/webp", true));
            }
        }
    }
    let path = media_file_path(state, hash)?;
    let bytes = std::fs::read(path).ok()?;
    let mime = image_mime(&bytes)?;
    Some((bytes, mime, false))
}

pub fn media_json_placeholder(hash: &str) -> Value {
    json!({ "hash": hash })
}
