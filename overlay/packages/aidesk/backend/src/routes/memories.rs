//! `/api/memories` — Hindsight memory proxy (graph, search, read and curate).
//!
//! The frontend never talks to Hindsight directly: the bank and the API token
//! live in the user's omp config (`~/.omp/agent/config.yml`) and in the nix
//! `omp` wrapper script, both of which only the backend can read. These routes
//! resolve that target once per request and forward to the upstream memory API.

use crate::config::Config;
use crate::routes::{body_json, json_ok, query};
use crate::state::SharedState;
use crate::util::{coded_error, json_status};
use axum::extract::{Path as AxumPath, Request, State};
use axum::http::{StatusCode, Uri};
use axum::response::Response;
use percent_encoding::{utf8_percent_encode, NON_ALPHANUMERIC};
use serde_json::{json, Map, Value};
use std::collections::{HashMap, HashSet};
use std::time::Duration;

pub const DEFAULT_API_URL: &str = "https://hindsight.chn.moe";
pub const DEFAULT_BANK_ID: &str = "default";
const DEFAULT_GRAPH_LIMIT: u32 = 1000;
const MAX_GRAPH_LIMIT: u32 = 2000;
const DEFAULT_SEARCH_LIMIT: u32 = 100;
const MAX_SEARCH_LIMIT: u32 = 1000;
const MAX_SEARCH_BODY_BYTES: usize = 256 * 1024;
const MAX_PATCH_BODY_BYTES: usize = 1024 * 1024;
const UPSTREAM_TIMEOUT: Duration = Duration::from_secs(60);
/// Synthetic edges are only a supplement to the real graph; cap them so a
/// recalled set of a hundred units cannot produce a quadratic edge list.
const MAX_SYNTHETIC_EDGES: usize = 1000;
const TOKEN_NAME: &str = "HINDSIGHT_API_TOKEN";

// ============================================================================
// Config resolution
// ============================================================================

/// The Hindsight endpoint a request should talk to, plus whether the user has
/// actually configured memory at all (drives the `configured` flag the UI uses
/// to show a setup hint instead of an error).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct HindsightTarget {
    pub api_url: String,
    pub bank_id: String,
    pub api_token: Option<String>,
    pub configured: bool,
}

fn non_empty(value: Option<&str>) -> Option<String> {
    let value = value?.trim();
    (!value.is_empty()).then(|| value.to_string())
}

fn env_non_empty(name: &str) -> Option<String> {
    non_empty(std::env::var(name).ok().as_deref())
}

/// Resolve the connection target for the current user.
pub fn resolve_target(cfg: &Config) -> HindsightTarget {
    resolve_target_with(cfg, &env_non_empty, &|spec| {
        crate::omp::usage::resolve_api_key(cfg, spec)
    })
}

/// Resolution with injectable environment/key lookups so it is testable
/// without mutating the process environment.
fn resolve_target_with(
    cfg: &Config,
    env_lookup: &dyn Fn(&str) -> Option<String>,
    key_lookup: &dyn Fn(&str) -> Option<String>,
) -> HindsightTarget {
    let document =
        crate::omp::settings::parse_yaml_mapping(&cfg.settings_path()).unwrap_or_default();
    let hindsight = document.get("hindsight").and_then(Value::as_object);
    let field = |name: &str| -> Option<String> {
        non_empty(
            hindsight
                .and_then(|map| map.get(name))
                .and_then(Value::as_str),
        )
    };

    let api_url = non_empty(env_lookup("HINDSIGHT_API_URL").as_deref())
        .or_else(|| field("apiUrl"))
        .map(|url| url.trim_end_matches('/').to_string())
        .filter(|url| !url.is_empty())
        .unwrap_or_else(|| DEFAULT_API_URL.to_string());

    let bank_id = non_empty(env_lookup("HINDSIGHT_BANK_ID").as_deref())
        .or_else(|| field("bankId"))
        .or_else(|| non_empty(env_lookup("USER").as_deref()))
        .or_else(|| non_empty(env_lookup("LOGNAME").as_deref()))
        .unwrap_or_else(|| DEFAULT_BANK_ID.to_string());

    let api_token = non_empty(key_lookup(TOKEN_NAME).as_deref()).or_else(|| {
        ["apiKey", "apiToken"].iter().find_map(|name| {
            let spec = field(name)?;
            non_empty(key_lookup(&spec).as_deref())
        })
    });

    let env_url = non_empty(env_lookup("HINDSIGHT_API_URL").as_deref());
    let backend_is_hindsight = document
        .get("memory")
        .and_then(Value::as_object)
        .and_then(|memory| memory.get("backend"))
        .and_then(Value::as_str)
        .map(|backend| backend.trim() == "hindsight")
        .unwrap_or(false);
    let has_block = hindsight.map(|map| !map.is_empty()).unwrap_or(false);
    let configured = backend_is_hindsight || has_block || env_url.is_some() || api_token.is_some();

    HindsightTarget {
        api_url,
        bank_id,
        api_token,
        configured,
    }
}

// ============================================================================
// Upstream transport
// ============================================================================

struct UpstreamFailure {
    status: StatusCode,
    message: String,
}

impl UpstreamFailure {
    fn unavailable(message: impl Into<String>) -> Self {
        Self {
            status: StatusCode::BAD_GATEWAY,
            message: message.into(),
        }
    }

    fn redacting(mut self, target: &HindsightTarget) -> Self {
        if let Some(token) = target
            .api_token
            .as_deref()
            .filter(|token| !token.is_empty())
        {
            self.message = self.message.replace(token, "[REDACTED]");
        }
        self
    }
}

fn encoded(value: &str) -> String {
    utf8_percent_encode(value, NON_ALPHANUMERIC).to_string()
}

