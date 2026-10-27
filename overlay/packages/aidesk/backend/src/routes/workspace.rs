//! Workspace, project, git and file-index routes.

use crate::omp::projects;
use crate::omp::session_reader;
use crate::routes::{body_json, json_ok, query, require_cwd};
use crate::state::SharedState;
use crate::util::{coded_error, expand_tilde, iso_from_ms, now_ms, path_key};
use axum::body::Body;
use axum::extract::State;
use axum::http::{StatusCode, Uri};
use axum::response::{IntoResponse, Response};
use serde_json::{json, Map, Value};
use std::collections::{HashMap, HashSet};
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};
use std::sync::{LazyLock, Mutex};
use std::time::{Duration, Instant};

// ============================================================================
// Home / default cwd / directory browser / cwd validation
// ============================================================================

pub async fn home(State(state): State<SharedState>) -> Response {
    json_ok(json!({ "home": state.cfg.home.to_string_lossy() }))
}

pub async fn default_cwd(State(state): State<SharedState>) -> Response {
    let date = iso_from_ms(now_ms())
        .get(0..10)
        .unwrap_or("1970-01-01")
        .replace('-', "");
    let dir = state.cfg.home.join(format!("omp-cwd-{}", date));
    if let Err(error) = std::fs::create_dir_all(&dir) {
        return crate::util::api_error(error, StatusCode::INTERNAL_SERVER_ERROR);
    }
    state.allow_root(&dir);
    json_ok(json!({ "cwd": dir.to_string_lossy() }))
}

fn is_os_root(path: &Path) -> bool {
    path.parent().is_none() || path == Path::new("/")
}

pub async fn cwd_browse(State(state): State<SharedState>, uri: Uri) -> Response {
    let query = query(&uri);
    let requested = query
        .get("path")
        .map(|path| path.trim())
        .filter(|path| !path.is_empty());
    let candidate = match requested {
        Some(path) => {
            if path == "~" {
                state.cfg.home.clone()
            } else if path.starts_with("~/") {
                expand_tilde(path, &state.cfg.home)
            } else {
                PathBuf::from(path)
            }
        }
        None => state.cfg.home.clone(),
    };
    let resolved = match std::fs::canonicalize(&candidate) {
        Ok(path) => path,
        Err(_) => {
            return coded_error(
                StatusCode::NOT_FOUND,
                "Directory does not exist",
                "directory_not_found",
            )
        }
    };
    let meta = match std::fs::metadata(&resolved) {
        Ok(meta) => meta,
        Err(_) => {
            return coded_error(
                StatusCode::NOT_FOUND,
                "Directory does not exist",
                "directory_not_found",
            )
        }
    };
    if !meta.is_dir() {
        return coded_error(
            StatusCode::BAD_REQUEST,
            "Path is not a directory",
            "not_a_directory",
        );
    }
    let mut directories = Vec::new();
    if let Ok(entries) = std::fs::read_dir(&resolved) {
        for entry in entries.flatten() {
            let Ok(file_type) = entry.file_type() else {
                continue;
            };
            let name = entry.file_name().to_string_lossy().into_owned();
            let is_directory = if file_type.is_dir() {
                true
            } else if file_type.is_symlink() {
                std::fs::metadata(entry.path())
                    .map(|meta| meta.is_dir())
                    .unwrap_or(false)
            } else {
                false
            };
            if is_directory {
                directories.push(json!({
                    "name": name,
                    "path": resolved.join(&name).to_string_lossy(),
                }));
            }
        }
    }
    directories.sort_by(|a, b| {
        let left = a
            .get("name")
            .and_then(Value::as_str)
            .unwrap_or("")
            .to_lowercase();
        let right = b
            .get("name")
            .and_then(Value::as_str)
            .unwrap_or("")
            .to_lowercase();
        left.cmp(&right)
    });
    let parent_path = if is_os_root(&resolved) {
        Value::Null
    } else {
        Value::String(
            resolved
                .parent()
                .map(|parent| parent.to_string_lossy().into_owned())
                .unwrap_or_default(),
        )
    };
    json_ok(json!({
        "path": resolved.to_string_lossy(),
        "parentPath": parent_path,
        "directories": directories,
    }))
}

pub async fn cwd_validate(
    State(state): State<SharedState>,
    request: axum::extract::Request,
) -> Response {
    let body = match body_json(request, 1024 * 1024).await {
        Ok(body) => body,
        Err(response) => return response,
    };
    let cwd = body
        .get("cwd")
        .and_then(Value::as_str)
        .map(str::trim)
        .unwrap_or("")
        .to_string();
    if cwd.is_empty() {
        return coded_error(StatusCode::BAD_REQUEST, "Path is required", "path_required");
    }
    let normalized = if cwd == "~" {
        state.cfg.home.clone()
    } else if cwd.starts_with("~/") {
        expand_tilde(&cwd, &state.cfg.home)
    } else {
        crate::util::absolute_path(Path::new(&cwd))
    };
    let meta = match std::fs::metadata(&normalized) {
        Ok(meta) => meta,
        Err(_) => {
            return coded_error(
                StatusCode::BAD_REQUEST,
                &format!("Directory does not exist: {}", cwd),
                "directory_not_found",
            )
        }
    };
    if !meta.is_dir() {
        return coded_error(
            StatusCode::BAD_REQUEST,
            &format!("Path is not a directory: {}", cwd),
            "not_a_directory",
        );
    }
    state.allow_root(&normalized);
    let (project_root, project_key) = projects::project_identity(&normalized);
    json_ok(json!({
        "success": true,
        "cwd": normalized.to_string_lossy(),
        "projectRoot": project_root,
        "projectKey": project_key,
    }))
}

// ============================================================================
// Projects registry
// ============================================================================

pub async fn projects_get(State(state): State<SharedState>) -> Response {
    let registry = projects::load_registry(&state.cfg);
    let sessions = session_reader::list_all_sessions(&state.cfg);
    let discovered: Vec<String> = sessions
        .into_iter()
        .map(|session| {
            if session.project_root.is_empty() {
                session.cwd
            } else {
                session.project_root
            }
        })
        .collect();
    let merged = projects::merge_projects(&registry, discovered);
    for project in &merged {
        if let Some(path) = project.get("path").and_then(Value::as_str) {
            state.allow_root(Path::new(path));
        }
    }
    json_ok(json!({ "projects": merged }))
}

