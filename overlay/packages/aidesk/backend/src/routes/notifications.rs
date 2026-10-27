//! Notifications devices/history/presence/test routes.

use crate::routes::{body_json, json_ok};
use crate::state::SharedState;
use crate::util::{atomic_write, now_ms};
use axum::extract::State;
use axum::http::{StatusCode, Uri};
use axum::response::{IntoResponse, Response};
use serde_json::{json, Map, Value};
use std::sync::{LazyLock, Mutex};

static PRESENCE: LazyLock<Mutex<Map<String, Value>>> = LazyLock::new(|| Mutex::new(Map::new()));
static NOTIFICATION_TX: LazyLock<tokio::sync::broadcast::Sender<Value>> =
    LazyLock::new(|| tokio::sync::broadcast::channel(256).0);

/// Multiplexed in-app notification stream consumed by
/// `/api/agent/running/events` (`{type:"notification", kind, event}`).
pub fn subscribe_notifications() -> tokio::sync::broadcast::Receiver<Value> {
    NOTIFICATION_TX.subscribe()
}

fn is_valid_notification_id(value: Option<&Value>) -> Option<String> {
    let value = value?.as_str()?;
    if (8..=64).contains(&value.len())
        && value
            .bytes()
            .all(|b| b.is_ascii_alphanumeric() || b == b'_' || b == b'-')
    {
        Some(value.to_string())
    } else {
        None
    }
}

fn default_prefs() -> Value {
    json!({
        "enabled": false,
        "types": { "completed": true, "input": true, "error": true, "modelSwitch": false },
        "whenActive": "toast",
        "locale": "en",
    })
}

fn parse_prefs(value: Option<&Value>) -> Value {
    let mut prefs = default_prefs();
    let Some(raw) = value.and_then(Value::as_object) else {
        return prefs;
    };
    let object = prefs.as_object_mut().unwrap();
    if let Some(enabled) = raw.get("enabled").and_then(Value::as_bool) {
        object.insert("enabled".into(), Value::Bool(enabled));
    }
    if let Some(types) = raw.get("types").and_then(Value::as_object) {
        if let Some(current) = object.get_mut("types").and_then(Value::as_object_mut) {
            for key in ["completed", "input", "error", "modelSwitch"] {
                if let Some(flag) = types.get(key).and_then(Value::as_bool) {
                    current.insert(key.into(), Value::Bool(flag));
                }
            }
        }
    }
    if raw.get("whenActive").and_then(Value::as_str) == Some("system") {
        object.insert("whenActive".into(), Value::String("system".into()));
    }
    if let Some(locale) = raw.get("locale").and_then(Value::as_str) {
        if (2..=10).contains(&locale.len())
            && locale.chars().all(|c| c.is_ascii_alphabetic() || c == '-')
        {
            object.insert("locale".into(), Value::String(locale.to_string()));
        }
    }
    prefs
}

fn parse_subscription(value: Option<&Value>) -> Result<Option<Value>, ()> {
    let Some(value) = value else { return Ok(None) };
    if value.is_null() {
        return Ok(None);
    }
    let Some(object) = value.as_object() else {
        return Err(());
    };
    let Some(endpoint) = object.get("endpoint").and_then(Value::as_str) else {
        return Err(());
    };
    if endpoint.len() > 2048 || !endpoint.starts_with("https://") {
        return Err(());
    }
    let Some(keys) = object.get("keys").and_then(Value::as_object) else {
        return Err(());
    };
    let p256dh = keys.get("p256dh").and_then(Value::as_str).unwrap_or("");
    let auth = keys.get("auth").and_then(Value::as_str).unwrap_or("");
    let valid_key = |text: &str, min: usize, max: usize| {
        text.len() >= min
            && text.len() <= max
            && text
                .bytes()
                .all(|b| b.is_ascii_alphanumeric() || b == b'_' || b == b'-' || b == b'=')
    };
    if !valid_key(p256dh, 86, 90) || !valid_key(auth, 21, 26) {
        return Err(());
    }
    Ok(Some(json!({
        "endpoint": endpoint,
        "keys": { "p256dh": p256dh, "auth": auth },
    })))
}

fn load_store_path(path: &std::path::Path) -> Map<String, Value> {
    std::fs::read_to_string(path)
        .ok()
        .and_then(|text| serde_json::from_str::<Value>(&text).ok())
        .and_then(|value| value.as_object().cloned())
        .unwrap_or_default()
}

