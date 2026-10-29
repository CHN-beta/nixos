//! `/api/files/{*path}` and `/api/media/{hash}`.

use crate::omp::media;
use crate::routes::{
    body_json, file_mtime_header, file_not_found, header_range, mime_for, not_a_directory,
    not_a_file, query, resolve_read_file_path, stream_file, strict_absolute_path,
};
use crate::state::SharedState;
use crate::util::{
    coded_error, content_disposition, document_mime, document_preview_kind, file_ext, file_name,
    image_mime, is_within, language_for, mtime_ms, now_iso,
};
use axum::body::Body;
use axum::extract::{FromRequest, Multipart, Path as AxumPath, State};
use axum::http::{header, HeaderValue, StatusCode, Uri};
use axum::response::{IntoResponse, Response};
use serde_json::{json, Map, Value};
use std::io::Read;
use std::path::{Path, PathBuf};

const IGNORED_NAMES: &[&str] = &[
    "node_modules",
    ".git",
    ".next",
    "dist",
    "build",
    "__pycache__",
    ".turbo",
    ".cache",
    "coverage",
    ".pytest_cache",
    ".mypy_cache",
    "target",
    "vendor",
    ".DS_Store",
];
const TEXT_PREVIEW_MAX_BYTES: u64 = 256 * 1024;
const IMAGE_PREVIEW_MAX_BYTES: u64 = 10 * 1024 * 1024;
const DOCX_PREVIEW_MAX_BYTES: u64 = 10 * 1024 * 1024;
const MAX_UPLOAD_FILE_BYTES: usize = 25 * 1024 * 1024;
const MAX_UPLOAD_TOTAL_BYTES: usize = 100 * 1024 * 1024;
const MAX_UPLOAD_CHECK_REQUEST_BYTES: usize = 1024 * 1024;

fn json_status(status: StatusCode, value: Value) -> Response {
    crate::util::json_status(status, value)
}

/// Nearest existing ancestor of `path` (which may be the path itself).
fn nearest_existing_ancestor(path: &Path) -> Option<PathBuf> {
    let mut current = path.to_path_buf();
    loop {
        if std::fs::symlink_metadata(&current).is_ok() {
            return Some(current);
        }
        let parent = current.parent()?.to_path_buf();
        if parent == current {
            return None;
        }
        current = parent;
    }
}

/// Canonical path a write would land on: resolves the deepest existing
/// ancestor and re-appends the not-yet-created components. Returns `None` for
/// paths that cannot be canonicalized at all.
fn canonical_write_target(path: &Path) -> Option<PathBuf> {
    let mut existing = path.to_path_buf();
    let mut tail: Vec<std::ffi::OsString> = Vec::new();
    loop {
        if std::fs::symlink_metadata(&existing).is_ok() {
            let mut target = std::fs::canonicalize(&existing).ok()?;
            for part in tail.iter().rev() {
                target.push(part);
            }
            return Some(crate::util::normalize_lexically(&target));
        }
        tail.push(existing.file_name()?.to_os_string());
        existing = existing.parent()?.to_path_buf();
    }
}

/// Deny writes to config/credential files even before they exist.
fn is_denied_write_target(state: &SharedState, path: &Path) -> bool {
    if state.is_config_root_denied_file(path) {
        return true;
    }
    match canonical_write_target(path) {
        Some(canonical) => state.is_config_root_denied_file(&canonical),
        None => true,
    }
}

// ============================================================================
// GET
// ============================================================================