fn graph_url(
    target: &HindsightTarget,
    limit: u32,
    fact_type: Option<&str>,
    q: Option<&str>,
) -> String {
    let mut url = format!(
        "{}/v1/default/banks/{}/graph?limit={}",
        target.api_url,
        encoded(&target.bank_id),
        limit
    );
    if let Some(fact_type) = fact_type.filter(|value| !value.is_empty()) {
        url.push_str("&type=");
        url.push_str(&encoded(fact_type));
    }
    if let Some(q) = q.filter(|value| !value.is_empty()) {
        url.push_str("&q=");
        url.push_str(&encoded(q));
    }
    url
}

fn memory_url(target: &HindsightTarget, id: &str) -> String {
    format!(
        "{}/v1/default/banks/{}/memories/{}",
        target.api_url,
        encoded(&target.bank_id),
        encoded(id)
    )
}

fn recall_url(target: &HindsightTarget) -> String {
    format!(
        "{}/v1/default/banks/{}/memories/recall",
        target.api_url,
        encoded(&target.bank_id)
    )
}

fn authorized(
    builder: reqwest::RequestBuilder,
    target: &HindsightTarget,
) -> reqwest::RequestBuilder {
    match target.api_token.as_deref() {
        Some(token) if !token.is_empty() => builder.bearer_auth(token),
        _ => builder,
    }
}

fn client() -> Result<reqwest::Client, UpstreamFailure> {
    reqwest::Client::builder()
        .timeout(UPSTREAM_TIMEOUT)
        .build()
        .map_err(|error| UpstreamFailure {
            status: StatusCode::INTERNAL_SERVER_ERROR,
            message: error.to_string(),
        })
}

/// A short, human-readable message out of an upstream error body. FastAPI
/// reports `{"detail": ...}`; Hindsight's own handlers use `{"error": ...}`.
fn upstream_message(raw: &str) -> Option<String> {
    let parsed: Option<Value> = serde_json::from_str(raw).ok();
    if let Some(value) = parsed {
        for key in ["detail", "error", "message"] {
            match value.get(key) {
                Some(Value::String(text)) if !text.trim().is_empty() => {
                    return Some(text.trim().chars().take(500).collect())
                }
                Some(Value::Array(items)) => {
                    // FastAPI validation errors are a list of `{msg, loc}` objects.
                    let messages: Vec<String> = items
                        .iter()
                        .filter_map(|item| {
                            item.get("msg")
                                .and_then(Value::as_str)
                                .or_else(|| item.as_str())
                        })
                        .map(|text| text.trim().to_string())
                        .filter(|text| !text.is_empty())
                        .collect();
                    if !messages.is_empty() {
                        return Some(messages.join("; ").chars().take(500).collect());
                    }
                }
                Some(Value::Object(object)) => {
                    if let Some(text) = object.get("message").and_then(Value::as_str) {
                        if !text.trim().is_empty() {
                            return Some(text.trim().chars().take(500).collect());
                        }
                    }
                }
                _ => {}
            }
        }
    }
    let trimmed = raw.trim();
    (!trimmed.is_empty()).then(|| trimmed.chars().take(500).collect())
}

async fn send_json(request: reqwest::RequestBuilder) -> Result<Value, UpstreamFailure> {
    let response = request.send().await.map_err(|error| {
        if error.is_timeout() {
            UpstreamFailure::unavailable("Hindsight request timed out")
        } else {
            UpstreamFailure::unavailable(error.to_string())
        }
    })?;
    let status = response.status();
    let raw = response.text().await.map_err(|error| {
        UpstreamFailure::unavailable(format!("Failed to read Hindsight response: {}", error))
    })?;
    if !status.is_success() {
        let code = StatusCode::from_u16(status.as_u16()).unwrap_or(StatusCode::BAD_GATEWAY);
        return Err(UpstreamFailure {
            status: code,
            message: upstream_message(&raw)
                .unwrap_or_else(|| format!("Hindsight returned {}", status)),
        });
    }
    serde_json::from_str::<Value>(&raw).map_err(|error| {
        UpstreamFailure::unavailable(format!("Hindsight returned invalid JSON: {}", error))
    })
}

async fn fetch_graph(
    target: &HindsightTarget,
    limit: u32,
    fact_type: Option<&str>,
    q: Option<&str>,
) -> Result<Value, UpstreamFailure> {
    let request = client()?
        .get(graph_url(target, limit, fact_type, q))
        .header(reqwest::header::ACCEPT, "application/json");
    send_json(authorized(request, target))
        .await
        .map_err(|failure| failure.redacting(target))
}

async fn fetch_recall(
    target: &HindsightTarget,
    query_text: &str,
    fact_type: Option<&str>,
) -> Result<Value, UpstreamFailure> {
    let body = json!({
        "query": query_text,
        "types": match fact_type {
            Some(fact_type) => json!([fact_type]),
            None => json!(["world", "experience", "observation"]),
        },
        "budget": "mid",
        "max_tokens": 4096,
        "trace": true,
        "include": {
            "entities": { "max_tokens": 500 },
            "source_facts": { "max_tokens": 2000 },
        },
    });
    let request = client()?
        .post(recall_url(target))
        .header(reqwest::header::ACCEPT, "application/json")
        .json(&body);
    send_json(authorized(request, target))
        .await
        .map_err(|failure| failure.redacting(target))
}

// ============================================================================
// Field normalization
// ============================================================================

fn str_field<'a>(value: &'a Value, name: &str) -> &'a str {
    value.get(name).and_then(Value::as_str).unwrap_or("")
}

/// `table_rows` writes `"N/A"` where memory has no context/date; the API
/// surface uses the empty string instead so the frontend never renders it.
fn display_text(value: &Value, name: &str) -> String {
    let text = str_field(value, name);
    if text.trim() == "N/A" {
        String::new()
    } else {
        text.to_string()
    }
}

/// `null` for a value the frontend should treat as absent, `""` for the empty
/// string Hindsight uses for "no context".
fn optional_string(value: &Value, name: &str) -> Value {
    match value.get(name) {
        Some(Value::String(text)) if !text.trim().is_empty() => {
            if text.trim() == "N/A" {
                Value::String(String::new())
            } else {
                Value::String(text.clone())
            }
        }
        _ => Value::Null,
    }
}

