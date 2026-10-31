/**
 * Reconnect loop for read-only `EventSource` streams.
 *
 * The browser retries a lost connection itself (readyState CONNECTING), but a
 * non-200 response (404/409/500) or a content-type mismatch fails the stream
 * permanently: `readyState` becomes CLOSED and no further events ever arrive.
 * Without a manual loop those panels silently freeze until a page reload.
 *
 * This helper owns one EventSource at a time, rebuilds it with capped
 * exponential backoff after a CLOSED stream, and reconnects immediately when
 * the network comes back.
 */

/** 1s → 2s → 5s → 10s → 20s → 30s (capped). */
export const SSE_RETRY_DELAYS_MS: readonly number[] = [1_000, 2_000, 5_000, 10_000, 20_000, 30_000];

export interface SseReconnectHandlers {
  /** URL for each attempt: reconnects may need fresh query parameters. */
  url: () => string;
  /** Attach per-connection listeners (named events, onmessage) here. The
   *  helper owns `onopen`/`onerror`, so this must not overwrite them. */
  setup?: (source: EventSource) => void;
  /** Fired whenever a connection opens (including reconnects). */
  onOpen?: (source: EventSource) => void;
  /** Fired for every `error` event. `closed` is true when the browser gave up
   *  and the helper scheduled a manual reconnect instead. */
  onError?: (closed: boolean, source: EventSource) => void;
  /** Return false to stop the loop for good (finished process, unmounted view
   *  state that no retry can fix). Checked before each scheduled attempt. */
  shouldReconnect?: () => boolean;
  /** Fired when a retry has been scheduled (for "reconnecting" affordances). */
  onRetry?: (delayMs: number) => void;
  retryDelays?: readonly number[];
}

export interface SseReconnectHandle {
  /** The live EventSource, or null while waiting for the next attempt. */
  readonly source: EventSource | null;
  /** Reconnect right now, discarding the pending backoff (online event). */
  reconnect(): void;
  /** Stop the loop and close the stream. Idempotent. */
  close(): void;
}

export function connectSse(handlers: SseReconnectHandlers): SseReconnectHandle {
  const delays = handlers.retryDelays ?? SSE_RETRY_DELAYS_MS;
  let source: EventSource | null = null;
  let retryTimer: ReturnType<typeof setTimeout> | null = null;
  let attempt = 0;
  let stopped = false;

  const clearRetry = () => {
    if (retryTimer !== null) {
      clearTimeout(retryTimer);
      retryTimer = null;
    }
  };

  const scheduleRetry = () => {
    if (stopped || retryTimer !== null) return;
    if (handlers.shouldReconnect && !handlers.shouldReconnect()) return;
    const delay = delays[Math.min(attempt, delays.length - 1)] ?? 0;
    attempt += 1;
    handlers.onRetry?.(delay);
    retryTimer = setTimeout(() => {
      retryTimer = null;
      open();
    }, delay);
  };

  function open() {
    if (stopped) return;
    clearRetry();
    if (source) {
      source.close();
      source = null;
    }
    const next = new EventSource(handlers.url());
    source = next;
    next.onopen = () => {
      if (stopped || source !== next) return;
      // A healthy open proves the endpoint and the network: restart the ladder.
      attempt = 0;
      handlers.onOpen?.(next);
    };
    next.onerror = () => {
      if (stopped || source !== next) return;
      const closed = next.readyState === EventSource.CLOSED;
      handlers.onError?.(closed, next);
      // CONNECTING means the browser is already retrying; a second loop would
      // race it. CLOSED never comes back on its own.
      if (!closed) return;
      next.close();
      if (source === next) source = null;
      scheduleRetry();
    };
    handlers.setup?.(next);
  }

  const onOnline = () => {
    if (stopped) return;
    attempt = 0;
    open();
  };

  if (typeof window !== "undefined") window.addEventListener("online", onOnline);
  open();

  return {
    get source() {
      return source;
    },
    reconnect() {
      if (stopped) return;
      attempt = 0;
      open();
    },
    close() {
      if (stopped) return;
      stopped = true;
      clearRetry();
      if (typeof window !== "undefined") window.removeEventListener("online", onOnline);
      source?.close();
      source = null;
    },
  };
}
