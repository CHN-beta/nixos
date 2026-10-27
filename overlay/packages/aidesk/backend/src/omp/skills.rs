//! Skill discovery (omp's `skill list --json` with a replica scan fallback)
//! and the disable-model-invocation toggle.

use crate::config::Config;
use crate::state::SharedState;
use serde_json::{json, Map, Value};
use std::collections::HashSet;
use std::path::{Path, PathBuf};
use std::process::Command;

pub const DISABLE_INVOCATION_KEYS: &[&str] =
    &["disable-model-invocation", "disableModelInvocation", "hide"];
const CANONICAL_DISABLE_KEY: &str = "disable-model-invocation";

pub struct ParsedFrontmatter {
    pub frontmatter: Map<String, Value>,
    pub body: String,
}

pub fn parse_skill_frontmatter(content: &str) -> ParsedFrontmatter {
    let normalized = content.replace("\r\n", "\n");
    let Some(rest) = normalized.strip_prefix("---\n") else {
        return ParsedFrontmatter {
            frontmatter: Map::new(),
            body: content.to_string(),
        };
    };
    let Some(end) = rest.find("\n---") else {
        return ParsedFrontmatter {
            frontmatter: Map::new(),
            body: content.to_string(),
        };
    };
    let block = &rest[..end];
    let after = &rest[end + 4..];
    let body = after.strip_prefix('\n').unwrap_or(after);
    let frontmatter = serde_yaml_ng::from_str::<Value>(block)
        .ok()
        .and_then(|value| match value {
            Value::Object(object) => Some(object),
            _ => None,
        })
        .unwrap_or_default();
    ParsedFrontmatter {
        frontmatter,
        body: body.to_string(),
    }
}

fn is_truthy_flag(value: Option<&Value>) -> bool {
    match value {
        Some(Value::Bool(true)) => true,
        Some(Value::String(text)) => text == "true",
        _ => false,
    }
}

pub fn read_disable_model_invocation(frontmatter: &Map<String, Value>) -> bool {
    DISABLE_INVOCATION_KEYS
        .iter()
        .any(|key| is_truthy_flag(frontmatter.get(*key)))
}

/// Set/clear the flag, editing an existing spelling rather than adding a
/// second copy.
pub fn set_disable_model_invocation(content: &str, disable: bool) -> String {
    let eol = if content.contains("\r\n") {
        "\r\n"
    } else {
        "\n"
    };
    let normalized = content.replace("\r\n", "\n");
    let Some(rest) = normalized.strip_prefix("---\n") else {
        return if disable {
            format!("---\n{}: true\n---\n{}", CANONICAL_DISABLE_KEY, content)
        } else {
            content.to_string()
        };
    };
    let Some(end) = rest.find("\n---") else {
        return if disable {
            format!("---\n{}: true\n---\n{}", CANONICAL_DISABLE_KEY, content)
        } else {
            content.to_string()
        };
    };
    let block = &rest[..end];
    let after = &normalized[end + 4..];
    let lines: Vec<String> = block.split('\n').map(|line| line.to_string()).collect();
    let hits: Vec<usize> = lines
        .iter()
        .enumerate()
        .filter(|(_, line)| {
            DISABLE_INVOCATION_KEYS.iter().any(|key| {
                let trimmed = line.trim_start();
                trimmed.starts_with(&format!("{}:", key))
            })
        })
        .map(|(index, _)| index)
        .collect();
    let next: Vec<String> = if disable {
        if hits.is_empty() {
            let mut next = vec![format!("{}: true", CANONICAL_DISABLE_KEY)];
            next.extend(lines);
            next
        } else {
            let keep = hits[0];
            let key_name = lines[keep]
                .trim_start()
                .split(':')
                .next()
                .unwrap_or(CANONICAL_DISABLE_KEY)
                .to_string();
            lines
                .iter()
                .enumerate()
                .filter(|(index, _)| *index == keep || !hits.contains(index))
                .map(|(index, line)| {
                    if index == keep {
                        format!("{}: true", key_name)
                    } else {
                        line.clone()
                    }
                })
                .collect()
        }
    } else {
        if hits.is_empty() {
            return content.to_string();
        }
        lines
            .iter()
            .enumerate()
            .filter(|(index, _)| !hits.contains(index))
            .map(|(_, line)| line.clone())
            .collect()
    };
    let restored_after = after.replace('\n', eol);
    format!("---{}{}{}---{}", eol, next.join(eol), eol, restored_after)
}

fn home_dir() -> PathBuf {
    PathBuf::from(std::env::var("HOME").unwrap_or_else(|_| "/".into()))
}

