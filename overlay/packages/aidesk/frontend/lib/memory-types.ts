/**
 * Hindsight memory graph shapes.
 *
 * Mirrors the `aidesk-backend` `/api/memories/*` contract 1:1. The literal
 * unions below are descriptive; payloads from older backends may carry other
 * values, so consumers must treat the string fields as open-ended.
 */

export type MemoryFactKind = "world" | "experience" | "observation";
export type MemorySearchMode = "text" | "meaning";
export type MemoryLinkKind = "semantic" | "temporal" | "entity" | "causal";

export interface MemoryGraphNodeData {
  id: string;
  label: string;
  text: string;
  date?: string;
  context?: string;
  entities?: string;
  factType?: MemoryFactKind | string | null;
  tags?: string[];
  color?: string;
}

export interface MemoryGraphNode {
  data: MemoryGraphNodeData;
}

export interface MemoryGraphEdgeData {
  id: string;
  source: string;
  target: string;
  linkType?: MemoryLinkKind | string;
  weight?: number;
  entityName?: string;
  color?: string;
  lineStyle?: string;
}

export interface MemoryGraphEdge {
  data: MemoryGraphEdgeData;
}

export interface MemoryTableRow {
  id: string;
  text: string;
  context?: string;
  date?: string | null;
  occurred_start?: string | null;
  occurred_end?: string | null;
  mentioned_at?: string | null;
  entities?: string;
  fact_type?: MemoryFactKind | null;
  tags?: string[];
  proof_count?: number | null;
}

export interface MemoryGraphResponse {
  configured: boolean;
  bankId: string;
  total_units: number;
  limit: number;
  nodes: MemoryGraphNode[];
  edges: MemoryGraphEdge[];
  table_rows: MemoryTableRow[];
  error?: string;
}

export interface MemorySearchItem {
  id: string;
  text: string;
  context?: string;
  fact_type?: MemoryFactKind | string | null;
  entities?: string[];
  tags?: string[];
  date?: string | null;
  occurred_start?: string | null;
  occurred_end?: string | null;
  mentioned_at?: string | null;
  document_id?: string | null;
  chunk_id?: string | null;
  proof_count?: number | null;
  score: number;
}

export interface MemorySearchResponse {
  mode: MemorySearchMode;
  query: string;
  total: number;
  items: MemorySearchItem[];
  nodes: MemoryGraphNode[];
  edges: MemoryGraphEdge[];
}

export interface MemorySourceMemory {
  id: string;
  text: string;
  type?: string;
  context?: string;
  occurred_start?: string | null;
  mentioned_at?: string | null;
}

export interface MemoryDetail {
  id: string;
  text: string;
  context?: string;
  date?: string;
  type?: MemoryFactKind | string;
  fact_type?: MemoryFactKind | string;
  state?: "valid" | "invalidated" | string;
  invalidated_at?: string | null;
  invalidation_reason?: string | null;
  edited_at?: string | null;
  consolidated_at?: string | null;
  occurred_start?: string | null;
  occurred_end?: string | null;
  mentioned_at?: string | null;
  document_id?: string | null;
  chunk_id?: string | null;
  entities?: string[];
  tags?: string[];
  metadata?: Record<string, unknown>;
  source_memory_ids?: string[];
  source_memories?: MemorySourceMemory[];
}

export interface MemorySearchRequest {
  query: string;
  mode: MemorySearchMode;
  type?: MemoryFactKind;
  limit?: number;
}

/** Curated fields for `PATCH /api/memories/{id}`. */
export interface MemoryEditPatch {
  text: string;
  context?: string | null;
  fact_type?: "world" | "experience";
  occurred_start?: string | null;
  occurred_end?: string | null;
  mentioned_at?: string | null;
  entities?: string[];
  resolve_entities?: false;
}

export interface MemoryStatePatch {
  state: "invalidated" | "valid";
  reason?: string;
}

export type MemoryPatch = MemoryEditPatch | MemoryStatePatch;

/** Graph nodes use `factType`, detail rows use `fact_type`; normalize once. */
export function memoryFactKind(value: unknown): MemoryFactKind | null {
  return value === "world" || value === "experience" || value === "observation" ? value : null;
}

/** First line / clipped preview used by labels, list rows, and neighbours. */
export function memoryPreview(text: string, limit = 96): string {
  const flat = text.replace(/\s+/g, " ").trim();
  if (flat.length <= limit) return flat;
  return `${flat.slice(0, limit - 1).trimEnd()}…`;
}
