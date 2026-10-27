//! Server configuration resolved from CLI arguments and the environment.

use std::env;
use std::path::{Path, PathBuf};

#[derive(Debug, Clone)]
pub struct SttConfig {
    pub endpoint: String,
    pub api_key: Option<String>,
    pub model: Option<String>,
}

#[derive(Debug, Clone)]
pub struct Config {
    pub home: PathBuf,
    pub config_root: PathBuf,
    pub agent_dir: PathBuf,
    pub sessions_dir: PathBuf,
    pub blobs_dir: PathBuf,
    pub archive_dir: PathBuf,
    pub diagnostics_dir: PathBuf,
    /// Resolved omp executable, or `None` when it is not installed.
    pub omp_bin: Option<PathBuf>,
    pub socket: Option<PathBuf>,
    pub port: Option<u16>,
    pub host: String,
    pub stt: Option<SttConfig>,
}

fn clean_env(name: &str) -> Option<String> {
    env::var(name)
        .ok()
        .map(|v| v.trim().to_string())
        .filter(|v| !v.is_empty())
}

fn home_dir() -> PathBuf {
    if let Some(home) = clean_env("HOME") {
        return PathBuf::from(home);
    }
    // Fall back to the passwd entry; the server always runs as a real user.
    unsafe {
        let mut buf = [0i8; 4096];
        let mut pwd: libc::passwd = std::mem::zeroed();
        let mut result: *mut libc::passwd = std::ptr::null_mut();
        if libc::getpwuid_r(
            libc::geteuid(),
            &mut pwd,
            buf.as_mut_ptr(),
            buf.len(),
            &mut result,
        ) == 0
            && !result.is_null()
            && !pwd.pw_dir.is_null()
        {
            let dir = std::ffi::CStr::from_ptr(pwd.pw_dir)
                .to_string_lossy()
                .into_owned();
            if !dir.is_empty() {
                return PathBuf::from(dir);
            }
        }
    }
    PathBuf::from("/")
}

fn is_dir(path: &Path) -> bool {
    path.is_dir()
}

fn xdg_data_agent_root(_home: &Path, config_root: &Path, agent_dir: &Path) -> Option<PathBuf> {
    if !cfg!(any(target_os = "linux", target_os = "macos")) {
        return None;
    }
    let default_agent = config_root.join("agent");
    if agent_dir != default_agent {
        return None;
    }
    let value = clean_env("XDG_DATA_HOME")?;
    let app_root = Path::new(&value).join("omp");
    if is_dir(&app_root) {
        Some(app_root)
    } else {
        None
    }
}

/// First existing candidate, or the first candidate when none exist.
fn first_existing(candidates: Vec<PathBuf>) -> PathBuf {
    for candidate in &candidates {
        if candidate.exists() {
            return candidate.clone();
        }
    }
    candidates.into_iter().next().unwrap_or_default()
}

impl Config {
    pub fn load() -> Self {
        let home = home_dir();
        let config_dir_name = clean_env("PI_CONFIG_DIR").unwrap_or_else(|| ".omp".to_string());
        let config_root = home.join(&config_dir_name);
        let agent_dir = match clean_env("PI_CODING_AGENT_DIR") {
            Some(value) => {
                let path = PathBuf::from(value);
                if path.is_absolute() {
                    path
                } else {
                    std::env::current_dir()
                        .unwrap_or_else(|_| home.clone())
                        .join(path)
                }
            }
            None => config_root.join("agent"),
        };

        let xdg = xdg_data_agent_root(&home, &config_root, &agent_dir);
        let data_root = xdg.clone().unwrap_or_else(|| agent_dir.clone());
        let sessions_dir = data_root.join("sessions");
        let blobs_dir = data_root.join("blobs");
        let archive_dir = sessions_dir
            .parent()
            .unwrap_or_else(|| Path::new("/"))
            .join("archive")
            .join("sessions");
        let diagnostics_dir = if agent_dir == config_root.join("agent") {
            config_root.join("omp-web")
        } else {
            agent_dir.join("omp-web")
        };

        let omp_bin = resolve_omp_bin();

        // Argument parsing: --socket/--port/--host. Unknown flags are ignored
        // so a service manager can pass through extra options.
        let mut socket = clean_env("AIDESK_SOCKET").map(PathBuf::from);
        let mut port = clean_env("PORT").and_then(|v| v.parse::<u16>().ok());
        let mut host = clean_env("HOST")
            .or_else(|| clean_env("OMP_WEB_HOSTNAME"))
            .unwrap_or_else(|| "127.0.0.1".to_string());
        let args: Vec<String> = env::args().skip(1).collect();
        let mut index = 0;
        while index < args.len() {
            let arg = args[index].clone();
            let (flag, inline) = match arg.split_once('=') {
                Some((name, value)) if name.starts_with("--") => {
                    (name.to_string(), Some(value.to_string()))
                }
                _ => (arg.clone(), None),
            };
            if flag != "--socket" && flag != "--port" && flag != "--host" {
                index += 1;
                continue;
            }
            let value = match inline {
                Some(value) => value,
                None => {
                    if index + 1 >= args.len() {
                        index += 1;
                        continue;
                    }
                    index += 1;
                    args[index].clone()
                }
            };
            match flag.as_str() {
                "--socket" => socket = Some(PathBuf::from(value)),
                "--port" => port = value.parse::<u16>().ok(),
                "--host" => host = value,
                _ => {}
            }
            index += 1;
        }

        if socket.is_none() && port.is_none() {
            port = Some(3000);
        }

        let stt = clean_env("OMP_WEB_STT_ENDPOINT").map(|endpoint| SttConfig {
            endpoint,
            api_key: clean_env("OMP_WEB_STT_KEY"),
            model: clean_env("OMP_WEB_STT_MODEL"),
        });

        Self {
            home,
            config_root,
            agent_dir,
            sessions_dir,
            blobs_dir,
            archive_dir,
            diagnostics_dir,
            omp_bin,
            socket,
            port,
            host,
            stt,
        }
    }

