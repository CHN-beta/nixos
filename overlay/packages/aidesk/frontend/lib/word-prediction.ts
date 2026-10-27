// Pure draft/ghost-text arithmetic for composer word prediction (omp's
// `predict_word` RPC). The engine answers with the suffix to paint after the
// word at the cursor; everything here decides where that suffix still applies.

/** A ghost-text suffix and the draft state (text + caret) it was predicted for. */
export interface WordGhost {
  text: string;
  cursor: number;
  suffix: string;
}

/** Ghost text only paints where the rest of the line is empty, so it never overlaps typed text. */
export function atLineEnd(text: string, cursor: number): boolean {
  const next = text.charAt(cursor);
  return next === "" || next === "\n";
}

/**
 * Carry `ghost` to a new draft state. Typing that matches the ghost keeps its
 * remainder (so it doesn't flicker while the engine re-answers); typing that
 * diverges reports `typedPast` so the engine can learn the rejection; any
 * other edit or caret move just drops it.
 */
export function advanceGhost(
  ghost: WordGhost,
  text: string,
  cursor: number,
): { ghost: WordGhost | null; typedPast: boolean } {
  if (text === ghost.text && cursor === ghost.cursor) return { ghost, typedPast: false };
  const head = ghost.text.slice(0, ghost.cursor);
  const tail = ghost.text.slice(ghost.cursor);
  const typed = text.slice(ghost.cursor, cursor);
  if (cursor <= ghost.cursor || text !== head + typed + tail) return { ghost: null, typedPast: false };
  if (ghost.suffix.toLocaleLowerCase().startsWith(typed.toLocaleLowerCase())) {
    const suffix = ghost.suffix.slice(typed.length);
    return { ghost: suffix ? { text, cursor, suffix } : null, typedPast: false };
  }
  return { ghost: null, typedPast: true };
}

/** Insert the ghost at its caret, plus the trailing space omp's editor adds unless whitespace/punctuation follows. */
export function acceptGhost(ghost: WordGhost): { text: string; cursor: number } {
  const after = ghost.text.slice(ghost.cursor);
  const insert = ghost.suffix + (/^[\s.,;:!?"\])}]/.test(after) ? "" : " ");
  return {
    text: ghost.text.slice(0, ghost.cursor) + insert + after,
    cursor: ghost.cursor + insert.length,
  };
}
