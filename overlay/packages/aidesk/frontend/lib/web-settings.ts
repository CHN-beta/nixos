/**
 * Account-wide UI preferences, persisted on the server so every device and
 * browser profile sees the same view of the code and the file tree.
 *
 * The store is shared by every mounted consumer: a toggle in one panel
 * notifies the others immediately, and the PUT only records the choice.
 */
import { useSyncExternalStore } from "react";
import { apiUrl } from "./api-origin";
import { isRecord } from "./type-guards";

export interface WebSettings {
  /** Wrap long source lines in the file viewer. */
  sourceWordWrap: boolean;
  /** Show dotfiles and dot-directories in the file explorer. */
  showHiddenFiles: boolean;
}

export interface WebSettingsActions {
  setSourceWordWrap: (next: boolean) => void;
  setShowHiddenFiles: (next: boolean) => void;
}

export const DEFAULT_WEB_SETTINGS: WebSettings = {
  sourceWordWrap: false,
  showHiddenFiles: false,
};

const SETTINGS_URL = apiUrl("/api/web-settings");

let settings: WebSettings = DEFAULT_WEB_SETTINGS;
const listeners = new Set<() => void>();

/**
 * Bumped by every local change. A GET that started before a change must not
 * overwrite it: the response predates the choice the user just made.
 */
let changes = 0;
/** Writes still in flight; their response is newer than any GET in flight. */
let writesInFlight = 0;
/** A GET answered after a write started would be stale; re-run it afterwards. */
let reloadWhenSettled = false;
let loadStarted = false;
let loadGeneration = 0;

function notify(): void {
  for (const listener of listeners) listener();
}

function readSettings(body: unknown): WebSettings {
  const record = isRecord(body) ? body : {};
  return {
    sourceWordWrap: record.sourceWordWrap === true,
    showHiddenFiles: record.showHiddenFiles === true,
  };
}

async function load(): Promise<void> {
  const generation = ++loadGeneration;
  const changesAtStart = changes;
  let body: unknown;
  try {
    const response = await fetch(SETTINGS_URL, { credentials: "same-origin" });
    if (!response.ok) return;
    body = await response.json();
  } catch {
    return; // Offline: keep the current view; the next focus or toggle catches up.
  }
  if (generation !== loadGeneration) return; // A newer request answers instead.
  if (changes !== changesAtStart || writesInFlight > 0) {
    // The user changed something while this GET was in flight, so its snapshot
    // is stale. Ask again once the writes settle.
    if (writesInFlight > 0) reloadWhenSettled = true;
    else void load();
    return;
  }
  const next = readSettings(body);
  if (next.sourceWordWrap === settings.sourceWordWrap && next.showHiddenFiles === settings.showHiddenFiles) {
    return;
  }
  settings = next;
  notify();
}

function update(patch: Partial<WebSettings>): void {
  changes += 1;
  settings = { ...settings, ...patch };
  notify();
  writesInFlight += 1;
  void fetch(SETTINGS_URL, {
    method: "PUT",
    headers: { "Content-Type": "application/json" },
    credentials: "same-origin",
    body: JSON.stringify(patch),
  })
    .catch(() => {
      // The optimistic value stays; the next load reconciles it with the server.
    })
    .finally(() => {
      writesInFlight -= 1;
      if (writesInFlight === 0 && reloadWhenSettled) {
        reloadWhenSettled = false;
        void load();
      }
    });
}

function onFocus(): void {
  if (listeners.size > 0) void load();
}

function subscribe(listener: () => void): () => void {
  listeners.add(listener);
  if (listeners.size === 1 && typeof window !== "undefined") {
    window.addEventListener("focus", onFocus);
  }
  if (!loadStarted) {
    loadStarted = true;
    void load();
  }
  return () => {
    listeners.delete(listener);
    if (listeners.size === 0 && typeof window !== "undefined") {
      window.removeEventListener("focus", onFocus);
    }
  };
}

function getSnapshot(): WebSettings {
  return settings;
}

export function setSourceWordWrap(next: boolean): void {
  if (settings.sourceWordWrap === next) return;
  update({ sourceWordWrap: next });
}

export function setShowHiddenFiles(next: boolean): void {
  if (settings.showHiddenFiles === next) return;
  update({ showHiddenFiles: next });
}

/**
 * The shared preferences plus their setters. Every mounted consumer reads the
 * same snapshot, so a toggle in the viewer also restyles an open editor and
 * the explorer without a reload.
 */
export function useWebSettings(): WebSettings & WebSettingsActions {
  const snapshot = useSyncExternalStore(subscribe, getSnapshot, () => DEFAULT_WEB_SETTINGS);
  return {
    sourceWordWrap: snapshot.sourceWordWrap,
    showHiddenFiles: snapshot.showHiddenFiles,
    setSourceWordWrap,
    setShowHiddenFiles,
  };
}
