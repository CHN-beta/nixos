//! Models, skills, settings, version, usage and manifest routes.

use crate::omp::{models_config, rpc, settings, skills, usage};
use crate::routes::{body_json, json_ok, query};
use crate::state::SharedState;
use crate::util::{coded_error, mtime_ms};
use axum::extract::State;
use axum::http::{StatusCode, Uri};
use axum::response::Response;
use serde_json::{json, Map, Value};
use std::collections::HashMap;
use std::sync::{LazyLock, Mutex};
use std::time::{Duration, Instant};

const MODELS_CACHE_TTL: Duration = Duration::from_secs(60);
const SAFE_MODEL_LOAD_FAILURE: &str =
    "Model list is temporarily unavailable. Check your configuration and try again.";

static MODELS_CACHE: LazyLock<Mutex<Option<(Instant, String, Value)>>> =
    LazyLock::new(|| Mutex::new(None));

fn empty_models() -> Value {
    json!({
        "models": {},
        "modelList": [],
        "defaultModel": Value::Null,
        "thinkingLevels": {},
    })
}

fn models_fingerprint(state: &SharedState) -> String {
    let path = state.cfg.models_config_path();
    match std::fs::metadata(&path) {
        Ok(meta) => format!("{}:{}:{}", path.display(), mtime_ms(&meta), meta.len()),
        Err(_) => format!("{}:missing", path.display()),
    }
}

fn numeric_compare(a: &str, b: &str) -> std::cmp::Ordering {
    // Case-insensitive, digit-run-aware comparison (Intl.Collator numeric).
    let a = a.to_lowercase();
    let b = b.to_lowercase();
    let mut left = a.char_indices().peekable();
    let mut right = b.char_indices().peekable();
    loop {
        let l = left.peek().map(|(_, c)| *c);
        let r = right.peek().map(|(_, c)| *c);
        match (l, r) {
            (None, None) => return std::cmp::Ordering::Equal,
            (None, Some(_)) => return std::cmp::Ordering::Less,
            (Some(_), None) => return std::cmp::Ordering::Greater,
            (Some(lc), Some(rc)) => {
                if lc.is_ascii_digit() && rc.is_ascii_digit() {
                    let read_number = |iter: &mut std::iter::Peekable<std::str::CharIndices>| {
                        let mut text = String::new();
                        while let Some((_, c)) = iter.peek() {
                            if c.is_ascii_digit() {
                                text.push(*c);
                                iter.next();
                            } else {
                                break;
                            }
                        }
                        text.parse::<u128>().unwrap_or(0)
                    };
                    let ln = read_number(&mut left);
                    let rn = read_number(&mut right);
                    if ln != rn {
                        return ln.cmp(&rn);
                    }
                    continue;
                }
                if lc != rc {
                    return lc.cmp(&rc);
                }
                left.next();
                right.next();
            }
        }
    }
}

fn thinking_levels_for(model: &Value) -> Vec<String> {
    if model.get("reasoning").and_then(Value::as_bool) != Some(true) {
        return vec!["off".to_string()];
    }
    let mut levels = vec!["off".to_string()];
    if let Some(efforts) = model
        .get("thinking")
        .and_then(|thinking| thinking.get("efforts"))
        .and_then(Value::as_array)
    {
        for effort in efforts {
            if let Some(effort) = effort.as_str() {
                levels.push(effort.to_string());
            }
        }
    }
    levels
}