fn project_error(code: &str, message: String) -> Response {
    crate::util::json_status(
        StatusCode::BAD_REQUEST,
        json!({ "error": message, "code": code }),
    )
}

pub async fn projects_post(
    State(state): State<SharedState>,
    request: axum::extract::Request,
) -> Response {
    let body = match body_json(request, 1024 * 1024).await {
        Ok(body) => body,
        Err(response) => return response,
    };
    let cwd = body.get("cwd").and_then(Value::as_str).unwrap_or("");
    let launch_config = match projects::parse_launch_config(body.get("launchConfig")) {
        Ok(config) => config,
        Err((code, message)) => return project_error(code, message),
    };
    let normalized = match projects::validate_project_path(&state.cfg, cwd) {
        Ok(path) => path,
        Err((code, message)) => return project_error(code, message),
    };
    let project = session_reader::resolve_project(&normalized.to_string_lossy());
    let mut registry = projects::load_registry(&state.cfg);
    projects::upsert(
        &mut registry,
        Path::new(&project.project_root),
        launch_config,
    );
    if let Err(error) = projects::save_registry(&state.cfg, &registry) {
        return crate::util::api_error(error, StatusCode::INTERNAL_SERVER_ERROR);
    }
    state.allow_root(Path::new(&project.project_root));
    let entry = registry.iter().find(|entry| {
        path_key(Path::new(&entry.path)) == path_key(Path::new(&project.project_root))
    });
    let mut payload = Map::new();
    if let Some(entry) = entry {
        payload.insert("path".into(), Value::String(entry.path.clone()));
        payload.insert("addedAt".into(), Value::String(entry.added_at.clone()));
        if let Some(config) = &entry.launch_config {
            payload.insert("launchConfig".into(), config.clone());
        }
    }
    json_ok(json!({ "project": Value::Object(payload) }))
}

fn normalize_probe_path(cfg: &crate::config::Config, cwd: &str) -> PathBuf {
    let trimmed = cwd.trim();
    let expanded = if trimmed == "~" {
        cfg.home.clone()
    } else if let Some(rest) = trimmed.strip_prefix("~/") {
        cfg.home.join(rest)
    } else {
        PathBuf::from(trimmed)
    };
    crate::util::canonical_or_original(&crate::util::absolute_path(&expanded))
}

pub async fn projects_patch(
    State(state): State<SharedState>,
    request: axum::extract::Request,
) -> Response {
    let body = match body_json(request, 2 * 1024 * 1024).await {
        Ok(body) => body,
        Err(response) => return response,
    };
    let raw_updates: Vec<Value> = match body.get("updates") {
        Some(Value::Array(items)) => items.clone(),
        _ => {
            if ["cwd", "alias", "sortOrder", "launchConfig"]
                .iter()
                .any(|key| body.get(*key).is_some())
            {
                vec![json!({
                    "cwd": body.get("cwd"),
                    "alias": body.get("alias"),
                    "sortOrder": body.get("sortOrder"),
                    "launchConfig": body.get("launchConfig"),
                })]
            } else {
                Vec::new()
            }
        }
    };
    if raw_updates.is_empty() {
        return coded_error(StatusCode::BAD_REQUEST, "Path is required", "path_required");
    }
    if raw_updates.len() > 500 {
        return coded_error(
            StatusCode::BAD_REQUEST,
            "Too many updates",
            "too_many_updates",
        );
    }
    let bulk = raw_updates.len() > 1;
    let registry_before = projects::load_registry(&state.cfg);
    let is_already_managed = |cwd: &str| -> Option<String> {
        let probe = normalize_probe_path(&state.cfg, cwd);
        let key = path_key(&probe);
        registry_before
            .iter()
            .find(|entry| path_key(Path::new(&entry.path)) == key)
            .map(|entry| entry.path.clone())
    };

    struct Update {
        path: String,
        alias: Option<Option<String>>,
        sort_order: Option<Option<f64>>,
        launch_config: Option<Option<Value>>,
    }
    let mut parsed: Vec<Update> = Vec::new();
    let mut skipped: Vec<Value> = Vec::new();
    for item in raw_updates {
        let cwd = item
            .get("cwd")
            .and_then(Value::as_str)
            .unwrap_or("")
            .trim()
            .to_string();
        if cwd.is_empty() {
            return coded_error(StatusCode::BAD_REQUEST, "Path is required", "path_required");
        }
        let alias = match item.get("alias") {
            None => None,
            Some(Value::Null) => Some(None),
            Some(Value::String(text)) => Some(Some(text.clone())),
            Some(_) => {
                return coded_error(
                    StatusCode::BAD_REQUEST,
                    "Alias must be a string",
                    "invalid_alias",
                )
            }
        };
        let sort_order = match item.get("sortOrder") {
            None => None,
            Some(Value::Null) => Some(None),
            Some(Value::Number(number)) => match number.as_f64() {
                Some(value) => Some(Some(value)),
                None => {
                    return coded_error(
                        StatusCode::BAD_REQUEST,
                        "Sort order must be a number",
                        "invalid_sort_order",
                    )
                }
            },
            Some(_) => {
                return coded_error(
                    StatusCode::BAD_REQUEST,
                    "Sort order must be a number",
                    "invalid_sort_order",
                )
            }
        };
        let launch_config = match item.get("launchConfig") {
            None => None,
            Some(Value::Null) => Some(None),
            Some(value) => match projects::parse_launch_config(Some(value)) {
                Ok(Some(config)) => Some(Some(config)),
                Ok(None) => None,
                Err((code, message)) => return project_error(code, message),
            },
        };
        let path = if let Some(managed) = is_already_managed(&cwd) {
            managed
        } else {
            match projects::validate_project_path(&state.cfg, &cwd) {
                Ok(path) => {
                    let project = session_reader::resolve_project(&path.to_string_lossy());
                    project.project_root
                }
                Err((code, message)) => {
                    if bulk {
                        skipped.push(json!({ "cwd": cwd, "code": code, "error": message }));
                        continue;
                    }
                    return project_error(code, message);
                }
            }
        };
        parsed.push(Update {
            path,
            alias,
            sort_order,
            launch_config,
        });
    }
    if parsed.is_empty() && !skipped.is_empty() {
        let first = &skipped[0];
        return crate::util::json_status(
            StatusCode::BAD_REQUEST,
            json!({
                "error": first.get("error").cloned().unwrap_or(Value::Null),
                "code": first.get("code").cloned().unwrap_or(Value::Null),
            }),
        );
    }
    // Merge duplicate targets per field (later defined fields win).
    let mut merged: Vec<Update> = Vec::new();
    for update in parsed {
        let key = path_key(Path::new(&update.path));
        match merged
            .iter_mut()
            .find(|existing| path_key(Path::new(&existing.path)) == key)
        {
            Some(existing) => {
                if update.alias.is_some() {
                    existing.alias = update.alias;
                }
                if update.sort_order.is_some() {
                    existing.sort_order = update.sort_order;
                }
                if update.launch_config.is_some() {
                    existing.launch_config = update.launch_config;
                }
            }
            None => merged.push(update),
        }
    }

    let mut registry = projects::load_registry(&state.cfg);
    let mut new_roots = Vec::new();
    for update in &merged {
        if !registry
            .iter()
            .any(|entry| path_key(Path::new(&entry.path)) == path_key(Path::new(&update.path)))
        {
            projects::upsert(&mut registry, Path::new(&update.path), None);
            new_roots.push(update.path.clone());
        }
    }
    let visible: Vec<&Update> = merged
        .iter()
        .filter(|update| {
            registry
                .iter()
                .find(|entry| path_key(Path::new(&entry.path)) == path_key(Path::new(&update.path)))
                .map(|entry| !entry.hidden)
                .unwrap_or(false)
        })
        .collect();
    let presentation: Vec<(
        String,
        Option<Option<String>>,
        Option<Option<f64>>,
        Option<Option<Value>>,
    )> = visible
        .iter()
        .map(|update| {
            (
                update.path.clone(),
                update.alias.clone(),
                update.sort_order,
                update.launch_config.clone(),
            )
        })
        .collect();
    projects::update_presentation(&mut registry, &presentation);
    if let Err(error) = projects::save_registry(&state.cfg, &registry) {
        return crate::util::api_error(error, StatusCode::INTERNAL_SERVER_ERROR);
    }
    for root in new_roots {
        state.allow_root(Path::new(&root));
    }
    let updated_keys: HashSet<String> = visible
        .iter()
        .map(|update| path_key(Path::new(&update.path)))
        .collect();
    let projects_payload: Vec<Value> = registry
        .iter()
        .filter(|entry| updated_keys.contains(&path_key(Path::new(&entry.path))))
        .map(|entry| {
            let mut object = Map::new();
            object.insert("path".into(), Value::String(entry.path.clone()));
            object.insert("addedAt".into(), Value::String(entry.added_at.clone()));
            object.insert("hidden".into(), Value::Bool(entry.hidden));
            if let Some(alias) = &entry.alias {
                object.insert("alias".into(), Value::String(alias.clone()));
            }
            if let Some(sort_order) = entry.sort_order {
                object.insert("sortOrder".into(), Value::from(sort_order));
            }
            if let Some(config) = &entry.launch_config {
                object.insert("launchConfig".into(), config.clone());
            }
            Value::Object(object)
        })
        .collect();
    json_ok(json!({ "projects": projects_payload }))
}

