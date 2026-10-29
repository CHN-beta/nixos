//! Integration tests for socket binding, session parsing, file writes,
//! terminal lifecycle and the settings endpoints.

use aidesk_backend::config::Config;
use aidesk_backend::omp::session_files;
use aidesk_backend::omp::session_reader;
use aidesk_backend::state::AppState;
use aidesk_backend::{bind_unix_socket, build_router, serve_unix};
use axum::body::Body;
use axum::http::{Request, StatusCode};
use http_body_util::BodyExt;
use serde_json::{json, Value};
use std::path::{Path, PathBuf};
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tower::ServiceExt;

fn test_root(name: &str) -> PathBuf {
    let root = std::env::temp_dir().join(format!("aidesk-test-{}-{}", name, uuid::Uuid::new_v4()));
    std::fs::create_dir_all(&root).unwrap();
    root
}

fn test_config(root: &Path) -> Config {
    let home = root.join("home");
    let config_root = home.join(".omp");
    let agent_dir = config_root.join("agent");
    for dir in [
        home.clone(),
        agent_dir.join("sessions"),
        agent_dir.join("blobs"),
        agent_dir.join("archive/sessions"),
        agent_dir.join("omp-web"),
    ] {
        std::fs::create_dir_all(dir).unwrap();
    }
    Config {
        home,
        config_root,
        agent_dir: agent_dir.clone(),
        sessions_dir: agent_dir.join("sessions"),
        blobs_dir: agent_dir.join("blobs"),
        archive_dir: agent_dir.join("archive/sessions"),
        diagnostics_dir: agent_dir.join("omp-web"),
        omp_bin: None,
        socket: None,
        port: None,
        host: "127.0.0.1".into(),
        stt: None,
    }
}

fn write_session(cfg: &Config, name: &str) -> PathBuf {
    let project_dir = cfg.sessions_dir.join("-home-test-project");
    std::fs::create_dir_all(&project_dir).unwrap();
    let path = project_dir.join(format!("{}.jsonl", name));
    let slot = session_files::serialize_title_slot(
        "My test session",
        Some("user"),
        "2026-01-02T03:04:05.000Z",
    );
    let header = json!({
        "type": "session",
        "version": 3,
        "id": name,
        "timestamp": "2026-01-02T03:04:05.000Z",
        "cwd": "/home/test/project",
    });
    let user = json!({
        "type": "message",
        "id": "u1",
        "parentId": null,
        "timestamp": "2026-01-02T03:04:06.000Z",
        "message": { "role": "user", "content": "Hello there" }
    });
    let assistant = json!({
        "type": "message",
        "id": "a1",
        "parentId": "u1",
        "timestamp": "2026-01-02T03:04:07.000Z",
        "message": {
            "role": "assistant",
            "provider": "anthropic",
            "model": "claude",
            "content": [{ "type": "text", "text": "Hi!" }]
        }
    });
    let model = json!({
        "type": "model_change",
        "id": "m1",
        "parentId": "a1",
        "timestamp": "2026-01-02T03:04:08.000Z",
        "model": "anthropic/claude"
    });
    let body = format!(
        "{}{}\n{}\n{}\n{}\n",
        slot,
        serde_json::to_string(&header).unwrap(),
        serde_json::to_string(&user).unwrap(),
        serde_json::to_string(&assistant).unwrap(),
        serde_json::to_string(&model).unwrap()
    );
    std::fs::write(&path, body).unwrap();
    path
}

async fn body_json(response: axum::response::Response) -> Value {
    let bytes = response.into_body().collect().await.unwrap().to_bytes();
    serde_json::from_slice(&bytes).unwrap()
}

fn json_request(method: &str, uri: &str, body: Value) -> Request<Body> {
    Request::builder()
        .method(method)
        .uri(uri)
        .header("content-type", "application/json")
        .body(Body::from(body.to_string()))
        .unwrap()
}

// ============================================================================
// Unix socket
// ============================================================================

