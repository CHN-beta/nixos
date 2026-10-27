//! The explicit workspace registry (`<agent>/omp-web/projects.json`).

use crate::config::Config;
use crate::omp::session_reader::resolve_project;
use crate::util::{atomic_write, iso_from_ms, now_ms, path_key};
use serde_json::{json, Map, Value};
use std::path::{Path, PathBuf};

const MAX_EXTRA_ARGS: usize = 32;
const MAX_EXTRA_ARG_LENGTH: usize = 256;
const RESERVED_LAUNCH_ARGS: &[&str] = &["--mode", "rpc-ui", "--cwd", "--resume"];
const RESERVED_LAUNCH_PREFIXES: &[&str] = &["--mode=", "--cwd=", "--resume="];

pub fn is_reserved_launch_arg(arg: &str) -> bool {
    RESERVED_LAUNCH_ARGS.contains(&arg)
        || RESERVED_LAUNCH_PREFIXES
            .iter()
            .any(|prefix| arg.starts_with(prefix))
}

#[derive(Debug, Clone)]
pub struct ProjectEntry {
    pub path: String,
    pub added_at: String,
    pub hidden: bool,
    pub alias: Option<String>,
    pub sort_order: Option<f64>,
    pub launch_config: Option<Value>,
}

impl ProjectEntry {
    fn to_json(&self, include_metadata: bool) -> Value {
        let mut object = Map::new();
        object.insert("path".into(), Value::String(self.path.clone()));
        if include_metadata {
            object.insert("addedAt".into(), Value::String(self.added_at.clone()));
            object.insert("hidden".into(), Value::Bool(self.hidden));
            if let Some(alias) = &self.alias {
                object.insert("alias".into(), Value::String(alias.clone()));
            }
            if let Some(sort_order) = self.sort_order {
                object.insert("sortOrder".into(), Value::from(sort_order));
            }
            if let Some(launch_config) = &self.launch_config {
                object.insert("launchConfig".into(), launch_config.clone());
            }
        } else {
            if let Some(alias) = &self.alias {
                object.insert("alias".into(), Value::String(alias.clone()));
            }
            if let Some(sort_order) = self.sort_order {
                object.insert("sortOrder".into(), Value::from(sort_order));
            }
            if let Some(launch_config) = &self.launch_config {
                object.insert("launchConfig".into(), launch_config.clone());
            }
        }
        Value::Object(object)
    }
}

/// Parse a workspace-level omp launch config; `Err` carries a stable code.
pub fn parse_launch_config(value: Option<&Value>) -> Result<Option<Value>, (&'static str, String)> {
    let Some(value) = value else { return Ok(None) };
    if value.is_null() {
        return Ok(None);
    }
    let Some(raw) = value.as_object() else {
        return Err((
            "invalid_launch_config",
            "Launch config must be an object".into(),
        ));
    };
    let profile = match raw.get("profile") {
        None | Some(Value::Null) => None,
        Some(Value::String(text)) => {
            let trimmed = text.trim();
            if trimmed.is_empty() {
                return Err((
                    "invalid_profile",
                    "Profile must be a non-empty string".into(),
                ));
            }
            if trimmed.starts_with('-') {
                return Err(("invalid_profile", "Profile must not start with '-'".into()));
            }
            Some(trimmed.to_string())
        }
        Some(_) => {
            return Err((
                "invalid_profile",
                "Profile must be a non-empty string".into(),
            ))
        }
    };
    let advisor = match raw.get("advisor") {
        None | Some(Value::Null) => None,
        Some(Value::Bool(value)) => Some(*value),
        Some(_) => return Err(("invalid_advisor", "Advisor must be a boolean".into())),
    };
    let extra_args = match raw.get("extraArgs") {
        None | Some(Value::Null) => None,
        Some(Value::Array(items)) => {
            if items.len() > MAX_EXTRA_ARGS {
                return Err((
                    "invalid_extra_args",
                    "Extra args must contain at most 32 arguments".into(),
                ));
            }
            let mut args = Vec::new();
            for item in items {
                let Some(arg) = item.as_str() else {
                    return Err((
                        "invalid_extra_args",
                        "Extra args contain an invalid or reserved argument".into(),
                    ));
                };
                if arg.is_empty() || arg.len() > MAX_EXTRA_ARG_LENGTH || is_reserved_launch_arg(arg)
                {
                    return Err((
                        "invalid_extra_args",
                        "Extra args contain an invalid or reserved argument".into(),
                    ));
                }
                args.push(Value::String(arg.to_string()));
            }
            Some(args)
        }
        Some(_) => {
            return Err((
                "invalid_extra_args",
                "Extra args must contain at most 32 arguments".into(),
            ))
        }
    };
    let mut out = Map::new();
    if let Some(profile) = profile {
        out.insert("profile".into(), Value::String(profile));
    }
    if let Some(advisor) = advisor {
        out.insert("advisor".into(), Value::Bool(advisor));
    }
    if let Some(extra_args) = &extra_args {
        if !extra_args.is_empty() {
            out.insert("extraArgs".into(), Value::Array(extra_args.clone()));
        }
    }
    if out.is_empty() {
        Ok(None)
    } else {
        Ok(Some(Value::Object(out)))
    }
}