pub async fn projects_delete(
    State(state): State<SharedState>,
    request: axum::extract::Request,
) -> Response {
    let body = match body_json(request, 1024 * 1024).await {
        Ok(body) => body,
        Err(response) => return response,
    };
    let cwd = body
        .get("cwd")
        .and_then(Value::as_str)
        .unwrap_or("")
        .trim()
        .to_string();
    if cwd.is_empty() {
        return coded_error(StatusCode::BAD_REQUEST, "Path is required", "path_required");
    }
    let project = session_reader::resolve_project(&cwd);
    let mut registry = projects::load_registry(&state.cfg);
    projects::hide(&mut registry, Path::new(&project.project_root));
    if let Err(error) = projects::save_registry(&state.cfg, &registry) {
        return crate::util::api_error(error, StatusCode::INTERNAL_SERVER_ERROR);
    }
    json_ok(json!({ "success": true }))
}

// ----------------------------------------------------------------------------
// Clone streaming
// ----------------------------------------------------------------------------

struct CloneState {
    cancel: std::sync::Arc<std::sync::atomic::AtomicBool>,
    pid: std::sync::Arc<std::sync::atomic::AtomicI32>,
}

static CLONES: LazyLock<Mutex<HashMap<String, CloneState>>> =
    LazyLock::new(|| Mutex::new(HashMap::new()));

fn clone_directory_name(url: &str) -> Option<String> {
    let trimmed = url.trim();
    if trimmed.is_empty()
        || trimmed.contains('\\')
        || trimmed.chars().any(|c| c.is_whitespace())
        || trimmed.starts_with('-')
    {
        return None;
    }
    let supported = trimmed.starts_with("https://") || trimmed.starts_with("ssh://") || {
        // scp-like `host:path` (no `::` and no `//` right after the colon).
        if let Some((host, path)) = trimmed.split_once(':') {
            !host.is_empty()
                && host.len() >= 2
                && !path.starts_with("//")
                && !path.starts_with(':')
                && host
                    .bytes()
                    .all(|b| b.is_ascii_alphanumeric() || b".-_@".contains(&b))
        } else {
            false
        }
    };
    if !supported {
        return None;
    }
    let path = trimmed
        .split(['?', '#'])
        .next()
        .unwrap_or("")
        .trim_end_matches('/');
    let name = path
        .rsplit(['/', ':'])
        .next()
        .unwrap_or("")
        .trim_end_matches(".git");
    if name.is_empty()
        || name == "."
        || name == ".."
        || !name
            .bytes()
            .all(|b| b.is_ascii_alphanumeric() || b == b'_' || b == b'-' || b == b'.')
    {
        return None;
    }
    Some(name.to_string())
}

