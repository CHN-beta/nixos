
import { useEffect, useRef, useState, useCallback } from "react";
import { Terminal } from "@xterm/xterm";
import { FitAddon } from "@xterm/addon-fit";
import "@xterm/xterm/css/xterm.css";
import { useTheme } from "@/hooks/useTheme";
import { Plus, SquareTerminal, Trash2 } from "lucide-react";
import { Tooltip } from "./ui/primitives";

interface TerminalPanelProps {
  cwd?: string | null;
  active?: boolean;
}

interface TerminalTab {
  id: string;
  title: string;
}

export function TerminalPanel({ cwd, active = true }: TerminalPanelProps) {
  const { isDark } = useTheme();
  const [tabs, setTabs] = useState<TerminalTab[]>([]);
  const [activeTabId, setActiveTabId] = useState<string | null>(null);

  const containerRef = useRef<HTMLDivElement | null>(null);
  const termRef = useRef<Terminal | null>(null);
  const fitAddonRef = useRef<FitAddon | null>(null);
  const eventSourceRef = useRef<EventSource | null>(null);
  const inputBufferRef = useRef<string[]>([]);
  const inputTimerRef = useRef<NodeJS.Timeout | null>(null);

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
    try {
      const res = await fetch("/api/terminal", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ cwd: cwd || undefined }),
      });
      const json = await res.json();
      if (json.terminal?.id) {
        const newTab: TerminalTab = {
          id: json.terminal.id,
          title: `sh (${json.terminal.id.slice(-4)})`,
        };
        setTabs((prev) => [...prev, newTab]);
        setActiveTabId(newTab.id);
      }
    } catch {
      // Failed to spawn
    }
  }, [cwd]);

  // Initial terminal creation
  useEffect(() => {
    if (tabs.length === 0) {
      void createTerminal();
    }
  }, [createTerminal, tabs.length]);

  // Setup xterm for activeTabId
  useEffect(() => {
    if (!activeTabId || !containerRef.current) return;

    if (eventSourceRef.current) {
      eventSourceRef.current.close();
      eventSourceRef.current = null;
    }
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

    // Connect SSE stream
    const es = new EventSource(`/api/terminal/${activeTabId}/stream`);
    eventSourceRef.current = es;

    es.onmessage = (event) => {
      try {
        const msg = JSON.parse(event.data);
        if (msg.type === "output" && msg.data) {
          term.write(msg.data);
        } else if (msg.type === "exit") {
          term.write(`\r\n\x1b[33m[Process exited with code ${msg.code}]\x1b[0m\r\n`);
        }
      } catch {
        // Ignored
      }
    };

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
      es.close();
      eventSourceRef.current = null;
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