fn ancestor_dirs(cwd: &Path) -> Vec<PathBuf> {
    let home = home_dir();
    let mut dirs = Vec::new();
    let mut current = crate::util::absolute_path(cwd);
    loop {
        dirs.push(current.clone());
        if current.join(".git").exists() {
            break;
        }
        if current == home {
            break;
        }
        match current.parent() {
            Some(parent) if parent != current => current = parent.to_path_buf(),
            _ => break,
        }
    }
    dirs
}

struct ScanRoot {
    dir: PathBuf,
    source: &'static str,
    scope: &'static str,
    require_description: bool,
}

fn build_scan_roots(cfg: &Config, cwd: &Path) -> Vec<ScanRoot> {
    let home = home_dir();
    let agent_dir = &cfg.agent_dir;
    let ancestors = ancestor_dirs(cwd);
    let project_ancestors: Vec<&PathBuf> = ancestors.iter().filter(|dir| **dir != home).collect();
    let mut roots = Vec::new();
    for dir in &project_ancestors {
        roots.push(ScanRoot {
            dir: dir.join(".omp").join("skills"),
            source: ".omp",
            scope: "project",
            require_description: true,
        });
    }
    roots.push(ScanRoot {
        dir: agent_dir.join("skills"),
        source: ".omp",
        scope: "user",
        require_description: true,
    });
    let claude_home = std::env::var("CLAUDE_CONFIG_DIR")
        .ok()
        .map(PathBuf::from)
        .unwrap_or_else(|| home.join(".claude"));
    roots.push(ScanRoot {
        dir: claude_home.join("skills"),
        source: ".claude",
        scope: "user",
        require_description: false,
    });
    for dir in &project_ancestors {
        roots.push(ScanRoot {
            dir: dir.join(".claude").join("skills"),
            source: ".claude",
            scope: "project",
            require_description: false,
        });
    }
    for dir in &project_ancestors {
        roots.push(ScanRoot {
            dir: dir.join(".agent").join("skills"),
            source: ".agents",
            scope: "project",
            require_description: false,
        });
        roots.push(ScanRoot {
            dir: dir.join(".agents").join("skills"),
            source: ".agents",
            scope: "project",
            require_description: false,
        });
    }
    for dir in [
        home.join(".agent").join("skills"),
        home.join(".agents").join("skills"),
    ] {
        roots.push(ScanRoot {
            dir,
            source: ".agents",
            scope: "user",
            require_description: false,
        });
    }
    roots.push(ScanRoot {
        dir: home.join(".codex").join("skills"),
        source: ".codex",
        scope: "user",
        require_description: false,
    });
    roots.push(ScanRoot {
        dir: cwd.join(".codex").join("skills"),
        source: ".codex",
        scope: "project",
        require_description: false,
    });
    let repo_root = ancestors
        .last()
        .cloned()
        .unwrap_or_else(|| cwd.to_path_buf());
    roots.push(ScanRoot {
        dir: repo_root.join(".github").join("skills"),
        source: ".github",
        scope: "project",
        require_description: true,
    });
    roots.push(ScanRoot {
        dir: agent_dir.join("managed-skills"),
        source: "managed",
        scope: "user",
        require_description: true,
    });
    roots
}

fn scan_root(root: &ScanRoot, diagnostics: &mut Vec<Value>) -> Vec<Value> {
    let mut skills = Vec::new();
    let entries = match std::fs::read_dir(&root.dir) {
        Ok(entries) => entries,
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => return skills,
        Err(error) => {
            diagnostics.push(json!({
                "type": "warning",
                "message": format!("Failed to read skills directory: {}", error),
                "path": root.dir.to_string_lossy(),
            }));
            return skills;
        }
    };
    for entry in entries.flatten() {
        let name = entry.file_name().to_string_lossy().into_owned();
        if name.starts_with('.') {
            continue;
        }
        let Ok(file_type) = entry.file_type() else {
            continue;
        };
        if !file_type.is_dir() && !file_type.is_symlink() {
            continue;
        }
        let skill_path = entry.path().join("SKILL.md");
        let content = match std::fs::read_to_string(&skill_path) {
            Ok(content) => content,
            Err(error) if error.kind() == std::io::ErrorKind::NotFound => continue,
            Err(_) => {
                diagnostics.push(json!({
                    "type": "warning",
                    "message": "Failed to read skill file",
                    "path": skill_path.to_string_lossy(),
                }));
                continue;
            }
        };
        let parsed = parse_skill_frontmatter(&content);
        if parsed.frontmatter.get("enabled").and_then(Value::as_bool) == Some(false) {
            continue;
        }
        let description = parsed
            .frontmatter
            .get("description")
            .and_then(Value::as_str)
            .unwrap_or("")
            .to_string();
        if root.require_description && description.is_empty() {
            continue;
        }
        let skill_name = parsed
            .frontmatter
            .get("name")
            .and_then(Value::as_str)
            .map(|value| value.trim())
            .filter(|value| !value.is_empty())
            .unwrap_or(&name)
            .to_string();
        skills.push(json!({
            "name": skill_name,
            "description": description,
            "filePath": skill_path.to_string_lossy(),
            "baseDir": entry.path().to_string_lossy(),
            "disableModelInvocation": read_disable_model_invocation(&parsed.frontmatter),
            "sourceInfo": { "source": root.source, "scope": root.scope },
        }));
    }
    skills
}

