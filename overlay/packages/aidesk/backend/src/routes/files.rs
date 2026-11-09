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
const MAX_UPLOAD_FILE_BYTES: usize = 100 * 1024 * 1024;
const MAX_UPLOAD_TOTAL_BYTES: usize = 500 * 1024 * 1024;
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
    if ![
        "list",
        "read",
        "download",
        "download-zip",
        "meta",
        "preview",
        "watch",
    ]
    .contains(&request_type)
    {
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
    let session_id = query
        .get("sessionId")
        .or_else(|| query.get("sourceSessionId"));
    let path = resolve_read_file_path(&state, &param, session_id, true);
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
        "download-zip" => {
            if !meta.is_dir() {
                return not_a_directory();
            }
            let include_ignored = crate::util::parse_bool_param(query.get("includeIgnored"));
            return zip_directory_response(state.clone(), path, include_ignored).await;
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
            let include_ignored = crate::util::parse_bool_param(query.get("includeIgnored"));
            let mut entries: Vec<(String, bool, bool, bool, u64, f64)> = Vec::new();
            if let Ok(mut children) = tokio::fs::read_dir(&path).await {
                while let Ok(Some(entry)) = children.next_entry().await {
                    let name = entry.file_name().to_string_lossy().into_owned();
                    if name.ends_with(".pyc") {
                        continue;
                    }
                    let is_ignored = IGNORED_NAMES.contains(&name.as_str());
                    if is_ignored && !include_ignored {
                        continue;
                    }
                    let entry_path = entry.path();
                    let Ok(symlink_meta) = tokio::fs::symlink_metadata(&entry_path).await else {
                        continue;
                    };
                    let is_symlink = symlink_meta.file_type().is_symlink();
                    let followed = tokio::fs::metadata(&entry_path).await.ok();
                    let is_dir = followed
                        .as_ref()
                        .map(std::fs::Metadata::is_dir)
                        .unwrap_or_else(|| symlink_meta.is_dir());
                    let size = if is_dir {
                        0
                    } else {
                        followed
                            .as_ref()
                            .map(std::fs::Metadata::len)
                            .unwrap_or_else(|| symlink_meta.len())
                    };
                    let modified = followed
                        .as_ref()
                        .map(mtime_ms)
                        .unwrap_or_else(|| mtime_ms(&symlink_meta));
                    entries.push((name, is_dir, is_symlink, is_ignored, size, modified));
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
                .map(|(name, is_dir, is_symlink, is_ignored, size, modified)| {
                    json!({
                        "name": name,
                        "isDir": is_dir,
                        "isSymlink": is_symlink,
                        "isIgnored": is_ignored,
                        "size": size,
                        "modified": modified,
                    })
                })
                .collect();
            json_status(
                StatusCode::OK,
                json!({ "entries": entries, "path": path.to_string_lossy() }),
            )
        }
    }
}

// ============================================================================
// ZIP download
// ============================================================================

const MAX_ZIP_TOTAL_BYTES: u64 = 500 * 1024 * 1024;

enum ZipBuildError {
    TooLarge,
    Failed(String),
}

fn zip_name_ignored(name: &str, include_ignored: bool) -> bool {
    // `.git` is never packed; `node_modules` only joins an explicit request.
    name == ".git" || (!include_ignored && name == "node_modules")
}

fn add_zip_file(
    state: &SharedState,
    zip: &mut zip::ZipWriter<std::fs::File>,
    options: zip::write::SimpleFileOptions,
    path: &Path,
    archive_name: &str,
    total: &mut u64,
    meta: &std::fs::Metadata,
) -> Result<(), ZipBuildError> {
    if is_denied_write_target(state, path) {
        return Ok(());
    }
    *total = total.saturating_add(meta.len());
    if *total > MAX_ZIP_TOTAL_BYTES {
        return Err(ZipBuildError::TooLarge);
    }
    let mut file =
        std::fs::File::open(path).map_err(|error| ZipBuildError::Failed(error.to_string()))?;
    zip.start_file(archive_name, options)
        .map_err(|error| ZipBuildError::Failed(error.to_string()))?;
    std::io::copy(&mut file, zip).map_err(|error| ZipBuildError::Failed(error.to_string()))?;
    Ok(())
}

/// Walk `root` and write a zip archive to `zip_path`. Blocking; callers run it
/// on the blocking pool. Symlinks escaping the authorized roots are skipped and
/// directory links are only followed once (cycle guard).
fn build_zip_archive(
    state: SharedState,
    root: PathBuf,
    include_ignored: bool,
    zip_path: &Path,
) -> Result<(), ZipBuildError> {
    let file = std::fs::File::create(zip_path)
        .map_err(|error| ZipBuildError::Failed(error.to_string()))?;
    let mut zip = zip::ZipWriter::new(file);
    let options = zip::write::SimpleFileOptions::default()
        .compression_method(zip::CompressionMethod::Deflated)
        .unix_permissions(0o644);
    let mut total = 0u64;
    let mut stack: Vec<(PathBuf, String)> = vec![(root.clone(), String::new())];
    let mut visited: std::collections::HashSet<PathBuf> = std::collections::HashSet::new();
    if let Ok(real) = std::fs::canonicalize(&root) {
        visited.insert(real);
    }
    while let Some((dir, prefix)) = stack.pop() {
        let Ok(entries) = std::fs::read_dir(&dir) else {
            continue;
        };
        let mut children: Vec<std::fs::DirEntry> = entries.flatten().collect();
        children.sort_by_key(|entry| entry.file_name());
        for entry in children.into_iter().rev() {
            let name = entry.file_name().to_string_lossy().into_owned();
            if zip_name_ignored(&name, include_ignored) {
                continue;
            }
            let archive_name = if prefix.is_empty() {
                name.clone()
            } else {
                format!("{}/{}", prefix, name)
            };
            let path = entry.path();
            let Ok(symlink_meta) = std::fs::symlink_metadata(&path) else {
                continue;
            };
            if symlink_meta.file_type().is_symlink() {
                // Never pack a link whose target escapes the workspace.
                let Ok(real) = std::fs::canonicalize(&path) else {
                    continue;
                };
                if !state.is_existing_path_allowed(&real) {
                    continue;
                }
                let Ok(meta) = std::fs::metadata(&path) else {
                    continue;
                };
                if meta.is_dir() {
                    if visited.insert(real) {
                        stack.push((path, archive_name));
                    }
                } else if meta.is_file() {
                    add_zip_file(
                        &state,
                        &mut zip,
                        options,
                        &path,
                        &archive_name,
                        &mut total,
                        &meta,
                    )?;
                }
                continue;
            }
            if symlink_meta.is_dir() {
                stack.push((path, archive_name));
            } else if symlink_meta.is_file() {
                add_zip_file(
                    &state,
                    &mut zip,
                    options,
                    &path,
                    &archive_name,
                    &mut total,
                    &symlink_meta,
                )?;
            }
        }
    }
    zip.finish()
        .map_err(|error| ZipBuildError::Failed(error.to_string()))?;
    Ok(())
}

struct TempArchive {
    path: PathBuf,
}

impl Drop for TempArchive {
    fn drop(&mut self) {
        let _ = std::fs::remove_file(&self.path);
    }
}

async fn zip_directory_response(
    state: SharedState,
    path: PathBuf,
    include_ignored: bool,
) -> Response {
    let zip_path =
        std::env::temp_dir().join(format!("aidesk-archive-{}.zip", uuid::Uuid::new_v4()));
    let build_state = state.clone();
    let build_root = path.clone();
    let build_path = zip_path.clone();
    let built = tokio::task::spawn_blocking(move || {
        build_zip_archive(build_state, build_root, include_ignored, &build_path)
    })
    .await;
    let built = match built {
        Ok(built) => built,
        Err(_) => {
            let _ = std::fs::remove_file(&zip_path);
            return crate::util::api_error(
                "Failed to build archive",
                StatusCode::INTERNAL_SERVER_ERROR,
            );
        }
    };
    if let Err(error) = built {
        let _ = std::fs::remove_file(&zip_path);
        return match error {
            ZipBuildError::TooLarge => coded_error(
                StatusCode::PAYLOAD_TOO_LARGE,
                "Archive is too large (>500MB)",
                "archive_too_large",
            ),
            ZipBuildError::Failed(message) => {
                crate::util::api_error(message, StatusCode::INTERNAL_SERVER_ERROR)
            }
        };
    }
    let meta = match tokio::fs::metadata(&zip_path).await {
        Ok(meta) => meta,
        Err(error) => {
            let _ = std::fs::remove_file(&zip_path);
            return crate::util::api_error(error, StatusCode::INTERNAL_SERVER_ERROR);
        }
    };
    let file = match tokio::fs::File::open(&zip_path).await {
        Ok(file) => file,
        Err(error) => {
            let _ = std::fs::remove_file(&zip_path);
            return crate::util::api_error(error, StatusCode::INTERNAL_SERVER_ERROR);
        }
    };
    let guard = TempArchive {
        path: zip_path.clone(),
    };
    let stream = futures_util::stream::unfold((file, guard), |(mut file, guard)| async move {
        let mut buffer = vec![0u8; 64 * 1024];
        match tokio::io::AsyncReadExt::read(&mut file, &mut buffer).await {
            Ok(0) | Err(_) => None,
            Ok(read) => {
                buffer.truncate(read);
                Some((
                    Ok::<bytes::Bytes, std::io::Error>(bytes::Bytes::from(buffer)),
                    (file, guard),
                ))
            }
        }
    });
    let archive_name = format!("{}.zip", file_name(&path));
    let fallback: String = archive_name
        .chars()
        .map(|ch| {
            if ch.is_ascii() && !ch.is_ascii_control() && !"\"\\;".contains(ch) {
                ch
            } else {
                '_'
            }
        })
        .collect();
    Response::builder()
        .status(StatusCode::OK)
        .header(header::CONTENT_TYPE, "application/zip")
        .header(header::CONTENT_LENGTH, meta.len().to_string())
        .header(header::CACHE_CONTROL, "no-cache")
        .header(
            header::CONTENT_DISPOSITION,
            if archive_name.is_ascii() {
                format!("attachment; filename=\"{}\"", fallback)
            } else {
                content_disposition(&archive_name, false)
            },
        )
        .body(Body::from_stream(stream))
        .unwrap_or_else(|_| StatusCode::INTERNAL_SERVER_ERROR.into_response())
}

// ============================================================================
// PATCH (rename / move / copy) + DELETE
// ============================================================================

fn is_allowed_root_itself(state: &SharedState, path: &Path) -> bool {
    let key = crate::util::path_key(path);
    let canonical = std::fs::canonicalize(path).ok();
    state.allowed_roots().iter().any(|root| {
        if crate::util::path_key(root) == key {
            return true;
        }
        match (canonical.as_deref(), std::fs::canonicalize(root).ok()) {
            (Some(path), Some(root)) => path == root,
            _ => false,
        }
    })
}

fn remove_tree_blocking(target: &Path) -> std::io::Result<()> {
    let meta = std::fs::symlink_metadata(target)?;
    if meta.is_dir() && !meta.file_type().is_symlink() {
        std::fs::remove_dir_all(target)
    } else {
        std::fs::remove_file(target)
    }
}

/// Recursive copy used for directories (and the EXDEV fallback of rename).
/// Symlinks are recreated as links; links escaping the authorized roots are
/// skipped instead of followed.
fn copy_tree_blocking(state: SharedState, src: PathBuf, dst: PathBuf) -> std::io::Result<()> {
    let meta = std::fs::symlink_metadata(&src)?;
    if meta.file_type().is_symlink() {
        let target = std::fs::read_link(&src)?;
        #[cfg(unix)]
        {
            std::os::unix::fs::symlink(&target, &dst)?;
        }
        #[cfg(not(unix))]
        {
            let _ = target;
            std::fs::copy(&src, &dst)?;
        }
        return Ok(());
    }
    if meta.is_dir() {
        std::fs::create_dir_all(&dst)?;
        for entry in std::fs::read_dir(&src)? {
            let entry = entry?;
            let child_src = entry.path();
            let child_dst = dst.join(entry.file_name());
            let Ok(child_meta) = std::fs::symlink_metadata(&child_src) else {
                continue;
            };
            if child_meta.file_type().is_symlink() {
                if !state.is_existing_path_allowed(&child_src) {
                    continue;
                }
                let target = std::fs::read_link(&child_src)?;
                #[cfg(unix)]
                {
                    std::os::unix::fs::symlink(&target, &child_dst)?;
                }
                #[cfg(not(unix))]
                {
                    let _ = target;
                    std::fs::copy(&child_src, &child_dst)?;
                }
            } else if child_meta.is_dir() {
                copy_tree_blocking(state.clone(), child_src, child_dst)?;
            } else if child_meta.is_file() {
                if is_denied_write_target(&state, &child_src) {
                    continue;
                }
                std::fs::copy(&child_src, &child_dst)?;
            }
        }
        Ok(())
    } else {
        std::fs::copy(&src, &dst).map(|_| ())
    }
}

fn move_across_devices(state: SharedState, src: PathBuf, dst: PathBuf) -> std::io::Result<()> {
    let meta = std::fs::symlink_metadata(&src)?;
    if meta.file_type().is_symlink() {
        let target = std::fs::read_link(&src)?;
        #[cfg(unix)]
        {
            std::os::unix::fs::symlink(&target, &dst)?;
        }
        #[cfg(not(unix))]
        {
            let _ = target;
            std::fs::copy(&src, &dst)?;
        }
        std::fs::remove_file(&src)?;
    } else if meta.is_dir() {
        copy_tree_blocking(state, src.clone(), dst)?;
        std::fs::remove_dir_all(&src)?;
    } else {
        std::fs::copy(&src, &dst)?;
        std::fs::remove_file(&src)?;
    }
    Ok(())
}

pub async fn files_patch(
    State(state): State<SharedState>,
    AxumPath(param): AxumPath<String>,
    uri: Uri,
    request: axum::extract::Request,
) -> Response {
    let query = query(&uri);
    let source_session_id = query
        .get("sourceSessionId")
        .or_else(|| query.get("sessionId"));
    let src_path = crate::util::normalize_lexically(&resolve_read_file_path(
        &state,
        &param,
        source_session_id,
        false,
    ));
    let src_meta = match tokio::fs::symlink_metadata(&src_path).await {
        Ok(meta) => meta,
        Err(_) => return file_not_found(),
    };
    let src_is_symlink = src_meta.file_type().is_symlink();
    if is_denied_write_target(&state, &src_path) || is_allowed_root_itself(&state, &src_path) {
        return crate::util::access_denied();
    }
    let referenced = crate::omp::session_reader::is_file_referenced_by_session(
        &state.cfg,
        &src_path,
        source_session_id,
    );
    let in_root = state.is_path_allowed(&src_path);
    let canonical_allowed = if src_is_symlink {
        in_root
    } else {
        state.is_existing_path_allowed(&src_path)
    };
    if !(in_root || canonical_allowed || referenced) {
        return crate::util::access_denied();
    }

    let body = match body_json(request, 64 * 1024).await {
        Ok(body) => body,
        Err(response) => return response,
    };
    let action = match body.get("action").and_then(Value::as_str) {
        Some(action @ ("rename" | "move" | "copy")) => action.to_string(),
        _ => {
            return coded_error(
                StatusCode::BAD_REQUEST,
                "action must be rename, move or copy",
                "invalid_action",
            )
        }
    };
    let Some(destination) = body.get("destination").and_then(Value::as_str) else {
        return coded_error(
            StatusCode::BAD_REQUEST,
            "destination must be a string",
            "invalid_destination",
        );
    };
    let overwrite = body.get("overwrite").and_then(Value::as_bool);
    if !destination.starts_with('/') {
        return coded_error(
            StatusCode::BAD_REQUEST,
            "destination must be an absolute path",
            "destination_must_be_absolute",
        );
    }
    let dst_path = crate::util::normalize_lexically(Path::new(destination));
    let Some(dst_parent) = dst_path.parent() else {
        return coded_error(
            StatusCode::BAD_REQUEST,
            "Invalid destination",
            "invalid_destination",
        );
    };
    let Some(dst_name) = dst_path.file_name() else {
        return coded_error(
            StatusCode::BAD_REQUEST,
            "Invalid destination",
            "invalid_destination",
        );
    };
    match tokio::fs::metadata(dst_parent).await {
        Ok(meta) if meta.is_dir() => {}
        _ => {
            return coded_error(
                StatusCode::BAD_REQUEST,
                "Destination parent directory does not exist",
                "destination_parent_not_found",
            )
        }
    }
    if !state.is_existing_path_allowed(dst_parent) || is_denied_write_target(&state, &dst_path) {
        return crate::util::access_denied();
    }
    let dst_parent_canonical = match tokio::fs::canonicalize(dst_parent).await {
        Ok(path) => path,
        Err(_) => return crate::util::access_denied(),
    };
    let dst_target_canonical =
        crate::util::normalize_lexically(&dst_parent_canonical.join(dst_name));
    let src_canonical = tokio::fs::canonicalize(&src_path)
        .await
        .unwrap_or_else(|_| src_path.clone());

    if src_meta.is_dir() && !src_is_symlink && is_within(&src_canonical, &dst_parent_canonical) {
        return coded_error(
            StatusCode::BAD_REQUEST,
            "Cannot move or copy a directory into itself",
            "destination_inside_source",
        );
    }
    if dst_target_canonical != src_canonical && is_within(&dst_target_canonical, &src_canonical) {
        return coded_error(
            StatusCode::BAD_REQUEST,
            "Destination contains the source and cannot be overwritten",
            "destination_contains_source",
        );
    }

    let same_path = crate::util::path_key(&src_path) == crate::util::path_key(&dst_path)
        || (!src_is_symlink && dst_target_canonical == src_canonical);
    let dst_exists = tokio::fs::symlink_metadata(&dst_path).await.is_ok();
    if dst_exists {
        if overwrite == Some(true) {
            if same_path {
                state.invalidate_file_index_cache(&src_path);
                state.invalidate_file_index_cache(&dst_path);
                return json_status(
                    StatusCode::OK,
                    json!({
                        "success": true,
                        "path": dst_path.to_string_lossy(),
                        "action": action,
                    }),
                );
            }
            if let Err(error) = remove_tree_blocking(&dst_path) {
                return crate::util::api_error(error, StatusCode::INTERNAL_SERVER_ERROR);
            }
        } else {
            return json_status(
                StatusCode::CONFLICT,
                json!({ "error": "Target already exists", "code": "already_exists" }),
            );
        }
    }

    let result: std::io::Result<()> = match action.as_str() {
        "rename" | "move" => match tokio::fs::rename(&src_path, &dst_path).await {
            Ok(()) => Ok(()),
            Err(error) if error.raw_os_error() == Some(libc::EXDEV) => {
                let move_state = state.clone();
                let move_src = src_path.clone();
                let move_dst = dst_path.clone();
                tokio::task::spawn_blocking(move || {
                    move_across_devices(move_state, move_src, move_dst)
                })
                .await
                .unwrap_or_else(|error| Err(std::io::Error::other(error.to_string())))
            }
            Err(error) => Err(error),
        },
        _ => {
            if src_is_symlink {
                let target = match tokio::fs::read_link(&src_path).await {
                    Ok(target) => target,
                    Err(error) => {
                        return crate::util::api_error(error, StatusCode::INTERNAL_SERVER_ERROR)
                    }
                };
                #[cfg(unix)]
                {
                    std::os::unix::fs::symlink(&target, &dst_path).map_err(std::io::Error::from)
                }
                #[cfg(not(unix))]
                {
                    let _ = target;
                    tokio::fs::copy(&src_path, &dst_path).await.map(|_| ())
                }
            } else if src_meta.is_dir() {
                let copy_state = state.clone();
                let copy_src = src_path.clone();
                let copy_dst = dst_path.clone();
                tokio::task::spawn_blocking(move || {
                    copy_tree_blocking(copy_state, copy_src, copy_dst)
                })
                .await
                .unwrap_or_else(|error| Err(std::io::Error::other(error.to_string())))
            } else {
                tokio::fs::copy(&src_path, &dst_path).await.map(|_| ())
            }
        }
    };
    if let Err(error) = result {
        // A failed copy may have left a partial target behind.
        let _ = remove_tree_blocking(&dst_path);
        return crate::util::api_error(error, StatusCode::INTERNAL_SERVER_ERROR);
    }
    state.invalidate_file_index_cache(&src_path);
    state.invalidate_file_index_cache(&dst_path);
    json_status(
        StatusCode::OK,
        json!({
            "success": true,
            "path": dst_path.to_string_lossy(),
            "action": action,
        }),
    )
}

pub async fn files_delete(
    State(state): State<SharedState>,
    AxumPath(param): AxumPath<String>,
    uri: Uri,
) -> Response {
    let query = query(&uri);
    let source_session_id = query
        .get("sourceSessionId")
        .or_else(|| query.get("sessionId"));
    let target = crate::util::normalize_lexically(&resolve_read_file_path(
        &state,
        &param,
        source_session_id,
        false,
    ));
    if !state.is_path_allowed(&target) {
        return crate::util::access_denied();
    }
    if is_allowed_root_itself(&state, &target) {
        return coded_error(
            StatusCode::FORBIDDEN,
            "Cannot delete an allowed root directory",
            "cannot_delete_root",
        );
    }
    if is_denied_write_target(&state, &target) {
        return crate::util::access_denied();
    }
    let meta = match tokio::fs::symlink_metadata(&target).await {
        Ok(meta) => meta,
        Err(_) => return file_not_found(),
    };
    let is_symlink = meta.file_type().is_symlink();
    if !is_symlink && !state.is_existing_path_allowed(&target) {
        return crate::util::access_denied();
    }
    let recursive = match query.get("recursive") {
        Some(value) => !matches!(value.to_ascii_lowercase().as_str(), "0" | "false" | "no"),
        None => true,
    };
    let result = if is_symlink || !meta.is_dir() {
        tokio::fs::remove_file(&target).await
    } else if recursive {
        tokio::fs::remove_dir_all(&target).await
    } else {
        tokio::fs::remove_dir(&target).await
    };
    if let Err(error) = result {
        if error.kind() == std::io::ErrorKind::DirectoryNotEmpty {
            return coded_error(
                StatusCode::CONFLICT,
                "Directory is not empty",
                "directory_not_empty",
            );
        }
        return crate::util::api_error(error, StatusCode::INTERNAL_SERVER_ERROR);
    }
    state.invalidate_file_index_cache(&target);
    json_status(
        StatusCode::OK,
        json!({ "success": true, "deleted": target.to_string_lossy() }),
    )
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
        // JSON ping every 15s: Nginx' streamProxy read timeout is 600s, and
        // the browser watchdog needs a real frame to notice a half-open link.
        let mut heartbeat = tokio::time::interval_at(
            tokio::time::Instant::now() + std::time::Duration::from_secs(15),
            std::time::Duration::from_secs(15),
        );
        heartbeat.set_missed_tick_behavior(tokio::time::MissedTickBehavior::Delay);
        loop {
            tokio::select! {
                _ = interval.tick() => {
                    if sse.is_closed() {
                        break;
                    }
                    // Async metadata: the watcher must not block a runtime
                    // worker on a slow/remote filesystem.
                    match tokio::fs::metadata(&path).await {
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
                _ = heartbeat.tick() => {
                    if !sse.ping().await {
                        break;
                    }
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
    let path =
        crate::util::normalize_lexically(&resolve_read_file_path(&state, &param, None, true));
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
    state.invalidate_file_index_cache(&path);
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

/// Normalize and validate one uploaded relative path. Backslashes are folded
/// to `/`; absolute paths, `.`/`..`, empty components, control characters and
/// `.git` components are rejected so a field can never escape the target
/// directory.
fn normalize_upload_name(name: &str) -> Option<String> {
    let replaced = name.replace('\\', "/");
    if replaced.is_empty() || replaced.starts_with('/') {
        return None;
    }
    if replaced.chars().any(|ch| ch == '\0' || ch.is_control()) {
        return None;
    }
    let mut parts: Vec<&str> = Vec::new();
    for part in replaced.split('/') {
        if part.is_empty() || part == "." || part == ".." || part == ".git" {
            return None;
        }
        parts.push(part);
    }
    Some(parts.join("/"))
}

fn validate_upload_names(file_names: &[String]) -> Option<String> {
    if file_names.is_empty() {
        return Some("No files selected".into());
    }
    let mut seen = std::collections::HashSet::new();
    for name in file_names {
        if normalize_upload_name(name).as_deref() != Some(name.as_str()) {
            return Some(format!("Invalid file name: {}", name));
        }
        if !seen.insert(name.as_str()) {
            return Some(format!("Duplicate file name in upload: {}", name));
        }
    }
    None
}

/// Pick the first free `stem (n).ext` beside an existing target.
fn unique_upload_name(
    rel: &str,
    directory: &Path,
    taken: &mut std::collections::HashSet<String>,
) -> String {
    let rel_path = Path::new(rel);
    let parent = rel_path.parent().filter(|p| !p.as_os_str().is_empty());
    let file = rel_path
        .file_name()
        .and_then(|name| name.to_str())
        .unwrap_or(rel);
    let stem = Path::new(file)
        .file_stem()
        .and_then(|stem| stem.to_str())
        .unwrap_or(file);
    let extension = Path::new(file).extension().and_then(|ext| ext.to_str());
    let mut index = 1u32;
    loop {
        let candidate_name = match extension {
            Some(extension) => format!("{} ({}).{}", stem, index, extension),
            None => format!("{} ({})", stem, index),
        };
        let candidate = match parent {
            Some(parent) => parent.join(&candidate_name),
            None => PathBuf::from(&candidate_name),
        };
        let relative = candidate.to_string_lossy().replace('\\', "/");
        if !taken.contains(&relative)
            && std::fs::symlink_metadata(directory.join(&candidate)).is_err()
        {
            taken.insert(relative.clone());
            return relative;
        }
        if index >= 100_000 {
            let fallback = format!("{}-{}", stem, uuid::Uuid::new_v4());
            taken.insert(fallback.clone());
            return fallback;
        }
        index += 1;
    }
}

/// Create the intermediate directories of a staged upload, refusing to walk
/// through symlinks or escape the resolved upload directory.
async fn prepare_upload_directory(real_directory: &Path, destination: &Path) -> Result<(), String> {
    let parent = destination
        .parent()
        .ok_or_else(|| "Invalid upload path".to_string())?;
    if !is_within(real_directory, parent) {
        return Err("Upload path escapes the target directory".into());
    }
    let relative = parent
        .strip_prefix(real_directory)
        .map_err(|_| "Upload path escapes the target directory".to_string())?;
    let mut current = real_directory.to_path_buf();
    for component in relative.components() {
        let std::path::Component::Normal(part) = component else {
            return Err("Invalid upload path".into());
        };
        current.push(part);
        match tokio::fs::symlink_metadata(&current).await {
            Ok(meta) => {
                if meta.file_type().is_symlink() || !meta.is_dir() {
                    return Err(format!(
                        "Cannot create a directory through {}",
                        current.to_string_lossy()
                    ));
                }
            }
            Err(_) => {
                tokio::fs::create_dir(&current)
                    .await
                    .map_err(|error| error.to_string())?;
            }
        }
        let canonical = tokio::fs::canonicalize(&current)
            .await
            .map_err(|error| error.to_string())?;
        if !is_within(real_directory, &canonical) {
            return Err("Upload path escapes the target directory".into());
        }
    }
    Ok(())
}

async fn cleanup_upload_files(paths: &[PathBuf]) {
    for path in paths {
        let _ = tokio::fs::remove_file(path).await;
    }
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
    state.invalidate_file_index_cache(&target);
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
                    "files must be an array of strings",
                    "invalid_file_names",
                );
            }
        };
        let raw_names = body
            .get("files")
            .or_else(|| body.get("fileNames"))
            .and_then(Value::as_array);
        let Some(raw_names) = raw_names else {
            return coded_error(
                StatusCode::BAD_REQUEST,
                "files must be an array of strings",
                "invalid_file_names",
            );
        };
        let Some(raw_names) = raw_names
            .iter()
            .map(|value| value.as_str().map(|s| s.to_string()))
            .collect::<Option<Vec<String>>>()
        else {
            return coded_error(
                StatusCode::BAD_REQUEST,
                "files must be an array of strings",
                "invalid_file_names",
            );
        };
        let mut file_names = Vec::with_capacity(raw_names.len());
        for raw_name in raw_names {
            match normalize_upload_name(&raw_name) {
                Some(name) => file_names.push(name),
                None => {
                    return json_status(
                        StatusCode::BAD_REQUEST,
                        json!({
                            "error": format!("Invalid file name: {}", raw_name),
                            "code": "invalid_file_name",
                        }),
                    )
                }
            }
        }
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
        value @ ("error" | "overwrite" | "skip" | "rename") => value.to_string(),
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
                "Uploads must total 500MB or less",
                "upload_total_too_large",
            )
        }
    };
    use tokio::io::AsyncWriteExt;

    // Fields stream to per-file temporary files in the destination directory;
    // nothing is committed until every field has been received and validated.
    let mut staging: Vec<(String, PathBuf)> = Vec::new();
    let mut temp_paths: Vec<PathBuf> = Vec::new();
    let mut total = 0usize;
    loop {
        let mut field = match multipart.next_field().await {
            Ok(Some(field)) => field,
            Ok(None) => break,
            Err(_) => {
                cleanup_upload_files(&temp_paths).await;
                return coded_error(
                    StatusCode::PAYLOAD_TOO_LARGE,
                    "Uploads must total 500MB or less",
                    "upload_total_too_large",
                );
            }
        };
        if field.name() != Some("files") {
            continue;
        }
        let Some(raw_name) = field.file_name().map(|name| name.to_string()) else {
            continue;
        };
        let Some(name) = normalize_upload_name(&raw_name) else {
            cleanup_upload_files(&temp_paths).await;
            return json_status(
                StatusCode::BAD_REQUEST,
                json!({
                    "error": format!("Invalid file name: {}", raw_name),
                    "code": "invalid_file_name",
                }),
            );
        };
        let temp_path = directory.join(format!(".aidesk-upload-{}.part", uuid::Uuid::new_v4()));
        temp_paths.push(temp_path.clone());
        let mut file = match tokio::fs::File::create(&temp_path).await {
            Ok(file) => file,
            Err(error) => {
                cleanup_upload_files(&temp_paths).await;
                return crate::util::api_error(error, StatusCode::INTERNAL_SERVER_ERROR);
            }
        };
        let mut field_size = 0usize;
        loop {
            match field.chunk().await {
                Ok(Some(chunk)) => {
                    field_size += chunk.len();
                    if field_size > MAX_UPLOAD_FILE_BYTES {
                        drop(file);
                        cleanup_upload_files(&temp_paths).await;
                        return coded_error(
                            StatusCode::PAYLOAD_TOO_LARGE,
                            "Each upload must be 100MB or smaller",
                            "upload_file_too_large",
                        );
                    }
                    total += chunk.len();
                    if total > MAX_UPLOAD_TOTAL_BYTES {
                        drop(file);
                        cleanup_upload_files(&temp_paths).await;
                        return coded_error(
                            StatusCode::PAYLOAD_TOO_LARGE,
                            "Uploads must total 500MB or less",
                            "upload_total_too_large",
                        );
                    }
                    if let Err(error) = file.write_all(&chunk).await {
                        drop(file);
                        cleanup_upload_files(&temp_paths).await;
                        return crate::util::api_error(error, StatusCode::INTERNAL_SERVER_ERROR);
                    }
                }
                Ok(None) => break,
                Err(_) => {
                    drop(file);
                    cleanup_upload_files(&temp_paths).await;
                    return coded_error(
                        StatusCode::PAYLOAD_TOO_LARGE,
                        "Uploads must total 500MB or less",
                        "upload_total_too_large",
                    );
                }
            }
        }
        if let Err(error) = file.flush().await {
            drop(file);
            cleanup_upload_files(&temp_paths).await;
            return crate::util::api_error(error, StatusCode::INTERNAL_SERVER_ERROR);
        }
        drop(file);
        staging.push((name, temp_path));
    }
    let file_names: Vec<String> = staging.iter().map(|(name, _)| name.clone()).collect();
    if let Some(error) = validate_upload_names(&file_names) {
        cleanup_upload_files(&temp_paths).await;
        return json_status(StatusCode::BAD_REQUEST, json!({ "error": error }));
    }
    if file_names
        .iter()
        .any(|name| is_denied_write_target(&state, &directory.join(name)))
    {
        cleanup_upload_files(&temp_paths).await;
        return crate::util::access_denied();
    }
    let inspection = inspect_upload_targets(&directory, &file_names);
    if strategy == "error" && !inspection.conflicts.is_empty() {
        cleanup_upload_files(&temp_paths).await;
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
    let conflict_set: std::collections::HashSet<String> =
        inspection.conflicts.iter().cloned().collect();
    let non_replaceable_set: std::collections::HashSet<String> =
        inspection.non_replaceable.iter().cloned().collect();
    // Reserve every requested name up front so auto-renames cannot steal a
    // sibling upload's destination.
    let mut taken: std::collections::HashSet<String> = file_names.iter().cloned().collect();
    let mut uploaded = Vec::new();
    let mut skipped = Vec::new();
    let mut errors: Vec<Value> = Vec::new();
    for (name, temp_path) in staging {
        let conflicted = conflict_set.contains(&name);
        if conflicted {
            if strategy == "skip" {
                skipped.push(name);
                continue;
            }
            if strategy != "rename" && non_replaceable_set.contains(&name) {
                errors.push(
                    json!({ "name": name, "error": "Cannot replace a directory or symbolic link" }),
                );
                continue;
            }
        }
        let final_name = if conflicted && strategy == "rename" {
            unique_upload_name(&name, &directory, &mut taken)
        } else {
            name.clone()
        };
        let destination = directory.join(&final_name);
        if let Err(message) = prepare_upload_directory(&directory, &destination).await {
            errors.push(json!({ "name": name, "error": message }));
            continue;
        }
        if conflicted && strategy == "overwrite" {
            if let Ok(meta) = tokio::fs::symlink_metadata(&destination).await {
                if meta.file_type().is_symlink() || !meta.is_dir() {
                    if let Err(error) = tokio::fs::remove_file(&destination).await {
                        errors.push(json!({ "name": name, "error": error.to_string() }));
                        continue;
                    }
                } else {
                    errors.push(json!({
                        "name": name,
                        "error": "Cannot replace a directory or symbolic link",
                    }));
                    continue;
                }
            }
        }
        match tokio::fs::rename(&temp_path, &destination).await {
            Ok(()) => uploaded.push(final_name),
            Err(error) => errors.push(json!({ "name": name, "error": error.to_string() })),
        }
    }
    cleanup_upload_files(&temp_paths).await;
    if !uploaded.is_empty() {
        state.invalidate_file_index_cache(&directory);
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
