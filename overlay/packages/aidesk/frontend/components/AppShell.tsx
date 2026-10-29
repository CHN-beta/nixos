
import { lazy, Suspense, useState, useCallback, useRef, useEffect, useLayoutEffect, useMemo } from "react";
import { useGlobalKeyboardShortcuts } from "@/hooks/useKeyboardShortcuts";
import { useSidebarHistory } from "@/hooks/useSidebarHistory";
import { useModalDialog } from "@/hooks/useModalDialog";
import { useNavigationHistory } from "@/hooks/useNavigationHistory";
import { isMacPlatform, navigateShortcutHint, NAVIGATION_HISTORY_MAX_ENTRIES } from "@/lib/navigation-history";
import { useMobileSidebarGestures } from "@/hooks/useMobileSidebarGestures";
import { SessionSidebar } from "./SessionSidebar";
import { ToastProvider } from "./ui/toast";
import { toast } from "./ui/toast";
import { notificationHistory, useUnreadNotificationCount } from "@/lib/notification-history";
import { ConfirmDialog } from "./ui/field";
import { ChatWindow } from "./ChatWindow";
import { type Tab } from "./TabBar";
import { type FileExplorerHandle } from "./FileExplorer";
import type { FileOpenMode } from "@/lib/file-types";
import type { RightPanelView } from "./RightPanel";
import { BranchNavigator } from "./BranchNavigator";
import { LanguageSwitcher } from "./LanguageSwitcher";
import { Check, ChevronDown, Ellipsis, Folder, History, Menu, PanelLeft, PanelRight, Wand2, Zap } from "lucide-react";
import { ThemeSwitcher } from "./ThemeSwitcher";
import { translate, useI18n } from "@/lib/i18n";
import { apiUrl } from "@/lib/api-origin";
import { formatApiError } from "@/lib/i18n/api-error";
import { formatGenerationSpeed } from "@/lib/generation-speed";
import { useIsMobile } from "@/hooks/useIsMobile";
import { useIsCompactOverlay } from "@/hooks/useIsCompactOverlay";
import { copyText } from "@/lib/clipboard";
import { encodeFilePathForApi, getFileName, getRelativeFilePath } from "@/lib/file-paths";
import { buildAtMentionText, buildFileAtMentionsText, buildFileLineMentionText } from "@/lib/file-fuzzy";
import { getInitialNavigation } from "@/lib/initial-navigation";
import { comparableProjectPath } from "@/lib/comparable-path";
import { clearDraft } from "@/lib/draft-store";
import { useNotifications } from "@/hooks/useNotifications";
import {
  PanelLoadingFallback,
  RIGHT_PANEL_MIN_WIDTH,
  RIGHT_PANEL_WIDTH_STORAGE_KEY,
  SIDEBAR_DEFAULT_WIDTH,
  SIDEBAR_WIDTH_STORAGE_KEY,
  clampRightPanelWidth,
  clampSidebarWidth,
  loadRightPanelWidth,
  loadSidebarWidth,
  projectLabel,
  WorkspaceState,
} from "./AppShell-layout";
import type { CrossSessionHostToolCall, ManagedProject, SessionInfo, SessionTreeNode } from "@/lib/types";
import { runHostTool } from "@/hooks/useAgentSession-stream";
import { sendAgentCommand } from "@/lib/agent-client";
import type { ChatInputHandle } from "./ChatInput";
import type { SessionStatsInfo, GenerationSpeedInfo } from "@/lib/pi-types";
import type { SettingsTab } from "./SettingsTabs";
import { SettingsConfig } from "./SettingsConfig";
import { ArchiveBrowser } from "./ArchiveBrowser";
import { publishSessionsChanged } from "@/lib/session-change-bus";
// The settings shell is part of the app bundle so opening it does not fetch or compile a modal chunk. The right panel (viewer included) is a separate chunk, preloaded on the first pointerdown or keydown and mounted on first open.
// No loading placeholder: it would take the panel's place in the layout (on
// phones, squeezing out the chat) for a frame even when the code is cached.
const RightPanel = lazy(() => import("./RightPanel").then((module) => ({ default: module.RightPanel })));

/** Replace the current history entry. The SPA renders from state; the URL only
 *  carries shareable `?session=` links, so no router is needed. */
function replaceHistoryUrl(url: string): void {
  window.history.replaceState(null, "", url);
}

const TOOL_CALLS_COLLAPSED_STORAGE_KEY = "omp-web:tool-calls-collapsed";
// Off by default, so the transcript keeps collapsing reasoning until asked.
const EXPAND_THINKING_STORAGE_KEY = "omp-web:expand-thinking";
const NATIVE_SELECT_ALL_STORAGE_KEY = "omp-web:scope-native-select-all";
const OPEN_URL_AUTOMATICALLY_STORAGE_KEY = "omp-web:open-url-automatically";


type AutoNameStatus =
  | { kind: "idle" }
  | { kind: "naming" }
  | { kind: "success" }
  | { kind: "error"; message: string };
type TimerHandle = NodeJS.Timeout;

