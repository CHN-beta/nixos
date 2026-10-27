//! Session reading, tree projection, context building and history paging.

use crate::config::Config;
use crate::omp::session_files::{
    build_session_tree, get_leaf_entry_id, list_session_files, load_session_file,
    read_session_header, resolve_blob_refs_in_entries, scan_session_info, SessionScanInfo,
};
use crate::util::{iso_from_ms, now_ms, parse_iso_ms, path_key, same_path};
use base64::Engine;
use serde::Serialize;
use serde_json::{json, Map, Value};
use sha2::{Digest, Sha256};
use std::collections::{HashMap, HashSet};
use std::path::{Path, PathBuf};
use std::process::Command;
use std::sync::{LazyLock, Mutex};
use std::time::{Duration, Instant};

pub const MAX_SYNC_MESSAGES: usize = 200;

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct SessionInfo {
    pub path: String,
    pub id: String,
    pub cwd: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub name: Option<String>,
    pub created: String,
    pub modified: String,
    pub message_count: usize,
    pub first_message: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub parent_session_id: Option<String>,
    pub project_root: String,
    pub project_key: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub worktree_branch: Option<String>,
}

#[derive(Debug, Clone)]
pub struct ProjectInfo {
    pub project_root: String,
    pub branch: Option<String>,
    pub is_worktree: bool,
}

static PROJECT_CACHE: LazyLock<Mutex<HashMap<String, (ProjectInfo, Instant)>>> =
    LazyLock::new(|| Mutex::new(HashMap::new()));

fn project_cache() -> &'static Mutex<HashMap<String, (ProjectInfo, Instant)>> {
    &PROJECT_CACHE
}

fn git_output(cwd: &Path, args: &[&str]) -> Option<String> {
    let output = Command::new("git")
        .arg("-C")
        .arg(cwd)
        .args(args)
        .env("LC_ALL", "C")
        .output()
        .ok()?;
    if !output.status.success() {
        return None;
    }
    Some(String::from_utf8_lossy(&output.stdout).trim().to_string())
}

fn real_path_or_self(path: &Path) -> PathBuf {
    std::fs::canonicalize(path).unwrap_or_else(|_| path.to_path_buf())
}

/// Resolve a cwd to its project root (linked worktrees collapse to the main
/// checkout only at the worktree top level).
pub fn resolve_project(cwd: &str) -> ProjectInfo {
    let key = path_key(Path::new(cwd));
    if let Ok(cache) = project_cache().lock() {
        if let Some((info, expires)) = cache.get(&key) {
            if *expires > Instant::now() {
                return info.clone();
            }
        }
    }
    let info = compute_project(cwd);
    if let Ok(mut cache) = project_cache().lock() {
        cache.insert(
            key,
            (info.clone(), Instant::now() + Duration::from_secs(60)),
        );
    }
    info
}

fn compute_project(cwd: &str) -> ProjectInfo {
    let path = Path::new(cwd);
    if !path.exists() {
        return ProjectInfo {
            project_root: cwd.to_string(),
            branch: None,
            is_worktree: false,
        };
    }
    let output = git_output(
        path,
        &[
            "rev-parse",
            "--path-format=absolute",
            "--git-common-dir",
            "--git-dir",
            "--show-toplevel",
            "--abbrev-ref",
            "HEAD",
        ],
    );
    let Some(output) = output else {
        return ProjectInfo {
            project_root: real_path_or_self(path).to_string_lossy().into_owned(),
            branch: None,
            is_worktree: false,
        };
    };
    let lines: Vec<&str> = output.lines().map(str::trim).collect();
    if lines.len() < 4 {
        return ProjectInfo {
            project_root: real_path_or_self(path).to_string_lossy().into_owned(),
            branch: None,
            is_worktree: false,
        };
    }
    let common_dir = real_path_or_self(Path::new(lines[0]));
    let git_dir = real_path_or_self(Path::new(lines[1]));
    let toplevel = real_path_or_self(Path::new(lines[2]));
    let reference = lines[3];
    let real_cwd = real_path_or_self(path);
    let is_top_level = same_path(&toplevel, &real_cwd);
    let is_worktree = !same_path(&git_dir, &common_dir) && is_top_level;
    let root = if is_worktree {
        common_dir.parent().unwrap_or(&common_dir).to_path_buf()
    } else if is_top_level {
        toplevel
    } else {
        real_cwd
    };
    ProjectInfo {
        project_root: real_path_or_self(&root).to_string_lossy().into_owned(),
        branch: if reference.is_empty() || reference == "HEAD" {
            None
        } else {
            Some(reference.to_string())
        },
        is_worktree,
    }
}

pub fn invalidate_project_cache() {
    if let Ok(mut cache) = project_cache().lock() {
        cache.clear();
    }
}

fn scan_info_to_session(_cfg: &Config, info: SessionScanInfo) -> SessionInfo {
    let project = if info.cwd.is_empty() {
        ProjectInfo {
            project_root: String::new(),
            branch: None,
            is_worktree: false,
        }
    } else {
        resolve_project(&info.cwd)
    };
    let project_root = if project.project_root.is_empty() {
        info.cwd.clone()
    } else {
        project.project_root.clone()
    };
    let created = info
        .created_ms
        .filter(|ms| ms.is_finite())
        .map(iso_from_ms)
        .unwrap_or_else(|| iso_from_ms(info.modified_ms));
    SessionInfo {
        path: info.path,
        id: info.id,
        cwd: info.cwd,
        name: info.title,
        created,
        modified: iso_from_ms(info.modified_ms),
        message_count: info.message_count,
        first_message: info.first_message,
        parent_session_id: None,
        project_key: path_key(Path::new(&project_root)),
        project_root,
        worktree_branch: if project.is_worktree {
            project.branch
        } else {
            None
        },
    }
}

/// All sessions, newest first, with parent ids resolved from either a path or
/// a bare session id.
///
/// Session listings are hit by nearly every request (roots, file authorization,
/// id resolution), so the scan is cached for a moment and invalidated whenever
/// the server observes a session change.
const SESSION_LIST_CACHE_TTL: Duration = Duration::from_secs(2);

struct SessionListCache {
    root: String,
    expires: Instant,
    sessions: Vec<SessionInfo>,
}

static SESSION_LIST_CACHE: LazyLock<Mutex<Option<SessionListCache>>> =
    LazyLock::new(|| Mutex::new(None));

pub fn invalidate_session_list_cache() {
    if let Ok(mut cache) = SESSION_LIST_CACHE.lock() {
        *cache = None;
    }
}

pub fn list_all_sessions(cfg: &Config) -> Vec<SessionInfo> {
    let root = path_key(&cfg.sessions_dir);
    if let Ok(cache) = SESSION_LIST_CACHE.lock() {
        if let Some(cache) = cache.as_ref() {
            if cache.root == root && cache.expires > Instant::now() {
                return cache.sessions.clone();
            }
        }
    }
    let sessions = scan_all_sessions(cfg);
    if let Ok(mut cache) = SESSION_LIST_CACHE.lock() {
        *cache = Some(SessionListCache {
            root,
            expires: Instant::now() + SESSION_LIST_CACHE_TTL,
            sessions: sessions.clone(),
        });
    }
    sessions
}

fn scan_all_sessions(cfg: &Config) -> Vec<SessionInfo> {
    let files = list_session_files(&cfg.sessions_dir);
    let mut scans: Vec<SessionScanInfo> = Vec::new();
    for file in files {
        if let Some(info) = scan_session_info(&file, true) {
            scans.push(info);
        }
    }
    let mut path_to_id: HashMap<String, String> = HashMap::new();
    let mut known_ids: HashSet<String> = HashSet::new();
    for scan in &scans {
        path_to_id.insert(path_key(Path::new(&scan.path)), scan.id.clone());
        known_ids.insert(scan.id.clone());
    }
    let mut sessions: Vec<SessionInfo> = scans
        .into_iter()
        .map(|scan| {
            let parent = scan.parent_session_path.as_deref().and_then(|parent| {
                path_to_id
                    .get(&path_key(Path::new(parent)))
                    .cloned()
                    .or_else(|| known_ids.contains(parent).then(|| parent.to_string()))
            });
            let mut session = scan_info_to_session(cfg, scan);
            session.parent_session_id = parent;
            session
        })
        .collect();
    sessions.sort_by(|a, b| {
        let left = parse_iso_ms(&b.modified).unwrap_or(0.0);
        let right = parse_iso_ms(&a.modified).unwrap_or(0.0);
        left.partial_cmp(&right)
            .unwrap_or(std::cmp::Ordering::Equal)
    });
    sessions
}

