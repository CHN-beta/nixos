
import { useLayoutEffect, useState, type RefObject } from "react";

const GAP = 4;
const VIEWPORT_PAD = 8;

/** Viewport position for a `position: fixed` menu below `triggerRef`, so the
 * menu escapes clipping ancestors such as the compact top-bar overflow strip.
 * Tracks scroll and resize while open. Returns null while closed. */
export function useFixedMenuPosition(
  open: boolean,
  triggerRef: RefObject<HTMLElement | null>,
  menuWidth: number,
): { top: number; left: number } | null {
  const [pos, setPos] = useState<{ top: number; left: number } | null>(null);

  useLayoutEffect(() => {
    const trigger = triggerRef.current;
    if (!open || !trigger) {
      setPos(null);
      return;
    }
    const update = () => {
      // --ui-scale zooms <html>: the rect is in painted pixels, while fixed
      // coordinates are zoomed again, so convert to unscaled CSS pixels.
      const scale = parseFloat(getComputedStyle(document.documentElement).getPropertyValue("--ui-scale")) || 1;
      const rect = trigger.getBoundingClientRect();
      const maxLeft = window.innerWidth / scale - menuWidth - VIEWPORT_PAD;
      setPos({ top: rect.bottom / scale + GAP, left: Math.max(VIEWPORT_PAD, Math.min(rect.left / scale, maxLeft)) });
    };
    update();
    window.addEventListener("scroll", update, true);
    window.addEventListener("resize", update);
    return () => {
      window.removeEventListener("scroll", update, true);
      window.removeEventListener("resize", update);
    };
  }, [open, triggerRef, menuWidth]);

  return pos;
}
