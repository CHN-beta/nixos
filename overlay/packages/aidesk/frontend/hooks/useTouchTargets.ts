
import { useCallback, useEffect, useSyncExternalStore } from "react";

export type TouchTargetsPreference = "auto" | "compact" | "accessible";

export const STORAGE_KEY = "omp-touch-targets";
export const DEFAULT_TOUCH_TARGETS: TouchTargetsPreference = "auto";
export const TOUCH_TARGETS_CHANGE_EVENT = "omp-touch-targets-change";

const VALID_TOUCH_TARGETS: Record<TouchTargetsPreference, true> = {
  auto: true,
  compact: true,
  accessible: true,
};

const listeners = new Set<() => void>();

function subscribe(cb: () => void): () => void {
  listeners.add(cb);
  return () => listeners.delete(cb);
}

function notifyListeners(): void {
  listeners.forEach((cb) => cb());
}

export function storedTouchTargetsPreference(): TouchTargetsPreference {
  if (typeof window === "undefined") return DEFAULT_TOUCH_TARGETS;
  try {
    const value = localStorage.getItem(STORAGE_KEY);
    return value && Object.hasOwn(VALID_TOUCH_TARGETS, value) ? (value as TouchTargetsPreference) : DEFAULT_TOUCH_TARGETS;
  } catch {
    return DEFAULT_TOUCH_TARGETS;
  }
}

export function nextTouchTargetsPreference(current: TouchTargetsPreference): TouchTargetsPreference {
  switch (current) {
    case "auto":
      return "compact";
    case "compact":
      return "accessible";
    case "accessible":
      return "auto";
    default:
      return DEFAULT_TOUCH_TARGETS;
  }
}

export function applyTouchTargets(preference: TouchTargetsPreference): void {
  if (typeof document !== "undefined") {
    document.documentElement.setAttribute("data-touch-targets", preference);
  }
  if (typeof window !== "undefined") {
    try {
      localStorage.setItem(STORAGE_KEY, preference);
    } catch {
      // Storage selection remains usable when localStorage is unavailable.
    }
    window.dispatchEvent(new CustomEvent(TOUCH_TARGETS_CHANGE_EVENT, { detail: preference }));
  }
  notifyListeners();
}

export function useTouchTargets() {
  const touchTargets = useSyncExternalStore(subscribe, storedTouchTargetsPreference, () => DEFAULT_TOUCH_TARGETS);

  useEffect(() => {
    if (typeof window === "undefined") return;

    const handleStorage = (event: StorageEvent) => {
      if (event.key === STORAGE_KEY) {
        notifyListeners();
      }
    };

    const handleCustomEvent = () => {
      notifyListeners();
    };

    window.addEventListener("storage", handleStorage);
    window.addEventListener(TOUCH_TARGETS_CHANGE_EVENT, handleCustomEvent);

    return () => {
      window.removeEventListener("storage", handleStorage);
      window.removeEventListener(TOUCH_TARGETS_CHANGE_EVENT, handleCustomEvent);
    };
  }, []);

  const setTouchTargets = useCallback((preference: TouchTargetsPreference) => {
    applyTouchTargets(preference);
  }, []);

  return {
    touchTargets,
    setTouchTargets,
  };
}
