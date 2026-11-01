//! Unit tests for the Hindsight proxy: config resolution, text scoring, graph
//! enrichment and recall item/edge assembly.

use super::*;
use crate::config::Config;
use serde_json::json;
use std::path::PathBuf;

fn test_config(name: &str) -> Config {
    let root =
        std::env::temp_dir().join(format!("aidesk-memories-{}-{}", name, uuid::Uuid::new_v4()));
    let home = root.join("home");
    let config_root = home.join(".omp");
    let agent_dir = config_root.join("agent");
    for dir in [
        home.clone(),
        agent_dir.clone(),
        agent_dir.join("sessions"),
        agent_dir.join("blobs"),
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

fn write_config(cfg: &Config, source: &str) -> PathBuf {
    let path = cfg.agent_dir.join("config.yml");
    std::fs::write(&path, source).unwrap();
    path
}

fn lookup<'a>(pairs: &'a [(&'a str, &'a str)]) -> impl Fn(&str) -> Option<String> + 'a {
    move |name: &str| {
        pairs
            .iter()
            .find(|(key, _)| *key == name)
            .map(|(_, value)| (*value).to_string())
    }
}

fn id_set(ids: &[&str]) -> HashSet<String> {
    ids.iter().map(|id| (*id).to_string()).collect()
}

/// The `/graph` fixture: three table rows in the upstream shape (entities are a
/// comma-separated string, `"None"` when empty).
fn sample_rows() -> Vec<Value> {
    vec![
        json!({
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
        }),
        json!({
            "id": "b",
            "text": "Bob went hiking in the alps",
            "context": "trip notes",
            "entities": "Bob",
            "tags": [],
            "fact_type": "experience",
            "date": "N/A",
            "mentioned_at": "2024-02-01T09:00:00Z",
            "proof_count": null,
        }),
        json!({
            "id": "c",
            "text": "Quarterly planning meeting",
            "context": "Google calendar sync",
            "entities": "None",
            "tags": ["work"],
            "fact_type": "observation",
            "date": "N/A",
        }),
    ]
}

// ============================================================================
// Config resolution
// ============================================================================

#[test]
fn resolves_target_from_config_file() {
    let cfg = test_config("config");
    write_config(
        &cfg,
        "memory:\n  backend: hindsight\nhindsight:\n  apiUrl: https://hs.example/\n  bankId: chn\n",
    );
    let env = lookup(&[("USER", "alice")]);
    let key = lookup(&[(TOKEN_NAME, "secret")]);
    let target = resolve_target_with(&cfg, &env, &key);
    assert_eq!(target.api_url, "https://hs.example");
    assert_eq!(target.bank_id, "chn");
    assert_eq!(target.api_token.as_deref(), Some("secret"));
    assert!(target.configured);
}

#[test]
fn env_overrides_config_and_trims_trailing_slash() {
    let cfg = test_config("env");
    write_config(
        &cfg,
        "hindsight:\n  apiUrl: https://config.example\n  bankId: chn\n",
    );
    let env = lookup(&[
        ("HINDSIGHT_API_URL", "https://env.example/"),
        ("HINDSIGHT_BANK_ID", "envbank"),
        ("USER", "alice"),
    ]);
    let key = lookup(&[]);
    let target = resolve_target_with(&cfg, &env, &key);
    assert_eq!(target.api_url, "https://env.example");
    assert_eq!(target.bank_id, "envbank");
    assert_eq!(target.api_token, None);
    assert!(target.configured);
}

#[test]
fn defaults_to_the_public_url_and_login_user() {
    let cfg = test_config("defaults");
    let env = lookup(&[("USER", "alice")]);
    let target = resolve_target_with(&cfg, &env, &lookup(&[]));
    assert_eq!(target.api_url, DEFAULT_API_URL);
    assert_eq!(target.bank_id, "alice");
    assert_eq!(target.api_token, None);
    assert!(!target.configured);
}

