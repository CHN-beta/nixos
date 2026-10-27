//! Reader/writer for oh-my-pi's session JSONL files (format v3).
//!
//! Layout: an optional fixed-width 256-byte title-slot line, then the
//! `{"type":"session"}` header line, then entries forming a tree via
//! `(id, parentId)`. Legacy pi v1/v2 files have no title slot and are migrated
//! in memory on load. Image payloads may be externalized as
//! `blob:sha256:<hex>` references into the content-addressed blob store.

use crate::util::{iso_from_ms, mtime_ms, parse_iso_ms, path_key};
use base64::Engine;
use flate2::read::GzDecoder;
use flate2::write::GzEncoder;
use flate2::Compression;
use serde_json::{json, Map, Value};
use std::collections::{HashMap, HashSet};
use std::fs;
use std::io::{Read, Write};
use std::path::{Path, PathBuf};

pub const SESSION_TITLE_SLOT_BYTES: usize = 256;
pub const CURRENT_SESSION_VERSION: i64 = 3;
pub const MAX_SESSION_LOAD_BYTES: u64 = 1024 * 1024 * 1024;
const SESSION_LIST_PREFIX_BYTES: usize = 4096;
const SESSION_LIST_SUFFIX_BYTES: usize = 32_768;
const BLOB_PREFIX: &str = "blob:sha256:";

#[derive(Debug, Clone)]
pub struct TitleSlot {
    pub title: String,
    pub source: Option<String>,
    pub updated_at: String,
}

#[derive(Debug, Clone, Default)]
pub struct LoadedSession {
    pub header: Option<Value>,
    pub entries: Vec<Value>,
    pub title_slot: Option<TitleSlot>,
    pub too_large: bool,
}

#[derive(Debug, Clone)]
pub struct SessionScanInfo {
    pub path: String,
    pub id: String,
    pub cwd: String,
    pub title: Option<String>,
    pub parent_session_path: Option<String>,
    pub created_ms: Option<f64>,
    pub modified_ms: f64,
    pub message_count: usize,
    pub size: u64,
    pub first_message: String,
    pub status: Option<String>,
}

fn truncate_for_slot(title: &str, source: Option<&str>, updated_at: &str) -> String {
    let chars: Vec<char> = title.chars().collect();
    let mut low = 0usize;
    let mut high = chars.len();
    let mut best = String::new();
    while low <= high {
        let mid = (low + high) / 2;
        let candidate: String = chars[..mid].iter().collect();
        let line = title_slot_json(&candidate, source, updated_at, "");
        if line.len() + 1 <= SESSION_TITLE_SLOT_BYTES {
            best = candidate;
            low = mid + 1;
        } else if mid == 0 {
            break;
        } else {
            high = mid - 1;
        }
    }
    best
}

fn title_slot_json(title: &str, source: Option<&str>, updated_at: &str, pad: &str) -> String {
    let mut map = Map::new();
    map.insert("type".into(), Value::String("title".into()));
    map.insert("v".into(), json!(1));
    map.insert("title".into(), Value::String(title.to_string()));
    if let Some(source) = source {
        map.insert("source".into(), Value::String(source.to_string()));
    }
    map.insert("updatedAt".into(), Value::String(updated_at.to_string()));
    map.insert("pad".into(), Value::String(pad.to_string()));
    serde_json::to_string(&Value::Object(map)).unwrap_or_default()
}

/// Serialize a 256-byte title slot (including the trailing newline).
pub fn serialize_title_slot(title: &str, source: Option<&str>, updated_at: &str) -> String {
    let title = truncate_for_slot(title, source, updated_at);
    let unpadded = title_slot_json(&title, source, updated_at, "");
    let total = unpadded.len() + 1;
    if total > SESSION_TITLE_SLOT_BYTES {
        return String::new();
    }
    let pad = " ".repeat(SESSION_TITLE_SLOT_BYTES - total);
    format!("{}\n", title_slot_json(&title, source, updated_at, &pad))
}

pub fn parse_title_slot_line(line: &str) -> Option<TitleSlot> {
    let value: Value = serde_json::from_str(line).ok()?;
    let record = value.as_object()?;
    if record.get("type").and_then(Value::as_str) != Some("title")
        || record.get("v").and_then(Value::as_i64) != Some(1)
    {
        return None;
    }
    let title = record.get("title").and_then(Value::as_str)?;
    let updated_at = record.get("updatedAt").and_then(Value::as_str)?;
    record.get("pad").and_then(Value::as_str)?;
    let source = match record.get("source").and_then(Value::as_str) {
        Some("auto") => Some("auto".to_string()),
        Some("user") => Some("user".to_string()),
        Some(_) => return None,
        None => None,
    };
    Some(TitleSlot {
        title: title.to_string(),
        source,
        updated_at: updated_at.to_string(),
    })
}