fn save_store_path(path: &std::path::Path, store: &Map<String, Value>) -> std::io::Result<()> {
    let text = format!(
        "{}\n",
        serde_json::to_string_pretty(&Value::Object(store.clone())).unwrap_or_default()
    );
    atomic_write(path, text.as_bytes())
}

fn load_store(state: &SharedState) -> Map<String, Value> {
    load_store_path(&state.cfg.notifications_path())
}

fn save_store(state: &SharedState, store: &Map<String, Value>) -> std::io::Result<()> {
    save_store_path(&state.cfg.notifications_path(), store)
}

/// Append a detected event to the persisted history. `id` is the replace-tag
/// (`<sessionId>:<type>`), so a newer event of the same kind replaces the old.
pub fn record_session_notification(
    cfg: &crate::config::Config,
    session_id: &str,
    session_name: Option<&str>,
    kind: &str,
    detail: Option<&str>,
) {
    if session_id.is_empty() || !["completed", "input", "error", "modelSwitch"].contains(&kind) {
        return;
    }
    let path = cfg.notifications_path();
    let mut store = load_store_path(&path);
    let mut entries = history(&store);
    let id = format!("{}:{}", session_id, kind);
    let mut event = Map::new();
    event.insert("type".into(), Value::String(kind.to_string()));
    event.insert("sessionId".into(), Value::String(session_id.to_string()));
    event.insert(
        "sessionName".into(),
        session_name
            .map(|name| Value::String(name.to_string()))
            .unwrap_or(Value::Null),
    );
    if let Some(detail) = detail.filter(|detail| !detail.trim().is_empty()) {
        let clipped: String = detail.split_whitespace().collect::<Vec<_>>().join(" ");
        let clipped = if clipped.chars().count() > 180 {
            format!("{}…", clipped.chars().take(179).collect::<String>())
        } else {
            clipped
        };
        event.insert("detail".into(), Value::String(clipped));
    }
    entries.retain(|entry| entry.get("id").and_then(Value::as_str) != Some(id.as_str()));
    entries.push(json!({
        "id": id,
        "event": Value::Object(event.clone()),
        "at": now_ms(),
        "read": false,
    }));
    if entries.len() > 100 {
        let excess = entries.len() - 100;
        entries.drain(..excess);
    }
    store.insert("history".into(), Value::Array(entries));
    let _ = save_store_path(&path, &store);

    // In-app toast to open tabs, but only when some device opted into this
    // event type (a device that is currently on screen is not tracked here).
    let enabled = devices(&store).iter().any(|device| {
        device
            .get("prefs")
            .map(|prefs| {
                prefs.get("enabled").and_then(Value::as_bool) == Some(true)
                    && prefs
                        .get("types")
                        .and_then(|types| types.get(kind))
                        .and_then(Value::as_bool)
                        == Some(true)
            })
            .unwrap_or(false)
    });
    if enabled {
        let _ = NOTIFICATION_TX.send(json!({
            "type": "notification",
            "kind": "toast",
            "event": Value::Object(event),
        }));
    }
}

fn devices(store: &Map<String, Value>) -> Vec<Value> {
    store
        .get("devices")
        .and_then(Value::as_array)
        .cloned()
        .unwrap_or_default()
}

fn history(store: &Map<String, Value>) -> Vec<Value> {
    store
        .get("history")
        .and_then(Value::as_array)
        .cloned()
        .unwrap_or_default()
}

fn vapid_public_key(store: &Map<String, Value>) -> String {
    store
        .get("vapid")
        .and_then(|vapid| vapid.get("publicKey"))
        .and_then(Value::as_str)
        .unwrap_or("")
        .to_string()
}

fn base64_url(bytes: &[u8]) -> String {
    use base64::Engine;
    base64::engine::general_purpose::URL_SAFE_NO_PAD.encode(bytes)
}

/// Generate a VAPID (P-256) key pair. The public key is the uncompressed point
/// browsers expect as `applicationServerKey`; the private key is stored as
/// PKCS#8 so a future Web Push implementation can load it back.
fn generate_vapid_keys() -> Option<(String, String)> {
    use ring::rand::SystemRandom;
    use ring::signature::{EcdsaKeyPair, KeyPair, ECDSA_P256_SHA256_ASN1_SIGNING};
    let rng = SystemRandom::new();
    let document = EcdsaKeyPair::generate_pkcs8(&ECDSA_P256_SHA256_ASN1_SIGNING, &rng).ok()?;
    let key_pair =
        EcdsaKeyPair::from_pkcs8(&ECDSA_P256_SHA256_ASN1_SIGNING, document.as_ref(), &rng).ok()?;
    Some((
        base64_url(key_pair.public_key().as_ref()),
        base64_url(document.as_ref()),
    ))
}

