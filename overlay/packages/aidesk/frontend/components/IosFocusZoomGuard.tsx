
import { useEffect } from "react";

/**
 * iOS Safari zooms the page when an input under 16px gains focus (issue #87).
 * `maximum-scale=1` stops that focus zoom while iOS still allows pinch-zoom,
 * so inputs can keep the chat font size. iOS/iPadOS only: Chrome on Android
 * honors maximum-scale (users would lose pinch-zoom) and does not focus-zoom.
 *
 * The viewport meta can be replaced or re-streamed at runtime, which would
 * lose a one-shot edit. Watch <head> and re-apply instead.
 */
export function IosFocusZoomGuard() {
  useEffect(() => {
    const { userAgent, platform, maxTouchPoints } = navigator;
    const isIos = /iP(hone|ad|od)/.test(userAgent) || (platform === "MacIntel" && maxTouchPoints > 1);
    if (!isIos) return;
    const apply = () => {
      document.querySelectorAll<HTMLMetaElement>('meta[name="viewport"]').forEach((meta) => {
        if (!meta.content.includes("maximum-scale")) meta.content += ", maximum-scale=1";
      });
    };
    apply();
    const observer = new MutationObserver(apply);
    observer.observe(document.head, { childList: true, subtree: true, attributes: true, attributeFilter: ["content"] });
    return () => observer.disconnect();
  }, []);
  return null;
}
