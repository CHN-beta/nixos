/**
 * Client-safe comparable form for project/session paths.
 *
 * Pure string normalization — no node:path, no process.platform — so it can
 * be imported from browser components (SessionSidebar) as well as server
 * modules (project-registry). Windows-ness is decided by the path's own form
 * (drive letter / UNC prefix), which is deterministic on every platform.
 * Callers always pass absolute paths, so no cwd resolution is needed.
 */

const WINDOWS_ABSOLUTE_RE = /^[a-zA-Z]:[\\/]/;
const UNC_PREFIX_RE = /^\/\//;

/** Case-insensitive comparable form on Windows-form paths (NTFS is
 *  case-insensitive); case-sensitive for POSIX-form paths. */
export function comparableProjectPath(value: string): string {
  let normalized = value.replace(/\\/g, "/");
  const windowsForm = WINDOWS_ABSOLUTE_RE.test(normalized) || UNC_PREFIX_RE.test(normalized);
  normalized = normalized.replace(/\/{2,}/g, "/").replace(/\/+$/, "");
  return windowsForm ? normalized.toLowerCase() : normalized;
}
