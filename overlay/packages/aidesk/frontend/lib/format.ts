/** Shared display formatters for UI surfaces (previously inlined per
 * component — AppShell had two byte-identical copies, ChatInput and
 * ModelCatalogPicker each had a near-identical variant). */

/** "1.2M / 34k / 1234" compact rendering. `toLocaleString` applies only when
 * `locale` is provided (the <1000 branch in ChatInput's token counter). */
export function formatCompactNumber(n: number, locale?: string): string {
  if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(1)}M`;
  if (n >= 1_000) return `${Math.round(n / 1_000)}k`;
  return locale ? n.toLocaleString(locale) : String(n);
}

/** Context-usage percentage with a stable one-decimal format. */
export function formatPercent(pct: number): string {
  return `${pct.toFixed(1)}%`;
}

/** Cache hit rate: cacheRead / (input + cacheRead) * 100 — matches `omp stats` cacheRate.
 * Returns null when denominator is 0 (no input/cache yet) so callers can hide the row. */
export function getCacheHitRate(input: number, cacheRead: number): number | null {
  const denom = input + cacheRead;
  return denom > 0 ? (cacheRead / denom) * 100 : null;
}
