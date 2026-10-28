
import { useCallback, useEffect, useState, useSyncExternalStore } from "react";

export type LightTheme = "light" | "one-light" | "catppuccin-latte" | "rose-pine-dawn";
export type DarkTheme =
  | "dark"
  | "omp"
  | "dracula"
  | "harbor"
  | "one-dark-pro"
  | "rose-pine"
  | "catppuccin-mocha"
  | "gruvbox-dark"
  | "nord"
  | "tokyo-night";

export type Theme = LightTheme | DarkTheme;
export type ThemeMode = "auto" | "light" | "dark";
/** A concrete theme, or `"system"` as the legacy spelling of `mode: "auto"`. */
export type ThemePreference = Theme | "system";

export type ThemeDefinition = {
  id: Theme;
  name: string;
  mode: "light" | "dark";
  bg: string;
  accent: string;
};

export const LIGHT_THEMES: ReadonlyArray<ThemeDefinition> = [
  { id: "catppuccin-latte", name: "Catppuccin Latte", mode: "light", bg: "#EFF1F5", accent: "#1E66F5" },
  { id: "light", name: "Warm Paper", mode: "light", bg: "#FAF9F6", accent: "#B03E22" },
  { id: "one-light", name: "One Light", mode: "light", bg: "#FAFAFA", accent: "#2F65D9" },
  { id: "rose-pine-dawn", name: "Rosé Pine Dawn", mode: "light", bg: "#FAF4ED", accent: "#286983" },
];

export const DARK_THEMES: ReadonlyArray<ThemeDefinition> = [
  { id: "omp", name: "AIDesk Midnight", mode: "dark", bg: "#000000", accent: "#EC5BAB" },
  { id: "dark", name: "Dark", mode: "dark", bg: "#1B1916", accent: "#E07B54" },
  { id: "dracula", name: "Dracula", mode: "dark", bg: "#282A36", accent: "#FF79C6" },
  { id: "harbor", name: "Harbor", mode: "dark", bg: "#1B1B1B", accent: "#E75A50" },
  { id: "one-dark-pro", name: "One Dark Pro", mode: "dark", bg: "#282C34", accent: "#61AFEF" },
  { id: "rose-pine", name: "Rosé Pine", mode: "dark", bg: "#191724", accent: "#EBBCBA" },
  { id: "catppuccin-mocha", name: "Catppuccin Mocha", mode: "dark", bg: "#1E1E2E", accent: "#CBA6F7" },
  { id: "gruvbox-dark", name: "Gruvbox Dark", mode: "dark", bg: "#282828", accent: "#FE8019" },
  { id: "nord", name: "Nord", mode: "dark", bg: "#2E3440", accent: "#88C0D0" },
  { id: "tokyo-night", name: "Tokyo Night", mode: "dark", bg: "#1A1B26", accent: "#7AA2F7" },
];

export const ALL_THEMES: ReadonlyArray<ThemeDefinition> = [...LIGHT_THEMES, ...DARK_THEMES];

export function isDarkTheme(theme: Theme): boolean {
  return !LIGHT_THEMES.some((definition) => definition.id === theme);
}

const LIGHT_IDS: Record<string, true> = Object.fromEntries(LIGHT_THEMES.map((theme) => [theme.id, true]));
const DARK_IDS: Record<string, true> = Object.fromEntries(DARK_THEMES.map((theme) => [theme.id, true]));

const MODE_STORAGE_KEY = "omp-theme-mode";
const LIGHT_STORAGE_KEY = "omp-theme-light";
const DARK_STORAGE_KEY = "omp-theme-dark";

const DEFAULT_LIGHT_THEME: LightTheme = "catppuccin-latte";
const DEFAULT_DARK_THEME: DarkTheme = "dark";

export interface ThemeState {
  mode: ThemeMode;
  lightTheme: LightTheme;
  darkTheme: DarkTheme;
}

const DEFAULT_STATE: ThemeState = {
  mode: "auto",
  lightTheme: DEFAULT_LIGHT_THEME,
  darkTheme: DEFAULT_DARK_THEME,
};

