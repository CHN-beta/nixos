//! Small shared helpers: JSON/HTTP responses, time formatting, atomic writes,
//! path normalization, MIME/language tables and query parsing.

use axum::body::Body;
use axum::http::{header, HeaderValue, StatusCode, Uri};
use axum::response::{IntoResponse, Response};
use serde_json::{json, Value};
use std::collections::HashMap;
use std::fs;
use std::io;
use std::path::{Component, Path, PathBuf};
use std::time::{Duration, SystemTime, UNIX_EPOCH};

pub fn now_ms() -> f64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or(Duration::ZERO)
        .as_secs_f64()
        * 1000.0
}

pub fn now_iso() -> String {
    iso_from_ms(now_ms())
}

/// Milliseconds since the epoch as an ISO-8601 UTC timestamp (millisecond
/// precision, matching `Date#toISOString`).
pub fn iso_from_ms(ms: f64) -> String {
    if !ms.is_finite() {
        return String::new();
    }
    let total_ms = ms.round() as i64;
    let secs = total_ms.div_euclid(1000);
    let millis = total_ms.rem_euclid(1000);
    let days = secs.div_euclid(86_400);
    let secs_of_day = secs.rem_euclid(86_400);
    let (year, month, day) = civil_from_days(days);
    format!(
        "{:04}-{:02}-{:02}T{:02}:{:02}:{:02}.{:03}Z",
        year,
        month,
        day,
        secs_of_day / 3600,
        (secs_of_day % 3600) / 60,
        secs_of_day % 60,
        millis
    )
}

/// Howard Hinnant's `civil_from_days` algorithm.
fn civil_from_days(days: i64) -> (i64, u32, u32) {
    let z = days + 719_468;
    let era = if z >= 0 { z } else { z - 146_096 } / 146_097;
    let doe = z - era * 146_097;
    let yoe = (doe - doe / 1460 + doe / 36_524 - doe / 146_096) / 365;
    let y = yoe + era * 400;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp = (5 * doy + 2) / 153;
    let d = doy - (153 * mp + 2) / 5 + 1;
    let m = if mp < 10 { mp + 3 } else { mp - 9 };
    (if m <= 2 { y + 1 } else { y }, m as u32, d as u32)
}

pub fn parse_iso_ms(value: &str) -> Option<f64> {
    // Accept the common `YYYY-MM-DDTHH:MM:SS[.sss]Z` shape (what omp writes).
    let bytes = value.as_bytes();
    if bytes.len() < 19 {
        return None;
    }
    let year: i64 = value.get(0..4)?.parse().ok()?;
    let month: u32 = value.get(5..7)?.parse().ok()?;
    let day: u32 = value.get(8..10)?.parse().ok()?;
    let hour: i64 = value.get(11..13)?.parse().ok()?;
    let minute: i64 = value.get(14..16)?.parse().ok()?;
    let second: i64 = value.get(17..19)?.parse().ok()?;
    let millis: f64 = if bytes.get(19) == Some(&b'.') {
        let rest = value.get(20..).unwrap_or("");
        let digits: String = rest.chars().take_while(|c| c.is_ascii_digit()).collect();
        if digits.is_empty() {
            0.0
        } else {
            let mut padded = digits;
            while padded.len() < 3 {
                padded.push('0');
            }
            padded[..3].parse::<f64>().ok()?
        }
    } else {
        0.0
    };
    let days = days_from_civil(year, month, day);
    Some((days * 86_400 + hour * 3600 + minute * 60 + second) as f64 * 1000.0 + millis)
}

fn days_from_civil(y: i64, m: u32, d: u32) -> i64 {
    let y = if m <= 2 { y - 1 } else { y };
    let era = if y >= 0 { y } else { y - 399 } / 400;
    let yoe = y - era * 400;
    let m = m as i64;
    let doy = (153 * (if m > 2 { m - 3 } else { m + 9 }) + 2) / 5 + d as i64 - 1;
    let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy;
    era * 146_097 + doe - 719_468
}

pub fn mtime_ms(meta: &fs::Metadata) -> f64 {
    meta.modified()
        .ok()
        .and_then(|t| t.duration_since(UNIX_EPOCH).ok())
        .map(|d| d.as_secs_f64() * 1000.0)
        .unwrap_or(0.0)
}