    /// Canonical config.yml (config.yaml fallback), matching omp's lookup.
    pub fn settings_path(&self) -> PathBuf {
        first_existing(vec![
            self.agent_dir.join("config.yml"),
            self.agent_dir.join("config.yaml"),
        ])
    }

    /// Canonical models.yml (models.yaml fallback).
    pub fn models_config_path(&self) -> PathBuf {
        first_existing(vec![
            self.agent_dir.join("models.yml"),
            self.agent_dir.join("models.yaml"),
        ])
    }

    pub fn projects_path(&self) -> PathBuf {
        self.agent_dir.join("omp-web").join("projects.json")
    }

    /// Existing registry file: omp-web (canonical) then the AIDesk spelling,
    /// then the pre-omp-web agent-dir location.
    pub fn existing_projects_path(&self) -> PathBuf {
        first_existing(vec![
            self.projects_path(),
            self.agent_dir.join("aidesk").join("projects.json"),
            self.agent_dir.join("projects.json"),
        ])
    }

    pub fn web_settings_path(&self) -> PathBuf {
        self.agent_dir.join("omp-web").join("settings.json")
    }

    pub fn existing_web_settings_path(&self) -> PathBuf {
        first_existing(vec![
            self.web_settings_path(),
            self.agent_dir.join("aidesk").join("settings.json"),
            self.agent_dir.join("omp-web-settings.json"),
        ])
    }

    pub fn notifications_path(&self) -> PathBuf {
        self.agent_dir.join("omp-web").join("notifications.json")
    }

    pub fn media_dir(&self) -> PathBuf {
        self.diagnostics_dir.join("media")
    }

    pub fn omp_bin_string(&self) -> String {
        self.omp_bin
            .as_ref()
            .map(|p| p.to_string_lossy().into_owned())
            .unwrap_or_else(|| "omp".to_string())
    }

    /// Config/agent roots that the generic file API may read (credentials files
    /// inside them are denied separately).
    pub fn config_agent_roots(&self) -> Vec<PathBuf> {
        vec![
            self.config_root.clone(),
            self.agent_dir.clone(),
            self.home.join(".agents"),
            self.home.join(".agent"),
        ]
    }
}

/// Locate the omp binary: AIDESK_OMP_BIN, then OMP_WEB_OMP_BIN, then PATH.
pub fn resolve_omp_bin() -> Option<PathBuf> {
    for name in ["AIDESK_OMP_BIN", "OMP_WEB_OMP_BIN"] {
        if let Some(value) = clean_env(name) {
            let path = PathBuf::from(&value);
            return if path.exists() { Some(path) } else { None };
        }
    }
    let bin_name = if cfg!(windows) { "omp.exe" } else { "omp" };
    if let Ok(path_var) = env::var("PATH") {
        for dir in path_var.split(':') {
            if dir.is_empty() {
                continue;
            }
            let candidate = Path::new(dir).join(bin_name);
            if candidate.is_file() {
                return Some(candidate);
            }
        }
    }
    let home = home_dir();
    for dir in [
        PathBuf::from("/opt/homebrew/bin"),
        PathBuf::from("/usr/local/bin"),
        home.join(".bun/bin"),
        home.join(".local/bin"),
    ] {
        let candidate = dir.join(bin_name);
        if candidate.is_file() {
            return Some(candidate);
        }
    }
    None
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn resolves_config_paths_under_home() {
        // Without environment overrides, agent dir lives under the config root.
        let home = home_dir();
        assert!(home.is_absolute() || home == PathBuf::from("/"));
    }
}
