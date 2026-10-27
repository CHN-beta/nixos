//! omp's native `config.yml` settings + model roles.

use crate::config::Config;
use serde_json::{json, Map, Value};
use std::collections::HashSet;
use std::path::Path;

fn parse_yaml_mapping(path: &Path) -> Result<Map<String, Value>, String> {
    let source = match std::fs::read_to_string(path) {
        Ok(source) => source,
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => return Ok(Map::new()),
        Err(error) => return Err(error.to_string()),
    };
    let value: Value = serde_yaml_ng::from_str(&source)
        .map_err(|error| format!("{} is not valid YAML: {}", path.display(), error))?;
    match value {
        Value::Object(object) => Ok(object),
        Value::Null => Ok(Map::new()),
        _ => Err(format!("{} must contain a YAML mapping", path.display())),
    }
}

fn write_yaml_mapping(path: &Path, mapping: &Map<String, Value>) -> Result<(), String> {
    let text =
        serde_yaml_ng::to_string(&Value::Object(mapping.clone())).map_err(|e| e.to_string())?;
    crate::util::atomic_write(path, text.as_bytes()).map_err(|e| e.to_string())
}

fn string_array(value: Option<&Value>) -> Option<Vec<String>> {
    value.and_then(Value::as_array).and_then(|items| {
        items
            .iter()
            .map(|item| item.as_str().map(|s| s.to_string()))
            .collect::<Option<Vec<String>>>()
    })
}

fn bool_in(value: Option<&Value>, allowed: &[&str]) -> Option<String> {
    let text = value?.as_str()?;
    allowed.contains(&text).then(|| text.to_string())
}

fn filter_object(source: Option<&Value>, names: &[&str]) -> Option<Value> {
    let object = source?.as_object()?;
    let mut out = Map::new();
    for name in names {
        if let Some(value) = object.get(*name) {
            out.insert((*name).to_string(), value.clone());
        }
    }
    (!out.is_empty()).then_some(Value::Object(out))
}

/// Extract the persisted, validated subset of omp's config.
pub fn read_native_settings(cfg: &Config) -> Result<Value, String> {
    let path = cfg.settings_path();
    let data = parse_yaml_mapping(&path)?;
    let mut settings = Map::new();
    if let Some(value) = bool_in(
        data.get("defaultThinkingLevel"),
        &["auto", "minimal", "low", "medium", "high", "xhigh", "max"],
    ) {
        settings.insert("defaultThinkingLevel".into(), Value::String(value));
    }
    if let Some(providers) = data.get("providers").and_then(Value::as_object) {
        if let Some(source) = bool_in(
            providers.get("autoThinkingSource"),
            &["classifier", "vendor"],
        ) {
            settings.insert("providers".into(), json!({ "autoThinkingSource": source }));
        }
    }
    for key in ["hideThinkingBlock", "externalThinking"] {
        if let Some(value) = data.get(key).and_then(Value::as_bool) {
            settings.insert(key.to_string(), Value::Bool(value));
        }
    }
    for (key, allowed) in [
        ("textVerbosity", &["low", "medium", "high"][..]),
        (
            "personality",
            &["default", "friendly", "pragmatic", "none"][..],
        ),
    ] {
        if let Some(value) = bool_in(data.get(key), allowed) {
            settings.insert(key.to_string(), Value::String(value));
        }
    }
    if let Some(advisor) = filter_object(
        data.get("advisor"),
        &["enabled", "subagents", "syncBacklog", "immuneTurns"],
    ) {
        settings.insert("advisor".into(), advisor);
    }
    if let Some(tools) = data.get("tools").and_then(Value::as_object) {
        let mut out = Map::new();
        if let Some(value) = bool_in(tools.get("approvalMode"), &["always-ask", "write", "yolo"]) {
            out.insert("approvalMode".into(), Value::String(value));
        }
        if let Some(approval) = filter_object(tools.get("approval"), &["bash", "extension"]) {
            out.insert("approval".into(), approval);
        }
        if !out.is_empty() {
            settings.insert("tools".into(), Value::Object(out));
        }
    }
    if let Some(skills) = filter_object(data.get("skills"), &["showStartupDiagnostics"]) {
        settings.insert("skills".into(), skills);
    }
    if let Some(values) = string_array(data.get("enabledModels")) {
        settings.insert("enabledModels".into(), json!(values));
    }
    if let Some(values) = string_array(data.get("disabledProviders")) {
        settings.insert("disabledProviders".into(), json!(values));
    }
    if let Some(values) = string_array(data.get("modelProviderOrder")) {
        settings.insert("modelProviderOrder".into(), json!(values));
    }
    let scoped = ["enabledModels", "disabledProviders", "modelProviderOrder"]
        .iter()
        .any(|key| {
            data.get(*key)
                .and_then(Value::as_array)
                .map(|items| items.iter().any(|item| !item.is_string()))
                .unwrap_or(false)
        });
    if scoped {
        settings.insert("registryHasScopedEntries".into(), Value::Bool(true));
    }
    for key in [
        "retry",
        "compaction",
        "memory",
        "autolearn",
        "mnemopi",
        "mcp",
    ] {
        if let Some(value) = data.get(key).and_then(Value::as_object) {
            if !value.is_empty() {
                settings.insert(key.to_string(), Value::Object(value.clone()));
            }
        }
    }
    Ok(json!({ "path": path.to_string_lossy(), "settings": Value::Object(settings) }))
}

