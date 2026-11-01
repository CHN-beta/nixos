//! End-to-end tests for `/api/memories/*` against a mock Hindsight server.

use aidesk_backend::build_router;
use aidesk_backend::config::Config;
use aidesk_backend::state::AppState;
use axum::extract::State;
use axum::http::{HeaderMap, StatusCode, Uri};
use axum::response::IntoResponse;
use axum::routing::{get, post};
use axum::{Json, Router};
use http_body_util::BodyExt;
use serde_json::{json, Value};
use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex};
use tower::ServiceExt;

#[derive(Clone, Debug)]
struct Seen {
    method: String,
    path: String,
    query: Option<String>,
    authorization: Option<String>,
    body: Option<Value>,
}

type Shared = Arc<Mutex<Vec<Seen>>>;

fn record(seen: &Shared, method: &str, uri: &Uri, headers: &HeaderMap, body: &[u8]) {
    seen.lock().unwrap().push(Seen {
        method: method.to_string(),
        path: uri.path().to_string(),
        query: uri.query().map(str::to_string),
        authorization: headers
            .get("authorization")
            .and_then(|value| value.to_str().ok())
            .map(str::to_string),
        body: serde_json::from_slice(body).ok(),
    });
}

fn graph_fixture() -> Value {
    json!({
        "nodes": [
            {"data": {"id": "a", "label": "Alice works at Google", "text": "Alice works at Google on the AI team", "entities": "Alice, Google", "color": "#90caf9"}},
            {"data": {"id": "b", "label": "Bob went hiking", "text": "Bob went hiking in the alps", "entities": "Bob", "color": "#90caf9"}},
            {"data": {"id": "c", "label": "Quarterly planning", "text": "Quarterly planning meeting", "entities": "None", "color": "#e0e0e0"}},
        ],
        "edges": [
            {"data": {"id": "a-b-semantic", "source": "a", "target": "b", "linkType": "semantic", "weight": 0.8}},
            {"data": {"id": "a-c-entity", "source": "a", "target": "c", "linkType": "entity", "weight": 1.0, "entityName": "Google"}},
        ],
        "table_rows": [
            {
                "id": "a",
                "text": "Alice works at Google on the AI team",
                "context": "work info",
                "entities": "Alice, Google",
                "tags": ["user_a"],
                "fact_type": "world",
                "date": "2024-01-15 10:30",
                "mentioned_at": "2024-01-15T10:30:00Z",
                "occurred_start": "2024-01-15T10:30:00Z",
                "document_id": "doc-1",
                "chunk_id": "chunk-1",
                "proof_count": 2,
            },
            {
                "id": "b",
                "text": "Bob went hiking in the alps",
                "context": "trip notes",
                "entities": "Bob",
                "tags": [],
                "fact_type": "experience",
                "date": "N/A",
                "proof_count": null,
            },
            {
                "id": "c",
                "text": "Quarterly planning meeting",
                "context": "Google calendar sync",
                "entities": "None",
                "tags": ["work"],
                "fact_type": "observation",
                "date": "N/A",
            },
        ],
        "total_units": 3,
        "limit": 1000,
    })
}

async fn mock_graph(
    State(seen): State<Shared>,
    uri: Uri,
    headers: HeaderMap,
) -> axum::response::Response {
    record(&seen, "GET", &uri, &headers, &[]);
    if uri.path().contains("/banks/broken/") {
        return (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(json!({"detail": "graph exploded"})),
        )
            .into_response();
    }
    Json(graph_fixture()).into_response()
}

async fn mock_recall(
    State(seen): State<Shared>,
    uri: Uri,
    headers: HeaderMap,
    body: axum::body::Bytes,
) -> Json<Value> {
    record(&seen, "POST", &uri, &headers, &body);
    Json(json!({
        "results": [
            {
                "id": "a",
                "text": "Alice works at Google on the AI team",
                "type": "world",
                "entities": ["Alice", "Google"],
                "context": "work info",
                "occurred_start": "2024-01-15T10:30:00Z",
                "mentioned_at": "2024-01-15T10:30:00Z",
                "document_id": "doc-1",
                "chunk_id": "chunk-1",
                "tags": ["user_a"],
                "scores": {"final": 0.2},
            },
            {
                "id": "c",
                "text": "Quarterly planning meeting",
                "type": "observation",
                "entities": ["Carol"],
                "context": serde_json::Value::Null,
                "scores": {"final": 0.9},
            },
        ],
        "trace": {"visits": []},
    }))
}

