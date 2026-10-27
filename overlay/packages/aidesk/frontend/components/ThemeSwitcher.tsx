
import { useEffect, useId, useRef, useState } from "react";
import { Check, ChevronDown, Monitor, Moon, Sparkles, Sun } from "lucide-react";
import { useIsMobile } from "@/hooks/useIsMobile";
import { useFixedMenuPosition } from "@/hooks/useFixedMenuPosition";
import {
  DARK_THEMES,
  LIGHT_THEMES,
  type ThemeMode,
  useTheme,
} from "@/hooks/useTheme";
import { useI18n } from "@/lib/i18n";

const MODE_ICONS = {
  auto: Monitor,
  light: Sun,
  dark: Moon,
} as const;

/** Theme picker for the top bar.
 *
 * The top row is a three-way mode selector (Auto / Light / Dark). Below it,
 * the light and dark theme columns sit side by side: Auto enables both (the
 * active one follows the OS, so each column keeps its own remembered choice),
 * while a fixed mode grays out the opposite column. */
export function ThemeSwitcher() {
  const { mode, lightTheme, darkTheme, setMode, setLightTheme, setDarkTheme } = useTheme();
  const { t } = useI18n();
  const isMobile = useIsMobile();
  const [open, setOpen] = useState(false);
  const [activeIndex, setActiveIndex] = useState(0);
  const triggerRef = useRef<HTMLButtonElement | null>(null);
  const itemRefs = useRef<Array<HTMLButtonElement | null>>([]);
  const baseId = useId();
  const menuId = `${baseId}-menu`;

  const modeOptions: Array<{ value: ThemeMode; label: string; Icon: typeof Monitor }> = [
    { value: "auto", label: t("appShell.themeModeAuto") || "Auto", Icon: MODE_ICONS.auto },
    { value: "light", label: t("appShell.themeModeLight") || "Light", Icon: MODE_ICONS.light },
    { value: "dark", label: t("appShell.themeModeDark") || "Dark", Icon: MODE_ICONS.dark },
  ];

  const lightDisabled = mode === "dark";
  const darkDisabled = mode === "light";
  const lightStart = modeOptions.length;
  const darkStart = lightStart + LIGHT_THEMES.length;
  const itemCount = darkStart + DARK_THEMES.length;

  // Keyboard order skips the grayed-out column.
  const enabledIndexes: number[] = [];
  for (let index = 0; index < itemCount; index += 1) {
    if (index >= lightStart && index < darkStart && lightDisabled) continue;
    if (index >= darkStart && darkDisabled) continue;
    enabledIndexes.push(index);
  }

  // Closed: the mode selector's current choice is the entry point. Open: if the
  // highlight now sits in a column this mode grays out (the mode changed while
  // the menu stayed open), pull it back to the mode row so focus never rests on
  // a disabled item.
  const currentModeIndex = modeOptions.findIndex((option) => option.value === mode);
  const activeIndexEnabled = enabledIndexes.includes(activeIndex);
  useEffect(() => {
    if (!open || !activeIndexEnabled) setActiveIndex(currentModeIndex);
  }, [currentModeIndex, open, activeIndexEnabled]);

  // Fixed positioning escapes the compact top-bar overflow strip, whose
  // horizontal scroller would otherwise clip the menu to its 48px height.
  const menuPos = useFixedMenuPosition(open, triggerRef, isMobile ? 280 : 340);
  const menuShown = menuPos !== null;

  useEffect(() => {
    if (menuShown) itemRefs.current[activeIndex]?.focus();
  }, [menuShown, activeIndex]);

  const close = (returnFocus = true) => {
    setOpen(false);
    if (returnFocus) triggerRef.current?.focus();
  };

  const origin = () => {
    const rect = triggerRef.current?.getBoundingClientRect();
    return rect ? { x: rect.left + rect.width / 2, y: rect.top + rect.height / 2 } : undefined;
  };

  const moveActive = (delta: number) => {
    const position = enabledIndexes.indexOf(activeIndex);
    const nextPosition = position === -1 ? 0 : (position + delta + enabledIndexes.length) % enabledIndexes.length;
    setActiveIndex(enabledIndexes[nextPosition]);
  };

  const onTriggerKeyDown = (event: React.KeyboardEvent) => {
    if (event.key === "ArrowDown" || event.key === "Enter" || event.key === " " || event.key === "ArrowUp") {
      event.preventDefault();
      setOpen(true);
      setActiveIndex(currentModeIndex >= 0 ? currentModeIndex : 0);
    }
  };

  const onItemKeyDown = (event: React.KeyboardEvent) => {
    switch (event.key) {
      case "ArrowDown":
      case "ArrowRight":
        event.preventDefault();
        moveActive(1);
        break;
      case "ArrowUp":
      case "ArrowLeft":
        event.preventDefault();
        moveActive(-1);
        break;
      case "Home":
        event.preventDefault();
        setActiveIndex(enabledIndexes[0]);
        break;
      case "End":
        event.preventDefault();
        setActiveIndex(enabledIndexes[enabledIndexes.length - 1]);
        break;
      case "Escape":
        event.preventDefault();
        // Stop the window-level Esc listener (abort agent) from firing while
        // the theme menu is open.
        event.stopPropagation();
        close(true);
        break;
      case "Tab":
        close(false);
        break;
    }
  };

  const TriggerIcon = MODE_ICONS[mode];

  const renderThemeItem = (id: string, index: number, name: string, bg: string, accent: string, selected: boolean, disabled: boolean, choose: () => void, isOmp = false) => (
    <button
      key={id}
      className="dropdown-item"
      ref={(element) => { itemRefs.current[index] = element; }}
      type="button"
      role="menuitemradio"
      tabIndex={-1}
      aria-checked={selected}
      disabled={disabled}
      onClick={choose}
      onKeyDown={onItemKeyDown}
      onMouseEnter={(event) => { if (!disabled) event.currentTarget.style.background = "var(--bg-hover)"; }}
      onMouseLeave={(event) => { event.currentTarget.style.background = selected ? "var(--bg-selected)" : "transparent"; }}
      style={{
        width: "100%",
        display: "flex",
        alignItems: "center",
        gap: 8,
        padding: "6px 8px",
        border: 0,
        borderRadius: 5,
        background: selected ? "var(--bg-selected)" : "transparent",
        color: disabled ? "var(--text-dim)" : selected ? "var(--text)" : "var(--text-muted)",
        cursor: disabled ? "not-allowed" : "pointer",
        fontSize: 12,
        textAlign: "left",
        transition: "background-color var(--dur-fast) var(--ease-out-warm), color var(--dur-fast) var(--ease-out-warm)",
      }}
    >
      <span
        style={{
          width: 13,
          height: 13,
          borderRadius: "50%",
          backgroundColor: bg,
          border: isOmp ? "1.5px solid #7DD7E8" : "1px solid color-mix(in srgb, var(--border) 80%, transparent)",
          display: "inline-flex",
          alignItems: "center",
          justifyContent: "center",
          flexShrink: 0,
        }}
      >
        <span style={{ width: 5, height: 5, borderRadius: "50%", backgroundColor: accent }} />
      </span>
      <span style={{ flex: 1, whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis", display: "inline-flex", alignItems: "center", gap: 5 }}>
        {name}
        {isOmp && <Sparkles size={11} strokeWidth={2} style={{ color: "var(--accent)", flexShrink: 0 }} aria-hidden="true" />}
      </span>
      {selected && <Check size={12} strokeWidth={2} aria-hidden="true" style={{ flexShrink: 0, color: "var(--accent)" }} />}
    </button>
  );

  return (
    <div
      style={{ position: "relative", flexShrink: 0 }}
      onBlur={(event) => {
        if (!event.currentTarget.contains(event.relatedTarget as Node)) setOpen(false);
      }}
    >
      <button
        ref={triggerRef}
        type="button"
        onClick={() => setOpen((value) => !value)}
        onKeyDown={onTriggerKeyDown}
        title={t("commandPalette.toggleTheme")}
        aria-haspopup="menu"
        aria-expanded={open}
        aria-controls={open ? menuId : undefined}
        className="shell-toolbar-btn shell-toolbar-picker ui-focus-ring"
        style={{
          width: "auto",
          minWidth: isMobile ? 44 : 36,
          padding: "0 8px",
          gap: 4,
          background: open ? "var(--bg-selected)" : undefined,
          color: open ? "var(--text)" : undefined,
        }}
      >
        <TriggerIcon size={16} strokeWidth={1.8} aria-hidden="true" />
        <ChevronDown
          size={10}
          strokeWidth={2}
          aria-hidden="true"
          style={{
            flexShrink: 0,
            transform: open ? "rotate(180deg)" : "none",
            transition: "transform var(--dur-fast) var(--ease-out-warm)",
          }}
        />
      </button>

      {open && menuPos && (
        <div
          id={menuId}
          role="menu"
          className="dropdown-surface animate-slide-down"
          style={{
            position: "fixed",
            top: menuPos.top,
            left: menuPos.left,
            zIndex: 600,
            minWidth: isMobile ? 280 : 340,
            maxWidth: "calc(100vw / var(--ui-scale) - 16px)",
            margin: 0,
            padding: 6,
            background: "var(--bg-panel)",
            border: "1px solid var(--border)",
            borderRadius: "var(--radius-control)",
            boxShadow: "var(--shadow-pop)",
          }}
        >
          {/* Mode selector */}
          <div
            role="group"
            aria-label={t("appShell.themeMode") || "Color mode"}
            style={{
              display: "grid",
              gridTemplateColumns: "repeat(3, minmax(0, 1fr))",
              gap: 4,
              padding: 4,
              marginBottom: 6,
              background: "var(--bg)",
              border: "1px solid var(--border)",
              borderRadius: "var(--radius-control)",
            }}
          >
            {modeOptions.map(({ value, label, Icon }, index) => {
              const selected = mode === value;
              return (
                <button
                  key={value}
                  ref={(element) => { itemRefs.current[index] = element; }}
                  type="button"
                  role="menuitemradio"
                  aria-checked={selected}
                  tabIndex={-1}
                  onClick={() => { setMode(value, origin()); setActiveIndex(index); }}
                  onKeyDown={onItemKeyDown}
                  title={label}
                  style={{
                    display: "inline-flex",
                    alignItems: "center",
                    justifyContent: "center",
                    gap: 5,
                    padding: "6px 4px",
                    border: 0,
                    borderRadius: 5,
                    background: selected ? "var(--bg-selected)" : "transparent",
                    color: selected ? "var(--text)" : "var(--text-muted)",
                    cursor: "pointer",
                    fontSize: 12,
                    fontWeight: selected ? 600 : 500,
                    whiteSpace: "nowrap",
                  }}
                >
                  <Icon size={13} strokeWidth={1.9} aria-hidden="true" style={{ color: selected ? "var(--accent)" : undefined }} />
                  <span style={{ overflow: "hidden", textOverflow: "ellipsis" }}>{label}</span>
                </button>
              );
            })}
          </div>

          <div
            style={{
              display: isMobile ? "flex" : "grid",
              flexDirection: isMobile ? "column" : undefined,
              gridTemplateColumns: isMobile ? undefined : "1fr 1fr",
              gap: isMobile ? 4 : 8,
              maxHeight: isMobile ? 380 : undefined,
              overflowY: isMobile ? "auto" : undefined,
            }}
          >
            {/* Light column */}
            <div
              aria-disabled={lightDisabled}
              style={{ display: "flex", flexDirection: "column", gap: 1, opacity: lightDisabled ? 0.45 : 1, pointerEvents: lightDisabled ? "none" : undefined }}
            >
              <div style={{ padding: "4px 8px 2px", fontSize: 10, fontWeight: 600, letterSpacing: "0.06em", textTransform: "uppercase", color: "var(--text-dim)" }}>
                {t("appShell.lightThemes") || "Light"}
              </div>
              {LIGHT_THEMES.map((theme, localIndex) => {
                const index = lightStart + localIndex;
                return renderThemeItem(
                  theme.id,
                  index,
                  theme.name,
                  theme.bg,
                  theme.accent,
                  theme.id === lightTheme,
                  lightDisabled,
                  () => { setLightTheme(theme.id as typeof lightTheme, origin()); close(true); },
                );
              })}
            </div>

            {/* Dark column */}
            <div
              aria-disabled={darkDisabled}
              style={{ display: "flex", flexDirection: "column", gap: 1, opacity: darkDisabled ? 0.45 : 1, pointerEvents: darkDisabled ? "none" : undefined }}
            >
              <div style={{ padding: "4px 8px 2px", fontSize: 10, fontWeight: 600, letterSpacing: "0.06em", textTransform: "uppercase", color: "var(--text-dim)" }}>
                {t("appShell.darkThemes") || "Dark"}
              </div>
              {DARK_THEMES.map((theme, localIndex) => {
                const index = darkStart + localIndex;
                return renderThemeItem(
                  theme.id,
                  index,
                  theme.name,
                  theme.bg,
                  theme.accent,
                  theme.id === darkTheme,
                  darkDisabled,
                  () => { setDarkTheme(theme.id as typeof darkTheme, origin()); close(true); },
                  theme.id === "omp",
                );
              })}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
