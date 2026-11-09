
import { forwardRef, memo, useState, useCallback, useEffect, useImperativeHandle, useMemo, useRef } from "react";
import {
  AtSign,
  Check,
  ChevronRight,
  CircleAlert,
  CircleMinus,
  ClipboardPaste,
  Copy,
  Download,
  FileArchive,
  FilePlus,
  FileText,
  Files,
  Folder,
  FolderOpen,
  FolderPlus,
  FolderUp,
  HardDrive,
  Loader2,
  Pencil,
  Scissors,
  Trash2,
  TriangleAlert,
  Upload,
  X,
} from "lucide-react";
import { getFileIcon } from "./FileIcons";
import { Dialog, DialogContent, DialogTitle, Tooltip } from "./ui/primitives";
import { ConfirmDialog } from "./ui/field";
import { toast } from "./ui/toast";
import { SidebarPortalMenu } from "./SessionSidebar-chrome";
import { translate, useI18n } from "@/lib/i18n";
import { apiUrl, redirectToAuth } from "@/lib/api-origin";
import { useWebSettings } from "@/lib/web-settings";
import { copyText } from "@/lib/clipboard";
import { useIsMobile } from "@/hooks/useIsMobile";
import {
  encodeFilePathForApi,
  getFileDirectory,
  getFileName,
  getRelativeFilePath,
  joinFilePath,
  normalizeFilePathSlashes,
} from "@/lib/file-paths";
import {
  collectDroppedFiles,
  duplicateCandidateName,
  formatFileModified,
  formatFileSize,
  isPathEqualOrInside,
  rebasePath,
  sortExplorerNodes,
  type ExplorerSortMode,
} from "@/lib/file-explorer-utils";
import type { GitFileStatus, GitFileStatusKind, GitStatusResponse } from "@/lib/git-types";
import type { FileOpenMode } from "@/lib/file-types";
import { MAX_RESULT_LIMIT, type FileIndexEntry } from "@/lib/file-fuzzy";
import { buildSearchRows } from "@/lib/search-results";

interface FileEntry {
  name: string;
  isDir: boolean;
  isSymlink?: boolean;
  isIgnored?: boolean;
  size: number;
  modified: number;
}

interface FileNode {
  name: string;
  fullPath: string;
  isDir: boolean;
  size: number;
  modified: number;
  isSymlink?: boolean;
  isIgnored?: boolean;
  children?: FileNode[];
  loaded?: boolean;
}

interface Props {
  cwd: string;
  onOpenFile: (filePath: string, fileName: string, openAs?: FileOpenMode) => void;
  refreshKey?: number;
  onAtMention?: (relativePath: string, isDir: boolean) => void;
  onAtMentions?: (relativePaths: string[]) => void;
  onUploadBusyChange?: (busy: boolean) => void;
  onRefreshDone?: () => void;
  fileSearchOpen?: boolean;
  onFileSearchOpenChange?: (open: boolean) => void;
  /** Absolute path of the file open in the right panel — rendered selected. */
  activeFilePath?: string | null;
  /** Absolute path to expand, highlight, and scroll into view (one-shot). */
  revealPath?: string | null;
  onRevealDone?: () => void;
  /** Reports the git changed-file count so the explorer header can badge it. */
  onGitStatusChange?: (changedCount: number, isRepo: boolean) => void;
  /** Session that owns the workspace; mutations pass it through for access checks. */
  sourceSessionId?: string | null;
  /** Only the visible explorer responds to F2/Delete/Ctrl+C/X/V shortcuts. */
  active?: boolean;
  /** A rename/move succeeded: open tabs must follow the new path. */
  onPathRenamed?: (oldPath: string, newPath: string, isDir: boolean) => void;
  /** Paths were deleted: open tabs below them must close. */
  onPathsDeleted?: (paths: string[]) => void;
  /** Opens Settings → Add-ons with the “mount as a drive” guide. */
  onOpenMountGuide?: () => void;
}

export interface FileExplorerHandle {
  openUploadPicker: () => void;
  openFolderUploadPicker: () => void;
  collapseAll: () => void;
}

/** Right-click target in the file tree. */
interface ExplorerMenuTarget {
  kind: "dir" | "file";
  path: string;
  name: string;
  /** Where the create actions land: the folder itself, or a file's parent. */
  directory: string;
}

interface ClipboardItem {
  path: string;
  name: string;
  isDir: boolean;
}

interface ClipboardState {
  action: "copy" | "cut";
  items: ClipboardItem[];
}

type PasteAction = "copy" | "move";

interface PastePlan {
  action: PasteAction;
  items: ClipboardItem[];
  destination: string;
  index: number;
}

interface PasteConflict {
  plan: PastePlan;
  index: number;
  item: ClipboardItem;
  destination: string;
}

interface RenameState {
  path: string;
  value: string;
  isDir: boolean;
  originalName: string;
}

const TREE_DRAG_TYPE = "application/x-aidesk-tree-paths";
const INCLUDE_IGNORED_KEY = "aidesk.fileExplorer.includeIgnored";
const SORT_MODE_KEY = "aidesk.fileExplorer.sortMode";

function readStoredBoolean(key: string): boolean {
  try {
    return localStorage.getItem(key) === "1";
  } catch {
    return false;
  }
}

function readStoredSortMode(): ExplorerSortMode {
  try {
    const stored = localStorage.getItem(SORT_MODE_KEY);
    if (stored === "modified" || stored === "size" || stored === "name") return stored;
  } catch {
    // storage unavailable
  }
  return "name";
}

function storePreference(key: string, value: string): void {
  try {
    localStorage.setItem(key, value);
  } catch {
    // storage unavailable (private mode etc.)
  }
}


/** "Open with" choices; each maps to a backend `?as=` override. */
const OPEN_WITH_OPTIONS: Array<{ mode: FileOpenMode; labelKey: string }> = [
  { mode: "edit", labelKey: "fileExplorer.openAsEdit" },
  { mode: "markdown", labelKey: "fileExplorer.openAsMarkdown" },
  { mode: "html", labelKey: "fileExplorer.openAsHtml" },
  { mode: "pdf", labelKey: "fileExplorer.openAsPdf" },
  { mode: "docx", labelKey: "fileExplorer.openAsDocx" },
  { mode: "image", labelKey: "fileExplorer.openAsImage" },
  { mode: "audio", labelKey: "fileExplorer.openAsAudio" },
];

