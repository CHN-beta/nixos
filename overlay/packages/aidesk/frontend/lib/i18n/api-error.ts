import { translate } from "./index";

/**
 * Client-side rendering of API error payloads. Routes attach a stable `code`
 * to well-known failures; the dictionary maps `errors.<code>` to a localized
 * message. Unknown or dynamic errors fall back to the server's English text.
 */
export interface ApiErrorPayload {
  error?: string;
  code?: string;
}

export function formatApiError(
  payload: ApiErrorPayload | string | null | undefined,
  fallbackKey = "errors.generic",
): string {
  if (typeof payload === "string") return payload;
  const code = payload?.code;
  if (code) {
    const key = `errors.${code}`;
    const localized = translate(key);
    if (localized !== key) return localized;
  }
  if (payload?.error) return payload.error;
  const fallback = translate(fallbackKey);
  return fallback === fallbackKey ? "Request failed" : fallback;
}