const listeners = new Set<() => void>();

function readStoredState(): ThemeState {
  if (typeof window === "undefined") return DEFAULT_STATE;
  try {
    const mode = window.localStorage.getItem(MODE_STORAGE_KEY);
    const lightTheme = window.localStorage.getItem(LIGHT_STORAGE_KEY);
    const darkTheme = window.localStorage.getItem(DARK_STORAGE_KEY);
    return {
      mode: mode === "light" || mode === "dark" || mode === "auto" ? mode : DEFAULT_STATE.mode,
      lightTheme: lightTheme && LIGHT_IDS[lightTheme] ? (lightTheme as LightTheme) : DEFAULT_STATE.lightTheme,
      darkTheme: darkTheme && DARK_IDS[darkTheme] ? (darkTheme as DarkTheme) : DEFAULT_STATE.darkTheme,
    };
  } catch {
    return DEFAULT_STATE;
  }
}

let currentState: ThemeState = readStoredState();

function subscribe(cb: () => void): () => void {
  listeners.add(cb);
  return () => listeners.delete(cb);
}

function getSnapshot(): ThemeState {
  return currentState;
}

function getServerSnapshot(): ThemeState {
  return DEFAULT_STATE;
}

/** Resolve which concrete theme the current mode shows. `mode: "auto"` follows
 *  the OS color scheme, using the configured light or dark theme. */
export function resolveActiveTheme(state: ThemeState, prefersDark = false): Theme {
  if (state.mode === "light") return state.lightTheme;
  if (state.mode === "dark") return state.darkTheme;
  return prefersDark ? state.darkTheme : state.lightTheme;
}

export function applyDomTheme(theme: Theme): void {
  if (typeof document === "undefined") return;
  const dark = isDarkTheme(theme);
  const cl = document.documentElement.classList;
  const toRemove: string[] = [];
  cl.forEach((cls) => {
    if (cls.startsWith("theme-")) toRemove.push(cls);
  });
  toRemove.forEach((cls) => cl.remove(cls));

  cl.toggle("dark", dark && theme !== "omp");
  cl.toggle("omp", theme === "omp");
  if (theme !== "omp") {
    cl.add(`theme-${theme}`);
  }
  document.documentElement.setAttribute("data-theme", theme);
  const icon = document.querySelector('link[rel="icon"]');
  if (icon) icon.setAttribute("href", dark ? "/aidesk-logo-dark.svg" : "/aidesk-logo-light.svg");
  const color = ALL_THEMES.find((definition) => definition.id === theme)?.bg;
  const meta = document.querySelector('meta[name="theme-color"]');
  if (meta && color) meta.setAttribute("content", color);
}

function prefersDarkNow(): boolean {
  return typeof window !== "undefined" && window.matchMedia?.("(prefers-color-scheme: dark)").matches === true;
}

type ToggleOrigin = { x: number; y: number };

function motionDurationMs(variable: string, fallback: number): number {
  const raw = getComputedStyle(document.documentElement).getPropertyValue(variable).trim();
  if (raw.endsWith("ms")) {
    const value = Number.parseFloat(raw);
    return Number.isFinite(value) ? value : fallback;
  }
  if (raw.endsWith("s")) {
    const value = Number.parseFloat(raw);
    return Number.isFinite(value) ? value * 1000 : fallback;
  }
  return fallback;
}

/** Persist one field of the theme state, then notify every subscriber and
 *  apply the resolved theme to the document (inside a circular wipe when the
 *  browser supports view transitions). */
