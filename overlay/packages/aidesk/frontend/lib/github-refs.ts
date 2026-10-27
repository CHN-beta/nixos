import { createContext } from "react";
import type { Link, Root } from "mdast";
import { findAndReplace } from "mdast-util-find-and-replace";

/** `owner/repo` of the GitHub repository bare `#123` references resolve against. */
export const GithubRepoContext = createContext<string | null>(null);

// `#123` or `owner/repo#123`, GitHub-style. The lookbehind rejects references
// glued to words or paths (`C#12`, `file.ts#12`, `a/b/c#12`, `&#123;`).
const GITHUB_REF_RE = /(?<![\w./#&-])(?:([A-Za-z0-9][A-Za-z0-9-]*\/[A-Za-z0-9._-]+))?#([1-9]\d{0,9})(?![\w-])/g;

/**
 * Links GitHub issue/PR references in prose. `owner/repo#N` always links;
 * bare `#N` links only when `repo` is known. `/issues/N` redirects to the
 * pull request when N is one. Existing links and code are left untouched.
 */
export function remarkGithubRefs({ repo }: { repo?: string | null } = {}) {
  return (tree: Root) => {
    findAndReplace(
      tree,
      [
        GITHUB_REF_RE,
        (match: string, slug: string | undefined, number: string): Link | false => {
          const target = slug ?? repo;
          if (!target) return false;
          return {
            type: "link",
            url: `https://github.com/${target}/issues/${number}`,
            children: [{ type: "text", value: match }],
          };
        },
      ],
      { ignore: ["link", "linkReference"] },
    );
  };
}
