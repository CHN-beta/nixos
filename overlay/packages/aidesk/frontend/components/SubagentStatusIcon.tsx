import { Ban, CheckCircle2, Circle, CircleAlert } from "lucide-react";

/** Terminal/live status icon shared by the composer roster (ComposerPanels)
 * and the in-message task summary (MessageView), which previously each
 * rendered their own copy.
 *
 * `live` refines the "started" state: `true` = actively running (pulsing
 * dot), `false` = orphaned/history entry (hollow circle), omitted = plain
 * running dot (MessageView's mid-run snapshot). */
export function SubagentStatusIcon({ status, live }: {
  status: "started" | "completed" | "failed" | "aborted";
  live?: boolean;
}) {
  const props = { size: 12, strokeWidth: 2, "aria-hidden": true as const };
  if (status === "completed") return <CheckCircle2 {...props} color="var(--accent)" />;
  if (status === "failed") return <CircleAlert {...props} color="var(--accent-strong)" />;
  if (status === "aborted") return <Ban {...props} color="var(--text-dim)" />;
  if (live === true) {
    return <span aria-hidden className="live-status-dot live-pulse inline-block h-1.5 w-1.5 shrink-0 rounded-full bg-accent" />;
  }
  if (live === false) return <Circle {...props} color="var(--text-dim)" />;
  return <span aria-hidden className="live-status-dot inline-block h-1.5 w-1.5 shrink-0 rounded-full bg-accent" />;
}
