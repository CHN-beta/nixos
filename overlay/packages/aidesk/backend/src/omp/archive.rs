//! Archive listing/restore for gzip-compressed session JSONL files.

use crate::config::Config;
use crate::util::{iso_from_ms, mtime_ms, parse_iso_ms};
use flate2::read::GzDecoder;
use flate2::write::GzEncoder;
use flate2::Compression;
use serde_json::Value;
use std::fs;
use std::io::{Read, Write};
use std::path::{Component, Path, PathBuf};

const ARCHIVE_PREFIX_BYTES: usize = 128 * 1024;
const MAX_ARCHIVE_COMPRESSED_BYTES: u64 = 256 * 1024 * 1024;

fn collect_archives(dir: &Path, files: &mut Vec<PathBuf>) {
    let Ok(entries) = fs::read_dir(dir) else {
        return;
    };
    for entry in entries.flatten() {
        let path = entry.path();
        let Ok(file_type) = entry.file_type() else {
            continue;
        };
        if file_type.is_dir() {
            collect_archives(&path, files);
        } else if file_type.is_file() && path.to_string_lossy().ends_with(".jsonl.gz") {
            files.push(path);
        }
    }
}

fn read_gzip_prefix(path: &Path, limit: usize) -> Option<String> {
    let file = fs::File::open(path).ok()?;
    let mut decoder = GzDecoder::new(file);
    let mut buffer = vec![0u8; limit];
    let mut read = 0usize;
    while read < buffer.len() {
        match decoder.read(&mut buffer[read..]) {
            Ok(0) => break,
            Ok(count) => read += count,
            Err(_) => break,
        }
    }
    Some(String::from_utf8_lossy(&buffer[..read]).into_owned())
}

fn text_from_content(content: &Value) -> String {
    match content {
        Value::String(text) => text.clone(),
        Value::Array(blocks) => blocks
            .iter()
            .filter(|block| block.get("type").and_then(Value::as_str) == Some("text"))
            .filter_map(|block| block.get("text").and_then(Value::as_str))
            .collect::<Vec<_>>()
            .join(" "),
        _ => String::new(),
    }
}

fn parse_archive(path: &Path, archive_root: &Path) -> Option<Value> {
    let meta = fs::metadata(path).ok()?;
    if meta.len() > MAX_ARCHIVE_COMPRESSED_BYTES {
        return None;
    }
    let prefix = read_gzip_prefix(path, ARCHIVE_PREFIX_BYTES)?;
    let lines: Vec<&str> = prefix
        .split('\n')
        .map(str::trim)
        .filter(|line| !line.is_empty())
        .collect();
    let first: Value = serde_json::from_str(lines.first()?).ok()?;
    let mut title = None;
    let mut header_index = 0usize;
    if first.get("type").and_then(Value::as_str) == Some("title") {
        title = first
            .get("title")
            .and_then(Value::as_str)
            .filter(|title| !title.is_empty())
            .map(|title| title.to_string());
        header_index = 1;
    }
    let header: Value = serde_json::from_str(lines.get(header_index)?.trim()).ok()?;
    if header.get("type").and_then(Value::as_str) != Some("session") {
        return None;
    }
    let id = header.get("id").and_then(Value::as_str)?.to_string();
    let mut message_count = 0usize;
    let mut first_message = String::new();
    for line in lines.iter().skip(header_index + 1) {
        let Ok(entry) = serde_json::from_str::<Value>(line) else {
            continue;
        };
        if entry.get("type").and_then(Value::as_str) != Some("message") {
            continue;
        }
        let Some(message) = entry.get("message") else {
            continue;
        };
        message_count += 1;
        if first_message.is_empty() && message.get("role").and_then(Value::as_str) == Some("user") {
            first_message = message
                .get("content")
                .map(text_from_content)
                .unwrap_or_default();
        }
    }
    let created = header
        .get("timestamp")
        .and_then(Value::as_str)
        .and_then(parse_iso_ms)
        .unwrap_or_else(|| mtime_ms(&meta));
    let relative = path
        .strip_prefix(archive_root)
        .unwrap_or(path)
        .to_string_lossy()
        .replace('\\', "/");
    let mut record = serde_json::Map::new();
    record.insert("key".into(), Value::String(relative));
    record.insert("id".into(), Value::String(id));
    record.insert(
        "cwd".into(),
        Value::String(
            header
                .get("cwd")
                .and_then(Value::as_str)
                .unwrap_or("")
                .to_string(),
        ),
    );
    if let Some(name) = title.or_else(|| {
        header
            .get("title")
            .and_then(Value::as_str)
            .filter(|title| !title.is_empty())
            .map(|title| title.to_string())
    }) {
        record.insert("name".into(), Value::String(name));
    }
    record.insert("created".into(), Value::String(iso_from_ms(created)));
    record.insert(
        "archivedAt".into(),
        Value::String(iso_from_ms(mtime_ms(&meta))),
    );
    record.insert("messageCount".into(), Value::from(message_count));
    record.insert(
        "firstMessage".into(),
        Value::String(if first_message.is_empty() {
            "(no messages)".to_string()
        } else {
            first_message
        }),
    );
    record.insert("size".into(), Value::from(meta.len()));
    record.insert("status".into(), Value::String("unknown".into()));
    Some(Value::Object(record))
}