fn parse_entry(item: &Value) -> Option<ProjectEntry> {
    let path = item.get("path").and_then(Value::as_str)?.trim();
    if path.is_empty() {
        return None;
    }
    let canonical = crate::util::canonical_or_original(Path::new(path));
    let added_at = item
        .get("addedAt")
        .and_then(Value::as_str)
        .map(|s| s.to_string())
        .unwrap_or_else(|| iso_from_ms(0.0));
    let launch_config = parse_launch_config(item.get("launchConfig")).ok().flatten();
    Some(ProjectEntry {
        path: canonical.to_string_lossy().into_owned(),
        added_at,
        hidden: item.get("hidden").and_then(Value::as_bool) == Some(true),
        alias: item
            .get("alias")
            .and_then(Value::as_str)
            .map(|s| s.trim())
            .filter(|s| !s.is_empty())
            .map(|s| s.to_string()),
        sort_order: item.get("sortOrder").and_then(Value::as_f64),
        launch_config,
    })
}

pub fn load_registry(cfg: &Config) -> Vec<ProjectEntry> {
    let path = cfg.existing_projects_path();
    let Ok(text) = std::fs::read_to_string(&path) else {
        return Vec::new();
    };
    let Ok(value) = serde_json::from_str::<Value>(&text) else {
        return Vec::new();
    };
    value
        .get("projects")
        .and_then(Value::as_array)
        .map(|items| items.iter().filter_map(parse_entry).collect())
        .unwrap_or_default()
}

pub fn save_registry(cfg: &Config, entries: &[ProjectEntry]) -> std::io::Result<()> {
    let body = json!({ "version": 1, "projects": entries.iter().map(|entry| entry.to_json(true)).collect::<Vec<_>>() });
    let text = format!(
        "{}\n",
        serde_json::to_string_pretty(&body).unwrap_or_default()
    );
    atomic_write(&cfg.projects_path(), text.as_bytes())
}

pub fn validate_project_path(cfg: &Config, cwd: &str) -> Result<PathBuf, (&'static str, String)> {
    let trimmed = cwd.trim();
    if trimmed.is_empty() {
        return Err(("path_required", "Path is required".into()));
    }
    let normalized = if trimmed == "~" {
        cfg.home.clone()
    } else if let Some(rest) = trimmed.strip_prefix("~/") {
        crate::util::expand_tilde(&format!("~/{}", rest), &cfg.home)
    } else {
        PathBuf::from(trimmed)
    };
    let absolute = crate::util::absolute_path(&normalized);
    let meta = std::fs::metadata(&absolute).map_err(|_| {
        (
            "directory_not_found",
            format!("Directory does not exist: {}", cwd),
        )
    })?;
    if !meta.is_dir() {
        return Err((
            "not_a_directory",
            format!("Path is not a directory: {}", cwd),
        ));
    }
    Ok(absolute)
}

pub fn upsert(entries: &mut Vec<ProjectEntry>, path: &Path, launch_config: Option<Value>) {
    let canonical = crate::util::canonical_or_original(path);
    let key = path_key(&canonical);
    let existing = entries
        .iter()
        .find(|entry| path_key(Path::new(&entry.path)) == key)
        .cloned();
    entries.retain(|entry| path_key(Path::new(&entry.path)) != key);
    entries.push(ProjectEntry {
        path: canonical.to_string_lossy().into_owned(),
        added_at: iso_from_ms(now_ms()),
        hidden: false,
        alias: None,
        sort_order: None,
        launch_config: launch_config.or_else(|| existing.and_then(|entry| entry.launch_config)),
    });
}

pub fn hide(entries: &mut Vec<ProjectEntry>, path: &Path) {
    let canonical = crate::util::canonical_or_original(path);
    let key = path_key(&canonical);
    if let Some(entry) = entries
        .iter_mut()
        .find(|entry| path_key(Path::new(&entry.path)) == key)
    {
        entry.hidden = true;
        return;
    }
    entries.push(ProjectEntry {
        path: canonical.to_string_lossy().into_owned(),
        added_at: iso_from_ms(now_ms()),
        hidden: true,
        alias: None,
        sort_order: None,
        launch_config: None,
    });
}

