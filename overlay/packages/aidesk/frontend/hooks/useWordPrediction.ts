import { useEffect, useRef, useState } from "react";
import { advanceGhost, atLineEnd, type WordGhost } from "@/lib/word-prediction";

export type PredictWord = (text: string, cursor: number) => Promise<string | null>;
export type PredictWordFeedback = (text: string, cursor: number, suggestion: string, accepted: boolean) => void;

/** Wait this long after the last keystroke before asking omp; a burst of typing sends one request. */
const DEBOUNCE_MS = 60;
/** omp's prose gate answers nothing past this draft length, so don't ship bigger drafts per keystroke. */
const MAX_DRAFT_LENGTH = 20_000;
/** After an omp without a command (predict_word, btw), check again this much later (it may have been updated and restarted). */
export const UNSUPPORTED_RETRY_MS = 60_000;

/**
 * Ghost-text state lives outside React state on purpose: the composer is a
 * large component, and re-rendering it per keystroke for a ghost change is
 * what makes typing lag. Only the subscribed ghost overlay re-renders.
 */
export interface WordPrediction {
  /** Feed every draft/caret change (onChange and onSelect). */
  update(text: string, selectionStart: number, selectionEnd: number): void;
  /** The ghost for the latest draft state, or null. */
  peek(): WordGhost | null;
  /** Take the ghost for insertion (reporting the accept), or null when none is showing. */
  take(): WordGhost | null;
  subscribe(listener: () => void): () => void;
}

export function useWordPrediction(predict: PredictWord | undefined, feedback: PredictWordFeedback | undefined): WordPrediction {
  // Latest callbacks without re-creating the controller.
  const deps = useRef({ predict, feedback });
  useEffect(() => {
    deps.current = { predict, feedback };
  }, [predict, feedback]);

  const [controller] = useState<WordPrediction & { dispose(): void }>(() => {
    let ghost: WordGhost | null = null;
    let seq = 0;
    let timer: number | undefined;
    let last: { text: string; start: number; end: number } | undefined;
    // An omp without predict_word answers "Unknown command"; pause asking it.
    let unsupportedUntil = 0;
    const listeners = new Set<() => void>();
    const set = (next: WordGhost | null) => {
      if (next === ghost) return;
      ghost = next;
      for (const listener of listeners) listener();
    };
    const cancel = () => {
      seq++;
      clearTimeout(timer);
    };
    return {
      update(text, start, end) {
        // onChange and onSelect both report a keystroke; handle it once.
        if (last && last.text === text && last.start === start && last.end === end) return;
        last = { text, start, end };
        cancel();
        const mySeq = seq;
        let carried: WordGhost | null = null;
        if (ghost) {
          const advanced = advanceGhost(ghost, text, start);
          if (advanced.typedPast) deps.current.feedback?.(ghost.text, ghost.cursor, ghost.suffix, false);
          carried = advanced.ghost;
        }
        const { predict } = deps.current;
        if (!predict || start !== end || !atLineEnd(text, start)) {
          set(null);
          return;
        }
        set(carried);
        if (text.length > MAX_DRAFT_LENGTH || Date.now() < unsupportedUntil) return;
        timer = window.setTimeout(() => {
          predict(text, start).then(
            (suffix) => {
              // A null answer while typing through a shown ghost keeps that ghost.
              if (mySeq === seq && suffix) set({ text, cursor: start, suffix });
            },
            (error: unknown) => {
              if (error instanceof Error && error.message.includes("Unknown command")) {
                unsupportedUntil = Date.now() + UNSUPPORTED_RETRY_MS;
              }
            },
          );
        }, DEBOUNCE_MS);
      },
      peek: () => ghost,
      take() {
        const current = ghost;
        if (!current) return null;
        cancel();
        set(null);
        deps.current.feedback?.(current.text, current.cursor, current.suffix, true);
        return current;
      },
      subscribe(listener) {
        listeners.add(listener);
        return () => listeners.delete(listener);
      },
      dispose: cancel,
    };
  });

  useEffect(() => controller.dispose, [controller]);
  return controller;
}