async fn mock_get_memory(
    State(seen): State<Shared>,
    uri: Uri,
    headers: HeaderMap,
) -> axum::response::Response {
    record(&seen, "GET", &uri, &headers, &[]);
    let id = uri
        .path()
        .rsplit('/')
        .next()
        .unwrap_or_default()
        .to_string();
    if id == "missing" {
        return (
            StatusCode::NOT_FOUND,
            Json(json!({"detail": format!("Memory unit '{}' not found", id)})),
        )
            .into_response();
    }
    Json(json!({
        "id": id,
        "text": "Alice works at Google on the AI team",
        "fact_type": "world",
        "entities": ["Alice", "Google"],
        "tags": ["user_a"],
        "state": "valid",
    }))
    .into_response()
}

async fn mock_patch_memory(
    State(seen): State<Shared>,
    uri: Uri,
    headers: HeaderMap,
    body: axum::body::Bytes,
) -> axum::response::Response {
    record(&seen, "PATCH", &uri, &headers, &body);
    let patch: Value = serde_json::from_slice(&body).unwrap_or(Value::Null);
    let id = uri
        .path()
        .rsplit('/')
        .next()
        .unwrap_or_default()
        .to_string();
    Json(json!({
        "id": id,
        "text": patch.get("text").cloned().unwrap_or(Value::Null),
        "state": patch.get("state").cloned().unwrap_or_else(|| json!("valid")),
    }))
    .into_response()
}

/// Start the mock Hindsight API; returns its base URL and the request log.
async fn start_mock() -> (String, Shared) {
    let seen: Shared = Arc::new(Mutex::new(Vec::new()));
    let app = Router::new()
        .route("/v1/default/banks/{bank}/graph", get(mock_graph))
        .route(
            "/v1/default/banks/{bank}/memories/recall",
            post(mock_recall),
        )
        .route(
            "/v1/default/banks/{bank}/memories/{id}",
            get(mock_get_memory).patch(mock_patch_memory),
        )
        .with_state(seen.clone());
    let listener = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
    let addr = listener.local_addr().unwrap();
    tokio::spawn(async move {
        axum::serve(listener, app).await.unwrap();
    });
    (format!("http://{}", addr), seen)
}

fn test_root(name: &str) -> PathBuf {
    let root = std::env::temp_dir().join(format!(
        "aidesk-memories-api-{}-{}",
        name,
        uuid::Uuid::new_v4()
    ));
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

/// A config pointing at the mock, with the token only available through the
/// nix `omp` wrapper (the path the production setup uses).
fn configured_state(name: &str, api_url: &str) -> Arc<AppState> {
    configured_state_for(name, api_url, "chn")
}

fn configured_state_for(name: &str, api_url: &str, bank_id: &str) -> Arc<AppState> {
    let root = test_root(name);
    let mut cfg = test_config(&root);
    std::fs::write(
        cfg.agent_dir.join("config.yml"),
        format!(
            "memory:\n  backend: hindsight\nhindsight:\n  apiUrl: \"{}\"\n  bankId: {}\n",
            api_url, bank_id
        ),
    )
    .unwrap();
    let wrapper = root.join("omp-wrapper");
    std::fs::write(
        &wrapper,
        "#!/bin/sh\nexport HINDSIGHT_API_TOKEN=\"tok-123\"\nexec omp \"$@\"\n",
    )
    .unwrap();
    cfg.omp_bin = Some(wrapper);
    AppState::new(cfg)
}

async fn body_json(response: axum::response::Response) -> Value {
    let bytes = response.into_body().collect().await.unwrap().to_bytes();
    serde_json::from_slice(&bytes).unwrap()
}

fn json_request(method: &str, uri: &str, body: Value) -> axum::http::Request<axum::body::Body> {
    axum::http::Request::builder()
        .method(method)
        .uri(uri)
        .header("content-type", "application/json")
        .body(axum::body::Body::from(body.to_string()))
        .unwrap()
}

fn get_request(uri: &str) -> axum::http::Request<axum::body::Body> {
    axum::http::Request::builder()
        .uri(uri)
        .body(axum::body::Body::empty())
        .unwrap()
}

fn find<'a>(seen: &'a [Seen], method: &str, path_suffix: &str) -> &'a Seen {
    seen.iter()
        .find(|entry| entry.method == method && entry.path.ends_with(path_suffix))
        .unwrap_or_else(|| panic!("no {} request ending in {}", method, path_suffix))
}

