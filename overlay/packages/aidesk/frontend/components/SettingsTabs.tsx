
import { useI18n } from "@/lib/i18n";
import { Bell, Info, Settings2, Wallet } from "lucide-react";
import type { ComponentType, CSSProperties } from "react";

export type SettingsTab = "general" | "notifications" | "account" | "about";

export interface TabItem {
  id: SettingsTab;
  label: string;
  description: string;
  Icon: ComponentType<{ size?: number; className?: string; "aria-hidden"?: boolean | "true" | "false"; style?: CSSProperties }>;
}

export const SETTINGS_CATEGORIES: TabItem[] = [
  { id: "general", label: "Interface & Behavior", description: "UI preferences, completion sound, submission mode", Icon: Settings2 },
  { id: "notifications", label: "Notifications", description: "Desktop and mobile notifications for your sessions", Icon: Bell },
  { id: "account", label: "Account & Usage", description: "Account session, quota, and provider usage", Icon: Wallet },
  { id: "about", label: "About & Acknowledgments", description: "AIDesk version, runtime, and open-source credits", Icon: Info },
];

export const getNormalizedActive = (tab: SettingsTab): SettingsTab => tab;

export function SettingsTabs({
  active,
  onSelect,
  layout = "vertical",
}: {
  active: SettingsTab;
  onSelect: (tab: SettingsTab) => void;
  layout?: "horizontal" | "vertical";
}) {
  const { t } = useI18n();
  const currentActive = getNormalizedActive(active);

  const onKeyDown = (event: React.KeyboardEvent, index: number) => {
    let nextIndex: number | null = null;
    if (event.key === "ArrowRight" || event.key === "ArrowDown") nextIndex = index + 1;
    if (event.key === "ArrowLeft" || event.key === "ArrowUp") nextIndex = index - 1;
    if (event.key === "Home") nextIndex = 0;
    if (event.key === "End") nextIndex = SETTINGS_CATEGORIES.length - 1;
    if (nextIndex !== null) {
      event.preventDefault();
      const next = SETTINGS_CATEGORIES[nextIndex];
      if (next) {
        onSelect(next.id);
        document.getElementById("settings-tab-" + next.id)?.focus();
      }
    }
  };

  if (layout === "vertical") {
    return (
      <nav
        aria-label={t("settingsTabs.ariaLabel")}
        role="tablist"
        aria-orientation="vertical"
        className="settings-nav"
      >
        {SETTINGS_CATEGORIES.map(({ id, label, description, Icon }, index) => {
          const labelKey = `settingsTabs.${id}.label`;
          const descKey = `settingsTabs.${id}.description`;
          const trLabel = t(labelKey);
          const trDesc = t(descKey);
          const displayLabel = trLabel !== labelKey ? trLabel : label;
          const displayDescription = trDesc !== descKey ? trDesc : description;
          const selected = id === currentActive;
          return (
            <button
              key={id}
              type="button"
              role="tab"
              id={`settings-tab-${id}`}
              aria-selected={selected}
              aria-controls={`settings-panel-${id}`}
              title={displayDescription}
              tabIndex={selected ? 0 : -1}
              onClick={() => onSelect(id)}
              onKeyDown={(event) => onKeyDown(event, index)}
              className={`settings-nav-item${selected ? " active" : ""}`}
            >
              <span style={{ position: "relative", display: "inline-flex", flexShrink: 0, marginTop: 2, color: selected ? "var(--accent)" : "currentColor" }}>
                <Icon size={16} aria-hidden="true" />
              </span>
              <div style={{ flex: 1, minWidth: 0, display: "flex", flexDirection: "column", gap: 2 }}>
                <div style={{ fontSize: 13, fontWeight: selected ? 600 : 500, lineHeight: 1.3, color: selected ? "var(--text)" : "inherit" }}>
                  {displayLabel}
                </div>
                <div style={{ fontSize: 11, color: "var(--text-dim)", lineHeight: 1.35, whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>
                  {displayDescription}
                </div>
              </div>
            </button>
          );
        })}
      </nav>
    );
  }

  return (
    <nav className="settings-nav-horizontal" aria-label={t("settingsTabs.ariaLabel")} role="tablist" style={{ display: "flex", gap: 3, padding: "7px 12px", borderBottom: "1px solid var(--border)", background: "var(--bg-panel)", flexShrink: 0, overflowX: "auto" }}>
      {SETTINGS_CATEGORIES.map(({ id, label, description, Icon }, index) => {
        const labelKey = `settingsTabs.${id}.label`;
        const descKey = `settingsTabs.${id}.description`;
        const trLabel = t(labelKey);
        const trDesc = t(descKey);
        const displayLabel = trLabel !== labelKey ? trLabel : label;
        const displayDescription = trDesc !== descKey ? trDesc : description;
        const selected = id === currentActive;
        return (
          <button
            key={id}
            type="button"
            role="tab"
            id={`settings-tab-${id}`}
            aria-selected={selected}
            aria-controls={`settings-panel-${id}`}
            aria-label={`${displayLabel}: ${displayDescription}`}
            title={displayDescription}
            tabIndex={selected ? 0 : -1}
            onClick={() => onSelect(id)}
            onKeyDown={(event) => onKeyDown(event, index)}
            style={{ display: "inline-flex", alignItems: "flex-start", gap: 5, padding: "6px 9px", border: "none", borderRadius: "var(--radius-control)", background: selected ? "var(--bg-selected)" : "transparent", color: selected ? "var(--text)" : "var(--text-muted)", cursor: "pointer", fontSize: 12, whiteSpace: "nowrap", textAlign: "left", minWidth: 150 }}
          >
            <span style={{ position: "relative", display: "inline-flex", flexShrink: 0, marginTop: 1 }}>
              <Icon size={13} aria-hidden="true" />
            </span>
            <span style={{ display: "flex", flexDirection: "column", gap: 1, minWidth: 0 }}>
              <span style={{ fontWeight: selected ? 600 : 500 }}>{displayLabel}</span>
              <span style={{ maxWidth: 220, overflow: "hidden", textOverflow: "ellipsis", color: "var(--text-muted)", fontSize: 10, fontWeight: 400, lineHeight: 1.25 }}>{displayDescription}</span>
            </span>
          </button>
        );
      })}
    </nav>
  );
}