fn is_placeholder(value: &str) -> bool {
    let value = value.trim();
    value.is_empty() || value.eq_ignore_ascii_case("none") || value == "N/A"
}

fn push_name(out: &mut Vec<String>, value: &str) {
    let value = value.trim();
    if !is_placeholder(value) && !out.iter().any(|item| item == value) {
        out.push(value.to_string());
    }
}

/// `/graph` reports entities as `"a, b"` (or `"None"`), `/memories/recall` as
/// a list. Normalize both to a list of names.
fn names_from(value: Option<&Value>) -> Vec<String> {
    let mut out = Vec::new();
    match value {
        Some(Value::Array(items)) => {
            for item in items {
                if let Some(name) = item.as_str() {
                    push_name(&mut out, name);
                }
            }
        }
        Some(Value::String(text)) => {
            for part in text.split(',') {
                push_name(&mut out, part);
            }
        }
        _ => {}
    }
    out
}

fn entities_from(value: &Value) -> Vec<String> {
    names_from(value.get("entities"))
}

fn tags_from(value: &Value) -> Vec<String> {
    names_from(value.get("tags"))
}

fn json_strings(names: &[String]) -> Value {
    Value::Array(names.iter().cloned().map(Value::String).collect())
}

fn json_array(value: Option<&Value>) -> Vec<Value> {
    value.and_then(Value::as_array).cloned().unwrap_or_default()
}

fn graph_nodes(graph: &Value) -> Vec<Value> {
    json_array(graph.get("nodes"))
}

fn graph_edges(graph: &Value) -> Vec<Value> {
    json_array(graph.get("edges"))
}

fn graph_rows(graph: &Value) -> Vec<Value> {
    json_array(graph.get("table_rows"))
}

fn node_id(node: &Value) -> Option<&str> {
    node.get("data")?.get("id")?.as_str()
}

fn edge_endpoints(edge: &Value) -> Option<(&str, &str)> {
    let data = edge.get("data")?;
    Some((data.get("source")?.as_str()?, data.get("target")?.as_str()?))
}

// ============================================================================
// Text scoring
// ============================================================================

/// Base-score bands. They are deliberately disjoint: a text hit always outranks
/// an entity/tag hit, which outranks a context hit, which outranks a bare token
/// overlap. The recency tie-breaker (below) is smaller than the narrowest gap so
/// it can only order results inside a band.
const TEXT_TIER: f64 = 0.76;
const TEXT_TIER_SPAN: f64 = 0.23;
const NAME_TIER: f64 = 0.66;
const NAME_TIER_SPAN: f64 = 0.09;
const CONTEXT_TIER: f64 = 0.55;
const CONTEXT_TIER_SPAN: f64 = 0.10;
const TOKEN_TIER: f64 = 0.30;
const TOKEN_TIER_SPAN: f64 = 0.24;
const RECENCY_WEIGHT: f64 = 1e-3;

fn tokenize(text: &str) -> Vec<String> {
    text.split(|c: char| !c.is_alphanumeric())
        .filter(|token| !token.is_empty())
        .map(|token| token.to_lowercase())
        .collect()
}

/// `1.0` when the needle opens the haystack, decaying with its position.
fn substring_quality(haystack: &str, needle_lower: &str) -> Option<f64> {
    if needle_lower.is_empty() || haystack.is_empty() {
        return None;
    }
    let haystack_lower = haystack.to_lowercase();
    let byte_pos = haystack_lower.find(needle_lower)?;
    let total = haystack_lower.chars().count().max(1) as f64;
    let at = haystack_lower[..byte_pos].chars().count() as f64;
    Some((1.0 - at / total).clamp(0.0, 1.0))
}

fn token_overlap_ratio(query_tokens: &[String], searchable: &str) -> f64 {
    if query_tokens.is_empty() {
        return 0.0;
    }
    let haystack: HashSet<String> = tokenize(searchable).into_iter().collect();
    let matched = query_tokens
        .iter()
        .filter(|token| haystack.contains(token.as_str()))
        .count();
    matched as f64 / query_tokens.len() as f64
}

/// How well a `/graph` `table_rows` entry matches the query, in `(0.0, 1.0]`.
/// `None` means no signal at all (no substring and no shared token).
fn text_match_score(row: &Value, query_text: &str, query_tokens: &[String]) -> Option<f64> {
    let needle = query_text.trim().to_lowercase();
    if needle.is_empty() {
        return None;
    }
    let text = str_field(row, "text");
    let context = str_field(row, "context");
    let entities = entities_from(row);
    let tags = tags_from(row);

    let mut best: Option<f64> = None;
    let mut consider = |score: f64| {
        best = Some(best.map_or(score, |current: f64| current.max(score)));
    };

    if let Some(quality) = substring_quality(text, &needle) {
        consider(TEXT_TIER + TEXT_TIER_SPAN * quality);
    }
    let names = [entities.as_slice(), tags.as_slice()].concat();
    if let Some(quality) = substring_quality(&names.join(", "), &needle) {
        consider(NAME_TIER + NAME_TIER_SPAN * quality);
    }
    if let Some(quality) = substring_quality(context, &needle) {
        consider(CONTEXT_TIER + CONTEXT_TIER_SPAN * quality);
    }

    let searchable = format!("{} {} {}", text, names.join(" "), context);
    let overlap = token_overlap_ratio(query_tokens, &searchable);
    if overlap > 0.0 {
        consider(TOKEN_TIER + TOKEN_TIER_SPAN * overlap);
    }

    best
}

/// Order rows already returned by `/graph`: earlier rows are the most recent
/// (`mentioned_at DESC` upstream), so they win ties inside the same band.
fn with_recency(base: f64, index: usize, total: usize) -> f64 {
    let rank = if total <= 1 {
        1.0
    } else {
        1.0 - index as f64 / total as f64
    };
    (base + RECENCY_WEIGHT * rank).clamp(1e-9, 1.0)
}

