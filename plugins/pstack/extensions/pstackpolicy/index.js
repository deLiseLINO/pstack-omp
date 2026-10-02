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
// cannot.
//
//   PSTACK_LANDING_GRANT=1   allow the forge mutations below for this process
//
// Absent that, every match is refused with the reason, and the refusal names the variable so
// the operator is told exactly what to set. A stack owner therefore cannot merge, close, or
// rewrite history unless a human armed it, and the arming is visible in the environment of the
// process that did it.

const GRANT = "PSTACK_LANDING_GRANT";

// Each entry is [why, RegExp]. The patterns run against the bash `command` string, which is
// what omp hands `tool_call` for a bash invocation. Ordered most specific first, because a
// force-push is also a push and the reason string should name the right one.
const FORBIDDEN = [
  [
    "merging a pull request",
    /\bgh\s+pr\s+merge\b|\bgh\s+api\b[^\n]*(?:\/merge\b|-X\s*POST[^\n]*(?:\/merge|\/pulls\/\d+\/merge))|\bgt\s+submit\b|\borigin\s+pr\s+merge\b/,
  ],
  [
    "arming merge-when-ready or auto-merge",
    /\bgh\s+pr\s+merge\b[^\n]*--auto\b|\bgt\s+submit\b[^\n]*--auto\b|\borigin\s+pr\s+merge\b[^\n]*--auto\b/,
  ],
  [
    "closing or reopening a pull request, issue, or thread",
    /\bgh\s+pr\s+(close|reopen)\b|\bgh\s+issue\s+(close|reopen)\b|\bgh\s+api\b[^\n]*-X\s*DELETE[^\n]*\/(issues|pulls)\b|\bgh\s+pr\s+comment\b[^\n]*delete\b/,
  ],
  [
    "retargeting a pull request base, which rewrites the whole stack under it",
    /\bgh\s+pr\s+edit\b[^\n]*--base\b|\borigin\s+pr\s+edit\b[^\n]*--base\b/,
  ],
  [
    "posting a review or resolving a review thread",
    /\bgh\s+pr\s+review\b|\bgh\s+api\b[^\n]*pulls\/\d+\/(reviews|comments)\b[^\n]*(?:-X\s*POST|-f|-F)|\bgh\s+api\b[^\n]*graphql[^\n]*resolveReviewThread|\bgt\s+reply\b/,
  ],
  [
    "rewriting published history on a shared or trunk branch",
    // A force push to a feature branch is the port's own rebase flow and stays allowed; a force push
    // that names a trunk ref is history rewrite on a shared branch, which is the thing the playbooks
    // keep escalating. The alternative, blocking every force push, would fail every stack owner
    // mid-rebase and make the extension unusable without a grant.
    /\bgit\s+push\b(?=[^\n]*(?:--force-with-lease\b|--force\b|\s-f\b))(?=[^\n]*\b(?:main|master|trunk)\b)/,
  ],
  [
    "destroying local history",
    /\bgit\s+update-ref\s+-d\b|\bgit\s+reflog\s+expire\b[^\n]*--expire=now[^\n]*--all|\bgit\s+reset\s+--hard\b[^\n]*\borigin\//,
  ],
  [
    "restacking with Graphite, which this port does not depend on",
    /\bgt\s+(rebase|restack|submit)\b/,
  ],
  [
    "deleting a branch on the forge",
    /\bgit\s+push\b[^\n]*--delete\b|\bgh\s+pr\s+delete\b|\bgit\s+branch\s+-D\b/,
  ],
];

// Exported so the port's gate can assert the rule set is still non-empty; a backstop emptied by a
// careless edit is indistinguishable from no backstop until it is needed.
export const DENY_REASONS = FORBIDDEN.map(([why]) => why);
function granted() {
  const raw = process.env[GRANT];
  // Anything but an explicit affirmative is absent. A stray "0" or "false" must not read as
  // consent, and an unset variable must not either.
  return raw === "1" || raw === "true";
}

export default function pstackpolicy(pi) {
  pi.on("tool_call", async (event) => {
    const name = event?.toolName;
    if (name !== "bash") return;
    const command = typeof event.input?.command === "string" ? event.input.command : "";
    if (!command) return;
    if (granted()) return;

    for (const [why, pattern] of FORBIDDEN) {
      if (pattern.test(command)) {
        return {
          block: true,
          reason:
            `pstackpolicy: refused ${why}. pstack's playbooks require an operator landing grant ` +
            `for this and no prose can enforce it: yolo auto-approves the exec tier, subagents run ` +
            `headless yolo, and bash's critical-pattern list does not cover forge mutations. If you ` +
            `are the operator and want it allowed for this run, restart with ${GRANT}=1. Otherwise ` +
            `return the step to the human and say what is blocked.`,
        };
      }
    }
  });
}