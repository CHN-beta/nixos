/**
 * App-level "still loading" notice.
 *
 * The shell keeps one sticky toast up while its state is not ready yet: during
 * the first paint (before the sidebar's session/project lists and the initial
 * restore have resolved) and while a dropped state stream reconnects and
 * re-syncs. A fixed timer would either hide the notice before slow data
 * arrives or linger after it, so the notice is bound to reasons instead:
 * `beginAppLoad`/`endAppLoad` pairs, and the toast closes when the last reason
 * ends.
 */
import { toast } from "@/components/ui/toast";
import { translate } from "@/lib/i18n";

export type AppLoadReason = "initial" | "reconnect";

/** One id for every update, so phases replace the notice instead of stacking. */
export const APP_LOADING_TOAST_ID = "app-loading";

const active = new Set<AppLoadReason>();

function render(): void {
  if (active.size === 0) {
    toast.close(APP_LOADING_TOAST_ID);
    return;
  }
  // A lost connection is the more urgent fact: say "reconnecting" even if the
  // first load is still in flight.
  const reconnecting = active.has("reconnect");
  toast.loading(
    translate(reconnecting ? "appLoading.reconnecting" : "appLoading.initial"),
    translate(reconnecting ? "appLoading.reconnectingDetail" : "appLoading.initialDetail"),
    { id: APP_LOADING_TOAST_ID, timeout: 0 },
  );
}

/** Mark one load phase as running; shows or replaces the notice. Idempotent. */
export function beginAppLoad(reason: AppLoadReason): void {
  if (active.has(reason)) return;
  active.add(reason);
  render();
}

/** Mark one load phase as done; closes the notice when none is left. Idempotent. */
export function endAppLoad(reason: AppLoadReason): void {
  if (!active.delete(reason)) return;
  render();
}