pub async fn projects_clone_post(
    State(state): State<SharedState>,
    request: axum::extract::Request,
) -> Response {
    let body = match body_json(request, 1024 * 1024).await {
        Ok(body) => body,
        Err(_) => {
            return coded_error(
                StatusCode::BAD_REQUEST,
                "Invalid request",
                "invalid_request",
            )
        }
    };
    let id = body
        .get("id")
        .and_then(Value::as_str)
        .filter(|id| {
            !id.is_empty()
                && id.len() <= 64
                && id.bytes().all(|b| b.is_ascii_alphanumeric() || b == b'-')
        })
        .map(|id| id.to_string());
    let url = body
        .get("url")
        .and_then(Value::as_str)
        .unwrap_or("")
        .trim()
        .to_string();
    let Some(id) = id else {
        return coded_error(
            StatusCode::BAD_REQUEST,
            "Invalid request",
            "invalid_request",
        );
    };
    if CLONES
        .lock()
        .map(|clones| clones.contains_key(&id))
        .unwrap_or(false)
    {
        return coded_error(
            StatusCode::BAD_REQUEST,
            "Invalid request",
            "invalid_request",
        );
    }
    let Some(name) = clone_directory_name(&url) else {
        return coded_error(
            StatusCode::BAD_REQUEST,
            "Enter an https:// or ssh Git URL",
            "invalid_git_url",
        );
    };
    let parent = match projects::validate_project_path(
        &state.cfg,
        body.get("parent").and_then(Value::as_str).unwrap_or(""),
    ) {
        Ok(path) => path,
        Err((code, message)) => return project_error(code, message),
    };
    let target = parent.join(&name);
    if let Err(error) = std::fs::create_dir(&target) {
        if error.kind() == std::io::ErrorKind::AlreadyExists {
            return coded_error(
                StatusCode::CONFLICT,
                &format!("Already exists: {}", target.to_string_lossy()),
                "clone_target_exists",
            );
        }
        return crate::util::api_error(error, StatusCode::INTERNAL_SERVER_ERROR);
    }
    let cancel = std::sync::Arc::new(std::sync::atomic::AtomicBool::new(false));
    let pid = std::sync::Arc::new(std::sync::atomic::AtomicI32::new(0));
    if let Ok(mut clones) = CLONES.lock() {
        clones.insert(
            id.clone(),
            CloneState {
                cancel: cancel.clone(),
                pid: pid.clone(),
            },
        );
    }

    let (tx, rx) = tokio::sync::mpsc::channel::<Result<bytes::Bytes, std::io::Error>>(64);
    let target_for_task = target.clone();
    let clones_id = id.clone();
    let cancel_for_task = cancel.clone();
    let pid_for_task = pid.clone();
    tokio::task::spawn_blocking(move || {
        use std::io::{BufRead, BufReader};
        use std::os::unix::process::CommandExt;
        let mut command = Command::new("git");
        command
            .args(["clone", "--progress", "--", &url])
            .arg(target_for_task.as_os_str())
            .stdin(Stdio::null())
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .env("GIT_TERMINAL_PROMPT", "0")
            .env("GIT_ASKPASS", "")
            .env("SSH_ASKPASS", "")
            .env("GIT_ALLOW_PROTOCOL", "https:ssh")
            .process_group(0);
        let send = |value: Value| -> bool {
            tx.blocking_send(Ok(bytes::Bytes::from(format!("{}\n", value))))
                .is_ok()
        };
        let mut child = match command.spawn() {
            Ok(child) => child,
            Err(_) => {
                let removed = std::fs::remove_dir_all(&target_for_task).is_ok();
                if !removed {
                    send(
                        json!({ "type": "error", "error": format!("Could not remove {}", target_for_task.to_string_lossy()), "code": "clone_cleanup_failed" }),
                    );
                } else {
                    send(
                        json!({ "type": "error", "error": "Could not run git — is it installed?", "code": "git_not_found" }),
                    );
                }
                if let Ok(mut clones) = CLONES.lock() {
                    clones.remove(&clones_id);
                }
                return;
            }
        };
        pid_for_task.store(child.id() as i32, std::sync::atomic::Ordering::SeqCst);
        let stdout = child.stdout.take();
        let stderr = child.stderr.take();
        fn spawn_reader<R: std::io::Read + Send + 'static>(
            stream: R,
            tx: tokio::sync::mpsc::Sender<Result<bytes::Bytes, std::io::Error>>,
        ) -> std::thread::JoinHandle<()> {
            std::thread::spawn(move || {
                let reader = BufReader::new(stream);
                for line in reader.lines().map_while(Result::ok) {
                    let frame = json!({ "type": "output", "text": format!("{}\n", line) });
                    if tx
                        .blocking_send(Ok(bytes::Bytes::from(format!("{}\n", frame))))
                        .is_err()
                    {
                        break;
                    }
                }
            })
        }
        let mut readers = Vec::new();
        if let Some(stdout) = stdout {
            readers.push(spawn_reader(stdout, tx.clone()));
        }
        if let Some(stderr) = stderr {
            readers.push(spawn_reader(stderr, tx.clone()));
        }
        let status = child.wait();
        for reader in readers {
            let _ = reader.join();
        }
        if let Ok(mut clones) = CLONES.lock() {
            clones.remove(&clones_id);
        }
        let code = status.ok().and_then(|status| status.code());
        let aborted = cancel_for_task.load(std::sync::atomic::Ordering::SeqCst);
        if code == Some(0) && !aborted {
            send(json!({ "type": "done", "path": target_for_task.to_string_lossy() }));
        } else {
            let removed = std::fs::remove_dir_all(&target_for_task).is_ok();
            if !removed {
                send(
                    json!({ "type": "error", "error": format!("Could not remove {}", target_for_task.to_string_lossy()), "code": "clone_cleanup_failed" }),
                );
            } else if aborted {
                send(json!({ "type": "cancelled", "path": target_for_task.to_string_lossy() }));
            } else if code.is_none() {
                send(
                    json!({ "type": "error", "error": "Could not run git — is it installed?", "code": "git_not_found" }),
                );
            } else {
                send(
                    json!({ "type": "error", "error": format!("git clone exited with code {}", code.unwrap_or(-1)), "code": "clone_failed" }),
                );
            }
        }
    });

    let response = Response::builder()
        .header("Content-Type", "application/x-ndjson; charset=utf-8")
        .header("Cache-Control", "no-store")
        .body(Body::from_stream(
            tokio_stream::wrappers::ReceiverStream::new(rx),
        ))
        .unwrap_or_else(|_| StatusCode::INTERNAL_SERVER_ERROR.into_response());
    state.allow_root(&target);
    response
}