pub fn read_title_slot(path: &Path) -> Option<TitleSlot> {
    use std::io::Read;
    let mut file = fs::File::open(path).ok()?;
    let mut buffer = [0u8; SESSION_TITLE_SLOT_BYTES];
    let mut read = 0usize;
    while read < buffer.len() {
        let count = file.read(&mut buffer[read..]).ok()?;
        if count == 0 {
            break;
        }
        read += count;
    }
    let text = String::from_utf8_lossy(&buffer[..read]);
    let newline = text.find('\n')?;
    parse_title_slot_line(&text[..newline])
}

pub fn parse_jsonl_lenient(text: &str) -> Vec<Value> {
    let mut out = Vec::new();
    for line in text.split('\n') {
        let line = line.trim();
        if line.is_empty() {
            continue;
        }
        if let Ok(value) = serde_json::from_str::<Value>(line) {
            out.push(value);
        }
    }
    out
}

fn random_id(taken: &HashSet<String>) -> String {
    for _ in 0..100 {
        let id = uuid::Uuid::new_v4().simple().to_string();
        let id = id[id.len() - 8..].to_string();
        if !taken.contains(&id) {
            return id;
        }
    }
    uuid::Uuid::new_v4().simple().to_string()
}

fn migrate_to_current_version(header: &mut Value, entries: &mut [Value]) {
    let version = header.get("version").and_then(Value::as_i64).unwrap_or(1);
    if version >= CURRENT_SESSION_VERSION {
        return;
    }
    if let Some(object) = header.as_object_mut() {
        object.insert("version".into(), json!(3));
    }
    if version < 2 {
        let mut ids: HashSet<String> = HashSet::new();
        let mut prev: Option<String> = None;
        // `firstKeptEntryIndex` counts physical entries, header at index 0.
        let mut kept_by_index: HashMap<usize, String> = HashMap::new();
        for (position, entry) in entries.iter_mut().enumerate() {
            let id = random_id(&ids);
            ids.insert(id.clone());
            if let Some(object) = entry.as_object_mut() {
                object.insert("id".into(), Value::String(id.clone()));
                object.insert(
                    "parentId".into(),
                    match &prev {
                        Some(parent) => Value::String(parent.clone()),
                        None => Value::Null,
                    },
                );
            }
            kept_by_index.insert(position + 1, id.clone());
            prev = Some(id);
        }
        for entry in entries.iter_mut() {
            if entry.get("type").and_then(Value::as_str) != Some("compaction") {
                continue;
            }
            let Some(index) = entry.get("firstKeptEntryIndex").and_then(Value::as_u64) else {
                continue;
            };
            let target = kept_by_index.get(&(index as usize)).cloned();
            if let (Some(target), Some(object)) = (target, entry.as_object_mut()) {
                object.insert("firstKeptEntryId".into(), Value::String(target));
            }
            if let Some(object) = entry.as_object_mut() {
                object.remove("firstKeptEntryIndex");
            }
        }
    }
    if version < 3 {
        for entry in entries.iter_mut() {
            if entry.get("type").and_then(Value::as_str) != Some("message") {
                continue;
            }
            if let Some(message) = entry.get_mut("message").and_then(Value::as_object_mut) {
                if message.get("role").and_then(Value::as_str) == Some("hookMessage") {
                    message.insert("role".into(), Value::String("custom".into()));
                }
            }
        }
    }
}

fn fold_title_slot(header: &mut Value, slot: &Option<TitleSlot>) {
    let Some(slot) = slot else { return };
    let Some(object) = header.as_object_mut() else {
        return;
    };
    if !slot.title.is_empty() {
        object.insert("title".into(), Value::String(slot.title.clone()));
        match &slot.source {
            Some(source) => {
                object.insert("titleSource".into(), Value::String(source.clone()));
            }
            None => {
                object.remove("titleSource");
            }
        }
    } else {
        object.remove("title");
        object.remove("titleSource");
    }
}

fn parse_header_and_slot(
    first_line: &str,
    second_line: Option<&str>,
) -> Option<(Value, Option<TitleSlot>, bool)> {
    let slot = parse_title_slot_line(first_line);
    let header_line = if slot.is_some() {
        second_line?
    } else {
        first_line
    };
    let header: Value = serde_json::from_str(header_line.trim()).ok()?;
    if header.get("type").and_then(Value::as_str) != Some("session") {
        return None;
    }
    if header.get("id").and_then(Value::as_str).is_none() {
        return None;
    }
    let had_slot = slot.is_some();
    Some((header, slot, had_slot))
}

