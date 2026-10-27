/**
 * Sanitizes markdown / formatted text for clean speech synthesis.
 * Strips code blocks, markdown syntax, links, and URLs so spoken output sounds natural.
 */
export function sanitizeTextForSpeech(text: string): string {
  if (!text) return "";

  let cleaned = text;

  // 1. Remove fenced code blocks completely (reading raw syntax or long code in TTS is unlistenable)
  cleaned = cleaned.replace(/```[\s\S]*?```/g, " ");

  // 2. Remove inline code backticks, keeping inner content
  cleaned = cleaned.replace(/`([^`]+)`/g, "$1");

  // 3. Remove images ![alt](url)
  cleaned = cleaned.replace(/!\[([^\]]*)\]\([^)]*\)/g, "");

  // 4. Convert markdown links [text](url) -> text
  cleaned = cleaned.replace(/\[([^\]]+)\]\([^)]*\)/g, "$1");

  // 5. Remove bare URLs
  cleaned = cleaned.replace(/https?:\/\/\S+/g, "");

  // 6. Remove HTML tags — tag-shaped only, so "x < y and z > 0" survives
  cleaned = cleaned.replace(/<\/?[A-Za-z][^<>]*>/g, "");

  // 7. Remove headers (# Header -> Header)
  cleaned = cleaned.replace(/^#{1,6}\s+/gm, "");

  // 8. Remove blockquotes (> quote -> quote)
  cleaned = cleaned.replace(/^>\s+/gm, "");

  // 9. Remove bold / italic markers (***text***, **text**, *text*, __text__, _text_)
  cleaned = cleaned.replace(/[*_]{1,3}([^*_]+)[*_]{1,3}/g, "$1");

  // 10. Remove strikethrough (~~text~~ -> text)
  cleaned = cleaned.replace(/~~([^~]+)~~/g, "$1");

  // 11. Remove markdown bullet points / list numbers (- item, * item, 1. item)
  cleaned = cleaned.replace(/^[\s]*[-*+]\s+/gm, "");
  cleaned = cleaned.replace(/^[\s]*\d+\.\s+/gm, "");

  // 12. Remove horizontal rules (---, ***, ___)
  cleaned = cleaned.replace(/^[-*_]{3,}\s*$/gm, "");

  // 13. Collapse multiple whitespace and newlines
  cleaned = cleaned.replace(/\s+/g, " ").trim();

  return cleaned;
}
