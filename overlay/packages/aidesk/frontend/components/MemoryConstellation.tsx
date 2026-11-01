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

interface SimNode {
  id: string;
  label: string;
  text: string;
  factKind: string | null;
  degree: number;
  radius: number;
  x: number;
  y: number;
  vx: number;
  vy: number;
  pinned: boolean;
  phase: number;
}

interface SimEdge {
  id: string;
  source: SimNode;
  target: SimNode;
  linkType: string;
  weight: number;
}

interface Palette {
  bg: string;
  text: string;
  muted: string;
  dim: string;
  border: string;
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
  node: SimNode | null;
  startX: number;
  startY: number;
  cameraX: number;
  cameraY: number;
  moved: boolean;
}

interface HoverTip {
  x: number;
  y: number;
  label: string;
  text: string;
  kind: string | null;
}

const REPULSION = 1400;
const REPULSION_RADIUS = 300;
const CELL_SIZE = 260;
const CELL_OFFSET = 512;
const SPRING_REST = 112;
const SPRING_STIFFNESS = 0.0032;
const GRAVITY = 0.00055;
const DAMPING = 0.86;
const MAX_PAIR_FORCE = 3.5;
const MAX_SPEED = 14;

function hashId(value: string): number {
  let hash = 2166136261;
  for (let index = 0; index < value.length; index += 1) {
    hash ^= value.charCodeAt(index);
    hash = Math.imul(hash, 16777619);
  }
  return hash >>> 0;
}

function clipLabel(label: string, max: number): string {
  const flat = label.replace(/\s+/g, " ").trim();
  return flat.length <= max ? flat : `${flat.slice(0, max - 1).trimEnd()}…`;
}