/// The token the resolver will use: a real `HINDSIGHT_API_TOKEN` in the test
/// environment wins over the wrapper script (that is the documented priority).
fn expected_token() -> String {
    std::env::var("HINDSIGHT_API_TOKEN")
        .ok()
        .map(|value| value.trim().to_string())
        .filter(|value| !value.is_empty())
        .unwrap_or_else(|| "tok-123".to_string())
}

/// True when the host itself exports a Hindsight token or URL, in which case a
/// config-less install is still "configured" by design.
fn host_env_is_configured() -> bool {
    ["HINDSIGHT_API_TOKEN", "HINDSIGHT_API_URL"]
        .iter()
        .any(|name| {
            std::env::var(name)
                .map(|value| !value.trim().is_empty())
                .unwrap_or(false)
        })
}

#[tokio::test]
async fn graph_route_passes_through_and_enriches_nodes() {
    let (api_url, seen) = start_mock().await;
    let router = build_router(configured_state("graph", &api_url));

    let response = router
        .oneshot(get_request(
            "/api/memories/graph?limit=500&type=world&q=google",
        ))
        .await
        .unwrap();
    assert_eq!(response.status(), StatusCode::OK);
    let value = body_json(response).await;

    assert_eq!(value["configured"], true);
    assert_eq!(value["bankId"], "chn");
    assert_eq!(value["limit"], 1000);
    assert_eq!(value["total_units"], 3);
    assert_eq!(value["nodes"].as_array().unwrap().len(), 3);
    assert_eq!(value["edges"].as_array().unwrap().len(), 2);
    assert_eq!(value["table_rows"].as_array().unwrap().len(), 3);
    assert_eq!(value["nodes"][0]["data"]["factType"], "world");
    assert_eq!(value["nodes"][0]["data"]["tags"], json!(["user_a"]));
    assert_eq!(value["nodes"][1]["data"]["factType"], "experience");

    let seen = seen.lock().unwrap();
    let request = find(&seen, "GET", "/v1/default/banks/chn/graph");
    let query = request.query.as_deref().unwrap();
    assert!(query.contains("limit=500"), "query was {}", query);
    assert!(query.contains("type=world"), "query was {}", query);
    assert!(query.contains("q=google"), "query was {}", query);
    assert_eq!(
        request.authorization.as_deref(),
        Some(format!("Bearer {}", expected_token()).as_str())
    );
}

#[tokio::test]
async fn text_search_scores_filters_and_prunes_the_graph() {
    let (api_url, seen) = start_mock().await;
    let router = build_router(configured_state("search-text", &api_url));

    let response = router
        .oneshot(json_request(
            "POST",
            "/api/memories/search",
            json!({"query": "google", "mode": "text", "limit": 50}),
        ))
        .await
        .unwrap();
    assert_eq!(response.status(), StatusCode::OK);
    let value = body_json(response).await;

    assert_eq!(value["mode"], "text");
    assert_eq!(value["query"], "google");
    assert_eq!(value["total"], 2);
    assert_eq!(value["items"][0]["id"], "a");
    assert_eq!(value["items"][1]["id"], "c");
    let first = value["items"][0]["score"].as_f64().unwrap();
    let second = value["items"][1]["score"].as_f64().unwrap();
    assert!(first > second && first <= 1.0 && second > 0.0);
    assert_eq!(value["items"][0]["entities"], json!(["Alice", "Google"]));
    assert_eq!(value["items"][0]["proof_count"], 2);
    // Only the matching memories survive, and only edges between them.
    let node_ids: Vec<&str> = value["nodes"]
        .as_array()
        .unwrap()
        .iter()
        .map(|node| node["data"]["id"].as_str().unwrap())
        .collect();
    assert_eq!(node_ids, vec!["a", "c"]);
    assert_eq!(value["edges"].as_array().unwrap().len(), 1);
    assert_eq!(value["edges"][0]["data"]["id"], "a-c-entity");

    let seen = seen.lock().unwrap();
    let request = find(&seen, "GET", "/v1/default/banks/chn/graph");
    assert!(
        request.query.as_deref().unwrap().contains("q=google"),
        "query was {:?}",
        request.query
    );
}

