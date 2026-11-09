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
    assert_eq!(body["sourceWordWrap"], json!(false));
    assert_eq!(body["showHiddenFiles"], json!(false));

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
    assert_eq!(body["sourceWordWrap"], json!(false));
    assert_eq!(body["showHiddenFiles"], json!(false));
    assert_eq!(body["agentEnv"]["FOO"], json!("bar"));

    let response = router
        .clone()
        .oneshot(json_request(
            "PUT",
            "/api/web-settings",
            json!({ "sourceWordWrap": true }),
        ))
        .await
        .unwrap();
    assert_eq!(response.status(), StatusCode::OK);
    let body = body_json(response).await;
    assert_eq!(body["sourceWordWrap"], json!(true));
    assert_eq!(body["showHiddenFiles"], json!(false));
    assert_eq!(body["autoResumeSessions"], json!(true));
    assert_eq!(body["agentEnv"]["FOO"], json!("bar"));

    let response = router
        .clone()
        .oneshot(json_request(
            "PUT",
            "/api/web-settings",
            json!({ "showHiddenFiles": true }),
        ))
        .await
        .unwrap();
    assert_eq!(response.status(), StatusCode::OK);
    let body = body_json(response).await;
    assert_eq!(body["sourceWordWrap"], json!(true));
    assert_eq!(body["showHiddenFiles"], json!(true));
    assert_eq!(body["autoResumeSessions"], json!(true));

    for (field, payload) in [
        ("sourceWordWrap", json!({ "sourceWordWrap": "yes" })),
        ("showHiddenFiles", json!({ "showHiddenFiles": "yes" })),
    ] {
        let response = router
            .clone()
            .oneshot(json_request("PUT", "/api/web-settings", payload))
            .await
            .unwrap();
        assert_eq!(response.status(), StatusCode::BAD_REQUEST);
        let body = body_json(response).await;
        assert_eq!(body["code"], json!("invalid_settings"));
        assert_eq!(body["error"], json!(format!("{field} must be a boolean")));
    }

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
    assert_eq!(body["sourceWordWrap"], json!(true));
    assert_eq!(body["showHiddenFiles"], json!(true));
    assert_eq!(body["autoResumeSessions"], json!(true));
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

// ============================================================================
// Explorer upgrade: list metadata, rename/move/copy/delete, zip, uploads
// ============================================================================

fn multipart_request(uri: &str, files: &[(&str, &[u8])]) -> Request<Body> {
    let boundary = "aidesk-test-boundary-7f3c";
    let mut body: Vec<u8> = Vec::new();
    for (name, bytes) in files {
        body.extend_from_slice(
            format!(
                "--{}\r\nContent-Disposition: form-data; name=\"files\"; filename=\"{}\"\r\nContent-Type: application/octet-stream\r\n\r\n",
                boundary, name
            )
            .as_bytes(),
        );
        body.extend_from_slice(bytes);
        body.extend_from_slice(b"\r\n");
    }
    body.extend_from_slice(format!("--{}--\r\n", boundary).as_bytes());
    Request::builder()
        .method("POST")
        .uri(uri)
        .header(
            "content-type",
            format!("multipart/form-data; boundary={}", boundary),
        )
        .body(Body::from(body))
        .unwrap()
}

fn entries_by_name(body: &Value) -> std::collections::HashMap<String, Value> {
    body["entries"]
        .as_array()
        .expect("entries array")
        .iter()
        .map(|entry| (entry["name"].as_str().unwrap().to_string(), entry.clone()))
        .collect()
}