pub async fn projects_clone_delete(request: axum::extract::Request) -> Response {
    let body = body_json(request, 64 * 1024).await.unwrap_or(Value::Null);
    let Some(id) = body.get("id").and_then(Value::as_str) else {
        return coded_error(
            StatusCode::NOT_FOUND,
            "No clone in progress",
            "clone_not_found",
        );
    };
    let found = CLONES.lock().ok().and_then(|clones| {
        clones.get(id).map(|clone| {
            clone
                .cancel
                .store(true, std::sync::atomic::Ordering::SeqCst);
            clone.pid.load(std::sync::atomic::Ordering::SeqCst)
        })
    });
    match found {
        Some(pid) => {
            if pid > 0 {
                unsafe {
                    libc::kill(-pid, libc::SIGTERM);
                }
            }
            json_ok(json!({ "ok": true }))
        }
        None => coded_error(
            StatusCode::NOT_FOUND,
            "No clone in progress",
            "clone_not_found",
        ),
    }
}

// ============================================================================
// GitHub repo + git status/diff
// ============================================================================

fn parse_github_remote_url(url: &str) -> Option<String> {
    let trimmed = url.trim();
    let lower = trimmed.to_ascii_lowercase();
    let index = lower.find("github.com")?;
    let rest = &trimmed[index + "github.com".len()..];
    let rest = rest.strip_prefix(':').or_else(|| rest.strip_prefix('/'))?;
    let rest = rest.trim_end_matches('/');
    let rest = rest.strip_suffix(".git").unwrap_or(rest);
    let (owner, repo) = rest.split_once('/')?;
    let owner_valid = !owner.is_empty()
        && owner.as_bytes()[0].is_ascii_alphanumeric()
        && owner
            .bytes()
            .all(|b| b.is_ascii_alphanumeric() || b == b'-');
    let repo_valid = !repo.is_empty()
        && repo
            .bytes()
            .all(|b| b.is_ascii_alphanumeric() || b == b'.' || b == b'_' || b == b'-');
    if owner_valid && repo_valid {
        Some(format!("{}/{}", owner, repo))
    } else {
        None
    }
}

fn pick_github_repo(git_config: &str) -> Option<String> {
    let mut urls: Vec<(String, String)> = Vec::new();
    let mut rewrites: Vec<(String, String)> = Vec::new();
    let mut resolved: Option<(String, String)> = None;
    for line in git_config.lines() {
        let line = line.trim();
        let lower = line.to_ascii_lowercase();
        if lower.starts_with("url.") {
            if let Some((prefix, base)) = lower
                .strip_prefix("url.")
                .and_then(|rest| rest.split_once(".insteadof "))
                .map(|(base, prefix)| (prefix.to_string(), base.to_string()))
            {
                // Keep the original casing of the value.
                let original_value = line
                    .rsplit_once(' ')
                    .map(|(_, value)| value.to_string())
                    .unwrap_or(prefix);
                rewrites.push((original_value, base));
                continue;
            }
        }
        if !lower.starts_with("remote.") {
            continue;
        }
        let rest = &line["remote.".len()..];
        let Some((name, tail)) = rest.split_once('.') else {
            continue;
        };
        let Some((key, value)) = tail.split_once(' ') else {
            continue;
        };
        match key {
            "url" => {
                if !urls.iter().any(|(existing, _)| existing == name) {
                    urls.push((name.to_string(), value.to_string()));
                }
            }
            "gh-resolved" => {
                if resolved.is_none() {
                    resolved = Some((name.to_string(), value.to_string()));
                }
            }
            _ => {}
        }
    }
    let repo_of = |name: &str| -> Option<String> {
        let url = urls
            .iter()
            .find(|(existing, _)| existing == name)?
            .1
            .clone();
        let mut rule: Option<&(String, String)> = None;
        for candidate in &rewrites {
            if url.starts_with(&candidate.0)
                && rule
                    .map(|existing| candidate.0.len() > existing.0.len())
                    .unwrap_or(true)
            {
                rule = Some(candidate);
            }
        }
        let expanded = match rule {
            Some((prefix, base)) => format!("{}{}", base, &url[prefix.len()..]),
            None => url,
        };
        parse_github_remote_url(&expanded)
    };
    if let Some((name, value)) = &resolved {
        if let Some(repo) = repo_of(name) {
            if value.split_once('/').is_some() {
                return Some(value.clone());
            }
            return Some(repo);
        }
    }
    let priority = |name: &str| -> usize {
        match name {
            "upstream" => 0,
            "github" => 1,
            "origin" => 2,
            _ => 3,
        }
    };
    let mut names: Vec<String> = urls.iter().map(|(name, _)| name.clone()).collect();
    names.sort_by_key(|name| priority(name));
    for name in names {
        if let Some(repo) = repo_of(&name) {
            return Some(repo);
        }
    }
    None
}

pub async fn github_repo(State(state): State<SharedState>, uri: Uri) -> Response {
    let query = query(&uri);
    let cwd = query.get("cwd").unwrap_or("").trim();
    let path = match require_cwd(&state, cwd) {
        Ok(path) => path,
        Err(response) => return response,
    };
    let output = Command::new("git")
        .arg("-C")
        .arg(&path)
        .args([
            "config",
            "--get-regexp",
            "^(remote\\..*\\.(url|gh-resolved)|url\\..*\\.insteadof)$",
        ])
        .env("LC_ALL", "C")
        .output();
    let repo = match output {
        Ok(output) if output.status.success() => {
            pick_github_repo(&String::from_utf8_lossy(&output.stdout))
        }
        _ => None,
    };
    json_ok(json!({ "repo": repo }))
}

struct GitEntry {
    path: String,
    original_path: Option<String>,
    index_status: String,
    worktree_status: String,
}

fn git_stdout(cwd: &Path, args: &[&str], input: Option<&[u8]>) -> Option<Vec<u8>> {
    let mut command = Command::new("git");
    command.arg("-C").arg(cwd).args(args).env("LC_ALL", "C");
    if input.is_some() {
        command.stdin(Stdio::piped());
    }
    command.stdout(Stdio::piped()).stderr(Stdio::piped());
    let mut child = command.spawn().ok()?;
    if let Some(input) = input {
        use std::io::Write;
        if let Some(mut stdin) = child.stdin.take() {
            let _ = stdin.write_all(input);
        }
    }
    let output = child.wait_with_output().ok()?;
    if !output.status.success() {
        return None;
    }
    Some(output.stdout)
}

fn find_git_root(cwd: &Path) -> Option<PathBuf> {
    let output = git_stdout(cwd, &["rev-parse", "--show-toplevel"], None)?;
    let text = String::from_utf8_lossy(&output).trim().to_string();
    if text.is_empty() {
        None
    } else {
        Some(PathBuf::from(text))
    }
}

