
import { forwardRef, useLayoutEffect, useRef, useSyncExternalStore, type RefObject } from "react";
import type { WordPrediction } from "@/hooks/useWordPrediction";

// Textarea properties that decide where each character lands; the mirror copies
// them so the ghost suffix paints exactly after the caret.
const LAYOUT_PROPS = [
  "fontFamily", "fontSize", "fontWeight", "fontStyle", "letterSpacing", "wordSpacing", "lineHeight",
  "textIndent", "textTransform", "tabSize", "paddingTop", "paddingRight", "paddingBottom", "paddingLeft",
  "whiteSpace", "overflowWrap", "wordBreak",
] as const;

interface Props {
  textareaRef: RefObject<HTMLTextAreaElement | null>;
  prediction: WordPrediction;
  /** Current draft; a ghost predicted for any other text is stale and hidden. */
  value: string;
}

/**
 * Inline ghost text for a textarea: an invisible copy of the draft, laid out
 * identically underneath the (transparent-background) textarea, with the
 * dimmed suggestion spliced in at the caret. The text after the caret must be
 * mirrored too: without it the mirror is shorter than the textarea, the
 * browser clamps its scrollTop, and the ghost paints below the caret.
 */
export const GhostMirror = forwardRef<HTMLDivElement, Props>(function GhostMirror({ textareaRef, prediction, value }, ref) {
  const localRef = useRef<HTMLDivElement | null>(null);
  const ghost = useSyncExternalStore(prediction.subscribe, prediction.peek, () => null);
  const visible = ghost !== null && ghost.text === value;

  useLayoutEffect(() => {
    const mirror = localRef.current;
    const textarea = textareaRef.current;
    if (!mirror || !textarea) return;
    const computed = getComputedStyle(textarea);
    for (const prop of LAYOUT_PROPS) mirror.style[prop] = computed[prop];
    // clientWidth excludes the scrollbar, so wrapping matches the textarea's.
    mirror.style.width = `${textarea.clientWidth}px`;
    mirror.style.height = `${textarea.clientHeight}px`;
    mirror.scrollTop = textarea.scrollTop;
  });

  if (!visible) return null;
  return (
    <div
      ref={(el) => {
        localRef.current = el;
        if (typeof ref === "function") ref(el);
        else if (ref) ref.current = el;
      }}
      aria-hidden="true"
      data-testid="composer-ghost"
      style={{
        position: "absolute",
        top: 0,
        left: 0,
        boxSizing: "border-box",
        overflow: "hidden",
        pointerEvents: "none",
        color: "transparent",
      }}
    >
      {ghost.text.slice(0, ghost.cursor)}
      <span style={{ color: "var(--text-dim)" }}>{ghost.suffix}</span>
      {/* The zero-width space gives a trailing newline its own line, as the textarea does. */}
      {`${ghost.text.slice(ghost.cursor)}\u200b`}
    </div>
  );
});