const THINKING_LEVELS: &[&str] = &["auto", "minimal", "low", "medium", "high", "xhigh", "max"];
const TEXT_VERBOSITIES: &[&str] = &["low", "medium", "high"];
const PERSONALITIES: &[&str] = &["default", "friendly", "pragmatic", "none"];
const BACKLOGS: &[&str] = &["off", "1", "3", "5"];
const APPROVAL_MODES: &[&str] = &["always-ask", "write", "yolo"];
const APPROVAL_POLICIES: &[&str] = &["allow", "prompt", "deny"];
const FALLBACK_POLICIES: &[&str] = &["cooldown-expiry", "never"];
const MEMORY_BACKENDS: &[&str] = &["off", "local", "mnemopi", "hindsight"];
const MEMORY_SCOPES: &[&str] = &["global", "per-project", "per-project-tagged"];

fn require_object(value: Option<&Value>, name: &str) -> Result<(), String> {
    if let Some(value) = value {
        if !value.is_object() {
            return Err(format!("{} must be an object", name));
        }
    }
    Ok(())
}

fn optional_bool(value: Option<&Value>, name: &str) -> Result<(), String> {
    if let Some(value) = value {
        if !value.is_boolean() {
            return Err(format!("{} must be a boolean", name));
        }
    }
    Ok(())
}

fn optional_string_in(value: Option<&Value>, name: &str, allowed: &[&str]) -> Result<(), String> {
    match value {
        None => Ok(()),
        Some(value) => match value.as_str() {
            Some(text) if allowed.contains(&text) => Ok(()),
            _ => Err(format!("Invalid {}", name)),
        },
    }
}