#[tokio::test]
async fn file_list_reports_real_metadata_and_include_ignored() {
    let root = test_root("list-meta");
    let cfg = test_config(&root);
    let workspace = root.join("workspace");
    std::fs::create_dir_all(workspace.join("sub")).unwrap();
    std::fs::create_dir_all(workspace.join("node_modules")).unwrap();
    std::fs::create_dir_all(workspace.join(".git")).unwrap();
    std::fs::write(workspace.join("alpha.txt"), "hello").unwrap();
    std::fs::write(workspace.join("node_modules/pkg.js"), "x").unwrap();
    #[cfg(unix)]
    std::os::unix::fs::symlink("alpha.txt", workspace.join("link.txt")).unwrap();

    let state = AppState::new(cfg);
    state.allow_root(&workspace);
    let router = build_router(state);

    let response = router
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!("{}?type=list", file_uri(&workspace)))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(response.status(), StatusCode::OK);
    let body = body_json(response).await;
    let entries = entries_by_name(&body);
    assert!(!entries.contains_key("node_modules"));
    assert!(!entries.contains_key(".git"));
    let alpha = &entries["alpha.txt"];
    assert_eq!(alpha["isDir"], json!(false));
    assert_eq!(alpha["isSymlink"], json!(false));
    assert_eq!(alpha["isIgnored"], json!(false));
    assert_eq!(alpha["size"], json!(5));
    assert!(alpha["modified"].as_f64().unwrap() > 0.0);
    let sub = &entries["sub"];
    assert_eq!(sub["isDir"], json!(true));
    assert_eq!(sub["size"], json!(0));
    #[cfg(unix)]
    {
        let link = &entries["link.txt"];
        assert_eq!(link["isSymlink"], json!(true));
        assert_eq!(link["isDir"], json!(false));
        assert_eq!(link["size"], json!(5));
    }

    let response = router
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!(
                    "{}?type=list&includeIgnored=1",
                    file_uri(&workspace)
                ))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(response.status(), StatusCode::OK);
    let entries = entries_by_name(&body_json(response).await);
    assert_eq!(entries["node_modules"]["isIgnored"], json!(true));
    assert_eq!(entries["node_modules"]["isDir"], json!(true));
    assert_eq!(entries[".git"]["isIgnored"], json!(true));
    assert_eq!(entries["alpha.txt"]["isIgnored"], json!(false));
    let _ = std::fs::remove_dir_all(root);
}

