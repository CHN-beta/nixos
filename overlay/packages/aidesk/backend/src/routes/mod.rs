//! Shared route helpers: query parsing, cwd/file authorization, file streaming.

pub mod agent;
pub mod files;
pub mod notifications;
pub mod sessions;
pub mod settings;
pub mod stt;
pub mod terminal;
pub mod workspace;

use crate::state::SharedState;
use crate::util::{
    absolute_path, content_disposition, document_mime, file_name, image_mime, is_within,
    json_status, path_key, QueryMap,
};
use axum::body::Body;
use axum::http::{header, HeaderMap, HeaderValue, StatusCode, Uri};
use axum::response::{IntoResponse, Response};
use serde_json::Value;
use std::path::{Path, PathBuf};
use tokio::io::{AsyncReadExt, AsyncSeekExt};
use tokio_util::io::ReaderStream;

pub fn query(uri: &Uri) -> QueryMap {
    QueryMap::parse(uri)
}

pub async fn body_json(request: axum::extract::Request, limit: usize) -> Result<Value, Response> {
    let bytes = axum::body::to_bytes(request.into_body(), limit)
        .await
        .map_err(|_| {
            crate::util::coded_error(
                StatusCode::PAYLOAD_TOO_LARGE,
                "Request body is too large",
                "request_too_large",
            )
        })?;
    serde_json::from_slice(&bytes).map_err(|_| {
        crate::util::coded_error(
            StatusCode::BAD_REQUEST,
            "Invalid JSON request body",
            "invalid_json",
        )
    })
}

/// Absolute cwd check shared by the workspace-scoped routes.
pub fn require_cwd(state: &SharedState, cwd: &str) -> Result<PathBuf, Response> {
    let trimmed = cwd.trim();
    if trimmed.is_empty() || (!trimmed.starts_with('/') && !trimmed.starts_with('~')) {
        return Err(crate::util::coded_error(
            StatusCode::BAD_REQUEST,
            "cwd must be an absolute path",
            "cwd_must_be_absolute",
        ));
    }
    let path = if trimmed.starts_with('~') {
        crate::util::expand_tilde(trimmed, &state.cfg.home)
    } else {
        PathBuf::from(trimmed)
    };
    if !state.is_path_allowed(&path) {
        return Err(crate::util::access_denied());
    }
    let meta = match std::fs::metadata(&path) {
        Ok(meta) => meta,
        Err(_) => {
            return Err(crate::util::coded_error(
                StatusCode::NOT_FOUND,
                "Directory not found",
                "directory_not_found",
            ))
        }
    };
    if !meta.is_dir() {
        return Err(crate::util::coded_error(
            StatusCode::BAD_REQUEST,
            "Not a directory",
            "not_a_directory",
        ));
    }
    if !state.is_existing_path_allowed(&path) {
        return Err(crate::util::access_denied());
    }
    Ok(path)
}

/// Join the catch-all request path into an absolute filesystem path.
pub fn file_path_from_param(param: &str) -> String {
    let joined = param.replace('\\', "/");
    let trimmed = joined.trim_start_matches('/');
    format!("/{}", trimmed)
}

/// Resolve a read request path: absolute first, then fan out over allowed roots
/// for relative names (chat links omit the leading slash).
pub fn resolve_read_file_path(state: &SharedState, param: &str) -> PathBuf {
    let normalized = param.replace('\\', "/");
    let trimmed = normalized.trim_start_matches('/');
    let segments: Vec<&str> = trimmed.split('/').collect();
    if segments.first() == Some(&"~") {
        let rest: PathBuf = segments[1..].iter().collect();
        return crate::util::normalize_lexically(&state.cfg.home.join(rest));
    }
    let absolute = crate::util::normalize_lexically(&PathBuf::from(file_path_from_param(param)));
    if state.is_path_allowed(&absolute) {
        return absolute;
    }
    let relative: PathBuf = segments.iter().collect();
    for root in state.allowed_roots() {
        let candidate = crate::util::normalize_lexically(&root.join(&relative));
        if is_within(&root, &candidate) && candidate.exists() {
            return candidate;
        }
    }
    absolute
}

/// Strictly absolute upload directory (never fans out relative requests).
pub fn strict_absolute_path(param: &str) -> PathBuf {
    PathBuf::from(file_path_from_param(param))
}

pub fn file_not_found() -> Response {
    crate::util::coded_error(StatusCode::NOT_FOUND, "Not found", "file_not_found")
}

pub fn not_a_file() -> Response {
    crate::util::coded_error(StatusCode::BAD_REQUEST, "Not a file", "not_a_file")
}

pub fn not_a_directory() -> Response {
    crate::util::coded_error(
        StatusCode::BAD_REQUEST,
        "Not a directory",
        "not_a_directory",
    )
}