/// Load and parse a session file (title slot stripped, legacy shapes migrated).
pub fn load_session_file(path: &Path, blobs_dir: Option<&Path>) -> LoadedSession {
    let meta = match fs::metadata(path) {
        Ok(meta) => meta,
        Err(_) => return LoadedSession::default(),
    };
    if meta.len() > MAX_SESSION_LOAD_BYTES {
        return LoadedSession {
            too_large: true,
            ..Default::default()
        };
    }
    let bytes = match fs::read(path) {
        Ok(bytes) => bytes,
        Err(_) => return LoadedSession::default(),
    };
    let text = String::from_utf8_lossy(&bytes);
    let mut records: Vec<Value> = Vec::new();
    let mut title_slot = None;
    let mut is_first_line = true;
    for raw_line in text.split('\n') {
        if is_first_line {
            is_first_line = false;
            if let Some(slot) = parse_title_slot_line(raw_line) {
                title_slot = Some(slot);
                continue;
            }
        }
        let line = raw_line.trim();
        if line.is_empty() {
            continue;
        }
        if let Ok(value) = serde_json::from_str::<Value>(line) {
            records.push(value);
        }
    }
    let header_record = match records.first() {
        Some(header) if header.get("type").and_then(Value::as_str) == Some("session") => {
            header.clone()
        }
        _ => {
            return LoadedSession {
                title_slot,
                ..Default::default()
            }
        }
    };
    let mut header = header_record;
    let mut entries: Vec<Value> = records
        .into_iter()
        .skip(1)
        .filter(|v| v.get("type").and_then(Value::as_str) != Some("session"))
        .collect();
    migrate_to_current_version(&mut header, &mut entries);
    fold_title_slot(&mut header, &title_slot);
    if let Some(blobs_dir) = blobs_dir {
        resolve_blob_refs_in_entries(&mut entries, false, blobs_dir);
    }
    LoadedSession {
        header: Some(header),
        entries,
        title_slot,
        too_large: false,
    }
}

/// Bounded, slot-aware header read (never loads message bodies).
pub fn read_session_header(path: &Path) -> Option<Value> {
    use std::io::Read;
    const MAX_HEADER_BYTES: usize = 64 * 1024 + SESSION_TITLE_SLOT_BYTES;
    let mut file = fs::File::open(path).ok()?;
    let mut buffer = vec![0u8; MAX_HEADER_BYTES];
    let mut read = 0usize;
    while read < buffer.len() {
        let count = file.read(&mut buffer[read..]).ok()?;
        if count == 0 {
            break;
        }
        read += count;
    }
    let head = String::from_utf8_lossy(&buffer[..read]);
    let (first_line, rest) = match head.find('\n') {
        Some(index) => (&head[..index], Some(&head[index + 1..])),
        None => (&head[..], None),
    };
    let first_line = first_line.trim();
    if first_line.is_empty() {
        return None;
    }
    let second_line = rest.map(|rest| match rest.find('\n') {
        Some(index) => &rest[..index],
        None => rest,
    });
    let (mut header, slot, _) = parse_header_and_slot(first_line, second_line)?;
    fold_title_slot(&mut header, &slot);
    Some(header)
}

/// Build the session tree: orphaned entries become extra roots.
pub fn build_session_tree(entries: &[Value]) -> Vec<Value> {
    let mut labels: HashMap<String, String> = HashMap::new();
    for entry in entries {
        if entry.get("type").and_then(Value::as_str) != Some("label") {
            continue;
        }
        let Some(target) = entry.get("targetId").and_then(Value::as_str) else {
            continue;
        };
        match entry.get("label").and_then(Value::as_str) {
            Some(label) if !label.is_empty() => {
                labels.insert(target.to_string(), label.to_string());
            }
            _ => {
                labels.remove(target);
            }
        }
    }

    let mut index_by_id: HashMap<&str, usize> = HashMap::new();
    for (index, entry) in entries.iter().enumerate() {
        if let Some(id) = entry.get("id").and_then(Value::as_str) {
            index_by_id.insert(id, index);
        }
    }
    let mut children: Vec<Vec<usize>> = vec![Vec::new(); entries.len()];
    let mut roots: Vec<usize> = Vec::new();
    for (index, entry) in entries.iter().enumerate() {
        let parent = entry.get("parentId");
        match parent {
            None | Some(Value::Null) => roots.push(index),
            Some(Value::String(parent_id)) => {
                if parent_id == entry.get("id").and_then(Value::as_str).unwrap_or_default() {
                    roots.push(index);
                    continue;
                }
                match index_by_id.get(parent_id.as_str()) {
                    Some(parent_index) => children[*parent_index].push(index),
                    None => roots.push(index),
                }
            }
            _ => roots.push(index),
        }
    }

    let timestamp = |value: &Value| -> f64 {
        value
            .get("timestamp")
            .and_then(Value::as_str)
            .and_then(parse_iso_ms)
            .or_else(|| value.get("timestamp").and_then(Value::as_f64))
            .unwrap_or(0.0)
    };
    for list in children.iter_mut() {
        list.sort_by(|a, b| {
            timestamp(&entries[*a])
                .partial_cmp(&timestamp(&entries[*b]))
                .unwrap_or(std::cmp::Ordering::Equal)
        });
    }

    fn build(
        index: usize,
        entries: &[Value],
        children: &[Vec<usize>],
        labels: &HashMap<String, String>,
        seen: &mut HashSet<usize>,
    ) -> Value {
        let entry = &entries[index];
        let id = entry.get("id").and_then(Value::as_str).unwrap_or_default();
        let mut node = Map::new();
        node.insert("entry".into(), entry.clone());
        if let Some(label) = labels.get(id) {
            node.insert("label".into(), Value::String(label.clone()));
        }
        let mut child_nodes = Vec::new();
        if seen.insert(index) {
            for child in &children[index] {
                if !seen.contains(child) {
                    child_nodes.push(build(*child, entries, children, labels, seen));
                }
            }
        }
        node.insert("children".into(), Value::Array(child_nodes));
        Value::Object(node)
    }

    let mut seen = HashSet::new();
    roots
        .iter()
        .map(|root| build(*root, entries, &children, &labels, &mut seen))
        .collect()
}

