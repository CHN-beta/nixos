
import { useEffect, useRef } from "react";

// Stack of open dialog containers; only the topmost one responds to Escape,
// so a sub-dialog (e.g. the provider picker over the models config) closes
// before its parent.
const dialogStack: HTMLElement[] = [];

const FOCUSABLE_SELECTOR = [
  "a[href]",
  "button:not([disabled])",
  "input:not([disabled])",
  "select:not([disabled])",
  "textarea:not([disabled])",
  '[tabindex]:not([tabindex="-1"])',
].join(", ");

function focusableIn(container: HTMLElement): HTMLElement[] {
  return Array.from(container.querySelectorAll<HTMLElement>(FOCUSABLE_SELECTOR))
    .filter((el) => el.getClientRects().length > 0 || el === document.activeElement);
}

export interface ModalDialogOptions {
  onClose: () => void;
  /** Set false while the dialog markup is not yet mounted (e.g. portal target pending). */
  active?: boolean;
}

/**
 * Dependency-free dialog behavior for overlay modals: moves focus into the
 * container on open, restores it to the opener on close, closes the topmost
 * dialog on document-level Escape, and wraps Tab/Shift-Tab inside the
 * container. Attach the returned ref to the dialog panel and give that
 * element tabIndex={-1} (plus role="dialog" / aria-modal / a label).
 */
export function useModalDialog<T extends HTMLElement>({ onClose, active = true }: ModalDialogOptions) {
  const containerRef = useRef<T | null>(null);
  const onCloseRef = useRef(onClose);
  onCloseRef.current = onClose;

  useEffect(() => {
    if (!active) return;
    const container = containerRef.current;
    if (!container) return;
    const opener = document.activeElement instanceof HTMLElement ? document.activeElement : null;
    dialogStack.push(container);

    if (!container.contains(document.activeElement)) {
      container.focus();
    }

    const handleKeyDown = (e: KeyboardEvent) => {
      if (dialogStack[dialogStack.length - 1] !== container) return;
      if (e.key === "Escape") {
        if (e.isComposing || e.keyCode === 229) return;
        e.preventDefault();
        // Swallow the event: the window-level shortcut handler (Esc = stop
        // agent) must not also fire just because focus sat inside a dialog.
        e.stopPropagation();
        onCloseRef.current();
        return;
      }
      if (e.key !== "Tab") return;
      const focusable = focusableIn(container);
      if (focusable.length === 0) {
        e.preventDefault();
        container.focus();
        return;
      }
      const activeEl = document.activeElement;
      const inside = activeEl instanceof Node && container.contains(activeEl);
      if (e.shiftKey) {
        if (!inside || activeEl === focusable[0] || activeEl === container) {
          e.preventDefault();
          focusable[focusable.length - 1].focus();
        }
      } else if (!inside || activeEl === focusable[focusable.length - 1]) {
        e.preventDefault();
        focusable[0].focus();
      }
    };

    // Capture phase so an inner stopPropagation cannot swallow Escape.
    document.addEventListener("keydown", handleKeyDown, true);
    return () => {
      document.removeEventListener("keydown", handleKeyDown, true);
      const index = dialogStack.indexOf(container);
      if (index !== -1) dialogStack.splice(index, 1);
      if (opener && opener.isConnected) opener.focus();
    };
  }, [active]);

  return containerRef;
}
