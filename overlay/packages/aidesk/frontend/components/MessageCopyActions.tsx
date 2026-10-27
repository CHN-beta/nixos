
import type { RefObject } from "react";
import { Check, Copy, FileText } from "lucide-react";
import { useCopyFeedback } from "@/hooks/useCopyFeedback";
import { useI18n } from "@/lib/i18n";
import { Tooltip } from "./ui/primitives";

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

export function MessageCopyActions({ texts, bodyRef }: {
  texts: string[];
  bodyRef: RefObject<HTMLDivElement | null>;
}) {
  const { t } = useI18n();
  const plain = useCopyFeedback();
  const markdown = useCopyFeedback();
  if (!texts.some((text) => text.trim())) return null;

  const copyPlain = () => {
    const bodies = bodyRef.current?.querySelectorAll<HTMLElement>("[data-message-text]");
    plain.copy(texts.map((text, index) => bodies?.[index] ? renderedText(bodies[index], text) : text).filter((text) => text.trim()).join("\n\n"));
  };

  return (
    <div className="message-copy-actions">
      {[
        { label: t("messageView.copyMessage"), text: t("messageView.copy"), copied: plain.copied, onClick: copyPlain, Icon: Copy },
        { label: t("messageView.copyMarkdown"), text: t("messageView.markdown"), copied: markdown.copied, onClick: () => markdown.copy(texts.join("\n\n")), Icon: FileText },
      ].map(({ label, text, copied, onClick, Icon }) => (
        <Tooltip key={label} content={label}>
          <button type="button" className="message-copy-action" onClick={onClick} aria-label={label}>
            {copied ? <Check size={13} aria-hidden="true" /> : <Icon size={13} aria-hidden="true" />}
            <span aria-live="polite">{copied ? t("messageView.copied") : text}</span>
          </button>
        </Tooltip>
      ))}
    </div>
  );
}