#[tokio::test]
async fn file_patch_renames_moves_copies_and_guards_conflicts() {
    let root = test_root("patch");
    let cfg = test_config(&root);
    let workspace = root.join("workspace");
    std::fs::create_dir_all(workspace.join("sub")).unwrap();
    std::fs::create_dir_all(workspace.join("tree/child")).unwrap();
    std::fs::write(workspace.join("a.txt"), "alpha").unwrap();
    std::fs::write(workspace.join("tree/child/leaf.txt"), "leaf").unwrap();
    std::fs::write(workspace.join("taken.txt"), "old").unwrap();

    let state = AppState::new(cfg);
    state.allow_root(&workspace);
    let router = build_router(state);

    let a = workspace.join("a.txt");
    let b = workspace.join("b.txt");
    let response = router
        .clone()
        .oneshot(json_request(
            "PATCH",
            &file_uri(&a),
            json!({ "action": "rename", "destination": b }),
        ))
        .await
        .unwrap();
    assert_eq!(response.status(), StatusCode::OK);
    let body = body_json(response).await;
    assert_eq!(body["success"], json!(true));
    assert_eq!(body["action"], json!("rename"));
    assert_eq!(body["path"], json!(b.to_string_lossy()));
    assert!(!a.exists());
    assert_eq!(std::fs::read_to_string(&b).unwrap(), "alpha");

    // move into an existing subdirectory
    let moved = workspace.join("sub/b.txt");
    let response = router
        .clone()
        .oneshot(json_request(
            "PATCH",
            &file_uri(&b),
            json!({ "action": "move", "destination": moved }),
        ))
        .await
        .unwrap();
    assert_eq!(response.status(), StatusCode::OK);
    assert!(!b.exists());
    assert_eq!(std::fs::read_to_string(&moved).unwrap(), "alpha");

    // copy keeps the source and duplicates contents
    let copy = workspace.join("copy.txt");
    let response = router
        .clone()
        .oneshot(json_request(
            "PATCH",
            &file_uri(&moved),
            json!({ "action": "copy", "destination": copy }),
        ))
        .await
        .unwrap();
    assert_eq!(response.status(), StatusCode::OK);
    assert_eq!(std::fs::read_to_string(&moved).unwrap(), "alpha");
    assert_eq!(std::fs::read_to_string(&copy).unwrap(), "alpha");

    // conflict without overwrite
    let taken = workspace.join("taken.txt");
    let response = router
        .clone()
        .oneshot(json_request(
            "PATCH",
            &file_uri(&copy),
            json!({ "action": "rename", "destination": taken }),
        ))
        .await
        .unwrap();
    assert_eq!(response.status(), StatusCode::CONFLICT);
    let body = body_json(response).await;
    assert_eq!(body["code"], json!("already_exists"));
    assert_eq!(body["error"], json!("Target already exists"));
    assert_eq!(std::fs::read_to_string(&taken).unwrap(), "old");

    // overwrite replaces the target in place
    let response = router
        .clone()
        .oneshot(json_request(
            "PATCH",
            &file_uri(&copy),
            json!({ "action": "rename", "destination": taken, "overwrite": true }),
        ))
        .await
        .unwrap();
    assert_eq!(response.status(), StatusCode::OK);
    assert_eq!(std::fs::read_to_string(&taken).unwrap(), "alpha");
    assert!(!copy.exists());

    #[cfg(unix)]
    {
        // Renaming a symbolic link moves the link itself, not its target.
        let link = workspace.join("link.txt");
        std::os::unix::fs::symlink("taken.txt", &link).unwrap();
        let moved_link = workspace.join("moved-link.txt");
        let response = router
            .clone()
            .oneshot(json_request(
                "PATCH",
                &file_uri(&link),
                json!({ "action": "rename", "destination": moved_link }),
            ))
            .await
            .unwrap();
        assert_eq!(response.status(), StatusCode::OK);
        assert!(std::fs::symlink_metadata(&link).is_err());
        let meta = std::fs::symlink_metadata(&moved_link).unwrap();
        assert!(meta.file_type().is_symlink());
        assert_eq!(std::fs::read_to_string(&moved_link).unwrap(), "alpha");
        assert_eq!(std::fs::read_to_string(&taken).unwrap(), "alpha");
    }

    // a directory may not be moved into its own subtree
    let tree = workspace.join("tree");
    let response = router
        .clone()
        .oneshot(json_request(
            "PATCH",
            &file_uri(&tree),
            json!({ "action": "move", "destination": tree.join("child/tree") }),
        ))
        .await
        .unwrap();
    assert_eq!(response.status(), StatusCode::BAD_REQUEST);
    assert_eq!(
        body_json(response).await["code"],
        json!("destination_inside_source")
    );
    assert!(tree.join("child/leaf.txt").exists());

    // destinations must be absolute
    let response = router
        .clone()
        .oneshot(json_request(
            "PATCH",
            &file_uri(&taken),
            json!({ "action": "copy", "destination": "relative.txt" }),
        ))
        .await
        .unwrap();
    assert_eq!(response.status(), StatusCode::BAD_REQUEST);
    assert_eq!(
        body_json(response).await["code"],
        json!("destination_must_be_absolute")
    );

    // directory copy duplicates the tree
    let copied_tree = workspace.join("tree-copy");
    let response = router
        .clone()
        .oneshot(json_request(
            "PATCH",
            &file_uri(&tree),
            json!({ "action": "copy", "destination": copied_tree }),
        ))
        .await
        .unwrap();
    assert_eq!(response.status(), StatusCode::OK);
    assert_eq!(
        std::fs::read_to_string(copied_tree.join("child/leaf.txt")).unwrap(),
        "leaf"
    );
    let _ = std::fs::remove_dir_all(root);
}

