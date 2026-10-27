/**
 * Web-native slash commands (prompt-composing).
 *
 * omp's own `/goal`, `/plan`, `/vibe`, ... are TUI-only builtins (`handleTui`);
 * the RPC prompt path (which AIDesk uses) forwards them as literal user text
 * instead of executing them. These client-side commands fill that gap: the
 * palette advertises them and the client built-in dispatcher expands them into
 * effective prompts sent through the normal prompt pipeline, so the agent
 * actually receives a clear instruction rather than a stray "/goal ..." line.
 *
 * Pure definitions — no I/O. Prompt text is deliberately concise; the args are
 * user-supplied and embedded verbatim.
 */

export interface WebSlashCommandDef {
  name: string;
  descriptionKey: string;
  /** i18n key for the bracketed argument hint shown in the palette, e.g. "[goal]". */
  argumentHintKey: string;
  /** Commands without args refuse to run and surface usage instead. */
  requiresArgs: boolean;
  buildPrompt: (args: string) => string;
}

const GOAL_PROMPT = (args: string) =>
  `Work toward this goal for the rest of the session:\n\n${args}\n\nTreat it as the objective to prioritize when deciding what to do next.`;

const PLAN_PROMPT = (args: string) =>
  `Create a plan for this task before doing anything else:\n\n${args}\n\nThink it through step by step, list concrete steps, and state what you will verify when done.`;

const REVIEW_PROMPT = (args: string) =>
  args
    ? `Review ${args} for bugs, security issues, and opportunities to simplify. Summarize what you find, then fix anything clearly wrong.`
    : `Review the current project state and recent changes for bugs, security issues, and opportunities to simplify. Summarize what you find, then fix anything clearly wrong.`;

const FIX_PROMPT = (args: string) =>
  `Fix this issue:\n\n${args}\n\nReproduce the problem, apply the smallest correct fix, and verify it works before finishing.`;

const TEST_PROMPT = (args: string) =>
  `Write tests for ${args}. Follow the project's test conventions, cover the important behavior and edge cases, and run the tests to confirm they pass.`;

const EXPLAIN_PROMPT = (args: string) =>
  `Explain ${args} concisely: what it does, how it works, and the key details worth knowing.`;

const SIMPLIFY_PROMPT = (args: string) =>
  `Simplify ${args}. Remove unnecessary complexity while preserving behavior, keep the change focused, and verify nothing breaks.`;

const COMMIT_PROMPT = (args: string) =>
  args
    ? `Stage the relevant files and commit the current changes with this message: ${JSON.stringify(args)}. Run the project's checks first so the commit is green.`
    : `Stage the relevant files and commit the current changes with a clear conventional commit message. Run the project's checks first so the commit is green.`;

const ADVISOR_PROMPT = (args: string) =>
  args
    ? `Act as an independent advisor reviewing this work: ${args}. Assess the approach, point out risks, gaps, and better alternatives, and give concrete recommendations without changing any code.`
    : `Act as an independent advisor reviewing the current work. Assess the recent changes and overall direction, point out risks, gaps, and better alternatives, and give concrete recommendations without changing any code.`;

const LOOP_MAX_ATTEMPTS = 10;
const LOOP_DEFAULT_ATTEMPTS = 3;

const LOOP_PROMPT = (args: string) => {
  const match = args.match(/^(\d+)\s+([\s\S]+)$/);
  const attempts = match ? Math.min(Math.max(parseInt(match[1], 10) || LOOP_DEFAULT_ATTEMPTS, 1), LOOP_MAX_ATTEMPTS) : LOOP_DEFAULT_ATTEMPTS;
  const task = match ? match[2].trim() : args;
  return `Attempt the following task, verifying the result concretely after each attempt (run the relevant checks or tests). If it is not fully done, try again from where it stands, building on what you learned — up to ${attempts} attempts in total. Stop early once it is done. Do not ask for confirmation between attempts.\n\nTask:\n\n${task}`;
};

