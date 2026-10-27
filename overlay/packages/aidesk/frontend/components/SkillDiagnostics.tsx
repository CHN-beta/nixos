
import { useEffect, useRef, useState } from "react";
import { CircleAlert, Info, Loader2, X } from "lucide-react";
import { sendAgentCommand } from "@/lib/agent-client";
import { useI18n } from "@/lib/i18n";
import { parseSkillDiagnosticsSnapshot, type SkillDiagnosticEntry, type SkillDiagnosticsSnapshot } from "@/lib/skill-diagnostics";
import { Dialog, DialogClose, DialogContent, DialogTitle } from "./ui/primitives";

const actionStyle = {
  display: "inline-flex", alignItems: "center", gap: 5,
  padding: "4px 10px", background: "var(--bg)",
  border: "1px solid var(--border)", borderRadius: "var(--radius-control)",
  color: "var(--text-muted)", cursor: "pointer", fontSize: 12, fontFamily: "inherit",
} as const;

function displayText(value: string): string {
  return value.replace(/[\p{Cc}\u202a-\u202e\u2066-\u2069]/gu, "");
}

function DiagnosticEntry({ label, entry }: { label: string; entry: SkillDiagnosticEntry }) {
  const { t } = useI18n();
  return (
    <div className="grid min-w-0 gap-1 text-xs">
      <div><span className="font-medium">{label}: </span><code style={{ overflowWrap: "anywhere" }}>{displayText(entry.name)}</code></div>
      <code className="text-text-muted" style={{ overflowWrap: "anywhere" }}>{displayText(entry.filePath)}</code>
      <span className="text-text-dim">{t("skillDiagnostics.source", { source: displayText(entry.source) })}{entry.pluginName ? ` · ${displayText(entry.pluginName)}` : ""}</span>
    </div>
  );
}

export function SkillDiagnosticsDialog({ open, onOpenChange, snapshot, loading = false, error }: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  snapshot: SkillDiagnosticsSnapshot | null;
  loading?: boolean;
  error?: string | null;
}) {
  const { t } = useI18n();
  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent ariaLabel={t("skillDiagnostics.title")} style={{ width: "min(92vw, 760px)", maxWidth: "min(92vw, 760px)", maxHeight: "85dvh", overflowY: "auto" }}>
        <div className="flex items-start justify-between gap-3">
          <DialogTitle>{t("skillDiagnostics.title")}</DialogTitle>
          <DialogClose aria-label={t("skillDiagnostics.close")} className="ui-focus-ring cursor-pointer text-text-muted" style={{ background: "none", border: "none", borderRadius: "var(--radius-control)" }}>
            <X size={16} strokeWidth={1.8} aria-hidden />
          </DialogClose>
        </div>
        {loading ? <p role="status" className="flex items-center gap-2 text-sm text-text-muted"><Loader2 size={14} aria-hidden className="animate-spin" />{t("skillDiagnostics.loading")}</p> : error ? <p role="alert" className="text-sm" style={{ color: "var(--status-error)" }}>{error}</p> : snapshot ? (
          <div className="grid gap-3">
            <code className="text-xs text-text-dim" style={{ overflowWrap: "anywhere" }}>{displayText(snapshot.cwd)}</code>
            {snapshot.diagnostics.length === 0 ? <p className="text-sm text-text-muted">{t("skillDiagnostics.clean")}</p> : snapshot.diagnostics.map((diagnostic) => {
              const selected = diagnostic.skills.find((entry) => entry.name === diagnostic.name);
              return (
                <section key={diagnostic.name} className="grid min-w-0 gap-3 border border-border bg-bg-subtle p-3" style={{ borderRadius: "var(--radius-card)" }}>
                  <h3 className="m-0 text-sm font-medium" style={{ overflowWrap: "anywhere" }}>{displayText(diagnostic.name)}</h3>
                  {selected ? <>
                    <DiagnosticEntry label={t("skillDiagnostics.default")} entry={selected} />
                    <p className="m-0 text-xs text-text-muted">{t(`skillDiagnostics.reason.${diagnostic.reason}`)}</p>
                  </> : <p className="m-0 text-xs text-text-muted">{t("skillDiagnostics.noDefault")}</p>}
                  {diagnostic.skills.filter((entry) => entry !== selected).map((entry) => <DiagnosticEntry key={entry.filePath} label={t("skillDiagnostics.variant")} entry={entry} />)}
                  {diagnostic.duplicates.map(({ skill, retained }) => (
                    <div key={skill.filePath} className="grid min-w-0 gap-1">
                      <DiagnosticEntry label={t("skillDiagnostics.redundant")} entry={skill} />
                      <p className="m-0 text-xs text-text-dim" style={{ overflowWrap: "anywhere" }}>{t("skillDiagnostics.retained", { name: displayText(retained.name), path: displayText(retained.filePath) })}</p>
                    </div>
                  ))}
                </section>
              );
            })}
            <p className="m-0 text-xs text-text-muted">{t("skillDiagnostics.lineage")}</p>
          </div>
        ) : null}
      </DialogContent>
    </Dialog>
  );
}