pub fn get_leaf_entry_id(entries: &[Value]) -> Option<String> {
    entries
        .last()
        .and_then(|entry| entry.get("id"))
        .and_then(Value::as_str)
        .map(|id| id.to_string())
}

fn extract_text_from_content(content: &Value) -> String {
    if let Some(text) = content.as_str() {
        return text.to_string();
    }
    let Some(blocks) = content.as_array() else {
        return String::new();
    };
    let mut parts = Vec::new();
    for block in blocks {
        if block.get("type").and_then(Value::as_str) == Some("text") {
            if let Some(text) = block.get("text").and_then(Value::as_str) {
                parts.push(text.to_string());
            }
        }
    }
    parts.join(" ")
}

fn status_from_tail_message(message: &Value) -> &'static str {
    match message.get("role").and_then(Value::as_str) {
        Some("assistant") => match message.get("stopReason").and_then(Value::as_str) {
            Some("error") => "error",
            Some("aborted") => "aborted",
            Some("length") => "interrupted",
            _ => {
                if message
                    .get("content")
                    .and_then(Value::as_array)
                    .map(|blocks| {
                        blocks
                            .iter()
                            .any(|b| b.get("type").and_then(Value::as_str) == Some("toolCall"))
                    })
                    .unwrap_or(false)
                {
                    "interrupted"
                } else {
                    "complete"
                }
            }
        },
        Some("toolResult") => "interrupted",
        Some("user") => "pending",
        _ => "unknown",
    }
}

fn derive_session_status(suffix: &str) -> Option<&'static str> {
    if suffix.is_empty() {
        return Some("unknown");
    }
    for line in suffix.split('\n').rev() {
        if !line.starts_with('{') {
            continue;
        }
        let Ok(entry) = serde_json::from_str::<Value>(line) else {
            continue;
        };
        if entry.get("type").and_then(Value::as_str) == Some("message") {
            if let Some(message) = entry.get("message") {
                return Some(status_from_tail_message(message));
            }
        }
    }
    Some("unknown")
}

fn read_text_slices(
    path: &Path,
    prefix_bytes: usize,
    suffix_bytes: usize,
) -> Option<(String, String, u64, f64)> {
    use std::io::{Read, Seek, SeekFrom};
    let meta = fs::metadata(path).ok()?;
    let size = meta.len();
    let mut file = fs::File::open(path).ok()?;
    let prefix_len = size.min(prefix_bytes as u64) as usize;
    let mut prefix_buffer = vec![0u8; prefix_len];
    let mut read = 0usize;
    while read < prefix_len {
        let count = file.read(&mut prefix_buffer[read..]).ok()?;
        if count == 0 {
            break;
        }
        read += count;
    }
    let prefix = String::from_utf8_lossy(&prefix_buffer[..read]).into_owned();
    let suffix_len = size.min(suffix_bytes as u64);
    let mut suffix = String::new();
    if suffix_len > 0 {
        file.seek(SeekFrom::Start(size - suffix_len)).ok()?;
        let mut buffer = vec![0u8; suffix_len as usize];
        let mut read = 0usize;
        while read < buffer.len() {
            let count = file.read(&mut buffer[read..]).ok()?;
            if count == 0 {
                break;
            }
            read += count;
        }
        suffix = String::from_utf8_lossy(&buffer[..read]).into_owned();
    }
    Some((prefix, suffix, size, mtime_ms(&meta)))
}

fn scan_first_user_message(path: &Path) -> String {
    use std::io::{BufRead, BufReader};
    // Stream the file instead of materializing it: session files can be huge,
    // and only the first user message is needed.
    let Ok(file) = fs::File::open(path) else {
        return String::new();
    };
    let mut reader = BufReader::new(file);
    let mut scanned = 0usize;
    let mut line = String::new();
    while let Ok(count) = reader.read_line(&mut line) {
        if count == 0 {
            break;
        }
        scanned += count;
        if scanned > 64 * 1024 * 1024 {
            break;
        }
        let trimmed = line.trim();
        if trimmed.starts_with('{') {
            if let Ok(entry) = serde_json::from_str::<Value>(trimmed) {
                if entry.get("type").and_then(Value::as_str) == Some("message") {
                    if let Some(message) = entry.get("message") {
                        if message.get("role").and_then(Value::as_str) == Some("user") {
                            if let Some(content) = message.get("content") {
                                let text = extract_text_from_content(content);
                                if !text.is_empty() {
                                    return text;
                                }
                            }
                        }
                    }
                }
            }
        }
        line.clear();
    }
    String::new()
}

