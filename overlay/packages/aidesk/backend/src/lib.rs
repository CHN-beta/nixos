pub mod config;
pub mod omp;
pub mod routes;
pub mod sse;
pub mod state;
pub mod util;

use axum::extract::DefaultBodyLimit;
use axum::routing::{get, post};
use axum::Router;
use config::Config;
use state::AppState;
use std::future::Future;
use std::path::{Path, PathBuf};
use std::sync::Arc;

/// The complete HTTP surface (same paths as the Next.js app, minus removed
/// features).
pub fn build_router(state: Arc<AppState>) -> Router {
    use routes::agent;
    use routes::files;
    use routes::notifications;
    use routes::sessions;
    use routes::settings;
    use routes::stt;
    use routes::terminal;
    use routes::workspace;

    Router::new()
        // Workspace + projects + git + file index
        .route("/api/home", get(workspace::home))
        .route("/api/default-cwd", post(workspace::default_cwd))
        .route("/api/cwd/browse", get(workspace::cwd_browse))
        .route("/api/cwd/validate", post(workspace::cwd_validate))
        .route(
            "/api/projects",
            get(workspace::projects_get)
                .post(workspace::projects_post)
                .patch(workspace::projects_patch)
                .delete(workspace::projects_delete),
        )
        .route(
            "/api/projects/clone",
            post(workspace::projects_clone_post).delete(workspace::projects_clone_delete),
        )
        .route("/api/github-repo", get(workspace::github_repo))
        .route("/api/git/status", get(workspace::git_status_route))
        .route("/api/git/diff", get(workspace::git_diff_route))
        .route("/api/file-index", get(workspace::file_index))
        // Files + media
        .route(
            "/api/files/{*path}",
            get(files::files_get)
                .put(files::files_put)
                .post(files::files_post),
        )
        .route("/api/media/{hash}", get(files::media_get))
        // Terminal
        .route(
            "/api/terminal",
            get(terminal::terminal_list).post(terminal::terminal_create),
        )
        .route(
            "/api/terminal/{id}",
            get(terminal::terminal_get).delete(terminal::terminal_delete),
        )
        .route("/api/terminal/{id}/input", post(terminal::terminal_input))
        .route("/api/terminal/{id}/resize", post(terminal::terminal_resize))
        .route("/api/terminal/{id}/stream", get(terminal::terminal_stream))
        // Sessions
        .route("/api/sessions", get(sessions::sessions_list))
        .route(
            "/api/sessions/archive",
            get(sessions::sessions_archive_list).post(sessions::sessions_archive_restore),
        )
        .route(
            "/api/sessions/{id}",
            get(sessions::session_get)
                .patch(sessions::session_patch)
                .delete(sessions::session_delete),
        )
        .route("/api/sessions/{id}/context", get(sessions::session_context))
        .route("/api/sessions/{id}/state", get(sessions::session_state))
        .route("/api/sessions/{id}/export", get(sessions::session_export))
        .route(
            "/api/sessions/{id}/auto-name",
            post(sessions::session_auto_name),
        )
        .route(
            "/api/sessions/{id}/archive",
            post(sessions::session_archive),
        )
        .route(
            "/api/sessions/{id}/entries/{entryId}/thinking",
            get(sessions::session_thinking),
        )
        .route(
            "/api/sessions/{id}/subagents",
            get(sessions::session_subagents),
        )
        .route(
            "/api/sessions/{id}/subagents/{subagentId}",
            get(sessions::session_subagent),
        )
        // Agent RPC
        .route("/api/agent/new", post(agent::agent_new))
        .route(
            "/api/agent/running/events",
            get(agent::agent_running_events),
        )
        .route(
            "/api/agent/host-tools/events",
            get(agent::agent_host_tools_events),
        )
        .route(
            "/api/agent/{id}",
            get(agent::agent_get).post(agent::agent_post),
        )
        .route("/api/agent/{id}/events", get(agent::agent_events))
        .route("/api/agent/{id}/bash-output", get(agent::agent_bash_output))
        // Models / skills / settings
        .route("/api/models", get(settings::models_get))
        .route(
            "/api/models-config",
            get(settings::models_config_get).put(settings::models_config_put),
        )
        .route(
            "/api/model-roles",
            get(settings::model_roles_get).put(settings::model_roles_put),
        )
        .route(
            "/api/skills",
            get(settings::skills_get).patch(settings::skills_patch),
        )
        .route("/api/skills/check", post(settings::skills_check))
        .route(
            "/api/omp-settings",
            get(settings::omp_settings_get).put(settings::omp_settings_put),
        )
        .route(
            "/api/web-settings",
            get(settings::web_settings_get).put(settings::web_settings_put),
        )
        .route("/api/omp-version", get(settings::omp_version))
        .route("/api/provider-usage", get(settings::provider_usage))
        // Notifications
        .route(
            "/api/notifications/devices",
            get(notifications::devices_get).put(notifications::devices_put),
        )
        .route(
            "/api/notifications/history",
            get(notifications::history_get)
                .patch(notifications::history_patch)
                .delete(notifications::history_delete),
        )
        .route("/api/notifications/presence", post(notifications::presence))
        .route("/api/notifications/test", post(notifications::notify_test))
        // STT
        .route("/api/stt", get(stt::stt_list).post(stt::stt_create))
        .route(
            "/api/stt/{jobId}",
            get(stt::stt_get)
                .post(stt::stt_retry)
                .delete(stt::stt_close),
        )
        .route("/api/stt/{jobId}/audio", get(stt::stt_audio))
        // PWA manifest
        .route("/api/manifest", get(settings::manifest))
        .fallback(not_found)
        .layer(DefaultBodyLimit::max(105 * 1024 * 1024))
        .with_state(state)
}

