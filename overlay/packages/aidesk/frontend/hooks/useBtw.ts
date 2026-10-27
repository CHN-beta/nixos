import { useCallback, useEffect, useRef, useState, type RefObject } from "react";
import { toast } from "@/components/ui/toast";
import { sendAgentCommand } from "@/lib/agent-client";
import { translate } from "@/lib/i18n";
import { applyBtwEvent, isBtwRecord, latestBtwTurn, mergeBtwHistory, upsertBtwRecord, type BtwRecord } from "@/lib/btw";
import { scheduleAtDisplayRate } from "@/lib/message-update-coalescer";
import { UNSUPPORTED_RETRY_MS } from "@/hooks/useWordPrediction";

/** omp's `btw` failure when a Cancel (or session change) beat its first checkpoint. */
const CANCELLED_BEFORE_START = "cancelled before it started";

// An omp without the btw commands answers "Unknown command": background
// history refreshes pause instead of failing on every SSE connect.
let unsupportedUntil = 0;

/** An omp without the btw RPC commands gets an upgrade hint, not its raw error. */
export function toastBtwError(error: unknown): void {
  const message = error instanceof Error ? error.message : String(error);
  if (message.includes("Unknown command")) toast.error(translate("btw.unsupported"));
  else toast.error(translate("btw.failed"), message);
}

type BtwFrame = { type: string; [key: string]: unknown };

/** Side questions (omp `/btw`) for one chat: the session's BTW history fed by
 * `btw_record`/`btw_delta` frames, the record shown in the composer panel, and
 * the history dialog. Never touches the main transcript. */
export function useBtw(sessionIdRef: RefObject<string | null>) {
  const [records, setRecords] = useState<BtwRecord[]>([]);
  // Synchronous mirror of `records`: what this tab already knows decides
  // auto-opening and which running records a history snapshot may interrupt.
  const recordsRef = useRef<BtwRecord[]>([]);
  const [activeId, setActiveId] = useState<string | null>(null);
  const [historyOpen, setHistoryOpen] = useState(false);
  // Deltas arrive at token rate; apply them at display rate (hidden-tab safe).
  const pendingFramesRef = useRef<BtwFrame[]>([]);
  const cancelFlushRef = useRef<(() => void) | null>(null);
  useEffect(() => () => cancelFlushRef.current?.(), []);

  const commit = useCallback((update: (prev: BtwRecord[]) => BtwRecord[]) => {
    const next = update(recordsRef.current);
    if (next === recordsRef.current) return;
    recordsRef.current = next;
    setRecords(next);
  }, []);

  const flushFrames = useCallback(() => {
    cancelFlushRef.current?.();
    cancelFlushRef.current = null;
    const frames = pendingFramesRef.current;
    if (frames.length === 0) return;
    pendingFramesRef.current = [];
    const known = new Set(recordsRef.current.map((record) => record.id));
    commit((prev) => frames.reduce(applyBtwEvent, prev));
    // A side question started elsewhere (another tab) opens the panel; a
    // topic this tab already knows never reopens a panel the user closed.
    const started = frames.map((frame) => frame.record)
      .findLast((record): record is BtwRecord => isBtwRecord(record) && latestBtwTurn(record).status === "running" && !known.has(record.id));
    if (started) setActiveId(started.id);
  }, [commit]);

  const applyEvent = useCallback((event: BtwFrame) => {
    pendingFramesRef.current.push(event);
    cancelFlushRef.current ??= scheduleAtDisplayRate(flushFrames);
  }, [flushFrames]);

  /** Merge omp's history. Background refreshes (SSE open, reconcile, a no-op
   * cancel) stay silent: the route never starts omp for them, and an omp
   * without the commands is not asked again for a while. */
  const refreshHistory = useCallback(async (sid: string, explicit = false) => {
    if (!explicit && Date.now() < unsupportedUntil) return;
    const knownBefore = new Set(recordsRef.current.map((record) => record.id));
    try {
      const data = await sendAgentCommand<{ records?: unknown[] } | null>(sid, { type: "get_btw_history" });
      unsupportedUntil = 0;
      if (sessionIdRef.current !== sid) return;
      const snapshot = (data?.records ?? []).filter(isBtwRecord);
      // Frames already received go first: the staleness rules then keep
      // whichever of them and the snapshot is newer. Applied after it, deltas
      // the snapshot already holds would be appended twice.
      flushFrames();
      const known = new Set(recordsRef.current.map((record) => record.id));
      commit((prev) => mergeBtwHistory(prev, snapshot, knownBefore));
      const running = snapshot.find((record) => latestBtwTurn(record).status === "running" && !known.has(record.id));
      if (running) setActiveId((id) => id ?? running.id);
    } catch (error) {
      if (error instanceof Error && error.message.includes("Unknown command")) unsupportedUntil = Date.now() + UNSUPPORTED_RETRY_MS;
      if (explicit) toastBtwError(error);
    }
  }, [commit, flushFrames, sessionIdRef]);

  /** Half-open SSE recovery: re-read the history while an answer is still running. */
  const reconcile = useCallback((sid: string) => {
    if (recordsRef.current.some((record) => latestBtwTurn(record).status === "running")) void refreshHistory(sid);
  }, [refreshHistory]);

  /** `/btw` alone: the history dialog. Unlike background reads, this starts omp. */
  const openHistory = useCallback(async (sid: string) => {
    setHistoryOpen(true);
    try {
      await sendAgentCommand(sid, { type: "get_state" });
    } catch (error) {
      toastBtwError(error);
      return;
    }
    await refreshHistory(sid, true);
  }, [refreshHistory]);

  /** Resolves once omp accepted the question (true), or it was cancelled
   * before it started (false: the user's own Cancel, which its `btw_record`
   * already shows). The answer streams via frames. Throws on refusal. */
  const ask = useCallback(async (sid: string, question: string, recordId?: string): Promise<boolean> => {
    let data: { record?: unknown } | null;
    try {
      data = await sendAgentCommand<{ record?: unknown } | null>(sid, { type: "btw", question, ...(recordId ? { recordId } : {}) });
    } catch (error) {
      if (error instanceof Error && error.message.includes(CANCELLED_BEFORE_START)) return false;
      throw error;
    }
    const record = data?.record;
    if (sessionIdRef.current !== sid || !isBtwRecord(record)) return true;
    // The start state: never newer than frames, so upsert keeps streamed text.
    commit((prev) => upsertBtwRecord(prev, record));
    setActiveId(record.id);
    return true;
  }, [commit, sessionIdRef]);

  const cancel = useCallback(async (recordId: string) => {
    const sid = sessionIdRef.current;
    if (!sid) return;
    try {
      const data = await sendAgentCommand<{ cancelled?: boolean } | null>(sid, { type: "btw_cancel", recordId });
      // Nothing was running: the shown state is stale (missed frame, lost child).
      if (data?.cancelled === false) await refreshHistory(sid);
    } catch (error) {
      toastBtwError(error);
    }
  }, [refreshHistory, sessionIdRef]);

  return { records, activeId, setActiveId, historyOpen, setHistoryOpen, applyEvent, reconcile, refreshHistory, openHistory, ask, cancel };
}
