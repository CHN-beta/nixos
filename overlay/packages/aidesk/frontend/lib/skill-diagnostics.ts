import { isRecord } from "./type-guards";

export type SkillDiagnosticReason = "source-order" | "custom-directory" | "authored-over-installed";

export interface SkillDiagnosticEntry {
  name: string;
  filePath: string;
  source: string;
  pluginName?: string;
}

export interface SkillDiagnosticDuplicate {
  skill: SkillDiagnosticEntry;
  retained: SkillDiagnosticEntry;
}

export interface SkillResolutionDiagnostic {
  name: string;
  reason: SkillDiagnosticReason;
  skills: SkillDiagnosticEntry[];
  duplicates: SkillDiagnosticDuplicate[];
}

export interface SkillDiagnosticsSnapshot {
  cwd: string;
  showStartupDiagnostics: boolean;
  diagnostics: SkillResolutionDiagnostic[];
}

function parseEntry(value: unknown): SkillDiagnosticEntry | undefined {
  if (!isRecord(value)
    || typeof value.name !== "string"
    || typeof value.filePath !== "string"
    || typeof value.source !== "string"
    || (value.pluginName !== undefined && typeof value.pluginName !== "string")) return undefined;
  const entry: SkillDiagnosticEntry = {
    name: value.name,
    filePath: value.filePath,
    source: value.source,
  };
  if (value.pluginName !== undefined) entry.pluginName = value.pluginName;
  return entry;
}

function parseDiagnostic(value: unknown): SkillResolutionDiagnostic | undefined {
  if (!isRecord(value)
    || typeof value.name !== "string"
    || (value.reason !== "source-order" && value.reason !== "custom-directory" && value.reason !== "authored-over-installed")
    || !Array.isArray(value.skills)
    || !Array.isArray(value.duplicates)) return undefined;

  const skills: SkillDiagnosticEntry[] = [];
  for (const rawSkill of value.skills) {
    const skill = parseEntry(rawSkill);
    if (!skill) return undefined;
    skills.push(skill);
  }

  const duplicates: SkillDiagnosticDuplicate[] = [];
  for (const rawDuplicate of value.duplicates) {
    if (!isRecord(rawDuplicate)) return undefined;
    const skill = parseEntry(rawDuplicate.skill);
    const retained = parseEntry(rawDuplicate.retained);
    if (!skill || !retained) return undefined;
    duplicates.push({ skill, retained });
  }

  return { name: value.name, reason: value.reason, skills, duplicates };
}

/** Parses untrusted RPC data into an allowlisted display DTO. */
export function parseSkillDiagnosticsSnapshot(value: unknown): SkillDiagnosticsSnapshot | undefined {
  if (!isRecord(value)
    || typeof value.cwd !== "string"
    || typeof value.showStartupDiagnostics !== "boolean"
    || !Array.isArray(value.diagnostics)) return undefined;

  const diagnostics: SkillResolutionDiagnostic[] = [];
  for (const rawDiagnostic of value.diagnostics) {
    const diagnostic = parseDiagnostic(rawDiagnostic);
    if (!diagnostic) return undefined;
    diagnostics.push(diagnostic);
  }

  return {
    cwd: value.cwd,
    showStartupDiagnostics: value.showStartupDiagnostics,
    diagnostics,
  };
}
