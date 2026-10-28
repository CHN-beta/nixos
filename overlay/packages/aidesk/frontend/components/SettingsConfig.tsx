
import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState, useTransition, cloneElement, isValidElement, type ReactElement, type ReactNode } from "react";
import { getSubmitDuringRunBehavior, getWordCompletionMode, setSubmitDuringRunBehavior, setWordCompletionMode, type SubmitDuringRunBehavior, type WordCompletionMode } from "@/lib/composer-prefs";
import { ArrowLeft, LogOut, RefreshCw, Search, X } from "lucide-react";
import { isRecord } from "@/lib/type-guards";
import { logoutFromAuth } from "@/lib/api-origin";
import {
  formatUsageReset,
  PROVIDER_DISPLAY_NAMES,
  reportUsageLimits,
  usageTone,
  usageWindowPercent,
  useProviderUsage,
} from "./AppShell-provider-usage";
import type { ProviderUsageLimitItem, ProviderUsageReport } from "@/lib/provider-usage-types";
import { Alert } from "@/components/ui/field";
import { toast } from "@/components/ui/toast";
import { useI18n } from "@/lib/i18n";
import { useIsMobile } from "@/hooks/useIsMobile";
import { SettingsTabs, type SettingsTab, SETTINGS_CATEGORIES, getNormalizedActive } from "./SettingsTabs";
import { useFontSize, type FontSizePreference } from "@/hooks/useFontSize";
import { useUiScale, type UiScalePreference } from "@/hooks/useUiScale";
import { useTouchTargets, type TouchTargetsPreference } from "@/hooks/useTouchTargets";
import { useSpeechSynthesis } from "@/hooks/useSpeechSynthesis";
import { useNotificationPrefs } from "@/hooks/useNotifications";
import { NOTIFICATION_TYPES, renderNotification, type NotificationType } from "@/lib/notification-events";
import {
  ensurePushSubscription,
  getNotificationDeviceId,
  getNotificationPrefs,
  getNotificationSupport,
  showSystemNotification,
  updateNotificationPrefs,
  type NotificationSupport,
} from "@/lib/notification-client";
import { OmpRuntimeVersion } from "./ChatWindow";

const nativeSelectStyle = {
  minHeight: "var(--control-height)",
  padding: "4px 28px 4px var(--control-padding-inline)",
  border: "1px solid var(--border)",
  borderRadius: "var(--radius-control)",
  background: "var(--bg)",
  color: "var(--text)",
  fontSize: "var(--text-sm)",
  maxWidth: "100%",
  overflow: "hidden",
  textOverflow: "ellipsis",
  whiteSpace: "nowrap",
  fontFamily: "inherit",
  cursor: "pointer",
  appearance: "none" as const,
  WebkitAppearance: "none" as const,
  MozAppearance: "none" as const,
  backgroundImage: `url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='12' height='12' viewBox='0 0 24 24' fill='none' stroke='%23888888' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'%3E%3Cpolyline points='6 9 12 15 18 9'%3E%3C/polyline%3E%3C/svg%3E")`,
  backgroundRepeat: "no-repeat" as const,
  backgroundPosition: "right 8px center" as const,
  outline: "none",
  colorScheme: "dark light",
} as const;

const nativeOptionStyle = {
  background: "var(--bg-panel)",
  color: "var(--text)",
  fontFamily: "inherit",
  fontSize: 12,
} as const;

const chipStyle = {
  fontSize: 10,
  padding: "1px 6px",
  borderRadius: 4,
  background: "var(--bg-subtle)",
  color: "var(--text-muted)",
  fontWeight: 500,
} as const;

const secondaryButtonStyle = {
  display: "inline-flex" as const,
  alignItems: "center" as const,
  gap: 6,
  padding: "6px 12px",
  border: "1px solid var(--border)",
  borderRadius: "var(--radius-control)",
  background: "var(--bg)",
  color: "var(--text)",
  fontSize: 12,
  fontWeight: 600,
  flexShrink: 0,
} as const;

const usageNoteStyle = {
  fontSize: 12.5,
  color: "var(--text-muted)",
  lineHeight: 1.5,
} as const;

function slugify(value: string): string {
  return value.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "");
}

const SettingsHighlightContext = createContext<string | null>(null);

type EnhancedChildProps = {
  id?: string;
  "aria-labelledby"?: string;
  "aria-describedby"?: string;
  "aria-label"?: string;
};

type SearchResult = {
  id: string;
  kind: "category" | "setting";
  tab: SettingsTab;
  label: string;
  description: string;
  scope?: string;
  section?: string;
};

type SettingIndexEntry = {
  id: string;
  tab: SettingsTab;
  sectionKey: string;
  labelKey: string;
  descKey: string;
  fallbackSection: string;
  fallbackLabel: string;
  fallbackDesc: string;
  scope?: "UI" | "Native OMP" | "Workspace";
};

