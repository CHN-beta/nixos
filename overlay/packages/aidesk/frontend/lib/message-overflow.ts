export const MESSAGE_OVERFLOW_EPSILON_PX = 1;

export interface MessageOverflowMetrics {
  scrollHeight: number;
  clientHeight: number;
}

/** Shared measurement predicate for capped message surfaces. */
export function isMessageOverflowing({ scrollHeight, clientHeight }: MessageOverflowMetrics): boolean {
  return scrollHeight > clientHeight + MESSAGE_OVERFLOW_EPSILON_PX;
}
