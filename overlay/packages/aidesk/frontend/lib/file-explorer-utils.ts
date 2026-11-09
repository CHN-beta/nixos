/**
 * Pure helpers for the file explorer: metadata formatting, client-side
 * ordering, duplicate-name selection, path containment, and recursive
 * extraction of files dropped from the operating system.
 *
 * Kept out of FileExplorer.tsx so the tree component stays about state and
 * rendering; nothing here touches React or the network.
 */
import { normalizeFilePathSlashes } from "./file-paths";

export type ExplorerSortMode = "name" | "modified" | "size";

export interface DroppedFile {
  file: File;
  /** Path relative to the drop target, including dropped folder names. */
  relativePath: string;
}

export interface ExplorerNodeLike {
  name: string;
  isDir: boolean;
  size?: number;
  modified?: number;
}

/** Human-readable byte count (`12.4 KB`) used in row metadata. */
export function formatFileSize(bytes: number): string {
  if (!Number.isFinite(bytes) || bytes <= 0) return "0 B";
  if (bytes < 1024) return `${Math.round(bytes)} B`;
  const units = ["KB", "MB", "GB", "TB", "PB"];
  let value = bytes / 1024;
  let unit = units[0];
  for (let index = 1; index < units.length && value >= 1024; index += 1) {
    value /= 1024;
    unit = units[index];
  }
  return `${value >= 100 ? value.toFixed(0) : value.toFixed(1)} ${unit}`;
}

/** Compact local modification time (`Nov 9, 14:32`); empty when unknown. */
export function formatFileModified(modified?: number): string {
  if (!modified || !Number.isFinite(modified)) return "";
  const date = new Date(modified);
  if (Number.isNaN(date.getTime())) return "";
  const now = new Date();
  const sameYear = date.getFullYear() === now.getFullYear();
  try {
    return date.toLocaleString(undefined, {
      year: sameYear ? undefined : "numeric",
      month: "short",
      day: "numeric",
      hour: "2-digit",
      minute: "2-digit",
    });
  } catch {
    return date.toISOString();
  }
}

/**
 * Folders first, then the requested key. Ties fall back to a natural,
 * case-insensitive name comparison so ordering is stable across refreshes.
 */
export function sortExplorerNodes<T extends ExplorerNodeLike>(
  nodes: readonly T[],
  mode: ExplorerSortMode,
): T[] {
  return [...nodes].sort((left, right) => {
    if (left.isDir !== right.isDir) return left.isDir ? -1 : 1;
    let result = 0;
    if (mode === "modified") result = (Number(right.modified) || 0) - (Number(left.modified) || 0);
    else if (mode === "size") result = (Number(right.size) || 0) - (Number(left.size) || 0);
    if (result === 0) {
      result = left.name.localeCompare(right.name, undefined, { numeric: true, sensitivity: "base" });
    }
    return result;
  });
}

function splitFileName(name: string, isDir: boolean): { base: string; ext: string } {
  if (isDir) return { base: name, ext: "" };
  const dot = name.lastIndexOf(".");
  // A leading dot (.env) is part of the name, not an extension.
  if (dot <= 0 || dot === name.length - 1) return { base: name, ext: "" };
  return { base: name.slice(0, dot), ext: name.slice(dot) };
}

/** `name copy.ext`, then `name (1).ext`, `name (2).ext`, ... */
export function duplicateCandidateName(name: string, isDir: boolean, attempt: number): string {
  const { base, ext } = splitFileName(name, isDir);
  if (attempt <= 1) return `${base} copy${ext}`;
  return `${base} (${attempt - 1})${ext}`;
}

function pathKey(path: string): string {
  const normalized = normalizeFilePathSlashes(path).replace(/\/+$/, "");
  return /^[a-zA-Z]:/.test(normalized) || normalized.startsWith("//")
    ? normalized.toLowerCase()
    : normalized;
}

/** True when `candidate` is `parent` or lives inside it. */
export function isPathEqualOrInside(candidate: string, parent: string): boolean {
  const candidateKey = pathKey(candidate);
  const parentKey = pathKey(parent);
  if (!parentKey) return false;
  return candidateKey === parentKey || candidateKey.startsWith(`${parentKey}/`);
}

/** Rebase a path after its ancestor was renamed or moved. */
export function rebasePath(path: string, oldBase: string, newBase: string, isDir: boolean): string {
  const normalizedPath = normalizeFilePathSlashes(path);
  const normalizedOld = normalizeFilePathSlashes(oldBase).replace(/\/+$/, "");
  if (normalizedPath === normalizedOld) return newBase;
  if (isDir && normalizedPath.startsWith(`${normalizedOld}/`)) {
    return `${newBase}${normalizedPath.slice(normalizedOld.length)}`;
  }
  return path;
}

/**
 * Walk a `DataTransfer` synchronously enough to capture every entry before
 * the first await (the browser invalidates items after the event handler
 * returns), then recursively expand dropped directories.
 */
export async function collectDroppedFiles(dataTransfer: DataTransfer): Promise<DroppedFile[]> {
  const entries: FileSystemEntry[] = [];
  const items = dataTransfer.items ? Array.from(dataTransfer.items) : [];
  for (const item of items) {
    if (item.kind !== "file") continue;
    const entry = item.webkitGetAsEntry?.() ?? null;
    if (entry) entries.push(entry);
  }

  // Older browsers (and some synthetic drops) only expose `files`.
  if (entries.length === 0) {
    return Array.from(dataTransfer.files ?? []).map((file) => ({ file, relativePath: file.name }));
  }

  const collected: DroppedFile[] = [];
  const walk = async (entry: FileSystemEntry, parent: string): Promise<void> => {
    if (entry.isFile) {
      const file = await fileFromEntry(entry as FileSystemFileEntry);
      collected.push({
        file,
        relativePath: parent ? `${parent}/${entry.name}` : entry.name,
      });
      return;
    }
    if (!entry.isDirectory) return;
    const directoryEntry = entry as FileSystemDirectoryEntry;
    const prefix = parent ? `${parent}/${entry.name}` : entry.name;
    const children = await readAllDirectoryEntries(directoryEntry.createReader());
    for (const child of children) await walk(child, prefix);
  };

  for (const entry of entries) await walk(entry, "");
  return collected;
}

function fileFromEntry(entry: FileSystemFileEntry): Promise<File> {
  const { promise, resolve, reject } = Promise.withResolvers<File>();
  entry.file(resolve, reject);
  return promise;
}

function readAllDirectoryEntries(reader: FileSystemDirectoryReader): Promise<FileSystemEntry[]> {
  return new Promise((resolve, reject) => {
    const all: FileSystemEntry[] = [];
    const readBatch = () => {
      reader.readEntries((batch) => {
        if (batch.length === 0) {
          resolve(all);
          return;
        }
        all.push(...batch);
        readBatch();
      }, reject);
    };
    readBatch();
  });
}