async fn load_models(state: &SharedState) -> Result<Value, rpc::RpcError> {
    let available_response = rpc::run_utility_command(
        state,
        json!({ "type": "get_available_models" }),
        Duration::from_secs(120),
    )
    .await?;
    let available: Vec<Value> = available_response
        .get("models")
        .and_then(Value::as_array)
        .cloned()
        .unwrap_or_default()
        .into_iter()
        .filter(|model| {
            model.get("id").and_then(Value::as_str).is_some()
                && model.get("provider").and_then(Value::as_str).is_some()
        })
        .map(|mut model| {
            let id = model
                .get("id")
                .and_then(Value::as_str)
                .unwrap_or("")
                .to_string();
            let name = model
                .get("name")
                .and_then(Value::as_str)
                .map(str::trim)
                .filter(|name| !name.is_empty())
                .unwrap_or(&id)
                .to_string();
            if let Some(object) = model.as_object_mut() {
                object.insert("name".into(), Value::String(name));
            }
            model
        })
        .collect();

    let login_response = rpc::run_utility_command(
        state,
        json!({ "type": "get_login_providers" }),
        Duration::from_secs(30),
    )
    .await?;
    let login_providers: Vec<Value> = login_response
        .get("providers")
        .and_then(Value::as_array)
        .cloned()
        .unwrap_or_default()
        .into_iter()
        .filter(|provider| {
            provider.get("id").and_then(Value::as_str).is_some()
                && provider.get("name").and_then(Value::as_str).is_some()
                && provider
                    .get("authenticated")
                    .and_then(Value::as_bool)
                    .is_some()
        })
        .collect();
    let disabled = settings::read_disabled_providers(&state.cfg);
    let connected: Vec<Value> = login_providers
        .iter()
        .filter(|provider| provider.get("authenticated").and_then(Value::as_bool) == Some(true))
        .map(|provider| {
            let id = provider.get("id").and_then(Value::as_str).unwrap_or("");
            json!({
                "id": id,
                "name": provider.get("name").cloned().unwrap_or(Value::Null),
                "disabled": disabled.contains(id),
            })
        })
        .collect();

    let mut name_map = Map::new();
    let mut thinking_levels = Map::new();
    let mut list: Vec<Value> = Vec::new();
    for model in &available {
        let id = model.get("id").and_then(Value::as_str).unwrap_or("");
        let provider = model.get("provider").and_then(Value::as_str).unwrap_or("");
        let name = model.get("name").and_then(Value::as_str).unwrap_or(id);
        let key = format!("{}:{}", provider, id);
        name_map.insert(key.clone(), Value::String(name.to_string()));
        thinking_levels.insert(key, json!(thinking_levels_for(model)));
        let mut entry = Map::new();
        entry.insert("id".into(), Value::String(id.to_string()));
        entry.insert("name".into(), Value::String(name.to_string()));
        entry.insert("provider".into(), Value::String(provider.to_string()));
        entry.insert("thinkingLevels".into(), json!(thinking_levels_for(model)));
        entry.insert(
            "supportsFastMode".into(),
            Value::Bool(matches!(provider, "anthropic" | "openai" | "google")),
        );
        entry.insert(
            "supportsSlowMode".into(),
            Value::Bool(matches!(
                provider,
                "anthropic" | "openai" | "openai-codex" | "google" | "google-vertex"
            )),
        );
        if let Some(context_window) = model.get("contextWindow").and_then(Value::as_f64) {
            entry.insert("contextWindow".into(), Value::from(context_window));
        }
        if let Some(max_tokens) = model.get("maxTokens").and_then(Value::as_f64) {
            entry.insert("maxTokens".into(), Value::from(max_tokens));
        }
        list.push(Value::Object(entry));
    }
    list.sort_by(|a, b| {
        let field = |value: &Value, key: &str| {
            value
                .get(key)
                .and_then(Value::as_str)
                .unwrap_or("")
                .to_string()
        };
        numeric_compare(
            &{
                let name = field(a, "name");
                if name.is_empty() {
                    field(a, "id")
                } else {
                    name
                }
            },
            &{
                let name = field(b, "name");
                if name.is_empty() {
                    field(b, "id")
                } else {
                    name
                }
            },
        )
        .then_with(|| numeric_compare(&field(a, "provider"), &field(b, "provider")))
        .then_with(|| numeric_compare(&field(a, "id"), &field(b, "id")))
    });

    let mut default_model = Value::Null;
    if let Ok(state_value) = rpc::run_utility_command(
        state,
        json!({ "type": "get_state" }),
        Duration::from_secs(30),
    )
    .await
    {
        if let Some(model) = state_value.get("model") {
            if let (Some(provider), Some(id)) = (
                model.get("provider").and_then(Value::as_str),
                model.get("id").and_then(Value::as_str),
            ) {
                if available.iter().any(|candidate| {
                    candidate.get("provider").and_then(Value::as_str) == Some(provider)
                        && candidate.get("id").and_then(Value::as_str) == Some(id)
                }) {
                    default_model = json!({ "provider": provider, "modelId": id });
                }
            }
        }
    }

    Ok(json!({
        "models": name_map,
        "modelList": list,
        "defaultModel": default_model,
        "thinkingLevels": thinking_levels,
        "connectedProviders": connected,
    }))
}

