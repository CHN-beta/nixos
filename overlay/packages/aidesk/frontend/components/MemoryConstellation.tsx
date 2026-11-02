import { useCallback, useEffect, useRef, useState } from "react";
import type { MemoryGraphEdge, MemoryGraphNode } from "@/lib/memory-types";

export interface MemoryConstellationLabels {
  graph: string;
  empty: string;
  world: string;
  experience: string;
  observation: string;
  semantic: string;
  temporal: string;
  entity: string;
  causal: string;
  zoomHint: string;
}

interface MemoryConstellationProps {
  nodes: MemoryGraphNode[];
  edges: MemoryGraphEdge[];
  selectedId: string | null;
  hoveredId: string | null;
  invalidatedIds: ReadonlySet<string>;
  paused: boolean;
  /** Increment to animate the camera back to a fitted view. */
  fitSignal: number;
  /** Pan the camera to a node; `nonce` makes repeated picks distinct. */
  focusSignal: { id: string; nonce: number } | null;
  labels: MemoryConstellationLabels;
  onSelect: (id: string | null) => void;
  onHover: (id: string | null) => void;
}

/**
 * A node of the constellation. Positions are closed-form (never simulated):
 * `wx`/`wy` are the node's home world coordinate and the ambient drift in the
 * render loop oscillates around it, so the field can never collapse.
 */
interface GraphNode {
  id: string;
  label: string;
  text: string;
  factKind: string | null;
  degree: number;
  radius: number;
  wx: number;
  wy: number;
  phase: number;
  clipChars: number;
  clipText: string;
}

interface GraphLink {
  a: number;
  b: number;
  linkType: string;
  /** Curve direction of the quadratic bend. */
  bend: number;
}

interface Palette {
  bg: string;
  text: string;
  muted: string;
  dim: string;
  accent: string;
  world: string;
  experience: string;
  observation: string;
  other: string;
  semantic: string;
  temporal: string;
  entity: string;
  causal: string;
  invalid: string;
}

interface DragState {
  mode: "pan" | "node";
  pointerId: number;
  node: GraphNode | null;
  startX: number;
  startY: number;
  cameraX: number;
  cameraY: number;
  moved: boolean;
}

interface HoverTip {
  label: string;
  text: string;
  kind: string | null;
}

interface Camera {
  x: number;
  y: number;
  scale: number;
}

interface Bounds {
  minX: number;
  minY: number;
  maxX: number;
  maxY: number;
}

interface FrameBuffers {
  x: Float32Array;
  y: Float32Array;
  driftX: Float32Array;
  driftY: Float32Array;
  visible: Uint8Array;
}

/** Ambient drift amplitude in world units. */
const DRIFT_AMP = 16;
/** Hard cap on batched background links drawn per frame. */
const MAX_LINKS = 6000;
/** Hard cap on labels drawn per frame (measureText is the expensive part). */
const MAX_LABELS = 240;
/** Label deconfliction grid cell in CSS pixels. */
const LABEL_GRID_CELL = 90;
const LABEL_FONT_SIZE = 11;
const LABEL_WIDTH_CACHE_LIMIT = 20000;

/**
 * Deterministic id hash. Used for ring placement, drift phase, and link bend so
 * that layout is stable across renders without any per-frame hashing. FNV-1a
 * plus a murmur3 finalizer: without the avalanche step, ids that differ only in
 * their last characters hash to neighbouring values, which collapses the ring
 * into visible arcs instead of an even annulus.
 */
function hashStr(value: string): number {
  let hash = 0x811c9dc5;
  for (let index = 0; index < value.length; index += 1) {
    hash ^= value.charCodeAt(index);
    hash = Math.imul(hash, 16777619);
  }
  hash ^= hash >>> 16;
  hash = Math.imul(hash, 0x7feb352d);
  hash ^= hash >>> 15;
  hash = Math.imul(hash, 0x846ca68b);
  hash ^= hash >>> 16;
  return hash | 0;
}

function clipLabel(label: string, max: number): string {
  const flat = label.replace(/\s+/g, " ").trim();
  return flat.length <= max ? flat : `${flat.slice(0, max - 1).trimEnd()}…`;
}

/** Integer key for a label-deconfliction cell; avoids per-frame string allocs. */
function labelCellKey(col: number, row: number): number {
  return (col + 4096) * 8192 + (row + 4096);
}

function readPalette(): Palette {
  const styles = getComputedStyle(document.documentElement);
  const read = (name: string, fallback: string) => styles.getPropertyValue(name).trim() || fallback;
  const accent = read("--accent", "#B03E22");
  return {
    bg: read("--bg", "#FAF9F6"),
    text: read("--text", "#2B2823"),
    muted: read("--text-muted", "#69635A"),
    dim: read("--text-dim", "#6A6458"),
    accent,
    world: accent,
    experience: read("--status-success", "#18794E"),
    observation: read("--status-warning", "#8A5A00"),
    other: read("--text-muted", "#69635A"),
    semantic: accent,
    temporal: read("--status-modified", "#A87B1F"),
    entity: read("--status-renamed", "#2563EB"),
    causal: read("--status-error", "#B42318"),
    invalid: read("--text-dim", "#6A6458"),
  };
}

