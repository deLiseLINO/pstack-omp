import { describe, expect, test } from "bun:test";
import policy, { DENY_REASONS } from "./index.js";

// The handler is the whole backstop, so it is tested against commands that must be refused and
// commands that must not be. A rule set that blocks nothing is indistinguishable from no
// backstop at all until something tries to merge. Every call awaits: the handler is async, and
// comparing a Promise against undefined would pass for the wrong reason.
async function run(command, env) {
  const saved = {};
  for (const [k, v] of Object.entries(env ?? {})) {
    saved[k] = process.env[k];
    if (v === undefined) delete process.env[k];
    else process.env[k] = v;
  }
  let handler;
  policy({ on: (_event, fn) => { handler = fn; } });
  try {
    return await handler({ toolName: "bash", input: { command } });
  } finally {
    for (const [k, v] of Object.entries(saved)) {
      if (v === undefined) delete process.env[k];
      else process.env[k] = v;
    }
  }
}

const MUST_BLOCK = [
  // A refspec this port cannot read is not a refspec. `git push origin HEAD` and a bare
  // `git push` land on whatever the checkout is on, which from a trunk checkout is trunk, and a
  // quoted refspec hid the destination from the colon split.
  "git push origin HEAD",
  "git push",
  "git push origin",
  "git push --force origin",
  "git push origin 'HEAD:main'",
  "gh pr edit 12 \\\n  --base main",
  "gh pr merge 12 \\\n  --auto",
  "gh --repo o/r pr merge 12 \\\n  --squash",
  // The forms that defeated the first version of this file.
  "gh --repo o/r pr merge 12 --squash",
  "gh --repo o/r pr edit 12 --base main",
  "gh --repo o/r pr review 12 --approve",
  "gh --repo o/r issue close 5",
  "git push origin HEAD:main",
  "git push origin main:main",
  "git push origin HEAD:refs/heads/main",
  "git push origin +main",
  "git push origin :feature/x",
  "git push --mirror git@github.com:o/r.git",
  "git update-ref refs/heads/main abc123",
  'gh api graphql -f query=\'mutation{mergePullRequest(input:{pullRequestId:"x"}){clientMutationId}}\'',
  "gh api -X PATCH repos/o/r/pulls/12 -f state=closed",
  "gh api -X DELETE /repos/o/r/git/refs/heads/main",
  // The forms it always caught.
  "gh pr merge 12 --squash --delete-branch",
  "gh pr merge 12 --squash --auto",
  "gh pr edit 12 --base main",
  "gh pr close 12",
  "gh pr review 12 --approve",
  "git push --force origin main",
  "git push origin main --force-with-lease",
  "git push origin --delete feature/x",
  "git branch -D feature/x",
  "gh api repos/o/r/pulls/12/merge -X POST",
  "gt submit --stack",
  "if [ -z \"$x\" ]; then gh pr merge 3; fi",
  "cd /tmp && gh pr merge 9 --squash",
];

const MUST_PASS = [
  "gh pr view 12",
  "gh pr list --state open",
  "gh pr diff 12",
  "git push origin feature/x",
  "git push --force-with-lease origin feature/x",
  "git status --porcelain",
  "bun run test",
  "git push --force-with-lease origin feature/x",
  "git push --force-with-lease origin main-menu",
  "git push --force origin feature/main-menu",
  "git commit -m \"merge main into feature\"",
  "gh pr list --search main",
  "git log main..HEAD",
  "git push origin feature/x",
];

describe("pstackpolicy", () => {
  test("refuses every forge mutation when no grant is set", async () => {
    for (const command of MUST_BLOCK) {
      const result = await run(command, { PSTACK_LANDING_GRANT: undefined });
      expect(result?.block, `should block: ${command}`).toBe(true);
      expect(result?.reason, `should explain: ${command}`).toContain("PSTACK_LANDING_GRANT");
    }
  });

  test("allows reads and ordinary pushes to pass through", async () => {
    for (const command of MUST_PASS) {
      expect(await run(command, { PSTACK_LANDING_GRANT: undefined }), `should pass: ${command}`)
        .toBeUndefined();
    }
  });

  test("an operator grant lifts every rule", async () => {
    for (const command of MUST_BLOCK) {
      expect(await run(command, { PSTACK_LANDING_GRANT: "1" }), `granted: ${command}`)
        .toBeUndefined();
    }
  });

  test("only an explicit affirmative counts as a grant", async () => {
    for (const value of ["0", "false", "", "yes", "no"]) {
      const result = await run("gh pr merge 12 --squash", { PSTACK_LANDING_GRANT: value });
      expect(result?.block, `not a grant: ${JSON.stringify(value)}`).toBe(true);
    }
    const ok = await run("gh pr merge 12 --squash", { PSTACK_LANDING_GRANT: "true" });
    expect(ok?.block).toBeUndefined();
  });

  test("ignores non-bash tools", async () => {
    let handler;
    policy({ on: (_e, fn) => { handler = fn; } });
    expect(await handler({ toolName: "read", input: { command: "gh pr merge 12" } })).toBeUndefined();
  });

  test("every rule carries a reason the port can assert on", () => {
    expect(DENY_REASONS.length).toBeGreaterThan(0);
    for (const why of DENY_REASONS) expect(typeof why).toBe("string");
  });
});