fn count_message_markers(content: &str) -> usize {
    content.matches("\"type\":\"message\"").count()
        + content.matches("\"type\": \"message\"").count()
}

fn extract_first_display_message_from_prefix(content: &str) -> Option<String> {
    for line in content.split('\n') {
        let line = line.trim();
        if !line.starts_with('{') {
            continue;
        }
        let Ok(entry) = serde_json::from_str::<Value>(line) else {
            continue;
        };
        if entry.get("type").and_then(Value::as_str) != Some("message") {
            continue;
        }
        let message = entry.get("message")?;
        let text = message
            .get("content")
            .map(extract_text_from_content)
            .unwrap_or_default();
        if !text.is_empty() {
            return Some(text);
        }
    }
    None
}

/// Scan a single session file using bounded prefix/suffix windows.
pub fn scan_session_info(path: &Path, with_status: bool) -> Option<SessionScanInfo> {
    let (prefix, suffix, size, modified) = read_text_slices(
        path,
        SESSION_LIST_PREFIX_BYTES,
        if with_status {
            SESSION_LIST_SUFFIX_BYTES
        } else {
            0
        },
    )?;
    let lines: Vec<&str> = prefix
        .split('\n')
        .filter(|line| !line.trim().is_empty())
        .collect();
    let mut title: Option<String> = None;
    let mut header_index = 0usize;
    if let Some(first) = lines.first() {
        if let Some(slot) = parse_title_slot_line(first.trim()) {
            title = if slot.title.trim().is_empty() {
                None
            } else {
                Some(slot.title)
            };
            header_index = 1;
        }
    }
    // The listing window is only 4 KiB; a long first entry (inline config,
    // large system prompt) can truncate the header line. Fall back to the
    // bounded 64 KiB header reader before dropping the session from the list.
    let mut header: Option<Value> = lines
        .get(header_index)
        .and_then(|line| serde_json::from_str(line.trim()).ok());
    if header
        .as_ref()
        .map(|value| value.get("type").and_then(Value::as_str) != Some("session"))
        .unwrap_or(true)
    {
        header = read_session_header(path);
    }
    let header = header?;
    if header.get("type").and_then(Value::as_str) != Some("session") {
        return None;
    }
    let id = header.get("id").and_then(Value::as_str)?.to_string();
    let cwd = header
        .get("cwd")
        .and_then(Value::as_str)
        .unwrap_or("")
        .to_string();
    let header_title = header
        .get("title")
        .and_then(Value::as_str)
        .map(|s| s.to_string());
    let title = title.or(header_title);
    let parent_session_path = header
        .get("parentSession")
        .and_then(Value::as_str)
        .map(|s| s.to_string());
    let created_ms = header
        .get("timestamp")
        .and_then(Value::as_str)
        .and_then(parse_iso_ms);

    let mut parsed_message_count = 0usize;
    let mut first_message = String::new();
    let mut short_summary: Option<String> = None;
    for line in lines.iter().skip(header_index + 1) {
        let Ok(entry) = serde_json::from_str::<Value>(line.trim()) else {
            continue;
        };
        if entry.get("type").and_then(Value::as_str) == Some("compaction") {
            if let Some(summary) = entry.get("shortSummary").and_then(Value::as_str) {
                short_summary = Some(summary.to_string());
            }
        }
        if entry.get("type").and_then(Value::as_str) == Some("message") {
            if let Some(message) = entry.get("message") {
                parsed_message_count += 1;
                if first_message.is_empty()
                    && message.get("role").and_then(Value::as_str) == Some("user")
                {
                    first_message = message
                        .get("content")
                        .map(extract_text_from_content)
                        .unwrap_or_default();
                }
            }
        }
    }
    let first_message = if first_message.is_empty() && size > SESSION_LIST_PREFIX_BYTES as u64 {
        let scanned = scan_first_user_message(path);
        scanned.chars().take(SESSION_LIST_PREFIX_BYTES).collect()
    } else {
        first_message
    };
    let first_message = if first_message.is_empty() {
        extract_first_display_message_from_prefix(&prefix).unwrap_or_default()
    } else {
        first_message
    };
    let message_count = parsed_message_count.max(count_message_markers(&prefix));
    let status = if with_status {
        derive_session_status(&suffix).map(|s| s.to_string())
    } else {
        None
    };
    Some(SessionScanInfo {
        path: path.to_string_lossy().into_owned(),
        id,
        cwd,
        title: title.or(short_summary),
        parent_session_path,
        created_ms,
        modified_ms: modified,
        message_count,
        size,
        first_message: if first_message.is_empty() {
            "(no messages)".to_string()
        } else {
            first_message
        },
        status,
    })
}