// ============================================================================
// Items
// ============================================================================

fn item_from_row(row: &Value) -> Option<Value> {
    let id = row.get("id").and_then(Value::as_str)?.trim().to_string();
    if id.is_empty() {
        return None;
    }
    let entities = entities_from(row);
    let tags = tags_from(row);
    let mut item = Map::new();
    item.insert("id".into(), Value::String(id));
    item.insert(
        "text".into(),
        Value::String(str_field(row, "text").to_string()),
    );
    item.insert(
        "context".into(),
        Value::String(display_text(row, "context")),
    );
    item.insert(
        "fact_type".into(),
        Value::String(str_field(row, "fact_type").to_string()),
    );
    item.insert("entities".into(), json_strings(&entities));
    item.insert("tags".into(), json_strings(&tags));
    item.insert("date".into(), Value::String(display_text(row, "date")));
    item.insert(
        "occurred_start".into(),
        optional_string(row, "occurred_start"),
    );
    item.insert("occurred_end".into(), optional_string(row, "occurred_end"));
    item.insert("mentioned_at".into(), optional_string(row, "mentioned_at"));
    item.insert("document_id".into(), optional_string(row, "document_id"));
    item.insert("chunk_id".into(), optional_string(row, "chunk_id"));
    item.insert(
        "proof_count".into(),
        row.get("proof_count").cloned().unwrap_or(Value::Null),
    );
    Some(Value::Object(item))
}

/// A recall result (plus any matching `/graph` table row) in the items shape.
fn item_from_recall(result: &Value, row: Option<&Value>) -> Option<Value> {
    let id = result.get("id").and_then(Value::as_str)?.trim().to_string();
    if id.is_empty() {
        return None;
    }
    let row_entities = row.map(entities_from).unwrap_or_default();
    let row_tags = row.map(tags_from).unwrap_or_default();
    let recall_entities = entities_from(result);
    let recall_tags = tags_from(result);
    let entities = if recall_entities.is_empty() {
        row_entities
    } else {
        recall_entities
    };
    let tags = if recall_tags.is_empty() {
        row_tags
    } else {
        recall_tags
    };

    let text = match non_empty(result.get("text").and_then(Value::as_str)) {
        Some(text) => text,
        None => row
            .map(|row| str_field(row, "text").to_string())
            .unwrap_or_default(),
    };
    let context = match non_empty(result.get("context").and_then(Value::as_str)) {
        Some(context) => context,
        None => row
            .map(|row| display_text(row, "context"))
            .unwrap_or_default(),
    };
    let fact_type = match non_empty(result.get("type").and_then(Value::as_str)) {
        Some(fact_type) => fact_type,
        None => row
            .map(|row| str_field(row, "fact_type").to_string())
            .unwrap_or_default(),
    };
    let occurred_start = result.get("occurred_start").cloned().unwrap_or_else(|| {
        row.map(|row| optional_string(row, "occurred_start"))
            .unwrap_or(Value::Null)
    });
    let occurred_end = result.get("occurred_end").cloned().unwrap_or_else(|| {
        row.map(|row| optional_string(row, "occurred_end"))
            .unwrap_or(Value::Null)
    });
    let mentioned_at = result.get("mentioned_at").cloned().unwrap_or_else(|| {
        row.map(|row| optional_string(row, "mentioned_at"))
            .unwrap_or(Value::Null)
    });
    let document_id = result.get("document_id").cloned().unwrap_or_else(|| {
        row.map(|row| optional_string(row, "document_id"))
            .unwrap_or(Value::Null)
    });
    let chunk_id = result.get("chunk_id").cloned().unwrap_or_else(|| {
        row.map(|row| optional_string(row, "chunk_id"))
            .unwrap_or(Value::Null)
    });
    let proof_count = row
        .and_then(|row| row.get("proof_count"))
        .filter(|value| value.is_number())
        .cloned()
        .unwrap_or(json!(1));
    let date = row
        .map(|row| display_text(row, "date"))
        .filter(|date| !date.is_empty())
        .or_else(|| {
            occurred_start
                .as_str()
                .and_then(|value| non_empty(Some(value)))
        })
        .or_else(|| {
            mentioned_at
                .as_str()
                .and_then(|value| non_empty(Some(value)))
        })
        .unwrap_or_default();

    let mut item = Map::new();
    item.insert("id".into(), Value::String(id));
    item.insert("text".into(), Value::String(text));
    item.insert("context".into(), Value::String(context));
    item.insert("fact_type".into(), Value::String(fact_type));
    item.insert("entities".into(), json_strings(&entities));
    item.insert("tags".into(), json_strings(&tags));
    item.insert("date".into(), Value::String(date));
    item.insert("occurred_start".into(), normalize_optional(occurred_start));
    item.insert("occurred_end".into(), normalize_optional(occurred_end));
    item.insert("mentioned_at".into(), normalize_optional(mentioned_at));
    item.insert("document_id".into(), normalize_optional(document_id));
    item.insert("chunk_id".into(), normalize_optional(chunk_id));
    item.insert("proof_count".into(), proof_count);
    Some(Value::Object(item))
}

fn normalize_optional(value: Value) -> Value {
    match value {
        Value::String(text) if text.trim().is_empty() => Value::Null,
        other => other,
    }
}