#[tokio::test]
async fn unix_socket_binding_serves_http() {
    let root = test_root("uds");
    let cfg = test_config(&root);
    let socket_path = root.join("run/aidesk.sock");
    let state = AppState::new(cfg);
    let router = build_router(state);
    let listener = bind_unix_socket(&socket_path).expect("bind UDS");
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        let mode = std::fs::metadata(&socket_path)
            .unwrap()
            .permissions()
            .mode()
            & 0o777;
        assert_eq!(mode, 0o660, "socket must be group-connectable");
        let parent_mode = std::fs::metadata(socket_path.parent().unwrap())
            .unwrap()
            .permissions()
            .mode()
            & 0o777;
        assert_eq!(parent_mode, 0o770);
    }
    tokio::spawn(serve_unix(listener, router));

    let mut stream = tokio::net::UnixStream::connect(&socket_path).await.unwrap();
    stream
        .write_all(b"GET /api/home HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n")
        .await
        .unwrap();
    let mut response = Vec::new();
    stream.read_to_end(&mut response).await.unwrap();
    let text = String::from_utf8_lossy(&response);
    assert!(text.contains("200 OK"), "response: {}", text);
    assert!(text.contains("\"home\""), "response: {}", text);

    // Re-binding removes a stale socket file instead of failing.
    let listener = bind_unix_socket(&socket_path).expect("rebind over stale socket");
    drop(listener);
    let _ = std::fs::remove_dir_all(root);
}

// ============================================================================
// Session JSONL parsing
// ============================================================================