function updateThemeState(patch: Partial<ThemeState>, origin?: ToggleOrigin): void {
  const next: ThemeState = { ...currentState, ...patch };
  currentState = next;
  try {
    window.localStorage.setItem(MODE_STORAGE_KEY, next.mode);
    window.localStorage.setItem(LIGHT_STORAGE_KEY, next.lightTheme);
    window.localStorage.setItem(DARK_STORAGE_KEY, next.darkTheme);
  } catch {
    // Theme selection remains usable when storage is unavailable.
  }
  listeners.forEach((cb) => cb());

  const theme = resolveActiveTheme(next, prefersDarkNow());
  const reduceMotion = window.matchMedia?.("(prefers-reduced-motion: reduce)").matches;
  const supportsVT = typeof document.startViewTransition === "function";
  if (!supportsVT || reduceMotion) {
    applyDomTheme(theme);
    return;
  }

  const x = origin?.x ?? window.innerWidth / 2;
  const y = origin?.y ?? window.innerHeight / 2;
  const endRadius = Math.hypot(Math.max(x, window.innerWidth - x), Math.max(y, window.innerHeight - y));
  const transition = document.startViewTransition(() => applyDomTheme(theme));
  transition.ready.then(() => {
    const styles = getComputedStyle(document.documentElement);
    document.documentElement.animate({ clipPath: [`circle(0px at ${x}px ${y}px)`, `circle(${endRadius}px at ${x}px ${y}px)`] }, {
      duration: motionDurationMs("--dur-theme", 450),
      easing: styles.getPropertyValue("--ease-out-warm").trim() || "ease-out",
      pseudoElement: "::view-transition-new(root)",
    });
  }).catch(() => {});
  transition.finished?.catch(() => {});
}

export function useTheme() {
  const state = useSyncExternalStore(subscribe, getSnapshot, getServerSnapshot);
  // Browser-only state: the SPA renders client-side, so reading the OS scheme
  // during render avoids a second render pass.
  const [osDark, setOsDark] = useState(prefersDarkNow);

  useEffect(() => {
    if (typeof window === "undefined") return;
    const media = window.matchMedia("(prefers-color-scheme: dark)");
    const onChange = () => setOsDark(media.matches);
    media.addEventListener("change", onChange);
    return () => media.removeEventListener("change", onChange);
  }, []);

  const theme = resolveActiveTheme(state, osDark);

  // Keep the document in sync with the stored state and the OS scheme. The
  // pre-paint script in index.html already applied the same class, so this
  // only heals later changes.
  useEffect(() => {
    applyDomTheme(resolveActiveTheme(currentState, prefersDarkNow()));
  }, [state]);

  useEffect(() => {
    if (state.mode !== "auto") return;
    applyDomTheme(osDark ? state.darkTheme : state.lightTheme);
  }, [state.mode, state.darkTheme, state.lightTheme, osDark]);

  const setMode = useCallback((mode: ThemeMode, origin?: ToggleOrigin) => {
    updateThemeState({ mode }, origin);
  }, []);

  const setLightTheme = useCallback((lightTheme: LightTheme, origin?: ToggleOrigin) => {
    updateThemeState({ lightTheme }, origin);
  }, []);

  const setDarkTheme = useCallback((darkTheme: DarkTheme, origin?: ToggleOrigin) => {
    updateThemeState({ darkTheme }, origin);
  }, []);

  /** Back-compatible setter: `"system"` switches to auto; a concrete theme
   *  selects it in its own column and fixes the mode to that column. */
  const setTheme = useCallback((next: ThemePreference, origin?: ToggleOrigin) => {
    if (next === "system") {
      updateThemeState({ mode: "auto" }, origin);
    } else if (isDarkTheme(next)) {
      updateThemeState({ mode: "dark", darkTheme: next as DarkTheme }, origin);
    } else {
      updateThemeState({ mode: "light", lightTheme: next as LightTheme }, origin);
    }
  }, []);

  const toggleTheme = useCallback((origin?: ToggleOrigin) => {
    updateThemeState({ mode: isDarkTheme(theme) ? "light" : "dark" }, origin);
  }, [theme]);

  return {
    theme,
    mode: state.mode,
    lightTheme: state.lightTheme,
    darkTheme: state.darkTheme,
    isDark: isDarkTheme(theme),
    preference: (state.mode === "auto" ? "system" : theme) as ThemePreference,
    setMode,
    setLightTheme,
    setDarkTheme,
    setTheme,
    toggleTheme,
  };
}