/// Text-mode results: every row that matches, scored and sorted, then capped.
fn text_search_items(rows: &[Value], query_text: &str, limit: usize) -> Vec<Value> {
    let tokens = tokenize(query_text);
    let total = rows.len();
    let mut scored: Vec<(f64, Value)> = Vec::new();
    for (index, row) in rows.iter().enumerate() {
        let Some(base) = text_match_score(row, query_text, &tokens) else {
            continue;
        };
        let Some(mut item) = item_from_row(row) else {
            continue;
        };
        let score = with_recency(base, index, total);
        if let Some(object) = item.as_object_mut() {
            object.insert("score".into(), json!(score));
        }
        scored.push((score, item));
    }
    scored.sort_by(|left, right| {
        right
            .0
            .partial_cmp(&left.0)
            .unwrap_or(std::cmp::Ordering::Equal)
            .then_with(|| {
                let left_id = left.1.get("id").and_then(Value::as_str).unwrap_or("");
                let right_id = right.1.get("id").and_then(Value::as_str).unwrap_or("");
                left_id.cmp(right_id)
            })
    });
    scored.truncate(limit);
    scored.into_iter().map(|(_, item)| item).collect()
}

fn graph_node_by_id(nodes: &[Value]) -> HashMap<String, Value> {
    let mut out = HashMap::new();
    for node in nodes {
        if let Some(id) = node_id(node) {
            out.entry(id.to_string()).or_insert_with(|| node.clone());
        }
    }
    out
}

/// Copy `factType` and `tags` from the flat table rows onto the Cytoscape
/// nodes, so the frontend can style a node without cross-referencing rows.
fn enrich_nodes(nodes: &mut [Value], rows: &[Value]) {
    let mut by_id: HashMap<&str, &Value> = HashMap::new();
    for row in rows {
        if let Some(id) = row.get("id").and_then(Value::as_str) {
            by_id.insert(id, row);
        }
    }
    for node in nodes.iter_mut() {
        let Some(id) = node_id(node).map(str::to_string) else {
            continue;
        };
        let Some(row) = by_id.get(id.as_str()).copied() else {
            continue;
        };
        let fact_type = str_field(row, "fact_type").trim().to_string();
        let tags = tags_from(row);
        if let Some(data) = node.get_mut("data").and_then(Value::as_object_mut) {
            if !fact_type.is_empty() {
                data.insert("factType".into(), Value::String(fact_type));
            }
            data.insert("tags".into(), json_strings(&tags));
        }
    }
}

fn truncate_label(text: &str) -> String {
    if text.chars().count() > 30 {
        let mut label: String = text.chars().take(30).collect();
        label.push_str("...");
        label
    } else {
        text.to_string()
    }
}

fn node_color(entity_count: usize) -> &'static str {
    match entity_count {
        0 => "#e0e0e0",
        1 => "#90caf9",
        _ => "#42a5f5",
    }
}

/// A Cytoscape node in the exact shape `/graph` uses, for recalled memories the
/// graph page did not return (or when the graph fetch failed).
fn synthesize_node(item: &Value) -> Value {
    let entities = entities_from(item);
    let text = str_field(item, "text").to_string();
    let mut data = Map::new();
    data.insert("id".into(), item.get("id").cloned().unwrap_or(Value::Null));
    data.insert("label".into(), Value::String(truncate_label(&text)));
    data.insert("text".into(), Value::String(text));
    data.insert(
        "date".into(),
        Value::String(str_field(item, "date").to_string()),
    );
    data.insert(
        "context".into(),
        Value::String(str_field(item, "context").to_string()),
    );
    data.insert(
        "entities".into(),
        Value::String(if entities.is_empty() {
            "None".to_string()
        } else {
            entities.join(", ")
        }),
    );
    data.insert(
        "color".into(),
        Value::String(node_color(entities.len()).into()),
    );
    data.insert(
        "factType".into(),
        Value::String(str_field(item, "fact_type").to_string()),
    );
    data.insert("tags".into(), json_strings(&tags_from(item)));
    json!({ "data": Value::Object(data) })
}

fn link_style(link_type: &str) -> (&'static str, &'static str) {
    match link_type {
        "temporal" => ("#00bcd4", "dashed"),
        "semantic" => ("#ff69b4", "solid"),
        "entity" => ("#ffd700", "solid"),
        _ => ("#999999", "solid"),
    }
}

fn synthetic_edge(source: &str, target: &str, link_type: &str, entity_name: &str) -> Value {
    let (color, line_style) = link_style(link_type);
    json!({
        "data": {
            "id": format!("{}-{}-{}", source, target, link_type),
            "source": source,
            "target": target,
            "linkType": link_type,
            "weight": 1.0,
            "entityName": entity_name,
            "color": color,
            "lineStyle": line_style,
        }
    })
}

fn pair_key(left: &str, right: &str) -> (String, String) {
    if left <= right {
        (left.to_string(), right.to_string())
    } else {
        (right.to_string(), left.to_string())
    }
}

/// Keep only the nodes belonging to `ids` and the edges whose endpoints both do.
fn filter_graph(
    nodes: &[Value],
    edges: &[Value],
    ids: &HashSet<String>,
) -> (Vec<Value>, Vec<Value>) {
    let nodes: Vec<Value> = nodes
        .iter()
        .filter(|node| node_id(node).map(|id| ids.contains(id)).unwrap_or(false))
        .cloned()
        .collect();
    let edges: Vec<Value> = edges
        .iter()
        .filter(|edge| match edge_endpoints(edge) {
            Some((source, target)) => ids.contains(source) && ids.contains(target),
            None => false,
        })
        .cloned()
        .collect();
    (nodes, edges)
}

/// Nodes for a recalled set: real graph nodes when available, synthesized ones
/// otherwise. Both carry `factType`/`tags` copied from the item.
fn recalled_nodes(items: &[Value], graph_node_index: &HashMap<String, Value>) -> Vec<Value> {
    items
        .iter()
        .filter_map(|item| {
            let id = item.get("id").and_then(Value::as_str)?;
            let node = match graph_node_index.get(id) {
                Some(node) => node.clone(),
                None => return Some(synthesize_node(item)),
            };
            let fact_type = str_field(item, "fact_type").trim().to_string();
            let tags = tags_from(item);
            let mut node = node;
            if let Some(data) = node.get_mut("data").and_then(Value::as_object_mut) {
                data.insert("tags".into(), json_strings(&tags));
                if !fact_type.is_empty() {
                    data.insert("factType".into(), Value::String(fact_type));
                }
            }
            Some(node)
        })
        .collect()
}