#[tokio::test]
async fn session_jsonl_parses_title_tree_and_context() {
    let root = test_root("sessions");
    let cfg = test_config(&root);
    let path = write_session(&cfg, "session-abc");

    let header = session_files::read_session_header(&path).expect("header");
    assert_eq!(header["id"], json!("session-abc"));
    assert_eq!(header["title"], json!("My test session"));
    assert_eq!(header["titleSource"], json!("user"));

    let sessions = session_reader::list_all_sessions(&cfg);
    assert_eq!(sessions.len(), 1);
    assert_eq!(sessions[0].id, "session-abc");
    assert_eq!(sessions[0].name.as_deref(), Some("My test session"));
    assert_eq!(sessions[0].first_message, "Hello there");
    assert_eq!(sessions[0].message_count, 2);
    assert_eq!(sessions[0].created, "2026-01-02T03:04:05.000Z");

    let loaded = session_files::load_session_file(&path, None);
    assert_eq!(loaded.entries.len(), 3);
    let tree = session_files::build_session_tree(&loaded.entries);
    assert_eq!(tree.len(), 1);
    assert_eq!(tree[0]["children"].as_array().unwrap().len(), 1);

    let context = session_reader::build_session_context(
        &cfg,
        &loaded.entries,
        None,
        session_reader::ContextOptions::default(),
    );
    assert_eq!(context["entryIds"], json!(["u1", "a1"]));
    assert_eq!(context["messages"][0]["content"], json!("Hello there"));
    assert_eq!(
        context["model"],
        json!({ "provider": "anthropic", "modelId": "claude" })
    );

    // Session endpoint parity.
    let state = AppState::new(cfg.clone());
    let router = build_router(state);
    let response = router
        .clone()
        .oneshot(
            Request::builder()
                .uri("/api/sessions")
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(response.status(), StatusCode::OK);
    let listed = body_json(response).await;
    assert_eq!(listed["sessions"][0]["id"], json!("session-abc"));
    assert!(listed["runningSessionIds"].as_array().unwrap().is_empty());

    let response = router
        .oneshot(
            Request::builder()
                .uri("/api/sessions/session-abc")
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(response.status(), StatusCode::OK);
    let detail = body_json(response).await;
    assert_eq!(detail["leafId"], json!("m1"));
    assert_eq!(detail["info"]["messageCount"], json!(2));
    assert_eq!(detail["tree"].as_array().unwrap().len(), 1);
    let _ = std::fs::remove_dir_all(root);
}

// ============================================================================
// File PUT conflict
// ============================================================================

#[tokio::test]
async fn file_put_checks_mtime_conflicts() {
    let root = test_root("files");
    let cfg = test_config(&root);
    let workspace = root.join("workspace");
    std::fs::create_dir_all(&workspace).unwrap();
    let file = workspace.join("notes.txt");
    std::fs::write(&file, "first").unwrap();
    let current_mtime = aidesk_backend::util::mtime_ms(&std::fs::metadata(&file).unwrap());

    let state = AppState::new(cfg);
    state.allow_root(&workspace);
    let router = build_router(state);
    let uri = format!(
        "/api/files/{}",
        file.to_string_lossy().trim_start_matches('/')
    );

    let response = router
        .clone()
        .oneshot(json_request(
            "PUT",
            &uri,
            json!({ "content": "second", "expectedMtime": current_mtime - 5_000.0 }),
        ))
        .await
        .unwrap();
    assert_eq!(response.status(), StatusCode::CONFLICT);
    let body = body_json(response).await;
    assert_eq!(body["code"], json!("conflict_mtime"));
    assert!(body["currentMtime"].as_f64().unwrap() > 0.0);
    assert_eq!(std::fs::read_to_string(&file).unwrap(), "first");

    let response = router
        .clone()
        .oneshot(json_request(
            "PUT",
            &uri,
            json!({ "content": "second", "expectedMtime": current_mtime }),
        ))
        .await
        .unwrap();
    assert_eq!(response.status(), StatusCode::OK);
    let body = body_json(response).await;
    assert_eq!(body["success"], json!(true));
    assert_eq!(std::fs::read_to_string(&file).unwrap(), "second");

    // Reading back reports the language, size and mtime header.
    let response = router
        .oneshot(
            Request::builder()
                .uri(format!("{}?type=read", uri))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(response.status(), StatusCode::OK);
    assert!(response.headers().contains_key("x-file-mtime"));
    let body = body_json(response).await;
    assert_eq!(body["content"], json!("second"));
    assert_eq!(body["language"], json!("text"));
    let _ = std::fs::remove_dir_all(root);
}

// ============================================================================
// Terminal PTY
// ============================================================================

#[tokio::test]
async fn terminal_pty_runs_and_streams_output() {
    let root = test_root("pty");
    let cfg = test_config(&root);
    let workspace = root.join("workspace");
    std::fs::create_dir_all(&workspace).unwrap();
    let state = AppState::new(cfg);
    let session = state
        .terminals
        .create(Some(workspace.to_str().unwrap()), 100, 30, Some("/bin/sh"))
        .expect("PTY session");
    let info = session.info();
    assert!(info.pid > 0);
    assert_eq!((info.cols, info.rows), (100, 30));
    assert!(session.write_input("echo aidesk-pty-ok\n"));
    let deadline = std::time::Instant::now() + std::time::Duration::from_secs(5);
    let mut seen = false;
    while std::time::Instant::now() < deadline {
        if session.history().contains("aidesk-pty-ok") {
            seen = true;
            break;
        }
        tokio::time::sleep(std::time::Duration::from_millis(100)).await;
    }
    assert!(seen, "history: {:?}", session.history());
    assert!(session.resize(90, 25));
    assert_eq!(session.info().cols, 90);
    assert!(state.terminals.kill(&info.id));
    assert!(state.terminals.get(&info.id).is_none());
    let _ = std::fs::remove_dir_all(root);
}

// ============================================================================
// Settings endpoints
// ============================================================================

#[tokio::test]
async fn settings_endpoints_roundtrip() {
    let root = test_root("settings");
    let cfg = test_config(&root);
    let state = AppState::new(cfg.clone());
    let router = build_router(state);

    let response = router
        .clone()
        .oneshot(
            Request::builder()
                .uri("/api/omp-settings")
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(response.status(), StatusCode::OK);
    let body = body_json(response).await;
    assert_eq!(body["path"], json!(cfg.settings_path().to_string_lossy()));

    let response = router
        .clone()
        .oneshot(json_request(
            "PUT",
            "/api/omp-settings",
            json!({ "settings": { "defaultThinkingLevel": "high", "hideThinkingBlock": true } }),
        ))
        .await
        .unwrap();
    assert_eq!(response.status(), StatusCode::OK);
    let body = body_json(response).await;
    assert_eq!(body["success"], json!(true));
    assert_eq!(body["settings"]["defaultThinkingLevel"], json!("high"));
    let text = std::fs::read_to_string(cfg.settings_path()).unwrap();
    assert!(text.contains("defaultThinkingLevel: high"));

    let response = router
        .clone()
        .oneshot(json_request(
            "PUT",
            "/api/omp-settings",
            json!({ "settings": { "defaultThinkingLevel": "impossible" } }),
        ))
        .await
        .unwrap();
    assert_eq!(response.status(), StatusCode::BAD_REQUEST);

    let response = router
        .clone()
        .oneshot(
            Request::builder()
                .uri("/api/web-settings")
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let body = body_json(response).await;
    assert_eq!(body["autoResumeSessions"], json!(false));

    let response = router
        .clone()
        .oneshot(json_request(
            "PUT",
            "/api/web-settings",
            json!({ "autoResumeSessions": true, "agentEnv": "FOO=bar" }),
        ))
        .await
        .unwrap();
    assert_eq!(response.status(), StatusCode::OK);
    let body = body_json(response).await;
    assert_eq!(body["autoResumeSessions"], json!(true));
    assert_eq!(body["agentEnv"]["FOO"], json!("bar"));

    let response = router
        .clone()
        .oneshot(json_request(
            "PUT",
            "/api/web-settings",
            json!({ "agentEnv": "PATH=/evil" }),
        ))
        .await
        .unwrap();
    assert_eq!(response.status(), StatusCode::BAD_REQUEST);
    let body = body_json(response).await;
    assert_eq!(body["code"], json!("invalid_agent_env"));

    // Stored settings are served back.
    let response = router
        .oneshot(
            Request::builder()
                .uri("/api/web-settings")
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let body = body_json(response).await;
    assert_eq!(body["agentEnv"]["FOO"], json!("bar"));
    let _ = std::fs::remove_dir_all(root);
}

#[tokio::test]
async fn account_endpoint_reads_proxy_headers() {
    let root = test_root("account");
    let cfg = test_config(&root);
    let state = AppState::new(cfg);
    let router = build_router(state);

    let response = router
        .clone()
        .oneshot(
            Request::builder()
                .uri("/api/account")
                .header("Remote-User", "chn")
                .header("Remote-Name", "CHN")
                .header("Remote-Email", "chn@chn.moe")
                .header("Remote-Groups", "admins, users ,,")
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(response.status(), StatusCode::OK);
    let body = body_json(response).await;
    assert_eq!(body["user"], json!("chn"));
    assert_eq!(body["name"], json!("CHN"));
    assert_eq!(body["email"], json!("chn@chn.moe"));
    assert_eq!(body["groups"], json!(["admins", "users"]));

    // Without a proxy in front, the local login account stands in.
    let response = router
        .oneshot(
            Request::builder()
                .uri("/api/account")
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(response.status(), StatusCode::OK);
    let body = body_json(response).await;
    assert!(!body["user"].as_str().unwrap_or_default().is_empty());
    assert_eq!(body["groups"], json!([]));
    let _ = std::fs::remove_dir_all(root);
}

#[tokio::test]
async fn manifest_and_version_endpoints_are_json() {
    let root = test_root("misc");
    let cfg = test_config(&root);
    let state = AppState::new(cfg);
    let router = build_router(state);
    let response = router
        .clone()
        .oneshot(
            Request::builder()
                .uri("/api/manifest")
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(response.status(), StatusCode::OK);
    let body = body_json(response).await;
    assert_eq!(body["start_url"], json!("/"));
    assert_eq!(body["display"], json!("standalone"));

    let response = router
        .oneshot(
            Request::builder()
                .uri("/api/omp-version")
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(response.status(), StatusCode::OK);
    let body = body_json(response).await;
    assert!(body.get("version").is_some());
    let _ = std::fs::remove_dir_all(root);
}

// ============================================================================
// Explorer context-menu actions + explicit viewer overrides
// ============================================================================

fn file_uri(path: &Path) -> String {
    format!(
        "/api/files/{}",
        path.to_string_lossy().trim_start_matches('/')
    )
}

#[tokio::test]
async fn file_actions_create_and_viewer_overrides() {
    let root = test_root("file-menu");
    let cfg = test_config(&root);
    let workspace = root.join("workspace");
    std::fs::create_dir_all(&workspace).unwrap();
    let state = AppState::new(cfg);
    state.allow_root(&workspace);
    let router = build_router(state);

    // POST ?type=mkdir creates the folder once and reports a conflict after.
    let folder = workspace.join("new-folder");
    let response = router
        .clone()
        .oneshot(
            Request::builder()
                .method("POST")
                .uri(format!("{}?type=mkdir", file_uri(&folder)))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(response.status(), StatusCode::OK);
    let body = body_json(response).await;
    assert_eq!(body["success"], json!(true));
    assert_eq!(body["path"], json!(folder.to_string_lossy()));
    assert!(folder.is_dir());

    let response = router
        .clone()
        .oneshot(
            Request::builder()
                .method("POST")
                .uri(format!("{}?type=mkdir", file_uri(&folder)))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(response.status(), StatusCode::CONFLICT);
    assert_eq!(body_json(response).await["code"], json!("already_exists"));

    // createOnly refuses to overwrite an existing file.
    let notes = workspace.join("notes.md");
    std::fs::write(&notes, "keep me").unwrap();
    let response = router
        .clone()
        .oneshot(json_request(
            "PUT",
            &file_uri(&notes),
            json!({ "content": "", "createOnly": true }),
        ))
        .await
        .unwrap();
    assert_eq!(response.status(), StatusCode::CONFLICT);
    assert_eq!(
        body_json(response).await["code"],
        json!("file_already_exists")
    );
    assert_eq!(std::fs::read_to_string(&notes).unwrap(), "keep me");

    // createOnly creates a brand new file.
    let created = workspace.join("created.md");
    let response = router
        .clone()
        .oneshot(json_request(
            "PUT",
            &file_uri(&created),
            json!({ "content": "", "createOnly": true }),
        ))
        .await
        .unwrap();
    assert_eq!(response.status(), StatusCode::OK);
    assert!(created.is_file());

    // as=markdown rewrites the reported language even for a .txt file.
    let plain = workspace.join("plain.txt");
    std::fs::write(&plain, "# heading\n").unwrap();
    let response = router
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!("{}?type=read&as=markdown", file_uri(&plain)))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(response.status(), StatusCode::OK);
    assert_eq!(body_json(response).await["language"], json!("markdown"));

    // as=text reads an image extension as UTF-8 text instead of streaming it.
    let fake_image = workspace.join("fake.png");
    std::fs::write(&fake_image, "not really an image").unwrap();
    let response = router
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!("{}?type=read&as=text", file_uri(&fake_image)))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(response.status(), StatusCode::OK);
    assert_eq!(
        response.headers()[axum::http::header::CONTENT_TYPE],
        "application/json"
    );
    let body = body_json(response).await;
    assert_eq!(body["content"], json!("not really an image"));
    assert_eq!(body["language"], json!("text"));

    // as=image streams the same file with an image MIME.
    let response = router
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!("{}?type=read&as=image", file_uri(&fake_image)))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(response.status(), StatusCode::OK);
    assert_eq!(
        response.headers()[axum::http::header::CONTENT_TYPE],
        "image/png"
    );

    // as=pdf serves raw PDF bytes regardless of the extension.
    let report = workspace.join("report.bin");
    std::fs::write(&report, b"%PDF-1.4 fake body").unwrap();
    let response = router
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!("{}?type=preview&as=pdf", file_uri(&report)))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(response.status(), StatusCode::OK);
    assert_eq!(
        response.headers()[axum::http::header::CONTENT_TYPE],
        "application/pdf"
    );
    let bytes = response.into_body().collect().await.unwrap().to_bytes();
    assert_eq!(&bytes[..], b"%PDF-1.4 fake body");

    let _ = std::fs::remove_dir_all(root);
}