#[test]
fn bank_id_falls_back_through_login_name_to_default() {
    let cfg = test_config("bank");
    let env = lookup(&[("LOGNAME", "bob")]);
    let target = resolve_target_with(&cfg, &env, &lookup(&[]));
    assert_eq!(target.bank_id, "bob");

    let target = resolve_target_with(&cfg, &lookup(&[]), &lookup(&[]));
    assert_eq!(target.bank_id, DEFAULT_BANK_ID);
}

#[test]
fn hindsight_block_api_key_is_resolved() {
    let cfg = test_config("api-key");
    write_config(
        &cfg,
        "hindsight:\n  apiKey: $(cat /run/secrets/hindsight)\n",
    );
    // The nix wrapper resolver expands `$(cat ...)`; mirror that here.
    let key = lookup(&[("$(cat /run/secrets/hindsight)", "file-secret")]);
    let target = resolve_target_with(&cfg, &lookup(&[]), &key);
    assert_eq!(target.api_token.as_deref(), Some("file-secret"));
    // The block alone is enough to mark memory as configured.
    assert!(target.configured);
}

#[test]
fn memory_backend_marks_configured_without_token() {
    let cfg = test_config("backend");
    write_config(&cfg, "memory:\n  backend: hindsight\n");
    let target = resolve_target_with(&cfg, &lookup(&[]), &lookup(&[]));
    assert!(target.configured);
    assert_eq!(target.api_url, DEFAULT_API_URL);
}

// ============================================================================
// URLs
// ============================================================================

#[test]
fn graph_url_encodes_query_and_optional_filters() {
    let target = HindsightTarget {
        api_url: "https://hs.example".into(),
        bank_id: "my bank".into(),
        api_token: None,
        configured: true,
    };
    let url = graph_url(&target, 25, Some("world"), Some("a b&c"));
    assert_eq!(
        url,
        "https://hs.example/v1/default/banks/my%20bank/graph?limit=25&type=world&q=a%20b%26c"
    );
    let url = graph_url(&target, 10, None, None);
    assert_eq!(
        url,
        "https://hs.example/v1/default/banks/my%20bank/graph?limit=10"
    );
}

// ============================================================================
// Text search
// ============================================================================

#[test]
fn text_search_ranks_text_hits_above_context_hits() {
    let rows = sample_rows();
    let items = text_search_items(&rows, "google", 100);
    let ids: Vec<&str> = items
        .iter()
        .filter_map(|item| item.get("id").and_then(Value::as_str))
        .collect();
    // "bob … alps" has no "google" anywhere and is dropped.
    assert_eq!(ids, vec!["a", "c"]);

    let first = items[0]["score"].as_f64().unwrap();
    let second = items[1]["score"].as_f64().unwrap();
    assert!(first > second);
    assert!(second > 0.55);
    assert!(first <= 1.0);
    // A text hit sits in the text band (0.76..=0.99).
    assert!(first >= 0.76);
    // A context hit sits in the context band (0.55..0.65).
    assert!(second >= 0.55 && second < 0.66);
}

#[test]
fn text_search_is_case_insensitive_and_normalizes_entities() {
    let rows = sample_rows();
    let items = text_search_items(&rows, "ALICE", 100);
    assert_eq!(items[0]["id"], "a");
    assert_eq!(items[0]["entities"], json!(["Alice", "Google"]));
    assert_eq!(items[0]["tags"], json!(["user_a"]));
    assert_eq!(items[0]["fact_type"], "world");
    assert_eq!(items[0]["context"], "work info");
    assert_eq!(items[0]["occurred_start"], "2024-01-15T10:30:00Z");
    assert_eq!(items[0]["document_id"], "doc-1");
    assert_eq!(items[0]["chunk_id"], "chunk-1");
    assert_eq!(items[0]["proof_count"], 2);
}

#[test]
fn text_search_handles_placeholder_entities_and_dates() {
    let rows = sample_rows();
    let items = text_search_items(&rows, "quarterly", 100);
    assert_eq!(items.len(), 1);
    assert_eq!(items[0]["id"], "c");
    assert_eq!(items[0]["entities"], json!([]));
    assert_eq!(items[0]["date"], "");
}