// Search only indexes the settings the remaining tabs actually render.
const SETTING_INDEX: SettingIndexEntry[] = [
  // Interface & Behavior
  { id: "completion-sound", tab: "general", sectionKey: "settingsConfig.interfaceBehavior", labelKey: "settingsConfig.completionSound", descKey: "settingsConfig.completionSoundDesc", fallbackSection: "Interface & Behavior", fallbackLabel: "Completion sound", fallbackDesc: "Play a tone when the agent completes a run.", scope: "UI" },
  { id: "keep-tool-calls-collapsed", tab: "general", sectionKey: "settingsConfig.interfaceBehavior", labelKey: "settingsConfig.keepToolCallsCollapsed", descKey: "settingsConfig.keepToolCallsCollapsedDesc", fallbackSection: "Interface & Behavior", fallbackLabel: "Keep tool calls collapsed", fallbackDesc: "Show only compact headers while tools execute.", scope: "UI" },
  { id: "expand-thinking-by-default", tab: "general", sectionKey: "settingsConfig.interfaceBehavior", labelKey: "settingsConfig.expandThinkingByDefault", descKey: "settingsConfig.expandThinkingByDefaultDesc", fallbackSection: "Interface & Behavior", fallbackLabel: "Expand thinking blocks by default", fallbackDesc: "Open every thinking block as it appears, including while it streams, so reasoning is readable without clicking each one. Collapsing a block by hand still works.", scope: "UI" },
  { id: "open-url-automatically", tab: "general", sectionKey: "settingsConfig.interfaceBehavior", labelKey: "settingsConfig.openUrlAutomatically", descKey: "settingsConfig.openUrlAutomaticallyDesc", fallbackSection: "Interface & Behavior", fallbackLabel: "Open agent links without asking", fallbackDesc: "Links the agent opens from the session you are viewing open in a new tab right away. Links from other sessions always ask first. Your browser may still block pop-ups.", scope: "UI" },
  { id: "scope-native-select-all", tab: "general", sectionKey: "settingsConfig.interfaceBehavior", labelKey: "settingsConfig.scopeNativeSelectAll", descKey: "settingsConfig.scopeNativeSelectAllDesc", fallbackSection: "Interface & Behavior", fallbackLabel: "Scope native Select All (experimental)", fallbackDesc: "Limit whole-page selections from browser or touch menus to the active message, chat, or file. May also narrow deliberate whole-page selections. Turn off if selection handles or menus misbehave. Keyboard shortcuts are unaffected.", scope: "UI" },
  { id: "tts-autoplay", tab: "general", sectionKey: "settingsConfig.interfaceBehavior", labelKey: "settingsConfig.ttsAutoplay", descKey: "settingsConfig.ttsAutoplayDesc", fallbackSection: "Interface & Behavior", fallbackLabel: "Auto-read assistant responses", fallbackDesc: "Automatically read aloud new assistant replies when completed.", scope: "UI" },
  { id: "tts-voice", tab: "general", sectionKey: "settingsConfig.interfaceBehavior", labelKey: "settingsConfig.ttsVoice", descKey: "settingsConfig.ttsVoiceDesc", fallbackSection: "Interface & Behavior", fallbackLabel: "Speech Voice", fallbackDesc: "Select the browser voice for text-to-speech reading.", scope: "UI" },
  { id: "chat-font-size", tab: "general", sectionKey: "settingsConfig.interfaceBehavior", labelKey: "settingsConfig.chatFontSize", descKey: "settingsConfig.chatFontSizeDesc", fallbackSection: "Interface & Behavior", fallbackLabel: "Chat Font Size", fallbackDesc: "Adjust text size for conversation messages, code blocks, and markdown output.", scope: "UI" },
  { id: "ui-scale", tab: "general", sectionKey: "settingsConfig.interfaceBehavior", labelKey: "settingsConfig.uiScale", descKey: "settingsConfig.uiScaleDesc", fallbackSection: "Interface & Behavior", fallbackLabel: "Interface Scale", fallbackDesc: "Adjust overall UI zoom and display density across sidebars, dialogs, buttons, and toolbars.", scope: "UI" },
  { id: "touch-targets", tab: "general", sectionKey: "settingsConfig.interfaceBehavior", labelKey: "settingsConfig.touchTargets", descKey: "settingsConfig.touchTargetsDesc", fallbackSection: "Interface & Behavior", fallbackLabel: "Touch Targets", fallbackDesc: "Adjust interactive target sizes for buttons and toolbar controls.", scope: "UI" },
  { id: "message-during-active-run", tab: "general", sectionKey: "settingsConfig.interfaceBehavior", labelKey: "settingsConfig.messageDuringActiveRun", descKey: "settingsConfig.messageDuringActiveRunDesc", fallbackSection: "Interface & Behavior", fallbackLabel: "Message during active run", fallbackDesc: "What composer does on submit while agent runs. Steer interrupts; Queue follow-up delivers after finish.", scope: "UI" },
  { id: "word-completion", tab: "general", sectionKey: "settingsConfig.interfaceBehavior", labelKey: "settingsConfig.wordCompletion", descKey: "settingsConfig.wordCompletionDesc", fallbackSection: "Interface & Behavior", fallbackLabel: "Word completion", fallbackDesc: "Ghost text from omp's word prediction; Tab or → accepts. Auto enables it only with a mouse or trackpad (not on touch keyboards).", scope: "UI" },
  // Notifications
  { id: "notifications-enable", tab: "notifications", sectionKey: "notifications.title", labelKey: "notifications.enable", descKey: "notifications.enableDesc", fallbackSection: "Notifications", fallbackLabel: "Enable notifications", fallbackDesc: "Asks the browser for permission to show notifications.", scope: "UI" },
  { id: "notifications-completed", tab: "notifications", sectionKey: "notifications.title", labelKey: "notifications.typeCompleted", descKey: "notifications.typeCompletedDesc", fallbackSection: "Notifications", fallbackLabel: "Task finished", fallbackDesc: "A prompt and the background work it started are done. Subagents never notify.", scope: "UI" },
  { id: "notifications-input", tab: "notifications", sectionKey: "notifications.title", labelKey: "notifications.typeInput", descKey: "notifications.typeInputDesc", fallbackSection: "Notifications", fallbackLabel: "Waiting for input", fallbackDesc: "The agent asks a question or needs an approval.", scope: "UI" },
  { id: "notifications-error", tab: "notifications", sectionKey: "notifications.title", labelKey: "notifications.typeError", descKey: "notifications.typeErrorDesc", fallbackSection: "Notifications", fallbackLabel: "Run failed", fallbackDesc: "A run stops with an error after retries and fallbacks, or the omp process exits.", scope: "UI" },
  { id: "notifications-modelSwitch", tab: "notifications", sectionKey: "notifications.title", labelKey: "notifications.typeModelSwitch", descKey: "notifications.typeModelSwitchDesc", fallbackSection: "Notifications", fallbackLabel: "Model switched automatically", fallbackDesc: "omp switches models on its own: a fallback after a refusal, rate limit, or usage limit, or a prewalk / plan hand-off.", scope: "UI" },
  { id: "notifications-when-active", tab: "notifications", sectionKey: "notifications.title", labelKey: "notifications.whenActive", descKey: "notifications.whenActiveDesc", fallbackSection: "Notifications", fallbackLabel: "When I'm using AIDesk in another tab", fallbackDesc: "Nothing is shown for the session you are viewing.", scope: "UI" },
  // Account & Usage
  { id: "account-session", tab: "account", sectionKey: "settingsConfig.accountTitle", labelKey: "settingsConfig.accountSession", descKey: "settingsConfig.accountSessionDesc", fallbackSection: "Account & Usage", fallbackLabel: "Account & sign out", fallbackDesc: "Shows the signed-in user and signs out of the browser session.", scope: "UI" },
  { id: "account-usage", tab: "account", sectionKey: "settingsConfig.accountTitle", labelKey: "settingsConfig.accountUsage", descKey: "settingsConfig.accountUsageDesc", fallbackSection: "Account & Usage", fallbackLabel: "Quota & usage", fallbackDesc: "Provider quota, used amount, reset windows, and the current period.", scope: "UI" },
];

const ACKNOWLEDGMENTS = [
  { name: "ompweb", packageName: "@kahme247/ompweb", license: "MIT", url: "https://github.com/kahme247/ompweb" },
  { name: "oh-my-pi", packageName: "@can1357/oh-my-pi", license: "MIT", url: "https://github.com/can1357/oh-my-pi" },
  { name: "React", packageName: "react", license: "MIT", url: "https://react.dev" },
  { name: "CodeMirror 6", packageName: "@codemirror/*", license: "MIT", url: "https://codemirror.net" },
  { name: "xterm.js", packageName: "@xterm/xterm", license: "MIT", url: "https://xtermjs.org" },
  { name: "Lucide Icons", packageName: "lucide-react", license: "ISC", url: "https://lucide.dev" },
  { name: "Tailwind CSS", packageName: "tailwindcss", license: "MIT", url: "https://tailwindcss.com" },
] as const;

function SearchResultsList({ results, query, onSelect }: { results: SearchResult[]; query: string; onSelect: (result: SearchResult) => void }) {
  const { t, tn } = useI18n();
  const isMobile = useIsMobile();
  const formatScope = (s?: string) => {
    if (s === "UI") return t("settingsConfig.chipUI");
    if (s === "Native OMP") return t("settingsConfig.chipNativeOMP");
    if (s === "Workspace") return t("settingsConfig.chipWorkspace");
    return s;
  };

  return (
    <div style={{ flex: 1, minHeight: 0, overflowY: "auto", background: "var(--bg)", padding: isMobile ? "16px 14px 32px" : "32px 24px 64px" }}>
      <div className="settings-panel-inner" style={{ gap: 12 }}>
        <div style={{ fontSize: "var(--text-md)", color: "var(--text-muted)", marginBottom: 4 }}>
          {results.length === 0 ? t("settingsConfig.noSettingsMatch", { query }) : tn("settingsConfig.searchResults", results.length, { count: results.length, query })}
        </div>
        <div style={{ display: "flex", flexDirection: "column", gap: 10, width: "100%" }}>
          {results.map((result) => (
            <button
              key={result.id}
              type="button"
              onClick={() => onSelect(result)}
              className="settings-card"
              style={{
                textAlign: "left",
                display: "flex",
                flexDirection: "column",
                alignItems: "flex-start",
                gap: 4,
                padding: "14px 18px",
                width: "100%",
                boxSizing: "border-box",
                cursor: "pointer",
              }}
            >
              <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
                <span style={{ fontSize: 13.5, fontWeight: 600, color: "var(--text)" }}>{result.label}</span>
                {result.kind === "category" && (
                  <span style={chipStyle}>{t("settingsConfig.chipSection")}</span>
                )}
                {result.scope && (
                  <span style={chipStyle}>{formatScope(result.scope)}</span>
                )}
              </div>
              <div style={{ fontSize: "var(--text-sm)", color: "var(--text-muted)", lineHeight: 1.45 }}>{result.description}</div>
              {result.section && <div style={{ fontSize: 10.5, color: "var(--text-dim)", fontFamily: "var(--font-mono)" }}>{result.section}</div>}
            </button>
          ))}
        </div>
      </div>
    </div>
  );
}

