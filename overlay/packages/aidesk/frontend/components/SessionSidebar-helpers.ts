import type { SessionInfo } from "@/lib/types";
import { comparableProjectPath } from "@/lib/comparable-path";
// Bounded retry window for restoring a brand-new session from its URL before
// omp flushes the JSONL (typically appears within a second or two of the
// first prompt, so 8 × 1s covers it without hanging a dead link forever).
const INITIAL_RESTORE_RETRY_MS = 1000;
const INITIAL_RESTORE_MAX_ATTEMPTS = 8;
const UNREAD_SESSIONS_STORAGE_KEY = "omp-web:unread-session-ids";

function loadUnreadSessionIds(): Set<string> {
  if (typeof window === "undefined") return new Set();
  try {
    const raw = window.localStorage.getItem(UNREAD_SESSIONS_STORAGE_KEY);
    if (!raw) return new Set();
    const parsed = JSON.parse(raw) as unknown;
    if (Array.isArray(parsed)) return new Set(parsed.filter((id): id is string => typeof id === "string"));
    return new Set();
  } catch {
    return new Set();
  }
}

function saveUnreadSessionIds(ids: Set<string>): void {
  if (typeof window === "undefined") return;
  try {
    if (ids.size === 0) window.localStorage.removeItem(UNREAD_SESSIONS_STORAGE_KEY);
    else window.localStorage.setItem(UNREAD_SESSIONS_STORAGE_KEY, JSON.stringify([...ids]));
  } catch {
    // ignore storage quota / privacy-mode errors
  }
}
const EXPANDED_PROJECTS_STORAGE_KEY = "omp-web:expanded-projects";

/** Sidebar organisation: one row per session (default) or grouped by workspace. */
type SidebarViewMode = "sessions" | "workspaces";
const SIDEBAR_VIEW_MODE_STORAGE_KEY = "omp-web:sidebar-view-mode";

/** Persisted sidebar view. Anything but an explicit "workspaces" falls back to
 *  the flat, chat-app-style session list. */
function loadSidebarViewMode(): SidebarViewMode {
  if (typeof window === "undefined") return "sessions";
  try {
    return window.localStorage.getItem(SIDEBAR_VIEW_MODE_STORAGE_KEY) === "workspaces" ? "workspaces" : "sessions";
  } catch {
    return "sessions";
  }
}

function saveSidebarViewMode(mode: SidebarViewMode): void {
  if (typeof window === "undefined") return;
  try {
    window.localStorage.setItem(SIDEBAR_VIEW_MODE_STORAGE_KEY, mode);
  } catch {
    // ignore storage quota / privacy-mode errors
  }
}

/** Shared empty set for the no-stored-expansion default (never mutated). */
const EMPTY_PROJECT_SET: ReadonlySet<string> = new Set();

/** Persisted expanded-project paths. Returns null when nothing was stored —
 *  the sidebar then defaults to expanding only the active project. */
function loadExpandedProjects(): Set<string> | null {
  if (typeof window === "undefined") return null;
  try {
    const raw = window.localStorage.getItem(EXPANDED_PROJECTS_STORAGE_KEY);
    if (!raw) return null;
    const parsed = JSON.parse(raw) as unknown;
    if (Array.isArray(parsed)) {
      return new Set(parsed.filter((path): path is string => typeof path === "string" && path.length > 0).map((path) => comparableProjectPath(path)));
    }
    return null;
  } catch {
    return null;
  }
}

