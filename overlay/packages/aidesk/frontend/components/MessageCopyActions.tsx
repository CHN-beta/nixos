import { useCallback, type RefObject } from "react";
import { copyText } from "@/lib/clipboard";
import { useI18n } from "@/lib/i18n";
import { toast } from "./ui/toast";

// Read only the message's text blocks, never adjacent thinking/tool panels.
// A mounted, offscreen clone lets innerText retain paragraph/table/code spacing
// without changing the user's selection or including renderer controls.
function renderedText(body: HTMLElement, source: string): string {
  const markdown = body.querySelector<HTMLElement>(".markdown-body");
  // Oversized messages deliberately render as raw text, on demand.
  if (!markdown) return source;
  const clone = markdown.cloneNode(true) as HTMLElement;
  clone.querySelectorAll(".markdown-code-header, .linenumber, .katex-mathml, .mermaid-block-loading, .mermaid-block-error").forEach((node) => node.remove());
  clone.querySelectorAll("img").forEach((image) => image.replaceWith(document.createTextNode(image.alt)));
  clone.querySelectorAll("svg").forEach((svg) => {
    const labels = [...svg.querySelectorAll("text, foreignObject")].map((node) => node.textContent ?? "");
    svg.replaceWith(document.createTextNode(labels.join("\n")));
  });
  clone.querySelectorAll("button").forEach((button) => button.replaceWith(...button.childNodes));
  clone.setAttribute("aria-hidden", "true");
  Object.assign(clone.style, { position: "fixed", left: "-100000px", top: "0", width: `${markdown.clientWidth}px`, pointerEvents: "none" });
  document.body.appendChild(clone);
  try {
    return clone.innerText.replace(/^\n+|\n+$/g, "");
  } finally {
    clone.remove();
  }
}

/**
 * Copy handlers for a message's right-click menu: the rendered text (what the
 * reader actually sees, including code/table spacing) and the raw Markdown
 * source. Both confirm with a toast — the menu closes before a button-local
 * "copied" state could be seen.
 */
export function useMessageCopyActions(texts: string[], bodyRef: RefObject<HTMLDivElement | null>) {
  const { t } = useI18n();

  const copyPlain = useCallback(() => {
    const bodies = bodyRef.current?.querySelectorAll<HTMLElement>("[data-message-text]");
    const text = texts
      .map((source, index) => (bodies?.[index] ? renderedText(bodies[index], source) : source))
      .filter((value) => value.trim())
      .join("\n\n");
    void copyText(text)
      .then(() => toast.success(t("messageView.copied")))
      .catch(() => {});
  }, [texts, bodyRef, t]);

  const copyMarkdown = useCallback(() => {
    void copyText(texts.join("\n\n"))
      .then(() => toast.success(t("messageView.copied")))
      .catch(() => {});
  }, [texts, t]);

  return { hasText: texts.some((text) => text.trim()), copyPlain, copyMarkdown };
}