pub async fn models_get(State(state): State<SharedState>) -> Response {
    let anthropic_slow_mode = settings::read_anthropic_slow_mode(&state.cfg);
    let fingerprint = models_fingerprint(&state);
    if let Ok(cache) = MODELS_CACHE.lock() {
        if let Some((expires, cached_fingerprint, data)) = cache.as_ref() {
            if *expires > Instant::now() && *cached_fingerprint == fingerprint {
                let mut response = data.clone();
                if let Some(object) = response.as_object_mut() {
                    object.insert("anthropicSlowMode".into(), Value::Bool(anthropic_slow_mode));
                }
                return json_ok(response);
            }
        }
    }
    // models.yml may have been edited outside the API. The cached model list
    // must be rebuilt, and the utility child re-reads the file only when it is
    // restarted, so dispose it first (waiting for the exit) before reloading.
    let cached_fingerprint = MODELS_CACHE.lock().ok().and_then(|cache| {
        cache
            .as_ref()
            .map(|(_, fingerprint, _)| fingerprint.clone())
    });
    if cached_fingerprint.as_deref() != Some(fingerprint.as_str()) {
        rpc::dispose_utility_rpc().await;
    }
    let body = match load_models(&state).await {
        Ok(data) => data,
        Err(_) => {
            let mut data = empty_models();
            if let Some(object) = data.as_object_mut() {
                object.insert(
                    "modelError".into(),
                    Value::String(SAFE_MODEL_LOAD_FAILURE.into()),
                );
            }
            data
        }
    };
    if let Ok(mut cache) = MODELS_CACHE.lock() {
        *cache = Some((Instant::now() + MODELS_CACHE_TTL, fingerprint, body.clone()));
    }
    let mut response = body;
    if let Some(object) = response.as_object_mut() {
        object.insert("anthropicSlowMode".into(), Value::Bool(anthropic_slow_mode));
    }
    json_ok(response)
}

// ============================================================================
// models.yml / model roles
// ============================================================================

pub async fn models_config_get(State(state): State<SharedState>) -> Response {
    let file = models_config::read_models_config_file(&state.cfg);
    if let Some(error) = file.parse_error {
        return json_ok(json!({
            "providers": {},
            "parseError": error,
            "path": file.path,
            "code": "models_config_unparseable",
        }));
    }
    json_ok(file.config)
}

pub async fn models_config_put(
    State(state): State<SharedState>,
    uri: Uri,
    request: axum::extract::Request,
) -> Response {
    let query = query(&uri);
    let overwrite_unparseable = query.get("overwrite") == Some("true");
    let body = match body_json(request, 1024 * 1024).await {
        Ok(body) => body,
        Err(response) => return response,
    };
    if let Err(error) = models_config::validate_models_config(&body) {
        return crate::util::json_status(StatusCode::BAD_REQUEST, json!({ "error": error }));
    }
    let existing = models_config::read_models_config_file(&state.cfg);
    if existing.parse_error.is_some() && !overwrite_unparseable {
        return crate::util::json_status(
            StatusCode::CONFLICT,
            json!({
                "error": format!("{} — fix it by hand; AIDesk will not overwrite it", existing.parse_error.unwrap_or_default()),
                "code": "models_config_unparseable",
            }),
        );
    }
    if let Err(error) = models_config::write_models_config(&state.cfg, &body, overwrite_unparseable)
    {
        return crate::util::api_error(error, StatusCode::INTERNAL_SERVER_ERROR);
    }
    if let Ok(mut cache) = MODELS_CACHE.lock() {
        *cache = None;
    }
    rpc::dispose_utility_rpc().await;
    json_ok(json!({ "success": true }))
}

pub async fn model_roles_get(State(state): State<SharedState>) -> Response {
    match settings::read_model_roles(&state.cfg) {
        Ok(value) => json_ok(value),
        Err(error) => crate::util::json_status(StatusCode::BAD_REQUEST, json!({ "error": error })),
    }
}