function ToggleSwitch({
  checked,
  onChange,
  disabled,
  id,
  "aria-label": ariaLabel,
  "aria-labelledby": ariaLabelledBy,
  "aria-describedby": ariaDescribedBy,
}: {
  checked: boolean;
  onChange: (checked: boolean) => void;
  disabled?: boolean;
  id?: string;
  "aria-label"?: string;
  "aria-labelledby"?: string;
  "aria-describedby"?: string;
}) {
  return (
    <button
      id={id}
      type="button"
      role="switch"
      aria-checked={checked}
      aria-label={ariaLabel}
      aria-labelledby={ariaLabelledBy}
      aria-describedby={ariaDescribedBy}
      disabled={disabled}
      onClick={() => onChange(!checked)}
      className="ui-focus-ring"
      style={{
        position: "relative",
        display: "inline-flex",
        alignItems: "center",
        justifyContent: "center",
        width: 44,
        height: 44,
        padding: 0,
        border: "none",
        background: "transparent",
        cursor: disabled ? "not-allowed" : "pointer",
        flexShrink: 0,
      }}
    >
      <span
        aria-hidden="true"
        style={{
          display: "inline-flex",
          alignItems: "center",
          width: 40,
          height: 24,
          padding: 2,
          borderRadius: 12,
          background: checked ? "var(--accent-strong)" : "var(--border)",
          transition: "background var(--dur-fast)",
        }}
      >
        <span
          style={{
            width: 20,
            height: 20,
            borderRadius: 10,
            background: "#fff",
            transform: checked ? "translateX(16px)" : "translateX(0px)",
            transition: "transform var(--dur-fast)",
            boxShadow: "0 1px 3px rgba(0,0,0,0.2)",
          }}
        />
      </span>
    </button>
  );
}

const NOTIFICATION_TYPE_LABELS: Record<NotificationType, { label: string; desc: string }> = {
  completed: { label: "notifications.typeCompleted", desc: "notifications.typeCompletedDesc" },
  input: { label: "notifications.typeInput", desc: "notifications.typeInputDesc" },
  error: { label: "notifications.typeError", desc: "notifications.typeErrorDesc" },
  modelSwitch: { label: "notifications.typeModelSwitch", desc: "notifications.typeModelSwitchDesc" },
};

const NOTIFICATION_STATUS_KEYS: Record<Exclude<NotificationSupport, "push" | "no-push">, string> = {
  insecure: "notifications.statusInsecure",
  "ios-install": "notifications.statusIosInstall",
  unsupported: "notifications.statusUnsupported",
  denied: "notifications.statusDenied",
};

/** Per-device notification prefs (lib/notification-client.ts), mirrored to the server. */
function NotificationSettingsPanel() {
  const { t, locale } = useI18n();
  const prefs = useNotificationPrefs();
  const [support, setSupport] = useState<NotificationSupport | null>(null);
  const [pushActive, setPushActive] = useState(false);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    let alive = true;
    setSupport(getNotificationSupport());
    // Enabled: join (or redo) the app's startup repair, which is single-flight,
    // so the status reflects the subscription after any repair, not before it.
    const pushState: Promise<boolean> = getNotificationPrefs().enabled
      ? ensurePushSubscription()
      : fetch(`/api/notifications/devices?deviceId=${encodeURIComponent(getNotificationDeviceId())}`)
          .then((res) => (res.ok ? res.json() : null))
          .then((data: { subscribed?: boolean } | null) => data?.subscribed === true);
    pushState.then((active) => { if (alive) setPushActive(active); }).catch(() => {});
    return () => { alive = false; };
  }, []);

  const errorText = (error: unknown) => (error instanceof Error ? error.message : String(error));

  const save = (patch: Parameters<typeof updateNotificationPrefs>[0]) => {
    void updateNotificationPrefs(patch).catch((error: unknown) => toast.error(t("notifications.saveFailed"), errorText(error)));
  };

  const setEnabled = async (enabled: boolean) => {
    setBusy(true);
    try {
      // First await inside the click: Safari only prompts during the user gesture.
      if (enabled && "Notification" in window && Notification.permission === "default") await Notification.requestPermission();
      await updateNotificationPrefs({ enabled, locale });
      if (enabled) setPushActive(await ensurePushSubscription());
    } catch (error) {
      toast.error(t("notifications.enableFailed", { error: errorText(error) }));
    } finally {
      setSupport(getNotificationSupport());
      setBusy(false);
    }
  };

  // With push, the server sends a real push; otherwise this tab shows one itself.
  const sendTest = async () => {
    const testNotification = renderNotification({ type: "test", sessionId: "", sessionName: "AIDesk" }, t);
    try {
      if (pushActive) {
        const res = await fetch("/api/notifications/test", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ deviceId: getNotificationDeviceId() }),
        });
        if (!res.ok) {
          const body: unknown = await res.json().catch(() => null);
          // The server drops a subscription the push service reports gone;
          // resubscribe so the next test (and real pushes) can reach this device.
          setPushActive(await ensurePushSubscription().catch(() => false));
          throw new Error(isRecord(body) && typeof body.error === "string" ? body.error : `HTTP ${res.status}`);
        }
      } else if (!(await showSystemNotification(testNotification))) {
        // No system notifications here (plain HTTP, permission missing): in-app toasts are what this browser gets.
        toast.info(testNotification.title, testNotification.body);
        return;
      }
      toast.success(t("notifications.testSent"));
    } catch (error) {
      toast.error(t("notifications.testFailed"), errorText(error));
    }
  };

  let status: string | null = null;
  if (support && support !== "push" && support !== "no-push") status = t(NOTIFICATION_STATUS_KEYS[support]);
  else if (support && prefs.enabled) {
    if (Notification.permission !== "granted") status = t("notifications.statusPermission");
    else status = t(pushActive ? "notifications.statusPush" : "notifications.statusInPage");
  }

  return (
    <>
      <NativeSetting searchId="notifications-enable" scope="UI" label={t("notifications.enable")} description={t("notifications.enableDesc")}>
        <ToggleSwitch checked={prefs.enabled} disabled={busy} onChange={(next) => void setEnabled(next)} />
      </NativeSetting>
      {status && <Alert variant={support === "push" || support === "no-push" ? "info" : "warning"} description={status} />}
      {NOTIFICATION_TYPES.map((type) => (
        <NativeSetting key={type} searchId={`notifications-${type}`} scope="UI" disabled={!prefs.enabled} label={t(NOTIFICATION_TYPE_LABELS[type].label)} description={t(NOTIFICATION_TYPE_LABELS[type].desc)}>
          <ToggleSwitch checked={prefs.types[type]} disabled={!prefs.enabled} onChange={(next) => save({ types: { ...prefs.types, [type]: next } })} />
        </NativeSetting>
      ))}
      <NativeSetting searchId="notifications-when-active" scope="UI" disabled={!prefs.enabled} label={t("notifications.whenActive")} description={t("notifications.whenActiveDesc")}>
        <select
          style={nativeSelectStyle}
          value={prefs.whenActive}
          disabled={!prefs.enabled}
          onChange={(event) => save({ whenActive: event.target.value === "system" ? "system" : "toast" })}
        >
          <option value="toast" style={nativeOptionStyle}>{t("notifications.whenActiveToast")}</option>
          <option value="system" style={nativeOptionStyle}>{t("notifications.whenActiveSystem")}</option>
        </select>
      </NativeSetting>
      <div>
        <button
          type="button"
          onClick={() => void sendTest()}
          disabled={!prefs.enabled}
          style={{
            padding: "6px 14px",
            border: "1px solid var(--accent-strong)",
            borderRadius: "var(--radius-control)",
            background: "var(--accent-strong)",
            color: "var(--on-accent)",
            cursor: prefs.enabled ? "pointer" : "not-allowed",
            fontSize: 12,
            fontWeight: 600,
            opacity: prefs.enabled ? 1 : 0.6,
          }}
        >
          {t("notifications.test")}
        </button>
      </div>
    </>
  );
}