fn parse_porcelain(output: &[u8]) -> Vec<GitEntry> {
    let records: Vec<String> = output
        .split(|byte| *byte == 0)
        .map(|record| String::from_utf8_lossy(record).into_owned())
        .collect();
    let mut entries = Vec::new();
    let mut index = 0usize;
    while index < records.len() {
        let record = &records[index];
        if record.len() < 4 || record.as_bytes().get(2) != Some(&b' ') {
            index += 1;
            continue;
        }
        let index_status = record[..1].to_string();
        let worktree_status = record[1..2].to_string();
        let mut entry = GitEntry {
            path: record[3..].to_string(),
            original_path: None,
            index_status: index_status.clone(),
            worktree_status: worktree_status.clone(),
        };
        if ["R", "C"].contains(&index_status.as_str())
            || ["R", "C"].contains(&worktree_status.as_str())
        {
            index += 1;
            entry.original_path = records
                .get(index)
                .filter(|value| !value.is_empty())
                .cloned();
        }
        entries.push(entry);
        index += 1;
    }
    entries
}

fn classify_status(entry: &GitEntry) -> (&'static str, &'static str) {
    let pair = format!("{}{}", entry.index_status, entry.worktree_status);
    const CONFLICTS: &[&str] = &["DD", "AU", "UD", "UA", "DU", "AA", "UU"];
    if pair == "??" {
        ("untracked", "U")
    } else if CONFLICTS.contains(&pair.as_str()) || pair.contains('U') {
        ("conflict", "C")
    } else if pair.contains('D') {
        ("deleted", "D")
    } else if pair.contains('R') || pair.contains('C') {
        ("renamed", "R")
    } else if pair.contains('A') {
        ("added", "A")
    } else {
        ("modified", "M")
    }
}

fn collapse_reasons(root: &Path, paths: &[String]) -> HashMap<String, String> {
    if paths.is_empty() {
        return HashMap::new();
    }
    let mut input = Vec::new();
    for path in paths {
        input.extend_from_slice(path.as_bytes());
        input.push(0);
    }
    let mut args = vec!["check-attr", "-z", "--stdin"];
    args.extend_from_slice(&[
        "linguist-generated",
        "linguist-vendored",
        "linguist-documentation",
        "diff",
        "binary",
    ]);
    let Some(output) = git_stdout(root, &args, Some(&input)) else {
        return HashMap::new();
    };
    let records: Vec<String> = output
        .split(|byte| *byte == 0)
        .map(|record| String::from_utf8_lossy(record).into_owned())
        .collect();
    let mut by_path: HashMap<String, HashMap<String, String>> = HashMap::new();
    let mut index = 0usize;
    while index + 2 < records.len() {
        let file = records[index].clone();
        let attr = records[index + 1].clone();
        let value = records[index + 2].clone();
        by_path.entry(file).or_default().insert(attr, value);
        index += 3;
    }
    let is_true =
        |value: Option<&String>| matches!(value.map(|v| v.as_str()), Some("set") | Some("true"));
    let mut reasons = HashMap::new();
    for (path, attrs) in by_path {
        if attrs.get("diff").map(|v| v.as_str()) == Some("unset")
            && attrs.get("binary").map(|v| v.as_str()) != Some("set")
        {
            reasons.insert(path, "no-diff".to_string());
        } else if is_true(attrs.get("linguist-generated")) {
            reasons.insert(path, "generated".to_string());
        } else if is_true(attrs.get("linguist-vendored")) {
            reasons.insert(path, "vendored".to_string());
        } else if is_true(attrs.get("linguist-documentation")) {
            reasons.insert(path, "documentation".to_string());
        }
    }
    reasons
}

pub async fn git_status_route(State(state): State<SharedState>, uri: Uri) -> Response {
    let query = query(&uri);
    let cwd = query.get("cwd").unwrap_or("").trim();
    let path = match require_cwd(&state, cwd) {
        Ok(path) => path,
        Err(response) => return response,
    };
    let Some(root) = find_git_root(&path) else {
        return json_ok(json!({
            "isGitRepository": false,
            "repositoryRoot": Value::Null,
            "files": [],
        }));
    };
    let Some(output) = git_stdout(
        &root,
        &["status", "--porcelain=v1", "-z", "--untracked-files=all"],
        None,
    ) else {
        return json_ok(json!({
            "isGitRepository": true,
            "repositoryRoot": root.to_string_lossy(),
            "files": [],
        }));
    };
    let entries: Vec<GitEntry> = parse_porcelain(&output)
        .into_iter()
        .filter(|entry| crate::util::is_within(&path, &root.join(&entry.path)))
        .collect();
    let paths: Vec<String> = entries.iter().map(|entry| entry.path.clone()).collect();
    let reasons = collapse_reasons(&root, &paths);
    let files: Vec<Value> = entries
        .iter()
        .map(|entry| {
            let (status, code) = classify_status(entry);
            let mut object = Map::new();
            object.insert(
                "filePath".into(),
                Value::String(root.join(&entry.path).to_string_lossy().into_owned()),
            );
            object.insert("status".into(), Value::String(status.into()));
            object.insert("code".into(), Value::String(code.into()));
            object.insert(
                "indexStatus".into(),
                Value::String(entry.index_status.clone()),
            );
            object.insert(
                "worktreeStatus".into(),
                Value::String(entry.worktree_status.clone()),
            );
            if let Some(reason) = reasons.get(&entry.path) {
                object.insert("collapseReason".into(), Value::String(reason.clone()));
            }
            Value::Object(object)
        })
        .collect();
    json_ok(json!({
        "isGitRepository": true,
        "repositoryRoot": root.to_string_lossy(),
        "files": files,
    }))
}

const TEXT_PREVIEW_MAX_BYTES: u64 = 256 * 1024;
const MAX_STATUS_BUFFER: usize = 8 * 1024 * 1024;

fn create_added_patch(git_path: &str, content: &str) -> String {
    let has_trailing_newline = content.ends_with('\n');
    let mut lines: Vec<&str> = content.split('\n').collect();
    if has_trailing_newline {
        lines.pop();
    }
    let body = lines
        .iter()
        .map(|line| format!("+{}", line))
        .collect::<Vec<_>>()
        .join("\n");
    let no_newline_marker = if !has_trailing_newline && !lines.is_empty() {
        "\n\\ No newline at end of file"
    } else {
        ""
    };
    format!(
        "diff --git a/{path} b/{path}\nnew file mode 100644\n--- /dev/null\n+++ b/{path}\n@@ -0,0 +1,{count} @@\n{body}{marker}",
        path = git_path,
        count = lines.len(),
        body = body,
        marker = no_newline_marker
    )
}

