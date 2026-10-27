//! `models.yml` reading/writing for the custom-model editor.

use crate::config::Config;
use serde_json::{json, Map, Value};
use std::path::Path;

pub struct ModelsConfigFile {
    pub path: String,
    pub exists: bool,
    pub config: Value,
    pub parse_error: Option<String>,
}

fn sanitize(config: Value) -> Value {
    let mut object = match config {
        Value::Object(object) => object,
        other => return other,
    };
    if let Some(providers) = object.get_mut("providers").and_then(Value::as_object_mut) {
        for (_, provider) in providers.iter_mut() {
            let Some(provider) = provider.as_object_mut() else {
                continue;
            };
            if let Some(models) = provider.get_mut("models").and_then(Value::as_array_mut) {
                models.retain(|model| match model.as_object() {
                    Some(model) => model
                        .get("id")
                        .and_then(Value::as_str)
                        .map(|id| !id.trim().is_empty())
                        .unwrap_or(true),
                    None => true,
                });
            }
        }
    }
    Value::Object(object)
}

pub fn read_models_config_file(cfg: &Config) -> ModelsConfigFile {
    let path = cfg.models_config_path();
    let empty = json!({ "providers": {} });
    if !path.exists() {
        return ModelsConfigFile {
            path: path.to_string_lossy().into_owned(),
            exists: false,
            config: empty,
            parse_error: None,
        };
    }
    let source = match std::fs::read_to_string(&path) {
        Ok(source) => source,
        Err(error) => {
            return ModelsConfigFile {
                path: path.to_string_lossy().into_owned(),
                exists: true,
                config: empty,
                parse_error: Some(error.to_string()),
            }
        }
    };
    let parsed: Value = match serde_yaml_ng::from_str(&source) {
        Ok(value) => value,
        Err(error) => {
            return ModelsConfigFile {
                path: path.to_string_lossy().into_owned(),
                exists: true,
                config: empty,
                parse_error: Some(error.to_string()),
            }
        }
    };
    if parsed.is_null() {
        return ModelsConfigFile {
            path: path.to_string_lossy().into_owned(),
            exists: true,
            config: empty,
            parse_error: None,
        };
    }
    if !parsed.is_object() {
        return ModelsConfigFile {
            path: path.to_string_lossy().into_owned(),
            exists: true,
            config: empty,
            parse_error: Some("the top level of models.yml must be a mapping".into()),
        };
    }
    ModelsConfigFile {
        path: path.to_string_lossy().into_owned(),
        exists: true,
        config: sanitize(parsed),
        parse_error: None,
    }
}

/// Reject configs omp itself would refuse to load.
pub fn validate_models_config(config: &Value) -> Result<(), String> {
    let object = config.as_object().ok_or("Config must be an object")?;
    let providers = match object.get("providers") {
        None | Some(Value::Null) => return Ok(()),
        Some(Value::Object(providers)) => providers,
        Some(_) => return Err("\"providers\" must be an object".into()),
    };
    for (name, provider) in providers {
        let provider = provider
            .as_object()
            .ok_or_else(|| format!("Provider {}: must be an object", name))?;
        let models = provider
            .get("models")
            .and_then(Value::as_array)
            .cloned()
            .unwrap_or_default();
        if !models.is_empty() {
            let has_base_url = provider
                .get("baseUrl")
                .and_then(Value::as_str)
                .map(|value| !value.trim().is_empty())
                .unwrap_or(false);
            if !has_base_url {
                return Err(format!(
                    "Provider {}: \"baseUrl\" is required when defining custom models.",
                    name
                ));
            }
            let auth_none = provider.get("auth").and_then(Value::as_str) == Some("none");
            let has_key = provider
                .get("apiKey")
                .and_then(Value::as_str)
                .map(|value| !value.trim().is_empty())
                .unwrap_or(false);
            if !has_key && !auth_none {
                return Err(format!(
                    "Provider {}: \"apiKey\" is required when defining custom models unless auth is \"none\".",
                    name
                ));
            }
        }
        let mut seen = std::collections::HashSet::new();
        for model in &models {
            let model = model
                .as_object()
                .ok_or_else(|| format!("Provider {}: model must be an object", name))?;
            let id = model
                .get("id")
                .and_then(Value::as_str)
                .filter(|id| !id.trim().is_empty())
                .ok_or_else(|| format!("Provider {}: model missing \"id\"", name))?;
            if !seen.insert(id.to_string()) {
                return Err(format!("Provider {}: duplicate model id {:?}", name, id));
            }
        }
    }
    Ok(())
}

/// Persist the whole config (unknown top-level keys from the request included).
pub fn write_models_config(
    cfg: &Config,
    config: &Value,
    overwrite_unparseable: bool,
) -> Result<(), String> {
    let file = read_models_config_file(cfg);
    if file.parse_error.is_some() && !overwrite_unparseable {
        return Err(format!(
            "{} — fix it by hand; AIDesk will not overwrite it",
            file.parse_error.unwrap_or_default()
        ));
    }
    let path = cfg.models_config_path();
    let text = serde_yaml_ng::to_string(config).map_err(|error| error.to_string())?;
    crate::util::atomic_write(Path::new(&path), text.as_bytes()).map_err(|error| error.to_string())
}

pub fn read_models_config(cfg: &Config) -> Map<String, Value> {
    match read_models_config_file(cfg).config {
        Value::Object(object) => object,
        _ => Map::new(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn custom_models_require_base_url_and_key() {
        let bad = json!({ "providers": { "local": { "models": [{ "id": "m" }] } } });
        assert!(validate_models_config(&bad).is_err());
        let good = json!({
            "providers": {
                "local": {
                    "baseUrl": "http://127.0.0.1:8080",
                    "apiKey": "x",
                    "models": [{ "id": "m" }]
                }
            }
        });
        assert!(validate_models_config(&good).is_ok());
    }

    #[test]
    fn empty_config_is_valid() {
        assert!(validate_models_config(&json!({ "providers": {} })).is_ok());
    }
}