pub async fn model_roles_put(
    State(state): State<SharedState>,
    request: axum::extract::Request,
) -> Response {
    let body = body_json(request, 1024 * 1024).await.unwrap_or(Value::Null);
    let Some(roles) = body.get("roles").and_then(Value::as_object) else {
        return crate::util::json_status(
            StatusCode::BAD_REQUEST,
            json!({ "error": "roles must be an object" }),
        );
    };
    let mut sanitized = Map::new();
    for (role, selector) in roles {
        if role.trim().is_empty() {
            continue;
        }
        if let Some(selector) = selector.as_str() {
            if !selector.trim().is_empty() {
                sanitized.insert(role.clone(), Value::String(selector.to_string()));
            }
        }
    }
    if let Err(error) = settings::write_model_roles(&state.cfg, &sanitized) {
        return crate::util::json_status(StatusCode::BAD_REQUEST, json!({ "error": error }));
    }
    if let Ok(mut cache) = MODELS_CACHE.lock() {
        *cache = None;
    }
    json_ok(json!({ "success": true, "roles": sanitized }))
}

// ============================================================================
// Skills
// ============================================================================

pub async fn skills_get(State(state): State<SharedState>, uri: Uri) -> Response {
    let query = query(&uri);
    let Some(cwd) = query.get("cwd").filter(|cwd| !cwd.is_empty()) else {
        return coded_error(StatusCode::BAD_REQUEST, "cwd required", "cwd_required");
    };
    if !state.is_existing_path_allowed(std::path::Path::new(cwd)) {
        return crate::util::access_denied();
    }
    json_ok(skills::load_skills_with_install_info(
        &state,
        std::path::Path::new(cwd),
    ))
}

pub async fn skills_patch(
    State(state): State<SharedState>,
    request: axum::extract::Request,
) -> Response {
    let body = body_json(request, 1024 * 1024).await.unwrap_or(Value::Null);
    let Some(file_path) = body.get("filePath").and_then(Value::as_str) else {
        return coded_error(
            StatusCode::BAD_REQUEST,
            "filePath required",
            "file_path_required",
        );
    };
    let Some(disable) = body.get("disableModelInvocation").and_then(Value::as_bool) else {
        return crate::util::json_status(
            StatusCode::BAD_REQUEST,
            json!({ "error": "disableModelInvocation must be a boolean", "code": "invalid_disable_model_invocation" }),
        );
    };
    let cwd = body
        .get("cwd")
        .and_then(Value::as_str)
        .map(std::path::Path::new);
    match skills::toggle_skill(&state, file_path, disable, cwd) {
        Ok(value) => json_ok(value),
        Err((status, message, code)) => crate::util::json_status(
            StatusCode::from_u16(status).unwrap_or(StatusCode::INTERNAL_SERVER_ERROR),
            json!({ "error": message, "code": code }),
        ),
    }
}

pub async fn skills_check(
    State(state): State<SharedState>,
    request: axum::extract::Request,
) -> Response {
    let body = body_json(request, 1024 * 1024).await.unwrap_or(Value::Null);
    let Some(cwd) = body
        .get("cwd")
        .and_then(Value::as_str)
        .filter(|cwd| !cwd.is_empty())
    else {
        return coded_error(StatusCode::BAD_REQUEST, "cwd required", "cwd_required");
    };
    if !state.is_existing_path_allowed(std::path::Path::new(cwd)) {
        return crate::util::access_denied();
    }
    let package = body.get("package").and_then(Value::as_str);
    let scope = match body.get("scope").and_then(Value::as_str) {
        Some(value @ ("global" | "project")) => Some(value),
        _ => None,
    };
    match skills::check_skill_updates(&state, std::path::Path::new(cwd), package, scope) {
        Ok(value) => json_ok(value),
        Err((status, message, code)) => crate::util::json_status(
            StatusCode::from_u16(status).unwrap_or(StatusCode::INTERNAL_SERVER_ERROR),
            json!({ "error": message, "code": code }),
        ),
    }
}

// ============================================================================
// omp settings / web settings
// ============================================================================

pub async fn omp_settings_get(State(state): State<SharedState>) -> Response {
    match settings::read_native_settings(&state.cfg) {
        Ok(value) => json_ok(value),
        Err(error) => crate::util::json_status(StatusCode::BAD_REQUEST, json!({ "error": error })),
    }
}

fn ambiguous_enabled_model(entries: &[String], models: &[Value]) -> Option<String> {
    let mut providers_by_id: HashMap<String, Vec<String>> = HashMap::new();
    for model in models {
        let Some(id) = model.get("id").and_then(Value::as_str) else {
            continue;
        };
        let Some(provider) = model.get("provider").and_then(Value::as_str) else {
            continue;
        };
        providers_by_id
            .entry(id.to_string())
            .or_default()
            .push(provider.to_string());
    }
    for entry in entries {
        if entry.contains('/') {
            continue;
        }
        if let Some(providers) = providers_by_id.get(entry) {
            if providers.len() > 1 {
                return Some(entry.clone());
            }
        }
    }
    None
}