#[test]
fn text_search_scores_token_overlap_below_substring_hits() {
    let rows = sample_rows();
    let items = text_search_items(&rows, "hiking alps trail", 100);
    assert_eq!(items.len(), 1);
    let score = items[0]["score"].as_f64().unwrap();
    assert!(score >= 0.30 && score < 0.55, "unexpected score {}", score);
}

#[test]
fn text_search_drops_everything_for_an_unknown_query() {
    let rows = sample_rows();
    assert!(text_search_items(&rows, "zzzz", 100).is_empty());
}

#[test]
fn text_search_respects_the_limit() {
    let rows = sample_rows();
    let items = text_search_items(&rows, "google", 1);
    assert_eq!(items.len(), 1);
    assert_eq!(items[0]["id"], "a");
}

#[test]
fn entity_and_tag_matches_land_in_the_name_band() {
    let row = json!({
        "id": "x",
        "text": "unrelated prose",
        "context": "otherwise empty",
        "entities": "Alice, Google",
        "tags": ["user_a"],
    });
    let score = text_match_score(&row, "google", &tokenize("google")).unwrap();
    assert!(score >= NAME_TIER && score < NAME_TIER + NAME_TIER_SPAN + 1e-9);
    let tag_score = text_match_score(&row, "user_a", &tokenize("user_a")).unwrap();
    assert!(tag_score >= NAME_TIER && tag_score < NAME_TIER + NAME_TIER_SPAN + 1e-9);
}

// ============================================================================
// Graph enrichment / filtering
// ============================================================================

#[test]
fn enrich_nodes_copies_fact_type_and_tags() {
    let mut nodes = vec![
        json!({"data": {"id": "a", "label": "Alice works at Google"}}),
        json!({"data": {"id": "b", "label": "Bob went hiking"}}),
        json!({"data": {"id": "zzz", "label": "not in the table"}}),
    ];
    let rows = sample_rows();
    enrich_nodes(&mut nodes, &rows);
    assert_eq!(nodes[0]["data"]["factType"], "world");
    assert_eq!(nodes[0]["data"]["tags"], json!(["user_a"]));
    assert_eq!(nodes[1]["data"]["factType"], "experience");
    assert_eq!(nodes[1]["data"]["tags"], json!([]));
    assert!(nodes[2]["data"].get("factType").is_none());
    assert!(nodes[2]["data"].get("tags").is_none());
}

#[test]
fn filter_graph_keeps_only_selected_nodes_and_inner_edges() {
    let nodes = vec![
        json!({"data": {"id": "a"}}),
        json!({"data": {"id": "b"}}),
        json!({"data": {"id": "c"}}),
    ];
    let edges = vec![
        json!({"data": {"id": "a-b-semantic", "source": "a", "target": "b"}}),
        json!({"data": {"id": "a-c-semantic", "source": "a", "target": "c"}}),
        json!({"data": {"id": "b-c-semantic", "source": "b", "target": "c"}}),
    ];
    let (nodes, edges) = filter_graph(&nodes, &edges, &id_set(&["a", "b"]));
    assert_eq!(nodes.len(), 2);
    assert_eq!(edges.len(), 1);
    assert_eq!(edges[0]["data"]["id"], "a-b-semantic");
}

// ============================================================================
// Recall items and scores
// ============================================================================

#[test]
fn recall_score_prefers_pipeline_scores() {
    let result = json!({"id": "x", "scores": {"final": 0.42}});
    assert!((recall_result_score(&result, 1, &HashMap::new()) - 0.42).abs() < 1e-12);

    let result = json!({"id": "x", "weight": 0.5, "score": 0.6});
    assert!((recall_result_score(&result, 1, &HashMap::new()) - 0.5).abs() < 1e-12);

    let result = json!({"id": "x", "scores": {"final": 3.2}});
    assert_eq!(recall_result_score(&result, 1, &HashMap::new()), 1.0);
}

