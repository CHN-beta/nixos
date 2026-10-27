
import { useSyncExternalStore } from "react";

// The right panel becomes an overlay at the same widths as its CSS treatment.
const COMPACT_OVERLAY_QUERY = "(max-width: 960px)";

function subscribe(cb: () => void): () => void {
  if (typeof window === "undefined" || !window.matchMedia) return () => {};
  const mql = window.matchMedia(COMPACT_OVERLAY_QUERY);
  mql.addEventListener("change", cb);
  return () => mql.removeEventListener("change", cb);
}

function getSnapshot(): boolean {
  if (typeof window === "undefined" || !window.matchMedia) return false;
  return window.matchMedia(COMPACT_OVERLAY_QUERY).matches;
}

function getServerSnapshot(): boolean {
  return false;
}

/** True when the right panel covers the workspace instead of docking beside it. */
export function useIsCompactOverlay(): boolean {
  return useSyncExternalStore(subscribe, getSnapshot, getServerSnapshot);
}