pub async fn omp_settings_put(
    State(state): State<SharedState>,
    request: axum::extract::Request,
) -> Response {
    let body = body_json(request, 2 * 1024 * 1024)
        .await
        .unwrap_or(Value::Null);
    let Some(settings_value) = body.get("settings").filter(|value| value.is_object()) else {
        return crate::util::json_status(
            StatusCode::BAD_REQUEST,
            json!({ "error": "settings must be an object" }),
        );
    };
    if let Some(enabled) = settings_value
        .get("enabledModels")
        .and_then(Value::as_array)
    {
        let entries: Vec<String> = enabled
            .iter()
            .filter_map(Value::as_str)
            .map(|s| s.to_string())
            .collect();
        if let Ok(response) = rpc::run_utility_command(
            &state,
            json!({ "type": "get_available_models" }),
            Duration::from_secs(120),
        )
        .await
        {
            let models: Vec<Value> = response
                .get("models")
                .and_then(Value::as_array)
                .cloned()
                .unwrap_or_default()
                .into_iter()
                .filter(|model| {
                    model.get("id").and_then(Value::as_str).is_some()
                        && model.get("provider").and_then(Value::as_str).is_some()
                })
                .collect();
            if let Some(entry) = ambiguous_enabled_model(&entries, &models) {
                return crate::util::json_status(
                    StatusCode::BAD_REQUEST,
                    json!({
                        "error": format!("Ambiguous enabledModels entry {:?}: use provider/id", entry),
                        "code": "ambiguous_model_scope",
                    }),
                );
            }
        }
    }
    match settings::write_native_settings(&state.cfg, settings_value) {
        Ok(settings) => {
            if let Ok(mut cache) = MODELS_CACHE.lock() {
                *cache = None;
            }
            rpc::dispose_utility_rpc().await;
            json_ok(json!({ "success": true, "settings": settings }))
        }
        Err(error) => crate::util::json_status(StatusCode::BAD_REQUEST, json!({ "error": error })),
    }
}

fn read_web_settings(state: &SharedState) -> Value {
    let path = state.cfg.existing_web_settings_path();
    let parsed = std::fs::read_to_string(&path)
        .ok()
        .and_then(|text| serde_json::from_str::<Value>(&text).ok())
        .and_then(|value| value.as_object().cloned())
        .unwrap_or_default();
    let auto_resume = parsed
        .get("autoResumeSessions")
        .and_then(Value::as_bool)
        .unwrap_or(false);
    let agent_env = parsed
        .get("agentEnv")
        .and_then(Value::as_object)
        .map(|object| {
            let mut out = Map::new();
            for (name, value) in object {
                if let Some(value) = value.as_str() {
                    out.insert(name.clone(), Value::String(value.to_string()));
                }
            }
            settings::sanitize_agent_env(&out).0
        })
        .unwrap_or_default();
    json!({ "autoResumeSessions": auto_resume, "agentEnv": agent_env })
}

pub async fn web_settings_get(State(state): State<SharedState>) -> Response {
    json_ok(read_web_settings(&state))
}

pub async fn web_settings_put(
    State(state): State<SharedState>,
    request: axum::extract::Request,
) -> Response {
    let body = body_json(request, 1024 * 1024).await.unwrap_or(Value::Null);
    let Some(payload) = body.as_object() else {
        return coded_error(
            StatusCode::BAD_REQUEST,
            "Request body must be a settings object",
            "invalid_settings",
        );
    };
    let current = read_web_settings(&state);
    let mut next = current.as_object().cloned().unwrap_or_default();
    if let Some(value) = payload.get("autoResumeSessions") {
        let Some(value) = value.as_bool() else {
            return coded_error(
                StatusCode::BAD_REQUEST,
                "autoResumeSessions must be a boolean",
                "invalid_settings",
            );
        };
        next.insert("autoResumeSessions".into(), Value::Bool(value));
    }
    if let Some(agent_env) = payload.get("agentEnv") {
        let (values, errors) = match agent_env {
            Value::String(text) => settings::parse_agent_env_text(text),
            Value::Object(object) => settings::sanitize_agent_env(object),
            _ => {
                return coded_error(
                    StatusCode::BAD_REQUEST,
                    "agentEnv must be KEY=VALUE text or an object of variables",
                    "invalid_agent_env",
                )
            }
        };
        if !errors.is_empty() {
            return crate::util::json_status(
                StatusCode::BAD_REQUEST,
                json!({
                    "error": "agentEnv contains invalid or reserved variable names",
                    "code": "invalid_agent_env",
                    "errors": errors,
                }),
            );
        }
        next.insert("agentEnv".into(), Value::Object(values));
    }
    let text = format!(
        "{}\n",
        serde_json::to_string_pretty(&Value::Object(next.clone())).unwrap_or_default()
    );
    if let Err(error) = crate::util::atomic_write(&state.cfg.web_settings_path(), text.as_bytes()) {
        return crate::util::api_error(error, StatusCode::INTERNAL_SERVER_ERROR);
    }
    json_ok(Value::Object(next))
}