/// Read the stored VAPID public key, generating and persisting one on first
/// use so `applicationServerKey` is never an empty string.
fn vapid_public_key_for(state: &SharedState) -> String {
    let mut store = load_store(state);
    let existing = vapid_public_key(&store);
    if !existing.is_empty() {
        return existing;
    }
    let Some((public_key, private_key)) = generate_vapid_keys() else {
        return String::new();
    };
    store.insert(
        "vapid".into(),
        json!({ "publicKey": public_key, "privateKey": private_key }),
    );
    let _ = save_store(state, &store);
    public_key
}

pub async fn devices_get(State(state): State<SharedState>, uri: Uri) -> Response {
    let query = crate::routes::query(&uri);
    let device_id = query
        .get("deviceId")
        .and_then(|id| is_valid_notification_id(Some(&Value::String(id.to_string()))));
    let store = load_store(&state);
    let subscribed = device_id
        .and_then(|id| {
            devices(&store)
                .into_iter()
                .find(|device| device.get("deviceId").and_then(Value::as_str) == Some(id.as_str()))
        })
        .map(|device| {
            device
                .get("subscription")
                .map(|s| !s.is_null())
                .unwrap_or(false)
        })
        .unwrap_or(false);
    json_ok(json!({
        "publicKey": vapid_public_key_for(&state),
        "subscribed": subscribed,
    }))
}

pub async fn devices_put(
    State(state): State<SharedState>,
    request: axum::extract::Request,
) -> Response {
    let body = body_json(request, 256 * 1024).await.unwrap_or(Value::Null);
    let Some(device_id) = is_valid_notification_id(body.get("deviceId")) else {
        return crate::util::coded_error(
            StatusCode::BAD_REQUEST,
            "deviceId is required",
            "invalid_device",
        );
    };
    let subscription = match parse_subscription(body.get("subscription")) {
        Ok(subscription) => subscription,
        Err(_) => {
            return crate::util::coded_error(
                StatusCode::BAD_REQUEST,
                "Invalid push subscription",
                "invalid_subscription",
            )
        }
    };
    let mut store = load_store(&state);
    let mut current = devices(&store);
    let existing = current
        .iter()
        .find(|device| device.get("deviceId").and_then(Value::as_str) == Some(device_id.as_str()))
        .cloned();
    let mut next = Map::new();
    next.insert("deviceId".into(), Value::String(device_id.clone()));
    next.insert("prefs".into(), parse_prefs(body.get("prefs")));
    let subscription = match subscription {
        Some(subscription) => Some(subscription),
        None => existing
            .as_ref()
            .and_then(|device| device.get("subscription"))
            .filter(|subscription| !subscription.is_null())
            .cloned(),
    };
    if let Some(subscription) = &subscription {
        next.insert("subscription".into(), subscription.clone());
    }
    next.insert("updatedAt".into(), Value::from(now_ms()));
    current.retain(|device| {
        device.get("deviceId").and_then(Value::as_str) != Some(device_id.as_str())
    });
    current.push(Value::Object(next));
    if current.len() > 50 {
        let excess = current.len() - 50;
        current.drain(..excess);
    }
    store.insert("devices".into(), Value::Array(current));
    if let Err(error) = save_store(&state, &store) {
        return crate::util::api_error(error, StatusCode::INTERNAL_SERVER_ERROR);
    }
    json_ok(json!({ "subscribed": subscription.is_some() }))
}

pub async fn history_get(State(state): State<SharedState>) -> Response {
    let mut entries = history(&load_store(&state));
    entries.sort_by(|a, b| {
        let left = a.get("at").and_then(Value::as_f64).unwrap_or(0.0);
        let right = b.get("at").and_then(Value::as_f64).unwrap_or(0.0);
        right
            .partial_cmp(&left)
            .unwrap_or(std::cmp::Ordering::Equal)
    });
    json_ok(json!({ "entries": entries }))
}

