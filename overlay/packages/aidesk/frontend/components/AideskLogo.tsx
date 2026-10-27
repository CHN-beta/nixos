import { useId } from "react";

/**
 * AIDesk brand mark: a minimal "A" glyph on a midnight tile.
 * Placeholder artwork until a final logo is designed.
 */
export default function AideskLogo({
  size = 20,
  label = "AIDesk logo",
}: {
  size?: number;
  label?: string;
}) {
  const uid = useId().replace(/[^a-zA-Z0-9]/g, "");
  const gradient = `aidesk-g-${uid}`;
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
        <linearGradient id={gradient} x1="0" y1="0" x2="1" y2="1">
          <stop offset="0" stopColor="#EC5BAB" />
          <stop offset="1" stopColor="#7DD7E8" />
        </linearGradient>
      </defs>
      <rect width="64" height="64" rx="14" fill="#101014" />
      <path
        d="M18 47 32 16l14 31"
        fill="none"
        stroke={`url(#${gradient})`}
        strokeWidth="6"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
      <path d="M24 36h16" fill="none" stroke="#7DD7E8" strokeWidth="5" strokeLinecap="round" />
    </svg>
  );
}
