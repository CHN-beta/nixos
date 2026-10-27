import { isRecord } from "./type-guards";

/** Tool calls and empty assistant envelopes are not a response. */
export function hasVisibleAssistantContent(value: unknown): boolean {
  if (!isRecord(value) || value.role !== "assistant") return false;
  if (!Array.isArray(value.content)) return typeof value.content === "string" && value.content.trim().length > 0;
  return value.content.some((block) => {
    if (!isRecord(block)) return false;
    if (block.type === "text") return typeof block.text === "string" && block.text.trim().length > 0;
    if (block.type === "image") return true;
    return false;
  });
}