#[tokio::test]
async fn file_delete_handles_files_directories_and_protects_roots() {
    let root = test_root("delete");
    let cfg = test_config(&root);
    let workspace = root.join("workspace");
    std::fs::create_dir_all(workspace.join("dir/nested")).unwrap();
    std::fs::write(workspace.join("file.txt"), "bye").unwrap();
    std::fs::write(workspace.join("dir/nested/child.txt"), "child").unwrap();

    let state = AppState::new(cfg);
    state.allow_root(&workspace);
    let router = build_router(state);

    let file = workspace.join("file.txt");
    let response = router
        .clone()
        .oneshot(
            Request::builder()
                .method("DELETE")
                .uri(file_uri(&file))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(response.status(), StatusCode::OK);
    let body = body_json(response).await;
    assert_eq!(body["success"], json!(true));
    assert_eq!(body["deleted"], json!(file.to_string_lossy()));
    assert!(!file.exists());

    // recursive defaults to true for non-empty directories
    let dir = workspace.join("dir");
    let response = router
        .clone()
        .oneshot(
            Request::builder()
                .method("DELETE")
                .uri(format!("{}?recursive=true", file_uri(&dir)))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(response.status(), StatusCode::OK);
    assert!(!dir.exists());

    // a non-recursive delete of a non-empty directory reports a conflict
    std::fs::create_dir_all(workspace.join("dir2")).unwrap();
    std::fs::write(workspace.join("dir2/child.txt"), "child").unwrap();
    let dir2 = workspace.join("dir2");
    let response = router
        .clone()
        .oneshot(
            Request::builder()
                .method("DELETE")
                .uri(format!("{}?recursive=0", file_uri(&dir2)))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(response.status(), StatusCode::CONFLICT);
    assert_eq!(
        body_json(response).await["code"],
        json!("directory_not_empty")
    );
    assert!(dir2.exists());

    #[cfg(unix)]
    {
        // Deleting a symlink to a directory unlinks the link only.
        let outside_dir = root.join("outside-dir");
        std::fs::create_dir_all(&outside_dir).unwrap();
        std::fs::write(outside_dir.join("keep.txt"), "keep").unwrap();
        let link_dir = workspace.join("link-dir");
        std::os::unix::fs::symlink(&outside_dir, &link_dir).unwrap();
        let response = router
            .clone()
            .oneshot(
                Request::builder()
                    .method("DELETE")
                    .uri(file_uri(&link_dir))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        assert_eq!(response.status(), StatusCode::OK);
        assert!(std::fs::symlink_metadata(&link_dir).is_err());
        assert_eq!(
            std::fs::read_to_string(outside_dir.join("keep.txt")).unwrap(),
            "keep"
        );
    }

    // an allowed root can never be deleted
    let response = router
        .oneshot(
            Request::builder()
                .method("DELETE")
                .uri(file_uri(&workspace))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(response.status(), StatusCode::FORBIDDEN);
    assert_eq!(
        body_json(response).await["code"],
        json!("cannot_delete_root")
    );
    assert!(workspace.exists());
    let _ = std::fs::remove_dir_all(root);
}

#[tokio::test]
async fn download_zip_skips_ignored_and_escaping_entries() {
    let root = test_root("zip");
    let cfg = test_config(&root);
    let workspace = root.join("workspace");
    std::fs::create_dir_all(workspace.join("proj/sub")).unwrap();
    std::fs::create_dir_all(workspace.join("proj/node_modules")).unwrap();
    std::fs::create_dir_all(workspace.join("proj/.git")).unwrap();
    std::fs::write(workspace.join("proj/a.txt"), "aaa").unwrap();
    std::fs::write(workspace.join("proj/sub/b.txt"), "bbb").unwrap();
    std::fs::write(workspace.join("proj/node_modules/pkg.js"), "ignored").unwrap();
    std::fs::write(workspace.join("proj/.git/config"), "secret").unwrap();
    let outside = root.join("outside.txt");
    std::fs::write(&outside, "outside").unwrap();
    #[cfg(unix)]
    std::os::unix::fs::symlink(&outside, workspace.join("proj/escape.txt")).unwrap();

    let state = AppState::new(cfg);
    state.allow_root(&workspace);
    let router = build_router(state);

    let proj = workspace.join("proj");
    let response = router
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!("{}?type=download-zip", file_uri(&proj)))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(response.status(), StatusCode::OK);
    assert_eq!(
        response.headers()[axum::http::header::CONTENT_TYPE],
        "application/zip"
    );
    assert_eq!(
        response.headers()[axum::http::header::CONTENT_DISPOSITION],
        "attachment; filename=\"proj.zip\""
    );
    let bytes = response.into_body().collect().await.unwrap().to_bytes();
    let mut archive = zip::ZipArchive::new(std::io::Cursor::new(bytes.to_vec())).unwrap();
    let mut names = Vec::new();
    for index in 0..archive.len() {
        names.push(archive.by_index(index).unwrap().name().to_string());
    }
    assert!(names.contains(&"a.txt".to_string()));
    assert!(names.contains(&"sub/b.txt".to_string()));
    assert!(!names.iter().any(|name| name.starts_with("node_modules/")));
    assert!(!names.iter().any(|name| name.starts_with(".git/")));
    assert!(!names.contains(&"escape.txt".to_string()));

    let response = router
        .oneshot(
            Request::builder()
                .uri(format!(
                    "{}?type=download-zip&includeIgnored=1",
                    file_uri(&proj)
                ))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(response.status(), StatusCode::OK);
    let bytes = response.into_body().collect().await.unwrap().to_bytes();
    let mut archive = zip::ZipArchive::new(std::io::Cursor::new(bytes.to_vec())).unwrap();
    let mut names = Vec::new();
    for index in 0..archive.len() {
        names.push(archive.by_index(index).unwrap().name().to_string());
    }
    assert!(names.contains(&"node_modules/pkg.js".to_string()));
    assert!(!names.iter().any(|name| name.starts_with(".git/")));
    let _ = std::fs::remove_dir_all(root);
}

#[tokio::test]
async fn uploads_support_relative_subdirectories_and_rename_conflicts() {
    let root = test_root("upload");
    let cfg = test_config(&root);
    let workspace = root.join("workspace");
    std::fs::create_dir_all(&workspace).unwrap();
    let state = AppState::new(cfg);
    state.allow_root(&workspace);
    let router = build_router(state);

    // upload-check accepts the explorer's `files` array and nested paths
    let response = router
        .clone()
        .oneshot(json_request(
            "POST",
            &format!("{}?type=upload-check", file_uri(&workspace)),
            json!({ "files": ["subfolder/a.txt"] }),
        ))
        .await
        .unwrap();
    assert_eq!(response.status(), StatusCode::OK);
    assert_eq!(body_json(response).await["conflicts"], json!([]));

    // invalid names are rejected before anything is written
    let response = router
        .clone()
        .oneshot(json_request(
            "POST",
            &format!("{}?type=upload-check", file_uri(&workspace)),
            json!({ "files": ["../escape.txt"] }),
        ))
        .await
        .unwrap();
    assert_eq!(response.status(), StatusCode::BAD_REQUEST);
    assert_eq!(
        body_json(response).await["code"],
        json!("invalid_file_name")
    );

    let upload_uri = format!("{}?type=upload", file_uri(&workspace));
    let response = router
        .clone()
        .oneshot(multipart_request(
            &upload_uri,
            &[("subfolder/a.txt", b"one")],
        ))
        .await
        .unwrap();
    assert_eq!(response.status(), StatusCode::OK);
    let body = body_json(response).await;
    assert_eq!(body["uploaded"], json!(["subfolder/a.txt"]));
    assert_eq!(
        std::fs::read_to_string(workspace.join("subfolder/a.txt")).unwrap(),
        "one"
    );

    // conflict=rename picks `stem (1).ext`
    let response = router
        .clone()
        .oneshot(multipart_request(
            &format!("{}&conflict=rename", upload_uri),
            &[("subfolder/a.txt", b"two")],
        ))
        .await
        .unwrap();
    assert_eq!(response.status(), StatusCode::OK);
    let body = body_json(response).await;
    assert_eq!(body["uploaded"], json!(["subfolder/a (1).txt"]));
    assert_eq!(
        std::fs::read_to_string(workspace.join("subfolder/a.txt")).unwrap(),
        "one"
    );
    assert_eq!(
        std::fs::read_to_string(workspace.join("subfolder/a (1).txt")).unwrap(),
        "two"
    );

    // a `.git` component is never allowed
    let response = router
        .clone()
        .oneshot(multipart_request(&upload_uri, &[(".git/config", b"nope")]))
        .await
        .unwrap();
    assert_eq!(response.status(), StatusCode::BAD_REQUEST);
    assert!(!workspace.join(".git/config").exists());

    #[cfg(unix)]
    {
        // Existing intermediate symlinks must not be followed out of the root.
        let outside_dir = root.join("outside-upload");
        std::fs::create_dir_all(&outside_dir).unwrap();
        std::os::unix::fs::symlink(&outside_dir, workspace.join("escape-dir")).unwrap();
        let response = router
            .clone()
            .oneshot(multipart_request(
                &upload_uri,
                &[("escape-dir/escaped.txt", b"nope")],
            ))
            .await
            .unwrap();
        assert_eq!(response.status(), StatusCode::MULTI_STATUS);
        let body = body_json(response).await;
        assert!(!body["errors"].as_array().unwrap().is_empty());
        assert!(!outside_dir.join("escaped.txt").exists());
    }
    let _ = std::fs::remove_dir_all(root);
}