pub async fn files_get(
    State(state): State<SharedState>,
    AxumPath(param): AxumPath<String>,
    uri: Uri,
    headers: axum::http::HeaderMap,
) -> Response {
    let query = query(&uri);
    let request_type = query.get("type").unwrap_or("list");
    if !["list", "read", "download", "meta", "preview", "watch"].contains(&request_type) {
        return coded_error(
            StatusCode::BAD_REQUEST,
            "Invalid file request type",
            "invalid_request_type",
        );
    }
    // Explicit viewer choice from the file tree's "Open with" menu. It wins
    // over extension sniffing, so e.g. a .bin can open in the PDF viewer.
    let open_as = query.get("as").map(|value| value.trim().to_lowercase());
    let open_as = open_as.as_deref();
    let session_id = query.get("sessionId");
    let path = resolve_read_file_path(&state, &param);
    let canonical = std::fs::canonicalize(&path).ok();
    if state.is_config_root_denied_file(&path)
        || canonical
            .as_deref()
            .map(|canonical| state.is_config_root_denied_file(canonical))
            .unwrap_or(false)
    {
        return crate::util::access_denied();
    }
    let allowed_by_root = state.is_path_allowed(&path);
    let allowed_by_session_reference = !allowed_by_root
        && request_type != "list"
        && crate::omp::session_reader::is_file_referenced_by_session(&state.cfg, &path, session_id);
    if !allowed_by_root && !allowed_by_session_reference {
        return crate::util::access_denied();
    }
    let meta = match std::fs::metadata(&path) {
        Ok(meta) => meta,
        Err(_) => return file_not_found(),
    };
    if !allowed_by_session_reference && !state.is_existing_path_allowed(&path) {
        return crate::util::access_denied();
    }

    match request_type {
        "read" => {
            if !meta.is_file() {
                return not_a_file();
            }
            match open_as {
                // Streamed media/documents ignore the extension so a file can
                // be inspected as image/audio/PDF/DOCX from "Open with".
                Some("image") => {
                    if meta.len() > IMAGE_PREVIEW_MAX_BYTES {
                        return coded_error(
                            StatusCode::PAYLOAD_TOO_LARGE,
                            "Image too large (>10MB)",
                            "image_too_large",
                        );
                    }
                    return stream_file(
                        &path,
                        &meta,
                        image_mime(&path).unwrap_or("application/octet-stream"),
                        header_range(&headers).as_deref(),
                        false,
                    )
                    .await;
                }
                Some("audio") => {
                    return stream_file(
                        &path,
                        &meta,
                        crate::util::audio_mime(&path).unwrap_or("audio/mpeg"),
                        header_range(&headers).as_deref(),
                        false,
                    )
                    .await;
                }
                Some("pdf") => {
                    return stream_file(
                        &path,
                        &meta,
                        "application/pdf",
                        header_range(&headers).as_deref(),
                        false,
                    )
                    .await;
                }
                Some("docx") => {
                    return stream_file(
                        &path,
                        &meta,
                        "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
                        header_range(&headers).as_deref(),
                        false,
                    )
                    .await;
                }
                // Text-ish overrides skip binary sniffing and only rewrite the
                // syntax language; the body stays the same JSON shape.
                Some("text") | Some("edit") | Some("markdown") | Some("html") => {}
                _ => {
                    if let Some(mime) = image_mime(&path) {
                        if meta.len() > IMAGE_PREVIEW_MAX_BYTES {
                            return coded_error(
                                StatusCode::PAYLOAD_TOO_LARGE,
                                "Image too large (>10MB)",
                                "image_too_large",
                            );
                        }
                        return stream_file(
                            &path,
                            &meta,
                            mime,
                            header_range(&headers).as_deref(),
                            false,
                        )
                        .await;
                    }
                    if let Some(mime) = crate::util::audio_mime(&path) {
                        return stream_file(
                            &path,
                            &meta,
                            mime,
                            header_range(&headers).as_deref(),
                            false,
                        )
                        .await;
                    }
                    if let Some(mime) = document_mime(&path) {
                        return stream_file(
                            &path,
                            &meta,
                            mime,
                            header_range(&headers).as_deref(),
                            false,
                        )
                        .await;
                    }
                }
            }
            if meta.len() > TEXT_PREVIEW_MAX_BYTES {
                return coded_error(
                    StatusCode::PAYLOAD_TOO_LARGE,
                    "File too large for preview (>256KB)",
                    "file_too_large_preview",
                );
            }
            let content = match std::fs::read(&path) {
                Ok(bytes) => String::from_utf8_lossy(&bytes).into_owned(),
                Err(_) => {
                    return crate::util::api_error(
                        "Cannot read file",
                        StatusCode::INTERNAL_SERVER_ERROR,
                    )
                }
            };
            let language = match open_as {
                Some("markdown") => "markdown",
                Some("html") => "html",
                _ => language_for(&path),
            };
            let response = crate::util::json_response(json!({
                "content": content,
                "language": language,
                "size": meta.len(),
            }));
            crate::routes::apply_headers(response, &[("X-File-Mtime", file_mtime_header(&meta))])
        }
        "download" => {
            if !meta.is_file() {
                return not_a_file();
            }
            stream_file(
                &path,
                &meta,
                mime_for(&path),
                header_range(&headers).as_deref(),
                true,
            )
            .await
        }
        "meta" => {
            if !meta.is_file() {
                return not_a_file();
            }
            let mime = image_mime(&path)
                .or_else(|| crate::util::audio_mime(&path))
                .or_else(|| document_mime(&path))
                .unwrap_or("text/plain");
            json_status(
                StatusCode::OK,
                json!({
                    "size": meta.len(),
                    "language": language_for(&path),
                    "mime": mime,
                    "previewKind": document_preview_kind(&path),
                }),
            )
        }
        "preview" => {
            if !meta.is_file() {
                return not_a_file();
            }
            let preview_kind = match open_as {
                Some("pdf") => Some("pdf"),
                Some("docx") => Some("docx"),
                _ => None,
            };
            let is_pdf =
                preview_kind == Some("pdf") || (preview_kind.is_none() && file_ext(&path) == "pdf");
            if is_pdf {
                // Browsers render application/pdf natively in an iframe.
                return stream_file(
                    &path,
                    &meta,
                    "application/pdf",
                    header_range(&headers).as_deref(),
                    false,
                )
                .await;
            }
            let is_docx = preview_kind == Some("docx")
                || (preview_kind.is_none() && file_ext(&path) == "docx");
            if !is_docx {
                return coded_error(
                    StatusCode::BAD_REQUEST,
                    "Preview not available for this file type",
                    "preview_unavailable",
                );
            }
            if meta.len() > DOCX_PREVIEW_MAX_BYTES {
                return coded_error(
                    StatusCode::PAYLOAD_TOO_LARGE,
                    "DOCX too large for preview (>10MB)",
                    "docx_too_large",
                );
            }
            match docx_preview_html(&path) {
                Ok(html) => {
                    let mut response = Response::new(Body::from(html));
                    let headers = response.headers_mut();
                    headers.insert(
                        header::CONTENT_TYPE,
                        HeaderValue::from_static("text/html; charset=utf-8"),
                    );
                    headers.insert(header::CACHE_CONTROL, HeaderValue::from_static("no-cache"));
                    headers.insert(
                        header::CONTENT_SECURITY_POLICY,
                        HeaderValue::from_static("default-src 'none'; img-src data:; style-src 'unsafe-inline'; base-uri 'none'; form-action 'none'; frame-ancestors 'self'"),
                    );
                    headers.insert(
                        header::REFERRER_POLICY,
                        HeaderValue::from_static("no-referrer"),
                    );
                    headers.insert(
                        header::HeaderName::from_static("x-content-type-options"),
                        HeaderValue::from_static("nosniff"),
                    );
                    response
                }
                Err(error) => crate::util::api_error(error, StatusCode::INTERNAL_SERVER_ERROR),
            }
        }
        "watch" => {
            if !meta.is_file() {
                return not_a_file();
            }
            file_watch_stream(&path, meta).await
        }
        _ => {
            if !meta.is_dir() {
                return not_a_directory();
            }
            let mut entries = Vec::new();
            if let Ok(children) = std::fs::read_dir(&path) {
                for entry in children.flatten() {
                    let name = entry.file_name().to_string_lossy().into_owned();
                    if IGNORED_NAMES.contains(&name.as_str()) || name.ends_with(".pyc") {
                        continue;
                    }
                    let is_dir = match entry.file_type() {
                        Ok(file_type) if file_type.is_dir() => true,
                        Ok(file_type) if file_type.is_file() => false,
                        _ => std::fs::metadata(entry.path())
                            .map(|meta| meta.is_dir())
                            .unwrap_or(false),
                    };
                    entries.push((name, is_dir));
                }
            }
            entries.sort_by(|a, b| {
                if a.1 != b.1 {
                    return if a.1 {
                        std::cmp::Ordering::Less
                    } else {
                        std::cmp::Ordering::Greater
                    };
                }
                a.0.to_lowercase().cmp(&b.0.to_lowercase())
            });
            let entries: Vec<Value> = entries
                .into_iter()
                .map(|(name, is_dir)| json!({ "name": name, "isDir": is_dir, "size": 0, "modified": "" }))
                .collect();
            json_status(
                StatusCode::OK,
                json!({ "entries": entries, "path": path.to_string_lossy() }),
            )
        }
    }
}

