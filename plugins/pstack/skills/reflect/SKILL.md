---
name: reflect
description: Spawn three parallel review subagents over the active transcript, surface learnings, and route each to a concrete edit on an existing skill. Use when the user says reflect.
disable-model-invocation: true
---

# Reflect

Mine the current conversation for durable learnings, then route them into skill edits.

Invoke when the user says "reflect" or "/reflect". Skip when the conversation is trivial, off-topic, or already covered by an existing skill the parent followed correctly. One-offs are not learnings.

## 1. Locate the active transcript

Before fanning out, find this conversation's transcript in the `agent-transcripts/` directory the system prompt names. Do not glob across sibling `~/.omp/agent/sessions/<other-cwd>/` buckets. That crosses workspace boundaries and reads private chats from unrelated projects.

```bash
ls -t ~/.omp/agent/sessions/<encoded-cwd>/*.jsonl ~/.omp/agent/sessions/<encoded-cwd>/*/*.jsonl ~/.omp/agent/sessions/<encoded-cwd>/*/*/*.jsonl 2>/dev/null | head -10
```

That covers the legacy flat (`<id>.jsonl`), current nested (`<id>/<id>.jsonl`), and subagent (`<parent>/subagents/<child>.jsonl`) layouts. For each candidate, read the first JSONL line. Take the file whose `message.content[0].text` contains the conversation's opening user prompt. If none matches, pass a tight digest of the session instead.

## 2. Spawn three reviewers in parallel

One message, three `Task` calls, `agent: generalPurpose`, agent mode (full tools per spawn). Reviewers need MCP access to look up the tickets, chat threads, and observability traces the transcript references, and nothing strips MCPs here.

Resolve exact discovered agent names for the three lenses and the synthesizer. Each agent's frontmatter or `task.agentModelOverrides[<exact-name>]` selects the model; the task item has no `model` field. Pick each subagent's reasoning level and fast or standard speed for the job, per the Subagents section of the **poteto-mode** skill.

| Lens | Exact agent | Prompt template |
|---|---|---|---|
| Judgment | discovered judgment agent | `references/judgment-reviewer.md` |
| Tooling | discovered tooling agent | `references/tooling-reviewer.md` |
| Divergent | discovered divergent agent | `references/divergent-reviewer.md` |

Pass each template verbatim, substituting the transcript path or digest where marked. Reviewers return findings in the spawn result's structured `data`, or in the delivered report when no schema was requested.

## 3. Synthesize

One `Task` call, `agent: generalPurpose`, `agent` from the `task.agentModelOverrides` entry for an exact discovered agent filling that role (default your strongest judgment model), agent mode (full tools per spawn). It spot-verifies citations through MCP, and nothing strips MCPs here. Pass `references/synthesizer.md` verbatim, with each reviewer's full output inlined where marked. It returns an Accepted / Rejected / Backlog list.

## 4. Structural enforcement check

Move any Accepted item that a lint rule, script, metadata flag, or runtime check would enforce more reliably to Backlog. See the **encode-lessons-in-structure** principle skill.

## 5. Apply

Present the synthesizer's full Accepted / Rejected / Backlog output and wait for explicit approval before applying any Accepted edit. The user picks the subset and may redirect routings. Skill changes affect every future agent in the org. Do not auto-apply.

File each Backlog item to your team's devex or backlog tracker without waiting. Only the Accepted list waits for approval.

Follow each approved row's Routing exactly:

- Trivial existing-skill edit (a one-line bullet, a tightened sentence, a stale fact corrected): the parent does it directly.
- Substantive existing-skill edit (a new section, a new pattern table, more than ~10 lines): hand to the `authoring-a-skill` playbook and run its draft / test / iterate loop.
- `tune description: <skill path>` (the skill exists but didn't trigger when it should have): hand to the `authoring-a-skill` playbook and run its description-optimization loop.
- `new skill via authoring-a-skill: <kebab-name>`: hand creation to the `authoring-a-skill` playbook. Do not invent the shape ad hoc.

If your environment ships a SKILL.md validator, run it on every touched skill before declaring done.

## 6. Summarize for the user

Short list, no preamble:

- Edits applied: `<skill path>`. What changed, one line each.
- New skills created: `<skill path>`. One line each (rare).
- Backlog filed to the devex tracker: `<issue title>` (`<tags>`). One line each.
- Dropped: one line per rejected finding + reason from the synthesizer.
