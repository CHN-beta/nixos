export interface ActiveGoal {
  objective: string;
  startedAt: number;
}

export interface ActivePlan {
  objective: string;
}

export function createActiveGoal(objective: string, startedAt = Date.now()): ActiveGoal {
  return { objective: objective.trim(), startedAt };
}

/** Parse sessionStorage safely: user data and old versions must never break chat. */
export function parseActiveGoal(value: string | null): ActiveGoal | null {
  if (!value) return null;
  try {
    const parsed: unknown = JSON.parse(value);
    if (!parsed || typeof parsed !== "object") return null;
    const { objective, startedAt } = parsed as Record<string, unknown>;
    if (typeof objective !== "string" || !objective.trim()
      || typeof startedAt !== "number" || !Number.isFinite(startedAt) || startedAt < 0) return null;
    return { objective, startedAt };
  } catch {
    return null;
  }
}

export function formatGoalElapsed(elapsedMs: number): string {
  const elapsedMinutes = Math.max(0, Math.floor(elapsedMs / 60_000));
  const hours = Math.floor(elapsedMinutes / 60);
  const minutes = elapsedMinutes % 60;
  return hours > 0 ? `${hours}h ${minutes}m` : `${minutes}m`;
}
