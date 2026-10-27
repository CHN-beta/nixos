// Side questions (omp's `/btw`) over RPC: record shapes and the pure state
// transitions applied to `btw_record`/`btw_delta` frames, `btw` responses and
// `get_btw_history` snapshots. These can arrive in any order relative to each
// other (SSE vs. HTTP), so a snapshot never rolls back what is already shown.

import { isRecord } from "./type-guards";

export type BtwStatus = "running" | "complete" | "cancelled" | "error" | "interrupted";

export interface BtwTurn {
  question: string;
  answer: string;
  status: BtwStatus;
  createdAt: number;
  updatedAt: number;
  error?: string;
}

export interface BtwRecord extends BtwTurn {
  id: string;
  leafId: string | null;
  followUps?: BtwTurn[];
}

const BTW_STATUSES: Record<BtwStatus, true> = { running: true, complete: true, cancelled: true, error: true, interrupted: true };

export function btwTurns(record: BtwRecord): BtwTurn[] {
  return [record, ...(record.followUps ?? [])];
}

export function latestBtwTurn(record: BtwRecord): BtwTurn {
  return record.followUps?.at(-1) ?? record;
}

/** What Copy copies: the newest answer with text. A follow-up that was
 * cancelled or failed before writing anything leaves the earlier answer
 * visible, so it stays copyable. */
export function latestBtwAnswer(record: BtwRecord): string {
  return btwTurns(record).findLast((turn) => turn.answer.trim())?.answer ?? "";
}

/** Epoch ms a `Date` can hold (omp's schema range); outside it `toISOString` throws. */
const MAX_DATE_MS = 8.64e15;

function isEpochMs(value: unknown): boolean {
  return typeof value === "number" && value >= 0 && value <= MAX_DATE_MS;
}

function isBtwTurn(value: unknown): value is BtwTurn {
  return isRecord(value)
    && typeof value.question === "string"
    && typeof value.answer === "string"
    && typeof value.status === "string" && Object.hasOwn(BTW_STATUSES, value.status)
    && isEpochMs(value.createdAt)
    && isEpochMs(value.updatedAt)
    && (value.error === undefined || typeof value.error === "string");
}

export function isBtwRecord(value: unknown): value is BtwRecord {
  return isRecord(value)
    && typeof value.id === "string"
    && (value.followUps === undefined || (Array.isArray(value.followUps) && value.followUps.every(isBtwTurn)))
    && isBtwTurn(value);
}

/** `incoming` is older than `current`: it misses a turn, reports a finished
 * turn as running, or lacks text that deltas already appended. */
function isStaleSnapshot(current: BtwRecord, incoming: BtwRecord): boolean {
  const have = current.followUps?.length ?? 0;
  const got = incoming.followUps?.length ?? 0;
  if (got !== have) return got < have;
  const mine = latestBtwTurn(current);
  const theirs = latestBtwTurn(incoming);
  if (theirs.status !== "running") return false;
  if (mine.status !== "running") return true;
  return mine.answer.length > theirs.answer.length && mine.answer.startsWith(theirs.answer);
}

function withLatestTurn(record: BtwRecord, patch: Partial<BtwTurn>): BtwRecord {
  const followUps = record.followUps;
  return followUps?.length
    ? { ...record, followUps: [...followUps.slice(0, -1), { ...followUps[followUps.length - 1], ...patch }] }
    : { ...record, ...patch };
}

/** omp's history order: newest topic first. */
function newestFirst(a: BtwRecord, b: BtwRecord): number {
  return b.createdAt - a.createdAt || (a.id < b.id ? -1 : a.id > b.id ? 1 : 0);
}

/** Insert (newest first) or replace a record unless the snapshot is stale. */
export function upsertBtwRecord(records: BtwRecord[], incoming: BtwRecord): BtwRecord[] {
  const index = records.findIndex((record) => record.id === incoming.id);
  if (index === -1) return [incoming, ...records];
  if (isStaleSnapshot(records[index], incoming)) return records;
  const next = records.slice();
  next[index] = incoming;
  return next;
}

/** Apply one SSE frame; unrelated or malformed frames leave `records` as is. */
export function applyBtwEvent(records: BtwRecord[], event: { type: string; [key: string]: unknown }): BtwRecord[] {
  if (event.type === "btw_record") {
    return isBtwRecord(event.record) ? upsertBtwRecord(records, event.record) : records;
  }
  if (event.type !== "btw_delta" || typeof event.recordId !== "string" || typeof event.delta !== "string" || !event.delta) {
    return records;
  }
  // Streamed text extends the latest turn of a running record only.
  const index = records.findIndex((record) => record.id === event.recordId);
  if (index === -1) return records;
  const latest = latestBtwTurn(records[index]);
  if (latest.status !== "running") return records;
  const next = records.slice();
  next[index] = withLatestTurn(records[index], { answer: latest.answer + event.delta });
  return next;
}

/** Replace local state with a history snapshot, keeping records the snapshot
 * predates (started after it was taken, or with newer streamed text). A record
 * that was running before the request (`knownBefore`) but is missing from the
 * snapshot cannot still be running: omp lost it (failed checkpoint, replaced
 * child), so it becomes `interrupted` instead of spinning forever. */
export function mergeBtwHistory(local: BtwRecord[], snapshot: BtwRecord[], knownBefore: ReadonlySet<string>): BtwRecord[] {
  const localById = new Map(local.map((record) => [record.id, record]));
  const snapshotIds = new Set(snapshot.map((record) => record.id));
  const merged = snapshot.map((record) => {
    const mine = localById.get(record.id);
    return mine && isStaleSnapshot(mine, record) ? mine : record;
  });
  for (const record of local) {
    if (snapshotIds.has(record.id)) continue;
    const lost = knownBefore.has(record.id) && latestBtwTurn(record).status === "running";
    merged.push(lost ? withLatestTurn(record, { status: "interrupted" }) : record);
  }
  return merged.sort(newestFirst);
}