// ============================================================================
// omp version / provider usage / manifest
// ============================================================================

pub async fn omp_version(State(state): State<SharedState>) -> Response {
    let version = match &state.cfg.omp_bin {
        Some(bin) => match tokio::process::Command::new(bin)
            .arg("--version")
            .output()
            .await
        {
            Ok(output) if output.status.success() => {
                let text = String::from_utf8_lossy(&output.stdout).trim().to_string();
                if text.is_empty() {
                    Value::Null
                } else {
                    Value::String(text)
                }
            }
            _ => Value::Null,
        },
        None => Value::Null,
    };
    json_ok(json!({ "version": version }))
}

fn is_usage_identifier(value: &str) -> bool {
    !value.is_empty()
        && value.len() <= 200
        && value
            .bytes()
            .all(|b| b.is_ascii_alphanumeric() || matches!(b, b'.' | b'_' | b':' | b'/' | b'-'))
}

pub async fn provider_usage(State(state): State<SharedState>, uri: Uri) -> Response {
    let query = query(&uri);
    let raw_provider = query.get("provider");
    let raw_model = query.get("model");
    let read_identifier = |value: Option<&str>| -> Result<Option<String>, ()> {
        match value {
            None => Ok(None),
            Some(value) => {
                let trimmed = value.trim();
                if trimmed.is_empty() {
                    Ok(None)
                } else if is_usage_identifier(trimmed) {
                    Ok(Some(trimmed.to_string()))
                } else {
                    Err(())
                }
            }
        }
    };
    let (provider, model) = match (read_identifier(raw_provider), read_identifier(raw_model)) {
        (Ok(provider), Ok(model)) => (provider, model),
        _ => {
            return coded_error(
                StatusCode::BAD_REQUEST,
                "Invalid provider or model identifier",
                "invalid_usage_query",
            )
        }
    };
    let refresh = query.get("refresh") == Some("true");
    let cfg = state.cfg.clone();
    let result = tokio::task::spawn_blocking(move || {
        usage::get_provider_usage(&cfg, provider.as_deref(), model.as_deref(), refresh)
    })
    .await;
    match result {
        Ok(Ok(value)) => json_ok(value),
        _ => coded_error(
            StatusCode::BAD_GATEWAY,
            "Provider usage is currently unavailable",
            "provider_usage_unavailable",
        ),
    }
}

pub async fn manifest(State(_state): State<SharedState>) -> Response {
    let name = std::env::var("AIDESK_NAME")
        .ok()
        .filter(|name| !name.trim().is_empty())
        .unwrap_or_else(|| "AIDesk".to_string());
    let body = json!({
        "name": name,
        "short_name": name,
        "description": "Web UI for the oh-my-pi (omp) coding agent",
        "start_url": "/",
        "scope": "/",
        "display": "standalone",
        "background_color": "#000000",
        "theme_color": "#000000",
        "icons": [
            { "src": "/icon-192.png", "sizes": "192x192", "type": "image/png" },
            { "src": "/icon.png", "sizes": "512x512", "type": "image/png" },
        ],
    });
    let mut response = json_ok(body);
    response.headers_mut().insert(
        axum::http::header::CONTENT_TYPE,
        axum::http::HeaderValue::from_static("application/manifest+json"),
    );
    response.headers_mut().insert(
        axum::http::header::CACHE_CONTROL,
        axum::http::HeaderValue::from_static("private, no-cache, max-age=0, must-revalidate"),
    );
    response
}