/** `disabled` only dims the row; the child control must be disabled itself. */
function NativeSetting({ label, description, scope, searchId, disabled, children }: { label: string; description: string; scope?: "UI" | "Native OMP" | "Workspace"; searchId?: string; disabled?: boolean; children: ReactNode }) {
  const { t } = useI18n();
  const ref = useRef<HTMLDivElement>(null);
  const highlightId = useContext(SettingsHighlightContext);
  const settingSlug = searchId || slugify(label);
  const highlighted = highlightId !== null && (highlightId === settingSlug || highlightId === slugify(label));
  const settingId = 'setting-' + settingSlug;
  const labelId = 'setting-label-' + settingSlug;
  const descId = 'setting-desc-' + settingSlug;

  const formatScope = (s?: string) => {
    if (s === "UI") return t("settingsConfig.chipUI");
    if (s === "Native OMP") return t("settingsConfig.chipNativeOMP");
    if (s === "Workspace") return t("settingsConfig.chipWorkspace");
    return s;
  };

  useEffect(() => {
    if (highlighted && ref.current) {
      ref.current.scrollIntoView({ behavior: "smooth", block: "center" });
    }
  }, [highlighted]);

  let enhancedChild = children;
  if (isValidElement(children)) {
    const childProps = children.props as EnhancedChildProps;
    enhancedChild = cloneElement(children as ReactElement<EnhancedChildProps>, {
      id: childProps.id || settingId,
      "aria-labelledby": childProps["aria-labelledby"] || labelId,
      "aria-describedby": childProps["aria-describedby"] || descId,
      "aria-label": childProps["aria-label"] || label,
    });
  }

  return (
    <div
      ref={ref}
      data-search-id={settingSlug}
      className="settings-card"
      style={{
        minWidth: 0,
        width: "100%",
        boxSizing: "border-box",
        marginBottom: 10,
        opacity: disabled ? 0.5 : 1,
        transition: "box-shadow var(--dur-fast), border-color var(--dur-fast), opacity var(--dur-fast)",
        ...(highlighted ? { borderColor: "var(--accent)", boxShadow: "0 0 0 2px var(--accent)" } : {}),
      }}
    >
      <div className="settings-card-text">
        <div style={{ display: "flex", alignItems: "center", gap: 8, marginBottom: 4 }}>
          <label id={labelId} htmlFor={settingId} className="settings-card-title" style={{ cursor: disabled ? "default" : "pointer" }}>{label}</label>
          {scope && (
            <span style={chipStyle}>
              {formatScope(scope)}
            </span>
          )}
        </div>
        <span id={descId} className="settings-card-desc">{description}</span>
      </div>
      <span className="settings-card-control">{enhancedChild}</span>
    </div>
  );
}

const UNIT_LABEL_KEYS: Record<string, string> = {
  tokens: "providerUsage.unitTokens",
  requests: "providerUsage.unitRequests",
  credits: "providerUsage.unitCredits",
  minutes: "providerUsage.unitMinutes",
  bytes: "providerUsage.unitBytes",
};

const WINDOW_LABEL_KEYS: Record<string, string> = {
  "5h": "providerUsage.window5h",
  "7d": "providerUsage.window7d",
  monthly: "providerUsage.windowMonthly",
};

/** `$3.45`, or `$0.0042` for sub-cent amounts. */
function formatUsageAmount(value: number, unit?: string): string {
  if (unit === "usd") return value > 0 && value < 0.01 ? `$${value.toFixed(4)}` : `$${value.toFixed(2)}`;
  if (unit === "percent") return `${Math.round(value)}%`;
  return new Intl.NumberFormat(undefined, { maximumFractionDigits: 2 }).format(value);
}

type AccountInfo = {
  user: string;
  name: string | null;
  email: string | null;
  groups: string[];
};

/** Settings card that participates in search highlighting like NativeSetting. */
function AccountSection({ searchId, children }: { searchId: string; children: ReactNode }) {
  const highlightId = useContext(SettingsHighlightContext);
  const ref = useRef<HTMLElement>(null);
  const highlighted = highlightId === searchId;
  useEffect(() => {
    if (highlighted && ref.current) ref.current.scrollIntoView({ behavior: "smooth", block: "center" });
  }, [highlighted]);
  return (
    <section
      ref={ref}
      data-search-id={searchId}
      className="settings-card"
      style={{
        display: "block",
        width: "100%",
        boxSizing: "border-box",
        padding: "16px 18px",
        transition: "box-shadow var(--dur-fast), border-color var(--dur-fast)",
        ...(highlighted ? { borderColor: "var(--accent)", boxShadow: "0 0 0 2px var(--accent)" } : {}),
      }}
    >
      {children}
    </section>
  );
}

/** One quota window: amounts first, a bar only when a share is known. */
function UsageLimitRow({ limit }: { limit: ProviderUsageLimitItem }) {
  const { t } = useI18n();
  const percent = usageWindowPercent(limit);
  const used = typeof limit.used === "number" ? limit.used : undefined;
  const quota = typeof limit.limit === "number" ? limit.limit : undefined;
  const remaining = typeof limit.remaining === "number"
    ? limit.remaining
    : quota !== undefined && used !== undefined
      ? Math.max(0, quota - used)
      : undefined;
  const resetValue = limit.resetMinutes ?? limit.resetHours;
  const reset = resetValue === undefined
    ? null
    : formatUsageReset(resetValue, limit.resetMinutes !== undefined ? "minutes" : "hours");
  const labelKey = limit.windowId ? WINDOW_LABEL_KEYS[limit.windowId] : undefined;
  const label = labelKey ? t(labelKey) : limit.label ?? limit.windowId ?? t("providerUsage.limit");
  const unitSuffix = limit.unit && limit.unit !== "usd" && limit.unit !== "percent"
    ? ` ${t(UNIT_LABEL_KEYS[limit.unit] ?? limit.unit)}`
    : "";
  const amount = (value: number) => `${formatUsageAmount(value, limit.unit)}${unitSuffix}`;

  let primary: string;
  if (used !== undefined) {
    primary = quota !== undefined
      ? `${t("providerUsage.used")} ${amount(used)} / ${t("providerUsage.quota")} ${amount(quota)}`
      : `${t("providerUsage.used")} ${amount(used)}`;
  } else if (percent !== null) {
    primary = `${t("providerUsage.used")} ${Math.round(percent)}%`;
  } else if (quota !== undefined) {
    primary = `${t("providerUsage.quota")} ${amount(quota)}`;
  } else {
    primary = "";
  }

  const meta: string[] = [];
  if (quota !== undefined && remaining !== undefined) meta.push(`${t("providerUsage.remaining")} ${amount(remaining)}`);
  if (used !== undefined && quota === undefined) meta.push(`${t("providerUsage.quota")}: ${t("providerUsage.unlimited")}`);
  if (reset) meta.push(t("providerUsage.resets", { value: reset }));

  return (
    <div style={{ display: "flex", flexDirection: "column", gap: 5 }}>
      <div style={{ display: "flex", alignItems: "baseline", justifyContent: "space-between", gap: 8, flexWrap: "wrap" }}>
        <span style={{ fontSize: 12, fontWeight: 500, color: "var(--text-muted)" }}>{label}</span>
        <span style={{ fontSize: 12, color: "var(--text)", fontVariantNumeric: "tabular-nums", textAlign: "right" }}>{primary}</span>
      </div>
      {percent !== null && (
        <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
          <div style={{ flex: 1, height: 6, borderRadius: 3, background: "var(--bg-subtle)", overflow: "hidden" }}>
            <div
              style={{
                width: `${Math.min(100, Math.max(0, percent))}%`,
                height: "100%",
                borderRadius: 3,
                background: usageTone(percent),
                transition: "width var(--dur-fast)",
              }}
            />
          </div>
          <span style={{ fontSize: 11, minWidth: 34, textAlign: "right", color: "var(--text-muted)", fontVariantNumeric: "tabular-nums" }}>
            {Math.round(percent)}%
          </span>
        </div>
      )}
      {meta.length > 0 && (
        <div style={{ fontSize: 11, color: "var(--text-dim)" }}>{meta.join(" · ")}</div>
      )}
    </div>
  );
}

