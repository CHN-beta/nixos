import { useCallback, useEffect, useMemo, useRef, useState, type CSSProperties, type ReactNode } from "react";
import {
  Ban,
  Brain,
  Check,
  ChevronRight,
  Loader2,
  Maximize2,
  Pause,
  Pencil,
  Play,
  RefreshCw,
  RotateCcw,
  Search,
  X,
} from "lucide-react";
import { useI18n } from "@/lib/i18n";
import { usePrefersReducedMotion } from "@/hooks/usePrefersReducedMotion";
import { toast } from "@/components/ui/toast";
import {
  buildEditPatch,
  fetchMemoryDetail,
  fetchMemoryGraph,
  patchMemory,
  searchMemories,
} from "@/lib/memory-client";
import {
  memoryFactKind,
  memoryPreview,
  type MemoryDetail,
  type MemoryFactKind,
  type MemoryGraphResponse,
  type MemorySearchMode,
  type MemorySearchResponse,
} from "@/lib/memory-types";
import { MemoryConstellation, type MemoryConstellationLabels } from "./MemoryConstellation";

type FactFilter = "" | MemoryFactKind;

const FACT_TONE: Record<MemoryFactKind, string> = {
  world: "var(--accent)",
  experience: "var(--status-success)",
  observation: "var(--status-warning)",
};

const FACT_LABEL_KEY: Record<MemoryFactKind, string> = {
  world: "memory.factWorld",
  experience: "memory.factExperience",
  observation: "memory.factObservation",
};

const SEARCH_MODES: MemorySearchMode[] = ["text", "meaning"];

const inputStyle: CSSProperties = {
  width: "100%",
  boxSizing: "border-box",
  padding: "5px 8px",
  fontSize: 12,
  lineHeight: 1.4,
  color: "var(--text)",
  background: "var(--bg)",
  border: "1px solid var(--border)",
  borderRadius: "var(--radius-control)",
  fontFamily: "inherit",
  outline: "none",
};

const fieldLabelStyle: CSSProperties = {
  display: "flex",
  flexDirection: "column",
  gap: 3,
  fontSize: 10.5,
  fontWeight: 500,
  color: "var(--text-muted)",
};

const miniTagStyle: CSSProperties = {
  display: "inline-flex",
  alignItems: "center",
  maxWidth: "100%",
  padding: "1px 5px",
  borderRadius: 999,
  border: "1px solid var(--border)",
  background: "var(--bg-subtle)",
  color: "var(--text-muted)",
  fontSize: 9.5,
  lineHeight: 1.5,
  overflow: "hidden",
  textOverflow: "ellipsis",
  whiteSpace: "nowrap",
};

const iconButtonStyle: CSSProperties = {
  display: "inline-flex",
  alignItems: "center",
  justifyContent: "center",
  width: 28,
  height: 28,
  padding: 0,
  borderRadius: "var(--radius-control)",
  border: "1px solid var(--border)",
  background: "var(--bg)",
  color: "var(--text-muted)",
  cursor: "pointer",
  flexShrink: 0,
};

const solidButtonStyle: CSSProperties = {
  display: "inline-flex",
  alignItems: "center",
  justifyContent: "center",
  gap: 5,
  height: 28,
  padding: "0 10px",
  borderRadius: "var(--radius-control)",
  border: "1px solid var(--border)",
  background: "var(--bg)",
  color: "var(--text-muted)",
  fontSize: 11.5,
  fontWeight: 500,
  cursor: "pointer",
  whiteSpace: "nowrap",
};

function formatScore(score: number): string {
  if (score > 0 && score <= 1) return `${Math.round(score * 100)}%`;
  return score.toFixed(2);
}

function formatMoment(value: string | null | undefined, locale: string): string | null {
  if (!value) return null;
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return value;
  return date.toLocaleString(locale, { dateStyle: "medium", timeStyle: "short" });
}