/** World-space extent of the layout, padded by drift, for camera fitting. */
function computeBounds(graphNodes: GraphNode[]): Bounds | null {
  if (graphNodes.length === 0) return null;
  let minX = Infinity;
  let minY = Infinity;
  let maxX = -Infinity;
  let maxY = -Infinity;
  for (const node of graphNodes) {
    const reach = node.radius + DRIFT_AMP;
    if (node.wx - reach < minX) minX = node.wx - reach;
    if (node.wy - reach < minY) minY = node.wy - reach;
    if (node.wx + reach > maxX) maxX = node.wx + reach;
    if (node.wy + reach > maxY) maxY = node.wy + reach;
  }
  return { minX, minY, maxX, maxY };
}

function linkColor(type: string, palette: Palette): string {
  if (type === "temporal") return palette.temporal;
  if (type === "entity") return palette.entity;
  if (type === "causal") return palette.causal;
  return palette.semantic;
}

function nodeColor(node: GraphNode, palette: Palette, invalid: boolean): string {
  if (invalid) return palette.invalid;
  if (node.factKind === "world") return palette.world;
  if (node.factKind === "experience") return palette.experience;
  if (node.factKind === "observation") return palette.observation;
  return palette.other;
}

/**
 * Canvas "Constellation" graph for Hindsight memory units.
 *
 * Layout is a closed-form polar ring derived from the node id hash (no physics
 * loop), so the graph is fully formed on the first frame and can never
 * collapse into a pile. Nodes breathe around their home position while idle
 * is off; pausing freezes the ambient clock in place.
 */
