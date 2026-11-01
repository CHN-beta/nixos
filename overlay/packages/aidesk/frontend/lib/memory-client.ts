import { apiUrl } from "./api-origin";
import { isRecord } from "./type-guards";
import type {
  MemoryDetail,
  MemoryEditPatch,
  MemoryFactKind,
  MemoryGraphEdge,
  MemoryGraphNode,
  MemoryGraphResponse,
  MemoryPatch,
  MemorySearchItem,
  MemorySearchRequest,
  MemorySearchResponse,
  MemorySourceMemory,
  MemoryTableRow,
} from "./memory-types";

/** Loads the whole (bounded) graph for a bank. `limit` caps unit count. */
export async function fetchMemoryGraph(
  options: { limit?: number; type?: MemoryFactKind } = {},
): Promise<MemoryGraphResponse> {
  const params = new URLSearchParams({ limit: String(options.limit ?? 1000) });
  if (options.type) params.set("type", options.type);
  const body = await requestJson<unknown>(`/api/memories/graph?${params.toString()}`);
  return normalizeGraph(body);
}

/** Text search (FTS) or semantic recall, depending on `mode`. */
export async function searchMemories(request: MemorySearchRequest): Promise<MemorySearchResponse> {
  const body = await requestJson<unknown>("/api/memories/search", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      query: request.query,
      mode: request.mode,
      ...(request.type ? { type: request.type } : {}),
      ...(request.limit ? { limit: request.limit } : {}),
    }),
  });
  const record = isRecord(body) ? body : {};
  const items = Array.isArray(record.items) ? record.items.map(normalizeSearchItem).filter(isPresent) : [];
  return {
    mode: record.mode === "meaning" ? "meaning" : "text",
    query: typeof record.query === "string" ? record.query : request.query,
    total: typeof record.total === "number" ? record.total : items.length,
    items,
    nodes: Array.isArray(record.nodes) ? record.nodes.map(normalizeGraphNode).filter(isPresent) : [],
    edges: Array.isArray(record.edges) ? record.edges.map(normalizeGraphEdge).filter(isPresent) : [],
  };
}

export async function fetchMemoryDetail(id: string): Promise<MemoryDetail> {
  const body = await requestJson<unknown>(`/api/memories/${encodeURIComponent(id)}`);
  return normalizeDetail(body, id);
}

/** Curate a memory: edit fields, invalidate it, or restore it. */
export async function patchMemory(id: string, patch: MemoryPatch): Promise<MemoryDetail> {
  const body = await requestJson<unknown>(`/api/memories/${encodeURIComponent(id)}`, {
    method: "PATCH",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(patch),
  });
  return normalizeDetail(body, id);
}

export function buildEditPatch(input: {
  text: string;
  context: string;
  factType: "world" | "experience";
  entities: string[];
  occurredStart: string;
  occurredEnd: string;
  mentionedAt: string;
}): MemoryEditPatch {
  return {
    text: input.text,
    context: input.context.trim() ? input.context.trim() : null,
    fact_type: input.factType,
    occurred_start: input.occurredStart || null,
    occurred_end: input.occurredEnd || null,
    mentioned_at: input.mentionedAt || null,
    entities: input.entities,
    resolve_entities: false,
  };
}

async function requestJson<T>(path: string, init?: RequestInit): Promise<T> {
  const response = await fetch(apiUrl(path), { credentials: "include", ...init });
  const payload: unknown = await response.json().catch(() => null);
  if (!response.ok) {
    const message =
      isRecord(payload) && typeof payload.error === "string" && payload.error.trim()
        ? payload.error.trim()
        : `HTTP ${response.status}`;
    throw new Error(message);
  }
  return payload as T;
}

function isPresent<T>(value: T | null): value is T {
  return value !== null;
}

function optionalString(value: unknown): string | undefined {
  return typeof value === "string" && value.length > 0 ? value : undefined;
}

function optionalNullableString(value: unknown): string | null | undefined {
  if (value === null) return null;
  return typeof value === "string" && value.length > 0 ? value : undefined;
}

function stringArray(value: unknown): string[] | undefined {
  if (!Array.isArray(value)) return undefined;
  const items = value.filter((entry): entry is string => typeof entry === "string" && entry.length > 0);
  return items.length > 0 ? items : undefined;
}

function normalizeGraphNode(raw: unknown): MemoryGraphNode | null {
  if (!isRecord(raw)) return null;
  const data = isRecord(raw.data) ? raw.data : raw;
  const id = optionalString(data.id);
  if (!id) return null;
  const text = typeof data.text === "string" ? data.text : "";
  const label = optionalString(data.label) ?? text.slice(0, 80);
  return {
    data: {
      id,
      label,
      text,
      date: optionalString(data.date),
      context: optionalString(data.context),
      entities: optionalString(data.entities),
      factType: optionalString(data.factType) ?? optionalString(data.fact_type) ?? null,
      tags: stringArray(data.tags),
      color: optionalString(data.color),
    },
  };
}

function normalizeGraphEdge(raw: unknown): MemoryGraphEdge | null {
  if (!isRecord(raw)) return null;
  const data = isRecord(raw.data) ? raw.data : raw;
  const source = optionalString(data.source);
  const target = optionalString(data.target);
  if (!source || !target) return null;
  const id = optionalString(data.id) ?? `${source}->${target}`;
  return {
    data: {
      id,
      source,
      target,
      linkType: optionalString(data.linkType),
      weight: typeof data.weight === "number" && Number.isFinite(data.weight) ? data.weight : undefined,
      entityName: optionalString(data.entityName),
      color: optionalString(data.color),
      lineStyle: optionalString(data.lineStyle),
    },
  };
}