export function SkillDiagnosticsNotice({ snapshot, onDisable }: {
  snapshot: SkillDiagnosticsSnapshot | null;
  onDisable: () => Promise<SkillDiagnosticsSnapshot>;
}) {
  const { t, tn } = useI18n();
  const [open, setOpen] = useState(false);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  // Dismissal hides this exact report for the session; a changed report shows again.
  const [dismissedKey, setDismissedKey] = useState<string | null>(null);
  useEffect(() => {
    if (!snapshot) setOpen(false);
  }, [snapshot]);
  if (!snapshot) return null;
  let conflicts = 0;
  let duplicates = 0;
  for (const diagnostic of snapshot.diagnostics) {
    if (diagnostic.skills.length > 1) conflicts++;
    duplicates += diagnostic.duplicates.length;
  }
  const reportKey = JSON.stringify(snapshot.diagnostics);
  const visible = snapshot.showStartupDiagnostics && (conflicts > 0 || duplicates > 0) && dismissedKey !== reportKey;
  const Icon = conflicts > 0 ? CircleAlert : Info;
  return (
    <>
      {visible && <div role="status" aria-live="polite" className="flex flex-wrap items-center gap-2 border border-border bg-bg-subtle px-3 py-2 text-xs" style={{ marginBottom: 8, borderRadius: "var(--radius-card)", color: conflicts > 0 ? "var(--status-warning)" : "var(--text-muted)" }}>
        <Icon size={14} aria-hidden />
        <span className="min-w-0 flex-1">{[conflicts > 0 ? tn("skillDiagnostics.conflicts", conflicts) : null, duplicates > 0 ? tn("skillDiagnostics.duplicates", duplicates) : null].filter(Boolean).join(" · ")}</span>
        <button type="button" className="ui-focus-ring" style={actionStyle} onClick={() => setOpen(true)}>{t("skillDiagnostics.details")}</button>
        <button type="button" className="ui-focus-ring" style={actionStyle} disabled={saving} onClick={async () => {
          setSaving(true); setError(null);
          try {
            const effective = await onDisable();
            if (effective.showStartupDiagnostics) setError(t("skillDiagnostics.overridden"));
          } catch {
            setError(t("skillDiagnostics.saveFailed"));
          } finally {
            setSaving(false);
          }
        }}>{saving ? t("skillDiagnostics.saving") : t("skillDiagnostics.disable")}</button>
        <button type="button" className="ui-focus-ring" style={{ display: "inline-flex", padding: 4, background: "none", border: "none", borderRadius: "var(--radius-control)", color: "var(--text-muted)", cursor: "pointer" }} aria-label={t("skillDiagnostics.dismiss")} title={t("skillDiagnostics.dismiss")} onClick={() => { setDismissedKey(reportKey); setError(null); }}><X size={14} aria-hidden /></button>
        {error && <span role="alert" style={{ color: "var(--status-error)", width: "100%" }}>{error}</span>}
      </div>}
      <SkillDiagnosticsDialog open={open} onOpenChange={setOpen} snapshot={snapshot} />
    </>
  );
}

/** Explicit inspection never starts a new empty session. Missing support is not a clean result. */
export function SkillDiagnosticsInspector({ sessionId }: { sessionId?: string | null }) {
  const { t } = useI18n();
  const [open, setOpen] = useState(false);
  const [snapshot, setSnapshot] = useState<SkillDiagnosticsSnapshot | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const requestVersion = useRef({ value: 0 });
  useEffect(() => {
    const requests = requestVersion.current;
    requests.value++;
    setOpen(false); setSnapshot(null); setError(null); setLoading(false);
    return () => { requests.value++; };
  }, [sessionId]);
  return (
    <>
      <button type="button" className="ui-focus-ring" style={actionStyle} disabled={!sessionId || loading} title={!sessionId ? t("skillDiagnostics.noSession") : undefined} onClick={async () => {
        if (!sessionId) return;
        const requests = requestVersion.current;
        const version = ++requests.value;
        setOpen(true); setLoading(true); setError(null); setSnapshot(null);
        try {
          const result = parseSkillDiagnosticsSnapshot(await sendAgentCommand<unknown>(sessionId, { type: "get_skill_diagnostics" }));
          if (version !== requests.value) return;
          if (!result) setError(t("skillDiagnostics.unavailable")); else setSnapshot(result);
        } catch {
          if (version === requests.value) setError(t("skillDiagnostics.unavailable"));
        } finally {
          if (version === requests.value) setLoading(false);
        }
      }}><Info size={13} aria-hidden />{t("skillDiagnostics.inspect")}</button>
      {!sessionId && <p className="m-0 text-xs text-text-muted">{t("skillDiagnostics.noSession")}</p>}
      <SkillDiagnosticsDialog open={open} onOpenChange={setOpen} snapshot={snapshot} loading={loading} error={error} />
    </>
  );
}