#[test]
fn recall_score_uses_trace_visit_weights() {
    let recall = json!({
        "results": [{"id": "x"}],
        "trace": {
            "visits": [
                {"node_id": "x", "weights": {"final_weight": 0.77, "activation": 0.2}},
                {"node_id": "y", "weights": {"activation": 0.35}},
            ]
        },
    });
    let visits = trace_visit_weights(&recall);
    let result = json!({"id": "x"});
    assert!((recall_result_score(&result, 3, &visits) - 0.77).abs() < 1e-12);
    assert!((recall_result_score(&json!({"id": "y"}), 3, &visits) - 0.35).abs() < 1e-12);
}

#[test]
fn recall_score_falls_back_to_rank_decay() {
    let result = json!({"id": "x"});
    let score = recall_result_score(&result, 2, &HashMap::new());
    assert!((score - 1.0 / (1.0 + 0.08 * 2.0)).abs() < 1e-12);
    assert!(score > 0.0 && score <= 1.0);
}

#[test]
fn recall_items_normalize_entities_and_merge_graph_rows() {
    let recall = json!({
        "results": [
            {
                "id": "low",
                "text": "low relevance fact",
                "type": "world",
                "entities": ["Alice"],
                "context": "work",
                "occurred_start": "2024-01-15T10:30:00Z",
                "mentioned_at": "2024-01-15T10:30:00Z",
                "document_id": "doc-1",
                "chunk_id": "chunk-1",
                "tags": ["user_a"],
                "scores": {"final": 0.2},
                "source_fact_ids": ["src"],
            },
            {
                "id": "high",
                "text": "high relevance fact",
                "type": "observation",
                "entities": null,
                "scores": {"final": 0.9},
            },
        ]
    });
    let rows = vec![json!({
        "id": "high",
        "text": "high relevance fact",
        "context": "N/A",
        "entities": "Carol, Dave",
        "tags": ["work"],
        "fact_type": "observation",
        "proof_count": 4,
    })];
    let items = recall_items(&recall, &rows_by_id(&rows), 100);
    assert_eq!(items.len(), 2);
    assert_eq!(items[0]["id"], "high");
    assert_eq!(items[0]["fact_type"], "observation");
    assert_eq!(items[0]["entities"], json!(["Carol", "Dave"]));
    assert_eq!(items[0]["tags"], json!(["work"]));
    assert_eq!(items[0]["proof_count"], 4);
    assert_eq!(items[0]["context"], "");
    assert!((items[0]["score"].as_f64().unwrap() - 0.9).abs() < 1e-12);

    assert_eq!(items[1]["id"], "low");
    assert_eq!(items[1]["entities"], json!(["Alice"]));
    assert_eq!(items[1]["proof_count"], 1);
    assert_eq!(items[1]["source_fact_ids"], json!(["src"]));
    // No matching table row: the occurred/mentioned timestamps become the date.
    assert_eq!(items[1]["date"], "2024-01-15T10:30:00Z");
}

// ============================================================================
// Recalled graph
// ============================================================================

#[test]
fn synthesized_nodes_keep_the_graph_shape() {
    let item = json!({
        "id": "unit-1",
        "text": "Alice works at Google on a very long project indeed",
        "context": "work info",
        "fact_type": "world",
        "entities": ["Alice", "Google"],
        "tags": ["user_a"],
        "date": "2024-01-15T10:30:00Z",
    });
    let node = synthesize_node(&item);
    assert_eq!(node["data"]["id"], "unit-1");
    assert_eq!(node["data"]["factType"], "world");
    assert_eq!(node["data"]["tags"], json!(["user_a"]));
    assert_eq!(node["data"]["entities"], "Alice, Google");
    assert_eq!(node["data"]["color"], "#42a5f5");
    let label = node["data"]["label"].as_str().unwrap();
    assert!(label.ends_with("..."));
    assert_eq!(label.chars().count(), 33);

    let empty = synthesize_node(&json!({"id": "u2", "text": "short", "entities": []}));
    assert_eq!(empty["data"]["entities"], "None");
    assert_eq!(empty["data"]["color"], "#e0e0e0");
    assert_eq!(empty["data"]["label"], "short");
}

