import { useEffect, useRef, useSyncExternalStore } from "react";
import { toast } from "@/components/ui/toast";
import { translate } from "@/lib/i18n";
import { DEFAULT_NOTIFICATION_PREFS, renderNotification, type NotificationEvent, type RenderedNotification } from "@/lib/notification-events";
import { notificationHistory } from "@/lib/notification-history";
import { isRecord } from "@/lib/type-guards";
import {
  ensurePushSubscription,
  getNotificationDeviceId,
  getNotificationPrefs,
  hasStoredNotificationPrefs,
  NOTIFICATION_MESSAGE_EVENT,
  notificationClientId,
  OPEN_SESSION_EVENT,
  showSystemNotification,
  subscribeNotificationPrefs,
  syncNotificationDevice,
  updateNotificationPrefs,
} from "@/lib/notification-client";

const PRESENCE_INTERVAL_MS = 30_000;
/** Without input for this long a visible tab no longer counts as the user being there. */
const IDLE_AFTER_MS = 3 * 60_000;
const ACTIVITY_EVENTS = ["pointerdown", "keydown", "wheel", "touchstart", "focus"] as const;
/** Orders this page's presence reports; it outlives effect re-runs, so a session switch never restarts it. */
let presenceSeq = 0;

/** Current per-device notification prefs (re-renders on change). */
export function useNotificationPrefs() {
  return useSyncExternalStore(subscribeNotificationPrefs, getNotificationPrefs, () => DEFAULT_NOTIFICATION_PREFS);
}

/**
 * App-level notification wiring, mounted once in AppShell:
 * - tells the server which session this tab shows and whether the user is here;
 * - shows toasts / system notifications the server routes to this tab;
 * - opens the session when a notification is clicked;
 * - keeps the server's copy of this device's prefs and push subscription current.
 *
 * `sessionId` is the session whose chat is on screen (null while Settings or
 * another view covers it).
 */
export function useNotifications({ sessionId, locale, onOpenSession }: { sessionId: string | null; locale: string; onOpenSession: (sessionId: string) => void }) {
  const openRef = useRef(onOpenSession);
  useEffect(() => {
    openRef.current = onOpenSession;
  }, [onOpenSession]);

  // Presence: visible and recently used. Reported on every change, plus a keep-alive.
  useEffect(() => {
    let lastInput = Date.now();
    let reported: boolean | null = null;
    const present = () => document.visibilityState === "visible" && Date.now() - lastInput < IDLE_AFTER_MS;
    const report = (visible = present()) => {
      reported = visible;
      presenceSeq += 1;
      const body = JSON.stringify({ clientId: notificationClientId, deviceId: getNotificationDeviceId(), visible, sessionId, seq: presenceSeq });
      if (!visible && navigator.sendBeacon) {
        navigator.sendBeacon("/api/notifications/presence", new Blob([body], { type: "application/json" }));
        return;
      }
      void fetch("/api/notifications/presence", { method: "POST", headers: { "Content-Type": "application/json" }, body, keepalive: true }).catch(() => {});
    };
    const onActivity = () => {
      lastInput = Date.now();
      if (reported === false && present()) report();
    };
    const onVisibility = () => report();
    const onPageHide = () => report(false);
    report();
    const timer = setInterval(() => {
      // Keep-alive while present; one report when the user goes idle.
      if (present() || reported) report();
    }, PRESENCE_INTERVAL_MS);
    for (const name of ACTIVITY_EVENTS) window.addEventListener(name, onActivity, { passive: true, capture: true });
    document.addEventListener("visibilitychange", onVisibility);
    window.addEventListener("pagehide", onPageHide);
    return () => {
      clearInterval(timer);
      for (const name of ACTIVITY_EVENTS) window.removeEventListener(name, onActivity, { capture: true });
      document.removeEventListener("visibilitychange", onVisibility);
      window.removeEventListener("pagehide", onPageHide);
    };
  }, [sessionId]);

  // Pushes are written in the device's language.
  useEffect(() => {
    const prefs = getNotificationPrefs();
    if (prefs.enabled && prefs.locale !== locale) void updateNotificationPrefs({ locale }).catch(() => {});
  }, [locale]);

  // Startup sync for any browser with saved settings: the server may have lost
  // its store, missed a save (including turning notifications off), or the
  // browser its subscription. Browsers that never opened the setting stay off
  // the server's device list.
  useEffect(() => {
    if (!hasStoredNotificationPrefs()) return;
    void (async () => {
      const pushActive = getNotificationPrefs().enabled && (await ensurePushSubscription().catch(() => false));
      if (!pushActive) await syncNotificationDevice();
    })().catch(() => {});
  }, []);

  // The persisted Notifications list: loaded now and whenever the tab comes back, which brings read marks and removals from other devices.
  useEffect(() => {
    void notificationHistory.load();
    const onVisibility = () => {
      if (document.visibilityState === "visible") void notificationHistory.load();
    };
    document.addEventListener("visibilitychange", onVisibility);
    return () => document.removeEventListener("visibilitychange", onVisibility);
  }, []);

  // Delivery to this tab and notification clicks.
  useEffect(() => {
    const showToast = (rendered: RenderedNotification, type: NotificationEvent["type"]) => {
      const show = type === "error" ? toast.error : toast.info;
      const target = rendered.sessionId;
      // The whole card opens the session (click, tap, or Enter on the focused card); following it is reading it.
      show(rendered.title, rendered.body, {
        id: rendered.tag,
        onClick: target ? () => {
          notificationHistory.markRead(rendered.tag);
          openRef.current(target);
        } : undefined,
      });
    };
    const onMessage = (raw: Event) => {
      if (!(raw instanceof CustomEvent)) return;
      // Sent by SessionSidebar from our own SSE stream. The server has already recorded it.
      const { kind, event }: { kind: "toast" | "os"; event: NotificationEvent } = raw.detail;
      notificationHistory.add(event);
      const rendered = renderNotification(event, translate);
      if (kind === "toast") {
        showToast(rendered, event.type);
        return;
      }
      // Permission withdrawn or never granted: the toast is the only way left to tell the user.
      void showSystemNotification(rendered).then((shown) => {
        if (!shown) showToast(rendered, event.type);
      });
    };
    const onOpen = (raw: Event) => {
      if (raw instanceof CustomEvent && typeof raw.detail === "string" && raw.detail) openRef.current(raw.detail);
    };
    const onWorkerMessage = (message: MessageEvent) => {
      const data: unknown = message.data;
      if (!isRecord(data)) return;
      if (data.type === "omp-open-session" && typeof data.sessionId === "string") {
        openRef.current(data.sessionId);
        return;
      }
      // A push the service worker showed while this tab was open: the server recorded it; fetch the list.
      if (data.type === "omp-notification-shown") void notificationHistory.load();
    };
    window.addEventListener(NOTIFICATION_MESSAGE_EVENT, onMessage);
    window.addEventListener(OPEN_SESSION_EVENT, onOpen);
    navigator.serviceWorker?.addEventListener("message", onWorkerMessage);
    return () => {
      window.removeEventListener(NOTIFICATION_MESSAGE_EVENT, onMessage);
      window.removeEventListener(OPEN_SESSION_EVENT, onOpen);
      navigator.serviceWorker?.removeEventListener("message", onWorkerMessage);
    };
  }, []);
}