pub async fn git_diff_route(State(state): State<SharedState>, uri: Uri) -> Response {
    let query = query(&uri);
    let cwd = query.get("cwd").unwrap_or("").trim();
    let file_path = query.get("path").unwrap_or("").trim();
    if cwd.is_empty() || !cwd.starts_with('/') {
        return coded_error(
            StatusCode::BAD_REQUEST,
            "cwd must be an absolute path",
            "cwd_must_be_absolute",
        );
    }
    if file_path.is_empty() || !file_path.starts_with('/') {
        return coded_error(
            StatusCode::BAD_REQUEST,
            "path must be an absolute path",
            "path_must_be_absolute",
        );
    }
    if !state.is_path_allowed(Path::new(cwd)) || !state.is_path_allowed(Path::new(file_path)) {
        return crate::util::access_denied();
    }
    if !state.is_existing_path_allowed(Path::new(cwd))
        || !state.is_existing_path_allowed(Path::new(file_path))
    {
        return crate::util::access_denied();
    }
    let cwd_path = PathBuf::from(cwd);
    let resolved_file = PathBuf::from(file_path);
    let Some(root) = find_git_root(&cwd_path) else {
        return json_ok(json!({ "supported": false }));
    };
    if !crate::util::is_within(&root, &resolved_file) {
        return json_ok(json!({ "supported": false }));
    }
    let Ok(meta) = std::fs::symlink_metadata(&resolved_file) else {
        return json_ok(json!({ "supported": false }));
    };
    if !meta.is_file() || meta.len() > TEXT_PREVIEW_MAX_BYTES {
        return json_ok(json!({ "supported": false }));
    }
    let relative = resolved_file
        .strip_prefix(&root)
        .map(|path| path.to_string_lossy().replace('\\', "/"))
        .unwrap_or_default();
    let Some(status_output) = git_stdout(
        &root,
        &["status", "--porcelain=v1", "-z", "--untracked-files=all"],
        None,
    ) else {
        return json_ok(json!({ "supported": false }));
    };
    let entries = parse_porcelain(&status_output);
    let Some(entry) = entries.iter().find(|entry| entry.path == relative) else {
        return json_ok(json!({ "supported": false }));
    };
    let (status, _) = classify_status(entry);
    if status == "deleted" {
        return json_ok(json!({ "supported": false }));
    }
    let Ok(content_bytes) = std::fs::read(&resolved_file) else {
        return json_ok(json!({ "supported": false }));
    };
    if content_bytes.contains(&0) {
        return json_ok(json!({ "supported": false }));
    }
    if collapse_reasons(&root, &[relative.clone()])
        .get(&relative)
        .map(|reason| reason.as_str())
        == Some("no-diff")
    {
        return json_ok(json!({ "supported": false }));
    }
    let content = String::from_utf8_lossy(&content_bytes);
    let patch = if status == "untracked" {
        create_added_patch(&relative, &content)
    } else {
        let mut paths: Vec<String> = Vec::new();
        if let Some(original) = &entry.original_path {
            if original != &relative {
                paths.push(original.clone());
            }
        }
        paths.push(relative.clone());
        let mut args = vec![
            "diff",
            "--no-color",
            "--no-ext-diff",
            "--unified=3",
            "HEAD",
            "--",
        ];
        args.extend(paths.iter().map(|path| path.as_str()));
        match git_stdout(&root, &args, None) {
            Some(output) => String::from_utf8_lossy(&output).into_owned(),
            None => {
                if status != "added" {
                    return json_ok(json!({ "supported": false }));
                }
                create_added_patch(&relative, &content)
            }
        }
    };
    if !patch.contains("\n@@ ") {
        return json_ok(json!({ "supported": false }));
    }
    let _ = MAX_STATUS_BUFFER;
    json_ok(json!({ "supported": true, "status": status, "patch": patch }))
}

// ============================================================================
// File index
// ============================================================================

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
const MAX_FILES: usize = 5000;
const GIT_HARD_CAP: usize = 200_000;
const WALK_HARD_CAP: usize = 50_000;
const MAX_WALK_DEPTH: usize = 8;
const MAX_QUERY_LENGTH: usize = 500;
const AT_RESULT_LIMIT: usize = 20;
const MAX_RESULT_LIMIT: usize = 200;

struct CacheEntry {
    files: Vec<String>,
    hard_truncated: bool,
    expires_at: Instant,
}

static FILE_INDEX_CACHE: LazyLock<Mutex<HashMap<String, CacheEntry>>> =
    LazyLock::new(|| Mutex::new(HashMap::new()));

fn list_with_git(cwd: &Path) -> Option<(Vec<String>, bool)> {
    let listed = git_stdout(
        cwd,
        &[
            "ls-files",
            "--cached",
            "--others",
            "--exclude-standard",
            "-z",
        ],
        None,
    )?;
    let deleted = git_stdout(cwd, &["ls-files", "--deleted", "-z"], None);
    let missing: HashSet<String> = deleted
        .map(|output| {
            output
                .split(|byte| *byte == 0)
                .filter(|record| !record.is_empty())
                .map(|record| String::from_utf8_lossy(record).into_owned())
                .collect()
        })
        .unwrap_or_default();
    let mut files: Vec<String> = listed
        .split(|byte| *byte == 0)
        .filter(|record| !record.is_empty())
        .map(|record| String::from_utf8_lossy(record).into_owned())
        .filter(|file| !missing.contains(file))
        .collect();
    let hard_truncated = files.len() > GIT_HARD_CAP;
    files.truncate(GIT_HARD_CAP);
    Some((files, hard_truncated))
}

fn list_with_walk(cwd: &Path) -> (Vec<String>, bool) {
    let mut files = Vec::new();
    let mut queue: std::collections::VecDeque<(PathBuf, String, usize)> =
        std::collections::VecDeque::new();
    queue.push_back((cwd.to_path_buf(), String::new(), 0));
    while let Some((abs, rel, depth)) = queue.pop_front() {
        let Ok(entries) = std::fs::read_dir(&abs) else {
            continue;
        };
        for entry in entries.flatten() {
            let name = entry.file_name().to_string_lossy().into_owned();
            if IGNORED_NAMES.contains(&name.as_str()) || name.ends_with(".pyc") {
                continue;
            }
            let child_rel = if rel.is_empty() {
                name.clone()
            } else {
                format!("{}/{}", rel, name)
            };
            let Ok(file_type) = entry.file_type() else {
                continue;
            };
            if file_type.is_dir() {
                if depth + 1 <= MAX_WALK_DEPTH {
                    queue.push_back((entry.path(), child_rel, depth + 1));
                }
            } else if file_type.is_file() {
                if files.len() >= WALK_HARD_CAP {
                    return (files, true);
                }
                files.push(child_rel);
            }
        }
    }
    (files, false)
}

