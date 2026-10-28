import { Component, StrictMode, Suspense, type ErrorInfo, type ReactNode } from "react";
import { createRoot } from "react-dom/client";
import { installApiTransport } from "@/lib/api-origin";
import { AppShell } from "@/components/AppShell";
import { IosFocusZoomGuard } from "@/components/IosFocusZoomGuard";
import "@/app/fonts.css";
import "@/app/globals.css";

// The API may live on another origin from this static bundle. Patch `fetch`
// and `EventSource` before any component runs so every `/api/...` call gets the
// API origin, credentials, and the Authelia redirect on 401.
installApiTransport();

// The sidebar owns the browser history stack for its back-gesture machinery
// (hooks/useSidebarHistory.ts). Re-dispatch popstate as a custom event so the
// hook can stopImmediatePropagation() on the native event before any other
// listener observes the traversal.
window.addEventListener("popstate", (event) => {
  window.dispatchEvent(new CustomEvent("omp:sidebar-popstate", { detail: event }));
});

const container = document.getElementById("root");
if (!container) throw new Error("Missing #root element");

/**
 * Last-resort error boundary. The fallback uses inline styles only: the failure
 * may be a stylesheet/chunk load, so it cannot depend on globals.css or on any
 * other module of the app.
 */
class ErrorBoundary extends Component<{ children: ReactNode }, { failed: boolean }> {
  state = { failed: false };

  static getDerivedStateFromError() {
    return { failed: true };
  }

  componentDidCatch(error: Error, info: ErrorInfo) {
    console.error("AIDesk crashed:", error, info.componentStack);
  }

  render() {
    if (!this.state.failed) return this.props.children;
    return (
      <div
        role="alert"
        style={{
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
          justifyContent: "center",
          minHeight: "100vh",
          padding: "2rem",
          gap: "1rem",
          fontFamily: "system-ui, -apple-system, sans-serif",
          textAlign: "center",
          color: "#2B2823",
          background: "#FAF9F6",
        }}
      >
        <h2 style={{ margin: 0, fontSize: "1.5rem", fontWeight: 600, fontFamily: "Georgia, 'Songti SC', serif" }}>
          AIDesk hit a snag
        </h2>
        <p style={{ margin: 0, color: "#69635A", maxWidth: "28rem", fontSize: "0.875rem", lineHeight: 1.6 }}>
          An unexpected error occurred. Reloading usually clears it.
        </p>
        <button
          type="button"
          onClick={() => window.location.reload()}
          style={{
            marginTop: "0.5rem",
            padding: "0.5rem 1.5rem",
            fontSize: "0.875rem",
            fontWeight: 500,
            border: "none",
            borderRadius: "8px",
            background: "#B03E22",
            color: "#fff",
            cursor: "pointer",
          }}
        >
          Reload
        </button>
      </div>
    );
  }
}

function RouteLoadingFallback() {
  return (
    <div className="route-fallback" role="status" aria-busy="true" aria-label="Loading AIDesk">
      <aside className="route-fallback-sidebar" aria-hidden="true">
        <div className="skeleton route-fallback-sidebar-title" />
        <div className="skeleton route-fallback-sidebar-button" />
        <div className="route-fallback-sidebar-list">
          <div className="skeleton route-fallback-sidebar-row" />
          <div className="skeleton route-fallback-sidebar-row" />
          <div className="skeleton route-fallback-sidebar-row" />
        </div>
      </aside>
      <main className="route-fallback-main" aria-hidden="true">
        <div className="route-fallback-topbar">
          <div className="skeleton route-fallback-topbar-control" />
          <div className="skeleton route-fallback-topbar-title" />
          <div className="skeleton route-fallback-topbar-control" />
        </div>
        <div className="route-fallback-content">
          <div className="skeleton route-fallback-line route-fallback-line-short" />
          <div className="skeleton route-fallback-line" />
          <div className="skeleton route-fallback-line" />
          <div className="skeleton route-fallback-composer" />
        </div>
      </main>
    </div>
  );
}

createRoot(container).render(
  <StrictMode>
    {/* Outermost safety net: a render error or a stale lazy chunk must show
        the fallback instead of unmounting the tree into a blank screen. */}
    <ErrorBoundary>
      <IosFocusZoomGuard />
      <Suspense fallback={<RouteLoadingFallback />}>
        <AppShell appName="AIDesk" />
      </Suspense>
    </ErrorBoundary>
  </StrictMode>,
);