function saveExpandedProjects(paths: Set<string>): void {
  if (typeof window === "undefined") return;
  try {
    window.localStorage.setItem(EXPANDED_PROJECTS_STORAGE_KEY, JSON.stringify([...paths]));
  } catch {
    // ignore storage quota / privacy-mode errors
  }
}
/** Substitute the home dir prefix with ~ (no path truncation — see PathLabel) */
function formatHomePath(targetPath: string, homeDir?: string | null): string {
  if (!targetPath) return "";
  if (!homeDir) return targetPath;
  const home = homeDir.replace(/[\\/]+$/, "");
  if (!home) return targetPath;
  const target = targetPath.replace(/[\\/]+$/, "");
  if (!target) return targetPath;
  if (target === home) return "~";
  const foldedTarget = comparableProjectPath(target);
  // Compare case-folded (Windows homes) but keep the separator boundary, so
  // `/home/me` never claims `/home/memo`.
  if (foldedTarget.startsWith(`${comparableProjectPath(home)}/`)) {
    const relative = target.slice(home.length).replace(/^[\\/]+/, "");
    return relative ? `~/${relative.replace(/\\/g, "/")}` : "~";
  }
  return targetPath;
}
/** Final folder name of a project path, portable across / and \ separators. */
function projectLabel(projectPath: string): string {
  const trimmed = projectPath.replace(/[\\/]+$/, "");
  const index = Math.max(trimmed.lastIndexOf("/"), trimmed.lastIndexOf("\\"));
  return index >= 0 ? trimmed.slice(index + 1) : trimmed;
}
/** Last-activity timestamp: `modified` normally wins; `created` covers
 *  optimistic placeholders whose modified stamp moves with the clock. */
function sessionActivityTime(session: Pick<SessionInfo, "modified" | "created">): number {
  return Math.max(Date.parse(session.modified) || 0, Date.parse(session.created) || 0);
}
function formatRelativeTime(value: string, _locale: string, now: number): string | null {
  const timestamp = new Date(value).getTime();
  if (!Number.isFinite(timestamp)) return null;

  const minutes = Math.max(0, Math.floor((now - timestamp) / 60_000));
  if (minutes < 1) return "now";
  if (minutes < 60) return `${minutes}m`;

  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours}h`;

  const days = Math.floor(hours / 24);
  if (days < 30) return `${days}d`;

  const months = Math.floor(days / 30);
  if (months < 12) return `${months}mo`;
  return `${Math.floor(months / 12)}y`;
}
interface SessionTreeNode {
  session: SessionInfo;
  children: SessionTreeNode[];
}

function buildSessionTree(sessions: SessionInfo[]): SessionTreeNode[] {
  const byId = new Map<string, SessionTreeNode>();
  for (const s of sessions) {
    byId.set(s.id, { session: s, children: [] });
  }

  // Build a map of parentSessionId chains so we can resolve missing ancestors
  const parentOf = new Map<string, string>();
  for (const s of sessions) {
    if (s.parentSessionId) parentOf.set(s.id, s.parentSessionId);
  }

  // Walk up the parentSessionId chain to find the nearest ancestor that exists in byId
  function resolveAncestor(id: string): string | null {
    let cur = parentOf.get(id);
    const visited = new Set<string>();
    while (cur) {
      if (visited.has(cur)) return null; // cycle guard
      visited.add(cur);
      if (byId.has(cur)) return cur;
      cur = parentOf.get(cur);
    }
    return null;
  }

  const roots: SessionTreeNode[] = [];
  for (const node of byId.values()) {
    const ancestor = resolveAncestor(node.session.id);
    if (ancestor) {
      byId.get(ancestor)!.children.push(node);
    } else {
      roots.push(node);
    }
  }

  // Sort each level by latest activity desc, so the freshest session sits at
  // the very top (falling back to the raw ISO stamp for equal instants).
  const sort = (nodes: SessionTreeNode[]) => {
    nodes.sort((a, b) => sessionActivityTime(b.session) - sessionActivityTime(a.session)
      || b.session.modified.localeCompare(a.session.modified));
    nodes.forEach((n) => sort(n.children));
  };
  sort(roots);
  return roots;
}
const MAX_PROJECT_SESSIONS = 5;
export {
  EMPTY_PROJECT_SET,
  EXPANDED_PROJECTS_STORAGE_KEY,
  INITIAL_RESTORE_MAX_ATTEMPTS,
  INITIAL_RESTORE_RETRY_MS,
  MAX_PROJECT_SESSIONS,
  SIDEBAR_VIEW_MODE_STORAGE_KEY,
  UNREAD_SESSIONS_STORAGE_KEY,
  buildSessionTree,
  formatHomePath,
  formatRelativeTime,
  loadExpandedProjects,
  loadSidebarViewMode,
  loadUnreadSessionIds,
  projectLabel,
  saveExpandedProjects,
  saveSidebarViewMode,
  saveUnreadSessionIds,
  sessionActivityTime,
  type SessionTreeNode,
  type SidebarViewMode,
};