/// Validate and persist a reviewed subset of omp's global config schema.
pub fn write_native_settings(cfg: &Config, settings: &Value) -> Result<Value, String> {
    let object = settings.as_object().ok_or("Settings must be an object")?;
    require_object(object.get("providers"), "providers")?;
    require_object(object.get("advisor"), "advisor")?;
    require_object(object.get("tools"), "tools")?;
    require_object(object.get("skills"), "skills")?;
    require_object(object.get("retry"), "retry")?;
    require_object(object.get("compaction"), "compaction")?;
    require_object(object.get("memory"), "memory")?;
    require_object(object.get("autolearn"), "autolearn")?;
    require_object(object.get("mnemopi"), "mnemopi")?;
    require_object(object.get("mcp"), "mcp")?;
    if let Some(tools) = object.get("tools") {
        require_object(tools.get("approval"), "tools.approval")?;
    }
    if let Some(skills) = object.get("skills").and_then(Value::as_object) {
        if skills.keys().any(|key| key != "showStartupDiagnostics") {
            return Err("Unsupported skills setting".into());
        }
    }
    optional_string_in(
        object.get("defaultThinkingLevel"),
        "default thinking level",
        THINKING_LEVELS,
    )?;
    optional_string_in(
        object.get("textVerbosity"),
        "text verbosity",
        TEXT_VERBOSITIES,
    )?;
    optional_string_in(object.get("personality"), "personality", PERSONALITIES)?;
    for (name, value) in [
        ("hideThinkingBlock", object.get("hideThinkingBlock")),
        ("externalThinking", object.get("externalThinking")),
    ] {
        optional_bool(value, name)?;
    }
    if let Some(providers) = object.get("providers") {
        optional_string_in(
            providers.get("autoThinkingSource"),
            "Auto thinking source",
            &["classifier", "vendor"],
        )?;
    }
    if let Some(advisor) = object.get("advisor") {
        optional_bool(advisor.get("enabled"), "advisor.enabled")?;
        optional_bool(advisor.get("subagents"), "advisor.subagents")?;
        optional_string_in(advisor.get("syncBacklog"), "advisor sync backlog", BACKLOGS)?;
    }
    if let Some(tools) = object.get("tools") {
        optional_string_in(tools.get("approvalMode"), "approval mode", APPROVAL_MODES)?;
        if let Some(approval) = tools.get("approval") {
            optional_string_in(
                approval.get("bash"),
                "Bash approval policy",
                APPROVAL_POLICIES,
            )?;
            optional_string_in(
                approval.get("extension"),
                "extension approval policy",
                &["allow", "prompt"],
            )?;
        }
    }
    if let Some(retry) = object.get("retry") {
        optional_bool(retry.get("enabled"), "retry.enabled")?;
        optional_bool(retry.get("modelFallback"), "retry.modelFallback")?;
        optional_string_in(
            retry.get("fallbackRevertPolicy"),
            "fallback revert policy",
            FALLBACK_POLICIES,
        )?;
    }
    if let Some(compaction) = object.get("compaction") {
        optional_bool(compaction.get("enabled"), "compaction.enabled")?;
        optional_bool(
            compaction.get("midTurnEnabled"),
            "compaction.midTurnEnabled",
        )?;
        optional_bool(compaction.get("autoContinue"), "compaction.autoContinue")?;
    }
    if let Some(memory) = object.get("memory") {
        optional_string_in(memory.get("backend"), "memory backend", MEMORY_BACKENDS)?;
    }
    if let Some(mnemopi) = object.get("mnemopi") {
        optional_string_in(
            mnemopi.get("scoping"),
            "Mnemopi memory scope",
            MEMORY_SCOPES,
        )?;
    }
    if let Some(autolearn) = object.get("autolearn") {
        optional_bool(autolearn.get("enabled"), "autolearn.enabled")?;
        optional_bool(autolearn.get("autoContinue"), "autolearn.autoContinue")?;
    }
    for name in ["enabledModels", "disabledProviders", "modelProviderOrder"] {
        if let Some(value) = object.get(name) {
            let Some(items) = value.as_array() else {
                return Err(format!("{} must contain non-empty strings", name));
            };
            if items
                .iter()
                .any(|item| item.as_str().map(|s| s.trim().is_empty()).unwrap_or(true))
            {
                return Err(format!("{} must contain non-empty strings", name));
            }
        }
    }

    let path = cfg.settings_path();
    let mut document = parse_yaml_mapping(&path)?;
    let mut set = |key: &str, value: Value| {
        document.insert(key.to_string(), value);
    };
    for key in [
        "defaultThinkingLevel",
        "hideThinkingBlock",
        "externalThinking",
        "textVerbosity",
        "personality",
        "enabledModels",
        "disabledProviders",
        "modelProviderOrder",
    ] {
        if let Some(value) = object.get(key) {
            set(key, value.clone());
        }
    }
    if let Some(providers) = object.get("providers") {
        let entry = document
            .entry("providers".to_string())
            .or_insert_with(|| Value::Object(Map::new()));
        if let Some(map) = entry.as_object_mut() {
            if let Some(value) = providers.get("autoThinkingSource") {
                map.insert("autoThinkingSource".into(), value.clone());
            }
        }
    }
    for key in [
        "advisor",
        "retry",
        "compaction",
        "memory",
        "autolearn",
        "mnemopi",
        "mcp",
    ] {
        if let Some(value) = object.get(key).and_then(Value::as_object) {
            let entry = document
                .entry(key.to_string())
                .or_insert_with(|| Value::Object(Map::new()));
            if let Some(map) = entry.as_object_mut() {
                for (field, field_value) in value {
                    map.insert(field.clone(), field_value.clone());
                }
            }
        }
    }
    if let Some(tools) = object.get("tools") {
        let entry = document
            .entry("tools".to_string())
            .or_insert_with(|| Value::Object(Map::new()));
        if let Some(map) = entry.as_object_mut() {
            if let Some(value) = tools.get("approvalMode") {
                map.insert("approvalMode".into(), value.clone());
            }
            if let Some(approval) = tools.get("approval").and_then(Value::as_object) {
                let nested = map
                    .entry("approval".to_string())
                    .or_insert_with(|| Value::Object(Map::new()));
                if let Some(nested) = nested.as_object_mut() {
                    for (field, value) in approval {
                        nested.insert(field.clone(), value.clone());
                    }
                }
            }
        }
    }
    if let Some(skills) = object.get("skills") {
        let entry = document
            .entry("skills".to_string())
            .or_insert_with(|| Value::Object(Map::new()));
        if let Some(map) = entry.as_object_mut() {
            if let Some(value) = skills.get("showStartupDiagnostics") {
                map.insert("showStartupDiagnostics".into(), value.clone());
            }
        }
    }
    write_yaml_mapping(&path, &document)?;
    Ok(read_native_settings(cfg)?
        .get("settings")
        .cloned()
        .unwrap_or_else(|| json!({})))
}