function UsageReportBlock({ report }: { report: ProviderUsageReport }) {
  const { t } = useI18n();
  const limits = reportUsageLimits(report);
  return (
    <div style={{ display: "flex", flexDirection: "column", gap: 8 }}>
      <div style={{ display: "flex", alignItems: "center", gap: 8, flexWrap: "wrap" }}>
        <span style={{ fontSize: 13.5, fontWeight: 600, color: "var(--text)" }}>
          {PROVIDER_DISPLAY_NAMES[report.provider] ?? report.provider}
        </span>
        {report.accountLabel && (
          <span style={{ fontFamily: "var(--font-mono)", fontSize: 11.5, color: "var(--text-muted)" }}>{report.accountLabel}</span>
        )}
        {report.plan && <span style={chipStyle}>{report.plan}</span>}
        {report.tier && <span style={chipStyle}>{report.tier}</span>}
        {report.modelId && <span style={chipStyle}>{report.modelId}</span>}
      </div>
      {report.noLimits ? (
        <span style={usageNoteStyle}>{t("providerUsage.noLimits")}</span>
      ) : limits.length === 0 ? (
        <span style={usageNoteStyle}>{t("providerUsage.noData")}</span>
      ) : (
        limits.map((limit, index) => (
          <UsageLimitRow key={`${limit.windowId ?? "limit"}-${index}`} limit={limit} />
        ))
      )}
    </div>
  );
}

/** Account session + provider quota; the sidebar widget used to cover this. */
function AccountPanel({ isMobile }: { isMobile: boolean }) {
  const { t } = useI18n();
  const [account, setAccount] = useState<AccountInfo | null>(null);
  const [accountFailed, setAccountFailed] = useState(false);
  const [refreshing, setRefreshing] = useState(false);
  const { snapshot, loading, error, refresh } = useProviderUsage("", 5 * 60_000);

  useEffect(() => {
    let alive = true;
    fetch("/api/account")
      .then(async (response) => {
        if (!response.ok) throw new Error(`HTTP ${response.status}`);
        const data: unknown = await response.json();
        if (!isRecord(data) || typeof data.user !== "string") throw new Error("invalid account payload");
        return {
          user: data.user,
          name: typeof data.name === "string" && data.name.trim() ? data.name.trim() : null,
          email: typeof data.email === "string" && data.email.trim() ? data.email.trim() : null,
          groups: Array.isArray(data.groups)
            ? data.groups.filter((group): group is string => typeof group === "string")
            : [],
        };
      })
      .then((info) => {
        if (!alive) return;
        setAccount(info);
        setAccountFailed(false);
      })
      .catch(() => {
        if (alive) setAccountFailed(true);
      });
    return () => { alive = false; };
  }, []);

  const reports = snapshot?.reports ?? [];
  const displayName = account ? account.name ?? account.user : "";

  const handleRefresh = async () => {
    setRefreshing(true);
    try {
      await refresh();
    } finally {
      setRefreshing(false);
    }
  };

  return (
    <div role="tabpanel" id="settings-panel-account" aria-labelledby="settings-tab-account" className="settings-panel-inner" style={{ padding: isMobile ? "16px 14px 32px" : "32px 24px 64px", gap: 16 }}>
      <div style={{ marginBottom: 4 }}>
        <h2 className="display-serif" style={{ fontSize: "var(--text-2xl)", fontWeight: 600, margin: 0, color: "var(--text)", letterSpacing: "-0.01em" }}>{t("settingsConfig.accountTitle")}</h2>
        <p className="settings-content-subtitle" style={{ margin: "4px 0 16px", fontSize: "var(--text-md)", color: "var(--text-muted)", lineHeight: 1.45 }}>{t("settingsConfig.accountDescription")}</p>
      </div>

      <AccountSection searchId="account-session">
        <div style={{ display: "flex", alignItems: "flex-start", justifyContent: "space-between", gap: 16, flexWrap: "wrap" }}>
          <div style={{ display: "flex", flexDirection: "column", gap: 3, minWidth: 0 }}>
            <span style={{ fontSize: 11, fontWeight: 500, color: "var(--text-muted)", letterSpacing: "0.01em" }}>{t("settingsConfig.accountSignedInAs")}</span>
            {account ? (
              <>
                <span style={{ fontSize: 15, fontWeight: 600, color: "var(--text)", overflow: "hidden", textOverflow: "ellipsis" }}>{displayName}</span>
                {account.name !== null && account.name !== account.user && (
                  <span style={{ fontFamily: "var(--font-mono)", fontSize: 12, color: "var(--text-muted)" }}>{account.user}</span>
                )}
                {account.email !== null && (
                  <span style={{ fontSize: 12, color: "var(--text-muted)" }}>{account.email}</span>
                )}
                {account.groups.length > 0 && (
                  <span style={{ display: "flex", flexWrap: "wrap", gap: 4, marginTop: 4 }}>
                    {account.groups.map((group) => <span key={group} style={chipStyle}>{group}</span>)}
                  </span>
                )}
              </>
            ) : (
              <span style={{ fontSize: 12.5, color: "var(--text-muted)" }}>
                {accountFailed ? t("settingsConfig.accountUnavailable") : t("settingsConfig.accountLoading")}
              </span>
            )}
          </div>
          <button
            type="button"
            onClick={logoutFromAuth}
            className="ui-focus-ring"
            style={{ ...secondaryButtonStyle, padding: "7px 14px", fontSize: 12.5, cursor: "pointer" }}
          >
            <LogOut size={14} aria-hidden="true" />
            {t("settingsConfig.accountSignOut")}
          </button>
        </div>
      </AccountSection>

      <AccountSection searchId="account-usage">
        <div style={{ display: "flex", alignItems: "flex-start", justifyContent: "space-between", gap: 12, marginBottom: 12, flexWrap: "wrap" }}>
          <div style={{ minWidth: 0 }}>
            <h3 style={{ margin: 0, fontSize: 13.5, fontWeight: 600, color: "var(--text)" }}>{t("settingsConfig.accountUsage")}</h3>
            <p style={{ margin: "2px 0 0", fontSize: 12, color: "var(--text-muted)", lineHeight: 1.45 }}>{t("settingsConfig.accountUsageDesc")}</p>
          </div>
          <button
            type="button"
            onClick={() => void handleRefresh()}
            disabled={refreshing || loading}
            className="ui-focus-ring"
            style={{ ...secondaryButtonStyle, cursor: refreshing || loading ? "not-allowed" : "pointer", opacity: refreshing || loading ? 0.55 : 1 }}
          >
            <RefreshCw size={13} aria-hidden="true" />
            {t("settingsConfig.accountUsageRefresh")}
          </button>
        </div>
        {loading && reports.length === 0 ? (
          <div style={usageNoteStyle}>{t("settingsConfig.accountUsageLoading")}</div>
        ) : error && reports.length === 0 ? (
          <div style={usageNoteStyle}>{t("settingsConfig.accountUsageError")}</div>
        ) : reports.length === 0 ? (
          <div style={usageNoteStyle}>{t("settingsConfig.accountUsageEmpty")}</div>
        ) : (
          <div style={{ display: "flex", flexDirection: "column", gap: 14 }}>
            {reports.map((report, index) => (
              <UsageReportBlock key={`${report.provider}:${report.accountLabel ?? report.accountIndex ?? index}:${report.modelId ?? ""}:${report.tier ?? ""}`} report={report} />
            ))}
          </div>
        )}
      </AccountSection>
    </div>
  );
}