pub fn json_response(value: Value) -> Response {
    (StatusCode::OK, axum::Json(value)).into_response()
}

pub fn json_status(status: StatusCode, value: Value) -> Response {
    (status, axum::Json(value)).into_response()
}

pub fn api_error(error: impl std::fmt::Display, status: StatusCode) -> Response {
    json_status(status, json!({ "error": error.to_string() }))
}

pub fn coded_error(status: StatusCode, message: &str, code: &str) -> Response {
    json_status(status, json!({ "error": message, "code": code }))
}

pub fn access_denied() -> Response {
    coded_error(StatusCode::FORBIDDEN, "Access denied", "access_denied")
}

pub async fn read_json_body(body: Body, limit: usize) -> Result<Value, Response> {
    let bytes = axum::body::to_bytes(body, limit).await.map_err(|_| {
        coded_error(
            StatusCode::PAYLOAD_TOO_LARGE,
            "Request body is too large",
            "request_too_large",
        )
    })?;
    serde_json::from_slice(&bytes).map_err(|_| {
        coded_error(
            StatusCode::BAD_REQUEST,
            "Invalid JSON request body",
            "invalid_json",
        )
    })
}

/// Replace a file through a temp file in the same directory plus rename, so a
/// crash leaves either the old or the new file.
pub fn atomic_write(path: &Path, contents: &[u8]) -> io::Result<()> {
    let dir = path.parent().unwrap_or_else(|| Path::new("."));
    fs::create_dir_all(dir)?;
    let tmp = dir.join(format!(
        ".{}.tmp-{}-{}",
        path.file_name().and_then(|n| n.to_str()).unwrap_or("file"),
        std::process::id(),
        uuid::Uuid::new_v4()
    ));
    let result = (|| -> io::Result<()> {
        fs::write(&tmp, contents)?;
        fs::rename(&tmp, path)?;
        Ok(())
    })();
    if result.is_err() {
        let _ = fs::remove_file(&tmp);
    }
    result
}

pub fn expand_tilde(value: &str, home: &Path) -> PathBuf {
    if value == "~" {
        return home.to_path_buf();
    }
    if let Some(rest) = value.strip_prefix("~/") {
        return home.join(rest);
    }
    PathBuf::from(value)
}

/// Lexical absolute path (no filesystem access), mirroring `path.resolve`.
pub fn absolute_path(value: &Path) -> PathBuf {
    if value.is_absolute() {
        normalize_lexically(value)
    } else {
        let cwd = std::env::current_dir().unwrap_or_else(|_| PathBuf::from("/"));
        normalize_lexically(&cwd.join(value))
    }
}

pub fn normalize_lexically(path: &Path) -> PathBuf {
    let mut out = PathBuf::new();
    for component in path.components() {
        match component {
            Component::CurDir => {}
            Component::ParentDir => {
                if !out.pop() {
                    out.push("..");
                }
            }
            other => out.push(other.as_os_str()),
        }
    }
    if out.as_os_str().is_empty() {
        out.push("/");
    }
    out
}

pub fn canonical_or_original(path: &Path) -> PathBuf {
    fs::canonicalize(path).unwrap_or_else(|_| absolute_path(path))
}

/// Normalized comparison key (no trailing separator).
pub fn path_key(path: &Path) -> String {
    let normalized = normalize_lexically(&absolute_path(path));
    let mut text = normalized.to_string_lossy().into_owned();
    while text.len() > 1 && text.ends_with('/') {
        text.pop();
    }
    text
}

pub fn same_path(a: &Path, b: &Path) -> bool {
    path_key(a) == path_key(b)
}

/// True when `target` is `root` or lives underneath it.
pub fn is_within(root: &Path, target: &Path) -> bool {
    let root = normalize_lexically(&absolute_path(root));
    let target = normalize_lexically(&absolute_path(target));
    target == root || target.starts_with(&root)
}

pub fn file_name(path: &Path) -> String {
    path.file_name()
        .and_then(|n| n.to_str())
        .unwrap_or("")
        .to_string()
}

pub fn file_ext(path: &Path) -> String {
    file_name(path)
        .rsplit_once('.')
        .map(|(_, ext)| ext.to_ascii_lowercase())
        .unwrap_or_default()
}