pub fn list_archived_sessions(cfg: &Config) -> Vec<Value> {
    let root = &cfg.archive_dir;
    let mut files = Vec::new();
    collect_archives(root, &mut files);
    let mut records: Vec<Value> = files
        .iter()
        .filter_map(|path| parse_archive(path, root))
        .collect();
    records.sort_by(|a, b| {
        let left = a
            .get("archivedAt")
            .and_then(Value::as_str)
            .and_then(parse_iso_ms)
            .unwrap_or(0.0);
        let right = b
            .get("archivedAt")
            .and_then(Value::as_str)
            .and_then(parse_iso_ms)
            .unwrap_or(0.0);
        right
            .partial_cmp(&left)
            .unwrap_or(std::cmp::Ordering::Equal)
    });
    records
}

fn normalize_archive_key(key: &str) -> Result<String, String> {
    if key.is_empty() || key.contains('\\') || Path::new(key).is_absolute() {
        return Err("Invalid archive key".into());
    }
    let path = Path::new(key);
    if path
        .components()
        .any(|component| !matches!(component, Component::Normal(_)))
        || !key.ends_with(".jsonl.gz")
    {
        return Err("Invalid archive key".into());
    }
    Ok(key.to_string())
}

pub fn restore_archived_session(cfg: &Config, key: &str) -> Result<String, (u16, String)> {
    let relative = normalize_archive_key(key).map_err(|error| (400, error))?;
    let source = cfg.archive_dir.join(&relative);
    let destination = cfg.sessions_dir.join(relative.trim_end_matches(".gz"));
    let source_artifacts = PathBuf::from(source.to_string_lossy().trim_end_matches(".gz"));
    let destination_artifacts =
        PathBuf::from(destination.to_string_lossy().trim_end_matches(".jsonl"));

    let source_real = crate::util::canonical_or_original(&source);
    let archive_root = crate::util::canonical_or_original(&cfg.archive_dir);
    let sessions_root = crate::util::canonical_or_original(&cfg.sessions_dir);
    if !source_real.starts_with(&archive_root) {
        return Err((400, "Invalid archive key".into()));
    }
    if !destination.starts_with(&sessions_root) {
        return Err((400, "Invalid archive key".into()));
    }
    if !source_real.is_file() {
        return Err((404, "Archived session not found".into()));
    }
    if destination.exists() || destination_artifacts.exists() {
        return Err((409, "Active session destination already exists".into()));
    }
    let raw = fs::read(&source_real).map_err(|error| (500, error.to_string()))?;
    let mut decoder = GzDecoder::new(&raw[..]);
    let mut restored = Vec::new();
    decoder
        .read_to_end(&mut restored)
        .map_err(|error| (500, error.to_string()))?;
    if let Some(parent) = destination.parent() {
        fs::create_dir_all(parent).map_err(|error| (500, error.to_string()))?;
    }
    crate::util::atomic_write(&destination, &restored).map_err(|error| (500, error.to_string()))?;

    let mut artifacts_moved = false;
    if source_artifacts.exists() {
        if source_artifacts.is_dir() {
            if let Some(parent) = destination_artifacts.parent() {
                let _ = fs::create_dir_all(parent);
            }
            if fs::rename(&source_artifacts, &destination_artifacts).is_ok() {
                artifacts_moved = true;
            }
        }
    }
    let id = match crate::omp::session_files::load_session_file(&destination, None).header {
        Some(header) => header
            .get("id")
            .and_then(Value::as_str)
            .map(|s| s.to_string()),
        None => None,
    };
    match id {
        Some(id) => {
            let _ = fs::remove_file(&source_real);
            Ok(id)
        }
        None => {
            let _ = fs::remove_file(&destination);
            if artifacts_moved {
                let _ = fs::rename(&destination_artifacts, &source_artifacts);
            }
            Err((500, "Archived session is invalid".into()))
        }
    }
}

/// Compress a session into the archive tree during tests.
pub fn archive_bytes(raw: &[u8]) -> Vec<u8> {
    let mut encoder = GzEncoder::new(Vec::new(), Compression::best());
    let _ = encoder.write_all(raw);
    encoder.finish().unwrap_or_default()
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::omp::session_files::parse_jsonl_lenient;

    #[test]
    fn archive_keys_reject_traversal() {
        assert!(normalize_archive_key("../x.jsonl.gz").is_err());
        assert!(normalize_archive_key("/abs.jsonl.gz").is_err());
        assert!(normalize_archive_key("dir/../x.jsonl.gz").is_err());
        assert!(normalize_archive_key("proj/session.jsonl.gz").is_ok());
    }

    #[test]
    fn gzip_roundtrip_keeps_prefix() {
        let raw = b"{\"type\":\"session\",\"id\":\"abc\"}\n";
        let compressed = archive_bytes(raw);
        let mut decoder = GzDecoder::new(&compressed[..]);
        let mut out = Vec::new();
        decoder.read_to_end(&mut out).unwrap();
        assert_eq!(out, raw);
        assert_eq!(parse_jsonl_lenient(&String::from_utf8_lossy(&out)).len(), 1);
    }
}