/// Recalled-graph edges: the real edges between recalled units, plus
/// shared-entity and observation→source links the graph did not already carry.
fn recalled_edges(
    items: &[Value],
    graph_edges_in: &[Value],
    recalled: &HashSet<String>,
) -> Vec<Value> {
    let mut edges: Vec<Value> = graph_edges_in
        .iter()
        .filter(|edge| match edge_endpoints(edge) {
            Some((source, target)) => recalled.contains(source) && recalled.contains(target),
            None => false,
        })
        .cloned()
        .collect();
    let mut seen: HashSet<(String, String)> = HashSet::new();
    for edge in &edges {
        if let Some((source, target)) = edge_endpoints(edge) {
            seen.insert(pair_key(source, target));
        }
    }

    // Entity name -> recalled ids mentioning it.
    let mut by_entity: HashMap<String, Vec<String>> = HashMap::new();
    for item in items {
        let Some(id) = item.get("id").and_then(Value::as_str) else {
            continue;
        };
        for entity in entities_from(item) {
            by_entity.entry(entity).or_default().push(id.to_string());
        }
    }
    // Rarest entities first: a name mentioned by everything links everything
    // to everything and says nothing.
    let mut entity_groups: Vec<(String, Vec<String>)> = by_entity.into_iter().collect();
    entity_groups.sort_by(|left, right| {
        left.1
            .len()
            .cmp(&right.1.len())
            .then_with(|| left.0.cmp(&right.0))
    });
    'outer: for (entity, ids) in entity_groups {
        for (index, left) in ids.iter().enumerate() {
            for right in ids.iter().skip(index + 1) {
                if edges.len() >= MAX_SYNTHETIC_EDGES {
                    break 'outer;
                }
                let key = pair_key(left, right);
                if left == right || !seen.insert(key) {
                    continue;
                }
                edges.push(synthetic_edge(left, right, "entity", &entity));
            }
        }
    }

    for item in items {
        let Some(id) = item.get("id").and_then(Value::as_str) else {
            continue;
        };
        let Some(sources) = item.get("source_fact_ids").and_then(Value::as_array) else {
            continue;
        };
        for source in sources.iter().filter_map(Value::as_str) {
            if edges.len() >= MAX_SYNTHETIC_EDGES {
                return edges;
            }
            if !recalled.contains(source) || source == id {
                continue;
            }
            if !seen.insert(pair_key(id, source)) {
                continue;
            }
            edges.push(synthetic_edge(source, id, "source_fact", ""));
        }
    }
    edges
}

// ============================================================================
// Recall scoring
// ============================================================================

/// `trace.visits[].node_id -> weights.final_weight` (or activation), which is
/// where the pre-scores API-era recall responses carry the ranking weight.
fn trace_visit_weights(recall: &Value) -> HashMap<String, f64> {
    let mut out = HashMap::new();
    let Some(visits) = recall
        .get("trace")
        .and_then(|trace| trace.get("visits"))
        .and_then(Value::as_array)
    else {
        return out;
    };
    for visit in visits {
        let Some(id) = visit.get("node_id").and_then(Value::as_str) else {
            continue;
        };
        let weights = visit.get("weights");
        let weight = ["final_weight", "activation"]
            .iter()
            .find_map(|name| {
                weights
                    .and_then(|weights| weights.get(*name))
                    .and_then(Value::as_f64)
            })
            .or_else(|| visit.get("final_weight").and_then(Value::as_f64));
        if let Some(weight) = weight {
            out.insert(id.to_string(), weight);
        }
    }
    out
}

fn positive_score(value: Option<f64>) -> Option<f64> {
    match value {
        Some(value) if value > 0.0 && value.is_finite() => Some(value.clamp(1e-9, 1.0)),
        _ => None,
    }
}

/// The score of one recall result: the pipeline's own final score when present
/// (`scores.final`, then the legacy weight/score/activation fields), else the
/// trace visit weight, else a rank-decayed fallback.
fn recall_result_score(result: &Value, rank: usize, visits: &HashMap<String, f64>) -> f64 {
    let explicit = result
        .get("scores")
        .and_then(|scores| scores.get("final"))
        .and_then(Value::as_f64)
        .or_else(|| result.get("weight").and_then(Value::as_f64))
        .or_else(|| result.get("score").and_then(Value::as_f64))
        .or_else(|| result.get("activation").and_then(Value::as_f64));
    if let Some(score) = positive_score(explicit) {
        return score;
    }
    if let Some(id) = result.get("id").and_then(Value::as_str) {
        if let Some(score) = positive_score(visits.get(id).copied()) {
            return score;
        }
    }
    let rank = rank.max(1) as f64;
    (1.0 / (1.0 + 0.08 * rank)).clamp(1e-9, 1.0)
}

fn recall_items(recall: &Value, rows_by_id: &HashMap<String, Value>, limit: usize) -> Vec<Value> {
    let visits = trace_visit_weights(recall);
    let mut scored: Vec<(f64, Value)> = Vec::new();
    let results = recall
        .get("results")
        .and_then(Value::as_array)
        .cloned()
        .unwrap_or_default();
    for (index, result) in results.iter().enumerate() {
        let id = match result.get("id").and_then(Value::as_str) {
            Some(id) => id,
            None => continue,
        };
        let mut item = match item_from_recall(result, rows_by_id.get(id)) {
            Some(item) => item,
            None => continue,
        };
        let score = recall_result_score(result, index + 1, &visits);
        if let Some(object) = item.as_object_mut() {
            object.insert("score".into(), json!(score));
            if let Some(source_fact_ids) = result.get("source_fact_ids").cloned() {
                object.insert("source_fact_ids".into(), source_fact_ids);
            }
        }
        scored.push((score, item));
    }
    scored.sort_by(|left, right| {
        right
            .0
            .partial_cmp(&left.0)
            .unwrap_or(std::cmp::Ordering::Equal)
            .then_with(|| {
                let left_id = left.1.get("id").and_then(Value::as_str).unwrap_or("");
                let right_id = right.1.get("id").and_then(Value::as_str).unwrap_or("");
                left_id.cmp(right_id)
            })
    });
    scored.truncate(limit);
    scored.into_iter().map(|(_, item)| item).collect()
}

