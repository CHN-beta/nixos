import { parse as parseYaml } from "yaml";

export interface FrontmatterResult {
  data: Record<string, unknown> | null;
  rest: string;
}

export function parseFrontmatter(markdown: string): FrontmatterResult {
  const opening = /^(?:\uFEFF)?---[ \t]*(?:\r\n|\n|\r)/.exec(markdown);
  if (!opening) return { data: null, rest: markdown };
  const closing = /^---[ \t]*(?:(?:\r\n|\n|\r)|$)/gm;
  closing.lastIndex = opening[0].length;
  const end = closing.exec(markdown);
  if (!end) return { data: null, rest: markdown };
  const yamlText = markdown.slice(opening[0].length, end.index).replace(/(?:\r\n|\n|\r)$/, "");
  try {
    const parsed = parseYaml(yamlText) as unknown;
    return parsed && typeof parsed === "object" && !Array.isArray(parsed)
      ? { data: parsed as Record<string, unknown>, rest: markdown.slice(end.index + end[0].length) }
      : { data: null, rest: markdown.slice(end.index + end[0].length) };
  } catch {
    return { data: null, rest: markdown.slice(end.index + end[0].length) };
  }
}

export function formatFrontmatterValue(value: unknown): string {
  if (value === null || value === undefined) return "";
  if (typeof value === "string" || typeof value === "number" || typeof value === "boolean") return String(value);
  if (Array.isArray(value)) return value.map(formatFrontmatterValue).filter(Boolean).join(", " );
  try { return JSON.stringify(value) ?? ""; } catch { return String(value); }
}