pub fn resolve_session_path(cfg: &Config, id: &str) -> Option<PathBuf> {
    list_all_sessions(cfg)
        .into_iter()
        .find(|session| session.id == id)
        .map(|session| PathBuf::from(session.path))
        .filter(|path| path.exists())
}

pub fn resolve_session_id_by_path(cfg: &Config, path: &Path) -> Option<String> {
    let key = path_key(path);
    list_all_sessions(cfg)
        .into_iter()
        .find(|session| path_key(Path::new(&session.path)) == key)
        .map(|session| session.id)
}

pub fn resolve_parent_session_id(cfg: &Config, parent: &str) -> Option<String> {
    if parent.is_empty() {
        return None;
    }
    if let Some(id) = resolve_session_id_by_path(cfg, Path::new(parent)) {
        return Some(id);
    }
    resolve_session_path(cfg, parent).map(|_| parent.to_string())
}

/// The session ids omp writes are UUIDs. Client-supplied ids that do not have
/// this shape cannot name a session file, so they never widen file access.
pub fn is_valid_session_id(value: &str) -> bool {
    let bytes = value.as_bytes();
    if bytes.len() != 36 {
        return false;
    }
    bytes.iter().enumerate().all(|(index, byte)| {
        if matches!(index, 8 | 13 | 18 | 23) {
            *byte == b'-'
        } else {
            byte.is_ascii_hexdigit()
        }
    })
}

fn is_path_char(ch: char) -> bool {
    ch.is_ascii_alphanumeric()
        || matches!(
            ch,
            '.' | '_' | '~' | '+' | '%' | '@' | '/' | '\\' | ':' | '-'
        )
}

fn has_reference_boundary_after(text: &str, index: usize) -> bool {
    let mut chars = text[index..].chars();
    match chars.next() {
        None => true,
        // `path:12` is a line reference, still the same file.
        Some(':') => chars.next().map(|c| c.is_ascii_digit()).unwrap_or(false),
        Some(ch) => !is_path_char(ch),
    }
}

/// Exact-path containment: `a/foo.rs` must not authorize `a/foo.rs.bak`, and
/// `web/src/x.ts` must not match inside `web/src/x.tsx`.
fn contains_exact_path_reference(text: &str, file_path: &str) -> bool {
    let target = file_path.replace('\\', "/");
    if target.is_empty() {
        return false;
    }
    let targets: Vec<String> = if target.starts_with('/') {
        vec![target.clone(), format!("file://{}", target)]
    } else {
        vec![target]
    };
    let mut haystacks: Vec<String> = vec![text.replace('\\', "/")];
    if let Ok(decoded) = percent_encoding::percent_decode_str(text).decode_utf8() {
        let decoded = decoded.into_owned();
        if decoded != text {
            haystacks.push(decoded.replace('\\', "/"));
        }
    }
    for haystack in haystacks {
        for candidate in &targets {
            let mut search_from = 0usize;
            while let Some(found) = haystack[search_from..].find(candidate.as_str()) {
                let index = search_from + found;
                let before = haystack[..index].chars().next_back();
                let after_index = index + candidate.len();
                let before_ok = before.map(|ch| !is_path_char(ch)).unwrap_or(true);
                if before_ok && has_reference_boundary_after(&haystack, after_index) {
                    return true;
                }
                search_from = index + haystack[index..].chars().next().map_or(1, char::len_utf8);
                if search_from >= haystack.len() {
                    break;
                }
            }
        }
    }
    false
}

fn collect_strings(value: &Value, out: &mut Vec<String>) {
    match value {
        Value::String(text) => out.push(text.clone()),
        Value::Array(items) => {
            for item in items {
                collect_strings(item, out);
            }
        }
        Value::Object(object) => {
            for item in object.values() {
                collect_strings(item, out);
            }
        }
        _ => {}
    }
}

fn normalized_path_targets(target: &Path, home: Option<&Path>) -> Vec<String> {
    let mut absolute: Vec<PathBuf> = Vec::new();
    let lexical = crate::util::normalize_lexically(target);
    absolute.push(lexical);
    if let Ok(real) = std::fs::canonicalize(target) {
        let real = crate::util::normalize_lexically(&real);
        if !absolute.contains(&real) {
            absolute.push(real);
        }
    }
    let home = home.map(|home| crate::util::normalize_lexically(home));
    let mut targets: Vec<String> = Vec::new();
    for path in absolute {
        let text = path.to_string_lossy().replace('\\', "/");
        if !text.is_empty() && !targets.contains(&text) {
            targets.push(text);
        }
        if let Some(home) = &home {
            if let Ok(relative) = path.strip_prefix(home) {
                let relative = relative.to_string_lossy().replace('\\', "/");
                if !relative.is_empty() {
                    let tilde = format!("~/{}", relative);
                    if !targets.contains(&tilde) {
                        targets.push(tilde);
                    }
                }
            }
        }
    }
    targets
}

/// `isFilePathReferencedByEntries`: an entry (message body, tool input, …)
/// names exactly this path, or the same path through `~`.
pub fn path_referenced_by_entries(target: &Path, entries: &[Value], home: Option<&Path>) -> bool {
    let targets = normalized_path_targets(target, home);
    if targets.is_empty() {
        return false;
    }
    entries.iter().any(|entry| {
        let mut strings = Vec::new();
        collect_strings(entry, &mut strings);
        strings.iter().any(|text| {
            targets
                .iter()
                .any(|target| contains_exact_path_reference(text, target))
        })
    })
}

/// `isBashOutputPathReferencedByEntries`: only a bash execution's recorded
/// `fullOutputPath` authorizes reading that log.
pub fn bash_output_referenced_by_entries(target: &Path, entries: &[Value]) -> bool {
    let target_key = path_key(target);
    entries.iter().any(|entry| {
        if entry.get("type").and_then(Value::as_str) != Some("message") {
            return false;
        }
        let Some(message) = entry.get("message") else {
            return false;
        };
        if message.get("role").and_then(Value::as_str) != Some("bashExecution") {
            return false;
        }
        message
            .get("fullOutputPath")
            .and_then(Value::as_str)
            .map(|path| path_key(Path::new(path)) == target_key)
            .unwrap_or(false)
    })
}

fn load_referencing_entries(cfg: &Config, session_id: Option<&str>) -> Option<Vec<Value>> {
    let session_id = session_id.filter(|id| is_valid_session_id(id))?;
    let path = resolve_session_path(cfg, session_id)?;
    let loaded = load_session_file(&path, None);
    if loaded.too_large {
        return None;
    }
    Some(loaded.entries)
}

pub fn is_file_referenced_by_session(
    cfg: &Config,
    target: &Path,
    session_id: Option<&str>,
) -> bool {
    // Only sessions explicitly named by the caller are considered, so this can
    // never widen the allow-list behind a request's back.
    let Some(entries) = load_referencing_entries(cfg, session_id) else {
        return false;
    };
    path_referenced_by_entries(target, &entries, Some(&cfg.home))
}

pub fn is_bash_output_referenced_by_session(
    cfg: &Config,
    target: &Path,
    session_id: Option<&str>,
) -> bool {
    let Some(entries) = load_referencing_entries(cfg, session_id) else {
        return false;
    };
    bash_output_referenced_by_entries(target, &entries)
}

// ============================================================================
// Display entries + context
// ============================================================================

pub fn load_display_entries(
    cfg: &Config,
    path: &Path,
    skip_tool_result_images: bool,
) -> Result<Vec<Value>, bool> {
    let loaded = load_session_file(path, None);
    if loaded.too_large {
        return Err(true);
    }
    let mut entries = loaded.entries;
    resolve_blob_refs_in_entries(&mut entries, skip_tool_result_images, &cfg.blobs_dir);
    Ok(entries)
}

pub fn load_raw_entries(path: &Path) -> Vec<Value> {
    load_session_file(path, None).entries
}

fn normalize_message_timestamp(message: &mut Map<String, Value>) {
    let Some(timestamp) = message.get("timestamp").cloned() else {
        return;
    };
    let normalized = match &timestamp {
        Value::Number(number) => number.as_f64().filter(|v| v.is_finite()).map(Value::from),
        Value::String(text) => parse_iso_ms(text).map(Value::from),
        _ => None,
    };
    match normalized {
        Some(value) => {
            message.insert("timestamp".into(), value);
        }
        None => {
            message.remove("timestamp");
        }
    }
}