const IMAGE_MIMES: &[(&str, &str)] = &[
    ("png", "image/png"),
    ("jpg", "image/jpeg"),
    ("jpeg", "image/jpeg"),
    ("gif", "image/gif"),
    ("webp", "image/webp"),
    ("svg", "image/svg+xml"),
    ("bmp", "image/bmp"),
    ("ico", "image/x-icon"),
    ("avif", "image/avif"),
];

const AUDIO_MIMES: &[(&str, &str)] = &[
    ("mp3", "audio/mpeg"),
    ("wav", "audio/wav"),
    ("ogg", "audio/ogg"),
    ("oga", "audio/ogg"),
    ("opus", "audio/ogg"),
    ("m4a", "audio/mp4"),
    ("aac", "audio/aac"),
    ("flac", "audio/flac"),
    ("weba", "audio/webm"),
    ("webm", "audio/webm"),
];

pub fn image_mime(path: &Path) -> Option<&'static str> {
    let ext = file_ext(path);
    IMAGE_MIMES.iter().find(|(e, _)| *e == ext).map(|(_, m)| *m)
}

pub fn audio_mime(path: &Path) -> Option<&'static str> {
    let ext = file_ext(path);
    AUDIO_MIMES.iter().find(|(e, _)| *e == ext).map(|(_, m)| *m)
}

pub fn document_mime(path: &Path) -> Option<&'static str> {
    match file_ext(path).as_str() {
        "pdf" => Some("application/pdf"),
        "docx" => Some("application/vnd.openxmlformats-officedocument.wordprocessingml.document"),
        _ => None,
    }
}

pub fn document_preview_kind(path: &Path) -> Option<&'static str> {
    match file_ext(path).as_str() {
        "pdf" => Some("pdf"),
        "docx" => Some("docx"),
        _ => None,
    }
}

pub fn stream_security_headers(content_type: &str) -> Vec<(&'static str, &'static str)> {
    if content_type == "image/svg+xml" {
        vec![(
            "Content-Security-Policy",
            "default-src 'none'; img-src data:; style-src 'unsafe-inline'; base-uri 'none'; form-action 'none'; frame-ancestors 'self'",
        )]
    } else {
        Vec::new()
    }
}

pub fn language_for(path: &Path) -> &'static str {
    let base = file_name(path).to_ascii_lowercase();
    if base == "dockerfile" || base.starts_with("dockerfile.") {
        return "dockerfile";
    }
    if base == ".env" || base.starts_with(".env.") {
        return "bash";
    }
    if base == "makefile" || base == "gnumakefile" {
        return "makefile";
    }
    match file_ext(path).as_str() {
        "ts" | "tsx" => "typescript",
        "js" | "jsx" | "mjs" | "cjs" => "javascript",
        "py" => "python",
        "rb" => "ruby",
        "go" => "go",
        "rs" => "rust",
        "java" => "java",
        "kt" => "kotlin",
        "swift" => "swift",
        "c" | "h" => "c",
        "cpp" | "hpp" => "cpp",
        "cs" => "csharp",
        "html" | "htm" => "html",
        "css" | "scss" | "less" => "css",
        "json" | "jsonl" => "json",
        "yaml" | "yml" => "yaml",
        "toml" => "toml",
        "xml" => "xml",
        "md" | "mdx" => "markdown",
        "sh" | "bash" | "zsh" | "fish" => "bash",
        "sql" => "sql",
        "graphql" | "gql" => "graphql",
        "tf" | "hcl" => "hcl",
        "env" | "gitignore" => "bash",
        "txt" => "text",
        "pdf" => "pdf",
        "docx" => "word",
        _ => "text",
    }
}

fn encode_header_value(value: &str) -> String {
    let mut out = String::new();
    for byte in value.bytes() {
        let ch = byte as char;
        if ch.is_ascii_alphanumeric() || "-_.!~*'()".contains(ch) {
            out.push(ch);
        } else {
            out.push_str(&format!("%{:02X}", byte));
        }
    }
    out
}