function normalizeTableRow(raw: unknown): MemoryTableRow | null {
  if (!isRecord(raw)) return null;
  const id = optionalString(raw.id);
  if (!id) return null;
  return {
    id,
    text: typeof raw.text === "string" ? raw.text : "",
    context: optionalString(raw.context),
    date: optionalNullableString(raw.date),
    occurred_start: optionalNullableString(raw.occurred_start),
    occurred_end: optionalNullableString(raw.occurred_end),
    mentioned_at: optionalNullableString(raw.mentioned_at),
    entities: optionalString(raw.entities),
    fact_type: raw.fact_type === "world" || raw.fact_type === "experience" || raw.fact_type === "observation" ? raw.fact_type : null,
    tags: stringArray(raw.tags),
    proof_count: typeof raw.proof_count === "number" && Number.isFinite(raw.proof_count) ? raw.proof_count : null,
  };
}

function normalizeGraph(raw: unknown): MemoryGraphResponse {
  const record = isRecord(raw) ? raw : {};
  const nodes = Array.isArray(record.nodes) ? record.nodes.map(normalizeGraphNode).filter(isPresent) : [];
  const edges = Array.isArray(record.edges) ? record.edges.map(normalizeGraphEdge).filter(isPresent) : [];
  return {
    configured: record.configured === true,
    bankId: typeof record.bankId === "string" ? record.bankId : "",
    total_units: typeof record.total_units === "number" ? record.total_units : nodes.length,
    limit: typeof record.limit === "number" ? record.limit : nodes.length,
    nodes,
    edges,
    table_rows: Array.isArray(record.table_rows) ? record.table_rows.map(normalizeTableRow).filter(isPresent) : [],
    error: optionalString(record.error),
  };
}

function normalizeSearchItem(raw: unknown): MemorySearchItem | null {
  if (!isRecord(raw)) return null;
  const id = optionalString(raw.id);
  if (!id) return null;
  const score = typeof raw.score === "number" && Number.isFinite(raw.score) ? raw.score : 0;
  return {
    id,
    text: typeof raw.text === "string" ? raw.text : "",
    context: optionalString(raw.context),
    fact_type: optionalString(raw.fact_type) ?? null,
    entities: stringArray(raw.entities),
    tags: stringArray(raw.tags),
    date: optionalNullableString(raw.date),
    occurred_start: optionalNullableString(raw.occurred_start),
    occurred_end: optionalNullableString(raw.occurred_end),
    mentioned_at: optionalNullableString(raw.mentioned_at),
    document_id: optionalNullableString(raw.document_id),
    chunk_id: optionalNullableString(raw.chunk_id),
    proof_count: typeof raw.proof_count === "number" && Number.isFinite(raw.proof_count) ? raw.proof_count : null,
    score,
  };
}

function normalizeSourceMemory(raw: unknown): MemorySourceMemory | null {
  if (!isRecord(raw)) return null;
  const id = optionalString(raw.id);
  if (!id) return null;
  return {
    id,
    text: typeof raw.text === "string" ? raw.text : "",
    type: optionalString(raw.type),
    context: optionalString(raw.context),
    occurred_start: optionalNullableString(raw.occurred_start),
    mentioned_at: optionalNullableString(raw.mentioned_at),
  };
}

function normalizeDetail(raw: unknown, fallbackId: string): MemoryDetail {
  const record = isRecord(raw) ? raw : {};
  const wrapper: Record<string, unknown> = isRecord(record.memory) ? record : {};
  const detail = isRecord(record.memory) ? record.memory : record;
  const sourceMemories = Array.isArray(detail.source_memories)
    ? detail.source_memories
    : Array.isArray(wrapper.source_memories)
      ? wrapper.source_memories
      : undefined;
  return {
    id: optionalString(detail.id) ?? fallbackId,
    text: typeof detail.text === "string" ? detail.text : "",
    context: optionalString(detail.context),
    date: optionalString(detail.date),
    type: optionalString(detail.type),
    fact_type: optionalString(detail.fact_type),
    state: optionalString(detail.state),
    invalidated_at: optionalNullableString(detail.invalidated_at),
    invalidation_reason: optionalNullableString(detail.invalidation_reason),
    edited_at: optionalNullableString(detail.edited_at),
    consolidated_at: optionalNullableString(detail.consolidated_at),
    occurred_start: optionalNullableString(detail.occurred_start),
    occurred_end: optionalNullableString(detail.occurred_end),
    mentioned_at: optionalNullableString(detail.mentioned_at),
    document_id: optionalNullableString(detail.document_id),
    chunk_id: optionalNullableString(detail.chunk_id),
    entities: stringArray(detail.entities),
    tags: stringArray(detail.tags),
    metadata: isRecord(detail.metadata) ? detail.metadata : undefined,
    source_memory_ids: stringArray(detail.source_memory_ids) ?? stringArray(wrapper.source_memory_ids),
    source_memories: sourceMemories ? sourceMemories.map(normalizeSourceMemory).filter(isPresent) : undefined,
  };
}
