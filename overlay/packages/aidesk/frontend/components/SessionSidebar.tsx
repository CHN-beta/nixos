
import { memo, useEffect, useState, useCallback, useRef, useMemo, useDeferredValue } from "react";
import type { ExitedRpcSession, ManagedProject, ProjectLaunchConfig, SessionInfo } from "@/lib/types";
import { useI18n } from "@/lib/i18n";
import { formatApiError } from "@/lib/i18n/api-error";
import { DirectoryPicker } from "./DirectoryPicker";
import { ProjectLaunchConfigDialog } from "./ProjectLaunchConfigDialog";
import { Tooltip } from "./ui/primitives";
import { toast } from "./ui/toast";
import { clearLastOpenSession, setLastOpenSession, workspaceKeyOf } from "@/lib/workspace-memory";
import { projectActivityCounts, sortManagedProjects } from "@/lib/project-ordering";
import { comparableProjectPath } from "@/lib/comparable-path";
import { Archive, ArrowLeft, ArrowRight, Check, ChevronRight, Folder, MessageSquare, Plus, RefreshCw, Search, Settings2, SlidersHorizontal, X } from "lucide-react";
import { publishSessionsChanged } from "@/lib/session-change-bus";
import { NOTIFICATION_MESSAGE_EVENT, notificationClientId } from "@/lib/notification-client";
import {
  EMPTY_PROJECT_SET,
  INITIAL_RESTORE_MAX_ATTEMPTS,
  INITIAL_RESTORE_RETRY_MS,
  MAX_PROJECT_SESSIONS,
  buildSessionTree,
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
} from "./SessionSidebar-helpers";
import { AideskTitle, SIDEBAR_BUTTON_TRANSITION, SidebarIconButton } from "./SessionSidebar-chrome";
import { ProjectRow, SessionTreeItem } from "./SessionSidebar-rows";

/** Deadline for one /api/sessions fetch. A wedged-but-listening server never
 * answers; without this the initial spinner would pend forever. */
const SESSIONS_FETCH_TIMEOUT_MS = 15_000;

declare global {
  interface Window {
    piDesktop?: {
      selectDirectory: () => Promise<string | null>;
    };
  }
}

interface Props {
  selectedSessionId: string | null;
  /** The active session can exist in memory before its JSONL file is flushed. */
  optimisticSession?: SessionInfo | null;
  onSelectSession: (session: SessionInfo, isRestore?: boolean) => void;
  onNewSession?: (sessionId: string, cwd: string) => void;
  initialSessionId?: string | null;
  skipInitialProjectSelection?: boolean;
  onInitialRestoreDone?: () => void;
  refreshKey?: number;
  onSessionDeleted?: (sessionId: string) => void;
  selectedCwd?: string | null;
  onCwdChange?: (cwd: string | null, projectRoot?: string | null) => void;
  onWorkspaceOptionsChange?: (projects: ManagedProject[], selectedProject: string | null, cwd: string | null) => void;
  addProjectOpen: boolean;
  setAddProjectOpen: (open: boolean) => void;
  /** Opens the app settings (pinned sidebar footer row). */
  onOpenSettings?: () => void;
  /** Opens the archived sessions browser. */
  onOpenArchive?: () => void;
  /** In-app back/forward over visited chat views (sidebar header buttons). */
  navigation?: {
    canBack: boolean;
    canForward: boolean;
    onBack: () => void;
    onForward: () => void;
    /** Platform shortcut label for the tooltip, e.g. "⌘[" / "Alt+←". */
    backShortcut: string;
    forwardShortcut: string;
  };
  /** True when settings full-page view is currently open. */
  settingsOpen?: boolean;
  /** Mobile full-screen drawer only: shows a top-left close control. */
  onClose?: () => void;
}






