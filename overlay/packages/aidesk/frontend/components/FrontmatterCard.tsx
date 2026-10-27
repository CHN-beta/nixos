
import { formatFrontmatterValue } from "@/lib/frontmatter";

export function FrontmatterCard({ data }: { data: Record<string, unknown> | null }) {
  if (!data || Object.keys(data).length === 0) return null;
  const title = typeof data.title === "string" ? data.title.trim() : "";
  const rows = Object.entries(data).filter(([key]) => key !== "title");
  return (
    <aside style={{ marginBottom: 18, padding: "12px 14px", border: "1px solid var(--border)", borderRadius: "var(--radius-card)", background: "var(--bg-panel)", fontSize: 12 }}>
      {title && <div style={{ marginBottom: 8, color: "var(--text)", fontWeight: 600 }}>{title}</div>}
      {rows.map(([key, value]) => (
        <div key={key} style={{ display: "grid", gridTemplateColumns: "minmax(90px, 0.35fr) 1fr", gap: 10, padding: "3px 0" }}>
          <span style={{ color: "var(--text-muted)", fontFamily: "var(--font-mono)" }}>{key}</span>
          <span style={{ color: "var(--text)", overflowWrap: "anywhere" }}>{formatFrontmatterValue(value)}</span>
        </div>
      ))}
    </aside>
  );
}