pub fn session_not_found() -> Response {
    crate::util::coded_error(
        StatusCode::NOT_FOUND,
        "Session not found",
        "session_not_found",
    )
}

pub fn apply_headers(mut response: Response, headers: &[(&str, String)]) -> Response {
    for (name, value) in headers {
        if let (Ok(name), Ok(value)) = (
            header::HeaderName::from_bytes(name.as_bytes()),
            HeaderValue::from_str(value),
        ) {
            response.headers_mut().insert(name, value);
        }
    }
    response
}

/// Parse a single `bytes=` range against a known file size.
fn parse_range(range: &str, size: u64) -> Result<(u64, u64), ()> {
    let spec = range.strip_prefix("bytes=").ok_or(())?;
    if spec.contains(',') {
        return Err(());
    }
    let (start_raw, end_raw) = spec.split_once('-').ok_or(())?;
    let start: u64;
    let end: u64;
    if start_raw.is_empty() {
        let suffix: u64 = end_raw.parse().map_err(|_| ())?;
        start = size.saturating_sub(suffix);
        end = size.saturating_sub(1);
    } else {
        start = start_raw.parse().map_err(|_| ())?;
        end = if end_raw.is_empty() {
            size.saturating_sub(1)
        } else {
            end_raw.parse().map_err(|_| ())?
        };
    }
    if start >= size || end < start {
        return Err(());
    }
    Ok((start, end.min(size.saturating_sub(1))))
}

/// Stream a file, honoring a single byte range like the reference route.
pub async fn stream_file(
    path: &Path,
    meta: &std::fs::Metadata,
    content_type: &str,
    range_header: Option<&str>,
    as_download: bool,
) -> Response {
    let size = meta.len();
    let mut builder = Response::builder()
        .header(header::CONTENT_TYPE, content_type)
        .header(header::CACHE_CONTROL, "no-cache")
        .header(header::ACCEPT_RANGES, "bytes")
        .header(
            header::CONTENT_DISPOSITION,
            content_disposition(&file_name(path), !as_download),
        );
    for (name, value) in crate::util::stream_security_headers(content_type) {
        builder = builder.header(name, value);
    }

    if let Some(range) = range_header {
        match parse_range(range, size) {
            Ok((start, end)) => {
                let length = end - start + 1;
                let mut file = match tokio::fs::File::open(path).await {
                    Ok(file) => file,
                    Err(_) => return file_not_found(),
                };
                if file.seek(std::io::SeekFrom::Start(start)).await.is_err() {
                    return crate::util::api_error(
                        "Cannot read file",
                        StatusCode::INTERNAL_SERVER_ERROR,
                    );
                }
                let reader = file.take(length);
                let stream = ReaderStream::new(reader);
                builder
                    .status(StatusCode::PARTIAL_CONTENT)
                    .header(header::CONTENT_LENGTH, length.to_string())
                    .header(
                        header::CONTENT_RANGE,
                        format!("bytes {}-{}/{}", start, end, size),
                    )
                    .body(Body::from_stream(stream))
                    .unwrap_or_else(|_| StatusCode::INTERNAL_SERVER_ERROR.into_response())
            }
            Err(_) => builder
                .status(StatusCode::RANGE_NOT_SATISFIABLE)
                .header(header::CONTENT_RANGE, format!("bytes */{}", size))
                .body(Body::empty())
                .unwrap_or_else(|_| StatusCode::RANGE_NOT_SATISFIABLE.into_response()),
        }
    } else {
        let file = match tokio::fs::File::open(path).await {
            Ok(file) => file,
            Err(_) => return file_not_found(),
        };
        let stream = ReaderStream::new(file);
        builder
            .header(header::CONTENT_LENGTH, size.to_string())
            .body(Body::from_stream(stream))
            .unwrap_or_else(|_| StatusCode::INTERNAL_SERVER_ERROR.into_response())
    }
}

pub fn mime_for(path: &Path) -> &'static str {
    image_mime(path)
        .or_else(|| crate::util::audio_mime(path))
        .or_else(|| document_mime(path))
        .unwrap_or("application/octet-stream")
}

pub fn header_range(headers: &HeaderMap) -> Option<String> {
    headers
        .get(header::RANGE)
        .and_then(|value| value.to_str().ok())
        .map(|value| value.to_string())
}

pub fn file_mtime_header(meta: &std::fs::Metadata) -> String {
    format!("{}", crate::util::mtime_ms(meta))
}

pub fn json_ok(value: Value) -> Response {
    json_status(StatusCode::OK, value)
}

pub fn compare_key(path: &Path) -> String {
    path_key(&absolute_path(path))
}

/// `?includeState=1`-style presence check.
pub fn has(query: &QueryMap, name: &str) -> bool {
    query.has(name)
}