function AboutPanel({ isMobile }: { isMobile: boolean }) {
  const { t } = useI18n();
  const rowStyle = { display: "flex", alignItems: "center", justifyContent: "space-between", gap: 16, padding: "12px 16px", borderBottom: "1px solid var(--border)" } as const;
  const valueStyle = { fontFamily: "var(--font-mono)", fontSize: 12, color: "var(--text-muted)", flexShrink: 0 } as const;
  return (
    <div role="tabpanel" id="settings-panel-about" aria-labelledby="settings-tab-about" className="settings-panel-inner" style={{ padding: isMobile ? "16px 14px 32px" : "32px 24px 64px", gap: 16 }}>
      <div style={{ marginBottom: 4 }}>
        <h2 className="display-serif" style={{ fontSize: "var(--text-2xl)", fontWeight: 600, margin: 0, color: "var(--text)", letterSpacing: "-0.01em" }}>{t("settingsConfig.aboutTitle")}</h2>
        <p className="settings-content-subtitle" style={{ margin: "4px 0 16px", fontSize: "var(--text-md)", color: "var(--text-muted)", lineHeight: 1.45 }}>{t("settingsConfig.aboutDescription")}</p>
      </div>

      <section className="settings-card" style={{ display: "block", width: "100%", boxSizing: "border-box", padding: 0, overflow: "hidden" }}>
        <div style={rowStyle}>
          <span style={{ fontSize: 13, fontWeight: 600 }}>{t("settingsConfig.aboutAppVersion")}</span>
          <span style={valueStyle}>v{__APP_VERSION__}</span>
        </div>
        <div style={{ ...rowStyle, borderBottom: "none" }}>
          <span style={{ fontSize: 13, fontWeight: 600 }}>{t("settingsConfig.aboutRuntimeVersion")}</span>
          <span style={{ ...valueStyle, display: "inline-flex", alignItems: "center", gap: 4 }}><OmpRuntimeVersion /></span>
        </div>
      </section>

      <section style={{ display: "flex", flexDirection: "column", gap: 8, width: "100%" }}>
        <h3 style={{ margin: 0, fontSize: 13.5, fontWeight: 600, color: "var(--text)" }}>{t("settingsConfig.aboutAcknowledgments")}</h3>
        <p style={{ margin: 0, fontSize: 12.5, color: "var(--text-muted)", lineHeight: 1.5 }}>{t("settingsConfig.aboutAcknowledgmentsDesc")}</p>
        <div className="settings-card" style={{ display: "block", width: "100%", boxSizing: "border-box", padding: 0, overflow: "hidden" }}>
          {ACKNOWLEDGMENTS.map((entry, index) => (
            <div key={entry.name} style={{ ...rowStyle, borderBottom: index === ACKNOWLEDGMENTS.length - 1 ? "none" : rowStyle.borderBottom }}>
              <span style={{ display: "flex", flexDirection: "column", gap: 2, minWidth: 0 }}>
                <a href={entry.url} target="_blank" rel="noreferrer" style={{ fontSize: 13, fontWeight: 600, color: "var(--text)", textDecoration: "none" }}>{entry.name}</a>
                <span style={{ fontSize: 11, color: "var(--text-dim)", fontFamily: "var(--font-mono)", overflow: "hidden", textOverflow: "ellipsis" }}>{entry.packageName}</span>
              </span>
              <span style={{ ...valueStyle, flexShrink: 0 }}>{entry.license}</span>
            </div>
          ))}
        </div>
      </section>
    </div>
  );
}