fn normalize_tool_calls(message: &mut Map<String, Value>) {
    if message.get("role").and_then(Value::as_str) != Some("assistant") {
        return;
    }
    let Some(content) = message.get_mut("content").and_then(Value::as_array_mut) else {
        return;
    };
    for block in content.iter_mut() {
        let Some(object) = block.as_object_mut() else {
            continue;
        };
        if object.get("type").and_then(Value::as_str) != Some("toolCall") {
            continue;
        }
        let tool_call_id = object
            .get("toolCallId")
            .and_then(Value::as_str)
            .or_else(|| object.get("id").and_then(Value::as_str))
            .unwrap_or("")
            .to_string();
        let tool_name = object
            .get("toolName")
            .and_then(Value::as_str)
            .or_else(|| object.get("name").and_then(Value::as_str))
            .unwrap_or("")
            .to_string();
        let input = object
            .get("input")
            .filter(|v| v.is_object())
            .cloned()
            .or_else(|| object.get("arguments").filter(|v| v.is_object()).cloned())
            .unwrap_or_else(|| Value::Object(Map::new()));
        object.insert("toolCallId".into(), Value::String(tool_call_id));
        object.insert("toolName".into(), Value::String(tool_name));
        object.insert("input".into(), input);
    }
}

fn truncate_task_text(value: &str) -> String {
    let chars: Vec<char> = value.chars().collect();
    if chars.len() <= 240 {
        value.to_string()
    } else {
        format!("{}…", chars[..240].iter().collect::<String>())
    }
}

const TASK_DETAIL_PROGRESS_KEYS: &[&str] = &[
    "index",
    "id",
    "agent",
    "agentSource",
    "status",
    "task",
    "assignment",
    "lastIntent",
    "toolCount",
    "requests",
    "tokens",
    "contextTokens",
    "contextWindow",
    "cost",
    "durationMs",
    "modelRole",
    "resolvedModel",
    "resolvedModelIsFallback",
    "retryFailure",
];

const TASK_DETAIL_RESULT_KEYS: &[&str] = &[
    "index",
    "id",
    "agent",
    "agentSource",
    "status",
    "task",
    "assignment",
    "exitCode",
    "truncated",
    "structuredOutput",
    "durationMs",
    "tokens",
    "requests",
    "contextTokens",
    "contextWindow",
    "modelRole",
    "resolvedModel",
    "resolvedModelIsFallback",
    "error",
    "aborted",
    "abortReason",
    "outputPath",
    "patchPath",
    "branchName",
];

fn truncate_string_fields(record: &mut Map<String, Value>) {
    for key in [
        "task",
        "assignment",
        "error",
        "abortReason",
        "lastIntent",
        "agent",
        "modelRole",
        "resolvedModel",
        "outputPath",
        "patchPath",
        "branchName",
    ] {
        if let Some(value) = record.get(key).and_then(Value::as_str) {
            let truncated = truncate_task_text(value);
            record.insert(key.into(), Value::String(truncated));
        }
    }
}

fn pick_task_rows(raw: &Value, keys: &[&str]) -> Option<Value> {
    let object = raw.as_object()?;
    let mut out = Map::new();
    for key in keys {
        if let Some(value) = object.get(*key) {
            out.insert((*key).to_string(), value.clone());
        }
    }
    truncate_string_fields(&mut out);
    // Settled results carry cost in `usage.cost`, not top-level `cost`.
    if out.get("cost").and_then(Value::as_f64).is_none() {
        if let Some(cost) = task_result_usage_cost(object) {
            out.insert("cost".into(), Value::from(cost));
        }
    }
    // Nested objects are projected to bounded, UI-only shapes.
    if object.contains_key("retryFailure") {
        match task_result_retry_failure(raw.get("retryFailure").unwrap_or(&Value::Null)) {
            Some(value) => {
                out.insert("retryFailure".into(), value);
            }
            None => {
                out.remove("retryFailure");
            }
        }
    }
    if object.contains_key("structuredOutput") {
        match task_result_structured_output(raw.get("structuredOutput").unwrap_or(&Value::Null)) {
            Some(value) => {
                out.insert("structuredOutput".into(), value);
            }
            None => {
                out.remove("structuredOutput");
            }
        }
    }
    Some(Value::Object(out))
}

/// `usage.cost.total`, falling back to input + output when a provider reports
/// only the component costs.
pub(crate) fn task_result_usage_cost(raw: &Map<String, Value>) -> Option<f64> {
    let cost = raw.get("usage")?.get("cost")?;
    if let Some(total) = cost.get("total").and_then(Value::as_f64) {
        if total.is_finite() {
            return Some(total);
        }
    }
    match (
        cost.get("input").and_then(Value::as_f64),
        cost.get("output").and_then(Value::as_f64),
    ) {
        (Some(input), Some(output)) if input.is_finite() && output.is_finite() => {
            Some(input + output)
        }
        _ => None,
    }
}

/// Retry telemetry: both fields must be present or the shape is ignored.
pub(crate) fn task_result_retry_failure(value: &Value) -> Option<Value> {
    let object = value.as_object()?;
    let attempt = object
        .get("attempt")
        .and_then(Value::as_f64)
        .filter(|value| value.is_finite())?;
    let error_message = object.get("errorMessage").and_then(Value::as_str)?;
    Some(json!({
        "attempt": attempt,
        "errorMessage": truncate_task_text(error_message),
    }))
}

/// `structuredOutput.data` is arbitrary upstream payload; only the documented
/// UI fields may ride a bounded history response.
pub(crate) fn task_result_structured_output(value: &Value) -> Option<Value> {
    let object = value.as_object()?;
    let mut out = Map::new();
    for key in ["source", "mode", "status", "error"] {
        if let Some(text) = object.get(key).and_then(Value::as_str) {
            out.insert(key.into(), Value::String(truncate_task_text(text)));
        }
    }
    if out.is_empty() {
        None
    } else {
        Some(Value::Object(out))
    }
}

fn hub_detail_targets(value: Option<&Value>) -> Option<Value> {
    let raw: Vec<&Value> = match value? {
        Value::Array(items) => items.iter().collect(),
        value @ Value::String(_) => vec![value],
        _ => return None,
    };
    let targets: Vec<Value> = raw
        .into_iter()
        .filter_map(Value::as_str)
        .filter(|text| !text.is_empty())
        .take(50)
        .map(|text| Value::String(truncate_task_text(text)))
        .collect();
    if targets.is_empty() {
        None
    } else {
        Some(Value::Array(targets))
    }
}

/// `hub` toolResults keep their delivery/job telemetry (bounded), which the
/// message view renders as a per-target summary.
fn keep_hub_tool_result_details(details: &Map<String, Value>) -> Option<Map<String, Value>> {
    let op = details.get("op").and_then(Value::as_str)?;
    if op != "send" && op != "jobs" {
        return None;
    }
    let mut kept = Map::new();
    kept.insert("op".into(), Value::String(op.to_string()));
    if op == "send" {
        if let Some(to) = hub_detail_targets(details.get("to")) {
            kept.insert("to".into(), to);
        }
        if let Some(receipts) = details.get("receipts").and_then(Value::as_array) {
            let rows: Vec<Value> = receipts
                .iter()
                .take(50)
                .filter_map(|raw| {
                    let object = raw.as_object()?;
                    let mut row = Map::new();
                    for key in ["to", "outcome"] {
                        if let Some(text) = object.get(key).and_then(Value::as_str) {
                            row.insert(key.into(), Value::String(truncate_task_text(text)));
                        }
                    }
                    if row.is_empty() {
                        None
                    } else {
                        Some(Value::Object(row))
                    }
                })
                .collect();
            if !rows.is_empty() {
                kept.insert("receipts".into(), Value::Array(rows));
            }
        }
    } else if let Some(jobs) = details.get("jobs").and_then(Value::as_array) {
        let rows: Vec<Value> = jobs
            .iter()
            .take(50)
            .filter_map(|raw| {
                let object = raw.as_object()?;
                let mut row = Map::new();
                for key in ["id", "type", "status", "label", "resolvedModel"] {
                    if let Some(text) = object.get(key).and_then(Value::as_str) {
                        row.insert(key.into(), Value::String(truncate_task_text(text)));
                    }
                }
                if let Some(duration) = object.get("durationMs").and_then(Value::as_f64) {
                    if duration.is_finite() {
                        row.insert("durationMs".into(), Value::from(duration));
                    }
                }
                if row.is_empty() {
                    None
                } else {
                    Some(Value::Object(row))
                }
            })
            .collect();
        if !rows.is_empty() {
            kept.insert("jobs".into(), Value::Array(rows));
        }
    }
    if kept.len() > 1 {
        Some(kept)
    } else {
        None
    }
}