fn rows_by_id(rows: &[Value]) -> HashMap<String, Value> {
    let mut out = HashMap::new();
    for row in rows {
        if let Some(id) = row.get("id").and_then(Value::as_str) {
            out.entry(id.to_string()).or_insert_with(|| row.clone());
        }
    }
    out
}

fn item_ids(items: &[Value]) -> HashSet<String> {
    items
        .iter()
        .filter_map(|item| item.get("id").and_then(Value::as_str).map(str::to_string))
        .collect()
}

// ============================================================================
// Parameter parsing
// ============================================================================

fn parse_limit(value: Option<&str>, default: u32, max: u32) -> u32 {
    value
        .and_then(|value| value.trim().parse::<u32>().ok())
        .unwrap_or(default)
        .clamp(1, max)
}

fn parse_body_limit(value: Option<&Value>, default: u32, max: u32) -> Result<u32, ()> {
    match value {
        None | Some(Value::Null) => Ok(default),
        Some(Value::Number(number)) => number
            .as_u64()
            .map(|value| (value as u32).clamp(1, max))
            .ok_or(()),
        Some(_) => Err(()),
    }
}

/// `world` | `experience` | `observation`, or `None` when absent/empty.
fn parse_fact_type(value: Option<&str>) -> Result<Option<String>, ()> {
    let Some(value) = value else { return Ok(None) };
    let value = value.trim();
    if value.is_empty() {
        return Ok(None);
    }
    match value {
        "world" | "experience" | "observation" => Ok(Some(value.to_string())),
        _ => Err(()),
    }
}

fn parse_fact_type_value(value: Option<&Value>) -> Result<Option<String>, ()> {
    match value {
        None | Some(Value::Null) => Ok(None),
        Some(Value::String(text)) => parse_fact_type(Some(text.as_str())),
        Some(_) => Err(()),
    }
}

fn invalid_fact_type() -> Response {
    coded_error(
        StatusCode::BAD_REQUEST,
        "type must be world, experience or observation",
        "invalid_fact_type",
    )
}

fn query_text_param(value: Option<&str>) -> Option<String> {
    non_empty(value)
}

// ============================================================================
// Handlers
// ============================================================================

fn unavailable(target: &HindsightTarget) -> Response {
    json_status(
        StatusCode::SERVICE_UNAVAILABLE,
        json!({
            "error": "Hindsight is not configured",
            "code": "hindsight_unconfigured",
            "configured": false,
            "bankId": target.bank_id,
        }),
    )
}

/// The 200-OK "nothing set up yet" graph payload the UI renders as a setup
/// hint instead of an error toast.
fn unconfigured_graph(target: &HindsightTarget, limit: u32) -> Value {
    json!({
        "configured": false,
        "bankId": target.bank_id,
        "nodes": [],
        "edges": [],
        "table_rows": [],
        "total_units": 0,
        "limit": limit,
        "error": "Hindsight is not configured",
        "code": "hindsight_unconfigured",
    })
}

/// `GET /api/memories/graph`
pub async fn memories_graph(State(state): State<SharedState>, uri: Uri) -> Response {
    let params = query(&uri);
    let limit = parse_limit(params.get("limit"), DEFAULT_GRAPH_LIMIT, MAX_GRAPH_LIMIT);
    let fact_type = match parse_fact_type(params.get("type")) {
        Ok(fact_type) => fact_type,
        Err(()) => return invalid_fact_type(),
    };
    let q = query_text_param(params.get("q"));
    let target = resolve_target(&state.cfg);
    if !target.configured {
        // Nothing to call and nothing to guess: the default URL is only a
        // placeholder for a user who has not set memory up at all.
        return json_ok(unconfigured_graph(&target, limit));
    }

    let graph = match fetch_graph(&target, limit, fact_type.as_deref(), q.as_deref()).await {
        Ok(graph) => graph,
        Err(failure) => {
            return json_status(
                failure.status,
                json!({
                    "configured": true,
                    "bankId": target.bank_id,
                    "error": failure.message,
                    "code": "hindsight_unavailable",
                }),
            );
        }
    };

    let mut nodes = graph_nodes(&graph);
    let edges = graph_edges(&graph);
    let table_rows = graph_rows(&graph);
    enrich_nodes(&mut nodes, &table_rows);

    json_ok(json!({
        "configured": target.configured,
        "bankId": target.bank_id,
        "nodes": nodes,
        "edges": edges,
        "table_rows": table_rows,
        "total_units": graph.get("total_units").cloned().unwrap_or(json!(0)),
        "limit": graph.get("limit").cloned().unwrap_or(json!(limit)),
    }))
}

