import { useState, useEffect, useRef, useCallback } from "react";
import type {
  ProviderUsageLimitItem,
  ProviderUsageReport,
  ProviderUsageSnapshot,
  ProviderUsageWindow,
} from "@/lib/provider-usage-types";

/** Display names for providers the UI knows; unknown ids render verbatim. */
export const PROVIDER_DISPLAY_NAMES: Record<string, string> = {
  anthropic: "Anthropic",
  openai: "OpenAI",
  "openai-codex": "OpenAI Codex",
  "github-copilot": "GitHub Copilot",
  google: "Google",
  "google-gemini-cli": "Gemini CLI",
  "google-antigravity": "Google Antigravity",
  cliproxyapi: "CLIProxyAPI",
  ollama: "Ollama",
};

export function formatUsageReset(value: number, unit: "minutes" | "hours"): string {
  if (unit === "minutes") {
    if (value < 60) return `${value}m`;
    const hours = Math.floor(value / 60);
    const minutes = value % 60;
    return minutes > 0 ? `${hours}h ${minutes}m` : `${hours}h`;
  }
  if (value < 24) return `${value}h`;
  const days = Math.floor(value / 24);
  const hours = value % 24;
  return hours > 0 ? `${days}d ${hours}h` : `${days}d`;
}

export function usageTone(percent: number): string {
  if (percent >= 80) return "var(--status-error)";
  if (percent >= 50) return "var(--status-warning)";
  return "var(--text-muted)";
}

/** Percentage used, derived from absolute amounts when no fraction is sent. */
export function usageWindowPercent(
  window: ProviderUsageWindow | ProviderUsageLimitItem,
): number | null {
  if (typeof window.percent === "number" && Number.isFinite(window.percent)) return window.percent;
  if (typeof window.used === "number" && typeof window.limit === "number") {
    if (window.limit > 0) return (window.used / window.limit) * 100;
    return window.used > 0 ? 100 : 0;
  }
  return null;
}

/** Limits to render for a report: the flat list when present, otherwise the
 *  legacy per-window fields. */
export function reportUsageLimits(report: ProviderUsageReport): ProviderUsageLimitItem[] {
  if (report.limits && report.limits.length > 0) return report.limits;
  const limits: ProviderUsageLimitItem[] = [];
  if (report.fiveHour) limits.push({ ...report.fiveHour, windowId: "5h" });
  if (report.sevenDay) limits.push({ ...report.sevenDay, windowId: "7d" });
  if (report.monthly) limits.push({ ...report.monthly, windowId: "monthly" });
  return limits;
}

export type ProviderUsageState = {
  snapshot: ProviderUsageSnapshot | null;
  loading: boolean;
  error: boolean;
};

export function useProviderUsage(query: string | null, refreshMs?: number): ProviderUsageState & { refresh: () => Promise<boolean> } {
  const [state, setState] = useState<ProviderUsageState>({ snapshot: null, loading: false, error: false });
  const refreshRef = useRef<() => Promise<boolean>>(async () => false);
  const refresh = useCallback(() => refreshRef.current(), []);
  useEffect(() => {
    if (query === null) {
      setState({ snapshot: null, loading: false, error: false });
      return;
    }
    const controller = new AbortController();
    setState({ snapshot: null, loading: true, error: false });
    let inFlight: Promise<boolean> | undefined;
    let inFlightForced = false;
    const load = (force = false): Promise<boolean> => {
      if (controller.signal.aborted) return Promise.resolve(false);
      if (inFlight) {
        return force && !inFlightForced ? inFlight.then(() => load(true)) : inFlight;
      }
      if (force) setState((previous) => ({ ...previous, loading: true, error: false }));
      const params = new URLSearchParams(query);
      if (force) params.set("refresh", "true");
      const queryString = params.toString();
      inFlightForced = force;
      inFlight = (async () => {
        try {
          const response = await fetch(`/api/provider-usage${queryString ? `?${queryString}` : ""}`, { signal: controller.signal });
          if (!response.ok) throw new Error(`HTTP ${response.status}`);
          const snapshot = await response.json() as ProviderUsageSnapshot;
          if (controller.signal.aborted) return false;
          setState({ snapshot, loading: false, error: false });
          return true;
        } catch {
          if (!controller.signal.aborted) setState({ snapshot: null, loading: false, error: true });
          return false;
        } finally {
          inFlight = undefined;
        }
      })();
      return inFlight;
    };
    refreshRef.current = () => load(true);
    void load();
    const interval = refreshMs ? window.setInterval(() => void load(), refreshMs) : undefined;
    return () => {
      refreshRef.current = async () => false;
      controller.abort();
      if (interval !== undefined) window.clearInterval(interval);
    };
  }, [query, refreshMs]);
  return { ...state, refresh };
}