pub fn read_model_roles(cfg: &Config) -> Result<Value, String> {
    let path = cfg.settings_path();
    let document = parse_yaml_mapping(&path)?;
    let roles = document
        .get("modelRoles")
        .and_then(Value::as_object)
        .map(|roles| {
            let mut out = Map::new();
            for (key, value) in roles {
                if let Some(value) = value.as_str() {
                    out.insert(key.clone(), Value::String(value.to_string()));
                }
            }
            Value::Object(out)
        })
        .unwrap_or_else(|| json!({}));
    Ok(json!({ "path": path.to_string_lossy(), "roles": roles }))
}

pub fn write_model_roles(cfg: &Config, roles: &Map<String, Value>) -> Result<(), String> {
    let path = cfg.settings_path();
    let mut document = parse_yaml_mapping(&path)?;
    document.insert("modelRoles".into(), Value::Object(roles.clone()));
    write_yaml_mapping(&path, &document)
}

pub fn read_disabled_providers(cfg: &Config) -> HashSet<String> {
    let Ok(document) = parse_yaml_mapping(&cfg.settings_path()) else {
        return HashSet::new();
    };
    string_array(document.get("disabledProviders"))
        .unwrap_or_default()
        .into_iter()
        .collect()
}

pub fn read_anthropic_slow_mode(cfg: &Config) -> bool {
    let Ok(document) = parse_yaml_mapping(&cfg.settings_path()) else {
        return false;
    };
    let nested = document
        .get("providers")
        .and_then(|p| p.get("anthropic"))
        .and_then(|a| a.get("slowMode"))
        .and_then(Value::as_str);
    let dotted = document
        .get("providers.anthropic.slowMode")
        .and_then(Value::as_str);
    nested.or(dotted) == Some("auto")
}

// ============================================================================
// omp child environment (`web-settings.json` → agentEnv)
// ============================================================================

pub const DENIED_ENV_NAMES: &[&str] = &[
    "PATH",
    "PATHEXT",
    "COMSPEC",
    "SYSTEMROOT",
    "WINDIR",
    "NODE_OPTIONS",
    "HOME",
    "USERPROFILE",
    "HOMEDRIVE",
    "HOMEPATH",
    "XDG_DATA_HOME",
    "XDG_CONFIG_HOME",
    "PI_CODING_AGENT_DIR",
    "PI_CONFIG_DIR",
    "OMP_PROFILE",
    "PI_PROFILE",
    "PORT",
    "NODE_ENV",
];
pub const DENIED_ENV_PREFIXES: &[&str] = &["OMP_WEB_", "NEXT_", "_"];

pub fn valid_env_name(name: &str) -> bool {
    let mut chars = name.chars();
    match chars.next() {
        Some(c) if c.is_ascii_alphabetic() || c == '_' => {}
        _ => return false,
    }
    if !chars.all(|c| c.is_ascii_alphanumeric() || c == '_') {
        return false;
    }
    let upper = name.to_uppercase();
    !DENIED_ENV_NAMES.contains(&upper.as_str())
        && !DENIED_ENV_PREFIXES
            .iter()
            .any(|prefix| upper.starts_with(prefix))
}

pub fn sanitize_agent_env(input: &Map<String, Value>) -> (Map<String, Value>, Vec<String>) {
    let mut values = Map::new();
    let mut errors = Vec::new();
    for (name, value) in input {
        let Some(value) = value.as_str() else {
            continue;
        };
        if !valid_env_name(name) {
            errors.push(format!(
                "\"{}\" is not a valid or allowed variable name",
                name
            ));
            continue;
        }
        values.insert(name.clone(), Value::String(value.to_string()));
    }
    (values, errors)
}

