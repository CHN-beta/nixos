/**
 * Where the API lives, relative to the static SPA.
 *
 * The SPA is deployed on `aidesk.chn.moe` (public, unauthenticated), while the
 * API is `api.aidesk.chn.moe` (Authelia-protected, per-user backends). Vite
 * still serves both from one origin in dev, so relative `/api/...` URLs stay
 * the default there.
 *
 * Resolution order:
 * 1. `VITE_API_ORIGIN` — explicit configuration for any other split deployment;
 * 2. the production hostname table below;
 * 3. `""` — same origin (dev server, `vite preview`, LAN tests).
 *
 * `VITE_AUTH_URL` overrides the Authelia origin used for the 401 redirect.
 */

const PRODUCTION_API_ORIGINS: Record<string, string> = {
  "aidesk.chn.moe": "https://api.aidesk.chn.moe",
};

const declaredApiOrigin = import.meta.env.VITE_API_ORIGIN?.trim().replace(/\/+$/, "") || null;
const declaredAuthUrl = import.meta.env.VITE_AUTH_URL?.trim().replace(/\/+$/, "") || null;

export const apiOrigin: string =
  declaredApiOrigin ??
  (typeof window === "undefined" ? null : (PRODUCTION_API_ORIGINS[window.location.hostname] ?? null)) ??
  "";

export const authUrl: string = declaredAuthUrl ?? "https://auth.chn.moe";

/**
 * Absolute URL for an absolute path. Data/blob/external URLs pass through, and
 * with an empty origin (single-origin dev) the path is returned unchanged.
 * Use this for URLs the app does not navigate through `fetch`/`EventSource`:
 * `<img src>`, `<a href>`, `<audio src>`, iframes, `window.open`.
 */
export function apiUrl(path: string): string {
  if (!path.startsWith("/") || path.startsWith("//")) return path;
  return apiOrigin ? `${apiOrigin}${path}` : path;
}

/** The `/api/...` path a URL targets, or null when the URL is not API traffic. */
function apiPath(url: string): string | null {
  if (url.startsWith("/") && !url.startsWith("//")) {
    return url.startsWith("/api/") ? url : null;
  }
  try {
    const target = new URL(url, window.location.href);
    const origin = apiOrigin ? new URL(apiOrigin).origin : window.location.origin;
    if (target.origin !== origin || !target.pathname.startsWith("/api/")) return null;
    return target.pathname + target.search + target.hash;
  } catch {
    return null;
  }
}

let redirectingToAuth = false;

/**
 * The API answers `401` instead of redirecting (a redirect would turn into an
 * opaque CORS failure for `fetch`). Send the top-level window to Authelia
 * ourselves, remembering where to come back to. Concurrent failures share one
 * redirect; callers that do not go through the patched `fetch` (XHR uploads)
 * call this directly.
 */
export function redirectToAuth(): void {
  if (redirectingToAuth) return;
  redirectingToAuth = true;
  window.location.replace(`${authUrl}/?rd=${encodeURIComponent(window.location.href)}`);
}

/** Set once the globals are patched; re-installing would wrap our own wrappers. */
let installed = false;

/**
 * Route every `/api/...` request to the API origin, send cookies, and turn an
 * unauthenticated `401` into the Authelia redirect. Installed before React
 * renders so no component can accidentally bind an API call to the static
 * origin or forget `credentials: "include"` / `withCredentials: true`.
 */
export function installApiTransport(): void {
  if (installed || typeof window === "undefined") return;
  installed = true;

  const nativeFetch = window.fetch.bind(window);
  window.fetch = (input: RequestInfo | URL, init?: RequestInit): Promise<Response> => {
    const url = typeof input === "string" ? input : input instanceof URL ? input.href : input.url;
    if (apiPath(url) === null) return nativeFetch(input, init);
    const requestInit: RequestInit = { ...init, credentials: "include" };
    const target = typeof input === "string" || input instanceof URL ? apiUrl(url) : new Request(apiUrl(url), input);
    return nativeFetch(target, requestInit).then((response) => {
      if (response.status === 401) redirectToAuth();
      return response;
    });
  };

  const NativeEventSource = window.EventSource;
  window.EventSource = class extends NativeEventSource {
    constructor(url: string | URL, init?: EventSourceInit) {
      const href = typeof url === "string" ? url : url.href;
      const isApi = apiPath(href) !== null;
      super(isApi ? apiUrl(href) : href, isApi ? { ...init, withCredentials: true } : init);
    }
  };
}