fn skills_from_cli_payload(data: &Value) -> Option<Value> {
    let skills = data.get("skills")?.as_array()?;
    let mut mapped = Vec::new();
    for raw in skills {
        let name = raw.get("name").and_then(Value::as_str)?;
        let file_path = raw.get("filePath").and_then(Value::as_str)?;
        let source = raw.get("source").and_then(Value::as_str).unwrap_or("");
        let mut parts = source.splitn(2, ':');
        let provider = parts.next().unwrap_or("");
        let scope = parts.next().unwrap_or("");
        let label = match provider {
            "native" => ".omp",
            "claude" => ".claude",
            "agents" => ".agents",
            "codex" => ".codex",
            "github" => ".github",
            "omp-managed" => "managed",
            other => other,
        };
        let base_dir = raw
            .get("baseDir")
            .and_then(Value::as_str)
            .map(|value| value.to_string())
            .unwrap_or_else(|| {
                Path::new(file_path)
                    .parent()
                    .map(|parent| parent.to_string_lossy().into_owned())
                    .unwrap_or_default()
            });
        mapped.push(json!({
            "name": name,
            "description": raw.get("description").and_then(Value::as_str).unwrap_or(""),
            "filePath": file_path,
            "baseDir": base_dir,
            "disableModelInvocation": raw.get("hide").and_then(Value::as_bool).unwrap_or(false),
            "sourceInfo": { "source": label, "scope": scope },
        }));
    }
    if !skills.is_empty() && mapped.is_empty() {
        return None;
    }
    let mut diagnostics = Vec::new();
    for raw in data
        .get("warnings")
        .and_then(Value::as_array)
        .cloned()
        .unwrap_or_default()
    {
        let Some(message) = raw.get("message").and_then(Value::as_str) else {
            continue;
        };
        let mut diagnostic = Map::new();
        diagnostic.insert("type".into(), Value::String("warning".into()));
        diagnostic.insert("message".into(), Value::String(message.to_string()));
        if let Some(path) = raw.get("skillPath").and_then(Value::as_str) {
            diagnostic.insert("path".into(), Value::String(path.to_string()));
        }
        diagnostics.push(Value::Object(diagnostic));
    }
    Some(json!({ "skills": mapped, "diagnostics": diagnostics }))
}

/// Prefer `omp skill list --json` (authoritative, includes aliases), falling
/// back to the replica scan.
pub fn discover_skills(state: &SharedState, cwd: &Path) -> Value {
    if let Some(bin) = &state.cfg.omp_bin {
        let output = Command::new(bin)
            .args(["skill", "list", "--json"])
            .current_dir(cwd)
            .env("LC_ALL", "C")
            .output();
        if let Ok(output) = output {
            if output.status.success() {
                if let Ok(data) = serde_json::from_slice::<Value>(&output.stdout) {
                    if let Some(listed) = skills_from_cli_payload(&data) {
                        return listed;
                    }
                }
            }
        }
    }
    let mut diagnostics = Vec::new();
    let mut by_name: Vec<(String, Value)> = Vec::new();
    let mut seen: HashSet<String> = HashSet::new();
    for root in build_scan_roots(&state.cfg, cwd) {
        for skill in scan_root(&root, &mut diagnostics) {
            let name = skill
                .get("name")
                .and_then(Value::as_str)
                .unwrap_or("")
                .to_string();
            if seen.insert(name.clone()) {
                by_name.push((name, skill));
            }
        }
    }
    by_name.sort_by(|a, b| {
        a.0.to_lowercase().cmp(&b.0.to_lowercase()).then_with(|| {
            a.1.get("filePath")
                .and_then(Value::as_str)
                .unwrap_or("")
                .cmp(b.1.get("filePath").and_then(Value::as_str).unwrap_or(""))
        })
    });
    json!({
        "skills": by_name.into_iter().map(|(_, skill)| skill).collect::<Vec<_>>(),
        "diagnostics": diagnostics,
    })
}

/// Roots a SKILL.md must sit under to be rewritable by PATCH /api/skills.
pub fn skill_toggle_roots(state: &SharedState, cwd: Option<&Path>) -> Vec<PathBuf> {
    let mut roots: Vec<PathBuf> = state.allowed_roots();
    let scan_cwd = match cwd {
        Some(cwd) if state.is_existing_path_allowed(cwd) => Some(cwd.to_path_buf()),
        _ => None,
    };
    for root in build_scan_roots(&state.cfg, scan_cwd.as_deref().unwrap_or(&state.cfg.home)) {
        roots.push(root.dir);
    }
    roots
}

