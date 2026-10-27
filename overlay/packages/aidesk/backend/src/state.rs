//! Process-wide application state: configuration, the file-access allow-list,
//! terminal sessions and the live agent registry handle.

use crate::config::Config;
use crate::omp::session_reader;
use crate::omp::terminal::TerminalManager;
use crate::util::path_key;
use std::collections::HashSet;
use std::path::{Path, PathBuf};
use std::sync::{LazyLock, Mutex, RwLock};
use std::time::{Duration, Instant};

pub struct AppState {
    pub cfg: Config,
    /// Roots explicitly authorized by API calls (validated cwds, projects).
    additional_roots: RwLock<HashSet<String>>,
    session_roots: Mutex<Option<(Instant, Vec<PathBuf>)>>,
    pub terminals: TerminalManager,
}

static GLOBAL_STATE: LazyLock<Mutex<Option<std::sync::Arc<AppState>>>> =
    LazyLock::new(|| Mutex::new(None));

impl AppState {
    pub fn new(cfg: Config) -> std::sync::Arc<Self> {
        let state = std::sync::Arc::new(Self {
            cfg,
            additional_roots: RwLock::new(HashSet::new()),
            session_roots: Mutex::new(None),
            terminals: TerminalManager::new(),
        });
        if let Ok(mut slot) = GLOBAL_STATE.lock() {
            *slot = Some(state.clone());
        }
        state
    }

    /// The shared instance, used by modules that need config outside a handler
    /// (e.g. RPC session spawning).
    pub fn global() -> Option<std::sync::Arc<Self>> {
        GLOBAL_STATE.lock().ok().and_then(|slot| slot.clone())
    }

    pub fn allow_root(&self, root: &Path) {
        if let Ok(mut roots) = self.additional_roots.write() {
            roots.insert(path_key(root));
        }
    }

    /// Session cwds and project roots, cached for 5 seconds.
    fn session_derived_roots(&self) -> Vec<PathBuf> {
        if let Ok(cache) = self.session_roots.lock() {
            if let Some((expires, roots)) = cache.as_ref() {
                if *expires > Instant::now() {
                    return roots.clone();
                }
            }
        }
        let mut roots = Vec::new();
        for session in session_reader::list_all_sessions(&self.cfg) {
            if !session.cwd.is_empty() {
                roots.push(PathBuf::from(&session.cwd));
            }
            if !session.project_root.is_empty() {
                roots.push(PathBuf::from(&session.project_root));
            }
        }
        if let Ok(mut cache) = self.session_roots.lock() {
            *cache = Some((Instant::now() + Duration::from_secs(5), roots.clone()));
        }
        roots
    }

    pub fn invalidate_session_roots(&self) {
        if let Ok(mut cache) = self.session_roots.lock() {
            *cache = None;
        }
        session_reader::invalidate_session_list_cache();
    }

    /// Every root the generic file API may touch, in priority order:
    /// session cwds, project roots, explicitly authorized roots, then config
    /// and agent roots.
    pub fn allowed_roots(&self) -> Vec<PathBuf> {
        let mut roots: Vec<PathBuf> = Vec::new();
        let mut seen: HashSet<String> = HashSet::new();
        let mut push = |path: PathBuf| {
            let key = path_key(&path);
            if seen.insert(key) {
                roots.push(path);
            }
        };
        for root in self.session_derived_roots() {
            push(root);
        }
        if let Ok(additional) = self.additional_roots.read() {
            for root in additional.iter() {
                push(PathBuf::from(root));
            }
        }
        for root in self.cfg.config_agent_roots() {
            push(root);
        }
        roots
    }

    pub fn is_path_allowed(&self, path: &Path) -> bool {
        let roots = self.allowed_roots();
        roots.iter().any(|root| crate::util::is_within(root, path))
    }

    /// Same check after resolving symlinks on both sides.
    pub fn is_existing_path_allowed(&self, path: &Path) -> bool {
        let real = match std::fs::canonicalize(path) {
            Ok(real) => real,
            Err(_) => return false,
        };
        let roots = self.allowed_roots();
        roots.iter().any(|root| match std::fs::canonicalize(root) {
            Ok(real_root) => crate::util::is_within(&real_root, &real),
            Err(_) => false,
        })
    }

    /// omp's credential store, config and models files must stay unreadable and
    /// unwritable through the generic file API. Both the lexical path and the
    /// canonicalized target are checked so symlinked config roots cannot slip
    /// through.
    pub fn is_config_root_denied_file(&self, path: &Path) -> bool {
        let config_roots = self.cfg.config_agent_roots();
        let canonical = std::fs::canonicalize(path).ok();
        let within_config_root = config_roots
            .iter()
            .any(|root| crate::util::is_within(root, path))
            || canonical.as_deref().map_or(false, |canonical| {
                config_roots.iter().any(|root| {
                    std::fs::canonicalize(root)
                        .map(|root| crate::util::is_within(&root, canonical))
                        .unwrap_or(false)
                })
            });
        if !within_config_root {
            return false;
        }
        let name = crate::util::file_name(path).to_ascii_lowercase();
        if matches!(
            name.as_str(),
            "agent.db"
                | "models.yml"
                | "models.yaml"
                | "config.yml"
                | "config.yaml"
                | "settings.json"
        ) {
            return true;
        }
        // SQLite sidecars (`agent.db-wal`, `agent.db-shm`, `agent.db-journal`).
        let stem = name.split('.').next().unwrap_or("");
        stem == "agent" && name.contains(".db")
    }
}

pub type SharedState = std::sync::Arc<AppState>;