#[tokio::test]
async fn meaning_search_recalls_and_rebuilds_the_graph() {
    let (api_url, seen) = start_mock().await;
    let router = build_router(configured_state("search-meaning", &api_url));

    let response = router
        .oneshot(json_request(
            "POST",
            "/api/memories/search",
            json!({"query": "what did alice do", "mode": "meaning"}),
        ))
        .await
        .unwrap();
    assert_eq!(response.status(), StatusCode::OK);
    let value = body_json(response).await;

    assert_eq!(value["mode"], "meaning");
    assert_eq!(value["total"], 2);
    assert_eq!(value["items"][0]["id"], "c");
    assert_eq!(value["items"][1]["id"], "a");
    assert!((value["items"][0]["score"].as_f64().unwrap() - 0.9).abs() < 1e-9);
    assert_eq!(value["items"][1]["fact_type"], "world");
    assert_eq!(value["items"][1]["entities"], json!(["Alice", "Google"]));
    assert_eq!(value["nodes"].as_array().unwrap().len(), 2);
    assert_eq!(value["nodes"][0]["data"]["factType"], "observation");
    // The a-c graph edge is the only real edge between the recalled units.
    assert_eq!(value["edges"].as_array().unwrap().len(), 1);
    assert_eq!(value["edges"][0]["data"]["id"], "a-c-entity");

    let seen = seen.lock().unwrap();
    let request = find(&seen, "POST", "/v1/default/banks/chn/memories/recall");
    assert_eq!(
        request.authorization.as_deref(),
        Some(format!("Bearer {}", expected_token()).as_str())
    );
    let body = request.body.as_ref().unwrap();
    assert_eq!(body["query"], "what did alice do");
    assert_eq!(body["types"], json!(["world", "experience", "observation"]));
    assert_eq!(body["budget"], "mid");
    assert_eq!(body["max_tokens"], 4096);
    assert_eq!(body["trace"], true);
    assert_eq!(body["include"]["entities"]["max_tokens"], 500);
    assert_eq!(body["include"]["source_facts"]["max_tokens"], 2000);

    let graph = find(&seen, "GET", "/v1/default/banks/chn/graph");
    assert!(
        graph.query.as_deref().unwrap().contains("limit=1000"),
        "query was {:?}",
        graph.query
    );
}

#[tokio::test]
async fn memory_get_and_patch_proxy_to_hindsight() {
    let (api_url, seen) = start_mock().await;
    let router = build_router(configured_state("crud", &api_url));

    let response = router
        .clone()
        .oneshot(get_request("/api/memories/m1"))
        .await
        .unwrap();
    assert_eq!(response.status(), StatusCode::OK);
    let value = body_json(response).await;
    assert_eq!(value["id"], "m1");
    assert_eq!(value["text"], "Alice works at Google on the AI team");

    let response = router
        .clone()
        .oneshot(get_request("/api/memories/missing"))
        .await
        .unwrap();
    assert_eq!(response.status(), StatusCode::NOT_FOUND);
    let value = body_json(response).await;
    assert_eq!(value["error"], "Memory unit 'missing' not found");

    let response = router
        .clone()
        .oneshot(json_request(
            "PATCH",
            "/api/memories/m1",
            json!({"text": "edited text", "state": "invalidated", "reason": "stale"}),
        ))
        .await
        .unwrap();
    assert_eq!(response.status(), StatusCode::OK);
    let value = body_json(response).await;
    assert_eq!(value["text"], "edited text");
    assert_eq!(value["state"], "invalidated");

    let seen = seen.lock().unwrap();
    let patch = find(&seen, "PATCH", "/v1/default/banks/chn/memories/m1");
    let body = patch.body.as_ref().unwrap();
    assert_eq!(body["text"], "edited text");
    assert_eq!(body["state"], "invalidated");
    assert_eq!(body["reason"], "stale");
    assert_eq!(
        patch.authorization.as_deref(),
        Some(format!("Bearer {}", expected_token()).as_str())
    );
}