/// `<sessionsRoot>/<project>/*.jsonl`, one level deep.
pub fn list_session_files(sessions_root: &Path) -> Vec<PathBuf> {
    let mut files = Vec::new();
    let Ok(entries) = fs::read_dir(sessions_root) else {
        return files;
    };
    for entry in entries.flatten() {
        let Ok(file_type) = entry.file_type() else {
            continue;
        };
        if !file_type.is_dir() {
            continue;
        }
        let dir = entry.path();
        let Ok(inner) = fs::read_dir(&dir) else {
            continue;
        };
        for file in inner.flatten() {
            let is_file = file.file_type().map(|t| t.is_file()).unwrap_or(false);
            if is_file && file.file_name().to_string_lossy().ends_with(".jsonl") {
                files.push(file.path());
            }
        }
    }
    files
}

pub fn clean_session_title(raw: &str) -> String {
    let mut text: String = raw
        .chars()
        .map(|c| if c.is_control() { ' ' } else { c })
        .collect();
    while text.contains("  ") {
        text = text.replace("  ", " ");
    }
    text.trim().to_string()
}

/// Persist a session title: in-place slot rewrite when possible, else atomic
/// whole-file rewrite with a fresh slot.
pub fn set_session_title(path: &Path, title: &str, source: &str) -> bool {
    let cleaned = clean_session_title(title);
    if cleaned.is_empty() {
        return false;
    }
    let updated_at = iso_from_ms(crate::util::now_ms());
    if read_title_slot(path).is_some() {
        let slot_line = serialize_title_slot(&cleaned, Some(source), &updated_at);
        if slot_line.len() != SESSION_TITLE_SLOT_BYTES {
            return false;
        }
        let Ok(mut file) = fs::OpenOptions::new().write(true).open(path) else {
            return false;
        };
        use std::io::{Seek, SeekFrom};
        if file.seek(SeekFrom::Start(0)).is_err() {
            return false;
        }
        return file.write_all(slot_line.as_bytes()).is_ok() && file.flush().is_ok();
    }

    let Ok(meta) = fs::metadata(path) else {
        return false;
    };
    if meta.len() > MAX_SESSION_LOAD_BYTES {
        return false;
    }
    let Ok(content) = fs::read_to_string(path) else {
        return false;
    };
    let mut lines: Vec<String> = content.split('\n').map(|s| s.to_string()).collect();
    let Some(header_index) = lines.iter().position(|line| !line.trim().is_empty()) else {
        return false;
    };
    let Ok(mut header) = serde_json::from_str::<Value>(lines[header_index].trim()) else {
        return false;
    };
    if header.get("type").and_then(Value::as_str) != Some("session") {
        return false;
    }
    if let Some(object) = header.as_object_mut() {
        object.insert("title".into(), Value::String(cleaned.clone()));
        object.insert("titleSource".into(), Value::String(source.to_string()));
    }
    lines[header_index] = serde_json::to_string(&header).unwrap_or_default();
    let mut body = serialize_title_slot(&cleaned, Some(source), &updated_at);
    body.push_str(&lines.join("\n"));
    write_session_file_atomic(path, &body).is_ok()
}

pub fn write_session_file_atomic(path: &Path, body: &str) -> std::io::Result<()> {
    crate::util::atomic_write(path, body.as_bytes())
}