async fn file_watch_stream(path: &Path, meta: std::fs::Metadata) -> Response {
    let (sse, response) = crate::sse::channel(64);
    sse.event("connected", &json!({ "filePath": path.to_string_lossy() }))
        .await;
    let path = path.to_path_buf();
    let mut last_mtime = mtime_ms(&meta);
    let mut last_size = meta.len();
    tokio::spawn(async move {
        let mut interval = tokio::time::interval(std::time::Duration::from_millis(500));
        interval.set_missed_tick_behavior(tokio::time::MissedTickBehavior::Delay);
        loop {
            interval.tick().await;
            if sse.is_closed() {
                break;
            }
            match std::fs::metadata(&path) {
                Ok(meta) => {
                    let mtime = mtime_ms(&meta);
                    if mtime == last_mtime && meta.len() == last_size {
                        continue;
                    }
                    last_mtime = mtime;
                    last_size = meta.len();
                    sse.event(
                        "change",
                        &json!({ "mtime": crate::util::iso_from_ms(mtime), "size": meta.len() }),
                    )
                    .await;
                }
                Err(_) => {
                    sse.event("change", &json!({ "mtime": now_iso(), "size": 0 }))
                        .await;
                }
            }
        }
    });
    response
}

fn escape_html(text: &str) -> String {
    text.replace('&', "&amp;")
        .replace('<', "&lt;")
        .replace('>', "&gt;")
        .replace('"', "&quot;")
        .replace('\'', "&#39;")
}

