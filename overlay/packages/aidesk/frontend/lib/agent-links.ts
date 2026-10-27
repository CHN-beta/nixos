import { createContext } from "react";
import { defaultUrlTransform, type UrlTransform } from "react-markdown";
import type { Link, Nodes, Root } from "mdast";
import { findAndReplace } from "mdast-util-find-and-replace";
import type { SubagentInfo } from "./subagent-types";

/**
 * `agent://<id>[/<child>...]` handles omp advertises for subagent output.
 * Id segments mirror omp's dot-qualified subagent ids; a trailing sentence
 * period is never part of a match.
 */
const SEGMENT = "[A-Za-z0-9_-]+(?:\\.[A-Za-z0-9_-]+)*";
const AGENT_URL_SOURCE = `agent://${SEGMENT}(?:/${SEGMENT})*`;
// The lookbehind rejects handles glued to words or paths (`xagent://`, `a/agent://`).
const AGENT_URL_PROSE_RE = new RegExp(`(?<![\\w/])${AGENT_URL_SOURCE}`, "g");
const AGENT_URL_EXACT_RE = new RegExp(`^${AGENT_URL_SOURCE}$`);
const AGENT_HREF_RE = new RegExp(`^agent://(${SEGMENT})((?:/[^?#]*)?)(?:[?#].*)?$`);
const CHILD_SEGMENT_RE = /^[A-Za-z0-9_-]+$/;
// omp's write-only broadcast address; reading it fails, so it is never linked.
const BROADCAST_URL = "agent://all";

/** Opens the subagent named by an `agent://` link; provided by the chat view. */
export const AgentLinkContext = createContext<((candidateIds: string[]) => void) | null>(null);

/**
 * Keeps `agent://` hrefs, which react-markdown's default transform blanks,
 * except the write-only broadcast address, and drops (rather than blanks) any
 * other href the default transform rejects: the sanitizer now admits `agent:`,
 * and `href=""` would link to AIDesk itself.
 */
export const agentAwareUrlTransform: UrlTransform = (url) => {
  const match = AGENT_HREF_RE.exec(url);
  if (match) return `agent://${match[1]}` === BROADCAST_URL ? undefined : url;
  return defaultUrlTransform(url) || undefined;
};

/**
 * Subagent ids an `agent://` href may name, most specific first. Mirrors omp's
 * resolver: `agent://Parent/Child` names `Parent.Child` when that output
 * exists, else the slash path is JSON extraction on `Parent`.
 */
export function agentLinkIds(href: string | undefined): string[] {
  const match = href ? AGENT_HREF_RE.exec(href) : null;
  if (!match || `agent://${match[1]}` === BROADCAST_URL) return [];
  const [, id, path] = match;
  const segments = path.split("/").filter(Boolean);
  if (segments.length > 0 && segments.every((segment) => CHILD_SEGMENT_RE.test(segment))) {
    return [[id, ...segments].join("."), id];
  }
  return [id];
}

/**
 * Roster entry an `agent://` link opens: the first candidate the live roster
 * knows, else a disk-backed stub for the base id (the dialog then reads the
 * persisted output, e.g. after the roster was pruned).
 */
export function agentLinkTarget(candidateIds: string[], roster: readonly SubagentInfo[]): SubagentInfo {
  for (const id of candidateIds) {
    const known = roster.find((subagent) => subagent.id === id);
    if (known) return known;
  }
  const id = candidateIds[candidateIds.length - 1];
  return { id, agent: id, status: "completed", index: 0, source: "history" };
}

/** Wraps inline code that is exactly one handle; existing links stay untouched. */
function linkInlineCode(node: Nodes): void {
  if (!("children" in node) || node.type === "link" || node.type === "linkReference") return;
  const children = node.children as Nodes[];
  children.forEach((child, index) => {
    if (child.type === "inlineCode" && child.value !== BROADCAST_URL && AGENT_URL_EXACT_RE.test(child.value)) {
      children[index] = { type: "link", url: child.value, children: [child] } satisfies Link;
    } else {
      linkInlineCode(child);
    }
  });
}

/** Remark plugin: link bare `agent://` handles and inline code holding exactly one. */
export function remarkAgentLinks() {
  return (tree: Root) => {
    findAndReplace(
      tree,
      [AGENT_URL_PROSE_RE, (match: string): Link | false => (match === BROADCAST_URL ? false : { type: "link", url: match, children: [{ type: "text", value: match }] })],
      { ignore: ["link", "linkReference"] },
    );
    linkInlineCode(tree);
  };
}