function ExplorerMenuItem({ label, icon, onSelect, disabled = false, danger = false }: {
  label: string;
  icon?: React.ReactNode;
  onSelect: () => void;
  disabled?: boolean;
  danger?: boolean;
}) {
  return (
    <button
      type="button"
      role="menuitem"
      className="sidebar-menu-item"
      disabled={disabled}
      onClick={onSelect}
      style={danger ? { color: "var(--status-error)" } : undefined}
    >
      {icon}
      <span style={{ minWidth: 0, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>{label}</span>
    </button>
  );
}

function ExplorerCheckableMenuItem({ label, checked, onSelect }: {
  label: string;
  checked: boolean;
  onSelect: () => void;
}) {
  return (
    <button
      type="button"
      role="menuitemcheckbox"
      aria-checked={checked}
      className="sidebar-menu-item"
      onClick={onSelect}
    >
      {checked
        ? <Check size={12} strokeWidth={2.2} aria-hidden="true" />
        : <span style={{ width: 12, height: 12, flexShrink: 0 }} aria-hidden="true" />}
      <span style={{ minWidth: 0, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>{label}</span>
    </button>
  );
}

function InlineRenameInput({ value, isDir, onChange, onCommit, onCancel }: {
  value: string;
  isDir: boolean;
  onChange: (value: string) => void;
  onCommit: () => void;
  onCancel: () => void;
}) {
  const inputRef = useRef<HTMLInputElement>(null);
  // Select the base name, leaving the extension out of the preselection so
  // typing replaces `report` rather than `report.md`.
  useEffect(() => {
    const input = inputRef.current;
    if (!input) return;
    input.focus();
    const dot = isDir ? -1 : value.lastIndexOf(".");
    input.setSelectionRange(0, dot > 0 ? dot : value.length);
    // Only on mount: value changes on every keystroke and must keep the caret.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);
  return (
    <input
      ref={inputRef}
      value={value}
      aria-label={translate("fileExplorer.rename")}
      onClick={(event) => event.stopPropagation()}
      onDoubleClick={(event) => event.stopPropagation()}
      onChange={(event) => onChange(event.target.value)}
      onKeyDown={(event) => {
        event.stopPropagation();
        if (event.key === "Enter") {
          event.preventDefault();
          onCommit();
        } else if (event.key === "Escape") {
          event.preventDefault();
          onCancel();
        }
      }}
      onBlur={onCommit}
      style={{
        flex: 1,
        minWidth: 0,
        height: 20,
        boxSizing: "border-box",
        padding: "0 4px",
        background: "var(--bg)",
        border: "1px solid var(--accent)",
        borderRadius: "var(--radius-control)",
        outline: "none",
        color: "var(--text)",
        fontSize: 12,
        fontFamily: "var(--font-mono)",
      }}
    />
  );
}

function CreateEntryDialog({ kind, directory, onClose, onCreated }: {
  kind: "file" | "dir";
  directory: string;
  onClose: () => void;
  onCreated: (path: string, kind: "file" | "dir") => void;
}) {
  const { t } = useI18n();
  const [name, setName] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const title = kind === "file" ? t("fileExplorer.newFile") : t("fileExplorer.newFolder");

  const submit = async () => {
    const trimmed = name.trim();
    if (!trimmed || busy) return;
    if (trimmed === "." || trimmed === ".." || /[\\/\0]/.test(trimmed)) {
      setError(t("fileExplorer.invalidName"));
      return;
    }
    const target = joinFilePath(directory, trimmed);
    setBusy(true);
    setError(null);
    try {
      const response = await fetch(
        apiUrl(`/api/files/${encodeFilePathForApi(target)}${kind === "dir" ? "?type=mkdir" : ""}`),
        kind === "dir"
          ? { method: "POST" }
          : {
              method: "PUT",
              headers: { "Content-Type": "application/json" },
              body: JSON.stringify({ content: "", createOnly: true }),
            },
      );
      const payload = await response.json().catch(() => ({})) as { error?: string; code?: string };
      if (!response.ok) {
        setError(
          payload.code === "file_already_exists" || payload.code === "already_exists"
            ? t("fileExplorer.nameTaken")
            : payload.error || t("fileExplorer.createFailed"),
        );
        return;
      }
      onCreated(target, kind);
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : String(cause));
    } finally {
      setBusy(false);
    }
  };

  return (
    <Dialog open onOpenChange={(next) => { if (!next) onClose(); }}>
      <DialogContent ariaLabel={title} style={{ width: 380, maxWidth: "min(92vw, 380px)", padding: 20 }}>
        <DialogTitle>{title}</DialogTitle>
        <div style={{ fontSize: 11, color: "var(--text-dim)", fontFamily: "var(--font-mono)", overflowWrap: "anywhere", marginBottom: 8 }}>{directory}</div>
        <input
          autoFocus
          value={name}
          onChange={(event) => setName(event.target.value)}
          onKeyDown={(event) => {
            if (event.key === "Enter") {
              event.preventDefault();
              void submit();
            }
            if (event.key === "Escape") {
              event.preventDefault();
              onClose();
            }
          }}
          aria-label={title}
          placeholder={kind === "file" ? t("fileExplorer.fileNamePlaceholder") : t("fileExplorer.folderNamePlaceholder")}
          style={{
            width: "100%",
            height: 32,
            boxSizing: "border-box",
            padding: "0 9px",
            background: "var(--bg)",
            border: `1px solid ${error ? "var(--status-error)" : "var(--border)"}`,
            borderRadius: "var(--radius-control)",
            outline: "none",
            color: "var(--text)",
            fontSize: 13,
            fontFamily: "var(--font-mono)",
          }}
        />
        {error && (
          <div role="alert" style={{ marginTop: 6, fontSize: 11, color: "var(--status-error)", overflowWrap: "anywhere" }}>{error}</div>
        )}
        <div style={{ display: "flex", justifyContent: "flex-end", gap: 8, marginTop: 14 }}>
          <button
            type="button"
            onClick={onClose}
            style={{ padding: "6px 14px", background: "none", border: "1px solid var(--border)", borderRadius: "var(--radius-control)", color: "var(--text-muted)", cursor: "pointer", fontSize: 13 }}
          >
            {t("fileExplorer.cancel")}
          </button>
          <button
            type="button"
            disabled={busy || !name.trim()}
            onClick={() => void submit()}
            style={{ padding: "6px 14px", background: "var(--accent-strong)", border: "none", borderRadius: "var(--radius-control)", color: "var(--on-accent)", cursor: busy ? "wait" : "pointer", fontSize: 13, fontWeight: 600, opacity: busy || !name.trim() ? 0.7 : 1 }}
          >
            {t("fileExplorer.create")}
          </button>
        </div>
      </DialogContent>
    </Dialog>
  );
}

type UploadPhase = "idle" | "checking" | "uploading";
export type UploadConflictStrategy = "error" | "overwrite" | "skip" | "rename";

interface UploadError {
  name: string;
  error: string;
}

interface UploadResponse {
  uploaded?: string[];
  skipped?: string[];
  errors?: UploadError[];
  conflicts?: string[];
  nonReplaceable?: string[];
  error?: string;
  code?: string;
}

interface UploadSummary {
  uploaded: string[];
  skipped: string[];
  errors: UploadError[];
  targetDirectory: string;
}

interface UploadItem {
  file: File;
  relativePath: string;
}

interface PendingConflict {
  items: UploadItem[];
  targetDirectory: string;
  conflicts: string[];
  nonReplaceable: string[];
}

interface MutationResponse {
  success?: boolean;
  path?: string;
  action?: string;
  code?: string;
  error?: string;
}

interface MutationResult {
  status: number;
  ok: boolean;
  data: MutationResponse;
}

async function fetchEntries(dirPath: string, includeIgnored: boolean): Promise<FileNode[]> {
  const encoded = encodeFilePathForApi(dirPath);
  const params = new URLSearchParams({ type: "list", includeIgnored: includeIgnored ? "1" : "0" });
  const res = await fetch(`/api/files/${encoded}?${params.toString()}`);
  if (!res.ok) {
    let message = translate("fileExplorer.loadFailed", { status: res.status });
    try {
      const data = await res.json() as { error?: string };
      if (data.error) message = data.error;
    } catch {
      // ignore non-JSON error bodies
    }
    throw new Error(message);
  }
  const data = await res.json() as { entries?: FileEntry[] };
  return (data.entries ?? []).map((e) => ({
    name: e.name,
    fullPath: joinFilePath(dirPath, e.name),
    isDir: e.isDir,
    size: typeof e.size === "number" ? e.size : 0,
    modified: typeof e.modified === "number" ? e.modified : 0,
    isSymlink: e.isSymlink,
    isIgnored: e.isIgnored,
    children: e.isDir ? [] : undefined,
    loaded: !e.isDir,
  }));
}

async function fetchGitStatus(cwd: string): Promise<GitStatusResponse> {
  const params = new URLSearchParams({ cwd });
  const res = await fetch(`/api/git/status?${params.toString()}`);
  if (!res.ok) throw new Error(translate("fileExplorer.gitStatusFailed", { status: res.status }));
  return res.json() as Promise<GitStatusResponse>;
}

export const GIT_STATUS_LABEL_KEYS: Record<GitFileStatusKind, string> = {
  modified: "fileExplorer.gitModified",
  added: "fileExplorer.gitAdded",
  deleted: "fileExplorer.gitDeleted",
  renamed: "fileExplorer.gitRenamed",
  untracked: "fileExplorer.gitUntracked",
  conflict: "fileExplorer.gitConflict",
};

export const GIT_STATUS_COLORS: Record<GitFileStatusKind, string> = {
  modified: "var(--status-modified)",
  added: "var(--status-success)",
  deleted: "var(--status-error)",
  renamed: "var(--status-renamed)",
  untracked: "var(--status-success)",
  conflict: "var(--status-error)",
};

function uploadFiles(
  targetDirectory: string,
  items: UploadItem[],
  strategy: UploadConflictStrategy,
  onProgress: (progress: number) => void,
): Promise<{ status: number; data: UploadResponse }> {
  return new Promise((resolve, reject) => {
    const formData = new FormData();
    // The third argument is the path relative to the upload target, so a
    // dropped folder keeps its structure (`src/sub/b.txt`).
    items.forEach(({ file, relativePath }) => formData.append("files", file, relativePath));

    const xhr = new XMLHttpRequest();
    xhr.open(
      "POST",
      apiUrl(`/api/files/${encodeFilePathForApi(targetDirectory)}?type=upload&conflict=${strategy}`),
    );
    // Cross-origin upload: the Authelia cookie must ride along.
    xhr.withCredentials = true;
    xhr.upload.onprogress = (event) => {
      if (event.lengthComputable && event.total > 0) {
        onProgress(Math.round((event.loaded / event.total) * 100));
      }
    };
    xhr.onerror = () => reject(new Error(translate("fileExplorer.uploadNetworkError")));
    xhr.onabort = () => reject(new Error(translate("fileExplorer.uploadCancelled")));
    xhr.onload = () => {
      if (xhr.status === 401) redirectToAuth();
      let data: UploadResponse = {};
      try {
        data = JSON.parse(xhr.responseText) as UploadResponse;
      } catch {
        if (xhr.responseText) data.error = xhr.responseText;
      }
      resolve({ status: xhr.status, data });
    };
    xhr.send(formData);
  });
}

async function patchFilePath(
  sourcePath: string,
  action: "rename" | "move" | "copy",
  destination: string,
  overwrite: boolean,
  sourceSessionId?: string | null,
): Promise<MutationResult> {
  const params = new URLSearchParams();
  if (sourceSessionId) params.set("sourceSessionId", sourceSessionId);
  const query = params.toString();
  const res = await fetch(
    apiUrl(`/api/files/${encodeFilePathForApi(sourcePath)}${query ? `?${query}` : ""}`),
    {
      method: "PATCH",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ action, destination, overwrite }),
    },
  );
  let data: MutationResponse = {};
  try {
    data = await res.json() as MutationResponse;
  } catch {
    // Empty/non-JSON error body.
  }
  return { status: res.status, ok: res.ok, data };
}

async function deleteFilePath(
  targetPath: string,
  sourceSessionId?: string | null,
): Promise<MutationResult> {
  const params = new URLSearchParams({ recursive: "true" });
  if (sourceSessionId) params.set("sourceSessionId", sourceSessionId);
  const res = await fetch(
    apiUrl(`/api/files/${encodeFilePathForApi(targetPath)}?${params.toString()}`),
    { method: "DELETE" },
  );
  let data: MutationResponse = {};
  try {
    data = await res.json() as MutationResponse;
  } catch {
    // Empty/non-JSON error body.
  }
  return { status: res.status, ok: res.ok, data };
}

function DismissButton({ onClick, title }: { onClick: () => void; title: string }) {
  return (
    <button
      type="button"
      onClick={onClick}
      title={title}
      aria-label={title}
      style={{
        width: 24, height: 24, padding: 0,
        display: "flex", alignItems: "center", justifyContent: "center",
        flexShrink: 0, border: "none",
        borderRadius: "var(--radius-control)",
        background: "none",
        color: "var(--text-dim)",
        cursor: "pointer",
        transition: `background var(--dur-fast) var(--ease-out-warm), color var(--dur-fast) var(--ease-out-warm)`,
      }}
      onMouseEnter={(event) => { event.currentTarget.style.color = "var(--text-muted)"; event.currentTarget.style.background = "var(--bg-hover)"; }}
      onMouseLeave={(event) => { event.currentTarget.style.color = "var(--text-dim)"; event.currentTarget.style.background = "none"; }}
    >
      <X size={13} strokeWidth={2.2} aria-hidden="true" />
    </button>
  );
}

// Desktop keeps the compact tree density; mobile uses 44px rows so the
// primary file navigation remains comfortable to tap.
const OVERSCAN_ROWS = 8;

type FlatRow =
  | { kind: "node"; node: FileNode; depth: number; secondaryLabel?: string }
  | { kind: "empty"; key: string; depth: number };

function flattenVisibleRows(
  nodes: FileNode[],
  expandedPaths: Set<string>,
  childrenByPath: Map<string, FileNode[]>,
  depth: number,
  out: FlatRow[],
): FlatRow[] {
  for (const node of nodes) {
    out.push({ kind: "node", node, depth });
    if (node.isDir && expandedPaths.has(node.fullPath)) {
      const children = childrenByPath.get(node.fullPath);
      if (children) {
        if (children.length === 0) {
          out.push({ kind: "empty", key: node.fullPath, depth: depth + 1 });
        } else {
          flattenVisibleRows(children, expandedPaths, childrenByPath, depth + 1, out);
        }
      }
    }
  }
  return out;
}

interface ExplorerRowProps {
  row: FlatRow;
  index: number;
  rowHeight: number;
  rowCount: number;
  cwd: string;
  open: boolean;
  loading: boolean;
  highlighted: boolean;
  isActiveFile: boolean;
  focused: boolean;
  cut: boolean;
  dropTarget: boolean;
  renaming: boolean;
  renameValue: string;
  gitStatusByPath: Map<string, GitFileStatus>;
  changedDirectoryPaths: Set<string>;
  onAtMention?: (relativePath: string, isDir: boolean) => void;
  onActivate: (node: FileNode, index: number) => void;
  onContextMenu: (target: ExplorerMenuTarget, event: React.MouseEvent) => void;
  onKeyDown: (event: React.KeyboardEvent<HTMLDivElement>, node: FileNode, index: number) => void;
  onFocusRow: (index: number) => void;
  onRenameChange: (value: string) => void;
  onRenameCommit: () => void;
  onRenameCancel: () => void;
  onDragStartNode: (node: FileNode, event: React.DragEvent<HTMLDivElement>) => void;
  onDragEndNode: () => void;
}

// Memoized: the parent re-renders on every scroll tick, but a row only
// re-renders when its own props change. Without this, scrolling a 30k-row
// tree reconciles the whole window per frame instead of the shifted edges.
const ExplorerRow = memo(function ExplorerRow({
  row,
  index,
  rowCount,
  rowHeight,
  cwd,
  open,
  loading,
  highlighted,
  isActiveFile,
  focused,
  cut,
  dropTarget,
  renaming,
  renameValue,
  gitStatusByPath,
  changedDirectoryPaths,
  onAtMention,
  onActivate,
  onContextMenu,
  onKeyDown,
  onFocusRow,
  onRenameChange,
  onRenameCommit,
  onRenameCancel,
  onDragStartNode,
  onDragEndNode,
}: ExplorerRowProps) {
  const { t } = useI18n();
  const [hovered, setHovered] = useState(false);

  if (row.kind === "empty") {
    return (
      <div
        data-file-path={row.key}
        data-file-is-dir="1"
        onContextMenu={(event) => {
          event.preventDefault();
          event.stopPropagation();
          onContextMenu({ kind: "dir", path: row.key, name: getFileName(row.key), directory: row.key }, event);
        }}
        style={{ paddingLeft: 8 + row.depth * 14, fontSize: 11, color: "var(--text-dim)", height: rowHeight, display: "flex", alignItems: "center" }}
      >
        {t("fileExplorer.emptyDir")}
      </div>
    );
  }

  const { node, secondaryLabel } = row;
  const normalizedPath = normalizeFilePathSlashes(node.fullPath);
  const gitStatus = gitStatusByPath.get(normalizedPath);
  const containsGitChanges = node.isDir && (
    gitStatus !== undefined || changedDirectoryPaths.has(normalizedPath)
  );
  const mentionLabel = t("fileExplorer.insertPathIntoChat");
  const modifiedLabel = formatFileModified(node.modified);
  const sizeLabel = !node.isDir && node.size > 0 ? formatFileSize(node.size) : "";
  const metaText = [sizeLabel, modifiedLabel].filter(Boolean).join(" · ");
  const rowTitle = metaText ? `${node.fullPath}\n${metaText}` : node.fullPath;

  return (
    <div
      onClick={() => onActivate(node, index)}
      onContextMenu={(event) => {
        event.preventDefault();
        event.stopPropagation();
        onContextMenu(
          node.isDir
            ? { kind: "dir", path: node.fullPath, name: node.name, directory: node.fullPath }
            : { kind: "file", path: node.fullPath, name: node.name, directory: getFileDirectory(node.fullPath) },
          event,
        );
      }}
      onKeyDown={(e) => onKeyDown(e, node, index)}
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
      onFocus={(e) => { if (e.target === e.currentTarget) onFocusRow(index); }}
      draggable={!renaming}
      onDragStart={(event) => onDragStartNode(node, event)}
      onDragEnd={onDragEndNode}
      role="treeitem"
      tabIndex={focused ? 0 : -1}
      data-index={index}
      data-file-path={node.fullPath}
      data-file-is-dir={node.isDir ? "1" : "0"}
      aria-selected={highlighted || isActiveFile}
      aria-current={isActiveFile ? "true" : undefined}
      aria-expanded={node.isDir ? open : undefined}
      aria-level={row.depth + 1}
      aria-setsize={rowCount}
      aria-posinset={index + 1}
      // Search rows repeat names such as route.ts, so the directory has to be
      // part of the accessible name, not just the dimmed text beside it.
      aria-label={node.isDir
        ? (node.name + " (folder" + (open ? ", expanded" : ", collapsed") + ")")
        : (secondaryLabel ? (node.name + " (file, " + secondaryLabel + ")") : (node.name + " (file)"))}
      style={{
        display: "flex",
        alignItems: "center",
        gap: 4,
        paddingLeft: 8 + row.depth * 14,
        paddingRight: 8,
        height: rowHeight,
        cursor: "pointer",
        background: dropTarget
          ? "color-mix(in srgb, var(--accent) 16%, var(--bg-hover))"
          : isActiveFile ? "var(--bg-selected)" : hovered ? "var(--bg-hover)" : "transparent",
        opacity: cut ? 0.55 : node.isIgnored ? 0.72 : 1,
        borderRadius: "var(--radius-control)",
        userSelect: "none",
        boxShadow: dropTarget
          ? "inset 0 0 0 2px var(--accent)"
          : focused ? "inset 0 0 0 1px color-mix(in srgb, var(--accent) 70%, transparent)" : isActiveFile ? "inset 2px 0 0 var(--accent)" : "none",
        outline: "none",
        transition: `background var(--dur-fast) var(--ease-out-warm)`,
      }}
    >
      {node.isDir && (
        <ChevronRight
          size={10}
          strokeWidth={2}
          color="var(--text-dim)"
          style={{
            flexShrink: 0,
            transform: open ? "rotate(90deg)" : "none",
            transition: `transform var(--dur-med) var(--ease-out-warm)`,
          }}
          aria-hidden="true"
        />
      )}
      {!node.isDir && <span style={{ width: 10, flexShrink: 0 }} />}
      <span style={{ flexShrink: 0, display: "flex", alignItems: "center", color: node.isDir ? "var(--text-muted)" : "var(--text-dim)" }}>
        {node.isDir ? (
          open ? <FolderOpen size={14} strokeWidth={1.8} aria-hidden="true" /> : <Folder size={14} strokeWidth={1.8} aria-hidden="true" />
        ) : (
          getFileIcon(node.name, 14)
        )}
      </span>
      {renaming ? (
        <InlineRenameInput
          value={renameValue}
          isDir={node.isDir}
          onChange={onRenameChange}
          onCommit={onRenameCommit}
          onCancel={onRenameCancel}
        />
      ) : (
        <span
          style={{
            fontSize: 12,
            color: "var(--text)",
            overflow: "hidden",
            textOverflow: "ellipsis",
            whiteSpace: "nowrap",
            // Prefer the name, but let it shrink to keep row actions reachable.
            flex: secondaryLabel ? "0 1 auto" : 1,
            maxWidth: secondaryLabel ? "72%" : undefined,
          }}
          title={rowTitle}
        >
          {node.name}
        </span>
      )}
      {!renaming && hovered && !secondaryLabel && metaText && (
        <span
          title={`${modifiedLabel ? t("fileExplorer.modifiedAt", { date: modifiedLabel }) : ""}${sizeLabel && modifiedLabel ? "\n" : ""}${sizeLabel}`}
          style={{
            flexShrink: 0,
            maxWidth: "45%",
            overflow: "hidden",
            textOverflow: "ellipsis",
            whiteSpace: "nowrap",
            fontSize: 10,
            color: "var(--text-dim)",
            fontVariantNumeric: "tabular-nums",
          }}
        >
          {metaText}
        </span>
      )}
      {secondaryLabel && (
        // Search rows are flat, so the directory is the only context a row has.
        <span
          style={{
            flex: "1 1 auto",
            minWidth: 0,
            fontSize: 11,
            color: "var(--text-dim)",
            overflow: "hidden",
            textOverflow: "ellipsis",
            whiteSpace: "nowrap",
            direction: "rtl",
            textAlign: "left",
          }}
          title={node.fullPath}
        >
          {secondaryLabel}
        </span>
      )}
      {highlighted && (
        <span
          title={t("fileExplorer.newlyUploaded")}
          aria-label={t("fileExplorer.newlyUploaded")}
          style={{ width: 6, height: 6, flexShrink: 0, borderRadius: "50%", background: "var(--accent)" }}
        />
      )}
      {!node.isDir && gitStatus && (
        <span
          title={t(GIT_STATUS_LABEL_KEYS[gitStatus.status])}
          aria-label={t(GIT_STATUS_LABEL_KEYS[gitStatus.status])}
          style={{
            width: 14,
            flexShrink: 0,
            color: GIT_STATUS_COLORS[gitStatus.status],
            fontFamily: "var(--font-mono)",
            fontSize: 11,
            fontWeight: 600,
            textAlign: "center",
          }}
        >
          {gitStatus.code}
        </span>
      )}
      {containsGitChanges && (
        <span
          title={t("fileExplorer.containsChangedFiles")}
          aria-label={t("fileExplorer.containsChangedFiles")}
          style={{
            width: 6,
            height: 6,
            flexShrink: 0,
            borderRadius: "50%",
            background: "var(--status-modified)",
          }}
        />
      )}
      {loading && (
        <Loader2 size={10} strokeWidth={2} color="var(--text-dim)" style={{ animation: "spin 0.8s linear infinite", flexShrink: 0 }} aria-hidden="true" />
      )}
      {onAtMention && (hovered || focused) && (
        <Tooltip content={mentionLabel}>
          <button
            type="button"
            onClick={(e) => {
              e.stopPropagation();
              onAtMention(getRelativeFilePath(node.fullPath, cwd), node.isDir);
            }}
            aria-label={mentionLabel}
            style={{
              flexShrink: 0,
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
              width: 22,
              height: 22,
              padding: 0,
              background: "transparent",
              border: "none",
              borderRadius: "var(--radius-control)",
              color: "var(--accent)",
              cursor: "pointer",
              transition: `background var(--dur-fast) var(--ease-out-warm), color var(--dur-fast) var(--ease-out-warm)`,
            }}
            onMouseEnter={(e) => { e.currentTarget.style.background = "var(--bg-panel)"; }}
            onMouseLeave={(e) => { e.currentTarget.style.background = "transparent"; }}
          >
            <AtSign size={12} strokeWidth={2.2} aria-hidden="true" />
          </button>
        </Tooltip>
      )}
    </div>
  );
});

export const FileExplorer = forwardRef<FileExplorerHandle, Props>(function FileExplorer({
  cwd,
  onOpenFile,
  refreshKey,
  onAtMention,
  onAtMentions,
  onUploadBusyChange,
  onRefreshDone,
  fileSearchOpen = false,
  onFileSearchOpenChange,
  activeFilePath = null,
  revealPath = null,
  onRevealDone,
  onGitStatusChange,
  sourceSessionId = null,
  active = true,
  onPathRenamed,
  onPathsDeleted,
  onOpenMountGuide,
}, ref) {
  const { t, tn } = useI18n();
  const isMobile = useIsMobile();
  const rowHeight = isMobile ? 44 : 24;
  // Directory listings keyed by absolute path. The tree renders from a flat
  // projection of this map, so 30k visible rows cost one array walk — never
  // 30k mounted components.
  const [childrenByPath, setChildrenByPath] = useState<Map<string, FileNode[]>>(new Map());
  const [loadingPaths, setLoadingPaths] = useState<Set<string>>(new Set());
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [expandedPaths, setExpandedPaths] = useState<Set<string>>(new Set());
  const [treeRefreshKey, setTreeRefreshKey] = useState(0);
  const [highlightedPaths, setHighlightedPaths] = useState<Set<string>>(new Set());
  const [gitFiles, setGitFiles] = useState<GitFileStatus[]>([]);
  const [focusedIndex, setFocusedIndex] = useState(0);
  const [scrollTop, setScrollTop] = useState(0);
  const [viewportHeight, setViewportHeight] = useState(0);
  const [uploadPhase, setUploadPhase] = useState<UploadPhase>("idle");
  const [uploadProgress, setUploadProgress] = useState(0);
  const [uploadError, setUploadError] = useState<string | null>(null);
  const [uploadSummary, setUploadSummary] = useState<UploadSummary | null>(null);
  const [pendingConflict, setPendingConflict] = useState<PendingConflict | null>(null);
  const [searchQuery, setSearchQuery] = useState("");
  const [searchPaths, setSearchPaths] = useState<string[]>([]);
  // Right-click menu + the "new file / new folder" prompt it can open.
  const [contextMenu, setContextMenu] = useState<{ x: number; y: number; target: ExplorerMenuTarget } | null>(null);
  // Account preference: dotfiles are opt-in, and toggling reloads nothing —
  // every loaded listing is filtered client-side.
  const { showHiddenFiles, setShowHiddenFiles } = useWebSettings();
  const [includeIgnored, setIncludeIgnored] = useState<boolean>(() => readStoredBoolean(INCLUDE_IGNORED_KEY));
  const [sortMode, setSortMode] = useState<ExplorerSortMode>(() => readStoredSortMode());
  const [createDialog, setCreateDialog] = useState<{ kind: "file" | "dir"; directory: string } | null>(null);
  const [searchTruncated, setSearchTruncated] = useState(false);
  const [searchLoading, setSearchLoading] = useState(false);
  const [searchFailed, setSearchFailed] = useState(false);
  const [renaming, setRenaming] = useState<RenameState | null>(null);
  const [deleteTarget, setDeleteTarget] = useState<ExplorerMenuTarget | null>(null);
  const [deleting, setDeleting] = useState(false);
  const [clipboard, setClipboard] = useState<ClipboardState | null>(null);
  const [pasteConflict, setPasteConflict] = useState<PasteConflict | null>(null);
  const [pasteBusy, setPasteBusy] = useState(false);
  const [dropTargetPath, setDropTargetPath] = useState<string | null>(null);
  const searchInputRef = useRef<HTMLInputElement>(null);
  const prevCwdRef = useRef<string | null>(null);
  const uploadInputRef = useRef<HTMLInputElement>(null);
  const uploadFolderInputRef = useRef<HTMLInputElement>(null);
  const uploadTargetRef = useRef<string>(cwd);
  const scrollRef = useRef<HTMLDivElement>(null);
  const loadingPathsRef = useRef<Set<string>>(new Set());
  const rootRequestRef = useRef(0);
  const expandedPathsRef = useRef<Set<string>>(new Set());
  expandedPathsRef.current = expandedPaths;
  const renameGuardRef = useRef<string | null>(null);
  const listingGenerationRef = useRef(0);
  const autoExpandTimerRef = useRef<number | null>(null);
  const autoExpandPathRef = useRef<string | null>(null);
  const refreshToken = `${refreshKey ?? 0}:${treeRefreshKey}`;
  // Which refresh the search request has already answered; re-baselined every
  // time the panel opens.
  const consumedRefreshTokenRef = useRef<string | null>(null);
  const uploadBusy = uploadPhase !== "idle";
  const searchActive = fileSearchOpen && searchQuery.trim().length > 0;

  // Opening the panel focuses the input; closing it resets the whole search,
  // mirroring how the session search behaves.
  useEffect(() => {
    if (fileSearchOpen) {
      // Baseline for forced refreshes: only a refresh after the panel opened
      // counts. The sidebar bumps the explorer key once on mount, and nobody
      // asked for that one.
      consumedRefreshTokenRef.current = refreshToken;
      searchInputRef.current?.focus();
      return;
    }
    setSearchQuery("");
    setSearchPaths([]);
    setSearchTruncated(false);
    setSearchLoading(false);
    setSearchFailed(false);
    // refreshToken is read as the value at open time on purpose: adding it to
    // the deps would re-baseline on every refresh and swallow it.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [fileSearchOpen]);

  // Debounced query against the same cached, bounded file index that backs
  // the @ mention autocomplete. No second index.
  useEffect(() => {
    if (!fileSearchOpen) return;
    const query = searchQuery.trim();
    if (!query) {
      setSearchPaths([]);
      setSearchTruncated(false);
      setSearchLoading(false);
      setSearchFailed(false);
      return;
    }
    const controller = new AbortController();
    setSearchLoading(true);
    setSearchFailed(false);
    const timer = setTimeout(() => {
      // Only a real refresh bypasses the index cache; typing must not force a
      // fresh listing on every keystroke.
      const requestedToken = refreshToken;
      const forceRefresh = consumedRefreshTokenRef.current !== requestedToken;
      const params = new URLSearchParams({
        cwd,
        q: query,
        limit: String(MAX_RESULT_LIMIT),
        // The panel lists files, so directories must be dropped before the
        // limit is applied, not after.
        kind: "file",
      });
      if (forceRefresh) params.set("refresh", "1");
      fetch(`/api/file-index?${params.toString()}`, { signal: controller.signal })
        .then((res) => res.ok
          ? res.json() as Promise<{ matches?: FileIndexEntry[]; truncated?: boolean }>
          : Promise.reject(new Error(`HTTP ${res.status}`)))
        .then((data) => {
          if (controller.signal.aborted) return;
          // Acknowledge the refresh only now: a failed or aborted request must
          // leave it pending so the next one still asks for a fresh listing.
          consumedRefreshTokenRef.current = requestedToken;
          setSearchPaths((data.matches ?? []).map((m) => m.path));
          setSearchTruncated(Boolean(data.truncated));
        })
        .catch(() => {
          if (!controller.signal.aborted) {
            setSearchPaths([]);
            setSearchTruncated(false);
            setSearchFailed(true);
          }
        })
        .finally(() => { if (!controller.signal.aborted) setSearchLoading(false); });
    }, 150);
    return () => { clearTimeout(timer); controller.abort(); };
    // refreshToken participates so the toolbar refresh button and a finished
    // upload re-run the visible query against a freshly built listing.
  }, [cwd, fileSearchOpen, searchQuery, refreshToken]);

  // Rows stay in the order the index ranked them, so the closest name matches
  // sit at the top. Folding them into a directory tree would re-sort them
  // alphabetically and push, say, AGENTS.md below every app/api/agent/… file
  // that only matched on its parent directory.
  const searchRows = useMemo(() => buildSearchRows(
    showHiddenFiles
      ? searchPaths
      // A hidden segment anywhere in the path hides the file, matching the tree.
      : searchPaths.filter((path) => !path.split("/").some((part) => part.startsWith("."))),
  ).map((row) => ({
    ...row,
    node: {
      name: row.name,
      fullPath: joinFilePath(cwd, row.path),
      isDir: false,
      size: 0,
      modified: 0,
      loaded: true,
    } satisfies FileNode,
  })), [cwd, searchPaths, showHiddenFiles]);

  const searchFlatRows: FlatRow[] = useMemo(() => searchRows.map((row) => ({
    kind: "node",
    node: row.node,
    depth: 0,
    secondaryLabel: row.directory,
  })), [searchRows]);

  const filterNodes = useCallback((nodes: FileNode[]) => nodes.filter((node) => (
    (showHiddenFiles || !node.name.startsWith("."))
    && (includeIgnored || !node.isIgnored)
  )), [includeIgnored, showHiddenFiles]);
  const roots = useMemo(
    () => sortExplorerNodes(filterNodes(childrenByPath.get(cwd) ?? []), sortMode),
    [childrenByPath, cwd, filterNodes, sortMode],
  );
  // Filtering the loaded listings (not the fetch) means toggling the preference
  // reveals or hides dotfiles/ignored folders immediately, including inside
  // expanded folders.
  const visibleChildrenByPath = useMemo(() => {
    const filtered = new Map<string, FileNode[]>();
    for (const [path, children] of childrenByPath) {
      filtered.set(path, sortExplorerNodes(filterNodes(children), sortMode));
    }
    return filtered;
  }, [childrenByPath, filterNodes, sortMode]);
  const rows: FlatRow[] = useMemo(() => {
    if (searchActive) return searchFlatRows;
    return flattenVisibleRows(roots, expandedPaths, visibleChildrenByPath, 0, []);
  }, [searchActive, searchFlatRows, roots, expandedPaths, visibleChildrenByPath]);
  const rowsRef = useRef<FlatRow[]>([]);
  rowsRef.current = rows;
  const focusedIndexRef = useRef(0);
  focusedIndexRef.current = focusedIndex;

  const normalizedActiveFilePath = activeFilePath ? normalizeFilePathSlashes(activeFilePath) : null;
  const totalListHeight = rows.length * rowHeight;
  const windowStart = Math.max(0, Math.floor(scrollTop / rowHeight) - OVERSCAN_ROWS);
  const windowEnd = Math.min(
    rows.length,
    Math.ceil((scrollTop + (viewportHeight || rowHeight)) / rowHeight) + OVERSCAN_ROWS,
  );

  const gitStatusByPath = useMemo(() => new Map(
    gitFiles.map((status) => [normalizeFilePathSlashes(status.filePath), status]),
  ), [gitFiles]);

  const changedDirectoryPaths = useMemo(() => {
    const directories = new Set<string>();
    const normalizedCwd = normalizeFilePathSlashes(cwd).replace(/\/$/, "");
    for (const status of gitFiles) {
      let directory = getFileDirectory(normalizeFilePathSlashes(status.filePath));
      while (directory === normalizedCwd || directory.startsWith(`${normalizedCwd}/`)) {
        directories.add(directory);
        if (directory === normalizedCwd) break;
        const parent = getFileDirectory(directory);
        if (parent === directory) break;
        directory = parent;
      }
    }
    return directories;
  }, [cwd, gitFiles]);

  const handleToggleExpanded = useCallback((fullPath: string, open: boolean) => {
    setExpandedPaths((prev) => {
      if (prev.has(fullPath) === open) return prev;
      const next = new Set(prev);
      if (open) next.add(fullPath); else next.delete(fullPath);
      return next;
    });
  }, []);
  // Single fetch path for every directory in the flat map. The ref guards
  // against duplicate in-flight requests; the state copy drives spinners.
  const fetchDir = useCallback((dirPath: string) => {
    if (loadingPathsRef.current.has(dirPath)) return Promise.resolve();
    loadingPathsRef.current.add(dirPath);
    setLoadingPaths((prev) => new Set(prev).add(dirPath));
    const generation = listingGenerationRef.current;
    return fetchEntries(dirPath, includeIgnored)
      .then((entries) => {
        if (generation !== listingGenerationRef.current) return;
        setChildrenByPath((prev) => {
          const next = new Map(prev);
          next.set(dirPath, entries);
          return next;
        });
        if (dirPath === cwd) setError(null);
      })
      .catch((e) => {
        if (dirPath === cwd) setError(e instanceof Error ? e.message : String(e));
      })
      .finally(() => {
        loadingPathsRef.current.delete(dirPath);
        setLoadingPaths((prev) => {
          const next = new Set(prev);
          next.delete(dirPath);
          return next;
        });
      });
  }, [cwd, includeIgnored]);

  // Scroll the virtual window so a row is visible, then focus it. The focus
  // retries across frames: the scroll triggers an async window re-render and
  // the row element may not exist on the first frame.
  const goToRow = useCallback((index: number) => {
    const list = rowsRef.current;
    if (index < 0 || index >= list.length || list[index].kind !== "node") return;
    setFocusedIndex(index);
    const container = scrollRef.current;
    if (container) {
      const top = index * rowHeight;
      const bottom = top + rowHeight;
      const nextTop = top < container.scrollTop
        ? top
        : bottom > container.scrollTop + container.clientHeight
          ? bottom - container.clientHeight
          : container.scrollTop;
      if (nextTop !== container.scrollTop) {
        container.scrollTop = nextTop;
        setScrollTop(nextTop);
      }
    }
    const attemptFocus = (triesLeft: number) => {
      const el = scrollRef.current?.querySelector<HTMLElement>(`[data-index="${index}"]`);
      if (el) {
        el.focus({ preventScroll: true });
        return;
      }
      if (triesLeft > 0) requestAnimationFrame(() => attemptFocus(triesLeft - 1));
    };
    requestAnimationFrame(() => attemptFocus(5));
  }, [rowHeight]);

  const handleActivateRow = useCallback((node: FileNode, index: number) => {
    setFocusedIndex(index);
    if (node.isDir) {
      setExpandedPaths((prev) => {
        if (prev.has(node.fullPath)) {
          const next = new Set(prev);
          next.delete(node.fullPath);
          return next;
        }
        return new Set(prev).add(node.fullPath);
      });
    } else {
      onOpenFile(node.fullPath, node.name);
    }
  }, [onOpenFile]);

  const handleRowKeyDown = useCallback((event: React.KeyboardEvent<HTMLDivElement>, node: FileNode, index: number) => {
    if (event.target !== event.currentTarget) return;
    const list = rowsRef.current;
    const row = list[index];
    const depth = row && row.kind === "node" ? row.depth : 0;
    if (event.key === "Enter" || event.key === " ") {
      event.preventDefault();
      handleActivateRow(node, index);
    } else if (event.key === "ArrowDown" || event.key === "ArrowUp") {
      event.preventDefault();
      const delta = event.key === "ArrowDown" ? 1 : -1;
      let next = index + delta;
      while (next >= 0 && next < list.length && list[next].kind !== "node") next += delta;
      if (next >= 0 && next < list.length) goToRow(next);
    } else if (event.key === "Home") {
      event.preventDefault();
      const first = list.findIndex((r) => r.kind === "node");
      if (first >= 0) goToRow(first);
    } else if (event.key === "End") {
      event.preventDefault();
      for (let i = list.length - 1; i >= 0; i -= 1) {
        if (list[i].kind === "node") {
          goToRow(i);
          break;
        }
      }
    } else if (event.key === "ArrowRight") {
      if (!node.isDir) return;
      event.preventDefault();
      if (!expandedPathsRef.current.has(node.fullPath)) {
        handleToggleExpanded(node.fullPath, true);
      } else if (index + 1 < list.length) {
        // Flat order guarantees the first child (or its empty placeholder)
        // follows its parent.
        goToRow(index + 1);
      }
    } else if (event.key === "ArrowLeft") {
      event.preventDefault();
      if (node.isDir && expandedPathsRef.current.has(node.fullPath)) {
        handleToggleExpanded(node.fullPath, false);
      } else {
        // The parent row always precedes its children in flat order.
        for (let i = index - 1; i >= 0; i -= 1) {
          const candidate = list[i];
          if (candidate.kind === "node" && candidate.depth === depth - 1) {
            goToRow(i);
            break;
          }
        }
      }
    }
  }, [goToRow, handleActivateRow, handleToggleExpanded]);

  const handleRowContextMenu = useCallback((target: ExplorerMenuTarget, event: React.MouseEvent) => {
    setContextMenu({ x: event.clientX, y: event.clientY, target });
  }, []);

  // Stable identity: the portal rebinds its outside-press listeners whenever
  // onClose changes, and the tree re-renders on every scroll tick.
  const closeContextMenu = useCallback(() => setContextMenu(null), []);

  const handleCreatedEntry = useCallback((path: string, kind: "file" | "dir") => {
    setCreateDialog(null);
    setContextMenu(null);
    // Drop the cached listing that would hide the new entry, then re-read the
    // root and every expanded directory. A collapsed parent is refetched the
    // next time it is expanded.
    setChildrenByPath((prev) => {
      const next = new Map(prev);
      next.delete(getFileDirectory(path));
      next.delete(path);
      return next;
    });
    setExpandedPaths((prev) => new Set(prev).add(kind === "dir" ? path : getFileDirectory(path)));
    setTreeRefreshKey((key) => key + 1);
    if (kind === "file") onOpenFile(path, getFileName(path), "edit");
  }, [onOpenFile]);

  // Re-read the affected directories after a path mutation and remap expanded
  // keys (a moved folder keeps its subtree open). Copies never notify tabs:
  // the source file itself did not move.
  const applyPathChange = useCallback((
    oldPath: string,
    newPath: string,
    isDir: boolean,
    action: "rename" | "move" | "copy",
  ) => {
    setChildrenByPath((prev) => {
      const next = new Map(prev);
      next.delete(getFileDirectory(oldPath));
      next.delete(getFileDirectory(newPath));
      if (action !== "copy") {
        for (const key of next.keys()) {
          if (isPathEqualOrInside(key, oldPath)) next.delete(key);
        }
      }
      return next;
    });
    if (action !== "copy" && isDir) {
      setExpandedPaths((prev) => {
        let changed = false;
        const next = new Set<string>();
        for (const path of prev) {
          const mapped = rebasePath(path, oldPath, newPath, true);
          if (mapped !== path) changed = true;
          next.add(mapped);
        }
        return changed ? next : prev;
      });
    }
    setHighlightedPaths(new Set([newPath]));
    setTreeRefreshKey((key) => key + 1);
    if (action !== "copy") onPathRenamed?.(oldPath, newPath, isDir);
  }, [onPathRenamed]);

  const runPasteQueue = useCallback(async (plan: PastePlan) => {
    let index = plan.index;
    while (index < plan.items.length) {
      const item = plan.items[index];
      const destination = joinFilePath(plan.destination, item.name);
      if (plan.action === "move"
        && normalizeFilePathSlashes(destination) === normalizeFilePathSlashes(item.path)) {
        index += 1;
        continue;
      }
      const result = await patchFilePath(item.path, plan.action, destination, false, sourceSessionId);
      if (result.status === 409) {
        setPasteConflict({ plan: { ...plan, index }, index, item, destination });
        return;
      }
      if (!result.ok) {
        toast.error(t(
          plan.action === "copy" ? "fileExplorer.copyFailed" : "fileExplorer.moveFailed",
          { error: result.data.error ?? result.status },
        ));
        return;
      }
      applyPathChange(item.path, destination, item.isDir, plan.action === "copy" ? "copy" : "move");
      index += 1;
    }
    if (plan.action === "move") setClipboard(null);
  }, [applyPathChange, sourceSessionId, t]);

  const pasteInto = useCallback((directory: string) => {
    setContextMenu(null);
    if (!clipboard) return;
    const recurses = clipboard.items.some((item) => isPathEqualOrInside(directory, item.path));
    if (clipboard.action === "cut" && recurses) {
      toast.error(t("fileExplorer.cannotMoveIntoSelf"));
      return;
    }
    if (clipboard.action === "copy" && recurses && clipboard.items.some((item) => item.isDir)) {
      toast.error(t("fileExplorer.cannotCopyIntoSelf"));
      return;
    }
    void runPasteQueue({
      action: clipboard.action === "cut" ? "move" : "copy",
      items: clipboard.items,
      destination: directory,
      index: 0,
    });
  }, [clipboard, runPasteQueue, t]);

  const resolvePasteConflict = useCallback(async (resolution: "overwrite" | "rename" | "cancel") => {
    const conflict = pasteConflict;
    if (!conflict) return;
    setPasteConflict(null);
    if (resolution === "cancel") return;
    setPasteBusy(true);
    const { plan, index, item } = conflict;
    try {
      if (resolution === "overwrite") {
        const destination = joinFilePath(plan.destination, item.name);
        const result = await patchFilePath(item.path, plan.action, destination, true, sourceSessionId);
        if (!result.ok) {
          toast.error(t(
            plan.action === "copy" ? "fileExplorer.copyFailed" : "fileExplorer.moveFailed",
            { error: result.data.error ?? result.status },
          ));
          return;
        }
        applyPathChange(item.path, destination, item.isDir, plan.action === "copy" ? "copy" : "move");
        await runPasteQueue({ ...plan, index: index + 1 });
        return;
      }
      // Keep both: pick the first candidate the destination listing does not
      // already contain, and let a surprise 409 advance to the next one.
      const existing = new Set((childrenByPath.get(plan.destination) ?? []).map((node) => node.name));
      for (let attempt = 1; attempt <= 50; attempt += 1) {
        const name = duplicateCandidateName(item.name, item.isDir, attempt);
        if (existing.has(name)) continue;
        const destination = joinFilePath(plan.destination, name);
        const result = await patchFilePath(item.path, plan.action, destination, false, sourceSessionId);
        if (result.status === 409) {
          existing.add(name);
          continue;
        }
        if (!result.ok) {
          toast.error(t(
            plan.action === "copy" ? "fileExplorer.copyFailed" : "fileExplorer.moveFailed",
            { error: result.data.error ?? result.status },
          ));
          return;
        }
        applyPathChange(item.path, destination, item.isDir, plan.action === "copy" ? "copy" : "move");
        await runPasteQueue({ ...plan, index: index + 1 });
        return;
      }
      toast.error(t("fileExplorer.duplicateFailed"));
    } finally {
      setPasteBusy(false);
    }
  }, [applyPathChange, childrenByPath, pasteConflict, runPasteQueue, sourceSessionId, t]);

  const rememberNode = useCallback((node: FileNode, action: "copy" | "cut") => {
    setClipboard({
      action,
      items: [{ path: node.fullPath, name: node.name, isDir: node.isDir }],
    });
    setContextMenu(null);
  }, []);

  const startRename = useCallback((node: FileNode) => {
    renameGuardRef.current = node.fullPath;
    setRenaming({
      path: node.fullPath,
      value: node.name,
      isDir: node.isDir,
      originalName: node.name,
    });
    setContextMenu(null);
  }, []);

  const cancelRename = useCallback(() => {
    renameGuardRef.current = null;
    setRenaming(null);
  }, []);

  const updateRenameValue = useCallback((value: string) => {
    setRenaming((prev) => prev ? { ...prev, value } : prev);
  }, []);

  const commitRename = useCallback(async () => {
    const current = renaming;
    if (!current || renameGuardRef.current !== current.path) return;
    // Guard both Enter and the following blur from issuing two PATCHes.
    renameGuardRef.current = null;
    setRenaming(null);
    const trimmed = current.value.trim();
    if (!trimmed || trimmed === current.originalName) return;
    if (trimmed === "." || trimmed === ".." || /[\\/\0]/.test(trimmed)) {
      toast.error(t("fileExplorer.invalidName"));
      return;
    }
    const destination = joinFilePath(getFileDirectory(current.path), trimmed);
    const result = await patchFilePath(current.path, "rename", destination, false, sourceSessionId);
    if (!result.ok) {
      toast.error(t("fileExplorer.renameFailed", { error: result.data.error ?? result.status }));
      return;
    }
    applyPathChange(current.path, destination, current.isDir, "rename");
  }, [applyPathChange, renaming, sourceSessionId, t]);

  const rememberDeleteTarget = useCallback((target: ExplorerMenuTarget) => {
    setContextMenu(null);
    setDeleteTarget(target);
  }, []);

  const confirmDelete = useCallback(async () => {
    if (!deleteTarget || deleting) return;
    setDeleting(true);
    const result = await deleteFilePath(deleteTarget.path, sourceSessionId);
    setDeleting(false);
    if (!result.ok) {
      toast.error(t("fileExplorer.deleteFailed", {
        name: deleteTarget.name,
        error: result.data.error ?? result.status,
      }));
      return;
    }
    const deletedPath = deleteTarget.path;
    const deletedName = deleteTarget.name;
    setDeleteTarget(null);
    setChildrenByPath((prev) => {
      const next = new Map(prev);
      next.delete(getFileDirectory(deletedPath));
      for (const key of next.keys()) {
        if (isPathEqualOrInside(key, deletedPath)) next.delete(key);
      }
      return next;
    });
    setExpandedPaths((prev) => {
      let changed = false;
      const next = new Set<string>();
      for (const path of prev) {
        if (isPathEqualOrInside(path, deletedPath)) changed = true;
        else next.add(path);
      }
      return changed ? next : prev;
    });
    setHighlightedPaths((prev) => {
      if (![...prev].some((path) => isPathEqualOrInside(path, deletedPath))) return prev;
      return new Set([...prev].filter((path) => !isPathEqualOrInside(path, deletedPath)));
    });
    setTreeRefreshKey((key) => key + 1);
    onPathsDeleted?.([deletedPath]);
    toast.success(t("fileExplorer.deleted", { name: deletedName }));
  }, [deleteTarget, deleting, onPathsDeleted, sourceSessionId, t]);

  const duplicateNode = useCallback(async (node: FileNode) => {
    setContextMenu(null);
    const directory = getFileDirectory(node.fullPath);
    const existing = new Set((childrenByPath.get(directory) ?? []).map((entry) => entry.name));
    for (let attempt = 1; attempt <= 50; attempt += 1) {
      const candidate = duplicateCandidateName(node.name, node.isDir, attempt);
      if (existing.has(candidate)) continue;
      const destination = joinFilePath(directory, candidate);
      const result = await patchFilePath(node.fullPath, "copy", destination, false, sourceSessionId);
      if (result.status === 409) {
        existing.add(candidate);
        continue;
      }
      if (!result.ok) {
        toast.error(t("fileExplorer.copyFailed", { error: result.data.error ?? result.status }));
        return;
      }
      applyPathChange(node.fullPath, destination, node.isDir, "copy");
      return;
    }
    toast.error(t("fileExplorer.duplicateFailed"));
  }, [applyPathChange, childrenByPath, sourceSessionId, t]);

  const downloadZip = useCallback((node: FileNode) => {
    const params = new URLSearchParams({
      type: "download-zip",
      includeIgnored: includeIgnored ? "1" : "0",
    });
    if (sourceSessionId) params.set("sourceSessionId", sourceSessionId);
    const link = document.createElement("a");
    link.href = apiUrl(`/api/files/${encodeFilePathForApi(node.fullPath)}?${params.toString()}`);
    link.download = `${node.name}.zip`;
    document.body.appendChild(link);
    link.click();
    link.remove();
  }, [includeIgnored, sourceSessionId]);

  const copyNodePath = useCallback((path: string, kind: "relative" | "absolute") => {
    setContextMenu(null);
    let relative = getRelativeFilePath(path, cwd);
    if (relative === path && normalizeFilePathSlashes(path) === normalizeFilePathSlashes(cwd)) {
      relative = ".";
    }
    const text = kind === "relative" ? relative : path;
    copyText(text).then(
      () => toast.success(t(kind === "relative" ? "fileExplorer.copiedRelativePath" : "fileExplorer.copiedAbsolutePath")),
      () => toast.error(t("fileExplorer.copyPathFailed")),
    );
  }, [cwd, t]);

  const toggleIncludeIgnored = useCallback((next: boolean) => {
    setIncludeIgnored(next);
    storePreference(INCLUDE_IGNORED_KEY, next ? "1" : "0");
    // The flag participates in the list request, so every cached listing must
    // be refetched rather than re-filtered. Let a new request through even if
    // the previous listing for the same directory is still in flight.
    listingGenerationRef.current += 1;
    loadingPathsRef.current = new Set();
    setLoadingPaths(new Set());
    setChildrenByPath(new Map());
    setLoading(true);
    setError(null);
    setTreeRefreshKey((key) => key + 1);
    setContextMenu(null);
  }, []);

  const changeSortMode = useCallback((next: ExplorerSortMode) => {
    setSortMode(next);
    storePreference(SORT_MODE_KEY, next);
    setContextMenu(null);
  }, []);

  const handleTreeScroll = useCallback(() => {
    const el = scrollRef.current;
    if (!el) return;
    setScrollTop(el.scrollTop);
    setViewportHeight(el.clientHeight);
  }, []);

  // Track the viewport height so the window math stays correct across panel
  // resizes; rows themselves are fixed-height and never measured.
  useEffect(() => {
    const el = scrollRef.current;
    if (!el) return;
    setViewportHeight(el.clientHeight);
    if (typeof ResizeObserver === "undefined") return;
    const observer = new ResizeObserver(() => {
      if (scrollRef.current) setViewportHeight(scrollRef.current.clientHeight);
    });
    observer.observe(el);
    return () => observer.disconnect();
  }, []);

  // Keep keyboard focus on a real row when collapsing shrinks the list.
  useEffect(() => {
    setFocusedIndex((prev) => Math.min(prev, Math.max(0, rowsRef.current.length - 1)));
  }, [rows.length]);

  const applyUploadResult = useCallback((data: UploadResponse, targetDirectory: string) => {
    const uploaded = data.uploaded ?? [];
    const skipped = data.skipped ?? [];
    const errors = data.errors ?? [];
    setUploadSummary({ uploaded, skipped, errors, targetDirectory });

    if (uploaded.length > 0) {
      // Uploaded names are relative to the target (folders keep `sub/file`).
      setHighlightedPaths(new Set(uploaded.map((name) => joinFilePath(targetDirectory, name))));
      setChildrenByPath((prev) => {
        const next = new Map(prev);
        next.delete(targetDirectory);
        for (const name of uploaded) {
          next.delete(getFileDirectory(joinFilePath(targetDirectory, name)));
        }
        return next;
      });
      setTreeRefreshKey((key) => key + 1);
    }
  }, []);

  const performUpload = useCallback(async (
    items: UploadItem[],
    targetDirectory: string,
    strategy: UploadConflictStrategy,
  ) => {
    setPendingConflict(null);
    setUploadError(null);
    setUploadProgress(0);
    setUploadPhase("uploading");

    try {
      const { status, data } = await uploadFiles(targetDirectory, items, strategy, setUploadProgress);
      if (status === 409 && data.conflicts?.length) {
        setPendingConflict({
          items,
          targetDirectory,
          conflicts: data.conflicts,
          nonReplaceable: data.nonReplaceable ?? [],
        });
        return;
      }
      if (status < 200 || status >= 300) {
        throw new Error(data.error ?? translate("fileExplorer.uploadFailed", { status }));
      }
      setUploadProgress(100);
      applyUploadResult(data, targetDirectory);
    } catch (uploadFailure) {
      setUploadError(uploadFailure instanceof Error ? uploadFailure.message : String(uploadFailure));
    } finally {
      setUploadPhase("idle");
    }
  }, [applyUploadResult]);

  const prepareUpload = useCallback(async (items: UploadItem[], targetDirectory: string) => {
    if (items.length === 0 || uploadBusy) return;
    setUploadSummary(null);
    setHighlightedPaths(new Set());
    setPendingConflict(null);
    setUploadError(null);
    setUploadProgress(0);
    setUploadPhase("checking");

    try {
      const res = await fetch(
        `/api/files/${encodeFilePathForApi(targetDirectory)}?type=upload-check`,
        {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ files: items.map((item) => item.relativePath) }),
        },
      );
      const data = await res.json().catch(() => ({})) as UploadResponse;
      if (!res.ok) throw new Error(data.error ?? translate("fileExplorer.uploadCheckFailed", { status: res.status }));

      if (data.conflicts?.length) {
        setPendingConflict({
          items,
          targetDirectory,
          conflicts: data.conflicts,
          nonReplaceable: data.nonReplaceable ?? [],
        });
        return;
      }

      await performUpload(items, targetDirectory, "error");
    } catch (uploadFailure) {
      setUploadError(uploadFailure instanceof Error ? uploadFailure.message : String(uploadFailure));
    } finally {
      setUploadPhase("idle");
    }
  }, [performUpload, uploadBusy]);

  const handleUploadInput = useCallback((event: React.ChangeEvent<HTMLInputElement>) => {
    const targetDirectory = uploadTargetRef.current || cwd;
    const items = Array.from(event.target.files ?? []).map((file) => ({
      file,
      // Folder pickers populate webkitRelativePath; plain pickers leave it "".
      relativePath: file.webkitRelativePath || file.name,
    }));
    event.target.value = "";
    void prepareUpload(items, targetDirectory);
  }, [cwd, prepareUpload]);

  const openUploadForDirectory = useCallback((directory: string, folder: boolean) => {
    setContextMenu(null);
    if (uploadBusy) return;
    uploadTargetRef.current = directory;
    if (folder) uploadFolderInputRef.current?.click();
    else uploadInputRef.current?.click();
  }, [uploadBusy]);

  useImperativeHandle(ref, () => ({
    openUploadPicker() {
      if (uploadBusy) return;
      uploadTargetRef.current = cwd;
      uploadInputRef.current?.click();
    },
    openFolderUploadPicker() {
      if (uploadBusy) return;
      uploadTargetRef.current = cwd;
      uploadFolderInputRef.current?.click();
    },
    collapseAll() {
      setExpandedPaths(new Set());
    },
  }), [cwd, uploadBusy]);

  useEffect(() => {
    onUploadBusyChange?.(uploadBusy);
  }, [onUploadBusyChange, uploadBusy]);

  useEffect(() => () => onUploadBusyChange?.(false), [onUploadBusyChange]);

  const clearAutoExpand = useCallback(() => {
    if (autoExpandTimerRef.current !== null) {
      window.clearTimeout(autoExpandTimerRef.current);
      autoExpandTimerRef.current = null;
    }
    autoExpandPathRef.current = null;
  }, []);

  useEffect(() => () => clearAutoExpand(), [clearAutoExpand]);

  // The hovered row decides the drop target: a folder row is its own target,
  // a file row falls back to its parent, and blank space is the workspace root.
  const resolveDropTarget = useCallback((target: EventTarget | null) => {
    const element = target instanceof Element ? target : null;
    const rowElement = element?.closest<HTMLElement>("[data-file-path]") ?? null;
    const path = rowElement?.dataset.filePath;
    if (!path) return { directory: cwd, highlight: null };
    const isDir = rowElement.dataset.fileIsDir === "1";
    return {
      directory: isDir ? path : getFileDirectory(path),
      highlight: isDir ? path : null,
    };
  }, [cwd]);

  const handleNodeDragStart = useCallback((node: FileNode, event: React.DragEvent<HTMLDivElement>) => {
    event.dataTransfer.effectAllowed = "move";
    event.dataTransfer.setData(TREE_DRAG_TYPE, JSON.stringify({
      paths: [node.fullPath],
      isDir: node.isDir,
    }));
    event.dataTransfer.setData("text/plain", node.fullPath);
  }, []);

  const handleNodeDragEnd = useCallback(() => {
    setDropTargetPath(null);
    clearAutoExpand();
  }, [clearAutoExpand]);

  const handleTreeDragOver = useCallback((event: React.DragEvent<HTMLDivElement>) => {
    const types = Array.from(event.dataTransfer.types);
    const internal = types.includes(TREE_DRAG_TYPE);
    const external = types.includes("Files");
    if (!internal && !external) return;
    event.preventDefault();
    event.dataTransfer.dropEffect = internal ? "move" : "copy";
    const target = resolveDropTarget(event.target);
    setDropTargetPath(target.highlight);
    if (internal && target.highlight && !expandedPathsRef.current.has(target.highlight)) {
      if (autoExpandPathRef.current !== target.highlight) {
        clearAutoExpand();
        autoExpandPathRef.current = target.highlight;
        autoExpandTimerRef.current = window.setTimeout(() => {
          autoExpandTimerRef.current = null;
          const path = autoExpandPathRef.current;
          autoExpandPathRef.current = null;
          if (path) handleToggleExpanded(path, true);
        }, 500);
      }
    } else {
      clearAutoExpand();
    }
  }, [clearAutoExpand, handleToggleExpanded, resolveDropTarget]);

  const handleTreeDragLeave = useCallback((event: React.DragEvent<HTMLDivElement>) => {
    const related = event.relatedTarget;
    if (related instanceof Node && event.currentTarget.contains(related)) return;
    setDropTargetPath(null);
    clearAutoExpand();
  }, [clearAutoExpand]);

  const handleTreeDrop = useCallback((event: React.DragEvent<HTMLDivElement>) => {
    event.preventDefault();
    const target = resolveDropTarget(event.target);
    setDropTargetPath(null);
    clearAutoExpand();
    const types = Array.from(event.dataTransfer.types);

    if (types.includes(TREE_DRAG_TYPE)) {
      let payload: { paths?: string[]; isDir?: boolean } | null = null;
      try {
        payload = JSON.parse(event.dataTransfer.getData(TREE_DRAG_TYPE)) as { paths?: string[]; isDir?: boolean };
      } catch {
        payload = null;
      }
      const paths = (payload?.paths ?? []).filter(Boolean);
      if (paths.length === 0) return;
      // Moving a folder into itself (or a descendant) would detach the tree.
      if (paths.some((path) => isPathEqualOrInside(target.directory, path))) {
        toast.error(t("fileExplorer.cannotMoveIntoSelf"));
        return;
      }
      const isDir = payload?.isDir === true;
      void runPasteQueue({
        action: "move",
        items: paths.map((path) => ({ path, name: getFileName(path), isDir })),
        destination: target.directory,
        index: 0,
      });
      return;
    }

    if (types.includes("Files")) {
      void collectDroppedFiles(event.dataTransfer)
        .then((files) => {
          if (files.length > 0) void prepareUpload(files, target.directory);
        })
        .catch((failure) => {
          setUploadError(failure instanceof Error ? failure.message : String(failure));
        });
    }
  }, [clearAutoExpand, prepareUpload, resolveDropTarget, runPasteQueue, t]);

  // F2 / Delete / Ctrl(Cmd)+C/X/V act on the focused row, and only while the
  // explorer is the visible panel: the file viewers keep their own handlers.
  useEffect(() => {
    if (!active) return;
    const handleKeyDown = (event: KeyboardEvent) => {
      const target = event.target;
      if (target instanceof Element && target.closest("input, textarea, select, [contenteditable='true']")) return;
      if (!scrollRef.current?.contains(document.activeElement)) return;
      const row = rowsRef.current[focusedIndexRef.current];
      const node = row?.kind === "node" ? row.node : null;
      const modifier = event.ctrlKey || event.metaKey;

      if (modifier && !event.altKey && !event.shiftKey) {
        const key = event.key.toLowerCase();
        if (key === "v") {
          event.preventDefault();
          pasteInto(node ? (node.isDir ? node.fullPath : getFileDirectory(node.fullPath)) : cwd);
          return;
        }
        if (!node) return;
        if (key === "c") {
          event.preventDefault();
          rememberNode(node, "copy");
          return;
        }
        if (key === "x") {
          event.preventDefault();
          rememberNode(node, "cut");
          return;
        }
      }

      if (!node) return;
      if (event.key === "F2") {
        event.preventDefault();
        startRename(node);
      } else if (event.key === "Delete") {
        event.preventDefault();
        rememberDeleteTarget({
          kind: node.isDir ? "dir" : "file",
          path: node.fullPath,
          name: node.name,
          directory: node.isDir ? node.fullPath : getFileDirectory(node.fullPath),
        });
      }
    };
    window.addEventListener("keydown", handleKeyDown);
    return () => window.removeEventListener("keydown", handleKeyDown);
  }, [active, cwd, pasteInto, rememberDeleteTarget, rememberNode, startRename]);

  // Keep the refresh-done callback in a ref so its identity cannot re-trigger
  // the fetch effect below (AppShell re-renders on every session boundary).
  const onRefreshDoneRef = useRef(onRefreshDone);
  onRefreshDoneRef.current = onRefreshDone;

  useEffect(() => {
    const cwdChanged = prevCwdRef.current !== cwd;
    prevCwdRef.current = cwd;

    // Reset expanded state only when cwd changes, not on refreshKey bumps
    if (cwdChanged) {
      setExpandedPaths(new Set());
      setHighlightedPaths(new Set());
      setUploadSummary(null);
      setPendingConflict(null);
      setUploadError(null);
      setChildrenByPath(new Map());
      loadingPathsRef.current = new Set();
      setLoadingPaths(new Set());
      setFocusedIndex(0);
      setScrollTop(0);
      setRenaming(null);
      renameGuardRef.current = null;
      setDeleteTarget(null);
      setPasteConflict(null);
      setClipboard(null);
      setDropTargetPath(null);
      clearAutoExpand();
    }

    setLoading(cwdChanged);
    setError(null);
    // Refresh re-reads the root plus every expanded directory so renames and
    // deletions surface; the expand effect below covers newly opened ones.
    // expandedPaths is read via ref: depending on the state would re-fire
    // this effect on every expand and refetch the world each time.
    // Settle the root request explicitly: only cwd fetches drive the
    // full-list loading state and the toolbar spinner's done signal.
    const requestId = ++rootRequestRef.current;
    void fetchDir(cwd).finally(() => {
      if (rootRequestRef.current !== requestId) return;
      setLoading(false);
      onRefreshDoneRef.current?.();
    });
    if (!cwdChanged) {
      for (const path of expandedPathsRef.current) fetchDir(path);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [cwd, refreshKey, treeRefreshKey]);

  // Fetch any expanded directory that has no listing yet. Clicks, keyboard,
  // and reveal all funnel through expandedPaths, so this single effect covers
  // every expansion path — including levels that mount while a reveal
  // ancestor chain is still loading.
  useEffect(() => {
    for (const path of expandedPaths) {
      if (!childrenByPath.has(path)) fetchDir(path);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [expandedPaths, childrenByPath, cwd]);

  const [isGitRepo, setIsGitRepo] = useState(false);
  useEffect(() => {
    let cancelled = false;
    fetchGitStatus(cwd)
      .then((status) => {
        if (cancelled) return;
        setGitFiles(status.isGitRepository ? status.files : []);
        setIsGitRepo(status.isGitRepository);
      })
      .catch(() => {
        if (cancelled) return;
        setGitFiles([]);
        setIsGitRepo(false);
      });
    return () => { cancelled = true; };
  }, [cwd, refreshKey, treeRefreshKey]);

  useEffect(() => {
    onGitStatusChange?.(gitFiles.length, isGitRepo);
  }, [gitFiles, isGitRepo, onGitStatusChange]);

  // One-shot reveal from the file panel: expand every ancestor directory of
  // the target, highlight the row, and scroll the virtual window to it. The
  // effect re-runs as ancestor listings resolve (rows identity changes), so
  // deep chains settle level by level; it gives up once every ancestor is
  // loaded but the target still isn't listed.
  useEffect(() => {
    if (!revealPath) return;
    const normalizedCwd = normalizeFilePathSlashes(cwd).replace(/\/$/, "");
    const normalizedTarget = normalizeFilePathSlashes(revealPath);
    if (normalizedTarget !== normalizedCwd && !normalizedTarget.startsWith(`${normalizedCwd}/`)) {
      onRevealDone?.();
      return;
    }
    const relative = normalizedTarget.slice(normalizedCwd.length + 1);
    const segments = relative.split("/").filter(Boolean);
    setExpandedPaths((prev) => {
      // Return the previous set when nothing changes: a fresh identity would
      // recompute rows, refire this effect, and loop until reveal clears.
      let changed = false;
      const next = new Set(prev);
      let prefix = normalizedCwd;
      for (let i = 0; i < segments.length - 1; i += 1) {
        prefix = `${prefix}/${segments[i]}`;
        for (const spelling of [prefix, joinFilePath(cwd, segments.slice(0, i + 1).join("/"))]) {
          if (!next.has(spelling)) {
            next.add(spelling);
            changed = true;
          }
        }
      }
      return changed ? next : prev;
    });
    setHighlightedPaths((prev) => {
      if (prev.has(revealPath)) return prev;
      return new Set(prev).add(revealPath);
    });
    const targetIndex = rows.findIndex(
      (row) => row.kind === "node" && normalizeFilePathSlashes(row.node.fullPath) === normalizedTarget,
    );
    if (targetIndex >= 0) {
      goToRow(targetIndex);
      onRevealDone?.();
      return;
    }
    const ancestorsLoaded = segments.slice(0, -1).every((_, level) => {
      const ancestor = joinFilePath(cwd, segments.slice(0, level + 1).join("/"));
      return childrenByPath.has(ancestor)
        || childrenByPath.has(`${normalizedCwd}/${segments.slice(0, level + 1).join("/")}`);
    });
    if (ancestorsLoaded) onRevealDone?.();
  }, [cwd, revealPath, onRevealDone, rows, childrenByPath, goToRow]);

  const showUploadFeedback = uploadBusy || pendingConflict !== null || uploadError !== null || uploadSummary !== null;
  // Renaming/deleting the workspace root would invalidate the explorer itself;
  // the empty-area menu still offers creation, upload, paste, and ZIP export.
  const contextTargetIsRoot = contextMenu !== null
    && contextMenu.target.kind === "dir"
    && normalizeFilePathSlashes(contextMenu.target.path) === normalizeFilePathSlashes(cwd);

  const addUploadedFilesToChat = useCallback(() => {
    if (!uploadSummary || uploadSummary.uploaded.length === 0) return;
    const { targetDirectory } = uploadSummary;
    onAtMentions?.(
      uploadSummary.uploaded.map((name) => getRelativeFilePath(joinFilePath(targetDirectory, name), cwd)),
    );
  }, [cwd, onAtMentions, uploadSummary]);

  // The tree shell always mounts (role=tree is a structural contract); only
  // the inner content swaps between state messages and the virtual window.
  // The window itself mounts ~60 rows no matter how far the user scrolls.
  const treeRows = (
    <div style={{ height: totalListHeight, position: "relative" }}>
        {rows.slice(windowStart, windowEnd).map((row, offset) => {
          const index = windowStart + offset;
          if (row.kind !== "node") {
            return (
              <div
                key={`empty:${row.key}`}
                style={{ position: "absolute", top: index * rowHeight, left: 0, right: 0, height: rowHeight }}
              >
                <ExplorerRow
                  row={row}
                  index={index}
                  rowHeight={rowHeight}
                  rowCount={rows.length}
                  cwd={cwd}
                  open={false}
                  loading={false}
                  highlighted={false}
                  isActiveFile={false}
                  focused={false}
                  cut={false}
                  dropTarget={dropTargetPath === row.key}
                  renaming={false}
                  renameValue=""
                  gitStatusByPath={gitStatusByPath}
                  changedDirectoryPaths={changedDirectoryPaths}
                  onAtMention={onAtMention}
                  onActivate={handleActivateRow}
                  onContextMenu={handleRowContextMenu}
                  onKeyDown={handleRowKeyDown}
                  onFocusRow={setFocusedIndex}
                  onRenameChange={updateRenameValue}
                  onRenameCommit={commitRename}
                  onRenameCancel={cancelRename}
                  onDragStartNode={handleNodeDragStart}
                  onDragEndNode={handleNodeDragEnd}
                />
              </div>
            );
          }
          const { node } = row;
          return (
            <div
              key={node.fullPath}
              style={{ position: "absolute", top: index * rowHeight, left: 0, right: 0, height: rowHeight }}
            >
              <ExplorerRow
                row={row}
                index={index}
                rowHeight={rowHeight}
                rowCount={rows.length}
                cwd={cwd}
                open={node.isDir && expandedPaths.has(node.fullPath)}
                loading={loadingPaths.has(node.fullPath)}
                highlighted={highlightedPaths.has(node.fullPath)}
                isActiveFile={!node.isDir && normalizedActiveFilePath === normalizeFilePathSlashes(node.fullPath)}
                focused={index === focusedIndex}
                cut={clipboard?.action === "cut" && clipboard.items.some((item) => item.path === node.fullPath)}
                dropTarget={dropTargetPath === node.fullPath}
                renaming={renaming?.path === node.fullPath}
                renameValue={renaming?.value ?? ""}
                gitStatusByPath={gitStatusByPath}
                changedDirectoryPaths={changedDirectoryPaths}
                onAtMention={onAtMention}
                onActivate={handleActivateRow}
                onContextMenu={handleRowContextMenu}
                onKeyDown={handleRowKeyDown}
                onFocusRow={setFocusedIndex}
                onRenameChange={updateRenameValue}
                onRenameCommit={commitRename}
                onRenameCancel={cancelRename}
                onDragStartNode={handleNodeDragStart}
                onDragEndNode={handleNodeDragEnd}
              />
            </div>
          );
        })}
      </div>
  );
  return (
    <div style={{ height: "100%", display: "flex", flexDirection: "column", minHeight: 0 }}>
      <input ref={uploadInputRef} type="file" multiple hidden onChange={handleUploadInput} />
      <input
        ref={uploadFolderInputRef}
        type="file"
        multiple
        hidden
        onChange={handleUploadInput}
        {...({ webkitdirectory: "true", directory: "true" } as Record<string, string>)}
      />
      {/* Pinned: the result list scrolls, so an un-sticky box leaves you
          unable to edit the query that produced it. */}
      {fileSearchOpen && (
        <div style={{
          position: "sticky",
          top: 0,
          zIndex: 1,
          background: "var(--bg-panel)",
          padding: "6px 8px 4px",
        }}>
          <input
            className="file-explorer-search-input"
            ref={searchInputRef}
            value={searchQuery}
            onChange={(e) => {
              // Arm the loading state in the same batch as the query: the
              // debounce effect only runs after paint, so the first keystroke
              // would otherwise show "No matching files" for a frame.
              setSearchQuery(e.target.value);
              setSearchLoading(true);
            }}
            onKeyDown={(e) => {
              if (e.key === "Escape") {
                e.preventDefault();
                onFileSearchOpenChange?.(false);
              }
            }}
            placeholder={t("fileExplorer.searchPlaceholder")}
            aria-label={t("fileExplorer.searchFiles")}
            style={{
              width: "100%",
              height: 27,
              boxSizing: "border-box",
              padding: searchQuery ? "0 26px 0 9px" : "0 9px",
              background: "var(--bg)",
              border: "1px solid var(--border)",
              borderRadius: "var(--radius-control)",
              outline: "none",
              color: "var(--text)",
              fontSize: 12,
            }}
            onFocus={(e) => { e.currentTarget.style.borderColor = "var(--accent)"; }}
            onBlur={(e) => { e.currentTarget.style.borderColor = "var(--border)"; }}
          />
          {searchQuery && (
            <button
              className="file-explorer-search-clear"
              type="button"
              onClick={() => {
                setSearchQuery("");
                searchInputRef.current?.focus();
              }}
              title={t("fileExplorer.clearSearch")}
              aria-label={t("fileExplorer.clearSearch")}
              style={{
                position: "absolute",
                right: 12,
                top: "50%",
                transform: "translateY(calc(-50% + 1px))",
                display: "flex",
                alignItems: "center",
                justifyContent: "center",
                width: 18,
                height: 18,
                padding: 0,
                border: "none",
                borderRadius: "var(--radius-control)",
                background: "none",
                color: "var(--text-dim)",
                cursor: "pointer",
                transition: `color var(--dur-fast) var(--ease-out-warm), background var(--dur-fast) var(--ease-out-warm)`,
              }}
              onMouseEnter={(e) => { e.currentTarget.style.background = "var(--bg-hover)"; e.currentTarget.style.color = "var(--text)"; }}
              onMouseLeave={(e) => { e.currentTarget.style.background = "none"; e.currentTarget.style.color = "var(--text-dim)"; }}
            >
              <X size={11} strokeWidth={2.4} aria-hidden="true" />
            </button>
          )}
        </div>
      )}
      {showUploadFeedback && (
        <div style={{ padding: "6px 8px", borderBottom: "1px solid var(--border)" }}>
        {uploadBusy && (
          <div role="status" aria-live="polite" aria-label={uploadPhase === "checking" ? t("fileExplorer.checkingFiles") : t("fileExplorer.uploadingPercent", { percent: uploadProgress })}>
            <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", gap: 8, minHeight: 14, color: "var(--text-muted)" }}>
              {uploadPhase === "checking" ? (
                <Loader2 size={13} strokeWidth={2.2} style={{ animation: "spin 0.8s linear infinite" }} aria-hidden="true" />
              ) : (
                <Upload size={13} strokeWidth={2} aria-hidden="true" />
              )}
              {uploadPhase === "uploading" && <span style={{ fontSize: 10 }}>{uploadProgress}%</span>}
            </div>
            {uploadPhase === "uploading" && (
              <div style={{ height: 3, marginTop: 4, overflow: "hidden", borderRadius: 2, background: "var(--border)" }}>
                <div style={{ width: `${uploadProgress}%`, height: "100%", background: "var(--accent)", transition: `width var(--dur-fast) var(--ease-out-warm)` }} />
              </div>
            )}
          </div>
        )}

        {pendingConflict && (
          <div role="alert" style={{ padding: 7, border: "1px solid color-mix(in srgb, var(--status-warning) 55%, var(--border))", borderRadius: 4, background: "color-mix(in srgb, var(--status-warning) 9%, var(--bg-panel))" }}>
            <div style={{ fontSize: 11, color: "var(--text)", lineHeight: 1.35, overflowWrap: "anywhere" }}>
              {tn("fileExplorer.filesAlreadyExist", pendingConflict.conflicts.length, { files: pendingConflict.conflicts.join(", ") })}
            </div>
            {pendingConflict.nonReplaceable.length > 0 && (
              <div style={{ marginTop: 3, fontSize: 10, color: "var(--status-warning)", lineHeight: 1.35, overflowWrap: "anywhere" }}>
                {t("fileExplorer.cannotReplace", { files: pendingConflict.nonReplaceable.join(", ") })}
              </div>
            )}
            <div style={{ display: "flex", gap: 5, marginTop: 7 }}>
              <button type="button" onClick={() => void performUpload(pendingConflict.items, pendingConflict.targetDirectory, "overwrite")} style={{ height: 24, minHeight: 24, padding: "0 8px", border: "1px solid var(--status-error)", borderRadius: "var(--radius-control)", background: "transparent", color: "var(--status-error)", cursor: "pointer", fontSize: 11 }}>
                {t("fileExplorer.replace")}
              </button>
              <button type="button" onClick={() => void performUpload(pendingConflict.items, pendingConflict.targetDirectory, "rename")} style={{ height: 24, minHeight: 24, padding: "0 8px", border: "1px solid var(--accent)", borderRadius: "var(--radius-control)", background: "transparent", color: "var(--accent)", cursor: "pointer", fontSize: 11 }}>
                {t("fileExplorer.keepBoth")}
              </button>
              <button type="button" onClick={() => void performUpload(pendingConflict.items, pendingConflict.targetDirectory, "skip")} style={{ height: 24, minHeight: 24, padding: "0 8px", border: "1px solid var(--border)", borderRadius: "var(--radius-control)", background: "var(--bg-panel)", color: "var(--text)", cursor: "pointer", fontSize: 11 }}>
                {t("fileExplorer.skipExisting")}
              </button>
              <button type="button" onClick={() => setPendingConflict(null)} style={{ height: 24, minHeight: 24, padding: "0 8px", border: "none", borderRadius: "var(--radius-control)", background: "transparent", color: "var(--text-muted)", cursor: "pointer", fontSize: 11 }}>
                {t("fileExplorer.cancel")}
              </button>
            </div>
          </div>
        )}

        {uploadError && (
          <div role="alert" style={{ display: "flex", alignItems: "flex-start", gap: 6, fontSize: 11, lineHeight: 1.35, color: "var(--status-error)" }}>
            <span style={{ minWidth: 0, flex: 1, overflowWrap: "anywhere" }}>{uploadError}</span>
            <DismissButton onClick={() => setUploadError(null)} title={t("fileExplorer.dismissError")} />
          </div>
        )}

        {uploadSummary && (
          <div aria-live="polite">
            <div style={{ display: "flex", alignItems: "center", gap: 8, minHeight: 22, fontSize: 11 }}>
              <div style={{ minWidth: 0, flex: 1, display: "flex", alignItems: "center", gap: 8 }}>
                {uploadSummary.uploaded.length > 0 && (
                  <span title={t("fileExplorer.uploadedCount", { count: uploadSummary.uploaded.length })} aria-label={t("fileExplorer.uploadedCount", { count: uploadSummary.uploaded.length })} style={{ display: "flex", alignItems: "center", gap: 3, color: "var(--status-success)" }}>
                    <Check size={13} strokeWidth={2.4} aria-hidden="true" />
                    <span>{uploadSummary.uploaded.length}</span>
                  </span>
                )}
                {uploadSummary.skipped.length > 0 && (
                  <span title={t("fileExplorer.skippedCount", { count: uploadSummary.skipped.length })} aria-label={t("fileExplorer.skippedCount", { count: uploadSummary.skipped.length })} style={{ display: "flex", alignItems: "center", gap: 3, color: "var(--text-dim)" }}>
                    <CircleMinus size={13} strokeWidth={2} aria-hidden="true" />
                    <span>{uploadSummary.skipped.length}</span>
                  </span>
                )}
                {uploadSummary.errors.length > 0 && (
                  <span title={t("fileExplorer.failedCount", { count: uploadSummary.errors.length })} aria-label={t("fileExplorer.failedCount", { count: uploadSummary.errors.length })} style={{ display: "flex", alignItems: "center", gap: 3, color: "var(--status-error)" }}>
                    <TriangleAlert size={13} strokeWidth={2} aria-hidden="true" />
                    <span>{uploadSummary.errors.length}</span>
                  </span>
                )}
              </div>
              {uploadSummary.uploaded.length > 0 && onAtMentions && (
                <Tooltip content={uploadSummary.uploaded.length === 1 ? t("fileExplorer.addUploadedFile") : t("fileExplorer.addAllUploadedFiles")}>
                  <button
                    type="button"
                    onClick={addUploadedFilesToChat}
                    aria-label={uploadSummary.uploaded.length === 1 ? t("fileExplorer.addUploadedFile") : t("fileExplorer.addAllUploadedFiles")}
                    style={{
                      height: 22, padding: "0 7px",
                      display: "flex", alignItems: "center", justifyContent: "center", gap: 4,
                      flexShrink: 0,
                      border: "1px solid var(--border)",
                      borderRadius: "var(--radius-control)",
                      background: "var(--bg-panel)",
                      color: "var(--accent)",
                      cursor: "pointer", fontSize: 11, fontWeight: 600, whiteSpace: "nowrap",
                      transition: `background var(--dur-fast) var(--ease-out-warm), border-color var(--dur-fast) var(--ease-out-warm)`,
                    }}
                  >
                    <AtSign size={11} strokeWidth={2.2} aria-hidden="true" />
                    {t("fileExplorer.mention")}
                  </button>
                </Tooltip>
              )}
              <DismissButton onClick={() => setUploadSummary(null)} title={t("fileExplorer.dismissUploadResults")} />
            </div>
            {uploadSummary.errors.map((item) => (
              <div key={item.name} title={item.error} style={{ display: "flex", alignItems: "center", gap: 4, marginTop: 3, minWidth: 0, fontSize: 10, color: "var(--status-error)" }}>
                <CircleAlert size={11} strokeWidth={2} style={{ flexShrink: 0 }} aria-hidden="true" />
                <span style={{ minWidth: 0, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>{item.name}</span>
              </div>
            ))}
          </div>
        )}
        </div>
      )}

      <div
        ref={scrollRef}
        role="tree"
        aria-label={t("sessionSidebar.explorer")}
        aria-busy={loading || searchLoading}
        onScroll={handleTreeScroll}
        onDragOver={handleTreeDragOver}
        onDragLeave={handleTreeDragLeave}
        onDrop={handleTreeDrop}
        onContextMenu={(event) => {
          // Rows stop propagation; anything reaching here is the empty area,
          // which stands for the workspace root.
          if (event.target !== event.currentTarget && (event.target as Element).closest("[role='treeitem']")) return;
          event.preventDefault();
          setContextMenu({
            x: event.clientX,
            y: event.clientY,
            target: { kind: "dir", path: cwd, name: getFileName(cwd), directory: cwd },
          });
        }}
        style={{ flex: 1, minHeight: 0, overflowY: "auto", overflowX: "hidden", padding: "2px 4px", outline: "none" }}
      >
        {searchActive ? (
          searchLoading ? (
            <div role="status" style={{ padding: "8px 12px", fontSize: 11, color: "var(--text-dim)" }}>{t("fileExplorer.searching")}</div>
          ) : searchFailed ? (
            <div role="alert" style={{ display: "flex", alignItems: "center", justifyContent: "space-between", gap: 8, padding: "8px 12px", fontSize: 11, color: "var(--status-error)" }}>
              <span>{t("fileExplorer.searchFailed")}</span>
              <button
                className="load-retry-button"
                type="button"
                onClick={() => setTreeRefreshKey((key) => key + 1)}
                style={{ minHeight: 32, padding: "4px 8px", border: "1px solid var(--border)", borderRadius: "var(--radius-control)", background: "var(--bg-panel)", color: "var(--text)", cursor: "pointer", fontSize: 11, fontWeight: 600 }}
              >
                {t("chatWindow.retry")}
              </button>
            </div>
          ) : rows.length === 0 ? (
            <div style={{ padding: "8px 12px", fontSize: 11, color: "var(--text-dim)" }}>{t("fileExplorer.noMatchingFiles")}</div>
          ) : (
            treeRows
          )
        ) : loading ? (
          <div role="status" aria-live="polite" style={{ padding: "8px 12px", fontSize: 11, color: "var(--text-dim)" }}>{t("fileExplorer.loadingFiles")}</div>
        ) : error ? (
          <div role="alert" style={{ display: "flex", alignItems: "center", justifyContent: "space-between", gap: 8, padding: "8px 12px", fontSize: 11, color: "var(--status-error)" }}>
            <span>{error}</span>
            <button
              className="load-retry-button"
              type="button"
              onClick={() => setTreeRefreshKey((key) => key + 1)}
              style={{ minHeight: 32, padding: "4px 8px", border: "1px solid var(--border)", borderRadius: "var(--radius-control)", background: "var(--bg-panel)", color: "var(--text)", cursor: "pointer", fontSize: 11, fontWeight: 600 }}
            >
              {t("chatWindow.retry")}
            </button>
          </div>
        ) : rows.length === 0 ? (
          <div style={{ padding: "8px 12px", fontSize: 11, color: "var(--text-dim)" }}>
            {t("fileExplorer.noFilesFound")}
          </div>
        ) : (
          treeRows
        )}
      </div>
      {searchActive && !searchLoading && !searchFailed && rows.length > 0 && searchTruncated && (
        // Without this the list looks complete, and a broad query in a
        // large repo silently hides everything past the cap.
        <div style={{ padding: "6px 12px 8px", fontSize: 10, color: "var(--text-dim)", flexShrink: 0 }}>
          {t("fileExplorer.searchTruncated", { count: searchRows.length })}
        </div>
      )}
      {contextMenu && (
        <SidebarPortalMenu
          anchorPoint={{ x: contextMenu.x, y: contextMenu.y }}
          open
          onClose={closeContextMenu}
          minWidth={200}
        >
          {contextMenu.target.kind === "file" ? (
            <>
              <ExplorerMenuItem
                label={t("fileExplorer.open")}
                icon={<FileText size={12} strokeWidth={1.8} aria-hidden="true" />}
                onSelect={() => {
                  const { path, name } = contextMenu.target;
                  setContextMenu(null);
                  onOpenFile(path, name);
                }}
              />
              <div style={{ padding: "6px 9px 2px", fontSize: 10, fontWeight: 600, letterSpacing: "0.02em", color: "var(--text-dim)" }}>
                {t("fileExplorer.openWith")}
              </div>
              {OPEN_WITH_OPTIONS.map((option) => (
                <button
                  key={option.mode}
                  type="button"
                  role="menuitem"
                  className="sidebar-menu-item sidebar-menu-subitem"
                  onClick={() => {
                    const path = contextMenu.target.path;
                    const name = contextMenu.target.name;
                    setContextMenu(null);
                    onOpenFile(path, name, option.mode);
                  }}
                >
                  {t(option.labelKey)}
                </button>
              ))}
              <div style={{ height: 1, margin: "4px 6px", background: "var(--border)" }} />
              <ExplorerMenuItem
                label={t("fileExplorer.newFileHere")}
                icon={<FilePlus size={12} strokeWidth={1.8} aria-hidden="true" />}
                onSelect={() => {
                  const directory = contextMenu.target.directory;
                  setContextMenu(null);
                  setCreateDialog({ kind: "file", directory });
                }}
              />
              <ExplorerMenuItem
                label={t("fileExplorer.newFolderHere")}
                icon={<FolderPlus size={12} strokeWidth={1.8} aria-hidden="true" />}
                onSelect={() => {
                  const directory = contextMenu.target.directory;
                  setContextMenu(null);
                  setCreateDialog({ kind: "dir", directory });
                }}
              />
              <div style={{ height: 1, margin: "4px 6px", background: "var(--border)" }} />
              <ExplorerMenuItem
                label={`${t("fileExplorer.cut")} (Ctrl/Cmd+X)`}
                icon={<Scissors size={12} strokeWidth={1.8} aria-hidden="true" />}
                onSelect={() => rememberNode({
                  name: contextMenu.target.name,
                  fullPath: contextMenu.target.path,
                  isDir: false,
                  size: 0,
                  modified: 0,
                }, "cut")}
              />
              <ExplorerMenuItem
                label={`${t("fileExplorer.copy")} (Ctrl/Cmd+C)`}
                icon={<Copy size={12} strokeWidth={1.8} aria-hidden="true" />}
                onSelect={() => rememberNode({
                  name: contextMenu.target.name,
                  fullPath: contextMenu.target.path,
                  isDir: false,
                  size: 0,
                  modified: 0,
                }, "copy")}
              />
              <ExplorerMenuItem
                label={`${t("fileExplorer.paste")} (Ctrl/Cmd+V)`}
                icon={<ClipboardPaste size={12} strokeWidth={1.8} aria-hidden="true" />}
                disabled={!clipboard}
                onSelect={() => pasteInto(contextMenu.target.directory)}
              />
              <ExplorerMenuItem
                label={t("fileExplorer.duplicate")}
                icon={<Files size={12} strokeWidth={1.8} aria-hidden="true" />}
                onSelect={() => void duplicateNode({
                  name: contextMenu.target.name,
                  fullPath: contextMenu.target.path,
                  isDir: false,
                  size: 0,
                  modified: 0,
                })}
              />
              <ExplorerMenuItem
                label={t("fileExplorer.renameWithShortcut")}
                icon={<Pencil size={12} strokeWidth={1.8} aria-hidden="true" />}
                onSelect={() => startRename({
                  name: contextMenu.target.name,
                  fullPath: contextMenu.target.path,
                  isDir: false,
                  size: 0,
                  modified: 0,
                })}
              />
              <ExplorerMenuItem
                label={t("fileExplorer.deleteWithShortcut")}
                icon={<Trash2 size={12} strokeWidth={1.8} aria-hidden="true" />}
                onSelect={() => rememberDeleteTarget(contextMenu.target)}
                danger
              />
              <div style={{ height: 1, margin: "4px 6px", background: "var(--border)" }} />
              <ExplorerMenuItem
                label={t("fileExplorer.copyRelativePath")}
                icon={<Copy size={12} strokeWidth={1.8} aria-hidden="true" />}
                onSelect={() => copyNodePath(contextMenu.target.path, "relative")}
              />
              <ExplorerMenuItem
                label={t("fileExplorer.copyAbsolutePath")}
                icon={<Copy size={12} strokeWidth={1.8} aria-hidden="true" />}
                onSelect={() => copyNodePath(contextMenu.target.path, "absolute")}
              />
              <div style={{ height: 1, margin: "4px 6px", background: "var(--border)" }} />
              <ExplorerMenuItem
                label={t("fileExplorer.mentionFile")}
                icon={<AtSign size={12} strokeWidth={2} aria-hidden="true" />}
                disabled={!onAtMention}
                onSelect={() => {
                  const path = contextMenu.target.path;
                  setContextMenu(null);
                  onAtMention?.(getRelativeFilePath(path, cwd), false);
                }}
              />
              <ExplorerMenuItem
                label={t("fileExplorer.downloadFile")}
                icon={<Download size={12} strokeWidth={2} aria-hidden="true" />}
                onSelect={() => {
                  const { path, name } = contextMenu.target;
                  setContextMenu(null);
                  const link = document.createElement("a");
                  link.href = apiUrl(`/api/files/${encodeFilePathForApi(path)}?type=download`);
                  link.download = name;
                  document.body.appendChild(link);
                  link.click();
                  link.remove();
                }}
              />
              <div style={{ height: 1, margin: "4px 6px", background: "var(--border)" }} />
              <ExplorerMenuItem
                label={t("fileExplorer.mountAsDrive")}
                icon={<HardDrive size={12} strokeWidth={2} aria-hidden="true" />}
                disabled={!onOpenMountGuide}
                onSelect={() => {
                  setContextMenu(null);
                  onOpenMountGuide?.();
                }}
              />
              <div style={{ height: 1, margin: "4px 6px", background: "var(--border)" }} />
              <ExplorerCheckableMenuItem
                label={t("fileExplorer.showHiddenFiles")}
                checked={showHiddenFiles}
                onSelect={() => {
                  setShowHiddenFiles(!showHiddenFiles);
                  setContextMenu(null);
                }}
              />
              <ExplorerCheckableMenuItem
                label={t("fileExplorer.showIgnored")}
                checked={includeIgnored}
                onSelect={() => toggleIncludeIgnored(!includeIgnored)}
              />
              <div style={{ padding: "6px 9px 2px", fontSize: 10, fontWeight: 600, letterSpacing: "0.02em", color: "var(--text-dim)" }}>
                {t("fileExplorer.sortBy")}
              </div>
              <ExplorerCheckableMenuItem
                label={t("fileExplorer.sortName")}
                checked={sortMode === "name"}
                onSelect={() => changeSortMode("name")}
              />
              <ExplorerCheckableMenuItem
                label={t("fileExplorer.sortModified")}
                checked={sortMode === "modified"}
                onSelect={() => changeSortMode("modified")}
              />
              <ExplorerCheckableMenuItem
                label={t("fileExplorer.sortSize")}
                checked={sortMode === "size"}
                onSelect={() => changeSortMode("size")}
              />
            </>
          ) : (
            <>
              <ExplorerMenuItem
                label={t("fileExplorer.newFile")}
                icon={<FilePlus size={12} strokeWidth={1.8} aria-hidden="true" />}
                onSelect={() => {
                  const directory = contextMenu.target.directory;
                  setContextMenu(null);
                  setCreateDialog({ kind: "file", directory });
                }}
              />
              <ExplorerMenuItem
                label={t("fileExplorer.newFolder")}
                icon={<FolderPlus size={12} strokeWidth={1.8} aria-hidden="true" />}
                onSelect={() => {
                  const directory = contextMenu.target.directory;
                  setContextMenu(null);
                  setCreateDialog({ kind: "dir", directory });
                }}
              />
              <ExplorerMenuItem
                label={t("fileExplorer.uploadFileHere")}
                icon={<Upload size={12} strokeWidth={1.8} aria-hidden="true" />}
                onSelect={() => openUploadForDirectory(contextMenu.target.path, false)}
              />
              <ExplorerMenuItem
                label={t("fileExplorer.uploadFolderHere")}
                icon={<FolderUp size={12} strokeWidth={1.8} aria-hidden="true" />}
                onSelect={() => openUploadForDirectory(contextMenu.target.path, true)}
              />
              <ExplorerMenuItem
                label={t("fileExplorer.downloadZip")}
                icon={<FileArchive size={12} strokeWidth={1.8} aria-hidden="true" />}
                onSelect={() => {
                  const { name, path } = contextMenu.target;
                  setContextMenu(null);
                  downloadZip({
                    name,
                    fullPath: path,
                    isDir: true,
                    size: 0,
                    modified: 0,
                  });
                }}
              />
              <ExplorerMenuItem
                label={t("fileExplorer.mountAsDrive")}
                icon={<HardDrive size={12} strokeWidth={2} aria-hidden="true" />}
                disabled={!onOpenMountGuide}
                onSelect={() => {
                  setContextMenu(null);
                  onOpenMountGuide?.();
                }}
              />
              <div style={{ height: 1, margin: "4px 6px", background: "var(--border)" }} />
              {!contextTargetIsRoot && (
                <>
                  <ExplorerMenuItem
                    label={`${t("fileExplorer.cut")} (Ctrl/Cmd+X)`}
                    icon={<Scissors size={12} strokeWidth={1.8} aria-hidden="true" />}
                    onSelect={() => rememberNode({
                      name: contextMenu.target.name,
                      fullPath: contextMenu.target.path,
                      isDir: true,
                      size: 0,
                      modified: 0,
                    }, "cut")}
                  />
                  <ExplorerMenuItem
                    label={`${t("fileExplorer.copy")} (Ctrl/Cmd+C)`}
                    icon={<Copy size={12} strokeWidth={1.8} aria-hidden="true" />}
                    onSelect={() => rememberNode({
                      name: contextMenu.target.name,
                      fullPath: contextMenu.target.path,
                      isDir: true,
                      size: 0,
                      modified: 0,
                    }, "copy")}
                  />
                </>
              )}
              <ExplorerMenuItem
                label={`${t("fileExplorer.paste")} (Ctrl/Cmd+V)`}
                icon={<ClipboardPaste size={12} strokeWidth={1.8} aria-hidden="true" />}
                disabled={!clipboard}
                onSelect={() => pasteInto(contextMenu.target.path)}
              />
              {!contextTargetIsRoot && (
                <>
                  <ExplorerMenuItem
                    label={t("fileExplorer.duplicate")}
                    icon={<Files size={12} strokeWidth={1.8} aria-hidden="true" />}
                    onSelect={() => void duplicateNode({
                      name: contextMenu.target.name,
                      fullPath: contextMenu.target.path,
                      isDir: true,
                      size: 0,
                      modified: 0,
                    })}
                  />
                  <ExplorerMenuItem
                    label={t("fileExplorer.renameWithShortcut")}
                    icon={<Pencil size={12} strokeWidth={1.8} aria-hidden="true" />}
                    onSelect={() => startRename({
                      name: contextMenu.target.name,
                      fullPath: contextMenu.target.path,
                      isDir: true,
                      size: 0,
                      modified: 0,
                    })}
                  />
                  <ExplorerMenuItem
                    label={t("fileExplorer.deleteWithShortcut")}
                    icon={<Trash2 size={12} strokeWidth={1.8} aria-hidden="true" />}
                    onSelect={() => rememberDeleteTarget(contextMenu.target)}
                    danger
                  />
                </>
              )}
              <div style={{ height: 1, margin: "4px 6px", background: "var(--border)" }} />
              <ExplorerMenuItem
                label={t("fileExplorer.copyRelativePath")}
                icon={<Copy size={12} strokeWidth={1.8} aria-hidden="true" />}
                onSelect={() => copyNodePath(contextMenu.target.path, "relative")}
              />
              <ExplorerMenuItem
                label={t("fileExplorer.copyAbsolutePath")}
                icon={<Copy size={12} strokeWidth={1.8} aria-hidden="true" />}
                onSelect={() => copyNodePath(contextMenu.target.path, "absolute")}
              />
              <div style={{ height: 1, margin: "4px 6px", background: "var(--border)" }} />
              <ExplorerMenuItem
                label={t("fileExplorer.mentionFolder")}
                icon={<AtSign size={12} strokeWidth={2} aria-hidden="true" />}
                disabled={!onAtMention}
                onSelect={() => {
                  const path = contextMenu.target.path;
                  setContextMenu(null);
                  onAtMention?.(getRelativeFilePath(path, cwd), true);
                }}
              />
              <div style={{ height: 1, margin: "4px 6px", background: "var(--border)" }} />
              <ExplorerCheckableMenuItem
                label={t("fileExplorer.showHiddenFiles")}
                checked={showHiddenFiles}
                onSelect={() => {
                  setShowHiddenFiles(!showHiddenFiles);
                  setContextMenu(null);
                }}
              />
              <ExplorerCheckableMenuItem
                label={t("fileExplorer.showIgnored")}
                checked={includeIgnored}
                onSelect={() => toggleIncludeIgnored(!includeIgnored)}
              />
              <div style={{ padding: "6px 9px 2px", fontSize: 10, fontWeight: 600, letterSpacing: "0.02em", color: "var(--text-dim)" }}>
                {t("fileExplorer.sortBy")}
              </div>
              <ExplorerCheckableMenuItem
                label={t("fileExplorer.sortName")}
                checked={sortMode === "name"}
                onSelect={() => changeSortMode("name")}
              />
              <ExplorerCheckableMenuItem
                label={t("fileExplorer.sortModified")}
                checked={sortMode === "modified"}
                onSelect={() => changeSortMode("modified")}
              />
              <ExplorerCheckableMenuItem
                label={t("fileExplorer.sortSize")}
                checked={sortMode === "size"}
                onSelect={() => changeSortMode("size")}
              />
            </>
          )}
        </SidebarPortalMenu>
      )}
      <ConfirmDialog
        open={deleteTarget !== null}
        onOpenChange={(open) => { if (!open && !deleting) setDeleteTarget(null); }}
        title={t("fileExplorer.deleteTitle", { name: deleteTarget?.name ?? "" })}
        description={deleteTarget?.kind === "dir"
          ? t("fileExplorer.deleteFolderDescription", { name: deleteTarget.name })
          : t("fileExplorer.deleteFileDescription", { name: deleteTarget?.name ?? "" })}
        confirmLabel={deleting ? t("fileExplorer.deleting") : t("fileExplorer.delete")}
        cancelLabel={t("fileExplorer.cancel")}
        danger
        busy={deleting}
        onConfirm={() => void confirmDelete()}
      />
      {pasteConflict && (
        <Dialog
          open
          onOpenChange={(open) => { if (!open) void resolvePasteConflict("cancel"); }}
        >
          <DialogContent
            ariaLabel={t("fileExplorer.pasteConflictTitle")}
            style={{ width: 430, maxWidth: "min(92vw, 430px)", padding: 20 }}
          >
            <DialogTitle>{t("fileExplorer.pasteConflictTitle")}</DialogTitle>
            <p style={{ margin: "0 0 14px", fontSize: 13, lineHeight: 1.55, color: "var(--text-muted)", overflowWrap: "anywhere" }}>
              {t("fileExplorer.pasteConflictDescription", { name: pasteConflict.item.name })}
            </p>
            <div style={{ display: "flex", justifyContent: "flex-end", gap: 8, flexWrap: "wrap" }}>
              <button
                type="button"
                disabled={pasteBusy}
                onClick={() => void resolvePasteConflict("overwrite")}
                style={{ padding: "6px 14px", background: "none", border: "1px solid var(--status-error)", borderRadius: "var(--radius-control)", color: "var(--status-error)", cursor: pasteBusy ? "wait" : "pointer", fontSize: 13 }}
              >
                {t("fileExplorer.replace")}
              </button>
              <button
                type="button"
                disabled={pasteBusy}
                onClick={() => void resolvePasteConflict("rename")}
                style={{ padding: "6px 14px", background: "var(--accent-strong)", border: "none", borderRadius: "var(--radius-control)", color: "var(--on-accent)", cursor: pasteBusy ? "wait" : "pointer", fontSize: 13, fontWeight: 600 }}
              >
                {t("fileExplorer.keepBoth")}
              </button>
              <button
                type="button"
                disabled={pasteBusy}
                onClick={() => void resolvePasteConflict("cancel")}
                style={{ padding: "6px 14px", background: "none", border: "1px solid var(--border)", borderRadius: "var(--radius-control)", color: "var(--text-muted)", cursor: "pointer", fontSize: 13 }}
              >
                {t("fileExplorer.cancel")}
              </button>
            </div>
          </DialogContent>
        </Dialog>
      )}
      {createDialog && (
        <CreateEntryDialog
          kind={createDialog.kind}
          directory={createDialog.directory}
          onClose={() => setCreateDialog(null)}
          onCreated={handleCreatedEntry}
        />
      )}
    </div>
  );
});