fn docx_preview_html(path: &Path) -> Result<String, String> {
    let file = std::fs::File::open(path).map_err(|error| error.to_string())?;
    let mut archive = zip::ZipArchive::new(file).map_err(|error| error.to_string())?;
    let mut document = archive
        .by_name("word/document.xml")
        .map_err(|error| error.to_string())?;
    let mut xml = String::new();
    document
        .read_to_string(&mut xml)
        .map_err(|error| error.to_string())?;
    // Paragraph and line breaks become newlines; everything else is markup.
    let text = xml
        .replace("</w:p>", "\n")
        .replace("<w:br/>", "\n")
        .replace("<w:tab/>", "\t");
    let mut plain = String::new();
    let mut in_tag = false;
    for ch in text.chars() {
        match ch {
            '<' => in_tag = true,
            '>' => in_tag = false,
            _ if !in_tag => plain.push(ch),
            _ => {}
        }
    }
    let plain = plain
        .replace("&amp;", "&")
        .replace("&lt;", "<")
        .replace("&gt;", ">")
        .replace("&quot;", "\"")
        .replace("&apos;", "'");
    let body = plain
        .lines()
        .map(|line| format!("<p>{}</p>", escape_html(line)))
        .collect::<Vec<_>>()
        .join("\n");
    Ok(format!(
        "<!doctype html>\n<html><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\
<style>:root{{color-scheme:light}}html,body{{margin:0;min-height:100%;background:#eef1f5;color:#171717}}\
body{{font-family:-apple-system,BlinkMacSystemFont,\"Segoe UI\",sans-serif;padding:28px}}\
main{{box-sizing:border-box;max-width:840px;min-height:calc(100vh - 56px);margin:0 auto;padding:56px 64px;background:#fff;box-shadow:0 8px 28px rgba(15,23,42,.14)}}\
.file-title{{margin:0 0 28px;padding-bottom:10px;border-bottom:1px solid #e5e7eb;color:#6b7280;font:12px ui-monospace,SFMono-Regular,Menlo,Consolas,monospace;word-break:break-word}}\
p{{margin:.65em 0;line-height:1.7}}</style></head><body><main>\
<div class=\"file-title\">{title}</div>{body}</main></body></html>",
        title = escape_html(&file_name(path)),
        body = body
    ))
}

