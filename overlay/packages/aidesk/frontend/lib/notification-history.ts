import { useSyncExternalStore } from "react";
import type { NotificationEvent, NotificationHistoryEntry } from "./notification-events";
import { isRecord } from "./type-guards";

/**
 * Browser mirror of the server's notification history (Notifications tab).
 * The server records every notification; this list shows them, updates at
 * once on read/remove/clear, and reloads from the server when a change
 * request fails or the tab becomes visible.
 */

const HISTORY_URL = "/api/notifications/history";
const LIMIT = 100;

let entries: NotificationHistoryEntry[] = [];
const listeners = new Set<() => void>();
function set(next: NotificationHistoryEntry[]) {
  entries = next;
  for (const listener of listeners) listener();
}

// A load's snapshot is stale if a local change happened while it was in flight,
// or a change request has not reached the server yet; it is then fetched again
// once those requests settle, so a removed entry never comes back.
let changes = 0;
let requestsInFlight = 0;
let loads = 0;
let reloadWhenSettled = false;
function change(next: NotificationHistoryEntry[]) {
  changes++;
  set(next);
}

const isEntry = (value: unknown): value is NotificationHistoryEntry =>
  isRecord(value) && typeof value.id === "string" && isRecord(value.event) && typeof value.event.sessionId === "string" && typeof value.event.type === "string" && typeof value.at === "number" && typeof value.read === "boolean";

function send(query: string, init: RequestInit) {
  requestsInFlight++;
  void fetch(`${HISTORY_URL}${query}`, init)
    .then((response) => {
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
    })
    // The server's list is the truth; drop the local change rather than show a state it does not have.
    .catch(() => { reloadWhenSettled = true; })
    .finally(() => {
      requestsInFlight--;
      if (requestsInFlight > 0 || !reloadWhenSettled) return;
      reloadWhenSettled = false;
      void notificationHistory.load();
    });
}

const markRead = (ids: string[]) => send("", { method: "PATCH", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ ids }) });

export const notificationHistory = {
  subscribe(listener: () => void) {
    listeners.add(listener);
    return () => { listeners.delete(listener); };
  },
  get: () => entries,
  /** Replace the list with the server's; a failed request keeps the current one. */
  async load() {
    const load = ++loads;
    const changesBefore = changes;
    let body: unknown;
    try {
      const response = await fetch(HISTORY_URL);
      if (!response.ok) return;
      body = await response.json();
    } catch {
      return; // Offline: keep what is shown; the next load catches up.
    }
    if (load !== loads) return; // A newer load answers instead.
    if (changes !== changesBefore || requestsInFlight > 0) {
      if (requestsInFlight > 0) reloadWhenSettled = true;
      else void notificationHistory.load();
      return;
    }
    if (isRecord(body) && Array.isArray(body.entries)) set(body.entries.filter(isEntry));
  },
  /** A notification delivered to this tab, already recorded by the server. */
  add(event: NotificationEvent) {
    const id = `${event.sessionId}:${event.type}`;
    change([{ id, event, at: Date.now(), read: false }, ...entries.filter((entry) => entry.id !== id)].slice(0, LIMIT));
  },
  markRead(id: string) {
    if (!entries.some((entry) => entry.id === id && !entry.read)) return;
    change(entries.map((entry) => (entry.id === id ? { ...entry, read: true } : entry)));
    markRead([id]);
  },
  /** Marks the entries this tab shows; ones that reached the server since stay unread. */
  markAllRead() {
    const unread = entries.filter((entry) => !entry.read).map((entry) => entry.id);
    if (unread.length === 0) return;
    change(entries.map((entry) => (entry.read ? entry : { ...entry, read: true })));
    markRead(unread);
  },
  remove(id: string) {
    change(entries.filter((entry) => entry.id !== id));
    send(`?id=${encodeURIComponent(id)}`, { method: "DELETE" });
  },
  clear() {
    change([]);
    send("?all=1", { method: "DELETE" });
  },
};

export function useNotificationHistory(): NotificationHistoryEntry[] {
  return useSyncExternalStore(notificationHistory.subscribe, notificationHistory.get, notificationHistory.get);
}

const unreadCount = () => entries.reduce((count, entry) => count + (entry.read ? 0 : 1), 0);
/** Unread entry count. A primitive snapshot, so callers re-render only when the count changes. */
export function useUnreadNotificationCount(): number {
  return useSyncExternalStore(notificationHistory.subscribe, unreadCount, unreadCount);
}