pub fn content_disposition(name: &str, inline: bool) -> String {
    let fallback: String = name
        .chars()
        .map(|c| {
            if c.is_ascii() && !c.is_ascii_control() && !"\"\\;".contains(c) {
                c
            } else {
                '_'
            }
        })
        .collect();
    let fallback = if fallback.is_empty() {
        "download".to_string()
    } else {
        fallback
    };
    format!(
        "{}; filename=\"{}\"; filename*=UTF-8''{}",
        if inline { "inline" } else { "attachment" },
        fallback,
        encode_header_value(name)
    )
}

/// Collected query parameters, preserving duplicates for presence checks.
#[derive(Debug, Default, Clone)]
pub struct QueryMap {
    pairs: Vec<(String, String)>,
}

impl QueryMap {
    pub fn parse(uri: &Uri) -> Self {
        let mut pairs = Vec::new();
        if let Some(query) = uri.query() {
            for (key, value) in form_urlencoded_parse(query) {
                pairs.push((key, value));
            }
        }
        Self { pairs }
    }

    pub fn get(&self, key: &str) -> Option<&str> {
        self.pairs
            .iter()
            .find(|(k, _)| k == key)
            .map(|(_, v)| v.as_str())
    }

    pub fn has(&self, key: &str) -> bool {
        self.pairs.iter().any(|(k, _)| k == key)
    }

    pub fn count(&self, key: &str) -> usize {
        self.pairs.iter().filter(|(k, _)| k == key).count()
    }

    pub fn get_all(&self, key: &str) -> Vec<&str> {
        self.pairs
            .iter()
            .filter(|(k, _)| k == key)
            .map(|(_, v)| v.as_str())
            .collect()
    }
}

fn form_urlencoded_parse(query: &str) -> Vec<(String, String)> {
    let mut out = Vec::new();
    for pair in query.split('&') {
        if pair.is_empty() {
            continue;
        }
        let (key, value) = match pair.split_once('=') {
            Some((key, value)) => (key, value),
            None => (pair, ""),
        };
        out.push((percent_decode(key), percent_decode(value)));
    }
    out
}

pub fn percent_decode(value: &str) -> String {
    percent_encoding::percent_decode_str(&value.replace('+', " "))
        .decode_utf8_lossy()
        .into_owned()
}

pub fn parse_bool_param(value: Option<&str>) -> bool {
    matches!(value, Some("1") | Some("true") | Some("yes"))
}

pub fn header_string(headers: &axum::http::HeaderMap, name: &str) -> Option<String> {
    headers
        .get(name)
        .and_then(|value| value.to_str().ok())
        .map(|v| v.to_string())
}

pub fn with_header(mut response: Response, name: &str, value: &str) -> Response {
    if let Ok(parsed) = HeaderValue::from_str(value) {
        response.headers_mut().insert(
            header::HeaderName::from_bytes(name.as_bytes()).unwrap_or(header::CONTENT_TYPE),
            parsed,
        );
    }
    response
}

pub fn sse_headers(mut response: Response) -> Response {
    let headers = response.headers_mut();
    headers.insert(
        header::CONTENT_TYPE,
        HeaderValue::from_static("text/event-stream; charset=utf-8"),
    );
    headers.insert(
        header::CACHE_CONTROL,
        HeaderValue::from_static("no-cache, no-transform"),
    );
    headers.insert(header::CONNECTION, HeaderValue::from_static("keep-alive"));
    headers.insert(
        header::HeaderName::from_static("x-accel-buffering"),
        HeaderValue::from_static("no"),
    );
    response
}

/// Convert a JSON object into a `HashMap<String, Value>` when it is one.
pub fn as_object(value: &Value) -> Option<&serde_json::Map<String, Value>> {
    value.as_object()
}

pub fn string_field<'a>(value: &'a Value, key: &str) -> Option<&'a str> {
    value.get(key).and_then(Value::as_str)
}

pub fn number_field(value: &Value, key: &str) -> Option<f64> {
    value.get(key).and_then(Value::as_f64)
}

pub fn bool_field(value: &Value, key: &str) -> Option<bool> {
    value.get(key).and_then(Value::as_bool)
}

/// Capture a HashMap-based lookup for the `Query` extractor used by a few
/// simple handlers.
pub fn query_pairs_map(uri: &Uri) -> HashMap<String, String> {
    QueryMap::parse(uri).pairs.into_iter().collect()
}