// ============================================================================
// PUT
// ============================================================================

pub async fn files_put(
    State(state): State<SharedState>,
    AxumPath(param): AxumPath<String>,
    request: axum::extract::Request,
) -> Response {
    let path = crate::util::normalize_lexically(&resolve_read_file_path(&state, &param));
    // Check both the lexical path and the canonical write target: a create
    // whose parents do not exist yet must still be confined to an allowed
    // root and must never land on models.yml/agent.db through a symlink.
    if is_denied_write_target(&state, &path) {
        return crate::util::access_denied();
    }
    if !state.is_path_allowed(&path) {
        return crate::util::access_denied();
    }
    let target_meta = std::fs::symlink_metadata(&path);
    if let Ok(meta) = &target_meta {
        if meta.file_type().is_symlink() {
            // Writing through a symlink could escape the authorized roots.
            return crate::util::access_denied();
        }
        if meta.is_dir() {
            return coded_error(
                StatusCode::BAD_REQUEST,
                "Target is a directory",
                "target_is_directory",
            );
        }
    }
    let Some(ancestor) = nearest_existing_ancestor(&path) else {
        return crate::util::access_denied();
    };
    let Some(canonical_target) = canonical_write_target(&path) else {
        return crate::util::access_denied();
    };
    if state.is_config_root_denied_file(&canonical_target)
        || !state.is_existing_path_allowed(&ancestor)
    {
        return crate::util::access_denied();
    }
    let body = match body_json(request, 25 * 1024 * 1024).await {
        Ok(body) => body,
        Err(response) => return response,
    };
    let Some(content) = body.get("content").and_then(Value::as_str) else {
        return coded_error(
            StatusCode::BAD_REQUEST,
            "content must be a string",
            "invalid_content",
        );
    };
    // "New file" from the explorer must never overwrite an existing file.
    if body.get("createOnly").and_then(Value::as_bool) == Some(true) && target_meta.is_ok() {
        return coded_error(
            StatusCode::CONFLICT,
            "File already exists",
            "file_already_exists",
        );
    }
    let expected_mtime = body.get("expectedMtime").and_then(Value::as_f64);
    if let Ok(meta) = &target_meta {
        if let Some(expected) = expected_mtime {
            if expected > 0.0 {
                let current = mtime_ms(meta);
                if (current - expected).abs() > 1000.0 {
                    return json_status(
                        StatusCode::CONFLICT,
                        json!({
                            "error": "File has been modified on disk by another process",
                            "code": "conflict_mtime",
                            "currentMtime": current,
                        }),
                    );
                }
            }
        }
    }
    if let Some(parent) = path.parent() {
        if !parent.exists() {
            if let Err(error) = std::fs::create_dir_all(parent) {
                return crate::util::api_error(error, StatusCode::INTERNAL_SERVER_ERROR);
            }
        }
    }
    if let Err(error) = crate::util::atomic_write(&path, content.as_bytes()) {
        return crate::util::api_error(error, StatusCode::INTERNAL_SERVER_ERROR);
    }
    match std::fs::metadata(&path) {
        Ok(meta) => json_status(
            StatusCode::OK,
            json!({ "success": true, "mtime": mtime_ms(&meta), "size": meta.len() }),
        ),
        Err(error) => crate::util::api_error(error, StatusCode::INTERNAL_SERVER_ERROR),
    }
}

// ============================================================================
// POST (uploads)
// ============================================================================

