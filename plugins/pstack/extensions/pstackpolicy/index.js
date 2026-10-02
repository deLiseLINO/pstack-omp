// pstackpolicy: the machine backstop for the one gate the port has no prose answer for.
//
// pstack's playbooks say "only under an operator landing grant", "never merge without an
// explicit request", "stop where the human's call begins". Those are instructions, and an
// instruction is not enforcement. On this harness they cannot be, either:
//
//   - `omp://approval-mode.md`: yolo auto-approves the `read`, `write`, AND `exec` tiers, so
//     `gh pr merge` inside a bash call runs with no prompt.
//   - same file, Subagents: "Subagents run headless with `tools.approvalMode: yolo`... The
//     parent `task` approval is the authorization boundary." Every pstack owner is a subagent.
//   - same file: bash's built-in critical patterns cover `rm -rf /`, fork bombs,
//     remote-fetch-then-execute, `/etc/passwd`, and host shutdown. A merge is not on that list.
//
// So an agent that reads a playbook step in isolation has licence to land the stack. This
// closes that with `tool_call`, the one native veto point that sits in front of execution.
//
// The grant is deliberately an environment variable rather than a flag or a command, because a
// flag the agent can pass is not a grant the operator made. The operator arms it; a subagent
// cannot set its own process environment.
//
//   PSTACK_LANDING_GRANT=1   allow the forge mutations below for this process
//
// Two shapes of rule, because one shape is not enough. The `gh` rules are regexes, so they have
// to tolerate global flags between the binary and the subcommand -- `gh --repo o/r pr merge` is
// the documented way to target a non-default repo and the port uses it constantly, and anchoring
// on `gh pr` alone let every one of them through. The `git push` rules are a token scan, because
// "does this push land on trunk" is a question about refspecs, not a substring: `git push origin
// HEAD:main` moves trunk with no force flag at all, which a force-token regex cannot see, and a
// naive trunk-word lookahead then blocks `feature/main-menu`.

const GRANT = "PSTACK_LANDING_GRANT";

const TRUNK = new Set(["main", "master", "trunk", "develop", "release"]);

// gh accepts global flags before the subcommand. Each rule permits any number of them, including
// `--repo owner/name`, which is the form the port actually uses.
const GH_FLAGS = String.raw`(?:\s+(?:-[A-Za-z]|[-]{2}[A-Za-z][\w-]*)(?:[= ]\S+)?)*`;

const FORBIDDEN = [
  [
    "merging a pull request",
    new RegExp(String.raw`\bgh\b${GH_FLAGS}\s+pr\s+merge\b`),
  ],
  [
    "merging a pull request through the API",
    new RegExp(
      String.raw`\bgh\b${GH_FLAGS}\s+api\b[^\n]*(?:\/pulls\/\d+\/merge|mergePullRequest|\/merge\b)`
    ),
  ],
  [
    "closing, reopening, or deleting a pull request, issue, or thread",
    new RegExp(
      String.raw`\bgh\b${GH_FLAGS}\s+(pr|issue)\s+(close|reopen|delete)\b|\bgh\b${GH_FLAGS}\s+api\b[^\n]*(?:-X\s*DELETE[^\n]*\/(issues|pulls|git\/refs)|state\s*=\s*closed|closePullRequest|closeIssue)`
    ),
  ],
  [
    "retargeting a pull request base, which rewrites the whole stack under it",
    new RegExp(String.raw`\bgh\b${GH_FLAGS}\s+pr\s+edit\b[^\n]*--base\b`),
  ],
  [
    "posting a review or resolving a review thread",
    new RegExp(
      String.raw`\bgh\b${GH_FLAGS}\s+pr\s+review\b|\bgh\b${GH_FLAGS}\s+api\b[^\n]*(?:-X\s*POST[^\n]*(?:\/reviews|pulls\/\d+\/(comments|reviews))|resolveReviewThread|addPullRequestReview)`
    ),
  ],
  [
    "armoring merge-when-ready",
    new RegExp(String.raw`\bgh\b${GH_FLAGS}\s+pr\s+merge\b[^\n]*--(?:auto|auto-merge)\b`),
  ],
  [
    "merging through Graphite",
    new RegExp(String.raw`\bgt\s+(submit|rebase|restack)\b`),
  ],
];

const DESTROY_LOCAL = new RegExp(
  String.raw`\bgit\s+(update-ref\s+(?!-d\b)|reflog\s+expire\b[^\n]*--expire=now[^\n]*--all|reset\s+--hard\b[^\n]*\sorigin/|branch\s+-D\b)`
);

/**
 * Token scan over every `git push` in the command. Returns why it is refused, or null.
 *
 * Deliberately blocks every push whose refspec lands on a trunk branch, not only forced ones:
 * the port's own pause list now names "pushing to trunk" as irreversible, and a plain
 * `git push origin HEAD:main` does that with no force flag to key on. A push to a feature branch
 * is the port's normal rebase flow and stays allowed.
 */
function pushOffence(command) {
  const tokens = command.split(/\s+/);
  for (let i = 0; i < tokens.length - 1; i += 1) {
    if (tokens[i] !== "git" || tokens[i + 1] !== "push") continue;
    const rest = tokens.slice(i + 2);
    if (rest.includes("--dry-run") || rest.includes("-n")) continue;
    if (rest.includes("--mirror") || rest.includes("--all") || rest.includes("--tags")) {
      return "pushing every ref, or mirroring the whole repository, at the remote";
    }
    if (rest.includes("--delete")) return "deleting a branch on the forge";
    for (const token of rest) {
      // `:branch` is git's refspec delete form; it carries no --delete flag.
      if (token.startsWith(":")) return "deleting a branch on the forge";
      const afterColon = token.includes(":") ? token.slice(token.lastIndexOf(":") + 1) : token;
      if (afterColon.startsWith("-")) continue;
      const clean = afterColon.replace(/^\+/, "").replace(/^refs\/heads\//, "");
      if (TRUNK.has(clean)) {
        return rest.some((t) => /^--force/.test(t) || t === "-f")
          ? "rewriting history on a trunk branch"
          : "pushing to trunk";
      }
    }
  }
  return null;
}

export const DENY_REASONS = FORBIDDEN.map(([why]) => why);

function granted() {
  const raw = process.env[GRANT];
  // Anything but an explicit affirmative is absent. A stray "0" or "false" must not read as
  // consent, and an unset variable must not either.
  return raw === "1" || raw === "true";
}

export default function pstackpolicy(pi) {
  pi.on("tool_call", async (event) => {
    if (event?.toolName !== "bash") return;
    const command = typeof event.input?.command === "string" ? event.input.command : "";
    if (!command) return;
    if (granted()) return;

    const why =
      pushOffence(command) ??
      (FORBIDDEN.find(([, pattern]) => pattern.test(command)) ?? null)?.[0] ??
      (DESTROY_LOCAL.test(command) ? "destroying local history" : null);

    if (why) {
      return {
        block: true,
        reason:
          `pstackpolicy: refused ${why}. pstack's playbooks require an operator landing grant for ` +
          `this and no prose can enforce it: yolo auto-approves the exec tier, subagents run ` +
          `headless yolo, and bash's critical-pattern list does not cover forge mutations. If you ` +
          `are the operator and want it allowed for this run, restart with ${GRANT}=1. Otherwise ` +
          `return the step to the human and say what is blocked.`,
      };
    }
  });
}