fn build_entries(files: &[String]) -> Vec<(String, bool)> {
    let mut dirs: HashSet<String> = HashSet::new();
    for file in files {
        let mut search = 0usize;
        while let Some(index) = file[search..].find('/') {
            let absolute = search + index;
            dirs.insert(file[..absolute].to_string());
            search = absolute + 1;
        }
    }
    let mut entries: Vec<(String, bool)> = dirs.into_iter().map(|dir| (dir, true)).collect();
    for file in files {
        if !file.is_empty() {
            entries.push((file.clone(), false));
        }
    }
    let depth = |path: &str| path.bytes().filter(|b| *b == b'/').count();
    entries.sort_by(|a, b| depth(&a.0).cmp(&depth(&b.0)).then_with(|| a.0.cmp(&b.0)));
    entries
}

fn is_subsequence(needle: &str, haystack: &str) -> bool {
    let mut chars = haystack.chars();
    needle
        .chars()
        .all(|target| chars.any(|candidate| candidate == target))
}

fn score_entry(path: &str, is_dir: bool, lower_query: &str) -> i32 {
    let lower_path = path.to_lowercase();
    let mut score = 0;
    if lower_query.contains('/') {
        if lower_path == lower_query {
            score = 100;
        } else if lower_path.starts_with(lower_query) {
            score = 80;
        } else if lower_path.contains(lower_query) {
            score = 50;
        } else if is_subsequence(lower_query, &lower_path) {
            score = 10;
        }
    } else {
        let name = match lower_path.rfind('/') {
            Some(index) => &lower_path[index + 1..],
            None => &lower_path,
        };
        if name == lower_query {
            score = 100;
        } else if name.starts_with(lower_query) {
            score = 80;
        } else if name.contains(lower_query) {
            score = 50;
        } else if lower_path.contains(lower_query) {
            score = 30;
        } else if is_subsequence(lower_query, &lower_path) {
            score = 10;
        }
    }
    if is_dir && score > 0 {
        score += 10;
    }
    score
}

fn parse_limit(raw: Option<&str>) -> usize {
    match raw.and_then(|value| value.parse::<i64>().ok()) {
        Some(value) if value >= 1 => (value as usize).min(MAX_RESULT_LIMIT),
        _ => AT_RESULT_LIMIT,
    }
}

pub async fn file_index(State(state): State<SharedState>, uri: Uri) -> Response {
    let query = query(&uri);
    let cwd = query.get("cwd").unwrap_or("").trim();
    if cwd.is_empty() || !cwd.starts_with('/') {
        return coded_error(
            StatusCode::BAD_REQUEST,
            "cwd must be an absolute path",
            "cwd_must_be_absolute",
        );
    }
    let raw_query = query.get("q").map(|q| q.to_string()).unwrap_or_default();
    let search: String = raw_query.chars().take(MAX_QUERY_LENGTH).collect();
    let path = match require_cwd(&state, cwd) {
        Ok(path) => path,
        Err(response) => return response,
    };
    let key = path_key(&path);
    let refresh = query.get("refresh") == Some("1");
    let cached = {
        let mut cache = match FILE_INDEX_CACHE.lock() {
            Ok(cache) => cache,
            Err(_) => {
                return crate::util::api_error(
                    "file index unavailable",
                    StatusCode::INTERNAL_SERVER_ERROR,
                )
            }
        };
        let expired = cache
            .get(&key)
            .map(|entry| entry.expires_at <= Instant::now())
            .unwrap_or(true);
        if expired || refresh {
            let (files, hard_truncated) = match list_with_git(&path) {
                Some(result) => result,
                None => list_with_walk(&path),
            };
            cache.retain(|_, entry| entry.expires_at > Instant::now());
            if cache.len() >= 20 && !cache.contains_key(&key) {
                cache.clear();
            }
            cache.insert(
                key.clone(),
                CacheEntry {
                    files,
                    hard_truncated,
                    expires_at: Instant::now() + Duration::from_secs(10),
                },
            );
        }
        cache
            .get(&key)
            .map(|entry| (entry.files.clone(), entry.hard_truncated))
            .unwrap_or_default()
    };
    let (files, hard_truncated) = cached;
    if !search.is_empty() {
        let limit = parse_limit(query.get("limit"));
        let entries = build_entries(&files);
        let kind_file = query.get("kind") == Some("file");
        let candidates: Vec<(String, bool)> = if kind_file {
            entries.into_iter().filter(|(_, is_dir)| !is_dir).collect()
        } else {
            entries
        };
        let mut scored: Vec<(i32, usize, String, bool)> = candidates
            .into_iter()
            .enumerate()
            .filter_map(|(index, (path, is_dir))| {
                let score = score_entry(&path, is_dir, &search.to_lowercase());
                (score > 0).then_some((score, index, path, is_dir))
            })
            .collect();
        let depth = |path: &str| path.bytes().filter(|b| *b == b'/').count();
        scored.sort_by(|a, b| {
            b.0.cmp(&a.0)
                .then_with(|| depth(&a.2).cmp(&depth(&b.2)))
                .then_with(|| a.2.cmp(&b.2))
        });
        let want = if kind_file { limit + 1 } else { limit };
        let truncated = scored.len() > limit || (kind_file && hard_truncated);
        let matches: Vec<Value> = scored
            .into_iter()
            .take(want)
            .take(if kind_file { limit } else { limit })
            .map(|(_, _, path, is_dir)| json!({ "path": path, "isDir": is_dir }))
            .collect();
        if kind_file {
            return json_ok(json!({ "matches": matches, "truncated": truncated }));
        }
        return json_ok(json!({ "matches": matches }));
    }
    let truncated = hard_truncated || files.len() > MAX_FILES;
    let mut listed = files;
    listed.truncate(MAX_FILES);
    json_ok(json!({ "files": listed, "truncated": truncated }))
}