export function MemoryConstellation({
  nodes,
  edges,
  selectedId,
  hoveredId,
  invalidatedIds,
  paused,
  fitSignal,
  focusSignal,
  labels,
  onSelect,
  onHover,
}: MemoryConstellationProps) {
  const wrapperRef = useRef<HTMLDivElement>(null);
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const tooltipRef = useRef<HTMLDivElement>(null);
  const sizeRef = useRef({ width: 0, height: 0 });
  const cameraRef = useRef<Camera>({ x: 0, y: 0, scale: 1 });
  const cameraTargetRef = useRef<Camera | null>(null);
  const nodesRef = useRef<GraphNode[]>([]);
  const indexByIdRef = useRef<Map<string, number>>(new Map());
  const linksRef = useRef<GraphLink[]>([]);
  const linksByNodeRef = useRef<Map<number, number[]>>(new Map());
  const linksByTypeRef = useRef<Array<{ type: string; indices: number[] }>>([]);
  const boundsRef = useRef<Bounds | null>(null);
  const manualPositionsRef = useRef<Map<string, { x: number; y: number }>>(new Map());
  const frameRef = useRef<FrameBuffers>({
    x: new Float32Array(0),
    y: new Float32Array(0),
    driftX: new Float32Array(0),
    driftY: new Float32Array(0),
    visible: new Uint8Array(0),
  });
  const labelWidthsRef = useRef<Map<string, number>>(new Map());
  const labelFontRef = useRef("");
  const signatureRef = useRef("");
  const pendingFitRef = useRef(true);
  const dragRef = useRef<DragState | null>(null);
  const pointerHoverRef = useRef<string | null>(null);
  const paletteRef = useRef<Palette | null>(null);
  const tooltipPosRef = useRef({ left: 0, top: 0 });

  const stateRef = useRef({ selectedId, hoveredId, invalidatedIds, paused });
  const labelsRef = useRef(labels);
  const callbacksRef = useRef({ onSelect, onHover });
  const [hoverTip, setHoverTip] = useState<HoverTip | null>(null);

  useEffect(() => {
    stateRef.current = { selectedId, hoveredId, invalidatedIds, paused };
  }, [selectedId, hoveredId, invalidatedIds, paused]);
  useEffect(() => {
    labelsRef.current = labels;
  }, [labels]);
  useEffect(() => {
    callbacksRef.current = { onSelect, onHover };
  }, [onSelect, onHover]);

  const fitToView = useCallback((animate: boolean) => {
    const bounds = boundsRef.current;
    const { width, height } = sizeRef.current;
    if (!bounds || width <= 0 || height <= 0) return;
    const padding = 90;
    const spanX = Math.max(1, bounds.maxX - bounds.minX);
    const spanY = Math.max(1, bounds.maxY - bounds.minY);
    const scale = Math.min(
      1.8,
      Math.max(
        0.08,
        Math.min((width - padding * 2) / spanX, (height - padding * 2) / spanY),
      ),
    );
    const target: Camera = {
      x: (bounds.minX + bounds.maxX) / 2,
      y: (bounds.minY + bounds.maxY) / 2,
      scale,
    };
    if (animate) {
      cameraTargetRef.current = target;
    } else {
      cameraRef.current = { ...target };
      cameraTargetRef.current = null;
    }
  }, []);

  // Build the closed-form layout. No iteration, no settling: every node gets a
  // deterministic home on an annulus (`0.3R..1.0R`) ordered by index, with the
  // id hash only jittering radius/offset so the ring reads as organic.
  useEffect(() => {
    const degree = new Map<string, number>();
    for (const edge of edges) {
      degree.set(edge.data.source, (degree.get(edge.data.source) ?? 0) + 1);
      degree.set(edge.data.target, (degree.get(edge.data.target) ?? 0) + 1);
    }

    const count = nodes.length;
    const baseRadius = Math.sqrt(Math.max(count, 1)) * 30;
    const manual = manualPositionsRef.current;
    const nextNodes: GraphNode[] = [];
    const indexById = new Map<string, number>();

    for (let index = 0; index < count; index += 1) {
      const entry = nodes[index];
      const id = entry.data.id;
      if (indexById.has(id)) continue;
      const nodeDegree = degree.get(id) ?? 0;
      const seed = hashStr(id);

      let wx: number;
      let wy: number;
      const pinned = manual.get(id);
      if (pinned) {
        wx = pinned.x;
        wy = pinned.y;
      } else {
        const angle =
          (index / Math.max(count, 1)) * Math.PI * 2 + ((Math.abs(seed % 100)) / 100) * 0.5;
        const radius =
          baseRadius * 0.3 + ((Math.abs(seed) % 1000) / 1000) * baseRadius * 0.7;
        wx = Math.cos(angle) * radius + ((seed % 200) - 100) * 0.5;
        wy = Math.sin(angle) * radius + (((seed >> 8) % 200) - 100) * 0.5;
      }

      indexById.set(id, nextNodes.length);
      nextNodes.push({
        id,
        label: entry.data.label,
        text: entry.data.text,
        factKind: entry.data.factType ?? null,
        degree: nodeDegree,
        radius: Math.min(16, 5 + Math.sqrt(nodeDegree) * 2.1),
        wx,
        wy,
        phase: ((Math.abs(seed) % 1000) / 1000) * Math.PI * 2,
        clipChars: -1,
        clipText: "",
      });
    }

    for (const key of manual.keys()) {
      if (!indexById.has(key)) manual.delete(key);
    }

    // Keep an in-flight node drag attached to the rebuilt node instance.
    const drag = dragRef.current;
    if (drag && drag.mode === "node" && drag.node) {
      const dragIndex = indexById.get(drag.node.id);
      if (dragIndex === undefined) dragRef.current = null;
      else drag.node = nextNodes[dragIndex];
    }

    boundsRef.current = computeBounds(nextNodes);

    // Integer-indexed links plus a per-node adjacency table, so the render loop
    // never hashes a string or walks the edge list to find a node's links.
    const nextLinks: GraphLink[] = [];
    const linksByNode = new Map<number, number[]>();
    const typeBuckets = new Map<string, number[]>();
    for (const edge of edges) {
      const a = indexById.get(edge.data.source);
      const b = indexById.get(edge.data.target);
      if (a === undefined || b === undefined || a === b) continue;
      const linkType = edge.data.linkType ?? "semantic";
      const linkIndex = nextLinks.length;
      nextLinks.push({
        a,
        b,
        linkType,
        bend: (hashStr(edge.data.id) & 1) === 0 ? 1 : -1,
      });
      const aLinks = linksByNode.get(a);
      if (aLinks) aLinks.push(linkIndex);
      else linksByNode.set(a, [linkIndex]);
      const bLinks = linksByNode.get(b);
      if (bLinks) bLinks.push(linkIndex);
      else linksByNode.set(b, [linkIndex]);
      const bucket = typeBuckets.get(linkType);
      if (bucket) bucket.push(linkIndex);
      else typeBuckets.set(linkType, [linkIndex]);
    }

    nodesRef.current = nextNodes;
    indexByIdRef.current = indexById;
    linksRef.current = nextLinks;
    linksByNodeRef.current = linksByNode;
    linksByTypeRef.current = Array.from(typeBuckets, ([type, indices]) => ({ type, indices }));

    const signature = nodes.map((node) => node.data.id).join("\u0000");
    if (signature !== signatureRef.current) {
      signatureRef.current = signature;
      if (sizeRef.current.width > 0 && nextNodes.length > 0) {
        pendingFitRef.current = false;
        fitToView(false);
      } else {
        pendingFitRef.current = nextNodes.length > 0;
      }
    }
  }, [nodes, edges, fitToView]);

  useEffect(() => {
    fitToView(true);
  }, [fitSignal, fitToView]);

  useEffect(() => {
    if (!focusSignal) return;
    const index = indexByIdRef.current.get(focusSignal.id);
    if (index === undefined) return;
    const node = nodesRef.current[index];
    if (!node) return;
    cameraTargetRef.current = {
      x: node.wx,
      y: node.wy,
      scale: Math.max(cameraRef.current.scale, 1.2),
    };
  }, [focusSignal]);

  const findNodeAt = useCallback((screenX: number, screenY: number): GraphNode | null => {
    const camera = cameraRef.current;
    const { width, height } = sizeRef.current;
    const graphNodes = nodesRef.current;
    const frame = frameRef.current;
    const scale = camera.scale;
    let best: GraphNode | null = null;
    let bestDistance = Infinity;
    for (let index = 0; index < graphNodes.length; index += 1) {
      const node = graphNodes[index];
      const driftX = index < frame.driftX.length ? frame.driftX[index] : 0;
      const driftY = index < frame.driftY.length ? frame.driftY[index] : 0;
      const nodeX = (node.wx + driftX - camera.x) * scale + width / 2;
      const nodeY = (node.wy + driftY - camera.y) * scale + height / 2;
      const distance = Math.hypot(screenX - nodeX, screenY - nodeY);
      const hitRadius = Math.max(10, node.radius * scale + 6);
      if (distance <= hitRadius && distance < bestDistance) {
        best = node;
        bestDistance = distance;
      }
    }
    return best;
  }, []);

  // Paint loop: ambient drift, batched typed edges, deconflicted labels.
  useEffect(() => {
    const canvas = canvasRef.current;
    const wrapper = wrapperRef.current;
    if (!canvas || !wrapper) return;
    const context = canvas.getContext("2d");
    if (!context) return;

    paletteRef.current = readPalette();
    let fontFamily = getComputedStyle(wrapper).fontFamily || "system-ui, sans-serif";

    const resize = () => {
      const rect = wrapper.getBoundingClientRect();
      const width = Math.max(1, Math.round(rect.width));
      const height = Math.max(1, Math.round(rect.height));
      sizeRef.current = { width, height };
      const dpr = window.devicePixelRatio || 1;
      canvas.width = Math.round(width * dpr);
      canvas.height = Math.round(height * dpr);
      canvas.style.width = `${width}px`;
      canvas.style.height = `${height}px`;
      if (pendingFitRef.current && nodesRef.current.length > 0) {
        pendingFitRef.current = false;
        fitToView(false);
      }
    };
    resize();

    const resizeObserver = new ResizeObserver(resize);
    resizeObserver.observe(wrapper);

    const themeObserver = new MutationObserver(() => {
      paletteRef.current = readPalette();
      fontFamily = getComputedStyle(wrapper).fontFamily || fontFamily;
    });
    themeObserver.observe(document.documentElement, {
      attributes: true,
      attributeFilter: ["class", "data-theme", "style"],
    });

    const frame = frameRef.current;
    const labelGrid = new Set<number>();
    const neighborSet = new Set<number>();
    let frameId = 0;
    let lastFrame = performance.now();
    let motionMs = 0;

    const render = (now: number) => {
      frameId = requestAnimationFrame(render);
      const dt = Math.min(64, Math.max(0, now - lastFrame));
      lastFrame = now;

      const size = sizeRef.current;
      if (size.width <= 0 || size.height <= 0) return;
      const width = size.width;
      const height = size.height;
      const palette = paletteRef.current ?? (paletteRef.current = readPalette());
      const state = stateRef.current;

      // Ambient clock: only advances while motion is enabled, so pausing holds
      // every drift/pulse/twinkle exactly where it is.
      if (!state.paused) motionMs += dt;
      const time = motionMs / 1000;

      const camera = cameraRef.current;
      const cameraTarget = cameraTargetRef.current;
      if (cameraTarget) {
        const ease = Math.min(1, 0.16 * Math.min(2, dt / 16.67));
        camera.x += (cameraTarget.x - camera.x) * ease;
        camera.y += (cameraTarget.y - camera.y) * ease;
        camera.scale += (cameraTarget.scale - camera.scale) * ease;
        if (
          Math.abs(cameraTarget.x - camera.x) < 0.4 &&
          Math.abs(cameraTarget.y - camera.y) < 0.4 &&
          Math.abs(cameraTarget.scale - camera.scale) < 0.002
        ) {
          cameraTargetRef.current = null;
        }
      }

      const dpr = window.devicePixelRatio || 1;
      const pixelWidth = Math.round(width * dpr);
      const pixelHeight = Math.round(height * dpr);
      if (canvas.width !== pixelWidth || canvas.height !== pixelHeight) {
        canvas.width = pixelWidth;
        canvas.height = pixelHeight;
      }
      context.setTransform(dpr, 0, 0, dpr, 0, 0);
      context.clearRect(0, 0, width, height);
      context.fillStyle = palette.bg;
      context.fillRect(0, 0, width, height);
      context.globalAlpha = 1;

      const graphNodes = nodesRef.current;
      const count = graphNodes.length;
      if (count === 0) {
        context.fillStyle = palette.dim;
        context.font = `13px ${fontFamily}`;
        context.textAlign = "center";
        context.textBaseline = "middle";
        context.fillText(labelsRef.current.empty, width / 2, height / 2);
        return;
      }

      if (frame.x.length < count) {
        const capacity = Math.max(64, count * 2);
        frame.x = new Float32Array(capacity);
        frame.y = new Float32Array(capacity);
        frame.driftX = new Float32Array(capacity);
        frame.driftY = new Float32Array(capacity);
        frame.visible = new Uint8Array(capacity);
      }
      const screenX = frame.x;
      const screenY = frame.y;
      const visible = frame.visible;
      const camX = camera.x;
      const camY = camera.y;
      const zoom = camera.scale;
      const centerX = width / 2;
      const centerY = height / 2;
      const margin = 60;

      const draggedNode = dragRef.current?.mode === "node" ? dragRef.current.node : null;
      for (let index = 0; index < count; index += 1) {
        const node = graphNodes[index];
        let driftX = 0;
        let driftY = 0;
        if (node !== draggedNode) {
          driftX = DRIFT_AMP * Math.sin(time * 0.6 + node.phase);
          driftY = DRIFT_AMP * Math.cos(time * 0.5 + node.phase * 1.3);
        }
        frame.driftX[index] = driftX;
        frame.driftY[index] = driftY;
        const sx = centerX + (node.wx + driftX - camX) * zoom;
        const sy = centerY + (node.wy + driftY - camY) * zoom;
        screenX[index] = sx;
        screenY[index] = sy;
        visible[index] = sx > -margin && sx < width + margin && sy > -margin && sy < height + margin ? 1 : 0;
      }

      const hoveredId = pointerHoverRef.current ?? state.hoveredId;
      const hoverIndex = hoveredId ? (indexByIdRef.current.get(hoveredId) ?? -1) : -1;
      const selectedIndex = state.selectedId ? (indexByIdRef.current.get(state.selectedId) ?? -1) : -1;
      const focusIndex = hoverIndex >= 0 ? hoverIndex : selectedIndex;
      const focusMode = focusIndex >= 0;
      const links = linksRef.current;
      const linksByNode = linksByNodeRef.current;

      neighborSet.clear();
      if (focusMode) {
        neighborSet.add(focusIndex);
        const adjacent = linksByNode.get(focusIndex);
        if (adjacent) {
          for (let index = 0; index < adjacent.length; index += 1) {
            const link = links[adjacent[index]];
            neighborSet.add(link.a === focusIndex ? link.b : link.a);
          }
        }
      }

      // --- Links: faint batched web (one stroke per link type) ---
      const shimmer = 1 + 0.18 * Math.sin(time * 0.6);
      const baseAlpha = focusMode ? 0.06 : Math.min(0.18, (0.06 + zoom * 0.04) * shimmer);
      context.lineWidth = 0.55;
      context.globalAlpha = baseAlpha;
      let drawnLinks = 0;
      const groups = linksByTypeRef.current;
      for (let groupIndex = 0; groupIndex < groups.length; groupIndex += 1) {
        if (drawnLinks >= MAX_LINKS) break;
        const group = groups[groupIndex];
        context.strokeStyle = linkColor(group.type, palette);
        context.beginPath();
        const indices = group.indices;
        for (let index = 0; index < indices.length; index += 1) {
          if (drawnLinks >= MAX_LINKS) break;
          const link = links[indices[index]];
          const ax = screenX[link.a];
          const ay = screenY[link.a];
          const bx = screenX[link.b];
          const by = screenY[link.b];
          if (
            (ax < -margin && bx < -margin) ||
            (ax > width + margin && bx > width + margin) ||
            (ay < -margin && by < -margin) ||
            (ay > height + margin && by > height + margin)
          ) {
            continue;
          }
          const dx = bx - ax;
          const dy = by - ay;
          context.moveTo(ax, ay);
          context.quadraticCurveTo(
            (ax + bx) / 2 + dy * 0.08 * link.bend,
            (ay + by) / 2 - dx * 0.08 * link.bend,
            bx,
            by,
          );
          drawnLinks += 1;
        }
        context.stroke();
      }
      context.globalAlpha = 1;

      // --- Focused neighborhood: bright edges plus travelling light beads ---
      if (focusMode) {
        const adjacent = linksByNode.get(focusIndex);
        if (adjacent) {
          for (let index = 0; index < adjacent.length; index += 1) {
            const linkIndex = adjacent[index];
            const link = links[linkIndex];
            const ax = screenX[link.a];
            const ay = screenY[link.a];
            const bx = screenX[link.b];
            const by = screenY[link.b];
            const dx = bx - ax;
            const dy = by - ay;
            const controlX = (ax + bx) / 2 + dy * 0.08 * link.bend;
            const controlY = (ay + by) / 2 - dx * 0.08 * link.bend;
            const color = linkColor(link.linkType, palette);

            context.strokeStyle = color;
            context.globalAlpha = 0.62;
            context.lineWidth = 1.6;
            context.beginPath();
            context.moveTo(ax, ay);
            context.quadraticCurveTo(controlX, controlY, bx, by);
            context.stroke();

            // Bead phase-offset per link, travelling from the focused node out.
            const fromFocus = link.a === focusIndex;
            const raw = (time * 0.22 + (linkIndex % 13) / 13) % 1;
            const u = fromFocus ? raw : 1 - raw;
            const inverse = 1 - u;
            const beadX = inverse * inverse * ax + 2 * inverse * u * controlX + u * u * bx;
            const beadY = inverse * inverse * ay + 2 * inverse * u * controlY + u * u * by;
            context.globalAlpha = 0.9 * (0.35 + 0.65 * Math.sin(u * Math.PI));
            context.fillStyle = color;
            context.beginPath();
            context.arc(beadX, beadY, 2, 0, Math.PI * 2);
            context.fill();
          }
        }
        context.globalAlpha = 1;
      }

      // --- Nodes: background pass, then the focused neighborhood on top ---
      const drawNode = (index: number) => {
        if (!visible[index]) return;
        const node = graphNodes[index];
        const nodeX = screenX[index];
        const nodeY = screenY[index];
        const isSelected = index === selectedIndex;
        const isHovered = index === hoverIndex;
        const isFocus = isSelected || isHovered;
        const isNeighbor = neighborSet.has(index);
        const isDim = focusMode && !isNeighbor;
        const isInvalid = state.invalidatedIds.has(node.id);
        const pulse = 1 + 0.09 * Math.sin(time * 1.05 + node.phase);
        const radius = Math.max(2.2, Math.min(24, node.radius * pulse * zoom));
        const color = nodeColor(node, palette, isInvalid);

        if (isFocus) {
          context.globalAlpha = isSelected ? 0.28 : 0.18;
          context.fillStyle = color;
          context.beginPath();
          context.arc(nodeX, nodeY, radius + 8, 0, Math.PI * 2);
          context.fill();
          context.globalAlpha = 0.85;
          context.strokeStyle = color;
          context.lineWidth = 1.6;
          context.beginPath();
          context.arc(nodeX, nodeY, radius + 3.5, 0, Math.PI * 2);
          context.stroke();
        }

        const twinkle = 0.86 + 0.14 * Math.sin(time * 1.4 + node.phase * 2.1);
        context.globalAlpha = isInvalid ? (isDim ? 0.12 : 0.5) : isDim ? 0.18 : isFocus ? 1 : twinkle;
        context.fillStyle = color;
        context.beginPath();
        context.arc(nodeX, nodeY, radius, 0, Math.PI * 2);
        context.fill();

        if (radius > 4.5 || isInvalid) {
          context.globalAlpha = isDim ? 0.25 : 0.9;
          context.strokeStyle = palette.bg;
          context.lineWidth = 1.4;
          if (isInvalid) {
            context.setLineDash([2.5, 2.5]);
            context.strokeStyle = palette.invalid;
          }
          context.stroke();
          context.setLineDash([]);
        }

        if (node.degree === 0) {
          context.globalAlpha = isDim ? 0.2 : 0.55;
          context.strokeStyle = color;
          context.lineWidth = 1;
          context.beginPath();
          context.arc(nodeX, nodeY, radius + 2.5, 0, Math.PI * 2);
          context.stroke();
        }
        context.globalAlpha = 1;
      };

      for (let index = 0; index < count; index += 1) {
        if (!neighborSet.has(index)) drawNode(index);
      }
      neighborSet.forEach((index) => {
        if (index !== focusIndex) drawNode(index);
      });
      if (focusMode) drawNode(focusIndex);

      // --- Labels: focus first, then neighbors, then zoomed-in nodes ---
      if (labelFontRef.current !== fontFamily) {
        labelFontRef.current = fontFamily;
        labelWidthsRef.current.clear();
      }
      const labelWidths = labelWidthsRef.current;
      if (labelWidths.size > LABEL_WIDTH_CACHE_LIMIT) labelWidths.clear();
      const normalFont = `500 ${LABEL_FONT_SIZE}px ${fontFamily}`;
      const strongFont = `600 ${LABEL_FONT_SIZE}px ${fontFamily}`;
      labelGrid.clear();
      let labelsDrawn = 0;
      const maxChars = zoom >= 1.4 ? 40 : zoom >= 0.8 ? 28 : 18;
      context.textAlign = "center";
      context.textBaseline = "middle";

      const drawLabel = (index: number, force: boolean) => {
        if (labelsDrawn >= MAX_LABELS) return;
        if (!force && !(focusMode && neighborSet.has(index)) && zoom <= 0.5) return;
        const node = graphNodes[index];
        if (!node.label) return;
        const nodeX = screenX[index];
        const nodeY = screenY[index];
        if (nodeX < -140 || nodeX > width + 140 || nodeY < -40 || nodeY > height + 40) return;
        if (node.clipChars !== maxChars) {
          node.clipText = clipLabel(node.label, maxChars);
          node.clipChars = maxChars;
        }
        const label = node.clipText;
        let textWidth = labelWidths.get(label);
        if (textWidth === undefined) {
          context.font = strongFont;
          textWidth = context.measureText(label).width;
          labelWidths.set(label, textWidth);
        }
        const radius = Math.max(2.2, Math.min(24, node.radius * zoom));
        const left = nodeX - textWidth / 2;
        const top = nodeY + radius + 5;

        if (!force) {
          const colStart = Math.floor((left - 4) / LABEL_GRID_CELL);
          const colEnd = Math.floor((left + textWidth + 4) / LABEL_GRID_CELL);
          const rowStart = Math.floor((top - 2) / LABEL_GRID_CELL);
          const rowEnd = Math.floor((top + 14) / LABEL_GRID_CELL);
          for (let col = colStart; col <= colEnd; col += 1) {
            for (let row = rowStart; row <= rowEnd; row += 1) {
              if (labelGrid.has(labelCellKey(col, row))) return;
            }
          }
          for (let col = colStart; col <= colEnd; col += 1) {
            for (let row = rowStart; row <= rowEnd; row += 1) {
              labelGrid.add(labelCellKey(col, row));
            }
          }
        }

        const strong = force && index === focusIndex;
        context.font = strong ? strongFont : normalFont;
        context.globalAlpha = 0.72;
        context.fillStyle = palette.bg;
        if (typeof context.roundRect === "function") {
          context.beginPath();
          context.roundRect(left - 4, top - 2, textWidth + 8, 16, 4);
          context.fill();
        } else {
          context.fillRect(left - 4, top - 2, textWidth + 8, 16);
        }
        context.globalAlpha = strong ? 0.98 : 0.85;
        context.fillStyle = strong ? palette.text : palette.muted;
        context.fillText(label, nodeX, top + 6);
        labelsDrawn += 1;
      };

      if (focusMode) {
        drawLabel(focusIndex, true);
        neighborSet.forEach((index) => {
          if (index !== focusIndex) drawLabel(index, false);
        });
      }
      if (zoom > 0.5 && labelsDrawn < MAX_LABELS) {
        for (let index = 0; index < count; index += 1) {
          if (labelsDrawn >= MAX_LABELS) break;
          if (neighborSet.has(index)) continue;
          drawLabel(index, false);
        }
      }
      context.globalAlpha = 1;
    };

    frameId = requestAnimationFrame(render);
    return () => {
      cancelAnimationFrame(frameId);
      resizeObserver.disconnect();
      themeObserver.disconnect();
    };
  }, [fitToView]);

  // Native wheel listener so zoom can prevent page scroll reliably.
  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const handleWheel = (event: WheelEvent) => {
      event.preventDefault();
      const rect = canvas.getBoundingClientRect();
      const pointerX = event.clientX - rect.left;
      const pointerY = event.clientY - rect.top;
      const camera = cameraRef.current;
      const { width, height } = sizeRef.current;
      const worldX = (pointerX - width / 2) / camera.scale + camera.x;
      const worldY = (pointerY - height / 2) / camera.scale + camera.y;
      const nextScale = Math.min(3.4, Math.max(0.08, camera.scale * Math.exp(-event.deltaY * 0.0014)));
      camera.scale = nextScale;
      camera.x = worldX - (pointerX - width / 2) / nextScale;
      camera.y = worldY - (pointerY - height / 2) / nextScale;
      cameraTargetRef.current = null;
    };
    canvas.addEventListener("wheel", handleWheel, { passive: false });
    return () => canvas.removeEventListener("wheel", handleWheel);
  }, []);

  // Tooltip position is written straight to the DOM; React state only changes
  // when the hovered node changes, so pointer moves never trigger a render.
  const moveTooltip = (x: number, y: number) => {
    const { width, height } = sizeRef.current;
    const left = Math.max(8, Math.min(x + 14, Math.max(8, width - 250)));
    const top = Math.max(8, Math.min(y + 14, Math.max(8, height - 108)));
    tooltipPosRef.current = { left, top };
    const element = tooltipRef.current;
    if (element) element.style.transform = `translate3d(${left}px, ${top}px, 0)`;
  };

  const handlePointerDown = (event: React.PointerEvent<HTMLCanvasElement>) => {
    const rect = event.currentTarget.getBoundingClientRect();
    const x = event.clientX - rect.left;
    const y = event.clientY - rect.top;
    try {
      event.currentTarget.setPointerCapture(event.pointerId);
    } catch {
      // Synthetic pointer events (automation) have no active pointer to capture.
    }
    setHoverTip(null);
    const hit = findNodeAt(x, y);
    dragRef.current = {
      mode: hit ? "node" : "pan",
      pointerId: event.pointerId,
      node: hit,
      startX: x,
      startY: y,
      cameraX: cameraRef.current.x,
      cameraY: cameraRef.current.y,
      moved: false,
    };
    event.currentTarget.style.cursor = "grabbing";
  };

  const handlePointerMove = (event: React.PointerEvent<HTMLCanvasElement>) => {
    const rect = event.currentTarget.getBoundingClientRect();
    const x = event.clientX - rect.left;
    const y = event.clientY - rect.top;
    const drag = dragRef.current;
    if (drag && drag.pointerId === event.pointerId) {
      if (drag.mode === "pan") {
        const deltaX = x - drag.startX;
        const deltaY = y - drag.startY;
        if (Math.abs(deltaX) + Math.abs(deltaY) > 2) drag.moved = true;
        cameraRef.current.x = drag.cameraX - deltaX / cameraRef.current.scale;
        cameraRef.current.y = drag.cameraY - deltaY / cameraRef.current.scale;
        cameraTargetRef.current = null;
      } else if (drag.node) {
        const camera = cameraRef.current;
        if (Math.abs(x - drag.startX) + Math.abs(y - drag.startY) > 2) drag.moved = true;
        drag.node.wx = (x - sizeRef.current.width / 2) / camera.scale + camera.x;
        drag.node.wy = (y - sizeRef.current.height / 2) / camera.scale + camera.y;
        manualPositionsRef.current.set(drag.node.id, { x: drag.node.wx, y: drag.node.wy });
      }
      return;
    }

    const hit = findNodeAt(x, y);
    const hoverId = hit ? hit.id : null;
    moveTooltip(x, y);
    if (hoverId !== pointerHoverRef.current) {
      pointerHoverRef.current = hoverId;
      callbacksRef.current.onHover(hoverId);
      event.currentTarget.style.cursor = hit ? "pointer" : "grab";
      setHoverTip(
        hit ? { label: hit.label, text: hit.text, kind: hit.factKind } : null,
      );
    }
  };

  const handlePointerUp = (event: React.PointerEvent<HTMLCanvasElement>) => {
    const drag = dragRef.current;
    dragRef.current = null;
    if (event.currentTarget.hasPointerCapture(event.pointerId)) {
      event.currentTarget.releasePointerCapture(event.pointerId);
    }
    event.currentTarget.style.cursor = "grab";
    if (!drag) return;
    if (drag.mode === "node" && drag.node) {
      manualPositionsRef.current.set(drag.node.id, { x: drag.node.wx, y: drag.node.wy });
      boundsRef.current = computeBounds(nodesRef.current);
      if (!drag.moved) callbacksRef.current.onSelect(drag.node.id);
    } else if (drag.mode === "pan" && !drag.moved) {
      callbacksRef.current.onSelect(null);
    }
  };

  const handlePointerLeave = () => {
    if (dragRef.current) return;
    pointerHoverRef.current = null;
    callbacksRef.current.onHover(null);
    setHoverTip(null);
  };

  const kindLabel =
    hoverTip?.kind === "world"
      ? labels.world
      : hoverTip?.kind === "experience"
        ? labels.experience
        : hoverTip?.kind === "observation"
          ? labels.observation
          : null;

  return (
    <div ref={wrapperRef} style={{ position: "relative", flex: 1, minWidth: 0, minHeight: 0, overflow: "hidden", background: "var(--bg)" }}>
      <canvas
        ref={canvasRef}
        role="img"
        aria-label={labels.graph}
        style={{ position: "absolute", inset: 0, display: "block", touchAction: "none", cursor: "grab" }}
        onPointerDown={handlePointerDown}
        onPointerMove={handlePointerMove}
        onPointerUp={handlePointerUp}
        onPointerCancel={handlePointerUp}
        onPointerLeave={handlePointerLeave}
      />

      <div
        style={{
          position: "absolute",
          left: 10,
          bottom: 10,
          display: "flex",
          flexDirection: "column",
          gap: 5,
          padding: "7px 9px",
          borderRadius: 8,
          border: "1px solid var(--border)",
          background: "color-mix(in srgb, var(--bg-panel) 80%, transparent)",
          backdropFilter: "blur(4px)",
          pointerEvents: "none",
          fontSize: 9.5,
          lineHeight: 1.35,
          color: "var(--text-muted)",
          maxWidth: "calc(100% - 20px)",
        }}
      >
        <div style={{ display: "flex", flexWrap: "wrap", gap: "3px 10px" }}>
          <LegendDot color="var(--accent)" label={labels.world} />
          <LegendDot color="var(--status-success)" label={labels.experience} />
          <LegendDot color="var(--status-warning)" label={labels.observation} />
        </div>
        <div style={{ display: "flex", flexWrap: "wrap", gap: "3px 10px" }}>
          <LegendLine color="var(--accent)" label={labels.semantic} />
          <LegendLine color="var(--status-modified)" label={labels.temporal} />
          <LegendLine color="var(--status-renamed)" label={labels.entity} />
          <LegendLine color="var(--status-error)" label={labels.causal} />
        </div>
        <span style={{ color: "var(--text-dim)" }}>{labels.zoomHint}</span>
      </div>

      {hoverTip && (
        <div
          ref={tooltipRef}
          style={{
            position: "absolute",
            left: 0,
            top: 0,
            transform: `translate3d(${tooltipPosRef.current.left}px, ${tooltipPosRef.current.top}px, 0)`,
            width: 236,
            padding: "8px 10px",
            borderRadius: 8,
            border: "1px solid var(--border)",
            background: "var(--bg-panel)",
            boxShadow: "var(--shadow-pop)",
            pointerEvents: "none",
            display: "flex",
            flexDirection: "column",
            gap: 3,
            zIndex: 2,
            willChange: "transform",
          }}
        >
          <span style={{ fontSize: 11.5, fontWeight: 600, color: "var(--text)", overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>
            {hoverTip.label}
          </span>
          <span style={{ fontSize: 10.5, lineHeight: 1.4, color: "var(--text-muted)", display: "-webkit-box", WebkitLineClamp: 4, WebkitBoxOrient: "vertical", overflow: "hidden" }}>
            {clipLabel(hoverTip.text, 180)}
          </span>
          {kindLabel && <span style={{ fontSize: 9.5, color: "var(--text-dim)" }}>{kindLabel}</span>}
        </div>
      )}
    </div>
  );
}

function LegendDot({ color, label }: { color: string; label: string }) {
  return (
    <span style={{ display: "inline-flex", alignItems: "center", gap: 4, whiteSpace: "nowrap" }}>
      <span style={{ width: 7, height: 7, borderRadius: "50%", background: color, flexShrink: 0 }} />
      {label}
    </span>
  );
}

function LegendLine({ color, label }: { color: string; label: string }) {
  return (
    <span style={{ display: "inline-flex", alignItems: "center", gap: 4, whiteSpace: "nowrap" }}>
      <span style={{ width: 11, height: 2, borderRadius: 1, background: color, flexShrink: 0 }} />
      {label}
    </span>
  );
}
