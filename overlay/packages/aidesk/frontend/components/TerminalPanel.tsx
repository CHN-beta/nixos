
import { useEffect, useRef, useState, useCallback } from "react";
import { Terminal } from "@xterm/xterm";
import { FitAddon } from "@xterm/addon-fit";
import "@xterm/xterm/css/xterm.css";
import { useTheme } from "@/hooks/useTheme";
import { Plus, SquareTerminal, Trash2 } from "lucide-react";
import { connectSse } from "@/lib/sse-reconnect";
import { Tooltip } from "./ui/primitives";

interface TerminalPanelProps {
  cwd?: string | null;
  active?: boolean;
}

interface TerminalTab {
  id: string;
  title: string;
  cwd?: string;
}

/** `GET/POST /api/terminal` payload. */
interface TerminalInfo {
  id: string;
  cwd?: string;
  cols?: number;
  rows?: number;
}

/** One frame of `GET /api/terminal/[id]/stream`.
 *  `startOffset` is the UTF-8 byte offset where this chunk begins and `offset`
 *  is the offset *after* its last byte (`end_offset`). The server accepts the
 *  end offset as `?offset=` to resume without replaying buffered history. */
interface TerminalStreamFrame {
  type?: string;
  data?: string;
  startOffset?: number;
  offset?: number;
  code?: number;
}