/// `POST /api/memories/search`
pub async fn memories_search(State(state): State<SharedState>, request: Request) -> Response {
    let body = match body_json(request, MAX_SEARCH_BODY_BYTES).await {
        Ok(body) => body,
        Err(response) => return response,
    };
    let Some(query_value) = body.get("query") else {
        return coded_error(
            StatusCode::BAD_REQUEST,
            "query is required",
            "invalid_query",
        );
    };
    let Some(query_text) = query_value
        .as_str()
        .and_then(|value| non_empty(Some(value)))
    else {
        return coded_error(
            StatusCode::BAD_REQUEST,
            "query is required",
            "invalid_query",
        );
    };
    let mode = match body.get("mode") {
        None | Some(Value::Null) => "text",
        Some(Value::String(text)) => match text.trim() {
            "" | "text" => "text",
            "meaning" => "meaning",
            _ => {
                return coded_error(
                    StatusCode::BAD_REQUEST,
                    "mode must be text or meaning",
                    "invalid_mode",
                )
            }
        },
        Some(_) => {
            return coded_error(
                StatusCode::BAD_REQUEST,
                "mode must be text or meaning",
                "invalid_mode",
            )
        }
    };
    let fact_type = match parse_fact_type_value(body.get("type")) {
        Ok(fact_type) => fact_type,
        Err(()) => return invalid_fact_type(),
    };
    let limit = match parse_body_limit(body.get("limit"), DEFAULT_SEARCH_LIMIT, MAX_SEARCH_LIMIT) {
        Ok(limit) => limit as usize,
        Err(()) => {
            return coded_error(
                StatusCode::BAD_REQUEST,
                "limit must be a positive integer",
                "invalid_limit",
            )
        }
    };
    let target = resolve_target(&state.cfg);
    if !target.configured {
        return unavailable(&target);
    }

    if mode == "text" {
        let graph = match fetch_graph(
            &target,
            limit as u32,
            fact_type.as_deref(),
            Some(&query_text),
        )
        .await
        {
            Ok(graph) => graph,
            Err(failure) => {
                return json_status(
                    failure.status,
                    json!({
                        "error": failure.message,
                        "code": "hindsight_unavailable",
                        "mode": "text",
                        "query": query_text,
                    }),
                )
            }
        };
        let nodes_all = graph_nodes(&graph);
        let edges_all = graph_edges(&graph);
        let table_rows = graph_rows(&graph);
        let items = text_search_items(&table_rows, &query_text, limit);
        let ids = item_ids(&items);
        let (mut nodes, edges) = filter_graph(&nodes_all, &edges_all, &ids);
        enrich_nodes(&mut nodes, &table_rows);
        return json_ok(json!({
            "mode": "text",
            "query": query_text,
            "total": items.len(),
            "items": items,
            "nodes": nodes,
            "edges": edges,
        }));
    }

    let (recall, graph) = tokio::join!(
        fetch_recall(&target, &query_text, fact_type.as_deref()),
        fetch_graph(&target, DEFAULT_GRAPH_LIMIT, fact_type.as_deref(), None),
    );
    let recall = match recall {
        Ok(recall) => recall,
        Err(failure) => {
            return json_status(
                failure.status,
                json!({
                    "error": failure.message,
                    "code": "hindsight_unavailable",
                    "mode": "meaning",
                    "query": query_text,
                }),
            )
        }
    };
    // The graph only adds real edges and node metadata; recall on its own is a
    // complete answer, so a failed graph fetch must not fail the search.
    let graph = graph.ok();
    let table_rows = graph.as_ref().map(graph_rows).unwrap_or_default();
    let rows = rows_by_id(&table_rows);
    let items = recall_items(&recall, &rows, limit);
    let ids = item_ids(&items);
    let node_index = graph
        .as_ref()
        .map(|graph| graph_node_by_id(&graph_nodes(graph)))
        .unwrap_or_default();
    let mut nodes = recalled_nodes(&items, &node_index);
    enrich_nodes(&mut nodes, &table_rows);
    let edges = recalled_edges(
        &items,
        graph
            .as_ref()
            .map(graph_edges)
            .unwrap_or_default()
            .as_slice(),
        &ids,
    );
    json_ok(json!({
        "mode": "meaning",
        "query": query_text,
        "total": items.len(),
        "items": items,
        "nodes": nodes,
        "edges": edges,
    }))
}

/// `GET /api/memories/{id}`
pub async fn memory_get(
    State(state): State<SharedState>,
    AxumPath(id): AxumPath<String>,
) -> Response {
    let id = id.trim().to_string();
    if id.is_empty() {
        return coded_error(
            StatusCode::BAD_REQUEST,
            "Memory id is required",
            "invalid_id",
        );
    }
    let target = resolve_target(&state.cfg);
    if !target.configured {
        return unavailable(&target);
    }
    let http = match client() {
        Ok(http) => http,
        Err(failure) => {
            return json_status(
                failure.status,
                json!({ "error": failure.message, "code": "hindsight_unavailable" }),
            )
        }
    };
    let request = http
        .get(memory_url(&target, &id))
        .header(reqwest::header::ACCEPT, "application/json");
    match send_json(authorized(request, &target)).await {
        Ok(value) => json_ok(value),
        Err(failure) => {
            let failure = failure.redacting(&target);
            json_status(
                failure.status,
                json!({ "error": failure.message, "code": "hindsight_error" }),
            )
        }
    }
}

/// `PATCH /api/memories/{id}`
pub async fn memory_patch(
    State(state): State<SharedState>,
    AxumPath(id): AxumPath<String>,
    request: Request,
) -> Response {
    let id = id.trim().to_string();
    if id.is_empty() {
        return coded_error(
            StatusCode::BAD_REQUEST,
            "Memory id is required",
            "invalid_id",
        );
    }
    let body = match body_json(request, MAX_PATCH_BODY_BYTES).await {
        Ok(body) => body,
        Err(response) => return response,
    };
    if !body.is_object() {
        return coded_error(
            StatusCode::BAD_REQUEST,
            "Request body must be a JSON object",
            "invalid_json",
        );
    }
    let target = resolve_target(&state.cfg);
    if !target.configured {
        return unavailable(&target);
    }
    let http = match client() {
        Ok(http) => http,
        Err(failure) => {
            return json_status(
                failure.status,
                json!({ "error": failure.message, "code": "hindsight_unavailable" }),
            )
        }
    };
    let upstream = http
        .patch(memory_url(&target, &id))
        .header(reqwest::header::ACCEPT, "application/json")
        .json(&body);
    match send_json(authorized(upstream, &target)).await {
        Ok(value) => json_ok(value),
        Err(failure) => {
            let failure = failure.redacting(&target);
            json_status(
                failure.status,
                json!({ "error": failure.message, "code": "hindsight_error" }),
            )
        }
    }
}

#[cfg(test)]
mod tests;