async fn not_found() -> axum::response::Response {
    (
        axum::http::StatusCode::NOT_FOUND,
        axum::Json(serde_json::json!({ "error": "Not found", "code": "not_found" })),
    )
        .into_response()
}

use axum::response::IntoResponse;

/// Bind the Unix socket, removing a stale socket file and creating/authorizing
/// the parent directory first.
pub fn bind_unix_socket(path: &Path) -> std::io::Result<tokio::net::UnixListener> {
    if let Some(parent) = path.parent() {
        if !parent.as_os_str().is_empty() {
            let created = !parent.exists();
            std::fs::create_dir_all(parent)?;
            // Only tighten a directory this process created: /tmp and /run are
            // owned/shared and must keep their system permissions.
            if created {
                #[cfg(unix)]
                {
                    use std::os::unix::fs::PermissionsExt;
                    let _ =
                        std::fs::set_permissions(parent, std::fs::Permissions::from_mode(0o770));
                }
            }
        }
    }
    // symlink_metadata: never follow a link planted at the socket path.
    #[cfg(unix)]
    use std::os::unix::fs::FileTypeExt;
    match std::fs::symlink_metadata(path) {
        Ok(meta) if meta.file_type().is_socket() => {
            std::fs::remove_file(path)?;
        }
        Ok(_) => {
            return Err(std::io::Error::new(
                std::io::ErrorKind::AlreadyExists,
                format!("{} exists and is not a socket", path.display()),
            ))
        }
        Err(_) => {}
    }
    let listener = tokio::net::UnixListener::bind(path)?;
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        std::fs::set_permissions(path, std::fs::Permissions::from_mode(0o660))?;
    }
    Ok(listener)
}

/// Serve the router on a Unix domain socket (one task per connection) until
/// `shutdown` resolves; in-flight connections get a short drain window.
pub async fn serve_unix_until(
    listener: tokio::net::UnixListener,
    router: Router,
    shutdown: impl Future<Output = ()>,
) -> std::io::Result<()> {
    let mut connections = tokio::task::JoinSet::new();
    tokio::pin!(shutdown);
    loop {
        tokio::select! {
            _ = &mut shutdown => break,
            accepted = listener.accept() => {
                let (stream, _) = match accepted {
                    Ok(accepted) => accepted,
                    Err(error) => return Err(error),
                };
                let router = router.clone();
                connections.spawn(async move {
                    let io = hyper_util::rt::TokioIo::new(stream);
                    let service = hyper_util::service::TowerToHyperService::new(router);
                    let _ = hyper_util::server::conn::auto::Builder::new(
                        hyper_util::rt::TokioExecutor::new(),
                    )
                    .serve_connection_with_upgrades(io, service)
                    .await;
                });
            }
            Some(_) = connections.join_next(), if !connections.is_empty() => {}
        }
    }
    // Drain: give open connections a moment to finish, then abandon them.
    let _ = tokio::time::timeout(std::time::Duration::from_secs(5), async {
        while connections.join_next().await.is_some() {}
    })
    .await;
    connections.shutdown().await;
    Ok(())
}