fn keep_task_tool_result_details(details: &Map<String, Value>) -> Option<Map<String, Value>> {
    let results = details
        .get("results")
        .and_then(Value::as_array)
        .cloned()
        .unwrap_or_default();
    let progress = details
        .get("progress")
        .and_then(Value::as_array)
        .cloned()
        .unwrap_or_default();
    let async_info = details.get("async").and_then(Value::as_object);
    if results.is_empty() && progress.is_empty() && async_info.is_none() {
        return None;
    }
    let mut kept = Map::new();
    if let Some(value) = details.get("totalDurationMs") {
        kept.insert("totalDurationMs".into(), value.clone());
    }
    if let Some(async_info) = async_info {
        let mut info = Map::new();
        for key in ["state", "jobId", "type"] {
            if let Some(value) = async_info.get(key).and_then(Value::as_str) {
                info.insert(key.into(), Value::String(truncate_task_text(value)));
            }
        }
        if !info.is_empty() {
            kept.insert("async".into(), Value::Object(info));
        }
    }
    if !progress.is_empty() {
        kept.insert(
            "progress".into(),
            Value::Array(
                progress
                    .iter()
                    .take(50)
                    .filter_map(|raw| pick_task_rows(raw, TASK_DETAIL_PROGRESS_KEYS))
                    .collect(),
            ),
        );
    }
    if !results.is_empty() {
        kept.insert(
            "results".into(),
            Value::Array(
                results
                    .iter()
                    .take(50)
                    .filter_map(|raw| pick_task_rows(raw, TASK_DETAIL_RESULT_KEYS))
                    .collect(),
            ),
        );
    }
    if kept.is_empty() {
        None
    } else {
        Some(kept)
    }
}

fn strip_tool_result_details(message: &mut Map<String, Value>) {
    if message.get("role").and_then(Value::as_str) != Some("toolResult") {
        return;
    }
    let Some(details) = message.get("details").and_then(Value::as_object).cloned() else {
        return;
    };
    let mut kept = Map::new();
    for key in ["patch", "diff"] {
        if let Some(value) = details.get(key) {
            if value.is_string() {
                kept.insert(key.into(), value.clone());
            }
        }
    }
    let tool_name = message
        .get("toolName")
        .and_then(Value::as_str)
        .unwrap_or("");
    if tool_name == "task" {
        if let Some(task_details) = keep_task_tool_result_details(&details) {
            for (key, value) in task_details {
                kept.insert(key, value);
            }
        }
    }
    if tool_name == "hub" {
        if let Some(hub_details) = keep_hub_tool_result_details(&details) {
            for (key, value) in hub_details {
                kept.insert(key, value);
            }
        }
    }
    if kept.is_empty() {
        message.remove("details");
    } else {
        message.insert("details".into(), Value::Object(kept));
    }
}

/// Store an inline base64 image under its content address (sha256).
pub fn store_inline_image(cfg: &Config, base64_data: &str) -> Option<String> {
    let bytes = base64::engine::general_purpose::STANDARD
        .decode(base64_data)
        .ok()?;
    let hash = format!("{:x}", Sha256::digest(&bytes));
    let media_path = cfg.media_dir().join(&hash);
    let blob_path = cfg.blobs_dir.join(&hash);
    let size_matches = |path: &Path| -> bool {
        std::fs::metadata(path)
            .map(|m| m.len() as usize == bytes.len())
            .unwrap_or(false)
    };
    if !size_matches(&blob_path) && !size_matches(&media_path) {
        let _ = crate::util::atomic_write(&media_path, &bytes);
    }
    Some(hash)
}

fn image_block_as_url(cfg: &Config, block: &mut Map<String, Value>) {
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
                .and_then(|s| s.get("data"))
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
                .and_then(|s| s.get("media_type"))
                .and_then(Value::as_str)
                .map(|s| s.to_string())
        });
    let hash = if let Some(hash) = data.strip_prefix("blob:sha256:") {
        if hash.len() != 64 {
            return;
        }
        let exists = cfg.blobs_dir.join(hash).exists() || cfg.media_dir().join(hash).exists();
        if !exists {
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
        let Some(hash) = store_inline_image(cfg, &data) else {
            return;
        };
        hash
    };
    let mut replacement = Map::new();
    replacement.insert("type".into(), Value::String("image".into()));
    if let Some(mime_type) = mime_type {
        replacement.insert("mimeType".into(), Value::String(mime_type));
    }
    replacement.insert("url".into(), Value::String(format!("/api/media/{}", hash)));
    *block = replacement;
}

fn tool_result_images_as_urls(cfg: &Config, message: &mut Map<String, Value>) {
    if message.get("role").and_then(Value::as_str) != Some("toolResult") {
        return;
    }
    if let Some(content) = message.get_mut("content").and_then(Value::as_array_mut) {
        for block in content.iter_mut() {
            if let Some(object) = block.as_object_mut() {
                if object.get("type").and_then(Value::as_str) == Some("image") {
                    image_block_as_url(cfg, object);
                }
            }
        }
    }
}

fn compaction_ui_message(entry: &Value, active: bool) -> Value {
    const SUPERSEDED: &str = "[Superseded compaction summary elided after a newer compaction]";
    let summary = entry.get("summary").and_then(Value::as_str).unwrap_or("");
    let mut details = Map::new();
    if let Some(value) = entry.get("tokensBefore") {
        details.insert("tokensBefore".into(), value.clone());
    }
    if let Some(value) = entry.get("tokensAfter") {
        details.insert("tokensAfter".into(), value.clone());
    }
    if let Some(value) = entry.get("method") {
        details.insert("method".into(), value.clone());
    }
    if let Some(value) = entry.get("firstKeptEntryId") {
        details.insert("firstKeptEntryId".into(), value.clone());
    }
    let timestamp = entry
        .get("timestamp")
        .and_then(Value::as_str)
        .and_then(parse_iso_ms)
        .map(Value::from)
        .unwrap_or(Value::Null);
    json!({
        "role": "custom",
        "customType": "compaction",
        "content": if active { Value::String(summary.to_string()) } else { Value::String(SUPERSEDED.to_string()) },
        "display": true,
        "details": Value::Object(details),
        "timestamp": timestamp,
    })
}