#[tokio::test]
async fn unconfigured_install_reports_configured_false() {
    if host_env_is_configured() {
        // The host itself exports a Hindsight token/URL (e.g. this test runs
        // under the nix `omp` wrapper), which by design makes the install
        // "configured": there is nothing left to test here.
        return;
    }
    let root = test_root("unconfigured");
    let state = AppState::new(test_config(&root));
    let router = build_router(state);

    let response = router
        .clone()
        .oneshot(get_request("/api/memories/graph"))
        .await
        .unwrap();
    assert_eq!(response.status(), StatusCode::OK);
    let value = body_json(response).await;
    assert_eq!(value["configured"], false);
    assert_eq!(value["nodes"], json!([]));
    assert_eq!(value["edges"], json!([]));
    assert_eq!(value["table_rows"], json!([]));
    assert_eq!(value["total_units"], 0);
    assert_eq!(value["limit"], 1000);
    assert!(value["error"].is_string());

    let response = router
        .oneshot(json_request(
            "POST",
            "/api/memories/search",
            json!({"query": "anything"}),
        ))
        .await
        .unwrap();
    assert_eq!(response.status(), StatusCode::SERVICE_UNAVAILABLE);
    let value = body_json(response).await;
    assert_eq!(value["code"], "hindsight_unconfigured");
}

#[tokio::test]
async fn search_validates_its_body() {
    let (api_url, _seen) = start_mock().await;
    let router = build_router(configured_state("validation", &api_url));

    let response = router
        .clone()
        .oneshot(json_request("POST", "/api/memories/search", json!({})))
        .await
        .unwrap();
    assert_eq!(response.status(), StatusCode::BAD_REQUEST);

    let response = router
        .clone()
        .oneshot(json_request(
            "POST",
            "/api/memories/search",
            json!({"query": "q", "mode": "fuzzy"}),
        ))
        .await
        .unwrap();
    assert_eq!(response.status(), StatusCode::BAD_REQUEST);

    let response = router
        .clone()
        .oneshot(json_request(
            "POST",
            "/api/memories/search",
            json!({"query": "q", "type": "bogus"}),
        ))
        .await
        .unwrap();
    assert_eq!(response.status(), StatusCode::BAD_REQUEST);
    let value = body_json(response).await;
    assert_eq!(value["code"], "invalid_fact_type");
}

#[tokio::test]
async fn graph_upstream_error_status_is_forwarded() {
    let (api_url, _seen) = start_mock().await;
    let router = build_router(configured_state_for("graph-error", &api_url, "broken"));

    let response = router
        .oneshot(get_request("/api/memories/graph"))
        .await
        .unwrap();
    assert_eq!(response.status(), StatusCode::INTERNAL_SERVER_ERROR);
    let value = body_json(response).await;
    assert_eq!(value["configured"], true);
    assert_eq!(value["bankId"], "broken");
    assert_eq!(value["error"], "graph exploded");
    assert_eq!(value["code"], "hindsight_unavailable");
}

#[tokio::test]
async fn meaning_search_survives_a_failed_graph_fetch() {
    let (api_url, _seen) = start_mock().await;
    let router = build_router(configured_state_for(
        "meaning-graph-fail",
        &api_url,
        "broken",
    ));

    let response = router
        .oneshot(json_request(
            "POST",
            "/api/memories/search",
            json!({"query": "alice", "mode": "meaning"}),
        ))
        .await
        .unwrap();
    assert_eq!(response.status(), StatusCode::OK);
    let value = body_json(response).await;
    assert_eq!(value["mode"], "meaning");
    assert_eq!(value["items"].as_array().unwrap().len(), 2);
    // Without the graph the nodes are synthesized, and no edges are known.
    assert_eq!(value["nodes"].as_array().unwrap().len(), 2);
    assert_eq!(value["nodes"][0]["data"]["factType"], "observation");
    assert_eq!(value["edges"], json!([]));
}

#[tokio::test]
async fn unreachable_upstream_is_a_bad_gateway() {
    // Bind then drop a listener so the port is guaranteed closed.
    let listener = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
    let addr = listener.local_addr().unwrap();
    drop(listener);
    let router = build_router(configured_state(
        "upstream-down",
        &format!("http://{}", addr),
    ));

    let response = router
        .clone()
        .oneshot(get_request("/api/memories/graph"))
        .await
        .unwrap();
    assert_eq!(response.status(), StatusCode::BAD_GATEWAY);
    let value = body_json(response).await;
    assert_eq!(value["configured"], true);
    assert!(value["error"].is_string());

    let response = router
        .oneshot(json_request(
            "POST",
            "/api/memories/search",
            json!({"query": "alice", "mode": "meaning"}),
        ))
        .await
        .unwrap();
    assert_eq!(response.status(), StatusCode::BAD_GATEWAY);
    let value = body_json(response).await;
    assert_eq!(value["mode"], "meaning");
    assert!(value["error"].is_string());
}