function toLocalInputValue(value: string | null | undefined): string {
  if (!value) return "";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "";
  const pad = (part: number) => String(part).padStart(2, "0");
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}T${pad(date.getHours())}:${pad(date.getMinutes())}`;
}

function fromLocalInputValue(value: string): string | null {
  if (!value) return null;
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? null : date.toISOString();
}

function errorMessage(error: unknown): string {
  return error instanceof Error && error.message ? error.message : String(error);
}

function FactBadge({ kind, label }: { kind: MemoryFactKind; label: string }) {
  const tone = FACT_TONE[kind];
  return (
    <span
      style={{
        display: "inline-flex",
        alignItems: "center",
        gap: 4,
        padding: "1px 6px",
        borderRadius: 999,
        border: `1px solid color-mix(in srgb, ${tone} 36%, transparent)`,
        background: `color-mix(in srgb, ${tone} 9%, transparent)`,
        color: tone,
        fontSize: 9.5,
        fontWeight: 600,
        lineHeight: 1.6,
        whiteSpace: "nowrap",
      }}
    >
      <span style={{ width: 5, height: 5, borderRadius: "50%", background: tone, flexShrink: 0 }} />
      {label}
    </span>
  );
}

function StateBadge({ label, tone }: { label: string; tone: string }) {
  return (
    <span
      style={{
        padding: "1px 6px",
        borderRadius: 999,
        border: `1px solid color-mix(in srgb, ${tone} 40%, transparent)`,
        color: tone,
        fontSize: 9.5,
        fontWeight: 600,
        lineHeight: 1.6,
        whiteSpace: "nowrap",
      }}
    >
      {label}
    </span>
  );
}

function DetailField({ label, children }: { label: string; children: ReactNode }) {
  return (
    <div style={{ display: "flex", flexDirection: "column", gap: 3 }}>
      <span style={{ fontSize: 9.5, fontWeight: 600, letterSpacing: "0.04em", textTransform: "uppercase", color: "var(--text-dim)" }}>{label}</span>
      <div style={{ fontSize: 11.5, lineHeight: 1.5, color: "var(--text-muted)", wordBreak: "break-word" }}>{children}</div>
    </div>
  );
}

function JumpRow({ text, caption, onClick }: { text: string; caption?: string; onClick: () => void }) {
  return (
    <button
      type="button"
      onClick={onClick}
      style={{
        display: "flex",
        alignItems: "center",
        gap: 6,
        width: "100%",
        padding: "6px 8px",
        borderRadius: 7,
        border: "1px solid var(--border)",
        background: "var(--bg)",
        color: "inherit",
        textAlign: "left",
        cursor: "pointer",
      }}
    >
      <span style={{ display: "flex", flexDirection: "column", gap: 1, minWidth: 0, flex: 1 }}>
        <span style={{ fontSize: 11, lineHeight: 1.4, color: "var(--text)", display: "-webkit-box", WebkitLineClamp: 2, WebkitBoxOrient: "vertical", overflow: "hidden" }}>{text}</span>
        {caption && <span style={{ fontSize: 9.5, color: "var(--text-dim)" }}>{caption}</span>}
      </span>
      <ChevronRight size={11} style={{ color: "var(--text-dim)", flexShrink: 0 }} aria-hidden="true" />
    </button>
  );
}

export function MemorySettingsPanel({ isMobile }: { isMobile: boolean }) {
  const { t, tn, locale } = useI18n();
  const reducedMotion = usePrefersReducedMotion();

  const [graph, setGraph] = useState<MemoryGraphResponse | null>(null);
  const [graphLoading, setGraphLoading] = useState(true);
  const [graphError, setGraphError] = useState<string | null>(null);
  const [refreshNonce, setRefreshNonce] = useState(0);

  const [mode, setMode] = useState<MemorySearchMode>("text");
  const [query, setQuery] = useState("");
  const [searchResult, setSearchResult] = useState<MemorySearchResponse | null>(null);
  const [searching, setSearching] = useState(false);
  const [searchError, setSearchError] = useState<string | null>(null);
  const [filterType, setFilterType] = useState<FactFilter>("");

  const [paused, setPaused] = useState(reducedMotion);
  const [fitSignal, setFitSignal] = useState(0);
  const [focusSignal, setFocusSignal] = useState<{ id: string; nonce: number } | null>(null);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [hoveredId, setHoveredId] = useState<string | null>(null);
  const [invalidatedIds, setInvalidatedIds] = useState<ReadonlySet<string>>(() => new Set<string>());

  const [detail, setDetail] = useState<MemoryDetail | null>(null);
  const [detailLoading, setDetailLoading] = useState(false);
  const [detailError, setDetailError] = useState<string | null>(null);
  const [detailReloadNonce, setDetailReloadNonce] = useState(0);

  const [editing, setEditing] = useState(false);
  const [saving, setSaving] = useState(false);
  const [editText, setEditText] = useState("");
  const [editFactType, setEditFactType] = useState<"world" | "experience">("world");
  const [editContext, setEditContext] = useState("");
  const [editEntities, setEditEntities] = useState<string[]>([]);
  const [entityDraft, setEntityDraft] = useState("");
  const [editOccurredStart, setEditOccurredStart] = useState("");
  const [editOccurredEnd, setEditOccurredEnd] = useState("");
  const [editMentionedAt, setEditMentionedAt] = useState("");

  const [confirmingInvalidate, setConfirmingInvalidate] = useState(false);
  const [invalidateReason, setInvalidateReason] = useState("");
  const [mutating, setMutating] = useState(false);

  const graphSeqRef = useRef(0);
  const searchSeqRef = useRef(0);
  const detailSeqRef = useRef(0);
  const debounceRef = useRef(0);

  const loadGraph = useCallback(async () => {
    const seq = ++graphSeqRef.current;
    setGraphLoading(true);
    setGraphError(null);
    try {
      const response = await fetchMemoryGraph({ limit: 1000, type: filterType || undefined });
      if (graphSeqRef.current !== seq) return;
      setGraph(response);
    } catch (error) {
      if (graphSeqRef.current !== seq) return;
      setGraphError(errorMessage(error));
    } finally {
      if (graphSeqRef.current === seq) setGraphLoading(false);
    }
  }, [filterType]);

  useEffect(() => {
    void loadGraph();
  }, [loadGraph, refreshNonce]);

  const runSearch = useCallback(
    async (rawQuery: string, nextMode: MemorySearchMode) => {
      const trimmed = rawQuery.trim();
      if (!trimmed) return;
      const seq = ++searchSeqRef.current;
      setSearching(true);
      setSearchError(null);
      try {
        const response = await searchMemories({
          query: trimmed,
          mode: nextMode,
          ...(filterType ? { type: filterType } : {}),
          limit: 100,
        });
        if (searchSeqRef.current !== seq) return;
        setSearchResult(response);
        setSelectedId((current) => {
          if (!current) return current;
          const present =
            response.items.some((item) => item.id === current) ||
            response.nodes.some((node) => node.data.id === current);
          return present ? current : null;
        });
      } catch (error) {
        if (searchSeqRef.current !== seq) return;
        setSearchError(errorMessage(error));
        setSearchResult(null);
      } finally {
        if (searchSeqRef.current === seq) setSearching(false);
      }
    },
    [filterType],
  );

  const resetSearchState = useCallback(() => {
    window.clearTimeout(debounceRef.current);
    searchSeqRef.current += 1;
    setSearching(false);
    setSearchResult(null);
    setSearchError(null);
  }, []);

  const clearSearch = useCallback(() => {
    resetSearchState();
    setQuery("");
    setHoveredId(null);
  }, [resetSearchState]);

  // Clearing the input — by typing it out or via the X button — restores the
  // full graph in either search mode.
  useEffect(() => {
    if (query.trim().length === 0) resetSearchState();
  }, [query, resetSearchState]);

  // Text search is debounced; meaning (semantic recall) waits for Enter/click.
  useEffect(() => {
    if (mode !== "text") return;
    const trimmed = query.trim();
    if (!trimmed) return;
    const timer = window.setTimeout(() => {
      void runSearch(trimmed, "text");
    }, 300);
    debounceRef.current = timer;
    return () => window.clearTimeout(timer);
  }, [query, mode, filterType, runSearch]);

  const changeFilterType = useCallback(
    (next: FactFilter) => {
      setFilterType(next);
      // Semantic recall only runs on an explicit trigger, so stale results from
      // the previous type filter must not linger.
      if (mode === "meaning") resetSearchState();
    },
    [mode, resetSearchState],
  );

  const submitSearch = useCallback(() => {
    window.clearTimeout(debounceRef.current);
    const trimmed = query.trim();
    if (!trimmed) {
      clearSearch();
      return;
    }
    void runSearch(trimmed, mode);
  }, [clearSearch, mode, query, runSearch]);

  const switchMode = useCallback(
    (nextMode: MemorySearchMode) => {
      if (nextMode === mode) return;
      setMode(nextMode);
      resetSearchState();
    },
    [mode, resetSearchState],
  );

  // Full detail for the selected unit; the basic graph/search fields render
  // immediately while this is in flight.
  useEffect(() => {
    if (!selectedId) {
      detailSeqRef.current += 1;
      setDetail(null);
      setDetailError(null);
      setDetailLoading(false);
      return;
    }
    const seq = ++detailSeqRef.current;
    let alive = true;
    setDetailLoading(true);
    setDetailError(null);
    setDetail((current) => (current?.id === selectedId ? current : null));
    fetchMemoryDetail(selectedId)
      .then((next) => {
        if (!alive || detailSeqRef.current !== seq) return;
        setDetail(next);
        setInvalidatedIds((previous) => {
          const invalidated = next.state === "invalidated";
          if (invalidated === previous.has(next.id)) return previous;
          const updated = new Set(previous);
          if (invalidated) updated.add(next.id);
          else updated.delete(next.id);
          return updated;
        });
      })
      .catch((error) => {
        if (!alive || detailSeqRef.current !== seq) return;
        setDetailError(errorMessage(error));
      })
      .finally(() => {
        if (alive && detailSeqRef.current === seq) setDetailLoading(false);
      });
    return () => {
      alive = false;
    };
  }, [selectedId, detailReloadNonce]);

  useEffect(() => {
    setEditing(false);
    setConfirmingInvalidate(false);
    setInvalidateReason("");
    setEntityDraft("");
  }, [selectedId]);

  useEffect(() => {
    if (reducedMotion) setPaused(true);
  }, [reducedMotion]);

  const displayNodes = searchResult?.nodes ?? graph?.nodes ?? [];
  const displayEdges = searchResult?.edges ?? graph?.edges ?? [];
  const searchActive = searching || searchResult !== null;

  const rankedItems = useMemo(
    () => [...(searchResult?.items ?? [])].sort((left, right) => right.score - left.score),
    [searchResult],
  );

  const detailMatches = detail && detail.id === selectedId ? detail : null;
  const selectedNode = useMemo(
    () => displayNodes.find((node) => node.data.id === selectedId)?.data ?? null,
    [displayNodes, selectedId],
  );
  const selectedSearchItem = useMemo(
    () => searchResult?.items.find((item) => item.id === selectedId) ?? null,
    [searchResult, selectedId],
  );

  const selectedKind =
    memoryFactKind(detailMatches?.fact_type ?? detailMatches?.type ?? selectedNode?.factType ?? selectedSearchItem?.fact_type) ?? null;
  const isObservation = selectedKind === "observation";
  const isInvalidated = detailMatches?.state === "invalidated" || (selectedId ? invalidatedIds.has(selectedId) : false);
  const isEdited = Boolean(detailMatches?.edited_at);

  const displayText = detailMatches?.text ?? selectedNode?.text ?? selectedSearchItem?.text ?? "";
  const displayContext = detailMatches?.context ?? selectedNode?.context ?? selectedSearchItem?.context ?? "";
  const displayEntities =
    detailMatches?.entities ??
    (selectedNode?.entities
      ? selectedNode.entities
          .split(",")
          .map((entity) => entity.trim())
          .filter((entity) => entity.length > 0 && entity.toLowerCase() !== "none" && entity.toUpperCase() !== "N/A")
      : selectedSearchItem?.entities ?? []);

  const neighborNodes = useMemo(() => {
    if (!selectedId) return [];
    const seen = new Set<string>();
    const nodes: Array<{ id: string; label: string; factKind: string | null }> = [];
    for (const edge of displayEdges) {
      const otherId =
        edge.data.source === selectedId
          ? edge.data.target
          : edge.data.target === selectedId
            ? edge.data.source
            : null;
      if (!otherId || seen.has(otherId)) continue;
      seen.add(otherId);
      const node = displayNodes.find((candidate) => candidate.data.id === otherId);
      if (node) nodes.push({ id: otherId, label: node.data.label, factKind: node.data.factType ?? null });
    }
    return nodes;
  }, [displayEdges, displayNodes, selectedId]);

  const constellationLabels = useMemo<MemoryConstellationLabels>(
    () => ({
      graph: t("memory.graphAria"),
      empty: searchResult ? t("memory.noResults") : graph && !graph.configured ? t("memory.notConfigured") : t("memory.emptyGraph"),
      world: t("memory.factWorld"),
      experience: t("memory.factExperience"),
      observation: t("memory.factObservation"),
      semantic: t("memory.linkSemantic"),
      temporal: t("memory.linkTemporal"),
      entity: t("memory.linkEntity"),
      causal: t("memory.linkCausal"),
      zoomHint: t("memory.zoomHint"),
    }),
    [graph, searchResult, t],
  );

  const selectMemory = useCallback((id: string) => {
    setSelectedId(id);
    setFocusSignal((previous) => ({ id, nonce: (previous?.nonce ?? 0) + 1 }));
  }, []);

  const applyDetailUpdate = useCallback((updated: MemoryDetail) => {
    setDetail(updated);
    setInvalidatedIds((previous) => {
      const invalidated = updated.state === "invalidated";
      if (invalidated === previous.has(updated.id)) return previous;
      const next = new Set(previous);
      if (invalidated) next.add(updated.id);
      else next.delete(updated.id);
      return next;
    });
    const nextFactType = updated.fact_type ?? updated.type ?? null;
    const mergeNode = (node: { data: { id: string; text: string; label: string; context?: string; factType?: string | null } }) =>
      node.data.id === updated.id
        ? {
            data: {
              ...node.data,
              text: updated.text,
              label: memoryPreview(updated.text, 80),
              context: updated.context ?? node.data.context,
              factType: nextFactType ?? node.data.factType,
            },
          }
        : node;
    setGraph((previous) => (previous ? { ...previous, nodes: previous.nodes.map(mergeNode) } : previous));
    setSearchResult((previous) => {
      if (!previous) return previous;
      return {
        ...previous,
        nodes: previous.nodes.map(mergeNode),
        items: previous.items.map((item) =>
          item.id === updated.id
            ? {
                ...item,
                text: updated.text,
                context: updated.context,
                fact_type: nextFactType ?? item.fact_type,
                entities: updated.entities,
              }
            : item,
        ),
      };
    });
  }, []);

  const startEditing = useCallback(() => {
    if (!detailMatches || memoryFactKind(detailMatches.fact_type ?? detailMatches.type) === "observation") return;
    setEditText(detailMatches.text);
    setEditFactType(detailMatches.fact_type === "experience" || detailMatches.type === "experience" ? "experience" : "world");
    setEditContext(detailMatches.context ?? "");
    setEditEntities(detailMatches.entities ?? []);
    setEditOccurredStart(toLocalInputValue(detailMatches.occurred_start));
    setEditOccurredEnd(toLocalInputValue(detailMatches.occurred_end));
    setEditMentionedAt(toLocalInputValue(detailMatches.mentioned_at));
    setEntityDraft("");
    setConfirmingInvalidate(false);
    setEditing(true);
  }, [detailMatches]);

  const commitEntity = useCallback(() => {
    const value = entityDraft.trim();
    if (!value) return;
    setEditEntities((previous) =>
      previous.some((entity) => entity.toLowerCase() === value.toLowerCase()) ? previous : [...previous, value],
    );
    setEntityDraft("");
  }, [entityDraft]);

  const handleSave = useCallback(async () => {
    if (!selectedId || !detailMatches || !editText.trim()) return;
    setSaving(true);
    try {
      const updated = await patchMemory(
        selectedId,
        buildEditPatch({
          text: editText.trim(),
          context: editContext,
          factType: editFactType,
          entities: editEntities,
          occurredStart: fromLocalInputValue(editOccurredStart) ?? "",
          occurredEnd: fromLocalInputValue(editOccurredEnd) ?? "",
          mentionedAt: fromLocalInputValue(editMentionedAt) ?? "",
        }),
      );
      applyDetailUpdate(updated);
      setEditing(false);
      toast.success(t("memory.savedSuccess"));
    } catch (error) {
      toast.error(t("memory.saveFailed"), errorMessage(error));
    } finally {
      setSaving(false);
    }
  }, [
    applyDetailUpdate,
    detailMatches,
    editContext,
    editEntities,
    editFactType,
    editMentionedAt,
    editOccurredEnd,
    editOccurredStart,
    editText,
    selectedId,
    t,
  ]);

  const handleInvalidate = useCallback(async () => {
    if (!selectedId) return;
    setMutating(true);
    try {
      const reason = invalidateReason.trim();
      const updated = await patchMemory(selectedId, {
        state: "invalidated",
        ...(reason ? { reason } : {}),
      });
      applyDetailUpdate(updated);
      setConfirmingInvalidate(false);
      setInvalidateReason("");
      toast.success(t("memory.invalidatedSuccess"));
    } catch (error) {
      toast.error(t("memory.invalidateFailed"), errorMessage(error));
    } finally {
      setMutating(false);
    }
  }, [applyDetailUpdate, invalidateReason, selectedId, t]);

  const handleRestore = useCallback(async () => {
    if (!selectedId) return;
    setMutating(true);
    try {
      const updated = await patchMemory(selectedId, { state: "valid" });
      applyDetailUpdate(updated);
      toast.success(t("memory.restoredSuccess"));
    } catch (error) {
      toast.error(t("memory.restoreFailed"), errorMessage(error));
    } finally {
      setMutating(false);
    }
  }, [applyDetailUpdate, selectedId, t]);

  const timestampRows = detailMatches
    ? [
        { key: "memory.date", value: formatMoment(detailMatches.date, locale) },
        { key: "memory.occurredStart", value: formatMoment(detailMatches.occurred_start, locale) },
        { key: "memory.occurredEnd", value: formatMoment(detailMatches.occurred_end, locale) },
        { key: "memory.mentionedAt", value: formatMoment(detailMatches.mentioned_at, locale) },
        { key: "memory.editedAt", value: formatMoment(detailMatches.edited_at, locale) },
        { key: "memory.invalidatedAt", value: formatMoment(detailMatches.invalidated_at, locale) },
      ].filter((row): row is { key: string; value: string } => Boolean(row.value))
    : [];

  const toolbarSpinner = <Loader2 size={12} strokeWidth={2} aria-hidden="true" style={{ animation: "spin 0.8s linear infinite" }} />;

  return (
    <div
      role="tabpanel"
      id="settings-panel-memory"
      aria-labelledby="settings-tab-memory"
      className="settings-panel-inner"
      style={{ padding: isMobile ? "16px 14px 32px" : "28px 24px 48px", gap: 16, maxWidth: 1160 }}
    >
      <div style={{ marginBottom: 4 }}>
        <h2
          className="display-serif"
          style={{ fontSize: "var(--text-2xl)", fontWeight: 600, margin: 0, color: "var(--text)", letterSpacing: "-0.01em" }}
        >
          {t("memory.title")}
        </h2>
        <p
          className="settings-content-subtitle"
          style={{ margin: "4px 0 16px", fontSize: "var(--text-md)", color: "var(--text-muted)", lineHeight: 1.45 }}
        >
          {t("memory.description")}
        </p>
      </div>

      <section
        className="settings-card"
        style={{
          padding: 0,
          overflow: "hidden",
          display: "flex",
          flexDirection: "column",
          height: isMobile ? "calc(100dvh - 190px)" : "min(740px, calc(100dvh - 190px))",
          minHeight: 540,
          width: "100%",
          boxSizing: "border-box",
          marginBottom: 0,
          alignItems: "stretch",
          gap: 0,
        }}
      >
        {/* Toolbar: mode, search, type filter, stats, graph controls. */}
        <div
          style={{
            display: "flex",
            flexWrap: "wrap",
            alignItems: "center",
            gap: 8,
            padding: isMobile ? "9px 10px" : "10px 14px",
            borderBottom: "1px solid var(--border)",
            background: "var(--bg-panel)",
            flexShrink: 0,
          }}
        >
          <div
            role="group"
            aria-label={t("memory.searchMode")}
            style={{
              display: "inline-flex",
              border: "1px solid var(--border)",
              borderRadius: "var(--radius-control)",
              overflow: "hidden",
              background: "var(--bg)",
              flexShrink: 0,
            }}
          >
            {SEARCH_MODES.map((option, index) => {
              const active = mode === option;
              return (
                <button
                  key={option}
                  type="button"
                  aria-pressed={active}
                  onClick={() => switchMode(option)}
                  style={{
                    height: 28,
                    padding: "0 9px",
                    border: "none",
                    borderLeft: index === 0 ? "none" : "1px solid var(--border)",
                    background: active ? "var(--bg-selected)" : "transparent",
                    color: active ? "var(--text)" : "var(--text-muted)",
                    fontSize: 11,
                    fontWeight: active ? 600 : 500,
                    cursor: "pointer",
                    whiteSpace: "nowrap",
                  }}
                >
                  {option === "text" ? t("memory.searchModeText") : t("memory.searchModeMeaning")}
                </button>
              );
            })}
          </div>

          <div
            style={{
              display: "flex",
              alignItems: "center",
              gap: 4,
              flex: "1 1 260px",
              minWidth: 200,
              maxWidth: 460,
              padding: "0 6px",
              height: 28,
              boxSizing: "border-box",
              border: "1px solid var(--border)",
              borderRadius: "var(--radius-control)",
              background: "var(--bg)",
            }}
          >
            <Search size={12} aria-hidden="true" style={{ color: "var(--text-dim)", flexShrink: 0 }} />
            <input
              value={query}
              onChange={(event) => setQuery(event.target.value)}
              onKeyDown={(event) => {
                if (event.key === "Enter") {
                  event.preventDefault();
                  submitSearch();
                }
              }}
              placeholder={mode === "text" ? t("memory.searchPlaceholderText") : t("memory.searchPlaceholderMeaning")}
              aria-label={t("memory.search")}
              style={{
                flex: 1,
                minWidth: 0,
                height: "100%",
                border: "none",
                background: "transparent",
                color: "var(--text)",
                fontSize: 12,
                outline: "none",
              }}
            />
            {(query.length > 0 || searchResult) && (
              <button
                type="button"
                onClick={clearSearch}
                title={t("memory.clearSearch")}
                aria-label={t("memory.clearSearch")}
                style={{ display: "inline-flex", padding: 2, border: "none", background: "transparent", color: "var(--text-dim)", cursor: "pointer", flexShrink: 0 }}
              >
                <X size={12} aria-hidden="true" />
              </button>
            )}
          </div>

          <button
            type="button"
            onClick={submitSearch}
            disabled={searching || query.trim().length === 0}
            title={t("memory.search")}
            style={{
              ...solidButtonStyle,
              color: query.trim() ? "var(--accent)" : "var(--text-dim)",
              borderColor: query.trim() ? "color-mix(in srgb, var(--accent) 45%, var(--border))" : "var(--border)",
              opacity: searching ? 0.7 : 1,
            }}
          >
            {searching ? toolbarSpinner : <Search size={12} aria-hidden="true" />}
            {searching ? t("memory.searching") : t("memory.search")}
          </button>

          <select
            aria-label={t("memory.filterLabel")}
            value={filterType}
            onChange={(event) => changeFilterType(event.target.value as FactFilter)}
            style={{ ...inputStyle, width: "auto", height: 28, padding: "0 6px", fontSize: 11, flexShrink: 0, cursor: "pointer" }}
          >
            <option value="">{t("memory.filterAll")}</option>
            <option value="world">{t("memory.filterWorld")}</option>
            <option value="experience">{t("memory.filterExperience")}</option>
            <option value="observation">{t("memory.filterObservation")}</option>
          </select>

          <span
            style={{
              marginLeft: "auto",
              display: "inline-flex",
              alignItems: "center",
              gap: 6,
              fontSize: 10.5,
              color: "var(--text-dim)",
              fontFamily: "var(--font-mono)",
              whiteSpace: "nowrap",
            }}
          >
            <span>{t("memory.stats", { nodes: displayNodes.length, edges: displayEdges.length })}</span>
            {graph?.bankId && (
              <span style={{ ...miniTagStyle, fontFamily: "var(--font-mono)" }} title={t("memory.bankId")}>
                {graph.bankId}
              </span>
            )}
          </span>

          <div style={{ display: "flex", alignItems: "center", gap: 4, flexShrink: 0 }}>
            <button
              type="button"
              onClick={() => setPaused((value) => !value)}
              title={paused ? t("memory.resumeMotion") : t("memory.pauseMotion")}
              aria-label={paused ? t("memory.resumeMotion") : t("memory.pauseMotion")}
              style={iconButtonStyle}
            >
              {paused ? <Play size={12} aria-hidden="true" /> : <Pause size={12} aria-hidden="true" />}
            </button>
            <button
              type="button"
              onClick={() => setFitSignal((value) => value + 1)}
              title={t("memory.fitView")}
              aria-label={t("memory.fitView")}
              style={iconButtonStyle}
            >
              <Maximize2 size={12} aria-hidden="true" />
            </button>
            <button
              type="button"
              onClick={() => setRefreshNonce((value) => value + 1)}
              title={t("memory.refresh")}
              aria-label={t("memory.refresh")}
              style={iconButtonStyle}
            >
              {graphLoading ? toolbarSpinner : <RefreshCw size={12} aria-hidden="true" />}
            </button>
          </div>
        </div>

        {searchError && (
          <div
            role="alert"
            style={{
              display: "flex",
              alignItems: "center",
              gap: 8,
              padding: "5px 14px",
              borderBottom: "1px solid var(--border)",
              background: "color-mix(in srgb, var(--status-error) 8%, var(--bg))",
              color: "var(--status-error)",
              fontSize: 11,
              flexShrink: 0,
            }}
          >
            <span style={{ flex: 1 }}>{t("memory.searchFailed")}: {searchError}</span>
            <button type="button" onClick={submitSearch} style={{ ...solidButtonStyle, height: 22, fontSize: 10.5 }}>
              {t("memory.retry")}
            </button>
          </div>
        )}

        <div
          style={{
            display: "flex",
            flex: 1,
            minHeight: 0,
            flexDirection: isMobile ? "column" : "row",
            position: "relative",
          }}
        >
          {/* Ranked search results (only while a search is active). */}
          {searchActive && (
            <div
              style={{
                width: isMobile ? "100%" : 264,
                flexShrink: 0,
                display: "flex",
                flexDirection: "column",
                minHeight: 0,
                maxHeight: isMobile ? 190 : undefined,
                borderRight: isMobile ? "none" : "1px solid var(--border)",
                borderBottom: isMobile ? "1px solid var(--border)" : "none",
                background: "var(--bg-panel)",
              }}
            >
              <div style={{ padding: "8px 12px 6px", borderBottom: "1px solid var(--border)", flexShrink: 0 }}>
                <div style={{ fontSize: 11, fontWeight: 600, color: "var(--text)" }}>
                  {searching ? t("memory.searching") : tn("memory.resultCount", rankedItems.length, { count: rankedItems.length })}
                </div>
                <div style={{ fontSize: 9.5, color: "var(--text-dim)" }}>{t("memory.sortedByScore")}</div>
              </div>
              <div style={{ flex: 1, minHeight: 0, overflowY: "auto", padding: "6px 8px 10px", display: "flex", flexDirection: "column", gap: 6 }}>
                {rankedItems.map((item, index) => {
                  const kind = memoryFactKind(item.fact_type);
                  const invalidated = invalidatedIds.has(item.id);
                  const selected = item.id === selectedId;
                  return (
                    <button
                      key={item.id}
                      type="button"
                      onClick={() => selectMemory(item.id)}
                      onMouseEnter={() => setHoveredId(item.id)}
                      onMouseLeave={() => setHoveredId(null)}
                      style={{
                        display: "flex",
                        flexDirection: "column",
                        gap: 4,
                        padding: "7px 9px",
                        borderRadius: 8,
                        border: `1px solid ${selected ? "var(--accent)" : "var(--border)"}`,
                        background: selected ? "var(--bg-selected)" : "var(--bg)",
                        color: "inherit",
                        textAlign: "left",
                        cursor: "pointer",
                        opacity: invalidated ? 0.68 : 1,
                      }}
                    >
                      <div style={{ display: "flex", alignItems: "center", gap: 6, minWidth: 0 }}>
                        <span style={{ fontFamily: "var(--font-mono)", fontSize: 9.5, color: "var(--text-dim)", flexShrink: 0 }}>
                          #{index + 1}
                        </span>
                        {kind && <FactBadge kind={kind} label={t(FACT_LABEL_KEY[kind])} />}
                        {invalidated && <StateBadge label={t("memory.stateInvalidated")} tone="var(--status-error)" />}
                        <span
                          title={t("memory.matchScore")}
                          style={{
                            marginLeft: "auto",
                            fontFamily: "var(--font-mono)",
                            fontSize: 9.5,
                            color: "var(--accent)",
                            flexShrink: 0,
                          }}
                        >
                          {formatScore(item.score)}
                        </span>
                      </div>
                      <span
                        style={{
                          fontSize: 11.5,
                          lineHeight: 1.4,
                          color: "var(--text)",
                          display: "-webkit-box",
                          WebkitLineClamp: 3,
                          WebkitBoxOrient: "vertical",
                          overflow: "hidden",
                        }}
                      >
                        {item.text}
                      </span>
                      {item.entities && item.entities.length > 0 && (
                        <div style={{ display: "flex", flexWrap: "wrap", gap: 3 }}>
                          {item.entities.slice(0, 4).map((entity) => (
                            <span key={entity} style={miniTagStyle}>{entity}</span>
                          ))}
                          {item.entities.length > 4 && (
                            <span style={miniTagStyle}>+{item.entities.length - 4}</span>
                          )}
                        </div>
                      )}
                    </button>
                  );
                })}
                {!searching && rankedItems.length === 0 && (
                  <div style={{ padding: "14px 6px", fontSize: 11, color: "var(--text-dim)", textAlign: "center" }}>
                    {t("memory.noResults")}
                  </div>
                )}
              </div>
            </div>
          )}

          {/* Center: interactive knowledge graph. */}
          <div
            style={{
              position: "relative",
              display: "flex",
              flex: 1,
              minWidth: 0,
              minHeight: isMobile ? 220 : 0,
              flexDirection: "column",
            }}
          >
            <MemoryConstellation
              nodes={displayNodes}
              edges={displayEdges}
              selectedId={selectedId}
              hoveredId={hoveredId}
              invalidatedIds={invalidatedIds}
              paused={paused}
              fitSignal={fitSignal}
              focusSignal={focusSignal}
              labels={constellationLabels}
              onSelect={setSelectedId}
              onHover={setHoveredId}
            />

            {(graphError || (graphLoading && !graph) || (graph && !graph.configured && !searchResult)) && (
              <div
                style={{
                  position: "absolute",
                  inset: 0,
                  display: "grid",
                  placeItems: "center",
                  padding: 20,
                  background: "color-mix(in srgb, var(--bg) 74%, transparent)",
                  backdropFilter: "blur(2px)",
                }}
              >
                <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 8, maxWidth: 340, textAlign: "center" }}>
                  <Brain size={20} aria-hidden="true" style={{ color: graphError ? "var(--status-error)" : "var(--text-dim)" }} />
                  <span style={{ fontSize: 12, lineHeight: 1.5, color: graphError ? "var(--status-error)" : "var(--text-muted)" }}>
                    {graphError
                      ? `${t("memory.loadFailed")}: ${graphError}`
                      : graph && !graph.configured
                        ? t("memory.notConfigured")
                        : t("memory.loadingGraph")}
                  </span>
                  {graph?.error && !graph.configured && (
                    <span style={{ fontSize: 10.5, color: "var(--text-dim)", lineHeight: 1.4 }}>{graph.error}</span>
                  )}
                  {(graphError || (graph && !graph.configured)) && (
                    <button
                      type="button"
                      onClick={() => setRefreshNonce((value) => value + 1)}
                      style={{ ...solidButtonStyle, color: "var(--accent)" }}
                    >
                      <RefreshCw size={11} aria-hidden="true" />
                      {t("memory.retry")}
                    </button>
                  )}
                </div>
              </div>
            )}
          </div>

          {/* Right: detail, edit, invalidate. */}
          {selectedId && (
            <div
              style={{
                width: isMobile ? "100%" : 320,
                flexShrink: 0,
                display: "flex",
                flexDirection: "column",
                minHeight: 0,
                maxHeight: isMobile ? "48%" : undefined,
                borderLeft: isMobile ? "none" : "1px solid var(--border)",
                borderTop: isMobile ? "1px solid var(--border)" : "none",
                background: "var(--bg-panel)",
              }}
            >
              <div style={{ display: "flex", alignItems: "center", gap: 6, padding: "8px 12px", borderBottom: "1px solid var(--border)", flexShrink: 0 }}>
                <Brain size={13} aria-hidden="true" style={{ color: "var(--accent)", flexShrink: 0 }} />
                <span style={{ fontSize: 11.5, fontWeight: 600, color: "var(--text)" }}>{t("memory.detail")}</span>
                {detailLoading && toolbarSpinner}
                <button
                  type="button"
                  onClick={() => setSelectedId(null)}
                  title={t("memory.closeDetail")}
                  aria-label={t("memory.closeDetail")}
                  style={{ ...iconButtonStyle, marginLeft: "auto", width: 24, height: 24, border: "none", background: "transparent" }}
                >
                  <X size={12} aria-hidden="true" />
                </button>
              </div>

              <div style={{ flex: 1, minHeight: 0, overflowY: "auto", padding: "10px 12px 20px", display: "flex", flexDirection: "column", gap: 12 }}>
                {editing && detailMatches ? (
                  <div style={{ display: "flex", flexDirection: "column", gap: 9 }}>
                    <label style={fieldLabelStyle}>
                      {t("memory.editText")}
                      <textarea
                        value={editText}
                        onChange={(event) => setEditText(event.target.value)}
                        rows={6}
                        style={{ ...inputStyle, minHeight: 96, resize: "vertical", lineHeight: 1.5 }}
                      />
                    </label>

                    <div style={{ display: "flex", flexDirection: "column", gap: 3 }}>
                      <span style={fieldLabelStyle}>{t("memory.editFactType")}</span>
                      <div style={{ display: "flex", gap: 4 }}>
                        {(["world", "experience"] as const).map((kind) => {
                          const active = editFactType === kind;
                          return (
                            <button
                              key={kind}
                              type="button"
                              onClick={() => setEditFactType(kind)}
                              style={{
                                flex: 1,
                                height: 26,
                                borderRadius: "var(--radius-control)",
                                border: `1px solid ${active ? "var(--accent)" : "var(--border)"}`,
                                background: active ? "var(--bg-selected)" : "var(--bg)",
                                color: active ? "var(--text)" : "var(--text-muted)",
                                fontSize: 10.5,
                                cursor: "pointer",
                              }}
                            >
                              {t(FACT_LABEL_KEY[kind])}
                            </button>
                          );
                        })}
                      </div>
                    </div>

                    <label style={fieldLabelStyle}>
                      {t("memory.editContext")}
                      <input value={editContext} onChange={(event) => setEditContext(event.target.value)} style={inputStyle} />
                    </label>

                    <div style={{ display: "flex", flexDirection: "column", gap: 4 }}>
                      <span style={fieldLabelStyle}>{t("memory.editEntities")}</span>
                      {editEntities.length > 0 && (
                        <div style={{ display: "flex", flexWrap: "wrap", gap: 4 }}>
                          {editEntities.map((entity) => (
                            <span key={entity} style={{ ...miniTagStyle, gap: 3, padding: "1px 4px 1px 6px", color: "var(--text)" }}>
                              {entity}
                              <button
                                type="button"
                                onClick={() => setEditEntities((previous) => previous.filter((entry) => entry !== entity))}
                                aria-label={`${t("memory.removeEntity")}: ${entity}`}
                                style={{ display: "inline-flex", padding: 0, border: "none", background: "transparent", color: "var(--text-dim)", cursor: "pointer" }}
                              >
                                <X size={9} aria-hidden="true" />
                              </button>
                            </span>
                          ))}
                        </div>
                      )}
                      <div style={{ display: "flex", gap: 4 }}>
                        <input
                          value={entityDraft}
                          onChange={(event) => setEntityDraft(event.target.value)}
                          onKeyDown={(event) => {
                            if (event.key === "Enter" || event.key === ",") {
                              event.preventDefault();
                              commitEntity();
                            }
                          }}
                          placeholder={t("memory.addEntity")}
                          style={{ ...inputStyle, flex: 1 }}
                        />
                        <button type="button" onClick={commitEntity} disabled={!entityDraft.trim()} style={{ ...solidButtonStyle, width: 28, padding: 0 }}>
                          +
                        </button>
                      </div>
                    </div>

                    <label style={fieldLabelStyle}>
                      {t("memory.occurredStart")}
                      <input type="datetime-local" value={editOccurredStart} onChange={(event) => setEditOccurredStart(event.target.value)} style={inputStyle} />
                    </label>
                    <label style={fieldLabelStyle}>
                      {t("memory.occurredEnd")}
                      <input type="datetime-local" value={editOccurredEnd} onChange={(event) => setEditOccurredEnd(event.target.value)} style={inputStyle} />
                    </label>
                    <label style={fieldLabelStyle}>
                      {t("memory.mentionedAt")}
                      <input type="datetime-local" value={editMentionedAt} onChange={(event) => setEditMentionedAt(event.target.value)} style={inputStyle} />
                    </label>

                    <div style={{ display: "flex", gap: 6, paddingTop: 2 }}>
                      <button
                        type="button"
                        onClick={() => void handleSave()}
                        disabled={saving || !editText.trim()}
                        style={{ ...solidButtonStyle, color: "var(--accent)", borderColor: "color-mix(in srgb, var(--accent) 45%, var(--border))", opacity: saving ? 0.7 : 1 }}
                      >
                        {saving ? toolbarSpinner : <Check size={12} aria-hidden="true" />}
                        {t("memory.save")}
                      </button>
                      <button type="button" onClick={() => setEditing(false)} disabled={saving} style={solidButtonStyle}>
                        {t("memory.cancel")}
                      </button>
                    </div>
                  </div>
                ) : (
                  <>
                    <div style={{ display: "flex", flexWrap: "wrap", alignItems: "center", gap: 5 }}>
                      {selectedKind && <FactBadge kind={selectedKind} label={t(FACT_LABEL_KEY[selectedKind])} />}
                      {isInvalidated && <StateBadge label={t("memory.stateInvalidated")} tone="var(--status-error)" />}
                      {isEdited && <StateBadge label={t("memory.stateEdited")} tone="var(--status-warning)" />}
                      {!isInvalidated && !isEdited && detailMatches && (
                        <StateBadge label={t("memory.stateValid")} tone="var(--status-success)" />
                      )}
                    </div>

                    <p
                      style={{
                        margin: 0,
                        fontSize: 12.5,
                        lineHeight: 1.55,
                        color: "var(--text)",
                        whiteSpace: "pre-wrap",
                        wordBreak: "break-word",
                      }}
                    >
                      {displayText || t("memory.noText")}
                    </p>

                    {detailLoading && !detailMatches && (
                      <span style={{ display: "inline-flex", alignItems: "center", gap: 5, fontSize: 10.5, color: "var(--text-dim)" }}>
                        {toolbarSpinner}
                        {t("memory.loadingDetail")}
                      </span>
                    )}

                    {detailError && (
                      <div
                        role="alert"
                        style={{
                          display: "flex",
                          flexDirection: "column",
                          gap: 5,
                          padding: "7px 8px",
                          borderRadius: 7,
                          border: "1px solid color-mix(in srgb, var(--status-error) 40%, var(--border))",
                          background: "color-mix(in srgb, var(--status-error) 7%, var(--bg))",
                          fontSize: 10.5,
                          color: "var(--status-error)",
                        }}
                      >
                        <span>{t("memory.detailFailed")}: {detailError}</span>
                        <button
                          type="button"
                          onClick={() => setDetailReloadNonce((value) => value + 1)}
                          style={{ ...solidButtonStyle, alignSelf: "flex-start", height: 22, fontSize: 10.5 }}
                        >
                          {t("memory.retry")}
                        </button>
                      </div>
                    )}

                    {isObservation && !isInvalidated && (
                      <div
                        style={{
                          padding: "7px 9px",
                          borderRadius: 7,
                          border: "1px solid var(--border)",
                          background: "var(--bg)",
                          fontSize: 10.5,
                          lineHeight: 1.5,
                          color: "var(--text-muted)",
                        }}
                      >
                        {t("memory.observationReadonlyHint")}
                      </div>
                    )}

                    {displayContext && (
                      <DetailField label={t("memory.context")}>
                        <span style={{ whiteSpace: "pre-wrap" }}>{displayContext}</span>
                      </DetailField>
                    )}

                    <DetailField label={t("memory.entities")}>
                      {displayEntities.length > 0 ? (
                        <div style={{ display: "flex", flexWrap: "wrap", gap: 3 }}>
                          {displayEntities.map((entity) => (
                            <span key={entity} style={miniTagStyle}>{entity}</span>
                          ))}
                        </div>
                      ) : (
                        <span style={{ color: "var(--text-dim)" }}>{t("memory.noEntities")}</span>
                      )}
                    </DetailField>

                    {detailMatches?.tags && detailMatches.tags.length > 0 && (
                      <DetailField label={t("memory.tags")}>
                        <div style={{ display: "flex", flexWrap: "wrap", gap: 3 }}>
                          {detailMatches.tags.map((tag) => (
                            <span key={tag} style={miniTagStyle}>#{tag}</span>
                          ))}
                        </div>
                      </DetailField>
                    )}

                    {timestampRows.length > 0 && (
                      <DetailField label={t("memory.timestamps")}>
                        <div style={{ display: "flex", flexDirection: "column", gap: 2 }}>
                          {timestampRows.map((row) => (
                            <span key={row.key} style={{ display: "flex", justifyContent: "space-between", gap: 8 }}>
                              <span style={{ color: "var(--text-dim)" }}>{t(row.key)}</span>
                              <span style={{ fontFamily: "var(--font-mono)", fontSize: 10, textAlign: "right" }}>{row.value}</span>
                            </span>
                          ))}
                        </div>
                      </DetailField>
                    )}

                    {isInvalidated && detailMatches?.invalidation_reason && (
                      <DetailField label={t("memory.invalidationReason")}>
                        <span style={{ whiteSpace: "pre-wrap" }}>{detailMatches.invalidation_reason}</span>
                      </DetailField>
                    )}

                    {detailMatches?.source_memories && detailMatches.source_memories.length > 0 && (
                      <div style={{ display: "flex", flexDirection: "column", gap: 4 }}>
                        <span style={{ fontSize: 9.5, fontWeight: 600, letterSpacing: "0.04em", textTransform: "uppercase", color: "var(--text-dim)" }}>
                          {t("memory.sourceMemories")}
                        </span>
                        {detailMatches.source_memories.map((source) => (
                          <JumpRow
                            key={source.id}
                            text={memoryPreview(source.text, 110)}
                            caption={formatMoment(source.occurred_start ?? source.mentioned_at, locale) ?? undefined}
                            onClick={() => selectMemory(source.id)}
                          />
                        ))}
                      </div>
                    )}

                    <div style={{ display: "flex", flexDirection: "column", gap: 4 }}>
                      <span style={{ fontSize: 9.5, fontWeight: 600, letterSpacing: "0.04em", textTransform: "uppercase", color: "var(--text-dim)" }}>
                        {t("memory.connectedMemories")}
                      </span>
                      {neighborNodes.length > 0 ? (
                        neighborNodes.map((neighbor) => {
                          const kind = memoryFactKind(neighbor.factKind);
                          return (
                            <JumpRow
                              key={neighbor.id}
                              text={memoryPreview(neighbor.label, 110)}
                              caption={kind ? t(FACT_LABEL_KEY[kind]) : undefined}
                              onClick={() => selectMemory(neighbor.id)}
                            />
                          );
                        })
                      ) : (
                        <span style={{ fontSize: 10.5, color: "var(--text-dim)" }}>{t("memory.noConnections")}</span>
                      )}
                    </div>

                    <div style={{ display: "flex", flexWrap: "wrap", gap: 6, borderTop: "1px solid var(--border)", paddingTop: 10 }}>
                      {isInvalidated ? (
                        <button
                          type="button"
                          onClick={() => void handleRestore()}
                          disabled={mutating}
                          style={{ ...solidButtonStyle, color: "var(--accent)", borderColor: "color-mix(in srgb, var(--accent) 45%, var(--border))" }}
                        >
                          {mutating ? toolbarSpinner : <RotateCcw size={12} aria-hidden="true" />}
                          {t("memory.restore")}
                        </button>
                      ) : (
                        <>
                          <button
                            type="button"
                            onClick={startEditing}
                            disabled={!detailMatches || isObservation || saving}
                            style={{ ...solidButtonStyle, opacity: !detailMatches || isObservation ? 0.5 : 1 }}
                          >
                            <Pencil size={12} aria-hidden="true" />
                            {t("memory.edit")}
                          </button>
                          <button
                            type="button"
                            onClick={() => {
                              setConfirmingInvalidate(true);
                              setEditing(false);
                            }}
                            disabled={!detailMatches || isObservation || mutating}
                            style={{
                              ...solidButtonStyle,
                              color: "var(--status-error)",
                              borderColor: "color-mix(in srgb, var(--status-error) 40%, var(--border))",
                              opacity: !detailMatches || isObservation ? 0.5 : 1,
                            }}
                          >
                            <Ban size={12} aria-hidden="true" />
                            {t("memory.invalidate")}
                          </button>
                        </>
                      )}
                    </div>

                    {confirmingInvalidate && (
                      <div
                        style={{
                          display: "flex",
                          flexDirection: "column",
                          gap: 6,
                          padding: "8px 9px",
                          borderRadius: 8,
                          border: "1px solid color-mix(in srgb, var(--status-error) 40%, var(--border))",
                          background: "var(--bg)",
                        }}
                      >
                        <span style={{ fontSize: 11, fontWeight: 600, color: "var(--text)" }}>{t("memory.invalidateConfirmTitle")}</span>
                        <input
                          value={invalidateReason}
                          onChange={(event) => setInvalidateReason(event.target.value)}
                          placeholder={t("memory.invalidateReasonPlaceholder")}
                          style={inputStyle}
                        />
                        <div style={{ display: "flex", gap: 6 }}>
                          <button
                            type="button"
                            onClick={() => void handleInvalidate()}
                            disabled={mutating}
                            style={{
                              ...solidButtonStyle,
                              color: "var(--status-error)",
                              borderColor: "color-mix(in srgb, var(--status-error) 45%, var(--border))",
                            }}
                          >
                            {mutating ? toolbarSpinner : <Ban size={11} aria-hidden="true" />}
                            {t("memory.confirmInvalidate")}
                          </button>
                          <button
                            type="button"
                            onClick={() => {
                              setConfirmingInvalidate(false);
                              setInvalidateReason("");
                            }}
                            disabled={mutating}
                            style={solidButtonStyle}
                          >
                            {t("memory.cancel")}
                          </button>
                        </div>
                      </div>
                    )}
                  </>
                )}
              </div>
            </div>
          )}
        </div>
      </section>
    </div>
  );
}