/// Convert one session entry on the active branch into a UI message.
pub fn entry_to_ui_message(
    cfg: &Config,
    entry: &Value,
    defer_thinking: bool,
    defer_media: bool,
) -> Option<Value> {
    match entry.get("type").and_then(Value::as_str)? {
        "message" => {
            let raw = entry.get("message")?.as_object()?;
            let role = raw.get("role").and_then(Value::as_str).unwrap_or("");
            let timestamp = || {
                raw.get("timestamp")
                    .and_then(Value::as_f64)
                    .or_else(|| {
                        raw.get("timestamp")
                            .and_then(Value::as_str)
                            .and_then(parse_iso_ms)
                    })
                    .map(Value::from)
                    .unwrap_or(Value::Null)
            };
            match role {
                "developer" => {
                    let passive =
                        raw.get("passiveToolContext").and_then(Value::as_bool) == Some(true);
                    return Some(json!({
                        "role": "custom",
                        "customType": if passive { "passive-tool-context" } else { "developer" },
                        "content": raw.get("content").cloned().unwrap_or(Value::Null),
                        "display": !passive,
                        "timestamp": timestamp(),
                    }));
                }
                "pythonExecution" => {
                    let code = raw.get("code").and_then(Value::as_str).unwrap_or("");
                    let output = raw.get("output").and_then(Value::as_str).unwrap_or("");
                    let output_block = if output.is_empty() {
                        "\n(no output)".to_string()
                    } else {
                        format!("\n```\n{}\n```", output)
                    };
                    let status = if raw.get("cancelled").and_then(Value::as_bool) == Some(true) {
                        "\n(execution cancelled)".to_string()
                    } else {
                        match raw.get("exitCode").and_then(Value::as_i64) {
                            Some(code) if code != 0 => {
                                format!("\nExecution failed with code {}", code)
                            }
                            _ => String::new(),
                        }
                    };
                    return Some(json!({
                        "role": "custom",
                        "customType": "python-execution",
                        "content": format!("Ran Python:\n```python\n{}\n```{}{}", code, output_block, status),
                        "display": true,
                        "timestamp": timestamp(),
                    }));
                }
                "fileMention" => {
                    let files: Vec<String> = raw
                        .get("files")
                        .and_then(Value::as_array)
                        .map(|items| {
                            items
                                .iter()
                                .filter_map(|item| item.get("path").and_then(Value::as_str))
                                .map(|path| format!("- {}", path))
                                .collect()
                        })
                        .unwrap_or_default();
                    return Some(json!({
                        "role": "custom",
                        "customType": "file-mention",
                        "content": format!(
                            "Attached file{}:\n{}",
                            if files.len() == 1 { "" } else { "s" },
                            files.join("\n")
                        ),
                        "display": true,
                        "timestamp": timestamp(),
                    }));
                }
                _ => {}
            }

            let mut message = raw.clone();
            normalize_tool_calls(&mut message);
            if defer_media {
                // Blob refs are still unresolved here for tool results; convert.
                tool_result_images_as_urls(cfg, &mut message);
            }
            strip_tool_result_details(&mut message);
            if defer_thinking && message.get("role").and_then(Value::as_str) == Some("assistant") {
                if let Some(content) = message.get_mut("content").and_then(Value::as_array_mut) {
                    for block in content.iter_mut() {
                        if let Some(object) = block.as_object_mut() {
                            if object.get("type").and_then(Value::as_str) == Some("thinking") {
                                let has_text = object
                                    .get("thinking")
                                    .and_then(Value::as_str)
                                    .map(|text| !text.trim().is_empty())
                                    .unwrap_or(false);
                                if has_text {
                                    object.insert("thinking".into(), Value::String(String::new()));
                                    object.insert("deferred".into(), Value::Bool(true));
                                }
                            }
                        }
                    }
                }
            }
            normalize_message_timestamp(&mut message);
            Some(Value::Object(message))
        }
        "branch_summary" => {
            let summary = entry.get("summary").and_then(Value::as_str)?;
            if summary.is_empty() {
                return None;
            }
            Some(json!({
                "role": "user",
                "content": format!("*The conversation briefly explored another branch and returned with this summary:*\n\n{}", summary),
                "timestamp": entry.get("timestamp").and_then(Value::as_str).and_then(parse_iso_ms).map(Value::from).unwrap_or(Value::Null),
                "branchSummary": true,
            }))
        }
        "custom_message" => Some(json!({
            "role": "custom",
            "customType": entry.get("customType").cloned().unwrap_or(Value::Null),
            "content": entry.get("content").cloned().unwrap_or(Value::Null),
            "display": entry.get("display").cloned().unwrap_or(Value::Bool(true)),
            "details": entry.get("details").cloned().unwrap_or(Value::Null),
            "timestamp": entry.get("timestamp").and_then(Value::as_str).and_then(parse_iso_ms).map(Value::from).unwrap_or(Value::Null),
        })),
        _ => None,
    }
}

fn parse_todo_phases(value: &Value) -> Option<Value> {
    let phases = value.as_array()?;
    let mut out = Vec::new();
    for phase in phases {
        let object = phase.as_object()?;
        let name = object.get("name").and_then(Value::as_str)?;
        let tasks = object.get("tasks").and_then(Value::as_array)?;
        let mut parsed_tasks = Vec::new();
        for task in tasks {
            let task = task.as_object()?;
            let content = task.get("content").and_then(Value::as_str)?;
            let status = task.get("status").and_then(Value::as_str)?;
            if ![
                "pending",
                "in_progress",
                "completed",
                "blocked",
                "abandoned",
            ]
            .contains(&status)
            {
                return None;
            }
            let mut parsed = Map::new();
            parsed.insert("content".into(), Value::String(content.to_string()));
            parsed.insert("status".into(), Value::String(status.to_string()));
            if let Some(blocker) = task.get("blocker").and_then(Value::as_str) {
                parsed.insert("blocker".into(), Value::String(blocker.to_string()));
            }
            parsed_tasks.push(Value::Object(parsed));
        }
        out.push(json!({ "name": name, "tasks": parsed_tasks }));
    }
    Some(Value::Array(out))
}

fn todo_phases(entries: &[Value], leaf_id: Option<&str>) -> Value {
    if entries.is_empty() {
        return Value::Array(Vec::new());
    }
    let by_id: HashMap<&str, &Value> = entries
        .iter()
        .filter_map(|entry| {
            entry
                .get("id")
                .and_then(Value::as_str)
                .map(|id| (id, entry))
        })
        .collect();
    let mut current: Option<&Value> = match leaf_id {
        Some("") => return Value::Array(Vec::new()),
        Some(id) => by_id.get(id).copied(),
        None => entries.last(),
    };
    let mut path = Vec::new();
    let mut seen = HashSet::new();
    while let Some(entry) = current {
        let id = entry.get("id").and_then(Value::as_str).unwrap_or_default();
        if !seen.insert(id.to_string()) {
            break;
        }
        path.push(entry);
        current = entry
            .get("parentId")
            .and_then(Value::as_str)
            .and_then(|parent| by_id.get(parent).copied());
    }
    for entry in path {
        if entry.get("type").and_then(Value::as_str) == Some("custom")
            && entry.get("customType").and_then(Value::as_str) == Some("user_todo_edit")
        {
            if let Some(phases) = entry.get("data").and_then(|d| d.get("phases")) {
                if let Some(parsed) = parse_todo_phases(phases) {
                    return parsed;
                }
            }
        }
        if entry.get("type").and_then(Value::as_str) == Some("message") {
            let Some(message) = entry.get("message").and_then(Value::as_object) else {
                continue;
            };
            if message.get("role").and_then(Value::as_str) != Some("toolResult")
                || message.get("toolName").and_then(Value::as_str) != Some("todo")
                || message.get("isError").and_then(Value::as_bool) == Some(true)
            {
                continue;
            }
            if let Some(phases) = message.get("details").and_then(|d| d.get("phases")) {
                if let Some(parsed) = parse_todo_phases(phases) {
                    return parsed;
                }
            }
        }
    }
    Value::Array(Vec::new())
}

#[derive(Debug, Clone, Copy, Default)]
pub struct ContextOptions {
    pub defer_thinking: bool,
    pub defer_media: bool,
    pub include_pre_compaction: bool,
}

struct SelectedContext {
    selected: Vec<Value>,
    compaction_id: Option<String>,
    thinking_level: String,
    model: Value,
    todo_phases: Value,
}