export function SettingsConfig({ activeTab, toolCallsDefaultCollapsed, onToolCallsDefaultCollapsedChange, expandThinkingByDefault, onExpandThinkingByDefaultChange, scopeNativeSelectAll, onScopeNativeSelectAllChange, openUrlAutomatically, onOpenUrlAutomaticallyChange, onSelectTab, onClose }: {
  activeTab: SettingsTab;
  toolCallsDefaultCollapsed: boolean;
  onToolCallsDefaultCollapsedChange: (collapsed: boolean) => void;
  expandThinkingByDefault: boolean;
  onExpandThinkingByDefaultChange: (expand: boolean) => void;
  scopeNativeSelectAll: boolean;
  onScopeNativeSelectAllChange: (enabled: boolean) => void;
  openUrlAutomatically: boolean;
  onOpenUrlAutomaticallyChange: (enabled: boolean) => void;
  onSelectTab: (tab: SettingsTab) => void;
  onClose: () => void;
}) {
  const isMobile = useIsMobile();
  const { t } = useI18n();
  const { fontSize, setFontSize } = useFontSize();
  const { uiScale, setUiScale } = useUiScale();
  const { touchTargets, setTouchTargets } = useTouchTargets();
  const {
    isSupported: ttsSupported,
    autoPlayEnabled: ttsAutoPlay,
    setAutoPlay: setTtsAutoPlay,
    voices: ttsVoices,
    selectedVoiceURI: ttsVoiceURI,
    setSelectedVoiceURI: setTtsVoiceURI,
  } = useSpeechSynthesis();
  const [searchQuery, setSearchQuery] = useState("");
  const [highlightId, setHighlightId] = useState<string | null>(null);
  const [submitBehavior, setSubmitBehavior] = useState<SubmitDuringRunBehavior>(() => getSubmitDuringRunBehavior());
  const [wordCompletion, setWordCompletion] = useState<WordCompletionMode>(() => getWordCompletionMode());
  const [soundEnabled, setSoundEnabled] = useState<boolean>(() => {
    if (typeof window === "undefined") return true;
    try {
      const value = window.localStorage.getItem("omp-sound-enabled");
      return value === null ? true : value === "true";
    } catch {
      return true;
    }
  });
  const [isPending, startTransition] = useTransition();

  const currentTab = getNormalizedActive(activeTab);
  const trimmedQuery = searchQuery.trim().toLowerCase();
  const searchActive = trimmedQuery.length > 0;

  const searchResults = useMemo<SearchResult[]>(() => {
    if (!trimmedQuery) return [];
    const results: SearchResult[] = [];
    for (const category of SETTINGS_CATEGORIES) {
      const labelKeyCat = `settingsTabs.${category.id}.label`;
      const descKeyCat = `settingsTabs.${category.id}.description`;
      const trLabelCat = t(labelKeyCat);
      const trDescCat = t(descKeyCat);
      const localizedLabel = trLabelCat !== labelKeyCat ? trLabelCat : category.label;
      const localizedDesc = trDescCat !== descKeyCat ? trDescCat : category.description;
      const haystack = `${localizedLabel} ${localizedDesc} ${category.label} ${category.description}`.toLowerCase();
      if (haystack.includes(trimmedQuery)) {
        results.push({ id: `tab-${category.id}`, kind: "category", tab: category.id, label: localizedLabel, description: localizedDesc });
      }
    }
    for (const setting of SETTING_INDEX) {
      const trLabel = t(setting.labelKey);
      const trDesc = t(setting.descKey);
      const trSection = t(setting.sectionKey);
      const localizedLabel = trLabel !== setting.labelKey ? trLabel : setting.fallbackLabel;
      const localizedDesc = trDesc !== setting.descKey ? trDesc : setting.fallbackDesc;
      const localizedSection = trSection !== setting.sectionKey ? trSection : setting.fallbackSection;
      const haystack = `${localizedLabel} ${localizedDesc} ${localizedSection} ${setting.fallbackLabel} ${setting.fallbackDesc} ${setting.fallbackSection}`.toLowerCase();
      if (haystack.includes(trimmedQuery)) {
        results.push({ id: setting.id, kind: "setting", tab: setting.tab, label: localizedLabel, description: localizedDesc, scope: setting.scope, section: localizedSection });
      }
    }
    return results;
  }, [trimmedQuery, t]);

  const openSearchResult = useCallback((result: SearchResult) => {
    startTransition(() => onSelectTab(result.tab));
    setHighlightId(result.kind === "setting" ? result.id : null);
    setSearchQuery("");
  }, [onSelectTab]);

  const handleSelectTab = useCallback((tab: SettingsTab) => {
    startTransition(() => onSelectTab(tab));
  }, [onSelectTab]);

  const contentStyle = useMemo(() => ({
    flex: 1 as const,
    minHeight: 0,
    display: "flex" as const,
    flexDirection: "column" as const,
    overflowY: "auto" as const,
    background: "var(--bg)" as const,
    opacity: isPending ? 0.92 : 1,
    transition: isPending ? "opacity 80ms ease-out" : "opacity 120ms ease-out",
  }), [isPending]);

  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === "Escape") {
        // Keep Escape for clearing a filled field; a checkbox's DOM value is always "on".
        const target = e.target;
        if (target instanceof HTMLInputElement && target.type !== "checkbox" && target.value) return;
        onClose();
      }
    };
    window.addEventListener("keydown", handleKeyDown);
    return () => window.removeEventListener("keydown", handleKeyDown);
  }, [onClose]);

  return (
    <div className="settings-view" role="region" aria-label={t("settingsConfig.title")}>
      <header className="settings-header">
        <div style={{ display: "flex", alignItems: "center", gap: 12 }}>
          <button
            type="button"
            className="settings-back"
            onClick={onClose}
            aria-label={t("settingsConfig.back")}
            title={`${t("settingsConfig.back")} (Esc)`}
          >
            <ArrowLeft size={15} aria-hidden="true" />
            <span>{t("settingsConfig.back")}</span>
          </button>
          <span style={{ width: 1, height: 18, background: "var(--border)", opacity: 0.8 }} aria-hidden="true" />
          <h1 style={{ fontSize: "var(--text-lg)", margin: 0, fontWeight: 600, letterSpacing: "-0.01em", color: "var(--text)" }}>
            {t("settingsConfig.title")}
          </h1>
        </div>

        <div style={{ display: "flex", alignItems: "center", gap: 10, flex: 1, maxWidth: 380, justifyContent: "flex-end" }}>
          <div style={{ position: "relative", width: "100%", maxWidth: 280 }}>
            <Search size={13} aria-hidden="true" style={{ position: "absolute", left: 10, top: "50%", transform: "translateY(-50%)", color: "var(--text-muted)", pointerEvents: "none" }} />
            <input
              type="text"
              aria-label={t("settingsConfig.searchPlaceholder")}
              placeholder={t("settingsConfig.searchPlaceholder")}
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === "Escape") {
                  if (searchQuery) {
                    e.stopPropagation();
                    setSearchQuery("");
                    setHighlightId(null);
                  } else {
                    onClose();
                  }
                  (e.target as HTMLInputElement).blur();
                }
              }}
              style={{ width: "100%", height: "var(--row-height-compact)", padding: "0 28px 0 30px", border: "1px solid var(--border)", borderRadius: "var(--radius-control)", background: "var(--bg)", color: "var(--text)", fontSize: "var(--text-sm)", outline: "none" }}
            />
            {searchQuery && (
              <button
                type="button"
                onClick={() => { setSearchQuery(""); setHighlightId(null); }}
                style={{ position: "absolute", right: 6, top: "50%", transform: "translateY(-50%)", background: "none", border: "none", color: "var(--text-muted)", cursor: "pointer", padding: 2, display: "flex", alignItems: "center", justifyContent: "center" }}
                aria-label="Clear search"
              >
                <X size={12} aria-hidden="true" />
              </button>
            )}
          </div>
          <button
            type="button"
            onClick={onClose}
            aria-label={t("settingsConfig.closeSettings")}
            title={`${t("settingsConfig.closeSettings")} (Esc)`}
            className="settings-close-btn ui-focus-ring"
          >
            <X size={16} aria-hidden="true" />
          </button>
        </div>
      </header>

      <div className="settings-body">
        {searchActive ? (
          <SearchResultsList results={searchResults} query={searchQuery.trim()} onSelect={openSearchResult} />
        ) : (
          <SettingsHighlightContext.Provider value={highlightId}>
            <SettingsTabs active={currentTab} onSelect={handleSelectTab} layout={isMobile ? "horizontal" : "vertical"} />

            <div className="settings-content" style={contentStyle}>
              {currentTab === "general" && (
                <div role="tabpanel" id="settings-panel-general" aria-labelledby="settings-tab-general" className="settings-panel-inner" style={{ padding: isMobile ? "16px 14px 32px" : "32px 24px 64px", gap: 16 }}>
                  <div style={{ marginBottom: 4 }}>
                    <h2 className="display-serif" style={{ fontSize: "var(--text-2xl)", fontWeight: 600, margin: 0, color: "var(--text)", letterSpacing: "-0.01em" }}>{t("settingsConfig.interfaceBehavior")}</h2>
                    <p className="settings-content-subtitle" style={{ margin: "4px 0 16px", fontSize: "var(--text-md)", color: "var(--text-muted)", lineHeight: 1.45 }}>{t("settingsConfig.interfaceBehaviorDesc")}</p>
                  </div>
                  <div style={{ display: "flex", flexDirection: "column", gap: 10, width: "100%" }}>
                    <NativeSetting searchId="keep-tool-calls-collapsed" label={t("settingsConfig.keepToolCallsCollapsed")} description={t("settingsConfig.keepToolCallsCollapsedDesc")} scope="UI">
                      <ToggleSwitch checked={toolCallsDefaultCollapsed} onChange={onToolCallsDefaultCollapsedChange} />
                    </NativeSetting>
                    <NativeSetting searchId="expand-thinking-by-default" label={t("settingsConfig.expandThinkingByDefault")} description={t("settingsConfig.expandThinkingByDefaultDesc")} scope="UI">
                      <ToggleSwitch checked={expandThinkingByDefault} onChange={onExpandThinkingByDefaultChange} />
                    </NativeSetting>
                    <NativeSetting searchId="scope-native-select-all" label={t("settingsConfig.scopeNativeSelectAll")} description={t("settingsConfig.scopeNativeSelectAllDesc")} scope="UI">
                      <ToggleSwitch checked={scopeNativeSelectAll} onChange={onScopeNativeSelectAllChange} />
                    </NativeSetting>
                    <NativeSetting searchId="open-url-automatically" label={t("settingsConfig.openUrlAutomatically")} description={t("settingsConfig.openUrlAutomaticallyDesc")} scope="UI">
                      <ToggleSwitch checked={openUrlAutomatically} onChange={onOpenUrlAutomaticallyChange} />
                    </NativeSetting>
                    <NativeSetting searchId="completion-sound" label={t("settingsConfig.completionSound")} description={t("settingsConfig.completionSoundDesc")} scope="UI">
                      <ToggleSwitch
                        checked={soundEnabled}
                        onChange={(next) => {
                          setSoundEnabled(next);
                          try { localStorage.setItem("omp-sound-enabled", String(next)); } catch { /* storage fallback */ }
                          window.dispatchEvent(new CustomEvent("omp-sound-pref-change", { detail: next }));
                        }}
                      />
                    </NativeSetting>
                    <NativeSetting
                      searchId="tts-autoplay"
                      label={t("settingsConfig.ttsAutoplay") || "Auto-read assistant responses"}
                      description={ttsSupported ? (t("settingsConfig.ttsAutoplayDesc") || "Automatically read aloud new assistant replies when completed.") : `${t("settingsConfig.ttsAutoplayDesc") || "Automatically read aloud new assistant replies when completed."} (${t("settingsConfig.ttsNotSupported") || "Not supported in this browser"})`}
                      scope="UI"
                    >
                      <ToggleSwitch
                        checked={ttsSupported ? ttsAutoPlay : false}
                        disabled={!ttsSupported}
                        onChange={setTtsAutoPlay}
                      />
                    </NativeSetting>
                    <NativeSetting
                      searchId="tts-voice"
                      label={t("settingsConfig.ttsVoice") || "Speech Voice"}
                      description={ttsSupported ? (t("settingsConfig.ttsVoiceDesc") || "Select the browser voice for text-to-speech reading.") : `${t("settingsConfig.ttsVoiceDesc") || "Select the browser voice for text-to-speech reading."} (${t("settingsConfig.ttsNotSupported") || "Not supported in this browser"})`}
                      scope="UI"
                    >
                      <select
                        style={nativeSelectStyle}
                        value={ttsVoiceURI || ""}
                        disabled={!ttsSupported || ttsVoices.length === 0}
                        onChange={(e) => setTtsVoiceURI(e.target.value || null)}
                      >
                        <option value="">{t("settingsConfig.defaultVoice") || "Default system voice"}</option>
                        {ttsVoices.map((v) => (
                          <option key={v.voiceURI} value={v.voiceURI}>
                            {v.name} ({v.lang})
                          </option>
                        ))}
                      </select>
                    </NativeSetting>
                    <NativeSetting searchId="chat-font-size" label={t("settingsConfig.chatFontSize")} description={t("settingsConfig.chatFontSizeDesc")} scope="UI">
                      <select
                        style={nativeSelectStyle}
                        value={fontSize}
                        onChange={(event) => setFontSize(event.target.value as FontSizePreference)}
                      >
                        <option value="sm" style={nativeOptionStyle}>{t("settingsConfig.fontSizeSmall")}</option>
                        <option value="md" style={nativeOptionStyle}>{t("settingsConfig.fontSizeMedium")}</option>
                        <option value="lg" style={nativeOptionStyle}>{t("settingsConfig.fontSizeLarge")}</option>
                        <option value="xl" style={nativeOptionStyle}>{t("settingsConfig.fontSizeXLarge")}</option>
                      </select>
                    </NativeSetting>
                    <NativeSetting searchId="ui-scale" label={t("settingsConfig.uiScale")} description={t("settingsConfig.uiScaleDesc")} scope="UI">
                      <select
                        style={nativeSelectStyle}
                        value={uiScale}
                        onChange={(event) => setUiScale(event.target.value as UiScalePreference)}
                      >
                        <option value="compact" style={nativeOptionStyle}>{t("settingsConfig.uiScaleCompact")}</option>
                        <option value="standard" style={nativeOptionStyle}>{t("settingsConfig.uiScaleStandard")}</option>
                        <option value="comfortable" style={nativeOptionStyle}>{t("settingsConfig.uiScaleComfortable")}</option>
                        <option value="large" style={nativeOptionStyle}>{t("settingsConfig.uiScaleLarge")}</option>
                      </select>
                    </NativeSetting>
                    <NativeSetting searchId="touch-targets" label={t("settingsConfig.touchTargets")} description={t("settingsConfig.touchTargetsDesc")} scope="UI">
                      <select
                        style={nativeSelectStyle}
                        value={touchTargets}
                        onChange={(event) => setTouchTargets(event.target.value as TouchTargetsPreference)}
                      >
                        <option value="auto" style={nativeOptionStyle}>{t("settingsConfig.touchTargetsAuto")}</option>
                        <option value="compact" style={nativeOptionStyle}>{t("settingsConfig.touchTargetsCompact")}</option>
                        <option value="accessible" style={nativeOptionStyle}>{t("settingsConfig.touchTargetsAccessible")}</option>
                      </select>
                    </NativeSetting>
                    <NativeSetting searchId="message-during-active-run" label={t("settingsConfig.messageDuringActiveRun")} description={t("settingsConfig.messageDuringActiveRunDesc")} scope="UI">
                      <select
                        style={nativeSelectStyle}
                        value={submitBehavior}
                        onChange={(event) => {
                          const next = event.target.value as SubmitDuringRunBehavior;
                          setSubmitDuringRunBehavior(next);
                          setSubmitBehavior(next);
                        }}
                      >
                        <option value="steer" style={nativeOptionStyle}>{t("settingsConfig.steerCurrentRun")}</option>
                        <option value="queue" style={nativeOptionStyle}>{t("settingsConfig.queueFollowUp")}</option>
                      </select>
                    </NativeSetting>
                    <NativeSetting searchId="word-completion" label={t("settingsConfig.wordCompletion")} description={t("settingsConfig.wordCompletionDesc")} scope="UI">
                      <select
                        style={nativeSelectStyle}
                        value={wordCompletion}
                        onChange={(event) => {
                          const next = event.target.value as WordCompletionMode;
                          setWordCompletionMode(next);
                          setWordCompletion(next);
                        }}
                      >
                        <option value="auto" style={nativeOptionStyle}>{t("settingsConfig.wordCompletionAuto")}</option>
                        <option value="on" style={nativeOptionStyle}>{t("settingsConfig.wordCompletionOn")}</option>
                        <option value="off" style={nativeOptionStyle}>{t("settingsConfig.wordCompletionOff")}</option>
                      </select>
                    </NativeSetting>
                  </div>
                </div>
              )}

              {currentTab === "notifications" && (
                <div role="tabpanel" id="settings-panel-notifications" aria-labelledby="settings-tab-notifications" className="settings-panel-inner" style={{ padding: isMobile ? "16px 14px 32px" : "32px 24px 64px", gap: 16 }}>
                  <div style={{ marginBottom: 4 }}>
                    <h2 className="display-serif" style={{ fontSize: "var(--text-2xl)", fontWeight: 600, margin: 0, color: "var(--text)", letterSpacing: "-0.01em" }}>{t("notifications.title")}</h2>
                    <p className="settings-content-subtitle" style={{ margin: "4px 0 16px", fontSize: "var(--text-md)", color: "var(--text-muted)", lineHeight: 1.45 }}>{t("notifications.subtitle")}</p>
                  </div>
                  <div style={{ display: "flex", flexDirection: "column", gap: 10, width: "100%" }}>
                    <NotificationSettingsPanel />
                  </div>
                </div>
              )}

              {currentTab === "account" && <AccountPanel isMobile={isMobile} />}

              {currentTab === "about" && <AboutPanel isMobile={isMobile} />}
            </div>
          </SettingsHighlightContext.Provider>
        )}
      </div>
    </div>
  );
}