function cellKey(cellX: number, cellY: number): number {
  return (cellX + CELL_OFFSET) * 4096 + (cellY + CELL_OFFSET);
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
    border: read("--border", "#E2DDD2"),
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

function stepPhysics(nodes: SimNode[], edges: SimEdge[], dt: number, time: number): void {
  if (nodes.length === 0) return;
  const factor = Math.min(2, Math.max(0.25, dt / 16.67));
  const buckets = new Map<number, SimNode[]>();
  for (const node of nodes) {
    const key = cellKey(Math.floor(node.x / CELL_SIZE), Math.floor(node.y / CELL_SIZE));
    const bucket = buckets.get(key);
    if (bucket) bucket.push(node);
    else buckets.set(key, [node]);
  }

  for (const node of nodes) {
    if (node.pinned) continue;
    const cellX = Math.floor(node.x / CELL_SIZE);
    const cellY = Math.floor(node.y / CELL_SIZE);
    for (let offsetX = -1; offsetX <= 1; offsetX += 1) {
      for (let offsetY = -1; offsetY <= 1; offsetY += 1) {
        const bucket = buckets.get(cellKey(cellX + offsetX, cellY + offsetY));
        if (!bucket) continue;
        for (const other of bucket) {
          if (other === node) continue;
          let dx = node.x - other.x;
          let dy = node.y - other.y;
          let distanceSq = dx * dx + dy * dy;
          if (distanceSq > REPULSION_RADIUS * REPULSION_RADIUS) continue;
          if (distanceSq < 36) {
            const jitter = hashId(`${node.id}|${other.id}`);
            dx += ((jitter % 100) / 100 - 0.5) * 0.8;
            dy += (((jitter >> 8) % 100) / 100 - 0.5) * 0.8;
            distanceSq = dx * dx + dy * dy;
            if (distanceSq < 1) {
              dx = 0.7;
              dy = 0.7;
              distanceSq = 0.98;
            }
          }
          const distance = Math.sqrt(distanceSq);
          const force = Math.min(MAX_PAIR_FORCE, REPULSION / distanceSq);
          node.vx += (dx / distance) * force * factor;
          node.vy += (dy / distance) * force * factor;
        }
      }
    }
    node.vx -= node.x * GRAVITY * factor;
    node.vy -= node.y * GRAVITY * factor;
    node.vx += Math.sin(time * 0.0004 + node.phase) * 0.012 * factor;
    node.vy += Math.cos(time * 0.00037 + node.phase * 1.7) * 0.012 * factor;
  }

  for (const edge of edges) {
    const { source, target } = edge;
    const dx = target.x - source.x;
    const dy = target.y - source.y;
    const distance = Math.sqrt(dx * dx + dy * dy) || 0.001;
    const weight = Math.max(0.2, Math.min(2, edge.weight));
    const force = (distance - (SPRING_REST + (1 - Math.min(1, weight)) * 40)) * SPRING_STIFFNESS * weight * factor;
    const forceX = (dx / distance) * force;
    const forceY = (dy / distance) * force;
    if (!source.pinned) {
      source.vx += forceX;
      source.vy += forceY;
    }
    if (!target.pinned) {
      target.vx -= forceX;
      target.vy -= forceY;
    }
  }

  for (const node of nodes) {
    if (node.pinned) {
      node.vx = 0;
      node.vy = 0;
      continue;
    }
    node.vx *= DAMPING;
    node.vy *= DAMPING;
    node.vx = Math.max(-MAX_SPEED, Math.min(MAX_SPEED, node.vx));
    node.vy = Math.max(-MAX_SPEED, Math.min(MAX_SPEED, node.vy));
    node.x += node.vx * factor;
    node.y += node.vy * factor;
    if (Math.abs(node.x) > 6000) {
      node.x = Math.sign(node.x) * 6000;
      node.vx *= -0.4;
    }
    if (Math.abs(node.y) > 6000) {
      node.y = Math.sign(node.y) * 6000;
      node.vy *= -0.4;
    }
  }
}

/**
 * Canvas force-directed "Constellation" graph for Hindsight memory units.
 * Self-contained: data arrives as props, all interaction state lives here.
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
  const sizeRef = useRef({ width: 0, height: 0 });
  const cameraRef = useRef({ x: 0, y: 0, scale: 1 });
  const cameraTargetRef = useRef<{ x: number; y: number; scale: number } | null>(null);
  const simNodesRef = useRef<SimNode[]>([]);
  const simByIdRef = useRef<Map<string, SimNode>>(new Map());
  const simEdgesRef = useRef<SimEdge[]>([]);
  const signatureRef = useRef("");
  const pendingFitRef = useRef(true);
  const dragRef = useRef<DragState | null>(null);
  const pointerHoverRef = useRef<string | null>(null);
  const paletteRef = useRef<Palette | null>(null);

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
    const simNodes = simNodesRef.current;
    const { width, height } = sizeRef.current;
    if (simNodes.length === 0 || width <= 0 || height <= 0) return;
    let minX = Infinity;
    let minY = Infinity;
    let maxX = -Infinity;
    let maxY = -Infinity;
    for (const node of simNodes) {
      minX = Math.min(minX, node.x);
      minY = Math.min(minY, node.y);
      maxX = Math.max(maxX, node.x);
      maxY = Math.max(maxY, node.y);
    }
    const padding = 90;
    const scale = Math.min(
      1.8,
      Math.max(
        0.08,
        Math.min(
          (width - padding * 2) / Math.max(1, maxX - minX),
          (height - padding * 2) / Math.max(1, maxY - minY),
        ),
      ),
    );
    const target = { x: (minX + maxX) / 2, y: (minY + maxY) / 2, scale };
    if (animate) {
      cameraTargetRef.current = target;
    } else {
      cameraRef.current = { ...target };
      cameraTargetRef.current = null;
    }
  }, []);

  // Reconcile incoming data with persistent simulation nodes (kept positions
  // and pins survive filter switches and search-result transitions).
  useEffect(() => {
    let fitTimer = 0;
    const degree = new Map<string, number>();
    for (const edge of edges) {
      degree.set(edge.data.source, (degree.get(edge.data.source) ?? 0) + 1);
      degree.set(edge.data.target, (degree.get(edge.data.target) ?? 0) + 1);
    }
    const previous = simByIdRef.current;
    const next = new Map<string, SimNode>();
    nodes.forEach((node, index) => {
      const id = node.data.id;
      const nodeDegree = degree.get(id) ?? 0;
      const factKind = node.data.factType ?? null;
      const radius = Math.min(16, 5 + Math.sqrt(nodeDegree) * 2.1);
      const existing = previous.get(id);
      if (existing) {
        existing.label = node.data.label;
        existing.text = node.data.text;
        existing.factKind = factKind;
        existing.degree = nodeDegree;
        existing.radius = radius;
        next.set(id, existing);
        return;
      }
      const hash = hashId(id);
      const goldenAngle = 2.399963229728653;
      const spread = Math.max(140, Math.sqrt(nodes.length) * 52);
      const angle = index * goldenAngle + ((hash % 360) / 360) * 0.6;
      const distanceFromCenter = spread * Math.sqrt((index + 0.5) / nodes.length) + (hash % 9) * 4;
      next.set(id, {
        id,
        label: node.data.label,
        text: node.data.text,
        factKind,
        degree: nodeDegree,
        radius,
        x: Math.cos(angle) * distanceFromCenter,
        y: Math.sin(angle) * distanceFromCenter,
        vx: 0,
        vy: 0,
        pinned: false,
        phase: (hash % 628) / 100,
      });
    });
    simByIdRef.current = next;
    simNodesRef.current = Array.from(next.values());

    const simEdges: SimEdge[] = [];
    for (const edge of edges) {
      const source = next.get(edge.data.source);
      const target = next.get(edge.data.target);
      if (!source || !target || source === target) continue;
      simEdges.push({
        id: edge.data.id,
        source,
        target,
        linkType: edge.data.linkType ?? "semantic",
        weight: typeof edge.data.weight === "number" ? edge.data.weight : 1,
      });
    }
    simEdgesRef.current = simEdges;

    const signature = nodes
      .map((node) => node.data.id)
      .sort()
      .join("\u0000");
    if (signature !== signatureRef.current) {
      signatureRef.current = signature;
      if (sizeRef.current.width > 0 && nodes.length > 0) {
        pendingFitRef.current = false;
        fitToView(false);
      } else {
        pendingFitRef.current = nodes.length > 0;
      }
      // The first fit happens against the seeded ring layout; refit once the
      // physics has had time to spread the clusters to their resting shape.
      fitTimer = window.setTimeout(() => fitToView(true), 600);
    }
    return () => window.clearTimeout(fitTimer);
  }, [nodes, edges, fitToView]);

  useEffect(() => {
    fitToView(true);
  }, [fitSignal, fitToView]);

  useEffect(() => {
    if (!focusSignal) return;
    const node = simByIdRef.current.get(focusSignal.id);
    if (!node) return;
    cameraTargetRef.current = {
      x: node.x,
      y: node.y,
      scale: Math.max(cameraRef.current.scale, 1.2),
    };
  }, [focusSignal]);

  const findNodeAt = useCallback((screenX: number, screenY: number): SimNode | null => {
    const camera = cameraRef.current;
    const { width, height } = sizeRef.current;
    let best: SimNode | null = null;
    let bestDistance = Infinity;
    for (const node of simNodesRef.current) {
      const nodeX = (node.x - camera.x) * camera.scale + width / 2;
      const nodeY = (node.y - camera.y) * camera.scale + height / 2;
      const distance = Math.hypot(screenX - nodeX, screenY - nodeY);
      const hitRadius = Math.max(10, node.radius * camera.scale + 6);
      if (distance <= hitRadius && distance < bestDistance) {
        best = node;
        bestDistance = distance;
      }
    }
    return best;
  }, []);

  // Animation, physics, drawing, and resize/theme bookkeeping.
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
      if (pendingFitRef.current && simNodesRef.current.length > 0) {
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

    let frameId = 0;
    let lastTime = performance.now();
    let motionTime = 0;

    const render = (now: number) => {
      frameId = requestAnimationFrame(render);
      const dt = Math.min(48, Math.max(0, now - lastTime));
      lastTime = now;

      const palette = paletteRef.current ?? (paletteRef.current = readPalette());
      const size = sizeRef.current;
      const camera = cameraRef.current;
      const simNodes = simNodesRef.current;
      const simEdges = simEdgesRef.current;
      const current = stateRef.current;

      if (!current.paused) {
        motionTime += dt;
        stepPhysics(simNodes, simEdges, dt, motionTime);
      }

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
      if (canvas.width !== Math.round(size.width * dpr) || canvas.height !== Math.round(size.height * dpr)) {
        canvas.width = Math.round(size.width * dpr);
        canvas.height = Math.round(size.height * dpr);
      }
      context.setTransform(dpr, 0, 0, dpr, 0, 0);
      context.clearRect(0, 0, size.width, size.height);
      context.fillStyle = palette.bg;
      context.fillRect(0, 0, size.width, size.height);

      const toScreenX = (x: number) => (x - camera.x) * camera.scale + size.width / 2;
      const toScreenY = (y: number) => (y - camera.y) * camera.scale + size.height / 2;
      const selected = current.selectedId ? simByIdRef.current.get(current.selectedId) : undefined;
      const hovered = current.hoveredId ? simByIdRef.current.get(current.hoveredId) : undefined;

      if (simNodes.length === 0) {
        context.fillStyle = palette.dim;
        context.font = `13px ${fontFamily}`;
        context.textAlign = "center";
        context.textBaseline = "middle";
        context.fillText(labelsRef.current.empty, size.width / 2, size.height / 2);
        return;
      }

      // Edges first (behind nodes), curved and typed by link kind.
      for (const edge of simEdges) {
        const active =
          edge.source === selected ||
          edge.target === selected ||
          edge.source === hovered ||
          edge.target === hovered;
        const sourceX = toScreenX(edge.source.x);
        const sourceY = toScreenY(edge.source.y);
        const targetX = toScreenX(edge.target.x);
        const targetY = toScreenY(edge.target.y);
        const dx = targetX - sourceX;
        const dy = targetY - sourceY;
        const length = Math.hypot(dx, dy) || 1;
        const curve = Math.min(64, length * 0.12) * (hashId(edge.id) % 2 === 0 ? 1 : -1);
        const controlX = (sourceX + targetX) / 2 - (dy / length) * curve;
        const controlY = (sourceY + targetY) / 2 + (dx / length) * curve;

        context.strokeStyle =
          edge.linkType === "temporal"
            ? palette.temporal
            : edge.linkType === "entity"
              ? palette.entity
              : edge.linkType === "causal"
                ? palette.causal
                : palette.semantic;
        context.globalAlpha = active ? 0.82 : camera.scale < 0.4 ? 0.12 : 0.24;
        context.lineWidth = active ? 1.9 : 1;
        context.beginPath();
        context.moveTo(sourceX, sourceY);
        context.quadraticCurveTo(controlX, controlY, targetX, targetY);
        context.stroke();

        if (active) {
          const head = ((motionTime * 0.00035 + (hashId(edge.id) % 100) / 100) % 1);
          for (const offset of [head, (head + 0.5) % 1]) {
            const inverse = 1 - offset;
            const particleX =
              inverse * inverse * sourceX + 2 * inverse * offset * controlX + offset * offset * targetX;
            const particleY =
              inverse * inverse * sourceY + 2 * inverse * offset * controlY + offset * offset * targetY;
            context.globalAlpha = 0.9;
            context.fillStyle = context.strokeStyle;
            context.beginPath();
            context.arc(particleX, particleY, 2.1, 0, Math.PI * 2);
            context.fill();
          }
        }
      }
      context.globalAlpha = 1;

      // Nodes with glow rings for hover/selection.
      for (const node of simNodes) {
        const nodeX = toScreenX(node.x);
        const nodeY = toScreenY(node.y);
        const radius = Math.max(3.4, Math.min(22, node.radius * camera.scale));
        if (nodeX < -60 || nodeY < -60 || nodeX > size.width + 60 || nodeY > size.height + 60) continue;
        const isSelected = node === selected;
        const isHovered = node === hovered;
        const isInvalid = current.invalidatedIds.has(node.id);
        const color = isInvalid
          ? palette.invalid
          : node.factKind === "world"
            ? palette.world
            : node.factKind === "experience"
              ? palette.experience
              : node.factKind === "observation"
                ? palette.observation
                : palette.other;

        if (isSelected || isHovered) {
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

        context.globalAlpha = isInvalid ? 0.45 : 1;
        context.fillStyle = color;
        context.beginPath();
        context.arc(nodeX, nodeY, radius, 0, Math.PI * 2);
        context.fill();
        context.globalAlpha = 0.9;
        context.strokeStyle = palette.bg;
        context.lineWidth = 1.4;
        if (isInvalid) {
          context.setLineDash([2.5, 2.5]);
          context.strokeStyle = palette.invalid;
        }
        context.stroke();
        context.setLineDash([]);
        if (node.degree === 0) {
          context.globalAlpha = 0.55;
          context.strokeStyle = color;
          context.lineWidth = 1;
          context.beginPath();
          context.arc(nodeX, nodeY, radius + 2.5, 0, Math.PI * 2);
          context.stroke();
        }
      }
      context.globalAlpha = 1;

      // Labels for important, zoomed-in, hovered, or selected nodes.
      const labelLimit = camera.scale >= 1.4 ? 40 : 26;
      context.textAlign = "center";
      context.textBaseline = "middle";
      for (const node of simNodes) {
        const isSelected = node === selected;
        const isHovered = node === hovered;
        if (!(isSelected || isHovered || camera.scale >= 1.02 || (node.degree >= 6 && camera.scale >= 0.35))) continue;
        const nodeX = toScreenX(node.x);
        const nodeY = toScreenY(node.y);
        const radius = Math.max(3.4, Math.min(22, node.radius * camera.scale));
        if (nodeX < -120 || nodeY < -40 || nodeX > size.width + 120 || nodeY > size.height + 40) continue;
        const label = clipLabel(node.label, labelLimit);
        context.font = `${isSelected ? 600 : 500} 11px ${fontFamily}`;
        const width = context.measureText(label).width;
        const left = nodeX - width / 2;
        const top = nodeY + radius + 5;
        context.globalAlpha = 0.72;
        context.fillStyle = palette.bg;
        if (typeof context.roundRect === "function") {
          context.beginPath();
          context.roundRect(left - 4, top - 2, width + 8, 16, 4);
          context.fill();
        } else {
          context.fillRect(left - 4, top - 2, width + 8, 16);
        }
        context.globalAlpha = isSelected || isHovered ? 0.98 : 0.82;
        context.fillStyle = isSelected || isHovered ? palette.text : palette.muted;
        context.fillText(label, nodeX, top + 6);
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

  const handlePointerDown = (event: React.PointerEvent<HTMLCanvasElement>) => {
    const rect = event.currentTarget.getBoundingClientRect();
    const x = event.clientX - rect.left;
    const y = event.clientY - rect.top;
    event.currentTarget.setPointerCapture(event.pointerId);
    setHoverTip(null);
    const hit = findNodeAt(x, y);
    if (hit) {
      hit.pinned = true;
      dragRef.current = {
        mode: "node",
        pointerId: event.pointerId,
        node: hit,
        startX: x,
        startY: y,
        cameraX: cameraRef.current.x,
        cameraY: cameraRef.current.y,
        moved: false,
      };
      // Reheat the neighbourhood so a dragged node tugs its cluster along.
      for (const edge of simEdgesRef.current) {
        const neighbor =
          edge.source === hit ? edge.target : edge.target === hit ? edge.source : null;
        if (!neighbor) continue;
        neighbor.vx += (Math.random() - 0.5) * 1.4;
        neighbor.vy += (Math.random() - 0.5) * 1.4;
      }
    } else {
      dragRef.current = {
        mode: "pan",
        pointerId: event.pointerId,
        node: null,
        startX: x,
        startY: y,
        cameraX: cameraRef.current.x,
        cameraY: cameraRef.current.y,
        moved: false,
      };
    }
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
        drag.node.x = (x - sizeRef.current.width / 2) / camera.scale + camera.x;
        drag.node.y = (y - sizeRef.current.height / 2) / camera.scale + camera.y;
      }
      return;
    }

    const hit = findNodeAt(x, y);
    const hoverId = hit ? hit.id : null;
    if (hoverId !== pointerHoverRef.current) {
      pointerHoverRef.current = hoverId;
      callbacksRef.current.onHover(hoverId);
      event.currentTarget.style.cursor = hit ? "pointer" : "grab";
    }
    if (hit) {
      const wrapperWidth = wrapperRef.current?.clientWidth ?? 400;
      const wrapperHeight = wrapperRef.current?.clientHeight ?? 300;
      setHoverTip({
        x: Math.max(8, Math.min(x + 14, wrapperWidth - 250)),
        y: Math.max(8, Math.min(y + 14, wrapperHeight - 96)),
        label: hit.label,
        text: hit.text,
        kind: hit.factKind,
      });
    } else {
      setHoverTip(null);
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
      drag.node.pinned = false;
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
          style={{
            position: "absolute",
            left: hoverTip.x,
            top: hoverTip.y,
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