fn select_context(
    entries: &[Value],
    leaf_id: Option<&str>,
    options: ContextOptions,
) -> SelectedContext {
    let empty = SelectedContext {
        selected: Vec::new(),
        compaction_id: None,
        thinking_level: "off".to_string(),
        model: Value::Null,
        todo_phases: todo_phases(entries, leaf_id),
    };
    let by_id: HashMap<&str, &Value> = entries
        .iter()
        .filter_map(|entry| {
            entry
                .get("id")
                .and_then(Value::as_str)
                .map(|id| (id, entry))
        })
        .collect();
    if leaf_id == Some("") {
        return empty;
    }
    let leaf = leaf_id
        .filter(|id| !id.is_empty())
        .and_then(|id| by_id.get(id).copied())
        .or_else(|| entries.last());
    let Some(leaf) = leaf else {
        return empty;
    };
    let mut path: Vec<&Value> = Vec::new();
    let mut seen = HashSet::new();
    let mut current = Some(leaf);
    while let Some(entry) = current {
        let id = entry.get("id").and_then(Value::as_str).unwrap_or_default();
        if !seen.insert(id.to_string()) {
            break;
        }
        path.push(entry);
        current = entry
            .get("parentId")
            .and_then(Value::as_str)
            .and_then(|parent| by_id.get(parent).copied());
    }
    path.reverse();

    let mut thinking_level = "off".to_string();
    let mut models: HashMap<String, String> = HashMap::new();
    let mut has_explicit_default = false;
    let mut compaction: Option<&Value> = None;
    for entry in &path {
        match entry.get("type").and_then(Value::as_str) {
            Some("thinking_level_change") => {
                thinking_level = entry
                    .get("thinkingLevel")
                    .and_then(Value::as_str)
                    .unwrap_or("off")
                    .to_string();
            }
            Some("model_change") => {
                if let Some(model) = entry.get("model").and_then(Value::as_str) {
                    let role = entry
                        .get("role")
                        .and_then(Value::as_str)
                        .unwrap_or("default");
                    models.insert(role.to_string(), model.to_string());
                    if role == "default" {
                        has_explicit_default = true;
                    }
                } else if let (Some(provider), Some(model_id)) = (
                    entry.get("provider").and_then(Value::as_str),
                    entry.get("modelId").and_then(Value::as_str),
                ) {
                    models.insert("default".to_string(), format!("{}/{}", provider, model_id));
                    has_explicit_default = true;
                }
            }
            Some("message") => {
                let Some(message) = entry.get("message").and_then(Value::as_object) else {
                    continue;
                };
                if message.get("role").and_then(Value::as_str) == Some("assistant")
                    && !has_explicit_default
                {
                    if let (Some(provider), Some(model)) = (
                        message.get("provider").and_then(Value::as_str),
                        message.get("model").and_then(Value::as_str),
                    ) {
                        models.insert("default".to_string(), format!("{}/{}", provider, model));
                    }
                }
            }
            Some("compaction") => compaction = Some(entry),
            _ => {}
        }
    }

    let mut selected: Vec<Value> = Vec::new();
    let include = |entry: &Value| -> bool {
        matches!(
            entry.get("type").and_then(Value::as_str),
            Some("compaction") | Some("custom_message")
        ) || (entry.get("type").and_then(Value::as_str) == Some("message")
            && entry.get("message").map(Value::is_object).unwrap_or(false))
            || (entry.get("type").and_then(Value::as_str) == Some("branch_summary")
                && entry
                    .get("summary")
                    .and_then(Value::as_str)
                    .map(|s| !s.is_empty())
                    .unwrap_or(false))
    };

    if let Some(active_compaction) = compaction.filter(|_| !options.include_pre_compaction) {
        selected.push(active_compaction.clone());
        let compaction_id = active_compaction
            .get("id")
            .and_then(Value::as_str)
            .unwrap_or("");
        let compaction_index = path
            .iter()
            .position(|entry| {
                entry.get("type").and_then(Value::as_str) == Some("compaction")
                    && entry.get("id").and_then(Value::as_str).unwrap_or("") == compaction_id
            })
            .unwrap_or(0);
        let first_kept = active_compaction
            .get("firstKeptEntryId")
            .and_then(Value::as_str);
        let mut found_first_kept = false;
        for entry in path.iter().take(compaction_index) {
            if Some(entry.get("id").and_then(Value::as_str).unwrap_or("")) == first_kept {
                found_first_kept = true;
            }
            if found_first_kept && include(entry) {
                selected.push((*entry).clone());
            }
        }
        for entry in path.iter().skip(compaction_index + 1) {
            if include(entry) {
                selected.push((*entry).clone());
            }
        }
    } else {
        for entry in &path {
            if include(entry) {
                selected.push((*entry).clone());
            }
        }
    }

    let model = match models.get("default") {
        Some(default_model) => match default_model.find('/') {
            Some(index) if index > 0 => json!({
                "provider": &default_model[..index],
                "modelId": &default_model[index + 1..],
            }),
            _ => json!({ "provider": "", "modelId": default_model }),
        },
        None => Value::Null,
    };

    SelectedContext {
        compaction_id: compaction
            .and_then(|entry| entry.get("id"))
            .and_then(Value::as_str)
            .map(|s| s.to_string()),
        selected,
        thinking_level,
        model,
        todo_phases: todo_phases(entries, leaf_id),
    }
}

pub fn build_session_context(
    cfg: &Config,
    entries: &[Value],
    leaf_id: Option<&str>,
    options: ContextOptions,
) -> Value {
    let selected = select_context(entries, leaf_id, options);
    let mut messages = Vec::new();
    let mut entry_ids = Vec::new();
    for entry in &selected.selected {
        if entry.get("type").and_then(Value::as_str) == Some("compaction") {
            let active =
                entry.get("id").and_then(Value::as_str) == selected.compaction_id.as_deref();
            messages.push(compaction_ui_message(entry, active));
        } else if let Some(message) =
            entry_to_ui_message(cfg, entry, options.defer_thinking, options.defer_media)
        {
            messages.push(message);
        } else {
            continue;
        }
        entry_ids.push(entry.get("id").cloned().unwrap_or(Value::Null));
    }
    json!({
        "messages": messages,
        "entryIds": entry_ids,
        "thinkingLevel": selected.thinking_level,
        "model": selected.model,
        "todoPhases": selected.todo_phases,
    })
}

/// Project the full tree into the shallow navigation tree the client renders.
pub fn project_tree_for_response(nodes: Vec<Value>) -> Vec<Value> {
    const MAX_DEPTH: usize = 200;

    fn entry_id(node: &Value) -> String {
        node.get("entry")
            .and_then(|entry| entry.get("id"))
            .and_then(Value::as_str)
            .unwrap_or("")
            .to_string()
    }

    fn branch_preview(entry: &Value) -> Option<Value> {
        if entry.get("type").and_then(Value::as_str) != Some("message") {
            return None;
        }
        let message = entry.get("message")?.as_object()?;
        let mut text = match message.get("content") {
            Some(Value::String(text)) => text.clone(),
            Some(Value::Array(blocks)) => blocks
                .iter()
                .filter(|block| block.get("type").and_then(Value::as_str) == Some("text"))
                .filter_map(|block| block.get("text").and_then(Value::as_str))
                .collect::<Vec<_>>()
                .join(" "),
            _ => String::new(),
        };
        text = text.split_whitespace().collect::<Vec<_>>().join(" ");
        let chars: Vec<char> = text.chars().collect();
        if chars.len() > 40 {
            text = format!("{}…", chars[..40].iter().collect::<String>());
        }
        if text.is_empty() {
            text = if message.get("role").and_then(Value::as_str) == Some("assistant") {
                "[assistant]".to_string()
            } else {
                "message".to_string()
            };
        }
        let mut preview = Map::new();
        if let Some(role) = message.get("role").and_then(Value::as_str) {
            if role == "user" || role == "assistant" {
                preview.insert("role".into(), Value::String(role.to_string()));
            }
        }
        preview.insert("text".into(), Value::String(text));
        Some(Value::Object(preview))
    }

    // Keep roots and branch points (not exactly one child), contracting chains.
    let mut keep: HashSet<String> = HashSet::new();
    for root in &nodes {
        keep.insert(entry_id(root));
    }
    let mut stack: Vec<&Value> = nodes.iter().collect();
    while let Some(node) = stack.pop() {
        let children = node.get("children").and_then(Value::as_array);
        if children.map(|c| c.len()).unwrap_or(0) != 1 {
            keep.insert(entry_id(node));
        }
        if let Some(children) = children {
            for child in children {
                stack.push(child);
            }
        }
    }

    fn clone_node(node: &Value, compressed: &[Value], preview: Option<Value>) -> Value {
        let mut object = node.as_object().cloned().unwrap_or_default();
        object.insert("children".into(), Value::Array(Vec::new()));
        if !compressed.is_empty() {
            object.insert(
                "compressedEntryIds".into(),
                Value::Array(compressed.to_vec()),
            );
        }
        if let Some(preview) = preview {
            object.insert("branchPreview".into(), preview);
        }
        Value::Object(object)
    }

    fn children_of(node: &Value) -> Vec<Value> {
        node.get("children")
            .and_then(Value::as_array)
            .cloned()
            .unwrap_or_default()
    }

    fn preview_of(node: &Value) -> Option<Value> {
        branch_preview(node.get("entry").unwrap_or(&Value::Null))
    }

    // At the depth ceiling the remaining kept nodes are flattened into one list.
    fn append_kept_descendants(
        source: &Value,
        projected_parent: &mut Value,
        keep: &HashSet<String>,
    ) {
        let mut pending: Vec<(Value, Vec<Value>, Option<Value>)> =
            vec![(source.clone(), Vec::new(), None)];
        let mut seen: HashSet<String> = HashSet::new();
        while let Some((node, compressed, preview)) = pending.pop() {
            let id = entry_id(&node);
            if !seen.insert(id.clone()) {
                continue;
            }
            let is_kept = keep.contains(&id);
            if is_kept {
                if let Some(children) = projected_parent
                    .get_mut("children")
                    .and_then(Value::as_array_mut)
                {
                    children.push(clone_node(
                        &node,
                        &compressed,
                        preview.clone().or_else(|| preview_of(&node)),
                    ));
                }
            }
            for child in children_of(&node).into_iter().rev() {
                let next_compressed = if is_kept {
                    Vec::new()
                } else {
                    let mut next = compressed.clone();
                    next.push(Value::String(id.clone()));
                    next
                };
                let next_preview = if is_kept {
                    None
                } else {
                    preview.clone().or_else(|| preview_of(&node))
                };
                pending.push((child, next_compressed, next_preview));
            }
        }
    }

    fn expand(source: &Value, projected_parent: &mut Value, depth: usize, keep: &HashSet<String>) {
        for mut child in children_of(source) {
            if depth >= MAX_DEPTH {
                append_kept_descendants(&child, projected_parent, keep);
                continue;
            }
            let mut compressed: Vec<Value> = Vec::new();
            let mut preview = preview_of(&child);
            loop {
                let id = entry_id(&child);
                if keep.contains(&id) {
                    break;
                }
                let grandchildren = children_of(&child);
                if grandchildren.len() != 1 {
                    break;
                }
                compressed.push(Value::String(id));
                child = grandchildren[0].clone();
                if preview.is_none() {
                    preview = preview_of(&child);
                }
            }
            if !keep.contains(&entry_id(&child)) {
                continue;
            }
            let mut projected_child = clone_node(&child, &compressed, preview);
            expand(&child, &mut projected_child, depth + 1, keep);
            if let Some(children) = projected_parent
                .get_mut("children")
                .and_then(Value::as_array_mut)
            {
                children.push(projected_child);
            }
        }
    }

    let mut projected = Vec::new();
    for root in &nodes {
        let mut projected_root = clone_node(root, &[], preview_of(root));
        expand(root, &mut projected_root, 1, &keep);
        projected.push(projected_root);
    }
    projected
}