export const SessionSidebar = memo(function SessionSidebar({ selectedSessionId, optimisticSession, onSelectSession, onNewSession, initialSessionId, skipInitialProjectSelection, onInitialRestoreDone, refreshKey, onSessionDeleted, selectedCwd: selectedCwdProp, onCwdChange, onWorkspaceOptionsChange, addProjectOpen, setAddProjectOpen, onOpenSettings, onOpenArchive, navigation, settingsOpen = false, onClose }: Props) {


  const { t } = useI18n();
  const [allSessions, setAllSessions] = useState<SessionInfo[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [selectedCwd, setSelectedCwd] = useState<string | null>(null);
  // Managed + session-discovered projects (server-merged, hidden excluded).
  const [projects, setProjects] = useState<ManagedProject[]>([]);
  const [draggedProjectPath, setDraggedProjectPath] = useState<string | null>(null);
  const [projectsError, setProjectsError] = useState<string | null>(null);
  // Add-project picker state.
  const [addProjectBusy, setAddProjectBusy] = useState(false);
  const [addProjectError, setAddProjectError] = useState<string | null>(null);
  // Per-project expansion, persisted to localStorage (null = nothing stored).
  const [expandedProjects, setExpandedProjects] = useState<Set<string> | null>(() => loadExpandedProjects());
  // Project currently being removed (hide) — serializes remove requests.
  const [removeProjectPath, setRemoveProjectPath] = useState<string | null>(null);
  const [launchConfigProject, setLaunchConfigProject] = useState<ManagedProject | null>(null);
  const [sessionRefreshDone, setSessionRefreshDone] = useState(false);
  const [runningSessionIds, setRunningSessionIds] = useState<Set<string>>(() => new Set());
  const [runningSessionCwds, setRunningSessionCwds] = useState<Record<string, string>>({});
  const [exitedSessions, setExitedSessions] = useState<Map<string, ExitedRpcSession>>(() => new Map());
  const knownRunningCwdsRef = useRef<Map<string, string>>(new Map());
  const [unreadSessionIds, setUnreadSessionIds] = useState<Set<string>>(() => loadUnreadSessionIds());
  const previousRunningSessionIdsRef = useRef<Set<string>>(new Set());
  // Relative session times must age while the sidebar stays open; one shared
  // minute clock avoids a timer per session row.
  const [relativeTimeNow, setRelativeTimeNow] = useState(() => Date.now());
  // Sidebar organisation: a flat chat-app-style session list (default) or the
  // workspace tree users switch to when they want folder grouping.
  const [viewMode, setViewMode] = useState<SidebarViewMode>(() => loadSidebarViewMode());
  const [homeDir, setHomeDir] = useState<string | null>(null);
  // Client-side workspace/session filtering (Workspaces header controls).
  const [searchOpen, setSearchOpen] = useState(false);
  const [searchQuery, setSearchQuery] = useState("");
  const [runningOnly, setRunningOnly] = useState(false);
  const searchInputRef = useRef<HTMLInputElement>(null);

  // Once the SSE stream has delivered a frame it is the source of truth for
  // running state; late /api/sessions responses must not overwrite it.
  const sseAuthoritativeRef = useRef(false);
  const sessionRefreshTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  const sessionsEtagRef = useRef<string | null>(null);
  const sessionsAbortRef = useRef<AbortController | null>(null);
  // Set once the first /api/sessions fetch settles (success OR failure) so the
  // initial-restore effect can stop waiting on a load that never yields rows.
  const initialLoadedRef = useRef(false);
  const loadSessions = useCallback(async (showLoading = false) => {
    sessionsAbortRef.current?.abort();
    const controller = new AbortController();
    sessionsAbortRef.current = controller;
    // A wedged-but-listening server (the long-idle failure mode) accepts the
    // TCP connection and never answers: without a deadline the fetch pends
    // forever and the sidebar shows its initial spinner indefinitely. Abort
    // with a TimeoutError so the catch surfaces an error and the
    // visibility/online recovery below can retry later.
    const timeout = setTimeout(() => controller.abort(new DOMException("Session list request timed out", "TimeoutError")), SESSIONS_FETCH_TIMEOUT_MS);
    try {
      if (showLoading) setLoading(true);
      const headers: Record<string, string> = {};
      if (sessionsEtagRef.current) headers["If-None-Match"] = sessionsEtagRef.current;
      const res = await fetch("/api/sessions", { headers, signal: controller.signal });
      if (res.status === 304) return;
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const etag = res.headers.get("ETag");
      if (etag) sessionsEtagRef.current = etag;
      const data = await res.json() as { sessions: SessionInfo[]; runningSessionIds?: string[]; runningSessions?: Array<{ id: string; cwd: string }> };
      setAllSessions(data.sessions);
      if (data.runningSessions) {
        for (const rs of data.runningSessions) {
          if (rs.id && rs.cwd) knownRunningCwdsRef.current.set(rs.id, rs.cwd);
        }
      }
      // Treat the fetched running set as an initial fallback only. Once SSE is
      // live it owns this state, so a slow fetch can't revive a stale snapshot.
      if (!sseAuthoritativeRef.current) {
        setRunningSessionIds(new Set(data.runningSessionIds ?? []));
        if (data.runningSessions) {
          const nextCwds: Record<string, string> = {};
          for (const rs of data.runningSessions) {
            if (rs.id && rs.cwd) nextCwds[rs.id] = rs.cwd;
          }
          setRunningSessionCwds(nextCwds);
        }
      }
      // Drop unread markers for sessions that no longer exist (e.g. deleted).
      const existingIds = new Set(data.sessions.map((s) => s.id));
      setUnreadSessionIds((prev) => {
        if (prev.size === 0) return prev;
        const next = new Set([...prev].filter((id) => existingIds.has(id)));
        return next.size === prev.size ? prev : next;
      });
      setError(null);
      if (!showLoading) {
        setSessionRefreshDone(true);
        if (sessionRefreshTimerRef.current) clearTimeout(sessionRefreshTimerRef.current);
        sessionRefreshTimerRef.current = setTimeout(() => setSessionRefreshDone(false), 2000);
      }
    } catch (e) {
      if ((e as Error)?.name === "AbortError") return;
      setError(t("sessionSidebar.loadFailed", { detail: e instanceof Error ? e.message : String(e) }));
    } finally {
      clearTimeout(timeout);
      initialLoadedRef.current = true;
      if (showLoading) setLoading(false);
    }
  }, [t]);

  const initialLoadDone = useRef(false);
  useEffect(() => {
    const isFirst = !initialLoadDone.current;
    initialLoadDone.current = true;
    loadSessions(isFirst);
  }, [loadSessions, refreshKey]);

  const projectsLoadSeqRef = useRef(0);
  const loadProjects = useCallback(async () => {
    const seq = ++projectsLoadSeqRef.current;
    try {
      const res = await fetch("/api/projects");
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const data = await res.json() as { projects?: ManagedProject[] };
      // A newer request superseded this one — drop the stale response.
      if (seq !== projectsLoadSeqRef.current) return;
      setProjects(data.projects ?? []);
      setProjectsError(null);
      projectsLoadedRef.current = true;
    } catch (e) {
      if (seq !== projectsLoadSeqRef.current) return;
      setProjectsError(t("projects.loadFailed", { detail: e instanceof Error ? e.message : String(e) }));
    }
  }, [t]);

  useEffect(() => {
    void loadProjects();
  }, [loadProjects, refreshKey]);

  // Persist the sidebar organisation: the flat session list is the default,
  // the workspace tree is opt-in and remembered across visits.
  useEffect(() => {
    saveSidebarViewMode(viewMode);
  }, [viewMode]);

  // The flat list shortens each session's working directory relative to the
  // account home (~/repo/x). A failed lookup simply leaves absolute paths.
  useEffect(() => {
    let cancelled = false;
    void fetch("/api/home")
      .then(async (response) => {
        if (!response.ok) throw new Error(`HTTP ${response.status}`);
        return await response.json() as { home?: string };
      })
      .then((data) => {
        if (!cancelled) setHomeDir(typeof data.home === "string" ? data.home : null);
      })
      .catch(() => {});
    return () => { cancelled = true; };
  }, []);

  useEffect(() => {
    const interval = setInterval(() => setRelativeTimeNow(Date.now()), 60_000);
    return () => clearInterval(interval);
  }, []);

  // Persist expansion state; null means nothing was stored yet.
  useEffect(() => {
    if (expandedProjects === null) return;
    saveExpandedProjects(expandedProjects);
  }, [expandedProjects]);

  // Persist unread markers so they survive a browser refresh before the user
  // has actually opened the completed session.
  useEffect(() => {
    saveUnreadSessionIds(unreadSessionIds);
  }, [unreadSessionIds]);

  // Debounce refresh bursts (agent_start + session_info_update + file-appear signal can fire within 250ms)
  const pendingRefreshRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const scheduleRefresh = useCallback(() => {
    if (pendingRefreshRef.current) return;
    pendingRefreshRef.current = setTimeout(() => {
      pendingRefreshRef.current = null;
      void loadSessions(false);
    }, 300);
  }, [loadSessions]);
  useEffect(() => () => {
    if (sessionRefreshTimerRef.current) {
      clearTimeout(sessionRefreshTimerRef.current);
      sessionRefreshTimerRef.current = null;
    }
  }, []);

  useEffect(() => {
    // Live running status and session-list invalidations arrive via SSE; the
    // sidebar never has to poll while an agent is working. The same stream
    // delivers this tab's notifications (handled by useNotifications).
    const source = new EventSource(`/api/agent/running/events?clientId=${encodeURIComponent(notificationClientId)}`);

    source.onmessage = (e) => {
      try {
        const data = JSON.parse(e.data) as {
          type?: string;
          runningSessionIds?: string[];
          runningSessions?: Array<{ id: string; cwd: string }>;
          exitedSessions?: ExitedRpcSession[];
          refreshSessionList?: boolean;
          sessionIds?: string[];
        };
        if (data.type === "running") {
          sseAuthoritativeRef.current = true;
          setRunningSessionIds(new Set(data.runningSessionIds ?? []));
          setExitedSessions(new Map((data.exitedSessions ?? []).map((session) => [session.id, session])));
          if (data.runningSessions) {
            const nextCwds: Record<string, string> = {};
            for (const rs of data.runningSessions) {
              if (rs.id && rs.cwd) {
                knownRunningCwdsRef.current.set(rs.id, rs.cwd);
                nextCwds[rs.id] = rs.cwd;
              }
            }
            setRunningSessionCwds(nextCwds);
          }
          if (data.refreshSessionList) scheduleRefresh();
        } else if (data.type === "sessions-changed") {
          if (data.refreshSessionList) scheduleRefresh();
          publishSessionsChanged(data.sessionIds ?? []);
        } else if (data.type === "notification") {
          window.dispatchEvent(new CustomEvent(NOTIFICATION_MESSAGE_EVENT, { detail: data }));
        }
      } catch {
        // ignore malformed frames
      }
    };

    source.onerror = () => {
      // EventSource auto-reconnects; until a fresh frame arrives, let the
      // polled /api/sessions fallback own running state again.
      sseAuthoritativeRef.current = false;
    };
    // On error EventSource auto-reconnects; keep the last known state meanwhile.
    return () => {
      if (pendingRefreshRef.current) clearTimeout(pendingRefreshRef.current);
      source.close();
    };
  }, [loadSessions, scheduleRefresh]);
  // Long-idle recovery: while the tab is hidden the SSE connection can die
  // (laptop sleep, network change, tab freeze) and its EventSource reconnect
  // carries no list invalidation. Refresh whenever the user actually comes
  // back or the network returns, so the list is never left stale/empty.
  useEffect(() => {
    const onVisible = () => {
      if (document.visibilityState === "visible") void loadSessions(false);
    };
    const onOnline = () => void loadSessions(false);
    document.addEventListener("visibilitychange", onVisible);
    window.addEventListener("online", onOnline);
    return () => {
      document.removeEventListener("visibilitychange", onVisible);
      window.removeEventListener("online", onOnline);
    };
  }, [loadSessions]);

  useEffect(() => {
    const previous = previousRunningSessionIdsRef.current;
    const completedInBackground = [...previous].filter((id) => !runningSessionIds.has(id) && id !== selectedSessionId);
    const newlyRunning = [...runningSessionIds].filter((id) => !previous.has(id));

    if (completedInBackground.length > 0 || newlyRunning.length > 0) {
      setUnreadSessionIds((prev) => {
        const next = new Set(prev);
        newlyRunning.forEach((id) => next.delete(id));
        completedInBackground.forEach((id) => next.add(id));
        return next;
      });
    }
    // A brand-new session's JSONL does not exist until the first assistant
    // turn makes progress — but its running badge must show immediately
    // via the optimistic row. Once any session completes (or a new session
    // appears on disk), reload so it replaces the optimistic placeholder
    // without waiting for another refresh trigger.
    if (completedInBackground.length > 0 || newlyRunning.length > 0) {
      loadSessions(false);
    }

    previousRunningSessionIdsRef.current = runningSessionIds;
  }, [runningSessionIds, selectedSessionId, loadSessions]);

  useEffect(() => {
    if (!selectedSessionId) return;
    setUnreadSessionIds((prev) => {
      if (!prev.has(selectedSessionId)) return prev;
      const next = new Set(prev);
      next.delete(selectedSessionId);
      return next;
    });
  }, [selectedSessionId]);


  const restoredRef = useRef(false);
  /** Set once the first /api/projects fetch succeeds; guards the expansion
   *  prune against running on an empty (still-loading) project list. */
  const projectsLoadedRef = useRef(false);

  /** Resolve the project root for a cwd from the freshest data available:
   *  the registered project path, else the session's own projectRoot, else
   *  the cwd itself. */
  const projectRootFor = useCallback((cwd: string | null): string | null => {
    if (!cwd) return null;
    const registered = projects.find((p) => comparableProjectPath(p.path) === comparableProjectPath(cwd));
    if (registered) return registered.path;
    const foldedCwd = comparableProjectPath(cwd);
    const match = allSessions.find((s) => comparableProjectPath(s.cwd) === foldedCwd);
    return match?.projectRoot ?? cwd;
  }, [allSessions, projects]);

  // ---- Expansion (used by the sync/notify effects below, so declared first) --
  // Keys are stored in comparableProjectPath form so case-variant spellings of
  // the same Windows path map to one entry (the server lowercases projectKey
  // on win32, while project.path preserves registry casing).
  const expandProject = useCallback((path: string) => {
    const key = comparableProjectPath(path);
    setExpandedProjects((prev) => {
      if (prev?.has(key)) return prev;
      const next = new Set(prev ?? []);
      next.add(key);
      return next;
    });
  }, []);

  const collapseProject = useCallback((path: string) => {
    const key = comparableProjectPath(path);
    setExpandedProjects((prev) => {
      if (!prev?.has(key)) return prev;
      const next = new Set(prev);
      next.delete(key);
      return next;
    });
  }, []);

  const toggleProjectExpanded = useCallback((path: string) => {
    const key = comparableProjectPath(path);
    setExpandedProjects((prev) => {
      const next = new Set(prev ?? []);
      if (next.has(key)) next.delete(key);
      else next.add(key);
      return next;
    });
  }, []);


  /** Activate a project (effective cwd = its root) and expand it, without
   *  opening a session. */
  const activateProject = useCallback((path: string) => {
    provisionalSelectionRef.current = false;
    setSelectedCwd(path);
    expandProject(path);
  }, [expandProject]);

  // Notify parent only when the effective cwd actually changes (not when
  // projectRootFor identity changes after a session-list refresh).
  const lastNotifiedCwdRef = useRef<string | null>(null);
  useEffect(() => {
    if (lastNotifiedCwdRef.current === selectedCwd) return;
    lastNotifiedCwdRef.current = selectedCwd;
    onCwdChange?.(selectedCwd, projectRootFor(selectedCwd));
  }, [selectedCwd, onCwdChange, projectRootFor]);

  // Sync to the selected session's cwd. Only fires when the prop value
  // changes, so a manual project switch is not snapped back. Sessions picked
  // outside the sidebar (URL restore, command palette) also expand their
  // containing project.
  const lastSyncedCwdPropRef = useRef<string | null>(null);
  useEffect(() => {
    // A withdrawn command must not swallow the next one: without this reset,
    // re-commanding a cwd the sidebar already synced (A -> sidebar B -> A)
    // stays stuck on B.
    if (!selectedCwdProp) {
      lastSyncedCwdPropRef.current = null;
      return;
    }
    if (selectedCwdProp !== lastSyncedCwdPropRef.current) {
      provisionalSelectionRef.current = false;
      lastSyncedCwdPropRef.current = selectedCwdProp;
      setSelectedCwd(selectedCwdProp);
      const project = projectRootFor(selectedCwdProp);
      if (project) expandProject(project);
    }
  }, [selectedCwdProp, projectRootFor, expandProject]);

  // Keep a just-created session and its project visible while omp is still
  // flushing the JSONL file. The server list remains authoritative once it
  // contains the same id.
  // IMPORTANT: derive synchronously so the optimistic row lands in the same
  // bucket as the server list once the JSONL file is flushed.
  const optimisticProjectRoot = (() => {
    if (!optimisticSession) return null;
    if (optimisticSession.projectRoot) return optimisticSession.projectRoot;
    if (optimisticSession.projectKey) return optimisticSession.projectKey;
    const cw = optimisticSession.cwd ?? "";
    if (!cw) return null;
    const reg = projects.find((p) => comparableProjectPath(p.path) === comparableProjectPath(cw));
    if (reg) return reg.path;
    return cw;
  })();
  // Stable placeholder timestamps: Date.now() inside the memo would churn every refresh and bust downstream memos.
  const placeholderTsRef = useRef<Map<string, string>>(new Map());
  useEffect(() => {
    if (optimisticSession?.id && optimisticSession.cwd) {
      knownRunningCwdsRef.current.set(optimisticSession.id, optimisticSession.cwd);
      setRunningSessionCwds((prev) => (prev[optimisticSession.id] === optimisticSession.cwd ? prev : { ...prev, [optimisticSession.id]: optimisticSession.cwd }));
    }
  }, [optimisticSession]);
  const visibleSessions = useMemo(() => {
    let base = allSessions;
    if (optimisticSession && !base.some((session) => session.id === optimisticSession.id)) {
      const stableRoot = optimisticProjectRoot ?? optimisticSession.cwd;
      const stableKey = stableRoot ? comparableProjectPath(stableRoot) : undefined;
      base = [...base, { ...optimisticSession, projectRoot: stableRoot ?? optimisticSession.cwd, ...(stableKey ? { projectKey: stableKey } : {}) }];
    }
    // A running session's JSONL may not exist yet (first turn still
    // streaming). Keep it in the list so navigating away never hides it
    // until the file lands and the next refresh replaces the placeholder.
    const known = new Set(base.map((s) => s.id));
    const placeholders: SessionInfo[] = [];
    const visibleLiveIds = new Set(runningSessionIds);
    for (const id of exitedSessions.keys()) visibleLiveIds.add(id);
    for (const id of visibleLiveIds) {
      if (known.has(id)) continue;
      let ts = placeholderTsRef.current.get(id);
      if (!ts) {
        ts = new Date().toISOString();
        placeholderTsRef.current.set(id, ts);
      }
      const isOptimistic = optimisticSession?.id === id;
      const sessionCwd = (isOptimistic ? optimisticSession.cwd : null)
        ?? runningSessionCwds[id]
        ?? exitedSessions.get(id)?.cwd
        ?? knownRunningCwdsRef.current.get(id)
        ?? selectedCwd
        ?? "";
      const resolvedRoot = isOptimistic
        ? (optimisticProjectRoot ?? optimisticSession.projectRoot ?? optimisticSession.cwd)
        : (projectRootFor(sessionCwd) ?? sessionCwd);
      const phRoot = resolvedRoot ?? "";
      const phKey = phRoot ? comparableProjectPath(phRoot) : undefined;
      placeholders.push({
        id,
        path: "",
        cwd: sessionCwd,
        name: undefined,
        created: ts,
        modified: ts,
        messageCount: 1,
        firstMessage: "",
        projectRoot: phRoot,
        ...(phKey ? { projectKey: phKey } : {}),
      });
    }
    // Prune timestamps and known cwds for ids that are now materialized or no longer live.
    if (placeholderTsRef.current.size > placeholders.length) {
      for (const key of [...placeholderTsRef.current.keys()]) {
        if (!visibleLiveIds.has(key) || known.has(key)) placeholderTsRef.current.delete(key);
      }
    }
    if (knownRunningCwdsRef.current.size > visibleLiveIds.size + (optimisticSession ? 1 : 0)) {
      if (optimisticSession) visibleLiveIds.add(optimisticSession.id);
      for (const key of [...knownRunningCwdsRef.current.keys()]) {
        if (!visibleLiveIds.has(key) && known.has(key)) knownRunningCwdsRef.current.delete(key);
      }
    }
    return placeholders.length ? [...base, ...placeholders] : base;
  }, [allSessions, optimisticSession, optimisticProjectRoot, runningSessionIds, runningSessionCwds, exitedSessions, projectRootFor, selectedCwd]);
  const visibleProjects = useMemo(() => {
    let base = projects;
    const hasOpt = optimisticProjectRoot ? base.some((p) => comparableProjectPath(p.path) === comparableProjectPath(optimisticProjectRoot)) : false;
    if (optimisticProjectRoot && !hasOpt) {
      base = [...base, { path: optimisticProjectRoot }];
    }
    // Running placeholders may belong to a project not yet in the managed list
    // (new session's cwd wasn't registered as a project). Keep that workspace
    // visible so the placeholder row has a bucket to render in.
    const knownFolded = new Set(base.map((p) => comparableProjectPath(p.path)));
    const visibleLiveIds = new Set(runningSessionIds);
    for (const id of exitedSessions.keys()) visibleLiveIds.add(id);
    for (const id of visibleLiveIds) {
      if (allSessions.some((s) => s.id === id)) continue;
      const isOptimistic = optimisticSession?.id === id;
      const sessionCwd = (isOptimistic ? optimisticSession.cwd : null)
        ?? runningSessionCwds[id]
        ?? exitedSessions.get(id)?.cwd
        ?? knownRunningCwdsRef.current.get(id)
        ?? selectedCwd
        ?? "";
      const resolvedRoot = isOptimistic
        ? (optimisticProjectRoot ?? optimisticSession.projectRoot ?? optimisticSession.cwd)
        : (projectRootFor(sessionCwd) ?? sessionCwd);
      const phPath = resolvedRoot ?? "";
      if (phPath && !knownFolded.has(comparableProjectPath(phPath))) {
        base = [...base, { path: phPath }];
        knownFolded.add(comparableProjectPath(phPath));
      }
    }
    return base;
  }, [optimisticProjectRoot, projects, runningSessionIds, runningSessionCwds, exitedSessions, allSessions, optimisticSession, projectRootFor, selectedCwd]);

  // ---- Derived project list ---------------------------------------------------
  const selectedProject = useMemo(() => projectRootFor(selectedCwd), [projectRootFor, selectedCwd]);
  // While a fresh optimistic/placeholder is pending (JSONL not yet on disk),
  // freeze ordering so the new project row does not flicker optimistic ->
  // confirmed position. New projects are allowed to append at the end.
  const hasPendingNewSession = Boolean(
    optimisticSession
    || [...runningSessionIds, ...exitedSessions.keys()].some((id) => !allSessions.some((session) => session.id === id)),
  );
  const sortedProjectsBase = useMemo(() => sortManagedProjects(visibleProjects), [visibleProjects]);
  const sortedProjectsRef = useRef<ManagedProject[] | null>(null);
  const sortedProjects = useMemo(() => {
    if (hasPendingNewSession && sortedProjectsRef.current) {
      const prev = sortedProjectsRef.current;
      const prevKeys = new Set(prev.map((p) => comparableProjectPath(p.path)));
      const next = [...prev];
      for (const p of sortedProjectsBase) if (!prevKeys.has(comparableProjectPath(p.path))) next.push(p);
      return next;
    }
    sortedProjectsRef.current = sortedProjectsBase;
    return sortedProjectsBase;
  }, [sortedProjectsBase, hasPendingNewSession]);
  /** New sessions need a cwd even before the user picks a workspace: fall
   *  back to the latest session's folder, then the first project, then the
   *  account home. */
  const mostRecentSessionCwd = useMemo(() => {
    let latest: SessionInfo | null = null;
    for (const session of allSessions) {
      if (!session.cwd) continue;
      if (!latest || sessionActivityTime(session) > sessionActivityTime(latest)) latest = session;
    }
    return latest?.cwd ?? null;
  }, [allSessions]);
  const effectiveDefaultCwd = selectedCwd ?? mostRecentSessionCwd ?? sortedProjects[0]?.path ?? homeDir;
  useEffect(() => {
    onWorkspaceOptionsChange?.(sortedProjects, selectedProject, selectedCwd);
  }, [onWorkspaceOptionsChange, sortedProjects, selectedProject, selectedCwd]);
  // Group sessions directly by `session.projectRoot ?? session.cwd`, keyed by
  // the case-folded comparable form so casing-only differences land in the
  // right project bucket.
  const sessionsByProject = useMemo(() => {
    const grouped = new Map<string, SessionInfo[]>();
    const bucketByKey = new Map<string, SessionInfo[]>();
    for (const project of sortedProjects) {
      const bucket: SessionInfo[] = [];
      grouped.set(project.path, bucket);
      bucketByKey.set(comparableProjectPath(project.path), bucket);
    }
    for (const session of visibleSessions) {
      const root = session.projectRoot ?? session.cwd;
      if (!root) continue;
      bucketByKey.get(comparableProjectPath(root))?.push(session);
    }
    return grouped;
  }, [sortedProjects, visibleSessions]);
  const projectActivity = useMemo(
    () => projectActivityCounts(visibleSessions, runningSessionIds, unreadSessionIds, exitedSessions.keys()),
    [visibleSessions, runningSessionIds, unreadSessionIds, exitedSessions],
  );

  // Client-side filtering (Workspaces header: search + "running only").
  // While a filter is active, workspaces with no matching sessions are hidden
  // so the list reads as a genuine result set; at rest every workspace stays.
  // Deferred search: typing stays responsive (input updates immediately) while the heavy
  // visibleProjectEntries filter runs at lower priority. Combines with the 200ms ETag loadSessions
  // debounce already in place — keystrokes never block the main thread on large session lists.
  const deferredSearchQuery = useDeferredValue(searchQuery);
  const filtersActive = searchOpen || runningOnly || deferredSearchQuery.trim().length > 0;
  const visibleProjectEntries = useMemo(() => {
    const q = deferredSearchQuery.trim().toLowerCase();
    const entries: { project: ManagedProject; sessions: SessionInfo[] }[] = [];
    for (const project of sortedProjects) {
      let list = sessionsByProject.get(project.path) ?? [];
      if (runningOnly) list = list.filter((s) => runningSessionIds.has(s.id));
      if (q) {
        list = list.filter((s) => (s.name ?? "").toLowerCase().includes(q) || s.firstMessage.toLowerCase().includes(q));
      }
      // Label/alias-only matches surface as empty workspaces; without this
      // clause a custom workspace name would be unfindable by search.
      if (list.length === 0 && (runningOnly || (q && !projectLabel(project.path).toLowerCase().includes(q) && !(project.alias ?? "").toLowerCase().includes(q)))) continue;
      entries.push({ project, sessions: list });
    }
    return entries;
  }, [sortedProjects, sessionsByProject, runningOnly, deferredSearchQuery, runningSessionIds]);

  const treesByProject = useMemo(() => {
    const m = new Map<string, SessionTreeNode[]>();
    for (const { project, sessions } of visibleProjectEntries) m.set(project.path, buildSessionTree(sessions));
    return m;
  }, [visibleProjectEntries]);

  // Flat "sessions" view: one row per session, filtered like the workspace
  // tree but ordered purely by latest activity (buildSessionTree sorts it).
  const visibleFlatSessions = useMemo(() => {
    const q = deferredSearchQuery.trim().toLowerCase();
    let list = visibleSessions;
    if (runningOnly) list = list.filter((session) => runningSessionIds.has(session.id));
    if (q) {
      list = list.filter((session) => (session.name ?? "").toLowerCase().includes(q)
        || session.firstMessage.toLowerCase().includes(q)
        || session.cwd.toLowerCase().includes(q));
    }
    return list;
  }, [visibleSessions, runningOnly, runningSessionIds, deferredSearchQuery]);
  const flatSessionTree = useMemo(() => buildSessionTree(visibleFlatSessions), [visibleFlatSessions]);

  // Drop persisted expansion keys whose project no longer exists (removed or
  // vanished), so the storage stays bounded to real projects. Only runs after
  // the first project fetch — an empty list mid-load must never wipe storage.
  useEffect(() => {
    if (expandedProjects === null || !projectsLoadedRef.current) return;
    const known = new Set(sortedProjects.map((p) => comparableProjectPath(p.path)));
    const stale = [...expandedProjects].filter((path) => !known.has(comparableProjectPath(path)));
    if (stale.length === 0) return;
    setExpandedProjects((prev) => {
      if (!prev) return prev;
      const next = new Set(prev);
      stale.forEach((path) => next.delete(path));
      return next;
    });
  }, [expandedProjects, sortedProjects]);

  // True while the auto-selected project was chosen before projects loaded
  // (ordering incomplete); cleared by any manual activation.
  const provisionalSelectionRef = useRef(false);

  // A just-started session's JSONL is not flushed until its first turn makes
  // progress, so a URL reopened in that window has no list entry yet. Retry
  // the list a few times before declaring the restore failed.
  const restoreRetryRef = useRef(0);
  const restoreRetryTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(() => () => {
    if (restoreRetryTimerRef.current) {
      clearTimeout(restoreRetryTimerRef.current);
      restoreRetryTimerRef.current = null;
    }
  }, []);

  // Auto-select cwd and restore session from URL on first load
  useEffect(() => {
    if (skipInitialProjectSelection) return;

    // If restoring a session, set cwd to match that session
    if (initialSessionId && !restoredRef.current) {
      // An empty list only blocks while the first load is still in flight —
      // a settled-but-empty or failed load means the target will never appear
      // (shared ?session= link, deleted session), so fall through to the
      // retry/exhaustion path below instead of returning forever.
      if (allSessions.length === 0 && !initialLoadedRef.current) return; // wait for sessions to load
      const target = allSessions.find((s) => s.id === initialSessionId);
      if (target) {
        restoreRetryRef.current = 0;
        restoredRef.current = true;
        setSelectedCwd(target.cwd);
        expandProject(comparableProjectPath(workspaceKeyOf(target)));
        onSelectSession(target, true);
        return;
      }
      if (restoreRetryRef.current < INITIAL_RESTORE_MAX_ATTEMPTS) {
        restoreRetryRef.current += 1;
        if (restoreRetryTimerRef.current) {
          clearTimeout(restoreRetryTimerRef.current);
          restoreRetryTimerRef.current = null;
        }
        restoreRetryTimerRef.current = setTimeout(() => {
          restoreRetryTimerRef.current = null;
          void loadSessions(false);
        }, INITIAL_RESTORE_RETRY_MS);
        return;
      }
      restoreRetryRef.current = 0;
      restoredRef.current = true;
      // Session not found — notify parent so it can show the placeholder
      onInitialRestoreDone?.();
    }
    // No restore target: activate the top project (most recently added) so New
    // Session and Explorer have a context. When projects have not loaded yet
    // the ordering is provisional — re-pick once they arrive, unless the user
    // already activated a project by hand.
    if (selectedCwd !== null && !provisionalSelectionRef.current) return;
    const top = sortedProjects[0];
    const fallbackCwd = top?.path ?? mostRecentSessionCwd ?? homeDir;
    if (!fallbackCwd) return;
    setSelectedCwd(fallbackCwd);
    if (top) expandProject(top.path);
    provisionalSelectionRef.current = allSessions.length === 0;
  }, [allSessions, selectedCwd, initialSessionId, skipInitialProjectSelection, onSelectSession, onInitialRestoreDone, sortedProjects, expandProject, loadSessions, mostRecentSessionCwd, homeDir]);

  // Default expansion: when the user has never stored an expansion choice,
  // expand only the active project.
  const defaultExpandedRef = useRef(false);
  useEffect(() => {
    if (defaultExpandedRef.current) return;
    const project = selectedProject;
    if (!project) return;
    defaultExpandedRef.current = true;
    if (expandedProjects === null) expandProject(project);
  }, [selectedProject, expandedProjects, expandProject]);

  const commitAddProject = useCallback(async (candidate?: string, launchConfig?: ProjectLaunchConfig) => {
    const path = (candidate ?? "").trim();
    if (!path || addProjectBusy) return;

    setAddProjectBusy(true);
    setAddProjectError(null);
    try {
      const res = await fetch("/api/projects", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ cwd: path, launchConfig }),
      });
      const data = await res.json().catch(() => ({})) as { project?: ManagedProject; error?: string; code?: string };
      if (!res.ok || data.error || !data.project) {
        setAddProjectError(formatApiError({ ...data, error: data.error ?? `HTTP ${res.status}` }));
        return;
      }
      await loadProjects();
      // Activate + expand the newly added project and close the picker.
      setSelectedCwd(data.project.path);
      expandProject(data.project.path);
      setAddProjectOpen(false);
    } catch (e) {
      setAddProjectError(e instanceof Error ? e.message : String(e));
    } finally {
      setAddProjectBusy(false);
    }
  }, [addProjectBusy, loadProjects, expandProject, setAddProjectOpen]);

  const handleUpdateProjectPresentation = useCallback(async (projectPath: string, updates: { alias?: string | null; sortOrder?: number | null; launchConfig?: ProjectLaunchConfig | null }) => {
    try {
      const response = await fetch("/api/projects", { method: "PATCH", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ cwd: projectPath, ...updates }) });
      if (!response.ok) throw new Error(t("projects.updateFailed"));
      await loadProjects();
    } catch (error) {
      toast.error(error instanceof Error ? error.message : String(error));
      throw error;
    }
  }, [loadProjects, t]);

  /** Persist one whole-list order as a single atomic batched PATCH. */
  const persistProjectOrder = useCallback(async (next: ManagedProject[]) => {
    try {
      // One batched request: the server applies every entry in a single
      // atomic registry save, so per-project writes can't interleave and lose
      // updates. Discovered projects included here are registered server-side.
      const response = await fetch("/api/projects", {
        method: "PATCH",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ updates: next.map((project, index) => ({ cwd: project.path, sortOrder: index })) }),
      });
      if (!response.ok) throw new Error(t("projects.reorderFailed"));
      await loadProjects();
    } catch (error) {
      toast.error(error instanceof Error ? error.message : String(error));
    }
  }, [loadProjects, t]);

  const handleProjectDrop = useCallback(async (targetPath: string) => {
    const sourcePath = draggedProjectPath;
    setDraggedProjectPath(null);
    if (!sourcePath || sourcePath === targetPath) return;
    const next = [...sortedProjects];
    const from = next.findIndex((project) => project.path === sourcePath);
    const to = next.findIndex((project) => project.path === targetPath);
    if (from < 0 || to < 0) return;
    const [moved] = next.splice(from, 1);
    if (!moved) return;
    next.splice(to, 0, moved);
    await persistProjectOrder(next);
  }, [draggedProjectPath, sortedProjects, persistProjectOrder]);

  /** Keyboard-accessible reorder: move one project up/down the list. */
  const handleMoveProject = useCallback(async (projectPath: string, delta: -1 | 1) => {
    const next = [...sortedProjects];
    const index = next.findIndex((project) => project.path === projectPath);
    const target = index + delta;
    if (index < 0 || target < 0 || target >= next.length) return;
    const [moved] = next.splice(index, 1);
    if (!moved) return;
    next.splice(target, 0, moved);
    await persistProjectOrder(next);
  }, [sortedProjects, persistProjectOrder]);

  const handleRemoveProject = useCallback(async (projectPath: string) => {
    if (removeProjectPath) return;
    setRemoveProjectPath(projectPath);
    try {
      const res = await fetch("/api/projects", {
        method: "DELETE",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ cwd: projectPath }),
      });
      const data = await res.json().catch(() => ({})) as { success?: boolean; error?: string; code?: string };
      if (!res.ok || !data.success) {
        toast.error(formatApiError({ ...data, error: data.error ?? `HTTP ${res.status}` }));
        return;
      }
      // Hiding the active project leaves nothing selected; activate the next
      // most-relevant project so New Session and Explorer stay usable.
      // Compare case-folded — the selected cwd can spell the project path
      // with different casing than this row (Windows/NTFS).
      if (selectedProject !== null && comparableProjectPath(selectedProject) === comparableProjectPath(projectPath)) {
        const next = sortedProjects.find((p) => p.path !== projectPath);
        setSelectedCwd(next ? next.path : null);
      }
      collapseProject(projectPath);
      await loadProjects();
    } catch (e) {
      toast.error(e instanceof Error ? e.message : String(e));
    } finally {
      setRemoveProjectPath(null);
    }
  }, [removeProjectPath, selectedProject, sortedProjects, collapseProject, loadProjects]);

  // Clicking a session moves the effective cwd to that session's cwd. Done on
  // the click path (not only via the selectedCwd prop sync) so it also works
  // when the prop value won't change. Selecting a session also activates and
  // expands its containing project.
  const handleSelectSessionFromList = useCallback((s: SessionInfo) => {
    provisionalSelectionRef.current = false;
    if (s.cwd) setSelectedCwd(s.cwd);
    expandProject(comparableProjectPath(workspaceKeyOf(s)));
    onSelectSession(s);
  }, [onSelectSession, expandProject]);

  const handleNewSession = useCallback(() => {
    if (!effectiveDefaultCwd) return;
    // Keep the manual selection honest: a fallback cwd becomes the active one
    // so the Explorer and the workspace switcher agree with the new chat.
    if (selectedCwd !== effectiveDefaultCwd) {
      provisionalSelectionRef.current = false;
      setSelectedCwd(effectiveDefaultCwd);
    }
    // Generate a temporary UUID client-side — no backend call needed.
    // Pi will be spawned lazily when the user sends the first message.
    const tempId = typeof crypto.randomUUID === "function"
      ? crypto.randomUUID()
      : `${Date.now().toString(36)}-${Math.random().toString(36).slice(2)}-${Math.random().toString(36).slice(2)}`;
    onNewSession?.(tempId, effectiveDefaultCwd);
  }, [effectiveDefaultCwd, selectedCwd, onNewSession]);

  // Sessions of every folder in the selected project are shown together.
  // Keys are comparableProjectPath forms (see expandProject) — comparable to
  // the folded registry paths rows are checked against.
  const expandedProjectKeys = expandedProjects ?? EMPTY_PROJECT_SET;

  // Stable callbacks for the session list so memoized children don't re-render
  // on every parent state change.
  const handleSessionDeleted = useCallback((id: string) => {
    const deleted = allSessions.find((session) => session.id === id);
    if (deleted) clearLastOpenSession(workspaceKeyOf(deleted));
    onSessionDeleted?.(id);
    loadSessions();
  }, [allSessions, onSessionDeleted, loadSessions]);

  useEffect(() => {
    const selected = allSessions.find((session) => session.id === selectedSessionId);
    if (selected) setLastOpenSession(workspaceKeyOf(selected), selected.id);
  }, [allSessions, selectedSessionId]);

  return (
    <div className="sidebar-shell" style={{ display: "flex", flexDirection: "column", height: "100%", overflow: "hidden", paddingBottom: "env(safe-area-inset-bottom)" }}>
      {addProjectOpen && (
        <DirectoryPicker
          busy={addProjectBusy}
          error={addProjectError}
          onCancel={() => {
            setAddProjectOpen(false);
            setAddProjectError(null);
          }}
          onSelect={(path, launchConfig) => void commitAddProject(path, launchConfig)}
        />
      )}
      {launchConfigProject && (
        <ProjectLaunchConfigDialog
          projectPath={launchConfigProject.path}
          initialConfig={launchConfigProject.launchConfig}
          onClose={() => setLaunchConfigProject(null)}
          onSave={async (launchConfig) => {
            await handleUpdateProjectPresentation(launchConfigProject.path, { launchConfig });
            toast.info(t("sessionSidebar.launchConfigSaved"));
          }}
        />
      )}
      {/* Header: branding + quiet utilities + New Session */}
      <div
        style={{
          padding: "10px 10px 8px",
          borderBottom: "1px solid var(--border)",
          flexShrink: 0,
          display: "flex",
          flexDirection: "column",
          gap: 8,
        }}
      >
        <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between" }}>
          <div style={{ display: "flex", alignItems: "center", gap: 4, minWidth: 0 }}>
            {onClose && (
              <button
                type="button"
                onClick={onClose}
                title={t("appShell.hideSidebar")}
                aria-label={t("appShell.hideSidebar")}
                className="shell-toolbar-btn ui-focus-ring"
              >
                <X size={16} strokeWidth={1.8} aria-hidden="true" />
              </button>
            )}
            <AideskTitle />
          </div>
          <div style={{ display: "flex", gap: 2 }}>
            {navigation && (
              <span className="sidebar-nav-buttons">
                <Tooltip content={`${t("sessionSidebar.navigateBack")} (${navigation.backShortcut})`} side="bottom">
                  <SidebarIconButton
                    label={t("sessionSidebar.navigateBack")}
                    onClick={navigation.onBack}
                    disabled={!navigation.canBack}
                  >
                    <ArrowLeft size={15} strokeWidth={1.9} aria-hidden="true" />
                  </SidebarIconButton>
                </Tooltip>
                <Tooltip content={`${t("sessionSidebar.navigateForward")} (${navigation.forwardShortcut})`} side="bottom">
                  <SidebarIconButton
                    label={t("sessionSidebar.navigateForward")}
                    onClick={navigation.onForward}
                    disabled={!navigation.canForward}
                  >
                    <ArrowRight size={15} strokeWidth={1.9} aria-hidden="true" />
                  </SidebarIconButton>
                </Tooltip>
              </span>
            )}
            {onOpenArchive && (
              <Tooltip content={t("sessionSidebar.archiveBrowserTitle")} side="bottom">
                <SidebarIconButton
                  label={t("sessionSidebar.archiveBrowser")}
                  onClick={onOpenArchive}
                >
                  <Archive size={14} strokeWidth={1.9} aria-hidden="true" />
                </SidebarIconButton>
              </Tooltip>
            )}
            <Tooltip content={t("sessionSidebar.refresh")} side="bottom">
              <SidebarIconButton
                label={t("sessionSidebar.refresh")}
                active={sessionRefreshDone}
                onClick={() => {
                  loadSessions(false);
                  void loadProjects();
                }}
              >
                {sessionRefreshDone ? (
                  <Check size={14} strokeWidth={2.2} aria-hidden="true" />
                ) : (
                  <RefreshCw size={14} strokeWidth={1.9} aria-hidden="true" />
                )}
              </SidebarIconButton>
            </Tooltip>
          </div>
        </div>
        <button
          onClick={handleNewSession}
          disabled={!effectiveDefaultCwd}
          className="sidebar-new-session"
          title={effectiveDefaultCwd ? t("sessionSidebar.newSessionIn", { cwd: effectiveDefaultCwd }) : t("sessionSidebar.selectProjectFirst")}
          style={{
            width: "100%",
            height: 38,
            boxSizing: "border-box",
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            gap: 7,
            background: "var(--bg-hover)",
            border: "1px solid var(--border)",
            borderRadius: "var(--radius-control)",
            color: effectiveDefaultCwd ? "var(--text)" : "var(--text-dim)",
            cursor: effectiveDefaultCwd ? "pointer" : "not-allowed",
            fontSize: 12.5,
            fontWeight: 600,
            letterSpacing: "-0.01em",
            opacity: effectiveDefaultCwd ? 1 : 0.65,
            transition: SIDEBAR_BUTTON_TRANSITION,
          }}
          onMouseEnter={(e) => {
            if (!effectiveDefaultCwd) return;
            e.currentTarget.style.background = "var(--bg-selected)";
            e.currentTarget.style.borderColor = "color-mix(in srgb, var(--accent) 30%, transparent)";
          }}
          onMouseLeave={(e) => {
            e.currentTarget.style.background = "var(--bg-hover)";
            e.currentTarget.style.borderColor = "var(--border)";
          }}
        >
          <Plus size={15} strokeWidth={2.2} style={{ color: "var(--accent)", flexShrink: 0 }} aria-hidden="true" />
          <span>{t("sessionSidebar.new")}</span>
        </button>
      </div>

      {/* List header: Sessions / Workspaces switch + search / filter / add */}
      <div style={{ flexShrink: 0, padding: "4px 10px 2px", display: "flex", alignItems: "center", gap: 2 }}>
        <div className="sidebar-view-switch" role="tablist" aria-label={t("sessionSidebar.viewModeLabel")}>
          <button
            type="button"
            role="tab"
            aria-selected={viewMode === "sessions"}
            data-active={viewMode === "sessions"}
            className="sidebar-view-tab ui-focus-ring"
            title={t("sessionSidebar.viewSessionsTitle")}
            onClick={() => setViewMode("sessions")}
          >
            <MessageSquare size={12} strokeWidth={2} aria-hidden="true" />
            <span>{t("sessionSidebar.viewSessions")}</span>
          </button>
          <button
            type="button"
            role="tab"
            aria-selected={viewMode === "workspaces"}
            data-active={viewMode === "workspaces"}
            className="sidebar-view-tab ui-focus-ring"
            title={t("sessionSidebar.viewWorkspacesTitle")}
            onClick={() => setViewMode("workspaces")}
          >
            <Folder size={12} strokeWidth={2} aria-hidden="true" />
            <span>{t("projects.heading")}</span>
          </button>
        </div>
        <SidebarIconButton
          label={t("sessionSidebar.search")}
          title={t("sessionSidebar.searchTitle")}
          active={searchOpen}
          onClick={() => {
            const nextOpen = !searchOpen;
            setSearchOpen(nextOpen);
            if (nextOpen) setTimeout(() => searchInputRef.current?.focus(), 0);
            else setSearchQuery("");
          }}
        >
          <Search size={15} strokeWidth={1.9} aria-hidden="true" />
        </SidebarIconButton>
        <SidebarIconButton
          label={t("sessionSidebar.filterRunning")}
          title={t("sessionSidebar.filterRunningTitle")}
          active={runningOnly}
          onClick={() => setRunningOnly((v) => !v)}
        >
          <SlidersHorizontal size={15} strokeWidth={1.9} aria-hidden="true" />
        </SidebarIconButton>
        {viewMode === "workspaces" && (
          <SidebarIconButton
            label={t("projects.add")}
            title={t("projects.addTitle")}
            onClick={() => {
              setAddProjectOpen(true);
              setAddProjectError(null);
            }}
          >
            <Plus size={15} strokeWidth={1.9} aria-hidden="true" />
          </SidebarIconButton>
        )}
      </div>
      {searchOpen && (
        <div style={{ padding: "0 10px 6px", flexShrink: 0 }}>
          <input
            className="sidebar-session-search"
            ref={searchInputRef}
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === "Escape") {
                e.preventDefault();
                setSearchOpen(false);
                setSearchQuery("");
              }
            }}
            placeholder={t("sessionSidebar.searchPlaceholder")}
            aria-label={t("sessionSidebar.search")}
            style={{
              width: "100%",
              height: 27,
              boxSizing: "border-box",
              padding: "0 9px",
              background: "var(--bg)",
              border: "1px solid var(--border)",
              borderRadius: "var(--radius-control)",
              outline: "none",
              color: "var(--text)",
              fontSize: 12,
            }}
            onFocus={(e) => { e.currentTarget.style.borderColor = "var(--accent)"; }}
            onBlur={(e) => { e.currentTarget.style.borderColor = "var(--border)"; }}
          />
        </div>
      )}

      {/* Session list (flat) or workspace tree */}
        <div
          style={{
            flex: "1 1 auto",
            overflowY: "auto",
            padding: "2px 10px 10px",
            minHeight: 80,
          }}
        >
          {loading && (
            <div role="status" aria-live="polite" aria-label={t("sessionSidebar.loading")} style={{ display: "grid", gap: 10, padding: "10px 4px" }}>
              <div aria-hidden="true" className="skeleton" style={{ width: "78%", height: 18 }} />
              <div aria-hidden="true" className="skeleton" style={{ width: "92%", height: 30 }} />
              <div aria-hidden="true" className="skeleton" style={{ width: "86%", height: 30 }} />
              <div aria-hidden="true" className="skeleton" style={{ width: "68%", height: 30 }} />
            </div>
          )}
          {viewMode === "workspaces" && projectsError && (
            <div role="alert" style={{ display: "flex", alignItems: "center", justifyContent: "space-between", gap: 8, padding: "10px 4px", color: "var(--status-error)", fontSize: 12 }}>
              <span>{projectsError}</span>
              <button className="load-retry-button" type="button" onClick={() => { loadSessions(false); void loadProjects(); }} style={{ minHeight: 32, padding: "4px 8px", border: "1px solid var(--border)", borderRadius: "var(--radius-control)", background: "var(--bg-panel)", color: "var(--text)", cursor: "pointer", fontSize: 11, fontWeight: 600 }}>{t("sessionSidebar.refresh")}</button>
            </div>
          )}
          {error && (
            <div role="alert" style={{ display: "flex", alignItems: "center", justifyContent: "space-between", gap: 8, padding: "10px 4px", color: "var(--status-error)", fontSize: 12 }}>
              <span>{error}</span>
              <button className="load-retry-button" type="button" onClick={() => { loadSessions(false); void loadProjects(); }} style={{ minHeight: 32, padding: "4px 8px", border: "1px solid var(--border)", borderRadius: "var(--radius-control)", background: "var(--bg-panel)", color: "var(--text)", cursor: "pointer", fontSize: 11, fontWeight: 600 }}>{t("sessionSidebar.refresh")}</button>
            </div>
          )}

          {viewMode === "sessions" ? (
            <>
              {!loading && !error && flatSessionTree.length === 0 && (
                <div style={{ padding: "14px 4px", color: "var(--text-dim)", fontSize: 11.5, lineHeight: 1.5 }}>
                  {filtersActive ? t("sessionSidebar.noMatches") : t("sessionSidebar.noSessions")}
                </div>
              )}
              {flatSessionTree.map((node) => (
                <SessionTreeItem
                  key={node.session.id}
                  node={node}
                  selectedSessionId={selectedSessionId}
                  runningSessionIds={runningSessionIds}
                  unreadSessionIds={unreadSessionIds}
                  exitedSessions={exitedSessions}
                  relativeTimeNow={relativeTimeNow}
                  onSelectSession={handleSelectSessionFromList}
                  onRenamed={loadSessions}
                  onSessionDeleted={handleSessionDeleted}
                  depth={0}
                  showCwd
                  homeDir={homeDir}
                />
              ))}
            </>
          ) : (
            <>
              {!loading && !projectsError && !error && sortedProjects.length === 0 && (
                <div style={{ padding: "10px 4px", color: "var(--text-muted)", fontSize: 12, lineHeight: 1.5 }}>
                  {t("projects.noProjects")}
                </div>
              )}
              {!loading && !projectsError && !error && sortedProjects.length > 0 && visibleProjectEntries.length === 0 && (
                <div style={{ padding: "14px 4px", color: "var(--text-dim)", fontSize: 11.5, lineHeight: 1.5 }}>
                  {t("sessionSidebar.noMatches")}
                </div>
              )}

              {visibleProjectEntries.map(({ project, sessions }) => {
                const tree = treesByProject.get(project.path) ?? buildSessionTree(sessions);
                // Sessions group under a project through the case-folded comparable
                // form, so the active highlight uses the same comparison: a session
                // whose cwd/projectRoot spells the project folder with different
                // casing (Windows/NTFS) lands in this row — the row must light up
                // for it too.
                const isActive = selectedProject !== null && comparableProjectPath(selectedProject) === comparableProjectPath(project.path);
                return (
                  <ProjectRow
                    key={project.path}
                    project={project}
                    isActive={isActive}
                    activity={projectActivity.get(comparableProjectPath(project.path))}
                    tree={tree}
                    isExpanded={expandedProjectKeys.has(comparableProjectPath(project.path))}
                    hiddenCount={filtersActive ? 0 : Math.max(0, tree.length - MAX_PROJECT_SESSIONS)}
                    selectedSessionId={selectedSessionId}
                    runningSessionIds={runningSessionIds}
                    unreadSessionIds={unreadSessionIds}
                    exitedSessions={exitedSessions}
                    relativeTimeNow={relativeTimeNow}
                    onActivate={activateProject}
                    onToggleExpand={toggleProjectExpanded}
                    onRemoveProject={handleRemoveProject}
                    onEditLaunchConfig={setLaunchConfigProject}
                    onUpdatePresentation={handleUpdateProjectPresentation}
                    onDragPathChange={setDraggedProjectPath}
                    onDropProject={(path) => void handleProjectDrop(path)}
                    onMoveProject={(path, delta) => void handleMoveProject(path, delta)}
                    isDragTarget={draggedProjectPath !== null && draggedProjectPath !== project.path}
                    removeBusy={removeProjectPath === project.path}
                    onSelectSession={handleSelectSessionFromList}
                    onRenamed={loadSessions}
                    onSessionDeleted={handleSessionDeleted}
                  />
                );
              })}
            </>
          )}
        </div>

      {/* Pinned footer: Settings */}
      <div style={{ borderTop: "1px solid var(--border)", flexShrink: 0 }}>
        <button
          className="sidebar-settings-row"
          data-active={settingsOpen}
          onClick={onOpenSettings}
          title={t("chatInput.settings")}
          aria-label={t("chatInput.settings")}
          style={{
            width: "100%",
            height: 36,
            boxSizing: "border-box",
            display: "flex",
            alignItems: "center",
            gap: 9,
            padding: "0 12px",
            background: settingsOpen ? "var(--bg-selected)" : "none",
            border: "none",
            color: settingsOpen ? "var(--text)" : "var(--text-muted)",
            cursor: "pointer",
            textAlign: "left",
            transition: SIDEBAR_BUTTON_TRANSITION,
          }}
          onMouseEnter={(e) => { e.currentTarget.style.background = settingsOpen ? "var(--bg-selected)" : "var(--bg-hover)"; e.currentTarget.style.color = "var(--text)"; }}
          onMouseLeave={(e) => { e.currentTarget.style.background = settingsOpen ? "var(--bg-selected)" : "none"; e.currentTarget.style.color = settingsOpen ? "var(--text)" : "var(--text-muted)"; }}
        >
          <Settings2 size={14} strokeWidth={2} aria-hidden="true" style={{ flexShrink: 0, color: "var(--accent)" }} />
          <span style={{ flex: 1, minWidth: 0, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap", fontSize: 12, fontWeight: 500 }}>
            {t("chatInput.settings")}
          </span>
          <ChevronRight size={13} strokeWidth={2} style={{ flexShrink: 0, color: "var(--text-dim)" }} aria-hidden="true" />
        </button>
      </div>
    </div>
  );
});