fn validate_upload_names(file_names: &[String]) -> Option<String> {
    if file_names.is_empty() {
        return Some("No files selected".into());
    }
    let mut seen = std::collections::HashSet::new();
    for name in file_names {
        if name.is_empty() || name == "." || name == ".." || name.contains('\0') {
            return Some(format!(
                "Invalid file name: {}",
                if name.is_empty() { "(empty)" } else { name }
            ));
        }
        if name.contains('/')
            || name.contains('\\')
            || Path::new(name).file_name().and_then(|n| n.to_str()) != Some(name.as_str())
        {
            return Some(format!("File names must not contain a path: {}", name));
        }
        if !seen.insert(name.clone()) {
            return Some(format!("Duplicate file name in upload: {}", name));
        }
    }
    None
}

struct UploadInspection {
    conflicts: Vec<String>,
    non_replaceable: Vec<String>,
}

fn inspect_upload_targets(directory: &Path, file_names: &[String]) -> UploadInspection {
    let mut conflicts = Vec::new();
    let mut non_replaceable = Vec::new();
    for name in file_names {
        let destination = directory.join(name);
        let Ok(meta) = std::fs::symlink_metadata(&destination) else {
            continue;
        };
        conflicts.push(name.clone());
        if !meta.is_file() || meta.file_type().is_symlink() {
            non_replaceable.push(name.clone());
        }
    }
    UploadInspection {
        conflicts,
        non_replaceable,
    }
}

fn upload_directory(state: &SharedState, param: &str) -> Result<PathBuf, Response> {
    let directory = strict_absolute_path(param);
    if !state.is_path_allowed(&directory) {
        return Err(crate::util::access_denied());
    }
    let meta = match std::fs::metadata(&directory) {
        Ok(meta) => meta,
        Err(_) => {
            return Err(coded_error(
                StatusCode::NOT_FOUND,
                "Upload directory not found",
                "upload_directory_not_found",
            ))
        }
    };
    if !meta.is_dir() {
        return Err(coded_error(
            StatusCode::BAD_REQUEST,
            "Upload target is not a directory",
            "upload_target_not_directory",
        ));
    }
    let real_directory = match std::fs::canonicalize(&directory) {
        Ok(path) => path,
        Err(_) => return Err(crate::util::access_denied()),
    };
    let real_roots: Vec<PathBuf> = state
        .allowed_roots()
        .iter()
        .filter_map(|root| std::fs::canonicalize(root).ok())
        .collect();
    if !real_roots
        .iter()
        .any(|root| is_within(root, &real_directory))
    {
        return Err(crate::util::access_denied());
    }
    Ok(real_directory)
}

/// Create one directory (and any missing parents) for the explorer's
/// "New folder" action, confined to the authorized roots.
fn create_directory(state: &SharedState, param: &str) -> Response {
    let target = crate::util::normalize_lexically(&strict_absolute_path(param));
    // Lexical and canonical checks: create_dir_all would happily follow a
    // symlinked parent out of the workspace.
    if is_denied_write_target(state, &target) || !state.is_path_allowed(&target) {
        return crate::util::access_denied();
    }
    let Some(ancestor) = nearest_existing_ancestor(&target) else {
        return crate::util::access_denied();
    };
    let Some(canonical_target) = canonical_write_target(&target) else {
        return crate::util::access_denied();
    };
    if !state.is_existing_path_allowed(&ancestor) || !state.is_path_allowed(&canonical_target) {
        return crate::util::access_denied();
    }
    if std::fs::symlink_metadata(&target).is_ok() {
        return coded_error(StatusCode::CONFLICT, "Already exists", "already_exists");
    }
    if let Err(error) = std::fs::create_dir_all(&target) {
        return crate::util::api_error(error, StatusCode::INTERNAL_SERVER_ERROR);
    }
    crate::routes::json_ok(json!({ "success": true, "path": target.to_string_lossy() }))
}