export function AppShell({ appName }: { appName: string }) {
  const [initialNavigation] = useState(() => getInitialNavigation(new URLSearchParams(window.location.search)));
  const { t, locale } = useI18n();
  const isMobile = useIsMobile();
  const isCompactOverlay = useIsCompactOverlay();
  const [selectedSession, setSelectedSession] = useState<SessionInfo | null>(null);
  // When user clicks +, we only store the cwd — no fake session id
  const [newSessionCwd, setNewSessionCwd] = useState<string | null>(null);
  const [workspaceOptions, setWorkspaceOptions] = useState<{ projects: ManagedProject[]; selectedProject: string | null; cwd: string | null }>({ projects: [], selectedProject: null, cwd: null });
  const [addProjectOpen, setAddProjectOpen] = useState(false);
  const handleWorkspaceOptionsChange = useCallback((projects: ManagedProject[], selectedProject: string | null, cwd: string | null) => {
    setWorkspaceOptions({ projects, selectedProject, cwd });
  }, []);
  const [initialCwdStatus, setInitialCwdStatus] = useState<"idle" | "validating" | "ready" | "error">(
    () => initialNavigation.requestedCwd ? "validating" : "idle",
  );
  const [initialCwdError, setInitialCwdError] = useState<string | null>(null);
  const [refreshKey, setRefreshKey] = useState(0);
  const [sessionKey, setSessionKey] = useState(0);
  const [explorerRefreshKey, setExplorerRefreshKey] = useState(0);
  const [explorerRefreshing, setExplorerRefreshing] = useState(false);
  const [settingsTab, setSettingsTab] = useState<SettingsTab | null>(null);
  const [archiveBrowserOpen, setArchiveBrowserOpen] = useState(false);
  const [sidebarOpen, setSidebarOpen] = useState(true);
  const [mobileSidebarReady, setMobileSidebarReady] = useState(false);
  const [sidebarWidth, setSidebarWidth] = useState<number>(SIDEBAR_DEFAULT_WIDTH);
  const [toolCallsDefaultCollapsed, setToolCallsDefaultCollapsed] = useState(true);
  // "Expand thinking blocks by default" — like the tool-call preference, a
  // UI-only behavior, so it lives in localStorage rather than omp's config.
  const [expandThinkingByDefault, setExpandThinkingByDefault] = useState(false);
  const [hideThinkingBlock, setHideThinkingBlock] = useState(false);
  useEffect(() => {
    // omp's own setting, so the transcript hides thinking when the TUI does.
    // Re-read on focus: the TUI or another tab may have changed it.
    const load = () => {
      fetch("/api/omp-settings")
        .then((response) => (response.ok ? response.json() : null))
        .then((data: { settings?: { hideThinkingBlock?: boolean } } | null) => { if (data) setHideThinkingBlock(data.settings?.hideThinkingBlock === true); })
        .catch(() => {});
    };
    load();
    window.addEventListener("focus", load);
    return () => window.removeEventListener("focus", load);
  }, []);
  const [scopeNativeSelectAll, setScopeNativeSelectAll] = useState(false);
  const [openUrlAutomatically, setOpenUrlAutomatically] = useState(false);
  const [sidebarResizing, setSidebarResizing] = useState(false);
  // Active drag handlers so an unmount mid-drag can detach them.
  const sidebarResizeHandlersRef = useRef<{ onMove: (ev: MouseEvent) => void; onUp: () => void } | null>(null);
  // DOM element + live width during a drag (see handleSidebarResizeStart).
  const sidebarContainerRef = useModalDialog<HTMLElement>({
    onClose: () => setSidebarOpen(false),
    active: isMobile && mobileSidebarReady && sidebarOpen && !settingsTab,
  });
  const pendingSidebarWidthRef = useRef<number>(SIDEBAR_DEFAULT_WIDTH);
  useEffect(() => {
    setSidebarWidth(loadSidebarWidth());
    try {
      setToolCallsDefaultCollapsed(window.localStorage.getItem(TOOL_CALLS_COLLAPSED_STORAGE_KEY) !== "false");
      setExpandThinkingByDefault(window.localStorage.getItem(EXPAND_THINKING_STORAGE_KEY) === "true");
      setScopeNativeSelectAll(window.localStorage.getItem(NATIVE_SELECT_ALL_STORAGE_KEY) === "true");
      setOpenUrlAutomatically(window.localStorage.getItem(OPEN_URL_AUTOMATICALLY_STORAGE_KEY) === "true");
    } catch {
      // Keep the compact default when storage is unavailable.
    }
  }, []);
  const handleToolCallsDefaultCollapsedChange = useCallback((collapsed: boolean) => {
    setToolCallsDefaultCollapsed(collapsed);
    try {
      window.localStorage.setItem(TOOL_CALLS_COLLAPSED_STORAGE_KEY, String(collapsed));
    } catch {
      // The preference still applies for this page load.
    }
  }, []);
  const handleExpandThinkingByDefaultChange = useCallback((expand: boolean) => {
    setExpandThinkingByDefault(expand);
    try {
      window.localStorage.setItem(EXPAND_THINKING_STORAGE_KEY, String(expand));
    } catch {
      // The preference still applies for this page load.
    }
  }, []);
  const handleScopeNativeSelectAllChange = useCallback((enabled: boolean) => {
    setScopeNativeSelectAll(enabled);
    try {
      window.localStorage.setItem(NATIVE_SELECT_ALL_STORAGE_KEY, String(enabled));
    } catch {
      // The preference still applies for this page load.
    }
  }, []);
  const handleOpenUrlAutomaticallyChange = useCallback((enabled: boolean) => {
    setOpenUrlAutomatically(enabled);
    try {
      window.localStorage.setItem(OPEN_URL_AUTOMATICALLY_STORAGE_KEY, String(enabled));
    } catch {
      // The preference still applies for this page load.
    }
  }, []);
  // Persist the committed width (after each change; skipped mid-drag, then
  // written once the drag ends). The first run is skipped so the mount-time
  // default cannot overwrite the stored width before it is loaded.
  const sidebarWidthMountedRef = useRef(false);
  useEffect(() => {
    if (!sidebarWidthMountedRef.current) {
      sidebarWidthMountedRef.current = true;
      return;
    }
    if (sidebarResizing) return;
    try {
      window.localStorage.setItem(SIDEBAR_WIDTH_STORAGE_KEY, String(sidebarWidth));
    } catch {
      // ignore storage quota / privacy-mode errors
    }
  }, [sidebarWidth, sidebarResizing]);
  // On mobile the sidebar is an overlay drawer; hide it by default so the chat
  // is visible on load. Runs once the breakpoint resolves after hydration.
  useEffect(() => {
    if (isMobile) setSidebarOpen(false);
  }, [isMobile]);
  useEffect(() => {
    setMobileSidebarReady(true);
  }, []);
  // Every right-click target in the app opens its own menu (sessions,
  // workspaces, chat messages, the file tree), so the browser's default menu
  // would only get in the way.
  useEffect(() => {
    const suppress = (event: MouseEvent) => event.preventDefault();
    document.addEventListener("contextmenu", suppress);
    return () => document.removeEventListener("contextmenu", suppress);
  }, []);
  // Chrome does not blur a focused descendant when a subtree becomes
  // aria-hidden + inert (e.g. tapping a session button closes the mobile
  // drawer), which leaves focus trapped where assistive tech cannot see it.
  // Blur synchronously in the same commit so the AX tree never observes a
  // focused element inside the hidden sidebar.
  useLayoutEffect(() => {
    if (sidebarOpen || !mobileSidebarReady) return;
    const container = sidebarContainerRef.current;
    const active = document.activeElement;
    if (container && active instanceof HTMLElement && container.contains(active)) {
      active.blur();
    }
  }, [sidebarOpen, mobileSidebarReady]);
  const chatInputRef = useRef<ChatInputHandle | null>(null);
  const topBarRef = useRef<HTMLDivElement>(null);
  const [sessionInfoContainer, setSessionInfoContainer] = useState<HTMLDivElement | null>(null);

  // Branch navigator state — populated by ChatWindow via onBranchDataChange
  const [branchTree, setBranchTree] = useState<SessionTreeNode[]>([]);
  const [branchActiveLeafId, setBranchActiveLeafId] = useState<string | null>(null);
  const branchLeafChangeFnRef = useRef<((leafId: string | null) => void) | null>(null);

  const handleBranchDataChange = useCallback((tree: SessionTreeNode[], activeLeafId: string | null, onLeafChange: (leafId: string | null) => void) => {
    setBranchTree(tree);
    setBranchActiveLeafId(activeLeafId);
    branchLeafChangeFnRef.current = onLeafChange;
  }, []);

  const handleBranchLeafChange = useCallback((leafId: string | null) => {
    branchLeafChangeFnRef.current?.(leafId);
  }, []);

  // Session stats (tokens + cost) — populated by ChatWindow, displayed in top bar
  const [sessionStats, setSessionStats] = useState<SessionStatsInfo | null>(null);
  const [autoNameStatus, setAutoNameStatus] = useState<AutoNameStatus>({ kind: "idle" });
  const autoNameTimerRef = useRef<TimerHandle | undefined>(undefined);
  const activeSessionIdRef = useRef<string | null>(selectedSession?.id ?? null);
  const archiveRetryTimerRef = useRef<TimerHandle | undefined>(undefined);
  useEffect(() => () => clearTimeout(archiveRetryTimerRef.current), []);
  useLayoutEffect(() => {
    activeSessionIdRef.current = selectedSession?.id ?? null;
  }, [selectedSession?.id]);
  const handleSessionStatsChange = useCallback((stats: SessionStatsInfo | null) => {
    setSessionStats(stats);
  }, []);

  useEffect(() => {
    return () => {
      clearTimeout(autoNameTimerRef.current);
    };
  }, []);

  // Single active panel — only one dropdown open at a time
  const [activeTopPanel, setActiveTopPanel] = useState<"branches" | null>(null);
  const mobileToolsRef = useRef<HTMLDetailsElement>(null);
  const mobileToolsContentRef = useRef<HTMLDivElement>(null);
  const restoreToolsFocusRef = useRef(false);
  const [compactTopbar, setCompactTopbar] = useState<boolean | null>(null);
  useLayoutEffect(() => {
    if (compactTopbar && restoreToolsFocusRef.current) {
      mobileToolsRef.current?.querySelector("summary")?.focus();
      restoreToolsFocusRef.current = false;
    }
  }, [compactTopbar]);
  useEffect(() => {
    if (!compactTopbar) return;
    const closeOnOutside = (event: PointerEvent) => {
      const tools = mobileToolsRef.current;
      if (tools?.open && !tools.contains(event.target as Node)) {
        tools.open = false;
        setActiveTopPanel(null);
      }
    };
    const closeOnEscape = (event: KeyboardEvent) => {
      const tools = mobileToolsRef.current;
      // Nested pickers and session panels handle their own Escape first.
      if (event.key !== "Escape" || event.defaultPrevented || activeTopPanel || !tools?.open) return;
      event.stopPropagation();
      tools.open = false;
      tools.querySelector("summary")?.focus();
    };
    document.addEventListener("pointerdown", closeOnOutside);
    document.addEventListener("keydown", closeOnEscape);
    return () => {
      document.removeEventListener("pointerdown", closeOnOutside);
      document.removeEventListener("keydown", closeOnEscape);
    };
  }, [compactTopbar, activeTopPanel]);
  const toggleTopPanel = useCallback((panel: "branches") => {
    if (isMobile) setSidebarOpen(false);
    setActiveTopPanel((cur) => cur === panel ? null : panel);
  }, [isMobile]);

  // Generation speed — current live t/s and the session average.
  const [generationSpeed, setGenerationSpeed] = useState<GenerationSpeedInfo | null>(null);
  const handleGenerationSpeedChange = useCallback((speed: GenerationSpeedInfo | null) => {
    setGenerationSpeed(speed);
  }, []);
  // /session opens the same information panel as the top-bar control.
  const openSessionStatsPanel = useCallback(() => {
    chatInputRef.current?.openContextPanel();
  }, []);

  const handleSidebarToggle = useCallback(() => {
    if (isMobile) {
      setActiveTopPanel(null);
      if (mobileToolsRef.current) mobileToolsRef.current.open = false;
    }
    setSidebarOpen((open) => !open);
  }, [isMobile]);

  const resetSidebarWidth = useCallback(() => {
    setSidebarWidth(SIDEBAR_DEFAULT_WIDTH);
  }, []);

  const changeSidebarWidth = useCallback((delta: number) => {
    setSidebarWidth((prev) => clampSidebarWidth(prev + delta));
  }, []);

  const handleSidebarResizeKey = useCallback((e: React.KeyboardEvent) => {
    if (e.key === "ArrowLeft") {
      e.preventDefault();
      changeSidebarWidth(-10);
    } else if (e.key === "ArrowRight") {
      e.preventDefault();
      changeSidebarWidth(10);
    } else if (e.key === "Enter" || e.key === " ") {
      e.preventDefault();
      resetSidebarWidth();
    }
  }, [changeSidebarWidth, resetSidebarWidth]);

  const handleSidebarResizeStart = useCallback((e: React.MouseEvent) => {
    if (isMobile) return;
    e.preventDefault();
    const startX = e.clientX;
    const startWidth = sidebarWidth;
    // Interface Scale (html[data-ui-scale] zoom) leaves clientX in viewport
    // pixels while the sidebar width is zoomed layout pixels: scale the drag
    // delta so the edge tracks the pointer at any zoom (same --ui-scale
    // ground truth as the zoom-aware menus in SessionSidebar-chrome).
    let uiScale = 1;
    try {
      const raw = getComputedStyle(document.documentElement).getPropertyValue("--ui-scale");
      const value = parseFloat(raw);
      if (Number.isFinite(value) && value > 0) uiScale = value;
    } catch {
      // SSR/unavailable: fall back to unscaled math.
    }
    setSidebarResizing(true);
    const onMove = (ev: MouseEvent) => {
      const next = clampSidebarWidth(startWidth + (ev.clientX - startX) / uiScale);
      // Write the CSS variable straight to the DOM: the flex row follows the
      // pointer without re-rendering the whole AppShell on every mousemove.
      sidebarContainerRef.current?.style.setProperty("--sidebar-width", `${next}px`);
      pendingSidebarWidthRef.current = next;
    };
    const onUp = () => {
      window.removeEventListener("mousemove", onMove);
      window.removeEventListener("mouseup", onUp);
      sidebarResizeHandlersRef.current = null;
      setSidebarResizing(false);
      // Commit the final width so state and the persisted value agree with
      // what the user actually dragged to.
      setSidebarWidth(pendingSidebarWidthRef.current);
      document.body.style.cursor = "";
      document.body.style.userSelect = "";
    };
    document.body.style.cursor = "col-resize";
    document.body.style.userSelect = "none";
    pendingSidebarWidthRef.current = startWidth;
    sidebarResizeHandlersRef.current = { onMove, onUp };
    window.addEventListener("mousemove", onMove);
    window.addEventListener("mouseup", onUp);
  }, [isMobile, sidebarWidth]);

  // If the app unmounts mid-drag, remove the window listeners and restore the
  // body cursor; otherwise the handlers leak and body stays cursor:col-resize.
  useEffect(() => () => {
    const handlers = sidebarResizeHandlersRef.current;
    if (!handlers) return;
    window.removeEventListener("mousemove", handlers.onMove);
    window.removeEventListener("mouseup", handlers.onUp);
    sidebarResizeHandlersRef.current = null;
    document.body.style.cursor = "";
    document.body.style.userSelect = "";
  }, []);

  const resetRightPanelWidth = useCallback(() => {
    rightPanelRef.current?.style.removeProperty("--right-panel-width");
    setRightPanelWidth(null);
  }, []);

  const changeRightPanelWidth = useCallback((delta: number) => {
    setRightPanelWidth((prev) => {
      // Keyboard steps from the fluid default start at the panel's live
      // width so the first press doesn't jump to the clamp minimum.
      const base = prev ?? rightPanelRef.current?.getBoundingClientRect().width ?? RIGHT_PANEL_MIN_WIDTH;
      const next = clampRightPanelWidth(base + delta);
      rightPanelRef.current?.style.setProperty("--right-panel-width", `${next}px`);
      return next;
    });
  }, []);

  const handleRightPanelResizeKey = useCallback((e: React.KeyboardEvent) => {
    // The handle sits on the panel's left edge: left widens, right narrows.
    if (e.key === "ArrowLeft") {
      e.preventDefault();
      changeRightPanelWidth(10);
    } else if (e.key === "ArrowRight") {
      e.preventDefault();
      changeRightPanelWidth(-10);
    } else if (e.key === "Enter" || e.key === " ") {
      e.preventDefault();
      resetRightPanelWidth();
    }
  }, [changeRightPanelWidth, resetRightPanelWidth]);

  const handleRightPanelResizeStart = useCallback((e: React.MouseEvent) => {
    if (isMobile) return;
    e.preventDefault();
    const startX = e.clientX;
    // Live rect, not state: it always reflects the committed width (custom or
    // fluid default), and keeps this callback above the state declarations
    // without a TDZ cycle. The handle only exists while the panel is open.
    const startWidth = rightPanelRef.current?.getBoundingClientRect().width
      ?? RIGHT_PANEL_MIN_WIDTH;
    // Same --ui-scale ground truth as the left sidebar handle: clientX is in
    // viewport pixels while the panel width is zoomed layout pixels.
    let uiScale = 1;
    try {
      const raw = getComputedStyle(document.documentElement).getPropertyValue("--ui-scale");
      const value = parseFloat(raw);
      if (Number.isFinite(value) && value > 0) uiScale = value;
    } catch {
      // SSR/unavailable: fall back to unscaled math.
    }
    setRightPanelResizing(true);
    const onMove = (ev: MouseEvent) => {
      // Dragging the left edge left grows the panel: inverse of the sidebar.
      const next = clampRightPanelWidth(startWidth - (ev.clientX - startX) / uiScale);
      // Write the CSS variable straight to the DOM: the flex row follows the
      // pointer without re-rendering the whole AppShell on every mousemove.
      rightPanelRef.current?.style.setProperty("--right-panel-width", `${next}px`);
      pendingRightPanelWidthRef.current = next;
    };
    const onUp = () => {
      window.removeEventListener("mousemove", onMove);
      window.removeEventListener("mouseup", onUp);
      rightResizeHandlersRef.current = null;
      setRightPanelResizing(false);
      // Commit the final width so state and the persisted value agree with
      // what the user actually dragged to.
      setRightPanelWidth(pendingRightPanelWidthRef.current);
      document.body.style.cursor = "";
      document.body.style.userSelect = "";
    };
    document.body.style.cursor = "col-resize";
    document.body.style.userSelect = "none";
    pendingRightPanelWidthRef.current = startWidth;
    rightResizeHandlersRef.current = { onMove, onUp };
    window.addEventListener("mousemove", onMove);
    window.addEventListener("mouseup", onUp);
  }, [isMobile]);

  // If the app unmounts mid-drag, remove the window listeners and restore the
  // body cursor; otherwise the handlers leak and body stays cursor:col-resize.
  useEffect(() => () => {
    const handlers = rightResizeHandlersRef.current;
    if (!handlers) return;
    window.removeEventListener("mousemove", handlers.onMove);
    window.removeEventListener("mouseup", handlers.onUp);
    rightResizeHandlersRef.current = null;
    document.body.style.cursor = "";
    document.body.style.userSelect = "";
  }, []);


  // Right panel tabs: Explorer | Git changes | open files (Tauri parity).
  const [fileTabs, setFileTabs] = useState<Tab[]>([]);
  const [activeFileTabId, setActiveFileTabId] = useState<string | null>(null);
  const [rightPanelOpen, setRightPanelOpen] = useState(false);
  const closeRightPanel = useCallback(() => {
    setRightPanelOpen(false);
    if (!isCompactOverlay) {
      topBarRef.current?.querySelector<HTMLButtonElement>(".shell-panel-opener")?.focus();
    }
  }, [isCompactOverlay]);
  const [rightPanelHasOpened, setRightPanelHasOpened] = useState(false);
  const [rightView, setRightView] = useState<RightPanelView>("explorer");
  const unreadNotifications = useUnreadNotificationCount();
  // Unread entries stay highlighted while the Notifications tab is shown and
  // become read once the user leaves it (switches tab or closes the panel).
  const viewingNotifications = rightPanelOpen && rightView === "notifications" && !settingsTab;
  const wasViewingNotificationsRef = useRef(false);
  useEffect(() => {
    if (wasViewingNotificationsRef.current && !viewingNotifications) notificationHistory.markAllRead();
    wasViewingNotificationsRef.current = viewingNotifications;
  }, [viewingNotifications]);
  const opensNotifications = unreadNotifications > 0 && !viewingNotifications;
  const panelOpenerLabel = opensNotifications
    ? t("appShell.showNotifications", { count: unreadNotifications })
    : rightPanelOpen ? t("appShell.hideFilePanel") : t("appShell.showFilePanel");
  // User-chosen pixel width (null = fluid 42% default), persisted.
  const [rightPanelWidth, setRightPanelWidth] = useState<number | null>(null);
  const [rightPanelResizing, setRightPanelResizing] = useState(false);
  // The panel is code-split and mounts a render after its first open, so the
  // dialog behavior (focus, Escape, Tab wrap) waits until the element exists.
  // The rest of the page goes inert at the same moment: made inert earlier,
  // it would drop focus from the opener (e.g. a file link in the chat) before
  // the dialog records it, and closing could not return focus there.
  const [rightPanelMounted, setRightPanelMounted] = useState(false);
  const rightPanelIsModal = isCompactOverlay && rightPanelMounted && rightPanelOpen && !settingsTab;
  const rightPanelRef = useModalDialog<HTMLDivElement>({
    onClose: closeRightPanel,
    active: rightPanelIsModal,
  });
  const attachRightPanel = useCallback((element: HTMLDivElement | null) => {
    rightPanelRef.current = element;
    setRightPanelMounted(element !== null);
  }, [rightPanelRef]);
  useMobileSidebarGestures({
    enabled: isMobile && mobileSidebarReady && !settingsTab,
    leftOpen: sidebarOpen,
    rightOpen: rightPanelOpen,
    onLeftOpenChange: setSidebarOpen,
    onRightOpenChange: setRightPanelOpen,
  });
  const pendingRightPanelWidthRef = useRef<number | null>(null);
  const rightResizeHandlersRef = useRef<{ onMove: (ev: MouseEvent) => void; onUp: () => void } | null>(null);
  useEffect(() => {
    setRightPanelWidth(loadRightPanelWidth());
  }, []);
  useEffect(() => {
    if (rightPanelOpen) setRightPanelHasOpened(true);
  }, [rightPanelOpen]);
  // Fetch the panel's code on the first interaction, so the first open rarely
  // waits for a download while pages nobody touches never fetch it. A failed
  // preload is retried by the first open.
  useEffect(() => {
    const preload = () => {
      window.removeEventListener("pointerdown", preload, true);
      window.removeEventListener("keydown", preload, true);
      import("./RightPanel").catch(() => {});
    };
    window.addEventListener("pointerdown", preload, true);
    window.addEventListener("keydown", preload, true);
    return () => {
      window.removeEventListener("pointerdown", preload, true);
      window.removeEventListener("keydown", preload, true);
    };
  }, []);
  // One-shot request asking the explorer tab to expand + scroll to a file.
  const [revealPath, setRevealPath] = useState<string | null>(null);
  const [fileSearchOpen, setFileSearchOpen] = useState(false);
  const [explorerUploadBusy, setExplorerUploadBusy] = useState(false);
  const [explorerGitCount, setExplorerGitCount] = useState(0);
  const [explorerIsRepo, setExplorerIsRepo] = useState(false);
  const fileExplorerRef = useRef<FileExplorerHandle>(null);
  const handleExplorerGitStatus = useCallback((changedCount: number, isRepo: boolean) => {
    setExplorerGitCount(changedCount);
    setExplorerIsRepo(isRepo);
  }, []);
  // Same guard as the left sidebar: skip the mount run and mid-drag writes. A
  // reset (null) removes the key so the fluid default returns.
  const rightPanelWidthMountedRef = useRef(false);
  useEffect(() => {
    if (!rightPanelWidthMountedRef.current) {
      rightPanelWidthMountedRef.current = true;
      return;
    }
    if (rightPanelResizing) return;
    try {
      if (rightPanelWidth === null) window.localStorage.removeItem(RIGHT_PANEL_WIDTH_STORAGE_KEY);
      else window.localStorage.setItem(RIGHT_PANEL_WIDTH_STORAGE_KEY, String(rightPanelWidth));
    } catch {
      // ignore storage quota / privacy-mode errors
    }
  }, [rightPanelWidth, rightPanelResizing]);

  // Same @mention format as the chat input's @ autocomplete, so the agent's
  // read tool resolves it the same way (it strips the @ prefix).
  const handleAtMention = useCallback((relativePath: string, isDir: boolean) => {
    chatInputRef.current?.insertText(buildAtMentionText(relativePath, isDir));
  }, []);

  const handleAtMentions = useCallback((relativePaths: string[]) => {
    const mentions = buildFileAtMentionsText(relativePaths);
    if (mentions) chatInputRef.current?.insertText(mentions);
  }, []);

  const handleFileLineMention = useCallback((relativePath: string, startLine: number, endLine: number) => {
    chatInputRef.current?.insertText(buildFileLineMentionText(relativePath, startLine, endLine));
  }, []);

  const initialSessionId = initialNavigation.sessionId;
  const [activeCwd, setActiveCwd] = useState<string | null>(null);
  // True once the initial ?session= URL param has been resolved (or confirmed absent)
  const [initialSessionRestored, setInitialSessionRestored] = useState<boolean>(() => !initialSessionId);
  // During the initial URL restore the sidebar adopts the restored cwd and
  // notifies us; that first onCwdChange must not bump sessionKey. We store the
  // expected cwd string and only skip when it matches, so a failure to fire
  // can't leave the suppression armed for the user's next genuine switch.
  const suppressCwdRef = useRef<string | null>(null);

  useEffect(() => {
    const requestedCwd = initialNavigation.requestedCwd;
    if (!requestedCwd) return;

    const controller = new AbortController();
    setInitialCwdStatus("validating");
    setInitialCwdError(null);

    void fetch("/api/cwd/validate", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ cwd: requestedCwd }),
      signal: controller.signal,
    })
      .then(async (response) => {
        const data = await response.json().catch(() => ({})) as { cwd?: string; error?: string; code?: string };
        if (!response.ok || !data.cwd) {
          throw new Error(data.error || data.code ? formatApiError(data) : `HTTP ${response.status}`);
        }

        // The sidebar will notify us when it adopts this cwd. Avoid remounting
        // the just-created empty chat during that initial synchronization.
        suppressCwdRef.current = data.cwd;
        setInitialCwdStatus("ready");
      })
      .catch((error: unknown) => {
        if (controller.signal.aborted) return;
        setInitialCwdError(error instanceof Error ? error.message : String(error));
        setInitialCwdStatus("error");
      });

    return () => controller.abort();
  }, [initialNavigation]);

  const handleCwdChange = useCallback((cwd: string | null, projectRoot?: string | null) => {
    setActiveCwd(cwd);
    // Skip if cwd is null (initial mount) or during the initial URL restore.
    if (!cwd) return;
    // Skip only when the notification matches the cwd we're suppressing for.
    if (suppressCwdRef.current !== null && suppressCwdRef.current === cwd) {
      suppressCwdRef.current = null;
      return;
    }
    // Moving the effective cwd within the same project (clicking a session
    // that lives in another folder of it) must not close the open session.
    // Compare case-folded: the same folder can be spelled with different
    // casing (Windows/NTFS) between the session's projectRoot and the
    // sidebar's resolved project root.
    const newProject = projectRoot ?? cwd;
    const sessionProject = selectedSession ? (selectedSession.projectRoot ?? selectedSession.cwd) : null;
    if (sessionProject && comparableProjectPath(sessionProject) === comparableProjectPath(newProject)) {
      return;
    }
    // Close any session that belongs to a different project — it no longer
    // matches the selected project directory.
    setSelectedSession(null);
    setNewSessionCwd((prev) => {
      if (prev && prev !== cwd) return null;
      return prev;
    });
    setSessionKey((k) => k + 1);
    setBranchTree([]);
    setBranchActiveLeafId(null);
    setActiveTopPanel(null);
    replaceHistoryUrl("/");
  }, [selectedSession]);

  const handleSelectSession = useCallback((session: SessionInfo, isRestore = false) => {
    // Re-picking the already-open session (sidebar double-click, palette
    // re-select, notification click) must not bump sessionKey: that remounts
    // ChatWindow, reconnects SSE, and drops the mid-run streaming view.
    setSettingsTab(null);
    // Re-picking the current conversation still closes/rearms the drawer,
    // without remounting the chat or disturbing its draft.
    if (isMobile && !isRestore) {
      setSidebarOpen(false);
      requestAnimationFrame(() => chatInputRef.current?.focus());
    }
    if (!isRestore && session.id === selectedSession?.id) return;
    setNewSessionCwd(null);
    setSelectedSession(session);
    setSessionKey((k) => k + 1);
    setInitialSessionRestored(true);
    if (isRestore) {
      // Suppress the redundant sessionKey bump that would come from the
      // onCwdChange effect firing after setSelectedCwd in the sidebar. We
      // arm the expected cwd (compared in handleCwdChange) rather than a
      // sticky flag so a missed notification can't suppress the next
      // genuine project switch.
      suppressCwdRef.current = session.cwd;
    }
    // Skip the history update when restoring from the URL — the param is
    // already correct.
    if (!isRestore) {
      replaceHistoryUrl(`?session=${encodeURIComponent(session.id)}`);
    }
  }, [isMobile, selectedSession?.id]);

  const handleNewSession = useCallback((_sessionId: string, cwd: string | null) => {
    setSettingsTab(null);
    setSelectedSession(null);
    setNewSessionCwd(cwd);
    setSessionKey((k) => k + 1);
    setBranchTree([]);
    setBranchActiveLeafId(null);
    setActiveTopPanel(null);
    if (isMobile) {
      setSidebarOpen(false);
      requestAnimationFrame(() => chatInputRef.current?.focus());
    }
    replaceHistoryUrl("/");
  }, [isMobile]);

  // ---- In-app Navigate back / forward over visited chat views ----
  // Own stack, not the browser History API (that one belongs to the mobile
  // back-gesture/exit-guard machinery — see lib/navigation-history.ts).
  const navigationHistory = useNavigationHistory();
  const {
    record: recordNavigationView,
    peekBack: peekNavigationBack,
    peekForward: peekNavigationForward,
  } = navigationHistory;
  // Bumped by the recording effect on every view change. navigateInHistory
  // captures it across its await and bails if the user moved on meanwhile,
  // so a slow session-list fetch can never yank the chat out from under a
  // view the user just switched to.
  const navViewVersionRef = useRef(0);
  const navSessionId = selectedSession?.id ?? null;
  const navSessionCwd = selectedSession?.cwd ?? null;
  useEffect(() => {
    navViewVersionRef.current += 1;
    recordNavigationView({
      sessionId: navSessionId,
      cwd: navSessionId ? navSessionCwd : newSessionCwd,
    });
  }, [navSessionId, navSessionCwd, newSessionCwd, recordNavigationView]);

  // Resolves a history entry's session id against the live list. `null`
  // means the id is gone (entry should be dropped); "unavailable" means the
  // list itself could not be fetched (keep the entry, abort this navigation).
  const fetchSessionForNavigation = useCallback(async (sessionId: string): Promise<SessionInfo | null | "unavailable"> => {
    try {
      const res = await fetch("/api/sessions");
      if (!res.ok) return "unavailable";
      const data = (await res.json()) as { sessions?: SessionInfo[] };
      return data.sessions?.find((s) => s.id === sessionId) ?? null;
    } catch {
      return "unavailable";
    }
  }, []);

  const navigateInHistory = useCallback(async (direction: -1 | 1): Promise<void> => {
    // Dead entries (deleted sessions) are skipped, like browser history
    // skipping a dead slot; bound the loop by the stack's own cap.
    for (let attempt = 0; attempt <= NAVIGATION_HISTORY_MAX_ENTRIES; attempt++) {
      const entry = direction === -1 ? peekNavigationBack() : peekNavigationForward();
      // Nothing that way: stay put. An exhausted stack never falls through to
      // the browser's own back/forward — the keystroke is swallowed by the
      // keyboard layer, so the app can never be backed out of by accident.
      if (!entry) return;
      if (entry.sessionId === null) {
        if (direction === -1) navigationHistory.commitBack();
        else navigationHistory.commitForward();
        handleNewSession("navigate-history", entry.cwd);
        return;
      }
      const versionAtPress = navViewVersionRef.current;
      const session = await fetchSessionForNavigation(entry.sessionId);
      if (navViewVersionRef.current !== versionAtPress) return; // user moved on: do nothing
      if (session === "unavailable") return; // list fetch failed: keep the entry, try again next press
      if (session) {
        if (direction === -1) navigationHistory.commitBack();
        else navigationHistory.commitForward();
        handleSelectSession(session, false);
        return;
      }
      if (direction === -1) navigationHistory.dropPeekedBack();
      else navigationHistory.dropPeekedForward();
    }
  }, [navigationHistory, peekNavigationBack, peekNavigationForward, fetchSessionForNavigation, handleNewSession, handleSelectSession]);

  // Shared by the sidebar buttons and the global shortcuts. The keyboard
  // layer always swallows the keystroke, so both directions stop dead at the
  // ends of the stack instead of continuing into browser history.
  const handleNavigateBack = useCallback(() => {
    void navigateInHistory(-1);
  }, [navigateInHistory]);
  const handleNavigateForward = useCallback(() => {
    void navigateInHistory(1);
  }, [navigateInHistory]);

  // Tooltip shortcut labels follow the platform (⌘[ vs Alt+←). Computed from
  // navigator after mount state to keep SSR markup stable.
  const [navIsMac] = useState(() => isMacPlatform());
  const sidebarNavigation = useMemo(() => ({
    canBack: navigationHistory.canBack,
    canForward: navigationHistory.canForward,
    onBack: handleNavigateBack,
    onForward: handleNavigateForward,
    backShortcut: navigateShortcutHint(-1, navIsMac),
    forwardShortcut: navigateShortcutHint(1, navIsMac),
  }), [navigationHistory.canBack, navigationHistory.canForward, handleNavigateBack, handleNavigateForward, navIsMac]);


  // Global keyboard shortcuts (handles Esc, Ctrl+Alt+N etc.)
  useGlobalKeyboardShortcuts({
    onNewSession: (cwd: string) => handleNewSession(`kb-${Date.now()}`, cwd),
    onNavigateBack: handleNavigateBack,
    onNavigateForward: handleNavigateForward,
    activeCwd,
    scopeNativeSelectAll,
  });

  // Client-built transient SessionInfo (new session / fork) lacks the
  // server-computed projectRoot, which the same-project check in
  // handleCwdChange relies on. Hydrate it from the session list so switching
  // folders right after creating a session doesn't close the chat.
  const hydrateSelectedSession = useCallback((sessionId: string) => {
    void fetch("/api/sessions")
      .then((r) => (r.ok ? (r.json() as Promise<{ sessions: SessionInfo[] }>) : null))
      .then((d) => {
        const full = d?.sessions.find((s) => s.id === sessionId);
        if (!full) return;
        setSelectedSession((prev) => (prev && prev.id === sessionId && !prev.projectRoot ? full : prev));
      })
      .catch(() => {});
  }, []);

  // Called by ChatWindow when a new session gets its real id from pi
  const handleSessionCreated = useCallback((session: SessionInfo) => {
    setNewSessionCwd(null);
    setSelectedSession(session);
    setRefreshKey((k) => k + 1);
    hydrateSelectedSession(session.id);
    replaceHistoryUrl(`?session=${encodeURIComponent(session.id)}`);
  }, [hydrateSelectedSession]);

  const handleAgentEnd = useCallback(() => {
    setRefreshKey((k) => k + 1);
    setExplorerRefreshKey((k) => k + 1);
  }, []);

  // Notification clicks name a session id; the session list carries its cwd
  // and project, which selecting needs. When the list cannot be read, load the
  // session URL directly so the app restores it on boot.
  const openSessionById = useCallback((sessionId: string) => {
    window.focus();
    // On narrow screens the file panel covers the chat it is about to show.
    if (isCompactOverlay) setRightPanelOpen(false);
    // A full load restores the session from its URL on boot.
    const sessionUrl = new URL(`/?session=${encodeURIComponent(sessionId)}`, window.location.origin).href;
    void fetch("/api/sessions")
      .then((r) => {
        if (!r.ok) {
          window.location.assign(sessionUrl);
          return;
        }
        return (r.json() as Promise<{ sessions: SessionInfo[] }>).then((d) => {
          const session = d.sessions.find((s) => s.id === sessionId);
          if (session) handleSelectSession(session);
          else toast.error(translate("notifications.sessionNotFound"));
        });
      })
      .catch(() => window.location.assign(sessionUrl));
  }, [handleSelectSession, isCompactOverlay]);

  // Full-page Settings hides the chat, so its session counts as not viewed.
  useNotifications({ sessionId: settingsTab ? null : selectedSession?.id ?? null, locale, onOpenSession: openSessionById });

  const handleAutoName = useCallback(async () => {
    const sessionId = selectedSession?.id;
    if (!sessionId || autoNameStatus.kind === "naming") return;
    clearTimeout(autoNameTimerRef.current);
    setActiveTopPanel(null);
    setAutoNameStatus({ kind: "naming" });

    try {
      const response = await fetch(`/api/sessions/${encodeURIComponent(sessionId)}/auto-name`, {
        method: "POST",
      });
      const body = (await response.json().catch(() => ({}))) as { title?: string; error?: string; code?: string };
      if (!response.ok || !body.title) {
        throw new Error(body.error || body.code ? formatApiError(body) : `HTTP ${response.status}`);
      }

      const title = body.title.trim();
      if (activeSessionIdRef.current !== sessionId) return;
      setRefreshKey((key) => key + 1);
      setSelectedSession((current) => current?.id === sessionId ? { ...current, name: title } : current);
      setSessionStats((current) => current?.sessionId === sessionId ? { ...current, sessionName: title } : current);
      setAutoNameStatus({ kind: "success" });
      autoNameTimerRef.current = setTimeout(() => setAutoNameStatus({ kind: "idle" }), 1800);
    } catch (error) {
      if (activeSessionIdRef.current !== sessionId) return;
      const message = error instanceof Error ? error.message : String(error);
      setAutoNameStatus({ kind: "error", message });
      autoNameTimerRef.current = setTimeout(() => setAutoNameStatus({ kind: "idle" }), 5000);
    }
  }, [autoNameStatus.kind, selectedSession?.id]);

  useEffect(() => {
    clearTimeout(autoNameTimerRef.current);
    setAutoNameStatus({ kind: "idle" });
  }, [selectedSession?.id]);

  const handleExplorerRefresh = useCallback(() => {
    setExplorerRefreshing(true);
    setExplorerRefreshKey((k) => k + 1);
  }, []);

  const handleExplorerRefreshDone = useCallback(() => {
    setExplorerRefreshing(false);
  }, []);

  const handleSessionForked = useCallback((newSessionId: string) => {
    setRefreshKey((k) => k + 1);
    setSessionKey((k) => k + 1);
    setNewSessionCwd(null);
    setSelectedSession((prev) => ({
      ...(prev ?? { path: "", cwd: "", created: "", modified: "", messageCount: 0, firstMessage: "" }),
      id: newSessionId,
      // path === "" is the sidebar's optimistic-row marker; keep it so the
      // fork shows up immediately instead of waiting for a refresh.
      path: "",
    }));
    hydrateSelectedSession(newSessionId);
    replaceHistoryUrl(`?session=${encodeURIComponent(newSessionId)}`);
  }, [hydrateSelectedSession]);

  const handleSessionDeleted = useCallback((sessionId: string) => {
    // The composer for this session can never be reopened, so its draft would
    // otherwise keep the exit guard armed for unreachable content.
    clearDraft(sessionId);
    setRefreshKey((k) => k + 1);
    if (selectedSession?.id === sessionId) {
      const cwd = selectedSession.cwd;
      setSelectedSession(null);
      setNewSessionCwd(cwd ?? null);
      setSessionKey((k) => k + 1);
      setBranchTree([]);
      setBranchActiveLeafId(null);
      setActiveTopPanel(null);
      replaceHistoryUrl("/");
    }
  }, [selectedSession]);
  const handleInitialRestoreDone = useCallback(() => {
    setInitialSessionRestored(true);
  }, []);

  const handleArchiveRestored = useCallback(async (sessionId: string) => {
    setArchiveBrowserOpen(false);
    publishSessionsChanged([sessionId]);
    setRefreshKey((k) => k + 1);

    // The poll must not yank the UI back to the restored session if the user
    // picks another one while we wait, and an untracked setTimeout chain would
    // keep retrying after unmount — so freeze the selection at start, bail out
    // of every attempt + the fallback when it changed, and track the timer.
    const sessionAtRestoreStart = activeSessionIdRef.current;
    const selectRestoredSession = async (attemptsLeft = 5): Promise<void> => {
      if (activeSessionIdRef.current !== sessionAtRestoreStart) return;
      try {
        const res = await fetch("/api/sessions");
        if (res.ok) {
          const data = (await res.json()) as { sessions?: SessionInfo[] };
          const found = data.sessions?.find((s) => s.id === sessionId);
          if (found) {
            if (activeSessionIdRef.current !== sessionAtRestoreStart) return;
            handleSelectSession(found, false);
            return;
          }
        }
      } catch {
        // network error / abort
      }

      if (attemptsLeft > 0) {
        archiveRetryTimerRef.current = setTimeout(() => void selectRestoredSession(attemptsLeft - 1), 300);
      } else if (activeSessionIdRef.current === sessionAtRestoreStart) {
        replaceHistoryUrl(`?session=${encodeURIComponent(sessionId)}`);
      }
    };

    void selectRestoredSession();
  }, [handleSelectSession]);

  const handleCloseFileTab = useCallback((tabId: string) => {
    // Compute everything from the current list outside the updaters: no side
    // effect inside a state updater, and no stale-closure read (the callback
    // is recreated whenever fileTabs changes, but a batched double-close
    // would still have read the pre-close list from the closure).
    const next = fileTabs.filter((t) => t.id !== tabId);
    setFileTabs(next);
    // The panel now hosts the Explorer tab, so it stays open: closing the
    // last file falls back to the explorer instead of hiding the panel.
    if (next.length === 0) setRightView("explorer");
    setActiveFileTabId((cur) => {
      if (cur !== tabId) return cur;
      return next.length > 0 ? next[next.length - 1].id : null;
    });
  }, [fileTabs]);

  const handleOpenFile = useCallback((filePath: string, fileName: string, sourceSessionId?: string | null, openAs?: FileOpenMode) => {
    const tabId = `file:${filePath}`;
    setFileTabs((prev) => {
      const existing = prev.find((t) => t.id === tabId);
      if (!existing) return [...prev, { id: tabId, label: fileName, filePath, sourceSessionId, openAs }];
      // "Open with" from the explorer retargets the existing tab instead of
      // stacking a duplicate tab for the same file.
      const nextSessionId = !sourceSessionId || existing.sourceSessionId === sourceSessionId
        ? existing.sourceSessionId
        : sourceSessionId;
      const nextOpenAs = openAs;
      if (nextSessionId === existing.sourceSessionId && nextOpenAs === existing.openAs) return prev;
      return prev.map((t) => t.id === tabId ? { ...t, sourceSessionId: nextSessionId, openAs: nextOpenAs } : t);
    });
    setActiveFileTabId(tabId);
    setRightView("file");
    setRightPanelOpen(true);
    // On mobile the file panel is full-screen; close the drawer so it shows.
    if (isMobile) setSidebarOpen(false);
  }, [isMobile]);

  // Agent open requests that wait for the user. URLs always ask unless the
  // user opted into opening links from the viewed session automatically; URLs
  // and files from a session this tab is not viewing always ask, so they cannot
  // take over the current view. The click is also the user gesture that lets
  // the new tab through pop-up blockers.
  const [pendingOpens, setPendingOpens] = useState<Array<{ kind: "url" | "file"; target: string; name: string; sessionId: string; crossSession: boolean }>>([]);
  const pendingOpen = pendingOpens[0] ?? null;
  // Keep the last request on screen while the dialog animates closed.
  const shownOpenRef = useRef(pendingOpen);
  if (pendingOpen) shownOpenRef.current = pendingOpen;
  const shownOpen = pendingOpen ?? shownOpenRef.current;
  const dismissPendingOpen = useCallback(() => setPendingOpens((queue) => queue.slice(1)), []);
  const requestOpenUrl = useCallback((url: string, sessionId: string, crossSession: boolean): string => {
    if (!crossSession && openUrlAutomatically) {
      window.open(url, "_blank", "noopener,noreferrer")?.focus?.();
      return `Opened ${url}`;
    }
    setPendingOpens((queue) => [...queue, { kind: "url", target: url, name: url, sessionId, crossSession }]);
    return crossSession
      ? `Asked the user to confirm opening ${url}; they are viewing another AIDesk session.`
      : `Asked the user to confirm opening ${url}.`;
  }, [openUrlAutomatically]);
  const handleSessionOpenUrl = useCallback((url: string) => requestOpenUrl(url, selectedSession?.id ?? "", false), [requestOpenUrl, selectedSession?.id]);
  const handleCrossSessionHostTool = useCallback(async (call: CrossSessionHostToolCall) => {
    // Full-page Settings hides the chat, so its session counts as not viewed.
    const viewing = call.sessionId === selectedSession?.id && !settingsTab;
    const { text, isError } = await runHostTool(call.toolName, call.arguments, {
      openUrl: (url) => requestOpenUrl(url, call.sessionId, !viewing),
      openFile: (path, name) => {
        if (viewing) return handleOpenFile(path, name, call.sessionId);
        setPendingOpens((queue) => [...queue, { kind: "file", target: path, name, sessionId: call.sessionId, crossSession: true }]);
        return `Asked the user to confirm opening ${path}; they are viewing another AIDesk session.`;
      },
    });
    try {
      await sendAgentCommand(call.sessionId, {
        type: "host_tool_result",
        id: call.id,
        isError,
        result: { content: [{ type: "text", text }] },
      });
    } catch (e) {
      console.error("Failed to send host tool result:", e);
    }
  }, [handleOpenFile, requestOpenUrl, selectedSession?.id, settingsTab]);
  const crossSessionHostToolRef = useRef(handleCrossSessionHostTool);
  useEffect(() => { crossSessionHostToolRef.current = handleCrossSessionHostTool; }, [handleCrossSessionHostTool]);
  useEffect(() => {
    // Mounted with the shell (not the sidebar) so it keeps listening on the
    // full-page Settings view too.
    const source = new EventSource("/api/agent/host-tools/events");
    source.onmessage = (e) => {
      try {
        const call = JSON.parse(e.data) as CrossSessionHostToolCall & { type?: string };
        if (call.type === "host_tool_call" && call.sessionId && call.id && call.toolName) {
          void crossSessionHostToolRef.current({ sessionId: call.sessionId, id: call.id, toolName: call.toolName, arguments: call.arguments ?? {} });
        }
      } catch {
        // ignore malformed frames
      }
    };
    return () => source.close();
  }, []);

  const activeFileTab = fileTabs.find((tab) => tab.id === activeFileTabId) ?? null;
  // Explorer, Git, and the file viewers follow the open session's folder, then
  // the sidebar's live cwd, then the new-session cwd. Relative paths (mention,
  // copy path) resolve against the same folder so they match the Explorer.
  const sessionCwd = selectedSession?.cwd ?? null;
  const explorerCwd = sessionCwd ?? activeCwd ?? newSessionCwd ?? null;
  const handleOpenLinkedFile = useCallback((filePath: string) => {
    handleOpenFile(filePath, getFileName(filePath), selectedSession?.id ?? null);
  }, [handleOpenFile, selectedSession?.id]);

  // File-panel integrations: every action works on the active tab so the right
  // panel behaves like an editor toolbar, not just a tab strip.
  const handleMentionActiveFile = useCallback(() => {
    if (!activeFileTab) return;
    handleAtMention(getRelativeFilePath(activeFileTab.filePath, explorerCwd ?? undefined), false);
  }, [activeFileTab, explorerCwd, handleAtMention]);

  const handleCopyActiveFilePath = useCallback(() => {
    if (!activeFileTab) return;
    const relative = getRelativeFilePath(activeFileTab.filePath, explorerCwd ?? undefined);
    copyText(relative).then(
      () => toast.success(t("appShell.copied")),
      () => toast.error(t("appShell.commandCopyFailed")),
    );
  }, [activeFileTab, explorerCwd, t]);

  const handleDownloadActiveFile = useCallback(() => {
    if (!activeFileTab) return;
    const link = document.createElement("a");
    link.href = apiUrl(`/api/files/${encodeFilePathForApi(activeFileTab.filePath)}?type=download`);
    link.download = activeFileTab.label;
    document.body.appendChild(link);
    link.click();
    link.remove();
  }, [activeFileTab]);
  const handleRevealActiveFile = useCallback(() => {
    if (!activeFileTab) return;
    setRevealPath(activeFileTab.filePath);
    setRightView("explorer");
    setRightPanelOpen(true);
  }, [activeFileTab]);

  const handleSelectFileTab = useCallback((tabId: string) => {
    setActiveFileTabId(tabId);
    setRightView("file");
  }, []);
  // Stable selectors for the memoized RightPanel: inline arrows here would be
  // new identities every render and defeat the memo boundary.
  const handleSelectRightView = useCallback((view: RightPanelView) => {
    setRightView(view);
  }, []);

  const handleRevealDone = useCallback(() => {
    setRevealPath(null);
  }, []);

  const handleToggleFileSearch = useCallback(() => {
    setFileSearchOpen((open) => !open);
  }, []);

  const handleCloseOtherFileTabs = useCallback(() => {
    if (!activeFileTab) return;
    setFileTabs([activeFileTab]);
  }, [activeFileTab]);

  const handleCloseAllFileTabs = useCallback(() => {
    setFileTabs([]);
    setActiveFileTabId(null);
    setRightView("explorer");
  }, []);

  const handleViewFullHistory = useCallback(() => {
    if (!selectedSession) return;
    window.open(
      apiUrl(`/api/sessions/${encodeURIComponent(selectedSession.id)}/export?inline=1`),
      "_blank",
      "noopener,noreferrer",
    );
  }, [selectedSession]);

  // Show chat area if a session is selected, or if we have a cwd to start a new session in
  const effectiveNewSessionCwd = newSessionCwd ?? (selectedSession === null && activeCwd ? activeCwd : null);
  const newSessionProject = (workspaceOptions.cwd === effectiveNewSessionCwd ? workspaceOptions.selectedProject : null) ?? effectiveNewSessionCwd ?? "";
  const showChat = selectedSession !== null || effectiveNewSessionCwd !== null;
  const currentRate = generationSpeed?.current;
  const rate = currentRate ?? generationSpeed?.average;
  const speed = showChat ? formatGenerationSpeed(rate) : null;
  const hasGenerationSpeed = speed !== null;
  useLayoutEffect(() => {
    const header = topBarRef.current;
    const details = mobileToolsRef.current;
    const content = mobileToolsContentRef.current;
    const right = header?.querySelector<HTMLElement>("[data-topbar-right-group]");
    const tools = header?.querySelector<HTMLElement>(".shell-topbar-tools");
    if (!header || !details || !content || !right || !tools) return;
    const update = () => {
      const hadControlsFocus = content.contains(document.activeElement);
      // Measure the real controls even while their disclosure is closed.
      const closed = !details.open;
      const display = content.style.display;
      const visibility = content.style.visibility;
      content.style.visibility = "hidden";
      content.style.display = "flex";
      details.open = true;
      const children = Array.from(content.children).filter((child) =>
        !["absolute", "fixed"].includes(getComputedStyle(child).position));
      const contentStyle = getComputedStyle(content);
      const headerStyle = getComputedStyle(header);
      const controlsWidth = children.reduce((width, child) => {
        const style = getComputedStyle(child);
        return width + child.getBoundingClientRect().width
          + parseFloat(style.marginLeft) + parseFloat(style.marginRight);
      }, 0) + Math.max(0, children.length - 1) * parseFloat(contentStyle.columnGap);
      const leftNeed = controlsWidth
        + (tools.firstElementChild?.getBoundingClientRect().width ?? 0)
        + parseFloat(getComputedStyle(tools).columnGap)
        + parseFloat(headerStyle.paddingLeft);
      const rightNeed = parseFloat(headerStyle.paddingRight) + right.offsetWidth;
      const required = leftNeed + parseFloat(headerStyle.columnGap) + rightNeed;
      if (closed) details.open = false;
      content.style.display = display;
      content.style.visibility = visibility;
      // Title pill: same inset on both sides = widest real cluster (+8px gap), so it
      // is truly centered and never under a control. Expand the tools only if the
      // pill still keeps >= 200px (the container-query hide threshold) with them.
      header.style.setProperty(
        "--topbar-side",
        `${Math.ceil(Math.max(tools.offsetLeft + tools.offsetWidth, header.clientWidth - right.offsetLeft)) + 8}px`,
      );
      const titleFits = header.querySelector(".shell-topbar-center") === null
        || 2 * Math.max(leftNeed, rightNeed) + 216 <= header.clientWidth;
      const compact = required > header.clientWidth || !titleFits;
      if (compact && details.dataset.compact !== "true" && hadControlsFocus) {
        restoreToolsFocusRef.current = true;
      }
      setCompactTopbar(compact);
    };
    const observer = new ResizeObserver(update);
    observer.observe(header);
    observer.observe(right);
    observer.observe(tools);
    observer.observe(content);
    for (const child of content.children) observer.observe(child);
    document.fonts.addEventListener("loadingdone", update);
    update();
    return () => {
      observer.disconnect();
      document.fonts.removeEventListener("loadingdone", update);
    };
  }, [isMobile, locale, settingsTab, showChat]);
  // While restoring initial session from URL, don't show the placeholder
  const showPlaceholder = initialSessionRestored && !showChat;

  const sidebarHistory = useSidebarHistory({
    active: isMobile && (showChat || Boolean(initialSessionId)),
    ready: mobileSidebarReady,
    sidebarOpen,
    setSidebarOpen,
    url: window.location.search.replace(/^\?/, ""),
  });
  useEffect(() => {
    if (sidebarHistory.exitNeedsNativeBack) {
      toast.info(t("appShell.exitNativeBackTitle"), t("appShell.exitNativeBackDescription"));
    }
  }, [sidebarHistory.exitNeedsNativeBack, t]);

  const activeCwdName = activeCwd ? getFileName(activeCwd) || activeCwd : null;
  const windowTitle = activeCwdName ? `${activeCwdName} - ${appName}` : appName;

  useEffect(() => {
    const syncWindowTitle = () => {
      if (document.title !== windowTitle) document.title = windowTitle;
    };

    syncWindowTitle();
    const observer = new MutationObserver(syncWindowTitle);
    observer.observe(document.head, { childList: true, subtree: true, characterData: true });
    return () => observer.disconnect();
  }, [windowTitle]);

  const sidebarContent = (
    <SessionSidebar
      selectedSessionId={selectedSession?.id ?? null}
      optimisticSession={selectedSession?.path === "" ? selectedSession : null}
      onSelectSession={handleSelectSession}
      onNewSession={handleNewSession}
      initialSessionId={initialSessionId}
      skipInitialProjectSelection={initialNavigation.requestedCwd !== null}
      onInitialRestoreDone={handleInitialRestoreDone}
      refreshKey={refreshKey}
      onSessionDeleted={handleSessionDeleted}
      selectedCwd={selectedSession?.cwd ?? newSessionCwd ?? null}
      onCwdChange={handleCwdChange}
      onWorkspaceOptionsChange={handleWorkspaceOptionsChange}
      addProjectOpen={addProjectOpen}
      setAddProjectOpen={setAddProjectOpen}
      settingsOpen={Boolean(settingsTab)}
      onOpenSettings={() => setSettingsTab((prev) => prev ? null : "general")}
      onOpenArchive={() => setArchiveBrowserOpen(true)}
      navigation={sidebarNavigation}
      onClose={isMobile ? handleSidebarToggle : undefined}
    />
  );

  return (
    <>
    <ToastProvider>
      <ConfirmDialog
        open={sidebarHistory.exitConfirmationOpen}
        onOpenChange={(open) => { if (!open) sidebarHistory.cancelExit(); }}
        title={t("appShell.exitTitle")}
        description={t("appShell.exitDescription")}
        confirmLabel={t("appShell.exitLeave")}
        cancelLabel={t("appShell.exitStay")}
        danger
        onConfirm={sidebarHistory.leave}
      />
      <ConfirmDialog
        open={pendingOpen !== null}
        onOpenChange={(open) => { if (!open) dismissPendingOpen(); }}
        title={t(shownOpen?.kind === "file" ? "appShell.openFileTitle" : shownOpen?.crossSession ? "appShell.openUrlTitle" : "appShell.openUrlSameSessionTitle")}
        description={t(shownOpen?.crossSession ? "appShell.openUrlDescription" : "appShell.openUrlSameSessionDescription", { url: shownOpen?.target ?? "" })}
        confirmLabel={t("appShell.openUrlConfirm")}
        cancelLabel={t("appShell.openUrlCancel")}
        onConfirm={() => {
          if (pendingOpen?.kind === "url") window.open(pendingOpen.target, "_blank", "noopener,noreferrer");
          else if (pendingOpen) {
            // The file panel is hidden behind full-page Settings.
            setSettingsTab(null);
            handleOpenFile(pendingOpen.target, pendingOpen.name, pendingOpen.sessionId);
          }
          dismissPendingOpen();
        }}
      />
    <style>{`
      @media (max-width: 640px) {
        .sidebar-container.sidebar-mobile-pending.sidebar-open {
          transform: translateX(-100%);
        }
      }
    `}
    </style>
    <a href="#main-content" className="skip-link">{t("appShell.skipToContent")}</a>
    <div style={{ display: "flex", height: "100%", flex: 1, minHeight: 0, minWidth: 0, overflow: "hidden", background: "var(--bg)" }}>
      {/* Left sidebar: hidden on full-page Settings */}
      {!settingsTab && (
        <>
      <nav
        id="workspace-sidebar"
        role={isMobile ? "dialog" : undefined}
        aria-modal={isMobile ? true : undefined}
        tabIndex={-1}
        ref={sidebarContainerRef}
        className={`sidebar-container${sidebarOpen ? " sidebar-open" : " sidebar-closed"}${mobileSidebarReady ? "" : " sidebar-mobile-pending"}${sidebarResizing ? " sidebar-resizing" : ""}`}
        aria-label={t("projects.heading")}
        aria-hidden={mobileSidebarReady && (!sidebarOpen || rightPanelIsModal) ? true : undefined}
        inert={mobileSidebarReady && (!sidebarOpen || rightPanelIsModal) ? true : undefined}
        style={{
          background: "var(--bg-panel)",
          borderRight: isMobile ? "none" : "1px solid var(--border)",
          display: "flex",
          flexDirection: "column",
          flexShrink: 0,
          zIndex: 200,
          // Desktop-only: the width is user-adjustable via the resize handle.
          ...(!isMobile ? { "--sidebar-width": `${sidebarWidth}px` } : {}),
        }}
      >
        {sidebarContent}
      </nav>

      {/* Resize handle — desktop only, hidden while the sidebar is closed */}
      {!isMobile && sidebarOpen && (
        <div
          className="sidebar-resize-handle"
          role="separator"
          aria-orientation="vertical"
          aria-label={t("appShell.resizeSidebar")}
          tabIndex={0}
          onMouseDown={handleSidebarResizeStart}
          onDoubleClick={resetSidebarWidth}
          onKeyDown={handleSidebarResizeKey}
          title={t("appShell.resizeSidebarTitle")}
          style={{
            width: 5,
            flexShrink: 0,
            marginLeft: -5,
            cursor: "col-resize",
            background: "transparent",
            zIndex: 205,
            outline: "none",
            transition: "background var(--dur-fast) var(--ease-out-warm)",
          }}
          onMouseEnter={(e) => { e.currentTarget.style.background = "color-mix(in srgb, var(--accent) 35%, transparent)"; }}
          onMouseLeave={(e) => { e.currentTarget.style.background = "transparent"; }}
          onFocus={(e) => { e.currentTarget.style.background = "color-mix(in srgb, var(--accent) 35%, transparent)"; }}
          onBlur={(e) => { e.currentTarget.style.background = "transparent"; }}
        />
      )}
        </>
      )}

      {/* Center: chat */}
      <main id="main-content" tabIndex={-1} inert={rightPanelIsModal ? true : undefined} style={{ flex: 1, display: "flex", flexDirection: "column", minHeight: 0, minWidth: 0, overflow: "hidden" }}>
        {settingsTab ? (
          <SettingsConfig
            activeTab={settingsTab}
            toolCallsDefaultCollapsed={toolCallsDefaultCollapsed}
            onToolCallsDefaultCollapsedChange={handleToolCallsDefaultCollapsedChange}
            expandThinkingByDefault={expandThinkingByDefault}
            onExpandThinkingByDefaultChange={handleExpandThinkingByDefaultChange}
            scopeNativeSelectAll={scopeNativeSelectAll}
            onScopeNativeSelectAllChange={handleScopeNativeSelectAllChange}
            openUrlAutomatically={openUrlAutomatically}
            onOpenUrlAutomaticallyChange={handleOpenUrlAutomaticallyChange}
            onSelectTab={setSettingsTab}
            onClose={() => setSettingsTab(null)}
          />
        ) : (
          <>
        {/* Top bar: 3-zone segmented control bar */}
        <div ref={topBarRef} className="shell-topbar" style={{
          position: "relative",
          alignItems: "center",
          flexShrink: 0,
          borderBottom: "1px solid var(--border)",
          minHeight: "var(--shell-topbar-height)",
          background: "var(--bg-panel)",
          padding: isMobile ? "env(safe-area-inset-top, 0px) max(4px, env(safe-area-inset-right, 0px)) 0 max(4px, env(safe-area-inset-left, 0px))" : "0 8px",
          gap: "0 8px",
          minWidth: 0,
        }}>
          {/* Left Zone: Utility group (sidebar, theme, language) & session controls (history, branches, system) */}
          <div className="shell-topbar-tools" style={{ display: "flex", alignItems: "center", gap: 4, height: isMobile ? 43 : 35, minWidth: 0, flexShrink: 0 }}>
            <button
              onClick={handleSidebarToggle}
              aria-expanded={sidebarOpen}
              aria-controls="workspace-sidebar"
              title={sidebarOpen ? t("appShell.hideSidebar") : t("appShell.showSidebar")}
              aria-label={sidebarOpen ? t("appShell.hideSidebar") : t("appShell.showSidebar")}
              className="shell-toolbar-btn ui-focus-ring"
            >
              {sidebarOpen ? <PanelLeft size={16} strokeWidth={1.8} aria-hidden="true" /> : <Menu size={16} strokeWidth={1.8} aria-hidden="true" />}
            </button>
            <details
              ref={mobileToolsRef}
              className="shell-topbar-overflow"
              data-compact={isMobile ? "true" : compactTopbar === null ? "pending" : compactTopbar}
              open={isMobile ? undefined : compactTopbar ? undefined : true}
              onToggle={(event) => {
                if (!event.currentTarget.open) setActiveTopPanel(null);
              }}
            >
              <summary
                className="shell-toolbar-btn ui-focus-ring"
                title={t("chatInput.moreControls")}
                aria-label={t("chatInput.moreControls")}
              >
                <Ellipsis size={16} strokeWidth={1.8} aria-hidden="true" />
              </summary>
              <div ref={mobileToolsContentRef} className="shell-topbar-overflow-content">
            <ThemeSwitcher />
            <LanguageSwitcher />
            {showChat && (
              <>
                <div className="shell-toolbar-divider" aria-hidden="true" />
                <button
                  onClick={handleViewFullHistory}
                  disabled={!selectedSession}
                  title={selectedSession ? t("appShell.fullHistory") : t("appShell.fullHistoryUnavailable")}
                  aria-label={t("appShell.fullHistory")}
                  className="shell-toolbar-btn ui-focus-ring"
                >
                  <History size={16} strokeWidth={1.8} aria-hidden="true" />
                </button>
                <BranchNavigator
                  tree={branchTree}
                  activeLeafId={branchActiveLeafId}
                  onLeafChange={handleBranchLeafChange}
                  inline
                  containerRef={compactTopbar ? mobileToolsContentRef : topBarRef}
                  open={activeTopPanel === "branches"}
                  onToggle={() => toggleTopPanel("branches")}
                  hasSession
                />
              </>
            )}
              </div>
            </details>
          </div>

          {/* Center Zone: Workspace & Session Breadcrumb + Auto-name action */}
          {showChat && (() => {
            const effectiveProject = selectedSession?.projectRoot ?? selectedSession?.cwd ?? activeCwd ?? "";
            const sessionTitle = selectedSession?.name || selectedSession?.firstMessage || t("appShell.newSession");
            const hasMessages = Boolean(
              selectedSession
              && (sessionStats?.userMessages ?? selectedSession.messageCount) > 0,
            );
            const wandDisabled = !selectedSession || !hasMessages || autoNameStatus.kind === "naming";
            const wandIsSuccess = autoNameStatus.kind === "success";
            const wandIsError = autoNameStatus.kind === "error";
            const wandLabel = autoNameStatus.kind === "naming"
              ? t("appShell.generating")
              : wandIsSuccess
                ? t("appShell.titleUpdated")
                : wandIsError
                  ? t("appShell.generationFailed")
                  : t("appShell.generateTitle");
            const wandTooltip = !selectedSession
              ? t("appShell.titleGenUnavailable")
              : !hasMessages
                ? t("appShell.titleGenNeedsMessage")
                : wandIsError
                  ? autoNameStatus.message
                  : t("appShell.generateSessionTitle");

            return (
              <div
                className="shell-topbar-center"
                style={{
                  minWidth: 0,
                  containerType: "inline-size",
                  containerName: "breadcrumb",
                  display: "flex",
                  alignItems: "center",
                  justifyContent: "center",
                }}
              >
                <div
                  className="shell-topbar-breadcrumb"
                  style={{
                    display: "inline-flex",
                    alignItems: "center",
                    gap: 6,
                    height: 26,
                    padding: "0 8px",
                    borderRadius: "var(--radius-control)",
                    background: "var(--bg-subtle)",
                    border: "1px solid var(--border)",
                    fontSize: 11,
                    color: "var(--text-muted)",
                    whiteSpace: "nowrap",
                    minWidth: 0,
                    width: "fit-content",
                    justifyContent: "center",
                    flexShrink: 1,
                  }}
                >
                  {effectiveProject ? (
                    <span className="shell-topbar-project-context" style={{ display: "contents" }}>
                      <Folder size={12} strokeWidth={1.8} style={{ opacity: 0.6, flexShrink: 0 }} aria-hidden="true" />
                      <span
                        style={{
                          fontWeight: 600,
                          color: "var(--text)",
                          flexShrink: 0,
                          maxWidth: 120,
                          overflow: "hidden",
                          textOverflow: "ellipsis",
                          whiteSpace: "nowrap",
                        }}
                        title={effectiveProject}
                      >
                        {projectLabel(effectiveProject)}
                      </span>
                      <span style={{ color: "var(--text-dim)", flexShrink: 0, opacity: 0.5 }}>/</span>
                    </span>
                  ) : null}
                  <span
                    style={{
                      color: "var(--text)",
                      fontWeight: 500,
                      overflow: "hidden",
                      textOverflow: "ellipsis",
                      whiteSpace: "nowrap",
                      minWidth: 0,
                    }}
                    title={sessionTitle}
                  >
                    {sessionTitle}
                  </span>
                  {selectedSession && (
                    <button
                      type="button"
                      onClick={() => void handleAutoName()}
                      disabled={wandDisabled}
                      title={wandTooltip}
                      aria-label={wandLabel}
                      className="ui-focus-ring"
                      style={{
                        display: "inline-flex",
                        alignItems: "center",
                        justifyContent: "center",
                        width: 18,
                        height: 18,
                        padding: 0,
                        marginLeft: 2,
                        border: "none",
                        borderRadius: 4,
                        background: "transparent",
                        color: wandIsSuccess ? "var(--accent)" : wandIsError ? "var(--status-error)" : "var(--text-dim)",
                        cursor: wandDisabled ? "default" : "pointer",
                        flexShrink: 0,
                        opacity: autoNameStatus.kind === "naming" ? 1 : wandDisabled ? 0.35 : 0.75,
                        transition: "color var(--dur-fast), opacity var(--dur-fast)",
                      }}
                    >
                      {autoNameStatus.kind === "naming" ? (
                        <svg className="animate-spin" width="12" height="12" viewBox="0 0 24 24" fill="none" aria-hidden="true">
                          <circle cx="12" cy="12" r="9" stroke="currentColor" strokeWidth="2" opacity="0.25" />
                          <path d="M21 12a9 9 0 0 0-9-9" stroke="currentColor" strokeWidth="2" strokeLinecap="round" />
                        </svg>
                      ) : wandIsSuccess ? (
                        <Check size={12} strokeWidth={2} aria-hidden="true" />
                      ) : (
                        <Wand2 size={12} strokeWidth={1.8} aria-hidden="true" />
                      )}
                    </button>
                  )}
                </div>
              </div>
            );
          })()}

          {/* Right zone: speed, mobile session information, and the file-panel opener. */}
          <div
            data-topbar-right-group
            style={{
              marginLeft: "auto",
              display: "flex",
              alignItems: "center",
              gap: isMobile ? 2 : 6,
              height: isMobile ? 43 : "calc(var(--shell-topbar-height) - 1px)",
              flexShrink: 1,
              minWidth: 0,
            }}
          >
            {hasGenerationSpeed && <div
              className="shell-topbar-metrics"
              style={{
                flex: "0 1 calc(10ch + 33px)",
                minWidth: 0,
                fontSize: 11,
                fontFamily: "var(--font-mono)",
                containerType: "inline-size",
                containerName: "topbar-speed",
              }}
            >
            {/* Generation speed pill */}
            {showChat && (() => {
              if (!speed || rate == null) return null;
              const isLive = currentRate != null;
              const speedTitle = t(isLive ? "appShell.tooltipCurrentSpeed" : "appShell.tooltipAverageSpeed", {
                value: `${rate.toFixed(1)} t/s`,
              });

              return (
                <div
                  title={speedTitle}
                  role="img"
                  aria-label={speedTitle}
                  className="shell-metric-pill shell-pill-extra"
                  style={{
                    display: "inline-flex",
                    alignItems: "center",
                    gap: 4,
                    height: 26,
                    padding: "0 8px",
                    borderRadius: "var(--radius-control)",
                    border: "1px solid var(--border)",
                    background: "var(--bg-subtle)",
                    color: isLive ? "var(--accent)" : "var(--text-muted)",
                    fontSize: 11,
                    fontFamily: "var(--font-mono)",
                    fontVariantNumeric: "tabular-nums",
                    whiteSpace: "nowrap",
                    cursor: "default",
                    width: "calc(10ch + 33px)",
                    flexShrink: 0,
                  }}
                >
                  {isLive ? (
                    <Zap size={11} strokeWidth={2} aria-hidden="true" style={{ flexShrink: 0, color: "var(--accent)" }} />
                  ) : (
                    <span aria-hidden="true" style={{ width: 11, lineHeight: "11px", textAlign: "center", flexShrink: 0, color: "var(--text-dim)" }}>~</span>
                  )}
                  <span style={{ display: "inline-flex", gap: "1ch", fontWeight: isLive ? 600 : 400 }}>
                    <span style={{ width: "5ch", textAlign: "right" }}>{speed.value}</span>
                    <span style={{ width: "4ch" }}>{speed.unit}</span>
                  </span>
                </div>
              );
            })()}
            </div>}
            {isMobile && showChat && (
              <div
                ref={setSessionInfoContainer}
                className="shell-session-info"
                style={{ display: "flex", height: 44, flexShrink: 0, alignSelf: "flex-start" }}
              />
            )}
            <button
              type="button"
              className="shell-toolbar-btn shell-panel-opener ui-focus-ring"
              onClick={() => {
                // Unread notifications turn the panel toggle into their shortcut.
                if (opensNotifications) {
                  setRightView("notifications");
                  setRightPanelOpen(true);
                } else {
                  setRightPanelOpen((open) => !open);
                }
              }}
              aria-expanded={rightPanelOpen}
              aria-controls="workspace-file-panel"
              aria-pressed={rightPanelOpen}
              title={panelOpenerLabel}
              aria-label={panelOpenerLabel}
            >
              <PanelRight size={16} strokeWidth={1.8} aria-hidden="true" />
              {unreadNotifications > 0 && (
                <span aria-hidden="true" className="panel-opener-badge">
                  {unreadNotifications > 99 ? "99+" : unreadNotifications}
                </span>
              )}
            </button>
          </div>

        </div>

        {/* Chat content */}
        <div style={{ flex: 1, overflow: "hidden", position: "relative" }}>
          {showChat ? (
            <ChatWindow
              key={sessionKey}
              session={selectedSession}
              newSessionCwd={effectiveNewSessionCwd}
              newSessionWorkspace={effectiveNewSessionCwd && (
                <div className="new-session-workspace">
                  <label id="new-session-workspace-label" htmlFor="new-session-workspace" className="new-session-workspace-label">
                    {t("settingsConfig.chipWorkspace")}
                  </label>
                  <div className="new-session-workspace-control">
                    <span className="new-session-workspace-icon" aria-hidden="true">
                      <Folder size={17} strokeWidth={1.8} />
                    </span>
                    <select
                      id="new-session-workspace"
                      aria-describedby="new-session-workspace-path"
                      value={effectiveNewSessionCwd}
                      onChange={(event) => {
                        const cwd = event.target.value;
                        if (!cwd) {
                          setAddProjectOpen(true);
                          return;
                        }
                        if (cwd === effectiveNewSessionCwd) return;
                        suppressCwdRef.current = cwd;
                        setActiveCwd(cwd);
                        handleNewSession("", cwd);
                      }}
                    >
                      {!workspaceOptions.projects.some((project) => comparableProjectPath(project.path) === comparableProjectPath(newSessionProject)) && (
                        <option value={effectiveNewSessionCwd}>{projectLabel(effectiveNewSessionCwd)}</option>
                      )}
                      {workspaceOptions.projects.map((project) => {
                        const current = comparableProjectPath(project.path) === comparableProjectPath(newSessionProject);
                        const label = project.alias ?? projectLabel(project.path);
                        const duplicate = workspaceOptions.projects.some((other) => other.path !== project.path && (other.alias ?? projectLabel(other.path)) === label);
                        return (
                          <option key={project.path} value={current ? effectiveNewSessionCwd : project.path}>
                            {duplicate ? `${label} — ${project.path}` : label}
                          </option>
                        );
                      })}
                      <option value="">+ {t("projects.add")}</option>
                    </select>
                    <ChevronDown className="new-session-workspace-chevron" size={16} strokeWidth={1.8} aria-hidden="true" />
                  </div>
                  <div id="new-session-workspace-path" className="new-session-workspace-path" title={effectiveNewSessionCwd}>
                    {effectiveNewSessionCwd}
                  </div>
                </div>
              )}
              onAgentEnd={handleAgentEnd}
              onSessionCreated={handleSessionCreated}
              onSessionForked={handleSessionForked}
              modelsRefreshKey={0}
              chatInputRef={chatInputRef}
              onOpenFile={handleOpenLinkedFile}
              onOpenUrl={handleSessionOpenUrl}
              onBranchDataChange={handleBranchDataChange}
              onSessionStatsChange={handleSessionStatsChange}
              onSessionStatsPanelOpen={openSessionStatsPanel}
              sessionInfoContainer={sessionInfoContainer}
              onGenerationSpeedChange={handleGenerationSpeedChange}
              toolCallsDefaultCollapsed={toolCallsDefaultCollapsed}
              expandThinkingByDefault={expandThinkingByDefault}
              hideThinkingBlock={hideThinkingBlock}
            />
          ) : initialCwdStatus === "validating" ? (
            <WorkspaceState
              kind="loading"
              title={t("appShell.openingWorkspace")}
              detail={<span className="workspace-state-path">{initialNavigation.requestedCwd}</span>}
            />
          ) : initialCwdStatus === "error" ? (
            <WorkspaceState
              kind="error"
              title={t("appShell.unableToOpenWorkspace")}
              detail={(
                <>
                  <span className="workspace-state-path">{initialNavigation.requestedCwd}</span>
                  <span>{initialCwdError}</span>
                </>
              )}
            />
          ) : !showPlaceholder ? (
            <PanelLoadingFallback />
          ) : activeCwd ? (
            <WorkspaceState kind="empty" title={t("appShell.selectSessionHint")} />
          ) : (
              <div style={{ position: "absolute", top: 12, left: 12, display: "flex", alignItems: "flex-start", gap: 8, userSelect: "none" }}>
                <svg width="44" height="44" viewBox="0 0 24 24" fill="none" stroke="var(--accent)" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" style={{ opacity: 0.7, flexShrink: 0 }}>
                  <line x1="20" y1="12" x2="4" y2="12" /><polyline points="10 6 4 12 10 18" />
                </svg>
                <div>
                  <div className="display-serif" style={{ fontSize: 20, color: "var(--text)", marginBottom: 8 }}>{t("appShell.getStarted")}</div>
                  <div style={{ fontSize: 12, color: "var(--text-muted)", lineHeight: 1.8 }}>
                    <span style={{ color: "var(--text-dim)", marginRight: 6 }}>1.</span>{t("appShell.getStartedStep1")}<br />
                    <span style={{ color: "var(--text-dim)", marginRight: 6 }}>2.</span>{t("appShell.getStartedStep2")}<br />
                  <button
                    type="button"
                    onClick={() => {
                      setSidebarOpen(true);
                      setAddProjectOpen(true);
                    }}
                    style={{ display: "flex", alignItems: "center", gap: 6, width: "fit-content", minHeight: 36, marginTop: 12, padding: "7px 10px", border: "1px solid var(--border)", borderRadius: "var(--radius-control)", background: "var(--bg-panel)", color: "var(--text)", cursor: "pointer", fontSize: 12, fontWeight: 600, boxShadow: "var(--shadow-card)" }}
                    className="ui-focus-ring"
                  >
                    <Folder size={14} strokeWidth={1.8} aria-hidden="true" />
                    {t("appShell.openWorkspaces")}
                  </button>
                  </div>
                </div>
              </div>
          )}
        </div>
          </>
        )}
      </main>
      {rightPanelIsModal && (
        <div
          className="right-panel-backdrop"
          aria-hidden="true"
          onClick={closeRightPanel}
        />
      )}
      {!settingsTab && rightPanelHasOpened && (
        <Suspense fallback={null}>
        <RightPanel
        fileTabs={fileTabs}
        activeFileTabId={activeFileTabId}
        rightView={rightView}
        onSelectView={handleSelectRightView}
        rightPanelOpen={rightPanelOpen}
        onClose={closeRightPanel}
        rightPanelWidth={rightPanelWidth}
        rightPanelResizing={rightPanelResizing}
        rightPanelRef={attachRightPanel}
        fileExplorerRef={fileExplorerRef}
        revealPath={revealPath}
        onRevealDone={handleRevealDone}
        explorerCwd={explorerCwd}
        explorerRefreshKey={explorerRefreshKey}
        fileSearchOpen={fileSearchOpen}
        onToggleFileSearch={handleToggleFileSearch}
        onFileSearchOpenChange={setFileSearchOpen}
        explorerUploadBusy={explorerUploadBusy}
        onUploadBusyChange={setExplorerUploadBusy}
        explorerGitCount={explorerGitCount}
        explorerIsRepo={explorerIsRepo}
        explorerRefreshing={explorerRefreshing}
        isMobile={isMobile}
        isCompactOverlay={isCompactOverlay}
        onOpenFile={handleOpenFile}
        onSelectFileTab={handleSelectFileTab}
        onCloseFileTab={handleCloseFileTab}
        onCloseOtherFileTabs={handleCloseOtherFileTabs}
        onCloseAllFileTabs={handleCloseAllFileTabs}
        onMentionActiveFile={handleMentionActiveFile}
        onCopyActiveFilePath={handleCopyActiveFilePath}
        onDownloadActiveFile={handleDownloadActiveFile}
        onRevealActiveFile={handleRevealActiveFile}
        onExplorerRefresh={handleExplorerRefresh}
        onExplorerRefreshDone={handleExplorerRefreshDone}
        onAtMention={handleAtMention}
        onAtMentions={handleAtMentions}
        onMentionLines={handleFileLineMention}
        onExplorerGitStatus={handleExplorerGitStatus}
        onResetRightPanelWidth={resetRightPanelWidth}
        onRightPanelResizeStart={handleRightPanelResizeStart}
        onRightPanelResizeKey={handleRightPanelResizeKey}
      />
        </Suspense>
      )}

    </div>
    {archiveBrowserOpen && (
      <ArchiveBrowser
        open={archiveBrowserOpen}
        onClose={() => setArchiveBrowserOpen(false)}
        onRestored={handleArchiveRestored}
      />
    )}
    </ToastProvider>
    </>
  );
}
