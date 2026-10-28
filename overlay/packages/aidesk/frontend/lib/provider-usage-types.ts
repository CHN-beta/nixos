export type ProviderUsageWindowId = "5h" | "7d" | "monthly";

export interface ProviderUsageWindow {
  /** Percentage used (0–100+). Absent when only absolute amounts are known. */
  percent?: number;
  resetMinutes?: number;
  resetHours?: number;
  used?: number;
  limit?: number;
  remaining?: number;
  /** `"usd"`, `"tokens"`, `"requests"`, `"credits"`, … */
  unit?: string;
  label?: string;
}

/** One flat rate-limit entry as reported by the provider. */
export interface ProviderUsageLimitItem extends ProviderUsageWindow {
  id?: string;
  windowId?: ProviderUsageWindowId;
  status?: string;
}

export interface ProviderUsageReport {
  provider: string;
  accountLabel?: string;
  accountIndex?: number;
  plan?: string;
  modelId?: string;
  tier?: string;
  noLimits?: boolean;
  fiveHour?: ProviderUsageWindow;
  sevenDay?: ProviderUsageWindow;
  monthly?: ProviderUsageWindow;
  limits?: ProviderUsageLimitItem[];
}

export interface ProviderUsageSnapshot {
  generatedAt: number | null;
  reports: ProviderUsageReport[];
}

export interface ProviderUsageContext {
  provider: string;
  modelId: string;
}