pub fn load_skills_with_install_info(state: &SharedState, cwd: &Path) -> Value {
    let mut result = discover_skills(state, cwd);
    let toggle_roots = skill_toggle_roots(state, Some(cwd));
    let real_roots: Vec<PathBuf> = toggle_roots
        .iter()
        .filter_map(|root| std::fs::canonicalize(root).ok())
        .collect();
    if let Some(skills) = result.get_mut("skills").and_then(Value::as_array_mut) {
        for skill in skills {
            let Some(file_path) = skill.get("filePath").and_then(Value::as_str) else {
                continue;
            };
            let togglable = std::fs::canonicalize(file_path)
                .map(|real| {
                    real_roots
                        .iter()
                        .any(|root| crate::util::is_within(root, &real))
                })
                .unwrap_or(false);
            if let Some(object) = skill.as_object_mut() {
                object.insert("togglable".into(), Value::Bool(togglable));
            }
        }
    }
    result
}

/// Update the disable-model-invocation flag on a SKILL.md.
pub fn toggle_skill(
    state: &SharedState,
    file_path: &str,
    disable: bool,
    cwd: Option<&Path>,
) -> Result<Value, (u16, String, &'static str)> {
    if Path::new(file_path).file_name().and_then(|n| n.to_str()) != Some("SKILL.md") {
        return Err((400, "not a SKILL.md file".into(), "not_a_skill_file"));
    }
    if !Path::new(file_path).exists() {
        return Err((404, "file not found".into(), "file_not_found"));
    }
    let roots = skill_toggle_roots(state, cwd);
    let real_roots: Vec<PathBuf> = roots
        .iter()
        .filter_map(|root| std::fs::canonicalize(root).ok())
        .collect();
    let resolved = std::fs::canonicalize(file_path)
        .map_err(|_| (404u16, "file not found".to_string(), "file_not_found"))?;
    if !real_roots
        .iter()
        .any(|root| crate::util::is_within(root, &resolved))
    {
        return Err((403, "Access denied".into(), "access_denied"));
    }
    let content = std::fs::read_to_string(&resolved)
        .map_err(|error| (500, error.to_string(), "internal_error"))?;
    let updated = set_disable_model_invocation(&content, disable);
    if updated != content {
        std::fs::write(&resolved, updated.as_bytes())
            .map_err(|error| (500, error.to_string(), "internal_error"))?;
    }
    let parsed = parse_skill_frontmatter(&std::fs::read_to_string(&resolved).unwrap_or(updated));
    Ok(json!({
        "success": true,
        "disableModelInvocation": read_disable_model_invocation(&parsed.frontmatter),
    }))
}

/// Skill update checks are network-scoped; without install metadata there is
/// nothing to check, so the endpoint reports an empty list.
pub fn check_skill_updates(
    state: &SharedState,
    cwd: &Path,
    package: Option<&str>,
    scope: Option<&str>,
) -> Result<Value, (u16, String, &'static str)> {
    if package.is_some() != scope.is_some() {
        return Err((
            400,
            "package and scope must be provided together".into(),
            "package_scope_together",
        ));
    }
    let listed = load_skills_with_install_info(state, cwd);
    let _ = package;
    // Skills installed through omp's lock file carry install metadata; AIDesk
    // does not track update channels itself, so report no pending updates.
    let _ = listed;
    Ok(json!({ "updates": [] }))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn frontmatter_parses_yaml_block() {
        let parsed = parse_skill_frontmatter("---\nname: demo\ndescription: hi\n---\nBody\n");
        assert_eq!(parsed.frontmatter["name"], json!("demo"));
        assert_eq!(parsed.body, "Body\n");
    }

    #[test]
    fn disable_flag_is_added_once_and_can_be_removed() {
        let content = "---\nname: demo\n---\nBody\n";
        let enabled = set_disable_model_invocation(content, true);
        assert!(enabled.contains("disable-model-invocation: true"));
        let again = set_disable_model_invocation(&enabled, true);
        assert_eq!(again.matches("disable-model-invocation:").count(), 1);
        let cleared = set_disable_model_invocation(&again, false);
        assert!(!cleared.contains("disable-model-invocation"));
    }

    #[test]
    fn existing_hide_spelling_is_edited_not_duplicated() {
        let content = "---\nname: demo\nhide: true\n---\n";
        let cleared = set_disable_model_invocation(content, false);
        assert!(!cleared.contains("hide"));
        let reenabled = set_disable_model_invocation(content, true);
        assert_eq!(reenabled.matches("hide:").count(), 1);
    }
}