export const WEB_SLASH_COMMANDS: readonly WebSlashCommandDef[] = [
  {
    name: "goal",
    descriptionKey: "chatInput.cmdGoal",
    argumentHintKey: "chatInput.cmdGoalArg",
    requiresArgs: true,
    buildPrompt: GOAL_PROMPT,
  },
  {
    name: "plan",
    descriptionKey: "chatInput.cmdPlan",
    argumentHintKey: "chatInput.cmdPlanArg",
    requiresArgs: true,
    buildPrompt: PLAN_PROMPT,
  },
  {
    name: "review",
    descriptionKey: "chatInput.cmdReview",
    argumentHintKey: "chatInput.cmdReviewArg",
    requiresArgs: false,
    buildPrompt: REVIEW_PROMPT,
  },
  {
    name: "fix",
    descriptionKey: "chatInput.cmdFix",
    argumentHintKey: "chatInput.cmdFixArg",
    requiresArgs: true,
    buildPrompt: FIX_PROMPT,
  },
  {
    name: "test",
    descriptionKey: "chatInput.cmdTest",
    argumentHintKey: "chatInput.cmdTestArg",
    requiresArgs: true,
    buildPrompt: TEST_PROMPT,
  },
  {
    name: "explain",
    descriptionKey: "chatInput.cmdExplain",
    argumentHintKey: "chatInput.cmdExplainArg",
    requiresArgs: true,
    buildPrompt: EXPLAIN_PROMPT,
  },
  {
    name: "simplify",
    descriptionKey: "chatInput.cmdSimplify",
    argumentHintKey: "chatInput.cmdSimplifyArg",
    requiresArgs: true,
    buildPrompt: SIMPLIFY_PROMPT,
  },
  {
    name: "commit",
    descriptionKey: "chatInput.cmdCommit",
    argumentHintKey: "chatInput.cmdCommitArg",
    requiresArgs: false,
    buildPrompt: COMMIT_PROMPT,
  },
  {
    name: "advisor",
    descriptionKey: "chatInput.cmdAdvisor",
    argumentHintKey: "chatInput.cmdAdvisorArg",
    requiresArgs: false,
    buildPrompt: ADVISOR_PROMPT,
  },
  {
    name: "loop",
    descriptionKey: "chatInput.cmdLoop",
    argumentHintKey: "chatInput.cmdLoopArg",
    requiresArgs: true,
    buildPrompt: LOOP_PROMPT,
  },
];
const WEB_SLASH_COMMAND_LOOKUP = new Map(WEB_SLASH_COMMANDS.map((command) => [command.name, command]));

export function getWebSlashCommand(name: string): WebSlashCommandDef | undefined {
  return WEB_SLASH_COMMAND_LOOKUP.get(name);
}

export type WebSlashCommandExpansion =
  | { kind: "expand"; prompt: string }
  | { kind: "usage-error"; command: string; argumentHintKey: string }
  | { kind: "not-web" };

/**
 * Resolve a full command line (e.g. "/goal ship the export") into either the
 * expanded prompt to send, a usage error for a required-arg command with no
 * args, or "not-web" for commands the client does not own. Single source of
 * truth for both the idle dispatcher and the streaming queue path, so a web
 * command is never forwarded to omp as literal slash text.
 */
export function expandWebSlashCommand(text: string): WebSlashCommandExpansion {
  if (!text.startsWith("/")) return { kind: "not-web" };
  const match = text.match(/^\/([^\s]+)(?:\s+([\s\S]*))?$/);
  if (!match) return { kind: "not-web" };
  const def = getWebSlashCommand(match[1]);
  if (!def) return { kind: "not-web" };
  const args = (match[2] ?? "").trim();
  if (def.requiresArgs && !args) {
    return { kind: "usage-error", command: `/${def.name}`, argumentHintKey: def.argumentHintKey };
  }
  return { kind: "expand", prompt: def.buildPrompt(args) };
}