#[test]
fn recalled_nodes_prefer_real_graph_nodes() {
    let items = vec![
        json!({"id": "a", "text": "graph node", "fact_type": "world", "tags": ["t"]}),
        json!({"id": "b", "text": "synthesized node", "fact_type": "experience"}),
    ];
    let mut graph_node_index = HashMap::new();
    graph_node_index.insert(
        "a".to_string(),
        json!({"data": {"id": "a", "label": "graph node", "text": "graph node", "color": "#90caf9"}}),
    );
    let nodes = recalled_nodes(&items, &graph_node_index);
    assert_eq!(nodes.len(), 2);
    assert_eq!(nodes[0]["data"]["color"], "#90caf9");
    assert_eq!(nodes[0]["data"]["factType"], "world");
    assert_eq!(nodes[0]["data"]["tags"], json!(["t"]));
    assert_eq!(nodes[1]["data"]["factType"], "experience");
}

#[test]
fn recalled_edges_merge_graph_entities_and_source_facts() {
    let items = vec![
        json!({
            "id": "a",
            "entities": ["Alice", "Google"],
            "fact_type": "world",
            "source_fact_ids": ["d"],
        }),
        json!({"id": "b", "entities": ["Google"], "fact_type": "world"}),
        json!({"id": "c", "entities": ["Alice"], "fact_type": "world"}),
        json!({"id": "d", "entities": ["Bob"], "fact_type": "world"}),
    ];
    let graph_edges = vec![
        json!({"data": {"id": "a-b-semantic", "source": "a", "target": "b", "linkType": "semantic"}}),
        json!({"data": {"id": "a-zzz-semantic", "source": "a", "target": "zzz", "linkType": "semantic"}}),
    ];
    let ids = id_set(&["a", "b", "c", "d"]);
    let edges = recalled_edges(&items, &graph_edges, &ids);

    let mut pairs: HashSet<(String, String)> = HashSet::new();
    let mut link_types: HashSet<String> = HashSet::new();
    for edge in &edges {
        let (source, target) = edge_endpoints(edge).unwrap();
        assert!(ids.contains(source) && ids.contains(target));
        assert!(
            pairs.insert(pair_key(source, target)),
            "duplicate edge {} -> {}",
            source,
            target
        );
        link_types.insert(edge["data"]["linkType"].as_str().unwrap().to_string());
    }
    assert!(link_types.contains("semantic"));
    assert!(link_types.contains("entity"));
    assert!(link_types.contains("source_fact"));
    // a-b is already connected by the graph edge, so no entity edge duplicates it.
    assert!(!edges.iter().any(|edge| {
        let data = &edge["data"];
        data["linkType"] == "entity"
            && data["entityName"] == "Google"
            && (data["source"] == "b" && data["target"] == "a")
    }));
    assert!(edges.iter().any(|edge| {
        let data = &edge["data"];
        data["linkType"] == "source_fact" && data["source"] == "d" && data["target"] == "a"
    }));
}

// ============================================================================
// Parameter parsing
// ============================================================================

#[test]
fn limit_parsing_clamps_to_the_allowed_range() {
    assert_eq!(parse_limit(None, 1000, 2000), 1000);
    assert_eq!(parse_limit(Some("50"), 1000, 2000), 50);
    assert_eq!(parse_limit(Some("99999"), 1000, 2000), 2000);
    assert_eq!(parse_limit(Some("0"), 1000, 2000), 1);
    assert_eq!(parse_limit(Some("nope"), 1000, 2000), 1000);
    assert_eq!(parse_body_limit(Some(&json!(250)), 100, 1000), Ok(250));
    assert_eq!(parse_body_limit(Some(&json!(0)), 100, 1000), Ok(1));
    assert_eq!(parse_body_limit(Some(&json!("250")), 100, 1000), Err(()));
    assert_eq!(parse_body_limit(None, 100, 1000), Ok(100));
}