pub async fn history_patch(
    State(state): State<SharedState>,
    request: axum::extract::Request,
) -> Response {
    let body = match body_json(request, 32 * 1024).await {
        Ok(body) => body,
        Err(_) => {
            return crate::util::coded_error(
                StatusCode::BAD_REQUEST,
                "Invalid history request",
                "invalid_history_request",
            )
        }
    };
    let Some(ids) = body.get("ids").and_then(Value::as_array) else {
        return crate::util::coded_error(
            StatusCode::BAD_REQUEST,
            "Invalid history request",
            "invalid_history_request",
        );
    };
    if ids.len() > 100 {
        return crate::util::coded_error(
            StatusCode::BAD_REQUEST,
            "Invalid history request",
            "invalid_history_request",
        );
    }
    let ids: Vec<String> = match ids
        .iter()
        .map(|id| {
            id.as_str()
                .filter(|id| !id.is_empty() && id.len() <= 256)
                .map(|s| s.to_string())
        })
        .collect::<Option<Vec<_>>>()
    {
        Some(ids) => ids,
        None => {
            return crate::util::coded_error(
                StatusCode::BAD_REQUEST,
                "Invalid history request",
                "invalid_history_request",
            )
        }
    };
    let mut store = load_store(&state);
    let mut entries = history(&store);
    for entry in entries.iter_mut() {
        let id = entry.get("id").and_then(Value::as_str).unwrap_or("");
        if ids.iter().any(|candidate| candidate == id) {
            if let Some(object) = entry.as_object_mut() {
                object.insert("read".into(), Value::Bool(true));
            }
        }
    }
    store.insert("history".into(), Value::Array(entries));
    let _ = save_store(&state, &store);
    json_ok(json!({ "ok": true }))
}

pub async fn history_delete(State(state): State<SharedState>, uri: Uri) -> Response {
    let query = crate::routes::query(&uri);
    let id = query.get("id");
    let clear_all = id.is_none() && query.get("all") == Some("1");
    let valid_id = id.filter(|id| !id.is_empty() && id.len() <= 256);
    if !clear_all && valid_id.is_none() {
        return crate::util::coded_error(
            StatusCode::BAD_REQUEST,
            "Invalid history request",
            "invalid_history_request",
        );
    }
    let mut store = load_store(&state);
    let mut entries = history(&store);
    if clear_all {
        entries.clear();
    } else if let Some(id) = valid_id {
        entries.retain(|entry| entry.get("id").and_then(Value::as_str) != Some(id));
    }
    store.insert("history".into(), Value::Array(entries));
    let _ = save_store(&state, &store);
    json_ok(json!({ "ok": true }))
}

pub async fn presence(_state: State<SharedState>, request: axum::extract::Request) -> Response {
    let body = body_json(request, 64 * 1024).await.unwrap_or(Value::Null);
    let client_id = is_valid_notification_id(body.get("clientId"));
    let device_id = is_valid_notification_id(body.get("deviceId"));
    let visible = body.get("visible").and_then(Value::as_bool);
    let seq = body.get("seq").and_then(Value::as_i64);
    let (Some(client_id), Some(device_id), Some(visible), Some(seq)) =
        (client_id, device_id, visible, seq)
    else {
        return crate::util::coded_error(
            StatusCode::BAD_REQUEST,
            "Invalid presence report",
            "invalid_presence",
        );
    };
    let session_id = body
        .get("sessionId")
        .and_then(Value::as_str)
        .filter(|value| !value.is_empty())
        .map(|value| value.to_string());
    if let Ok(mut presence) = PRESENCE.lock() {
        presence.insert(
            client_id,
            json!({
                "deviceId": device_id,
                "visible": visible,
                "sessionId": session_id,
                "seq": seq,
                "lastSeen": now_ms(),
            }),
        );
    }
    StatusCode::NO_CONTENT.into_response()
}

pub async fn notify_test(
    State(state): State<SharedState>,
    request: axum::extract::Request,
) -> Response {
    let body = body_json(request, 64 * 1024).await.unwrap_or(Value::Null);
    let Some(device_id) = is_valid_notification_id(body.get("deviceId")) else {
        return crate::util::coded_error(
            StatusCode::BAD_REQUEST,
            "deviceId is required",
            "invalid_device",
        );
    };
    let store = load_store(&state);
    let subscribed = devices(&store)
        .into_iter()
        .find(|device| device.get("deviceId").and_then(Value::as_str) == Some(device_id.as_str()))
        .and_then(|device| device.get("subscription").cloned())
        .map(|subscription| !subscription.is_null())
        .unwrap_or(false);
    if !subscribed {
        return crate::util::json_status(
            StatusCode::BAD_GATEWAY,
            json!({ "error": "This device has no push subscription", "code": "push_failed" }),
        );
    }
    // Web Push payload encryption is not implemented by this server; report the
    // same failure shape the push service would.
    crate::util::json_status(
        StatusCode::BAD_GATEWAY,
        json!({ "error": "Web Push delivery is unavailable in this build", "code": "push_failed" }),
    )
}