/// Archive one session in omp's gc layout: gzip below the archive root, with
/// the sibling artifacts directory moved alongside.
pub fn archive_session_file_with_artifacts(
    sessions_root: &Path,
    archive_root: &Path,
    file_path: &Path,
) -> Result<PathBuf, String> {
    let source = crate::util::canonical_or_original(file_path);
    let sessions_root = crate::util::canonical_or_original(sessions_root);
    let relative = source
        .strip_prefix(&sessions_root)
        .map_err(|_| "Session path is outside the active OMP sessions directory".to_string())?
        .to_path_buf();
    if relative.as_os_str().is_empty()
        || !relative.to_string_lossy().ends_with(".jsonl")
        || relative
            .components()
            .any(|c| matches!(c, std::path::Component::ParentDir))
    {
        return Err("Session path is outside the active OMP sessions directory".to_string());
    }
    let meta = fs::symlink_metadata(&source).map_err(|e| e.to_string())?;
    if !meta.is_file() {
        return Err("Session path is not a regular file".to_string());
    }
    let archive_root = crate::util::canonical_or_original(archive_root);
    let destination = archive_root.join(format!("{}.gz", relative.to_string_lossy()));
    let legacy_destination = archive_root.join(&relative);
    if destination.exists() || legacy_destination.exists() {
        return Err("Archived session destination already exists".to_string());
    }
    let source_artifacts = PathBuf::from(source.to_string_lossy().trim_end_matches(".jsonl"));
    let destination_text = destination
        .to_string_lossy()
        .trim_end_matches(".gz")
        .to_string();
    let destination_artifacts = PathBuf::from(destination_text);

    if let Some(parent) = destination.parent() {
        fs::create_dir_all(parent).map_err(|e| e.to_string())?;
    }
    let raw = fs::read(&source).map_err(|e| e.to_string())?;
    let mut encoder = GzEncoder::new(Vec::new(), Compression::best());
    encoder.write_all(&raw).map_err(|e| e.to_string())?;
    let compressed = encoder.finish().map_err(|e| e.to_string())?;
    let temp_compressed = destination.with_extension(format!("gz.tmp-{}", uuid::Uuid::new_v4()));
    fs::write(&temp_compressed, &compressed).map_err(|e| e.to_string())?;
    fs::rename(&temp_compressed, &destination).map_err(|e| e.to_string())?;

    let destination_created = true;
    let mut source_removed = false;
    let mut artifacts_moved = false;
    let result = (|| -> Result<(), String> {
        fs::remove_file(&source).map_err(|e| e.to_string())?;
        source_removed = true;
        if source_artifacts.exists() {
            if destination_artifacts.exists() {
                return Err("Archived session artifacts destination already exists".to_string());
            }
            if let Some(parent) = destination_artifacts.parent() {
                fs::create_dir_all(parent).map_err(|e| e.to_string())?;
            }
            fs::rename(&source_artifacts, &destination_artifacts).map_err(|e| e.to_string())?;
            artifacts_moved = true;
        }
        Ok(())
    })();

    if let Err(error) = result {
        if artifacts_moved {
            let _ = fs::rename(&destination_artifacts, &source_artifacts);
        }
        let mut restored = true;
        if source_removed && destination_created {
            restored = false;
            if let Ok(file) = fs::File::open(&destination) {
                let mut decoder = GzDecoder::new(file);
                let mut restored_bytes = Vec::new();
                if decoder.read_to_end(&mut restored_bytes).is_ok() {
                    if let Some(parent) = source.parent() {
                        let _ = fs::create_dir_all(parent);
                    }
                    if fs::write(&source, restored_bytes).is_ok() {
                        restored = true;
                    }
                }
            }
        }
        // Only delete the archive once the source is safely back on disk; a
        // failed restore leaves it as the only copy.
        if destination_created && restored {
            let _ = fs::remove_file(&destination);
        }
        return Err(error);
    }
    Ok(destination)
}

/// Delete a session file and its sibling artifacts directory.
pub fn delete_session_file_with_artifacts(path: &Path) -> std::io::Result<()> {
    fs::remove_file(path)?;
    if path.to_string_lossy().ends_with(".jsonl") {
        let artifacts = PathBuf::from(path.to_string_lossy().trim_end_matches(".jsonl"));
        let _ = fs::remove_dir_all(artifacts);
    }
    Ok(())
}

pub fn contains_blob_ref(value: &Value) -> bool {
    match value {
        Value::String(text) => text.starts_with(BLOB_PREFIX),
        Value::Array(items) => items.iter().any(contains_blob_ref),
        Value::Object(map) => map.values().any(contains_blob_ref),
        _ => false,
    }
}

fn blob_hash(data: &str) -> Option<&str> {
    let hash = data.strip_prefix(BLOB_PREFIX)?;
    if hash.len() == 64
        && hash
            .bytes()
            .all(|b| b.is_ascii_hexdigit() && !b.is_ascii_uppercase())
    {
        Some(hash)
    } else {
        None
    }
}

fn resolve_blobs_in_value(value: &mut Value, key: Option<&str>, blobs_dir: &Path) {
    match value {
        Value::Array(items) => {
            for item in items {
                resolve_blobs_in_value(item, key, blobs_dir);
            }
        }
        Value::Object(map) => {
            let is_image_block = map.get("type").and_then(Value::as_str) == Some("image");
            let data_is_blob = map
                .get("data")
                .and_then(Value::as_str)
                .map(|data| blob_hash(data).is_some())
                .unwrap_or(false);
            let is_image_payload = data_is_blob
                && (is_image_block
                    || map
                        .get("mimeType")
                        .and_then(Value::as_str)
                        .map(|mime| mime.to_ascii_lowercase().starts_with("image/"))
                        .unwrap_or(false));
            if is_image_payload && (key == Some("content") || key == Some("images")) {
                if let Some(hash) = map.get("data").and_then(Value::as_str).and_then(blob_hash) {
                    let hash = hash.to_string();
                    match fs::read(blobs_dir.join(&hash)) {
                        Ok(bytes) => {
                            map.insert(
                                "data".into(),
                                Value::String(
                                    base64::engine::general_purpose::STANDARD.encode(bytes),
                                ),
                            );
                        }
                        Err(_) => {
                            map.insert("type".into(), Value::String("text".into()));
                            map.insert(
                                "text".into(),
                                Value::String(format!(
                                    "[image unavailable: blob {}… not found]",
                                    &hash[..12]
                                )),
                            );
                            map.remove("data");
                            map.remove("mimeType");
                            map.remove("source");
                        }
                    }
                }
                return;
            }
            if map.get("type").and_then(Value::as_str) == Some("image_generation_call") {
                if let Some(hash) = map
                    .get("result")
                    .and_then(Value::as_str)
                    .and_then(blob_hash)
                {
                    let hash = hash.to_string();
                    if let Ok(bytes) = fs::read(blobs_dir.join(&hash)) {
                        map.insert(
                            "result".into(),
                            Value::String(base64::engine::general_purpose::STANDARD.encode(bytes)),
                        );
                    }
                }
            }
            if let Some(hash) = map
                .get("image_url")
                .and_then(Value::as_str)
                .and_then(blob_hash)
            {
                let hash = hash.to_string();
                if let Ok(bytes) = fs::read(blobs_dir.join(&hash)) {
                    map.insert(
                        "image_url".into(),
                        Value::String(String::from_utf8_lossy(&bytes).into_owned()),
                    );
                }
            }
            for (child_key, item) in map.iter_mut() {
                resolve_blobs_in_value(item, Some(child_key), blobs_dir);
            }
        }
        _ => {}
    }
}

