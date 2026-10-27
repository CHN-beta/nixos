import { formatCompactNumber } from "@/lib/format";

export interface ModelOption {
  provider: string;
  modelId: string;
  name: string;
}

export const COMPOSER_MODELS_STORAGE_KEY = "omp-composer-models";

export function readVisibleModelKeys(): Set<string> | null {
  try {
    const value = JSON.parse(localStorage.getItem(COMPOSER_MODELS_STORAGE_KEY) ?? "null");
    return Array.isArray(value) ? new Set(value.filter((item): item is string => typeof item === "string")) : null;
  } catch {
    return null;
  }
}

export function compareModelOptions(collator: Intl.Collator, a: ModelOption, b: ModelOption): number {
  return collator.compare(a.name || a.modelId, b.name || b.modelId)
    || collator.compare(a.provider, b.provider)
    || collator.compare(a.modelId, b.modelId);
}

export function filterModelOptions(options: ModelOption[], query: string, locale: string): ModelOption[] {
  const normalizedQuery = query.trim().toLocaleLowerCase(locale);
  if (!normalizedQuery) return options;
  return options.filter((option) => (
    option.name.toLocaleLowerCase(locale).includes(normalizedQuery)
    || option.modelId.toLocaleLowerCase(locale).includes(normalizedQuery)
    || option.provider.toLocaleLowerCase(locale).includes(normalizedQuery)
  ));
}

export function formatTokenCount(tokens: number, locale: string): string {
  return formatCompactNumber(tokens, locale);
}
