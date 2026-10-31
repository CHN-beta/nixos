// Client-side helper for POST /api/agent/[id].
//
// Every /api/agent/[id] route returns one of:
//   { success: true, data: <result> }
//   { error: string }              (non-2xx)
//
// Call sites previously repeated the same 5-line fetch block 13× in
// hooks/useAgentSession.ts. This helper collapses that down to one line.

import { formatApiError } from "@/lib/i18n/api-error";
import { translate } from "@/lib/i18n";

// A command POST that never settles (lost Wi-Fi, hung RPC child, proxy that
// keeps the socket open) used to hang the caller forever — the send path then
// never cleared its "dispatching" state and the composer stayed in
// "generating". Bound it; callers roll back through their normal failure arm.
export const AGENT_COMMAND_TIMEOUT_MS = 20_000;

/** A command POST that hit {@link AGENT_COMMAND_TIMEOUT_MS}. Callers treat it
 *  like any other failure, but the outcome on the server is unknown. */
export class AgentCommandTimeoutError extends Error {
  readonly timeoutMs: number;

  constructor(timeoutMs: number) {
    super(translate("agentClient.timeout", { seconds: Math.round(timeoutMs / 1000) }));
    this.name = "AgentCommandTimeoutError";
    this.timeoutMs = timeoutMs;
  }
}

// Sessions whose per-chat advisor toggle is on: their lazily spawned omp
// process must start with --advisor. Keyed by session id because the spawn
// decision happens inside the route, which only sees id + query string.
const advisorSpawnSessions = new Set<string>();

export function setSessionAdvisorSpawn(sessionId: string, enabled: boolean) {
  if (enabled) advisorSpawnSessions.add(sessionId);
  else advisorSpawnSessions.delete(sessionId);
}

export interface SendAgentCommandOptions {
  /** Override the request bound for commands known to run longer. */
  timeoutMs?: number;
}

export async function sendAgentCommand<T = unknown>(
  sessionId: string,
  command: Record<string, unknown>,
  options: SendAgentCommandOptions = {},
): Promise<T> {
  const timeoutMs = options.timeoutMs ?? AGENT_COMMAND_TIMEOUT_MS;
  const query = advisorSpawnSessions.has(sessionId) ? "?advisor=1" : "";
  let res: Response;
  try {
    res = await fetch(`/api/agent/${encodeURIComponent(sessionId)}${query}`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(command),
      signal: AbortSignal.timeout(timeoutMs),
    });
  } catch (error) {
    if (error instanceof DOMException && error.name === "TimeoutError") {
      throw new AgentCommandTimeoutError(timeoutMs);
    }
    throw error;
  }
  const body = (await res.json().catch(() => ({}))) as {
    success?: boolean;
    data?: T;
    error?: string;
    code?: string;
  };
  if (!res.ok || body.error) {
    // Routes attach a stable `code` for well-known failures; these messages are
    // surfaced to the user as notices, so localize before throwing.
    throw new Error(
      body.error || body.code ? formatApiError(body) : `HTTP ${res.status}`,
    );
  }
  return body.data as T;
}