pub fn resolve_blob_refs_in_entries(
    entries: &mut [Value],
    skip_tool_result_images: bool,
    blobs_dir: &Path,
) {
    for entry in entries.iter_mut() {
        if skip_tool_result_images
            && entry.get("type").and_then(Value::as_str) == Some("message")
            && entry
                .get("message")
                .and_then(|m| m.get("role"))
                .and_then(Value::as_str)
                == Some("toolResult")
        {
            continue;
        }
        if !contains_blob_ref(entry) {
            continue;
        }
        resolve_blobs_in_value(entry, None, blobs_dir);
    }
}

/// Every `*.jsonl` transcript in a session's artifacts directory.
pub fn list_session_artifact_transcripts(session_file: &Path) -> Vec<PathBuf> {
    let text = session_file.to_string_lossy();
    if !text.ends_with(".jsonl") {
        return Vec::new();
    }
    let root = PathBuf::from(text.trim_end_matches(".jsonl"));
    let mut transcripts = Vec::new();
    let mut pending = vec![root.clone()];
    while let Some(dir) = pending.pop() {
        let Ok(entries) = fs::read_dir(&dir) else {
            continue;
        };
        for entry in entries.flatten() {
            let entry_path = entry.path();
            let Ok(file_type) = entry.file_type() else {
                continue;
            };
            if file_type.is_dir() {
                let skip_local = dir == root && entry.file_name().to_string_lossy() == "local";
                if !skip_local {
                    pending.push(entry_path);
                }
            } else if file_type.is_file() && entry_path.to_string_lossy().ends_with(".jsonl") {
                transcripts.push(entry_path);
            }
        }
    }
    transcripts
}

pub fn session_path_key(path: &Path) -> String {
    path_key(path)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn title_slot_is_fixed_width_and_roundtrips() {
        let line = serialize_title_slot(
            "A useful session title",
            Some("user"),
            "2026-01-02T03:04:05.006Z",
        );
        assert_eq!(line.len(), SESSION_TITLE_SLOT_BYTES);
        assert!(line.ends_with('\n'));
        let slot = parse_title_slot_line(line.trim_end_matches('\n')).expect("slot parses");
        assert_eq!(slot.title, "A useful session title");
        assert_eq!(slot.source.as_deref(), Some("user"));
    }

    #[test]
    fn long_titles_are_truncated_to_fit() {
        let long = "日本語".repeat(200);
        let line = serialize_title_slot(&long, Some("auto"), "2026-01-02T03:04:05.006Z");
        assert_eq!(line.len(), SESSION_TITLE_SLOT_BYTES);
        let slot = parse_title_slot_line(line.trim_end_matches('\n')).unwrap();
        assert!(slot.title.chars().count() < long.chars().count());
    }

    #[test]
    fn lenient_jsonl_skips_torn_lines() {
        let text = "{\"a\":1}\nnot json\n\n{\"b\":2}";
        let values = parse_jsonl_lenient(text);
        assert_eq!(values.len(), 2);
    }

    #[test]
    fn tree_links_children_and_detaches_orphans() {
        let entries = vec![
            json!({"type":"message","id":"a","parentId":null,"timestamp":"2026-01-01T00:00:00.000Z"}),
            json!({"type":"message","id":"b","parentId":"a","timestamp":"2026-01-01T00:00:01.000Z"}),
            json!({"type":"message","id":"c","parentId":"missing","timestamp":"2026-01-01T00:00:02.000Z"}),
        ];
        let tree = build_session_tree(&entries);
        assert_eq!(tree.len(), 2);
        assert_eq!(tree[0]["children"].as_array().unwrap().len(), 1);
    }
}
