
import type { ReactNode } from "react";
import { CircleAlert, MessageSquareText } from "lucide-react";
import { useI18n } from "@/lib/i18n";

export function projectLabel(projectPath: string): string {
  const trimmed = projectPath.replace(/[\\/]+$/, "");
  const index = Math.max(trimmed.lastIndexOf("/"), trimmed.lastIndexOf("\\"));
  return index >= 0 ? trimmed.slice(index + 1) : trimmed;
}

// Resizable desktop sidebar: the width is stored on the container as the
// --sidebar-width CSS variable (globals.css) and persisted between sessions.
export const SIDEBAR_WIDTH_STORAGE_KEY = "omp-web:sidebar-width";
export const SIDEBAR_MIN_WIDTH = 200;
export const SIDEBAR_DEFAULT_WIDTH = 260;

// Resizable right (file) panel: null means the fluid 42% default; a number is
// a user-chosen pixel width persisted between sessions (same drag pattern as
// the left sidebar, mirrored — the handle sits on the panel's left edge).
export const RIGHT_PANEL_WIDTH_STORAGE_KEY = "omp-web:right-panel-width";
export const RIGHT_PANEL_MIN_WIDTH = 300;

/**
 * Desktop width budget shared by the two docked side panels: together they may
 * occupy at most 90% of the workspace flex row, so the center chat column
 * always keeps at least 10%. There is no fixed pixel cap for either panel —
 * a panel alone may use the whole budget.
 */
export const DOCKED_PANELS_BUDGET_RATIO = 0.9;

/** Joint pixel budget `B = floor(0.90 × W)` for the docked side panels. */
export function dockedPanelsBudget(workspaceWidth: number): number {
  if (!Number.isFinite(workspaceWidth)) return Number.POSITIVE_INFINITY;
  return Math.max(0, Math.floor(workspaceWidth * DOCKED_PANELS_BUDGET_RATIO));
}

/**
 * Max width for the left sidebar given the shared budget. With the right panel
 * docked the pair shares the budget, so the sidebar may grow into everything
 * except the right panel's minimum (option A2: pushing it wider shrinks the
 * opposite panel). Alone it may use the entire budget.
 */
export function sidebarMaxWidth(budget: number, rightDocked: boolean): number {
  return rightDocked
    ? Math.max(SIDEBAR_MIN_WIDTH, budget - RIGHT_PANEL_MIN_WIDTH)
    : Math.max(SIDEBAR_MIN_WIDTH, budget);
}

/** Mirror of {@link sidebarMaxWidth} for the right (file) panel. */
export function rightPanelMaxWidth(budget: number, leftDocked: boolean): number {
  return leftDocked
    ? Math.max(RIGHT_PANEL_MIN_WIDTH, budget - SIDEBAR_MIN_WIDTH)
    : Math.max(RIGHT_PANEL_MIN_WIDTH, budget);
}

export function clampSidebarWidth(width: number, maxWidth: number = Number.POSITIVE_INFINITY): number {
  const upper = Math.max(SIDEBAR_MIN_WIDTH, Math.floor(maxWidth));
  return Math.min(upper, Math.max(SIDEBAR_MIN_WIDTH, Math.round(width)));
}

export function clampRightPanelWidth(width: number, maxWidth: number = Number.POSITIVE_INFINITY): number {
  const upper = Math.max(RIGHT_PANEL_MIN_WIDTH, Math.floor(maxWidth));
  return Math.min(upper, Math.max(RIGHT_PANEL_MIN_WIDTH, Math.round(width)));
}

// The persisted width is capped to the current viewport budget as a first
// approximation; the workspace-row ResizeObserver in AppShell re-clamps it
// against the real flex-container width once mounted.
export function loadSidebarWidth(): number {
  if (typeof window === "undefined") return SIDEBAR_DEFAULT_WIDTH;
  try {
    const raw = window.localStorage.getItem(SIDEBAR_WIDTH_STORAGE_KEY);
    const width = raw ? Number(raw) : NaN;
    return Number.isFinite(width) ? clampSidebarWidth(width, dockedPanelsBudget(window.innerWidth)) : SIDEBAR_DEFAULT_WIDTH;
  } catch {
    return SIDEBAR_DEFAULT_WIDTH;
  }
}

export function loadRightPanelWidth(): number | null {
  if (typeof window === "undefined") return null;
  try {
    const raw = window.localStorage.getItem(RIGHT_PANEL_WIDTH_STORAGE_KEY);
    if (!raw) return null;
    const width = Number(raw);
    return Number.isFinite(width) ? clampRightPanelWidth(width, dockedPanelsBudget(window.innerWidth)) : null;
  } catch {
    return null;
  }
}

type WorkspaceStateKind = "loading" | "error" | "empty";

export function WorkspaceState({
  kind,
  title,
  detail,
}: {
  kind: WorkspaceStateKind;
  title: string;
  detail?: ReactNode;
}) {
  return (
    <div
      className={`workspace-state workspace-state-${kind}`}
      role={kind === "error" ? "alert" : kind === "loading" ? "status" : undefined}
      aria-busy={kind === "loading" ? true : undefined}
      aria-label={kind === "loading" ? title : undefined}
    >
      <div className="workspace-state-surface">
        {kind === "loading" ? (
          <div className="workspace-state-skeleton" aria-hidden="true">
            <span />
            <span />
            <span />
          </div>
        ) : kind === "error" ? (
          <CircleAlert className="workspace-state-icon" size={18} strokeWidth={1.8} aria-hidden="true" />
        ) : (
          <MessageSquareText className="workspace-state-icon" size={18} strokeWidth={1.8} aria-hidden="true" />
        )}
        <div className="workspace-state-copy">
          <div className="workspace-state-title">{title}</div>
          {detail ? <div className="workspace-state-detail">{detail}</div> : null}
        </div>
      </div>
    </div>
  );
}

export function PanelLoadingFallback() {
  const { t } = useI18n();
  return <WorkspaceState kind="loading" title={t("appShell.loading")} />;
}