/// Full display payload pieces for `GET /api/sessions/{id}`.
pub struct SessionDetail {
    pub info: Value,
    pub leaf_id: Option<String>,
    pub tree: Vec<Value>,
    pub context: Value,
}

pub fn session_detail(
    cfg: &Config,
    path: &Path,
    header: &Value,
    defer_thinking: bool,
    defer_media: bool,
) -> Result<SessionDetail, bool> {
    let entries = load_display_entries(cfg, path, defer_media)?;
    let leaf_id = get_leaf_entry_id(&entries);
    let tree = project_tree_for_response(build_session_tree(&entries));
    let context = build_session_context(
        cfg,
        &entries,
        leaf_id.as_deref(),
        ContextOptions {
            defer_thinking,
            defer_media,
            include_pre_compaction: false,
        },
    );
    let message_count = context
        .get("messages")
        .and_then(Value::as_array)
        .map(|messages| messages.len())
        .unwrap_or(0);
    let first_message = context
        .get("messages")
        .and_then(Value::as_array)
        .and_then(|messages| {
            messages
                .iter()
                .find(|message| message.get("role").and_then(Value::as_str) == Some("user"))
                .map(|message| match message.get("content") {
                    Some(Value::String(text)) => text.clone(),
                    Some(Value::Array(blocks)) => blocks
                        .iter()
                        .find(|block| block.get("type").and_then(Value::as_str) == Some("text"))
                        .and_then(|block| block.get("text").and_then(Value::as_str))
                        .unwrap_or("")
                        .to_string(),
                    _ => String::new(),
                })
                .filter(|text| !text.is_empty())
        })
        .unwrap_or_else(|| "(no messages)".to_string());
    let modified = std::fs::metadata(path)
        .map(|meta| crate::util::mtime_ms(&meta))
        .unwrap_or(0.0);
    let created = header
        .get("timestamp")
        .and_then(Value::as_str)
        .filter(|value| parse_iso_ms(value).is_some())
        .map(|value| value.to_string())
        .unwrap_or_else(|| iso_from_ms(modified));
    let info = json!({
        "path": path.to_string_lossy(),
        "id": header.get("id").cloned().unwrap_or(Value::Null),
        "cwd": header.get("cwd").and_then(Value::as_str).unwrap_or(""),
        "name": header.get("title").cloned().unwrap_or(Value::Null),
        "created": created,
        "modified": iso_from_ms(modified),
        "messageCount": message_count,
        "firstMessage": first_message,
        "parentSessionId": header.get("parentSession").and_then(Value::as_str)
            .and_then(|parent| resolve_parent_session_id(cfg, parent))
            .map(Value::from)
            .unwrap_or(Value::Null),
    });
    Ok(SessionDetail {
        info,
        leaf_id,
        tree,
        context,
    })
}

// ============================================================================
// History paging (sync=1)
// ============================================================================

#[derive(Debug, Clone, Default)]
pub struct HistoryCursor {
    pub first_entry_id: Option<String>,
    pub last_entry_id: Option<String>,
}

pub fn parse_history_cursor(raw: Option<&str>) -> Result<Option<HistoryCursor>, ()> {
    let Some(raw) = raw else { return Ok(None) };
    if raw.len() > 2048 {
        return Err(());
    }
    let value: Value = serde_json::from_str(raw).map_err(|_| ())?;
    let object = value.as_object().ok_or(())?;
    let valid_id = |value: Option<&Value>| -> Result<Option<String>, ()> {
        match value {
            None | Some(Value::Null) => Ok(None),
            Some(Value::String(text)) if !text.is_empty() && text.len() <= 256 => {
                Ok(Some(text.clone()))
            }
            _ => Err(()),
        }
    };
    let first = valid_id(object.get("firstEntryId"))?;
    let last = valid_id(object.get("lastEntryId"))?;
    if first.is_some() != last.is_some() {
        return Err(());
    }
    Ok(Some(HistoryCursor {
        first_entry_id: first,
        last_entry_id: last,
    }))
}

pub struct HistoryRange {
    pub mode: &'static str,
    pub base_entry_id: Option<String>,
    pub start: usize,
    pub end: usize,
    pub cursor: HistoryCursor,
    pub has_more: bool,
}

pub fn select_history_range(
    entry_ids: &[String],
    cursor: Option<&HistoryCursor>,
    limit: usize,
) -> HistoryRange {
    let first_entry_id = entry_ids.first().cloned();
    let cursor_index = cursor
        .and_then(|c| c.last_entry_id.as_ref())
        .map(|id| {
            entry_ids
                .iter()
                .position(|candidate| candidate == id)
                .map(|index| index as isize)
                .unwrap_or(-1)
        })
        .unwrap_or(-1);
    let append = cursor.is_some()
        && cursor.and_then(|c| c.first_entry_id.clone()) == first_entry_id
        && ((cursor_index >= 0
            && entry_ids
                .get(cursor_index as usize)
                .zip(cursor.and_then(|c| c.last_entry_id.as_ref()))
                .map(|(a, b)| a == b)
                .unwrap_or(false))
            || (cursor.and_then(|c| c.last_entry_id.as_ref()).is_none() && entry_ids.is_empty()));
    let start = if append { cursor_index + 1 } else { 0 } as usize;
    let end = (start + limit).min(entry_ids.len());
    HistoryRange {
        mode: if append { "append" } else { "replace" },
        base_entry_id: if append {
            cursor.and_then(|c| c.last_entry_id.clone())
        } else {
            None
        },
        start,
        end,
        cursor: HistoryCursor {
            first_entry_id,
            last_entry_id: if end > start {
                entry_ids.get(end - 1).cloned()
            } else {
                None
            },
        },
        has_more: end < entry_ids.len(),
    }
}

pub struct HistoryPage {
    pub context: Value,
    pub mode: &'static str,
    pub base_entry_id: Option<String>,
    pub cursor: HistoryCursor,
    pub has_more: bool,
    pub leaf_id: Option<String>,
}