pub fn update_presentation(
    entries: &mut [ProjectEntry],
    updates: &[(
        String,
        Option<Option<String>>,
        Option<Option<f64>>,
        Option<Option<Value>>,
    )],
) {
    for entry in entries.iter_mut() {
        let key = path_key(Path::new(&entry.path));
        let Some((_, alias, sort_order, launch_config)) = updates
            .iter()
            .find(|(path, _, _, _)| path_key(Path::new(path)) == key)
        else {
            continue;
        };
        if let Some(alias) = alias {
            entry.alias = alias.clone();
        }
        if let Some(sort_order) = sort_order {
            entry.sort_order = *sort_order;
        }
        if let Some(launch_config) = launch_config {
            entry.launch_config = launch_config.clone();
        }
    }
}

/// Registered (non-hidden) projects merged with session-discovered ones.
pub fn merge_projects(entries: &[ProjectEntry], discovered: Vec<String>) -> Vec<Value> {
    let mut registered: Vec<ProjectEntry> = entries
        .iter()
        .filter(|entry| !entry.hidden)
        .cloned()
        .collect();
    registered.sort_by(|a, b| {
        let left = a.sort_order.unwrap_or(f64::INFINITY);
        let right = b.sort_order.unwrap_or(f64::INFINITY);
        left.partial_cmp(&right)
            .unwrap_or(std::cmp::Ordering::Equal)
            .then_with(|| b.added_at.cmp(&a.added_at))
    });
    let hidden: std::collections::HashSet<String> = entries
        .iter()
        .filter(|entry| entry.hidden)
        .map(|entry| path_key(Path::new(&entry.path)))
        .collect();
    let seen: std::collections::HashSet<String> = registered
        .iter()
        .map(|entry| path_key(Path::new(&entry.path)))
        .collect();
    let mut merged: Vec<Value> = Vec::new();
    let mut registered_seen: std::collections::HashSet<String> = std::collections::HashSet::new();
    for entry in &registered {
        let key = path_key(Path::new(&entry.path));
        if registered_seen.insert(key) {
            merged.push(entry.to_json(false));
        }
    }
    let mut extra: Vec<(String, Value)> = Vec::new();
    let mut extra_seen = std::collections::HashSet::new();
    for raw in discovered {
        if raw.is_empty() {
            continue;
        }
        let canonical = crate::util::canonical_or_original(Path::new(&raw));
        let key = path_key(&canonical);
        if hidden.contains(&key) || !extra_seen.insert(key) {
            continue;
        }
        if seen.contains(&path_key(&canonical)) {
            continue;
        }
        extra.push((
            canonical.to_string_lossy().into_owned(),
            json!({ "path": canonical.to_string_lossy() }),
        ));
    }
    extra.sort_by(|a, b| a.0.cmp(&b.0));
    merged.extend(extra.into_iter().map(|(_, value)| value));
    merged
}

/// Launch config for a cwd (worktrees inherit their main repo's config).
pub fn launch_config_for_cwd(cfg: &Config, cwd: &str) -> Option<Value> {
    let canonical = crate::util::canonical_or_original(Path::new(cwd));
    let key = path_key(&canonical);
    let entries = load_registry(cfg);
    for entry in entries {
        if entry.hidden {
            continue;
        }
        let project_key = path_key(Path::new(&entry.path));
        if key == project_key || key.starts_with(&format!("{}-worktrees/", project_key)) {
            return entry.launch_config;
        }
    }
    None
}

/// `{ projectRoot, isWorktree }` for the validate endpoint.
pub fn project_identity(cwd: &Path) -> (String, String) {
    let project = resolve_project(&cwd.to_string_lossy());
    (
        project.project_root.clone(),
        path_key(Path::new(&project.project_root)),
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn launch_config_rejects_reserved_args() {
        let value = json!({ "extraArgs": ["--resume", "x"] });
        assert!(parse_launch_config(Some(&value)).is_err());
        let ok = json!({ "profile": "work", "advisor": true });
        assert!(parse_launch_config(Some(&ok)).unwrap().is_some());
    }

    #[test]
    fn merge_skips_hidden_and_duplicates() {
        let entries = vec![
            ProjectEntry {
                path: "/tmp/a".into(),
                added_at: "2026-01-01T00:00:00.000Z".into(),
                hidden: false,
                alias: None,
                sort_order: None,
                launch_config: None,
            },
            ProjectEntry {
                path: "/tmp/b".into(),
                added_at: "2026-01-01T00:00:00.000Z".into(),
                hidden: true,
                alias: None,
                sort_order: None,
                launch_config: None,
            },
        ];
        let merged = merge_projects(&entries, vec!["/tmp/b".into(), "/tmp/c".into()]);
        assert_eq!(merged.len(), 2);
        assert_eq!(merged[0]["path"], json!("/tmp/a"));
        assert_eq!(merged[1]["path"], json!("/tmp/c"));
    }
}