pub async fn files_post(
    State(state): State<SharedState>,
    AxumPath(param): AxumPath<String>,
    uri: Uri,
    request: axum::extract::Request,
) -> Response {
    let query = query(&uri);
    let request_type = query.get("type").unwrap_or("upload");

    // "New folder" from the explorer. Unlike uploads the target does not exist
    // yet, so this runs before `upload_directory` (which requires one).
    if request_type == "mkdir" {
        return create_directory(&state, &param);
    }

    let directory = match upload_directory(&state, &param) {
        Ok(directory) => directory,
        Err(response) => return response,
    };

    if request_type == "upload-check" {
        let body = match body_json(request, MAX_UPLOAD_CHECK_REQUEST_BYTES).await {
            Ok(body) => body,
            Err(response) => {
                if response.status() == StatusCode::PAYLOAD_TOO_LARGE {
                    return coded_error(
                        StatusCode::PAYLOAD_TOO_LARGE,
                        "Upload check request is too large",
                        "upload_check_too_large",
                    );
                }
                return coded_error(
                    StatusCode::BAD_REQUEST,
                    "fileNames must be an array of strings",
                    "invalid_file_names",
                );
            }
        };
        let Some(file_names) = body.get("fileNames").and_then(Value::as_array) else {
            return coded_error(
                StatusCode::BAD_REQUEST,
                "fileNames must be an array of strings",
                "invalid_file_names",
            );
        };
        let Some(file_names) = file_names
            .iter()
            .map(|value| value.as_str().map(|s| s.to_string()))
            .collect::<Option<Vec<String>>>()
        else {
            return coded_error(
                StatusCode::BAD_REQUEST,
                "fileNames must be an array of strings",
                "invalid_file_names",
            );
        };
        if let Some(error) = validate_upload_names(&file_names) {
            return json_status(StatusCode::BAD_REQUEST, json!({ "error": error }));
        }
        let inspection = inspect_upload_targets(&directory, &file_names);
        return json_status(
            StatusCode::OK,
            json!({ "conflicts": inspection.conflicts, "nonReplaceable": inspection.non_replaceable }),
        );
    }

    if request_type != "upload" {
        return coded_error(
            StatusCode::BAD_REQUEST,
            "Invalid upload request type",
            "invalid_upload_type",
        );
    }
    let strategy = match query.get("conflict").unwrap_or("error") {
        value @ ("error" | "overwrite" | "skip") => value.to_string(),
        _ => {
            return coded_error(
                StatusCode::BAD_REQUEST,
                "Invalid conflict strategy",
                "invalid_conflict_strategy",
            )
        }
    };
    let mut multipart = match Multipart::from_request(request, &()).await {
        Ok(multipart) => multipart,
        Err(_) => {
            return coded_error(
                StatusCode::PAYLOAD_TOO_LARGE,
                "Uploads must total 100MB or less",
                "upload_total_too_large",
            )
        }
    };
    let mut files: Vec<(String, Vec<u8>)> = Vec::new();
    let mut total = 0usize;
    loop {
        match multipart.next_field().await {
            Ok(Some(field)) => {
                if field.name() != Some("files") {
                    continue;
                }
                let Some(file_name) = field.file_name().map(|name| name.to_string()) else {
                    continue;
                };
                let bytes = match field.bytes().await {
                    Ok(bytes) => bytes.to_vec(),
                    Err(_) => {
                        return coded_error(
                            StatusCode::PAYLOAD_TOO_LARGE,
                            "Uploads must total 100MB or less",
                            "upload_total_too_large",
                        )
                    }
                };
                if bytes.len() > MAX_UPLOAD_FILE_BYTES {
                    return coded_error(
                        StatusCode::PAYLOAD_TOO_LARGE,
                        "Each upload must be 25MB or smaller",
                        "upload_file_too_large",
                    );
                }
                total += bytes.len();
                if total > MAX_UPLOAD_TOTAL_BYTES {
                    return coded_error(
                        StatusCode::PAYLOAD_TOO_LARGE,
                        "Uploads must total 100MB or less",
                        "upload_total_too_large",
                    );
                }
                files.push((file_name, bytes));
            }
            Ok(None) => break,
            Err(_) => {
                return coded_error(
                    StatusCode::PAYLOAD_TOO_LARGE,
                    "Uploads must total 100MB or less",
                    "upload_total_too_large",
                )
            }
        }
    }
    let file_names: Vec<String> = files.iter().map(|(name, _)| name.clone()).collect();
    if let Some(error) = validate_upload_names(&file_names) {
        return json_status(StatusCode::BAD_REQUEST, json!({ "error": error }));
    }
    if file_names
        .iter()
        .any(|name| is_denied_write_target(&state, &directory.join(name)))
    {
        return crate::util::access_denied();
    }
    let inspection = inspect_upload_targets(&directory, &file_names);
    if strategy == "error" && !inspection.conflicts.is_empty() {
        return json_status(
            StatusCode::CONFLICT,
            json!({
                "error": "One or more files already exist",
                "code": "upload_conflict",
                "conflicts": inspection.conflicts,
                "nonReplaceable": inspection.non_replaceable,
            }),
        );
    }
    let conflict_set: std::collections::HashSet<&String> = inspection.conflicts.iter().collect();
    let non_replaceable_set: std::collections::HashSet<&String> =
        inspection.non_replaceable.iter().collect();
    let mut uploaded = Vec::new();
    let mut skipped = Vec::new();
    let mut errors: Vec<Value> = Vec::new();
    for (name, bytes) in files {
        let destination = directory.join(&name);
        if conflict_set.contains(&name) {
            if strategy == "skip" {
                skipped.push(name);
                continue;
            }
            if non_replaceable_set.contains(&name) {
                errors.push(
                    json!({ "name": name, "error": "Cannot replace a directory or symbolic link" }),
                );
                continue;
            }
            if let Err(error) = std::fs::remove_file(&destination) {
                errors.push(json!({ "name": name, "error": error.to_string() }));
                continue;
            }
        }
        match std::fs::OpenOptions::new()
            .write(true)
            .create_new(true)
            .open(&destination)
        {
            Ok(mut file) => {
                use std::io::Write;
                match file.write_all(&bytes) {
                    Ok(()) => uploaded.push(name),
                    Err(error) => errors.push(json!({ "name": name, "error": error.to_string() })),
                }
            }
            Err(error) => errors.push(json!({ "name": name, "error": error.to_string() })),
        }
    }
    let status = if errors.is_empty() {
        StatusCode::OK
    } else {
        StatusCode::MULTI_STATUS
    };
    json_status(
        status,
        json!({ "uploaded": uploaded, "skipped": skipped, "errors": errors }),
    )
}