pub fn history_page(
    cfg: &Config,
    entries: &[Value],
    cursor: Option<&HistoryCursor>,
    limit: usize,
    leaf_id: Option<&str>,
    options: ContextOptions,
) -> HistoryPage {
    let tip_id = entries
        .last()
        .and_then(|entry| entry.get("id"))
        .and_then(Value::as_str)
        .map(|id| id.to_string());
    // Mirror the reference: an explicit leaf that exists wins, anything else
    // (omitted, empty, unknown) resolves to the tip so the client can keep
    // paging the same branch.
    let resolved_leaf = match leaf_id {
        Some(id)
            if !id.is_empty()
                && entries
                    .iter()
                    .any(|entry| entry.get("id").and_then(Value::as_str) == Some(id)) =>
        {
            Some(id.to_string())
        }
        _ => tip_id,
    };
    let context = build_session_context(cfg, entries, resolved_leaf.as_deref(), options);
    let entry_ids: Vec<String> = context
        .get("entryIds")
        .and_then(Value::as_array)
        .map(|ids| {
            ids.iter()
                .filter_map(Value::as_str)
                .map(|id| id.to_string())
                .collect()
        })
        .unwrap_or_default();
    let messages = context
        .get("messages")
        .and_then(Value::as_array)
        .cloned()
        .unwrap_or_default();
    let range = select_history_range(&entry_ids, cursor, limit);
    let metadata = |context: &Value| {
        let mut object = context.as_object().cloned().unwrap_or_default();
        object.remove("messages");
        object.remove("entryIds");
        Value::Object(object)
    };
    let mut page_context = metadata(&context);
    if let Some(object) = page_context.as_object_mut() {
        object.insert(
            "entryIds".into(),
            Value::Array(
                entry_ids[range.start.min(entry_ids.len())..range.end.min(entry_ids.len())]
                    .iter()
                    .cloned()
                    .map(Value::String)
                    .collect(),
            ),
        );
        object.insert(
            "messages".into(),
            Value::Array(
                messages[range.start.min(messages.len())..range.end.min(messages.len())].to_vec(),
            ),
        );
    }
    HistoryPage {
        context: page_context,
        mode: range.mode,
        base_entry_id: range.base_entry_id,
        cursor: range.cursor,
        has_more: range.has_more,
        leaf_id: resolved_leaf,
    }
}

pub fn context_boundary(cfg: &Config, path: &Path) -> Result<Value, bool> {
    let entries = load_display_entries(cfg, path, false)?;
    let context = build_session_context(cfg, &entries, None, ContextOptions::default());
    Ok(json!({
        "entryIds": context.get("entryIds").cloned().unwrap_or_else(|| Value::Array(Vec::new())),
    }))
}

pub fn read_session_header_or_error(path: &Path) -> Option<Value> {
    read_session_header(path)
}

pub fn last_entry_id(path: &Path) -> Option<String> {
    get_leaf_entry_id(&load_session_file(path, None).entries)
}

pub fn session_path_from_id(cfg: &Config, id: &str) -> Option<PathBuf> {
    resolve_session_path(cfg, id)
}

pub fn now_iso_ms() -> String {
    iso_from_ms(now_ms())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn entry(id: &str, parent: Option<&str>, role: &str, text: &str) -> Value {
        json!({
            "type": "message",
            "id": id,
            "parentId": parent,
            "timestamp": format!("2026-01-01T00:00:0{}.000Z", id.len()),
            "message": { "role": role, "content": text }
        })
    }

    #[test]
    fn history_range_replaces_and_appends() {
        let ids: Vec<String> = (0..5).map(|i| format!("id{}", i)).collect();
        let first = select_history_range(&ids, None, 3);
        assert_eq!(first.mode, "replace");
        assert_eq!((first.start, first.end), (0, 3));
        assert!(first.has_more);

        let cursor = HistoryCursor {
            first_entry_id: Some("id0".into()),
            last_entry_id: Some("id2".into()),
        };
        let second = select_history_range(&ids, Some(&cursor), 3);
        assert_eq!(second.mode, "append");
        assert_eq!((second.start, second.end), (3, 5));
        assert!(!second.has_more);
    }

    #[test]
    fn context_walks_the_leaf_branch_only() {
        let entries = vec![
            entry("a", None, "user", "hello"),
            entry("b", Some("a"), "assistant", "hi"),
            entry("c", Some("a"), "user", "other branch"),
        ];
        let cfg = Config::load();
        let ctx = build_session_context(&cfg, &entries, Some("b"), ContextOptions::default());
        assert_eq!(ctx["entryIds"].as_array().unwrap().len(), 2);
        assert_eq!(ctx["messages"][1]["content"], json!("hi"));
    }

    #[test]
    fn exact_path_references_require_boundaries() {
        assert!(contains_exact_path_reference(
            "see /tmp/a.rs:12 for details",
            "/tmp/a.rs"
        ));
        assert!(contains_exact_path_reference(
            "file:///tmp/a.rs",
            "/tmp/a.rs"
        ));
        assert!(contains_exact_path_reference(
            "attached %2Ftmp%2Fa.rs",
            "/tmp/a.rs"
        ));
        assert!(!contains_exact_path_reference("/tmp/a.rs.bak", "/tmp/a.rs"));
        assert!(!contains_exact_path_reference("/tmp/a.rsx", "/tmp/a.rs"));
        assert!(!contains_exact_path_reference("x/tmp/a.rs", "/tmp/a.rs"));
    }

    #[test]
    fn bash_output_references_match_recorded_path() {
        let entries = vec![json!({
            "type": "message",
            "message": {
                "role": "bashExecution",
                "fullOutputPath": "/tmp/pi-bash-abc.log"
            }
        })];
        assert!(bash_output_referenced_by_entries(
            Path::new("/tmp/pi-bash-abc.log"),
            &entries
        ));
        assert!(!bash_output_referenced_by_entries(
            Path::new("/tmp/pi-bash-abc.log.1"),
            &entries
        ));
    }

    #[test]
    fn history_page_resolves_leaf_to_tip() {
        let entries = vec![
            entry("u1", None, "user", "hi"),
            entry("a1", Some("u1"), "assistant", "hello"),
        ];
        let cfg = Config::load();
        let page = history_page(&cfg, &entries, None, 100, None, ContextOptions::default());
        assert_eq!(page.leaf_id.as_deref(), Some("a1"));
        let unknown = history_page(
            &cfg,
            &entries,
            None,
            100,
            Some("missing"),
            ContextOptions::default(),
        );
        assert_eq!(unknown.leaf_id.as_deref(), Some("a1"));
    }

    #[test]
    fn tool_calls_normalize_field_names() {
        let mut message = json!({
            "role": "assistant",
            "content": [{ "type": "toolCall", "id": "call1", "name": "read", "arguments": {"path": "a"} }]
        })
        .as_object()
        .unwrap()
        .clone();
        normalize_tool_calls(&mut message);
        let block = &message["content"][0];
        assert_eq!(block["toolCallId"], json!("call1"));
        assert_eq!(block["toolName"], json!("read"));
        assert_eq!(block["input"]["path"], json!("a"));
    }

    #[test]
    fn tree_projection_contracts_single_child_chains() {
        let nodes = vec![json!({
            "entry": { "id": "a", "type": "message", "message": { "role": "user", "content": "hi" } },
            "children": [{
                "entry": { "id": "b", "type": "message", "message": { "role": "assistant", "content": "one" } },
                "children": [{
                    "entry": { "id": "c", "type": "message", "message": { "role": "assistant", "content": "two" } },
                    "children": []
                }]
            }]
        })];
        let projected = project_tree_for_response(nodes);
        assert_eq!(projected.len(), 1);
        let children = projected[0]["children"].as_array().unwrap();
        assert_eq!(children.len(), 1);
        assert_eq!(children[0]["entry"]["id"], json!("c"));
        assert_eq!(children[0]["compressedEntryIds"], json!(["b"]));
        assert_eq!(projected[0]["branchPreview"]["text"], json!("hi"));
    }

    #[test]
    fn compaction_collapses_to_first_kept_entry() {
        let entries = vec![
            entry("u1", None, "user", "old question"),
            entry("a1", Some("u1"), "assistant", "old answer"),
            entry("u2", Some("a1"), "user", "new question"),
            entry("a2", Some("u2"), "assistant", "new answer"),
            json!({
                "type": "compaction",
                "id": "c1",
                "parentId": "a2",
                "timestamp": "2026-01-02T00:00:09.000Z",
                "summary": "Earlier context",
                "firstKeptEntryId": "u2",
                "tokensBefore": 1000,
                "tokensAfter": 200,
            }),
        ];
        let cfg = Config::load();
        let context = build_session_context(&cfg, &entries, None, ContextOptions::default());
        assert_eq!(context["entryIds"], json!(["c1", "u2", "a2"]));
        assert_eq!(context["messages"][0]["customType"], json!("compaction"));
        assert_eq!(context["messages"][0]["content"], json!("Earlier context"));
        assert_eq!(context["messages"][1]["content"], json!("new question"));

        let full = build_session_context(
            &cfg,
            &entries,
            None,
            ContextOptions {
                include_pre_compaction: true,
                ..Default::default()
            },
        );
        assert_eq!(full["entryIds"], json!(["u1", "a1", "u2", "a2", "c1"]));
    }
}