export function TerminalPanel({ cwd, active = true }: TerminalPanelProps) {
  const { isDark } = useTheme();
  const [tabs, setTabs] = useState<TerminalTab[]>([]);
  const [activeTabId, setActiveTabId] = useState<string | null>(null);

  const containerRef = useRef<HTMLDivElement | null>(null);
  const termRef = useRef<Terminal | null>(null);
  const fitAddonRef = useRef<FitAddon | null>(null);
  const inputBufferRef = useRef<string[]>([]);
  const inputTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  // Bytes already printed per tab, so a reconnect can resume after them.
  const offsetsRef = useRef<Map<string, number>>(new Map());
  // A shell that reported `exit` must not be re-attached: the PTY is gone and
  // the server would only replay its exit frame.
  const exitedTabsRef = useRef<Set<string>>(new Set());
  // Guards the mount flow against a second POST (StrictMode re-runs effects).
  const creatingRef = useRef(false);

  // Send buffered input
  const flushInput = useCallback((sessionId: string) => {
    if (inputBufferRef.current.length === 0) return;
    const combined = inputBufferRef.current.join("");
    inputBufferRef.current = [];

    void fetch(`/api/terminal/${sessionId}/input`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ data: combined }),
    }).catch(() => {});
  }, []);

  const queueInput = useCallback((sessionId: string, data: string) => {
    inputBufferRef.current.push(data);
    if (!inputTimerRef.current) {
      inputTimerRef.current = setTimeout(() => {
        inputTimerRef.current = null;
        flushInput(sessionId);
      }, 5);
    }
  }, [flushInput]);

  const sendResize = useCallback((sessionId: string, cols: number, rows: number) => {
    void fetch(`/api/terminal/${sessionId}/resize`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ cols, rows }),
    }).catch(() => {});
  }, []);

  // Create new terminal
  const createTerminal = useCallback(async () => {
    if (creatingRef.current) return;
    creatingRef.current = true;
    try {
      const res = await fetch("/api/terminal", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ cwd: cwd || undefined }),
      });
      const json = await res.json() as { terminal?: TerminalInfo };
      const terminal = json.terminal;
      if (terminal?.id) {
        const newTab: TerminalTab = {
          id: terminal.id,
          title: `sh (${terminal.id.slice(-4)})`,
          cwd: terminal.cwd,
        };
        setTabs((prev) => (prev.some((tab) => tab.id === newTab.id) ? prev : [...prev, newTab]));
        setActiveTabId(newTab.id);
      }
    } catch {
      // Failed to spawn
    } finally {
      creatingRef.current = false;
    }
  }, [cwd]);

  // Initial terminal: a refresh (or another browser tab) must reuse the shell
  // that is already alive on the server. POSTing unconditionally on every
  // mount leaked one PTY per page load, each holding a child process.
  useEffect(() => {
    if (tabs.length > 0) return;
    let cancelled = false;
    void (async () => {
      let restored: TerminalTab[] = [];
      try {
        const res = await fetch("/api/terminal");
        if (res.ok) {
          const json = await res.json() as { terminals?: TerminalInfo[] };
          const live = (json.terminals ?? []).filter((terminal) => typeof terminal?.id === "string");
          // Prefer shells already rooted in this session's directory; fall
          // back to every live shell so a refresh restores the workspace.
          const targetCwd = (cwd ?? "").replace(/\/+$/, "");
          const matching = targetCwd
            ? live.filter((terminal) => (terminal.cwd ?? "").replace(/\/+$/, "") === targetCwd)
            : [];
          restored = (matching.length > 0 ? matching : live).map((terminal) => ({
            id: terminal.id,
            title: `sh (${terminal.id.slice(-4)})`,
            cwd: terminal.cwd,
          }));
        }
      } catch {
        // Treat an unreachable list as empty and fall through to creating one.
      }
      if (cancelled) return;
      if (restored.length > 0) {
        setTabs(restored);
        setActiveTabId(restored[restored.length - 1].id);
        return;
      }
      await createTerminal();
    })();
    return () => { cancelled = true; };
  }, [createTerminal, cwd, tabs.length]);

  // A pending input flush belongs to an unmounted view otherwise.
  useEffect(() => () => {
    clearTimeout(inputTimerRef.current ?? undefined);
    inputTimerRef.current = null;
  }, []);

  // Setup xterm for activeTabId
  useEffect(() => {
    if (!activeTabId || !containerRef.current) return;

    if (termRef.current) {
      termRef.current.dispose();
      termRef.current = null;
    }

    const term = new Terminal({
      cursorBlink: true,
      cursorStyle: "bar",
      fontSize: 13,
      fontFamily: "var(--font-mono), monospace",
      theme: isDark
        ? {
            background: "#121214",
            foreground: "#ececec",
            cursor: "#f4f4f5",
            selectionBackground: "#3f3f46",
          }
        : {
            background: "#faf8f5",
            foreground: "#27272a",
            cursor: "#18181b",
            selectionBackground: "#e4e4e7",
          },
      allowTransparency: true,
    });

    const fitAddon = new FitAddon();
    term.loadAddon(fitAddon);

    term.open(containerRef.current);
    fitAddon.fit();

    termRef.current = term;
    fitAddonRef.current = fitAddon;

    // Send initial size
    sendResize(activeTabId, term.cols, term.rows);

    // Listen to user typing
    const onDataDisposable = term.onData((data) => {
      queueInput(activeTabId, data);
    });

    // A fresh xterm has no scrollback, so this connection starts at byte 0;
    // reconnects reuse the last acknowledged offset. Output is written with
    // byte accounting so a resumed stream neither loses bytes nor re-prints
    // the replay the server sends for `offset=0`.
    offsetsRef.current.set(activeTabId, 0);
    const encoder = new TextEncoder();
    const decoder = new TextDecoder();
    // `startOffset` marks where the chunk begins, `offset` where it ends. A
    // resumed stream can replay bytes already printed, so trim that overlap
    // and then record the server's end offset (all offsets are UTF-8 bytes).
    const appendOutput = (chunk: string, startOffset?: number, endOffset?: number) => {
      if (!chunk) return;
      const printed = offsetsRef.current.get(activeTabId) ?? 0;
      const bytes = encoder.encode(chunk);
      const validStart =
        typeof startOffset === "number" && Number.isFinite(startOffset) ? startOffset : undefined;
      const validEnd =
        typeof endOffset === "number" && Number.isFinite(endOffset) ? endOffset : undefined;
      // Legacy frames without `startOffset` fall back to `offset` as the start.
      const chunkStart = validStart ?? validEnd ?? printed;
      const chunkEnd = validEnd ?? chunkStart + bytes.length;
      let data = chunk;
      const overlap = printed - chunkStart;
      if (overlap > 0) {
        if (overlap >= bytes.length) {
          // Whole chunk was already printed; only advance the offset.
          offsetsRef.current.set(activeTabId, Math.max(printed, chunkEnd));
          return;
        }
        // Never start mid-codepoint: a split UTF-8 sequence would decode as
        // a replacement character at the seam.
        let start = overlap;
        while (start < bytes.length && (bytes[start] & 0xc0) === 0x80) start += 1;
        data = decoder.decode(bytes.subarray(start));
      }
      offsetsRef.current.set(activeTabId, Math.max(printed, chunkEnd));
      if (data) term.write(data);
    };

    const stream = connectSse({
      // Incremental resume. The server only replays bytes after this offset,
      // and an already-exited PTY only answers with its exit frame.
      url: () => `/api/terminal/${encodeURIComponent(activeTabId)}/stream?offset=${offsetsRef.current.get(activeTabId) ?? 0}`,
      shouldReconnect: () => !exitedTabsRef.current.has(activeTabId),
      setup: (source) => {
        source.onmessage = (event) => {
          let frame: TerminalStreamFrame;
          try {
            frame = JSON.parse(event.data) as TerminalStreamFrame;
          } catch {
            return;
          }
          // Keepalive only: it proves the socket is alive and prints nothing.
          if (frame.type === "ping") return;
          if (frame.type === "output" && typeof frame.data === "string") {
            appendOutput(frame.data, frame.startOffset, frame.offset);
          } else if (frame.type === "exit") {
            // The PTY is gone: stop re-attaching it.
            exitedTabsRef.current.add(activeTabId);
            term.write(`\r\n\x1b[33m[Process exited with code ${frame.code}]\x1b[0m\r\n`);
          }
        };
      },
    });

    // Resize observer
    const resizeObserver = new ResizeObserver(() => {
      if (!active) return;
      try {
        fitAddon.fit();
        sendResize(activeTabId, term.cols, term.rows);
      } catch {
        // Ignored
      }
    });
    resizeObserver.observe(containerRef.current);

    return () => {
      onDataDisposable.dispose();
      resizeObserver.disconnect();
      stream.close();
      term.dispose();
      termRef.current = null;
    };
  }, [activeTabId, isDark, queueInput, sendResize, active]);

  // Focus terminal when active
  useEffect(() => {
    if (active && termRef.current) {
      termRef.current.focus();
      fitAddonRef.current?.fit();
    }
  }, [active]);

  const handleCloseTab = useCallback((idToClose: string) => {
    void fetch(`/api/terminal/${idToClose}`, { method: "DELETE" });
    offsetsRef.current.delete(idToClose);
    exitedTabsRef.current.delete(idToClose);
    setTabs((prev) => {
      const remaining = prev.filter((t) => t.id !== idToClose);
      if (activeTabId === idToClose) {
        setActiveTabId(remaining[remaining.length - 1]?.id ?? null);
      }
      return remaining;
    });
  }, [activeTabId]);

  const handleClear = useCallback(() => {
    termRef.current?.clear();
  }, []);

  return (
    <div style={{ display: "flex", flexDirection: "column", height: "100%", width: "100%", background: isDark ? "#121214" : "#faf8f5" }}>
      {/* Terminal Top Bar */}
      <div
        style={{
          display: "flex",
          alignItems: "center",
          justifyContent: "space-between",
          padding: "4px 8px",
          borderBottom: "1px solid var(--border)",
          background: "var(--bg-panel)",
          fontSize: 12,
        }}
      >
        <div style={{ display: "flex", alignItems: "center", gap: 4, overflowX: "auto" }}>
          {tabs.map((tab) => {
            const isActive = tab.id === activeTabId;
            return (
              <div
                key={tab.id}
                onClick={() => setActiveTabId(tab.id)}
                style={{
                  display: "flex",
                  alignItems: "center",
                  gap: 6,
                  padding: "3px 8px",
                  borderRadius: "var(--radius-control)",
                  background: isActive ? "var(--bg-selected)" : "transparent",
                  color: isActive ? "var(--text)" : "var(--text-muted)",
                  cursor: "pointer",
                  fontSize: 11,
                  fontFamily: "var(--font-mono)",
                }}
              >
                <SquareTerminal size={12} />
                <span>{tab.title}</span>
                {tabs.length > 1 && (
                  <button
                    type="button"
                    onClick={(e) => {
                      e.stopPropagation();
                      handleCloseTab(tab.id);
                    }}
                    style={{
                      background: "none",
                      border: "none",
                      color: "inherit",
                      cursor: "pointer",
                      padding: 0,
                      opacity: 0.7,
                      fontSize: 12,
                      lineHeight: 1,
                    }}
                  >
                    ×
                  </button>
                )}
              </div>
            );
          })}
          <Tooltip content="New terminal">
            <button
              type="button"
              onClick={createTerminal}
              style={{
                display: "inline-flex",
                alignItems: "center",
                justifyContent: "center",
                width: 20,
                height: 20,
                borderRadius: "var(--radius-control)",
                border: "none",
                background: "transparent",
                color: "var(--text-muted)",
                cursor: "pointer",
              }}
            >
              <Plus size={13} />
            </button>
          </Tooltip>
        </div>

        <div style={{ display: "flex", alignItems: "center", gap: 4 }}>
          <Tooltip content="Clear terminal">
            <button
              type="button"
              onClick={handleClear}
              style={{
                display: "inline-flex",
                alignItems: "center",
                justifyContent: "center",
                width: 22,
                height: 22,
                borderRadius: "var(--radius-control)",
                border: "none",
                background: "transparent",
                color: "var(--text-muted)",
                cursor: "pointer",
              }}
            >
              <Trash2 size={13} />
            </button>
          </Tooltip>
        </div>
      </div>

      {/* Terminal View */}
      <div
        ref={containerRef}
        style={{
          flex: 1,
          width: "100%",
          height: "100%",
          padding: "6px 8px",
          boxSizing: "border-box",
          overflow: "hidden",
        }}
      />
    </div>
  );
}