#[test]
fn fact_type_parsing_accepts_only_known_types() {
    assert_eq!(parse_fact_type(None), Ok(None));
    assert_eq!(parse_fact_type(Some(" ")), Ok(None));
    assert_eq!(
        parse_fact_type(Some("world")),
        Ok(Some("world".to_string()))
    );
    assert_eq!(parse_fact_type(Some("bogus")), Err(()));
    assert_eq!(
        parse_fact_type_value(Some(&json!("observation"))),
        Ok(Some("observation".to_string()))
    );
    assert_eq!(parse_fact_type_value(Some(&json!(3))), Err(()));
}

#[test]
fn upstream_error_messages_are_extracted() {
    assert_eq!(
        upstream_message(r#"{"detail": "Memory unit 'x' not found"}"#),
        Some("Memory unit 'x' not found".to_string())
    );
    assert_eq!(
        upstream_message(r#"{"detail": [{"msg": "query must be non-empty"}]}"#),
        Some("query must be non-empty".to_string())
    );
    assert_eq!(
        upstream_message(r#"{"error": {"message": "boom"}}"#),
        Some("boom".to_string())
    );
    assert_eq!(
        upstream_message("plain text"),
        Some("plain text".to_string())
    );
    assert_eq!(upstream_message("   "), None);
}

#[test]
fn trailing_slash_is_trimmed_from_the_env_url_only_once() {
    let cfg = test_config("slash");
    let env = lookup(&[("HINDSIGHT_API_URL", "https://hs.example///")]);
    let target = resolve_target_with(&cfg, &env, &lookup(&[]));
    // trim_end_matches removes every trailing slash; the URL stays usable.
    assert_eq!(target.api_url, "https://hs.example");
}

#[test]
fn config_path_prefers_existing_yaml_variant() {
    // `settings_path()` is what the resolver reads; make sure a config.yaml-only
    // install still resolves.
    let cfg = test_config("yaml");
    std::fs::write(
        cfg.agent_dir.join("config.yaml"),
        "hindsight:\n  bankId: from-yaml\n",
    )
    .unwrap();
    let target = resolve_target_with(&cfg, &lookup(&[]), &lookup(&[]));
    assert_eq!(target.bank_id, "from-yaml");
}

// ============================================================================
// Unconfigured responses
// ============================================================================

fn unconfigured_target() -> HindsightTarget {
    HindsightTarget {
        api_url: DEFAULT_API_URL.to_string(),
        bank_id: DEFAULT_BANK_ID.to_string(),
        api_token: None,
        configured: false,
    }
}

#[test]
fn unconfigured_graph_has_the_setup_hint_shape() {
    let value = unconfigured_graph(&unconfigured_target(), 250);
    assert_eq!(value["configured"], false);
    assert_eq!(value["bankId"], DEFAULT_BANK_ID);
    assert_eq!(value["nodes"], json!([]));
    assert_eq!(value["edges"], json!([]));
    assert_eq!(value["table_rows"], json!([]));
    assert_eq!(value["total_units"], 0);
    assert_eq!(value["limit"], 250);
    assert_eq!(value["code"], "hindsight_unconfigured");
    assert_eq!(value["error"], "Hindsight is not configured");
}

#[tokio::test]
async fn unavailable_response_is_a_service_unavailable_error() {
    let response = unavailable(&unconfigured_target());
    assert_eq!(response.status(), StatusCode::SERVICE_UNAVAILABLE);
    let bytes = axum::body::to_bytes(response.into_body(), 64 * 1024)
        .await
        .unwrap();
    let value: Value = serde_json::from_slice(&bytes).unwrap();
    assert_eq!(value["configured"], false);
    assert_eq!(value["code"], "hindsight_unconfigured");
    assert_eq!(value["bankId"], DEFAULT_BANK_ID);
    assert_eq!(value["error"], "Hindsight is not configured");
}