pub fn parse_agent_env_text(raw: &str) -> (Map<String, Value>, Vec<String>) {
    let mut values = Map::new();
    let mut errors = Vec::new();
    for (index, raw_line) in raw.split('\n').enumerate() {
        let line_number = index + 1;
        let trimmed = raw_line.trim();
        if trimmed.is_empty() || trimmed.starts_with('#') {
            continue;
        }
        let body = trimmed
            .strip_prefix("export ")
            .unwrap_or(trimmed)
            .trim_start();
        let Some((name, value)) = body.split_once('=') else {
            errors.push(format!("Line {}: expected KEY=VALUE", line_number));
            continue;
        };
        let name = name.trim();
        let value = value.trim();
        if name.is_empty() {
            errors.push(format!("Line {}: missing variable name", line_number));
            continue;
        }
        if !name.chars().enumerate().all(|(i, c)| {
            if i == 0 {
                c.is_ascii_alphabetic() || c == '_'
            } else {
                c.is_ascii_alphanumeric() || c == '_'
            }
        }) {
            errors.push(format!(
                "Line {}: \"{}\" is not a valid variable name",
                line_number, name
            ));
            continue;
        }
        if !valid_env_name(name) {
            errors.push(format!(
                "Line {}: \"{}\" is reserved by AIDesk and cannot be set",
                line_number, name
            ));
            continue;
        }
        values.insert(name.to_string(), Value::String(value.to_string()));
    }
    (values, errors)
}

/// Values from web-settings `agentEnv`, re-validated here so a hand-edited
/// settings file cannot smuggle a reserved variable into a spawned child.
pub fn agent_env_overrides(cfg: &Config) -> Vec<(String, String)> {
    let path = cfg.existing_web_settings_path();
    let parsed = std::fs::read_to_string(&path)
        .ok()
        .and_then(|text| serde_json::from_str::<Value>(&text).ok())
        .and_then(|value| value.as_object().cloned())
        .unwrap_or_default();
    let Some(object) = parsed.get("agentEnv").and_then(Value::as_object) else {
        return Vec::new();
    };
    let (values, _) = sanitize_agent_env(object);
    values
        .iter()
        .filter_map(|(name, value)| {
            value
                .as_str()
                .map(|value| (name.clone(), value.to_string()))
        })
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    fn temp_config() -> (std::path::PathBuf, Config) {
        let dir = std::env::temp_dir().join(format!("aidesk-settings-{}", uuid::Uuid::new_v4()));
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
            port: Some(0),
            host: "127.0.0.1".into(),
            stt: None,
        };
        (dir, cfg)
    }

    #[test]
    fn native_settings_roundtrip_preserves_unrelated_keys() {
        let (dir, cfg) = temp_config();
        std::fs::write(
            cfg.settings_path(),
            "theme: dark\ntools:\n  approvalMode: write\n",
        )
        .unwrap();
        let settings =
            json!({ "settings": { "defaultThinkingLevel": "high", "hideThinkingBlock": true } });
        write_native_settings(&cfg, &settings["settings"]).unwrap();
        let read = read_native_settings(&cfg).unwrap();
        assert_eq!(read["settings"]["defaultThinkingLevel"], json!("high"));
        let text = std::fs::read_to_string(cfg.settings_path()).unwrap();
        assert!(text.contains("theme: dark"));
        let _ = std::fs::remove_dir_all(dir);
    }

    #[test]
    fn invalid_settings_are_rejected() {
        let (dir, cfg) = temp_config();
        let error =
            write_native_settings(&cfg, &json!({ "defaultThinkingLevel": "ultra" })).unwrap_err();
        assert!(error.contains("thinking level"));
        let _ = std::fs::remove_dir_all(dir);
    }

    #[test]
    fn model_roles_roundtrip() {
        let (dir, cfg) = temp_config();
        let mut roles = Map::new();
        roles.insert("default".into(), json!("anthropic/claude"));
        write_model_roles(&cfg, &roles).unwrap();
        assert_eq!(
            read_model_roles(&cfg).unwrap()["roles"]["default"],
            json!("anthropic/claude")
        );
        let _ = std::fs::remove_dir_all(dir);
    }
}