/// Serve the router on a Unix domain socket (one task per connection).
pub async fn serve_unix(listener: tokio::net::UnixListener, router: Router) -> std::io::Result<()> {
    serve_unix_until(listener, router, std::future::pending::<()>()).await
}

/// Prepare the socket path and start serving it in the background.
pub fn spawn_unix_server(
    path: PathBuf,
    router: Router,
) -> std::io::Result<tokio::task::JoinHandle<()>> {
    let listener = bind_unix_socket(&path)?;
    Ok(tokio::spawn(async move {
        if let Err(error) = serve_unix(listener, router).await {
            eprintln!("[aidesk] unix listener error: {}", error);
        }
    }))
}

/// Initialize process state from the environment and serve the configured
/// listeners. Both may be active at once when `--socket` and `--port` are set.
pub async fn run(cfg: Config) -> std::io::Result<()> {
    #[cfg(unix)]
    unsafe {
        libc::umask(0o007);
    }
    let socket = cfg.socket.clone();
    let port = cfg.port;
    let host = cfg.host.clone();
    let state = AppState::new(cfg);
    let router = build_router(state.clone());

    let (shutdown_tx, shutdown_rx) = tokio::sync::watch::channel(false);
    let mut unix_task: Option<tokio::task::JoinHandle<()>> = None;
    if let Some(path) = &socket {
        let listener = bind_unix_socket(path)?;
        eprintln!("[aidesk] listening on unix:{}", path.display());
        let socket_path = path.clone();
        let unix_router = router.clone();
        let mut unix_shutdown = shutdown_rx.clone();
        unix_task = Some(tokio::spawn(async move {
            let stop = async move {
                while !*unix_shutdown.borrow() {
                    if unix_shutdown.changed().await.is_err() {
                        break;
                    }
                }
            };
            if let Err(error) = serve_unix_until(listener, unix_router, stop).await {
                eprintln!("[aidesk] unix listener error: {}", error);
            }
            // Never leave a dead socket behind for the next start (and for
            // systemd's Restart=on-failure path).
            let _ = std::fs::remove_file(&socket_path);
        }));
    }

    if let Some(port) = port {
        let address = format!("{}:{}", host, port);
        let listener = tokio::net::TcpListener::bind(&address).await?;
        eprintln!("[aidesk] listening on http://{}", address);
        let mut tcp_shutdown = shutdown_rx.clone();
        let shutdown_signal = async move {
            wait_for_shutdown_signal().await;
            let _ = shutdown_tx.send(true);
        };
        axum::serve(listener, router)
            .with_graceful_shutdown(shutdown_signal)
            .await?;
        let _ = tcp_shutdown.changed().await;
    } else {
        wait_for_shutdown_signal().await;
        let _ = shutdown_tx.send(true);
    }
    if let Some(task) = unix_task {
        let _ = tokio::time::timeout(std::time::Duration::from_secs(10), task).await;
    }
    shutdown_children().await;
    Ok(())
}

/// SIGINT or SIGTERM: systemd/docker stop with SIGTERM, so both must drain.
async fn wait_for_shutdown_signal() {
    #[cfg(unix)]
    {
        let mut terminate =
            match tokio::signal::unix::signal(tokio::signal::unix::SignalKind::terminate()) {
                Ok(signal) => signal,
                Err(_) => {
                    let _ = tokio::signal::ctrl_c().await;
                    return;
                }
            };
        tokio::select! {
            _ = tokio::signal::ctrl_c() => {}
            _ = terminate.recv() => {}
        }
    }
    #[cfg(not(unix))]
    {
        let _ = tokio::signal::ctrl_c().await;
    }
}

async fn shutdown_children() {
    crate::omp::rpc::shutdown_all().await;
    if let Some(state) = AppState::global() {
        state.terminals.kill_all();
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn router_constructs() {
        let dir = std::env::temp_dir().join(format!("aidesk-router-{}", uuid::Uuid::new_v4()));
        std::fs::create_dir_all(&dir).unwrap();
        let cfg = Config {
            home: dir.clone(),
            config_root: dir.clone(),
            agent_dir: dir.clone(),
            sessions_dir: dir.join("sessions"),
            blobs_dir: dir.join("blobs"),
            archive_dir: dir.join("archive/sessions"),
            diagnostics_dir: dir.join("omp-web"),
            omp_bin: None,
            socket: None,
            port: None,
            host: "127.0.0.1".into(),
            stt: None,
        };
        let state = AppState::new(cfg);
        let _router = build_router(state);
        let _ = std::fs::remove_dir_all(dir);
    }
}
