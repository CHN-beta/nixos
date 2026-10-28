import { useId } from "react";
import { isDarkTheme, useTheme } from "@/hooks/useTheme";

export type AideskLogoVariant = "auto" | "light" | "dark";

type Palette = {
  tileFrom: string;
  tileTo: string;
  tileStroke: string;
  deskFill: string;
  deskFrom: string;
  deskTo: string;
  apron: string;
  sparkFrom: string;
  sparkTo: string;
  dot: string;
};

// Catppuccin Latte for light surfaces, Catppuccin Mocha for dark ones. Both
// variants share the same desk + spark geometry; only the colors differ.
const PALETTES: Record<Exclude<AideskLogoVariant, "auto">, Palette> = {
  light: {
    tileFrom: "#FCFBF9",
    tileTo: "#EFF1F5",
    tileStroke: "#DCE0E8",
    deskFill: "rgba(30, 102, 245, 0.10)",
    deskFrom: "#1E66F5",
    deskTo: "#8839EF",
    apron: "#1E66F5",
    sparkFrom: "#FE640B",
    sparkTo: "#EA76CB",
    dot: "#1E66F5",
  },
  dark: {
    tileFrom: "#24273A",
    tileTo: "#181825",
    tileStroke: "#313244",
    deskFill: "rgba(137, 180, 250, 0.12)",
    deskFrom: "#89B4FA",
    deskTo: "#CBA6F7",
    apron: "#89B4FA",
    sparkFrom: "#FAB387",
    sparkTo: "#F5C2E7",
    dot: "#89B4FA",
  },
};

/**
 * AIDesk brand mark: an isometric writing desk under a glowing AI spark.
 * The palette follows the active theme unless `variant` pins one.
 */
export default function AideskLogo({
  size = 20,
  label = "AIDesk logo",
  variant = "auto",
}: {
  size?: number;
  label?: string;
  variant?: AideskLogoVariant;
}) {
  const uid = useId().replace(/[^a-zA-Z0-9]/g, "");
  const { theme } = useTheme();
  const resolved = variant === "auto" ? (isDarkTheme(theme) ? "dark" : "light") : variant;
  const palette = PALETTES[resolved];
  const tileGradient = `aidesk-tile-${uid}`;
  const deskGradient = `aidesk-desk-${uid}`;
  const sparkGradient = `aidesk-spark-${uid}`;

  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 64 64"
      role="img"
      aria-label={label}
      style={{ display: "block", flexShrink: 0 }}
    >
      <defs>
        <linearGradient id={tileGradient} x1="0" y1="0" x2="1" y2="1">
          <stop offset="0" stopColor={palette.tileFrom} />
          <stop offset="1" stopColor={palette.tileTo} />
        </linearGradient>
        <linearGradient
          id={deskGradient}
          gradientUnits="userSpaceOnUse"
          x1="14"
          y1="25"
          x2="50"
          y2="49"
        >
          <stop offset="0" stopColor={palette.deskFrom} />
          <stop offset="1" stopColor={palette.deskTo} />
        </linearGradient>
        <linearGradient id={sparkGradient} x1="0" y1="0" x2="1" y2="1">
          <stop offset="0" stopColor={palette.sparkFrom} />
          <stop offset="1" stopColor={palette.sparkTo} />
        </linearGradient>
      </defs>
      <rect
        x="2"
        y="2"
        width="60"
        height="60"
        rx="15"
        fill={`url(#${tileGradient})`}
        stroke={palette.tileStroke}
        strokeWidth="1.75"
      />
      <path
        d="M14 34 L22 25 L42 25 L50 34 Z"
        fill={palette.deskFill}
        stroke={`url(#${deskGradient})`}
        strokeWidth="3.2"
        strokeLinejoin="round"
      />
      <path d="M16 34 H48" fill="none" stroke={palette.apron} strokeWidth="3.2" strokeLinecap="round" />
      <path
        d="M19 34 L16 49 M45 34 L48 49"
        fill="none"
        stroke={`url(#${deskGradient})`}
        strokeWidth="3.2"
        strokeLinecap="round"
      />
      <path
        d="M21 43 H43"
        fill="none"
        stroke={`url(#${deskGradient})`}
        strokeWidth="2.4"
        strokeLinecap="round"
      />
      <path
        d="M32 8 C33.2 13.2 34.8 14.8 40 16 C34.8 17.2 33.2 18.8 32 24 C30.8 18.8 29.2 17.2 24 16 C29.2 14.8 30.8 13.2 32 8 Z"
        fill={`url(#${sparkGradient})`}
      />
      <circle cx="42" cy="11" r="1.8" fill={palette.dot} />
    </svg>
  );
}