// ============================================================================
// Media
// ============================================================================

pub async fn media_get(
    State(state): State<SharedState>,
    AxumPath(hash): AxumPath<String>,
    uri: Uri,
) -> Response {
    let query = query(&uri);
    let thumb = query.has("thumb");
    media::sweep_media_cache(&state);
    let Some((bytes, mime, immutable)) = media::media_payload(&state, &hash, thumb) else {
        if media::media_file_path(&state, &hash).is_some() {
            return Response::builder()
                .status(StatusCode::UNSUPPORTED_MEDIA_TYPE)
                .body(Body::from("Not an image"))
                .unwrap_or_else(|_| StatusCode::UNSUPPORTED_MEDIA_TYPE.into_response());
        }
        return Response::builder()
            .status(StatusCode::NOT_FOUND)
            .body(Body::from("Not found"))
            .unwrap_or_else(|_| StatusCode::NOT_FOUND.into_response());
    };
    let cache = if immutable {
        "private, max-age=31536000, immutable"
    } else {
        "private, no-cache"
    };
    Response::builder()
        .status(StatusCode::OK)
        .header(header::CONTENT_TYPE, mime)
        .header(header::CACHE_CONTROL, cache)
        .header(
            header::HeaderName::from_static("x-content-type-options"),
            "nosniff",
        )
        .header(header::CONTENT_LENGTH, bytes.len().to_string())
        .body(Body::from(bytes))
        .unwrap_or_else(|_| StatusCode::INTERNAL_SERVER_ERROR.into_response())
}

#[allow(dead_code)]
fn _unused(_: &Map<String, Value>, _: &Path) -> String {
    content_disposition("", false)
}
