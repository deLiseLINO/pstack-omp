# The substitution table, executable. Run as `sed -E -i -f omp-port/rules.sed <file>` on every
# text file of an upstream `pstack/{skills,agents}` export. Port-only file, never upstream.
#
# One rule per line, ordered, each with a `#` comment naming the Cursor mechanic and the omp
# mechanic it maps to. This file replaces PORTING.md's substitution table: the table is here now.
# Order is load-bearing in three places, each marked below.
#
# Prose the port adds on top of these rewrites lives in plugins/pstack/skills/omp-mechanics.
# Script changes live in omp-port/patches. Neither belongs here.

## 1. Whole-sentence rewrites, which must read raw upstream text before any token rule edits it.

# Cursor's reasoning-effort ladder over its own slug names -> a selector omp models reports.
s#So `small` turns `claude-[a-z0-9.-]+` into `claude-[a-z0-9.-]+`, and `grok-[a-z0-9.-]+` into `[a-z0-9.-]+` when only that form is detected\.#So `small` takes the lowest-effort selector in the same family that `omp models` reports, and marks the role as needing a choice when that family offers none.#
# New budget defaults use xhigh; unlimited raises effort but never invents provider slugs.
s#^\*\*\(b\) Apply it\.\*\*.*#**(b) Apply it.** Build the working table from the skill defaults, preserving saved per-role family, panel list, and aliases on a re-run. Apply `unlimited`, `large`, `medium`, and `small` as target reasoning efforts `max`, `xhigh`, `high`, and `medium` to every real model selection, including panel entries. Use only selectors and effort settings the detected runtime reports, never manufacture a model slug by changing a suffix. Choose the same family's highest available effort at or below the target; if none exists, mark the role as needing a choice. Keep `inherit-parent` and `auto` unchanged. The upstream defaults correspond to `large`. `unlimited` raises a family to `max` only when detected; a family capped at `xhigh`, such as upstream Grok, stays at `xhigh`. `small` targets `medium`. Read `skill://pstack-omp` and `skill://omp-mechanics` for the live configuration contract.#
# Upstream's new two-family panels stay two seats, not the old three-family default.
s#`claude-opus-[0-9.-]+-xhigh` and `grok-[0-9.]+-xhigh-fast`#your strongest judgment model and your fast code model#g
s#: claude-opus-[0-9.-]+-xhigh, grok-[0-9.]+-xhigh-fast$#: your strongest judgment model, your fast code model#
# Help's companion-plugin inventory must see raw names before generic tool substitutions.
s#^- `/deslop`, `control-cli`, and `control-ui` ship in the `cursor-team-kit` plugin\.$#- OMP maps the imported writing and verification names to available tools. Read `skill://pstack-omp` and use only tools exposed in this session.#
# These paragraphs describe Cursor model payloads; OMP binds discovered role agents instead.
s#^3\. Pick the runners\. Use the `arena runners` line.*#3. Pick the runners through `skill://pstack-omp`, preserving the saved `arena runners` panel and one participant per entry, including aliases. With no saved panel, use two independent candidates, one judgment-oriented and one fast-code-oriented, preferring different model families when configured. `auto` and `inherit-parent` preserve parent-model inheritance on task runtimes and never become task payload fields. Resolve rejected or unavailable model choices from detected runtime configuration, prefer the same family and reasoning tier, and report any fallback and actual resolved model. Do not change saved operator choices merely to run a panel. Spawn more when the arena covers multiple design directions. Same model N times when the work is generation-bound rather than judgment-sensitive.#
s#^Take the runners from the `architect runners` line.*#Take the runners from the saved `architect runners` panel through `skill://pstack-omp`, in place of `arena runners`. Without a saved panel, use two independent candidates, one judgment-oriented and one fast-code-oriented. Preserve aliases and configured panel size; unavailable model choices follow Arena's detected-configuration fallback and reporting rules.#
s#^After all Phase B candidates complete, choose one model from the `arena cross-judge pool` line.*#After all Phase B candidates complete, resolve one judge from the saved `arena cross-judge pool` through `skill://pstack-omp`. With no saved pool, prefer a judgment-oriented or fast-code-oriented judge on a different model family from the parent's when configured. Spawn one independent read-only judge with a write ban in its brief. It sees the rubric and the candidates by path label, scores each criterion, and recommends a base with rationale. It runs in parallel with the parent's reading in Phase D, not with the candidates themselves. Don't spawn the judge while candidates are still writing.#
s#^(Each spawn below|Each reviewer and the synthesizer) names a role line in the `pstack-models\.mdc` rule and a default\..*#Each participant names a role and default capability. Resolve its saved model choice through `skill://pstack-omp` against the live roster and configuration; never pass a per-call `model` field. Aliases preserve parent-model inheritance on task runtimes. Detect available models before choosing an equivalent fallback of the same family and reasoning tier, report rejected choices and actual resolved models, and keep saved user configuration unchanged during workflow execution.#
s#^- `model`: the `([^`]+)` line, default `[^`]+`$#- Model role: `\1`, resolved through `skill://pstack-omp` and saved runtime configuration, not a task payload field.#
s#^- `model`: the configured `interrogate reviewers` entry,.*#- Model role: each saved `interrogate reviewers` entry, preserving panel size and aliases through `skill://pstack-omp`. Never pass a per-call model field.#
s#^If the Task tool rejects a configured entry, run that reviewer.*#If the runtime cannot resolve a configured reviewer model, detect available equivalents and prefer the same family and reasoning tier. Report the fallback and actual resolved model, preserving the independent reviewer count. Do not block solely on an unavailable default when a detected equivalent exists. Never treat `auto` or `inherit-parent` as rejected model slugs. Do not rewrite saved operator configuration during the review; report any default-table correction separately.#
s#^4\. Pick the worker model from the `swarm workers` line.*#4. Resolve workers from the saved `swarm workers` role through `skill://pstack-omp`, preserving configured aliases and model choices. With no saved choice, use the fast-code capability available in the runtime. Never pass a per-call model field. If a model cannot resolve, choose a detected equivalent of the same family and reasoning tier and report the fallback and resolved model. For a race or comparison, resolve each arm's configured role independently; do not alter saved choices to manufacture diversity.#
s#with `model` from the `reflect judgment, divergent, synthesizer` line \(default `[^`]+`\)#with its synthesizer role resolved through `skill://pstack-omp` and saved runtime configuration, never a per-call model field#
s#^The default role-to-model mapping is the rule shape shown in step 5 below\..*#The table in step 5 names the pstack roles and upstream default capabilities. Read `task.agentModelOverrides`, `modelRoles`, and recorded budget through `skill://pstack-omp`; keep saved role choices, lists, aliases, and unrelated entries. Start only unconfigured pstack roles from detected equivalents of the defaults. Drop an entry only when the adapter identifies it as a retired pstack-owned role, and report what was dropped.#
# The help builtin inventory must also precede generic create-skill substitutions.
s#^- `/loop` and `/create-skill` are Cursor built-ins\.$#- OMP's `/loop` is a runtime command with different timing semantics. Skill authoring follows pstack's Authoring a skill playbook, not a Cursor builtin.#
# Cursor's multi-slug review panel -> one model per family, resolved at run time (backticked form).
s#(`claude-[a-z0-9.-]+`, `gpt-[a-z0-9.-]+`, `grok-[a-z0-9.-]+`(, `claude-[a-z0-9.-]+`)?|`claude-fable-5-1-thinking-max`, `gpt-5\.6-sol-max`, `grok-4\.6-fast-xhigh`, `claude-opus-5-thinking-xhigh`)#one model per distinct family `omp models` reports#g
# Same panel in the bare rule-file form, where the slugs carry no backticks.
s#(claude-[a-z0-9.-]+, gpt-[a-z0-9.-]+, grok-[a-z0-9.-]+(, claude-[a-z0-9.-]+)?|claude-fable-5-1-thinking-max, gpt-5\.6-sol-max, grok-4\.6-fast-xhigh, claude-opus-5-thinking-xhigh)#one model per distinct family omp models reports#g
# Cursor names the judgment slug twice in one clause; omp names the capability once.
s#go to your strongest judgment model \(`claude-[a-z0-9.-]+`\)#go to your strongest judgment model#
# Cursor lists its spawn parameters inline; on omp the whole list is one batched task call.
s#Spawn all N workers in one message with `subagent_type: generalPurpose`, `environment: "cloud"`, `run_in_background: true`, and the configured model\. Use `environment: "local"` only when the worker needs access to something on the user's computer\.#Spawn all N workers in one `task` call with all items in `tasks[]`, each item `agent`: `task` (omp's general-purpose bundled agent) with `isolated: true`. Every worker runs on this machine, so read `skill://omp-mechanics` for the isolation gate and the per-worker output fallback.#
s#Spawn all N subagents in one message with `run_in_background: true`, each with#Spawn all N subagents in one `task` call with all items in `tasks[]`, each with#
s#One message, three `Task` calls, `subagent_type: generalPurpose`, (explicit `model:` on each|with `model` set as below), agent mode \(`readonly: false`\)\.#One `task` call with three items in `tasks[]`, each `agent`: `task` (omp's general-purpose bundled agent) pinned by its own agent name, full tools per spawn. Run the three lenses on three different model families where `omp models` offers them, and keep Divergent on a different model family from Judgment, since the lens earns its name from different priors and not a different prompt.#
# A diverse-model review is a property of the reviewers, so each skill states it in its own steps.
s#extending or shrinking the Reviewer [A-Z/]+ labels below to the configured entry count\. (Otherwise|If the rule or that line is missing,) use the table defaults\.#extending or shrinking the Reviewer A/B/C/D labels below to the configured entry count. Otherwise use the table defaults. Give each reviewer a different model family from the other reviewers and from the parent that wrote the code, resolved at run time from what `omp models` reports. A reviewer sharing the writer's family shares the writer's blind spots, which is the one thing this skill exists to defeat. `skill://omp-mechanics` covers the single-family case.#
# Cursor reads the playbook from trunk because it is vendored there; omp reads the install.
s#Read these from trunk at program start\. Re-read them at every tick\.#Read these at program start and re-read them at every tick. The install on disk is authoritative, not a remote ref.#
# Cursor's rule file is the artifact step 5 writes; omp's is a keyed map in its own config.
s#Write `~/\.cursor/rules/pstack-models\.mdc`, an always-applied rule that sets pstack's model per role\.#Write `task.agentModelOverrides` in `~/.omp/agent/config.yml`, the keyed override map that sets pstack's model per role agent. The chat model stays the operator's choice, made with `/model`, and pstack never overrides it. `skill://omp-mechanics` holds the file shape.#
s|Write `~/\.cursor/rules/pstack-models\.mdc` with `alwaysApply: true`, a `# budget` line with the chosen label and its target effort, and one line per role, using the same labels poteto-mode uses. Overwrite the whole file so re-runs stay idempotent. Shape:|Write `task.agentModelOverrides` and `modelRoles` in `~/.omp/agent/config.yml`, with a `# budget` comment carrying the chosen label and its target effort, and one entry per role agent, using the same labels poteto-mode uses. Overwrite the whole pstack part of both maps so re-runs stay idempotent. The block below is the role-to-capability table and not the file format, which `skill://omp-mechanics` holds. Shape:|

## 2. Model slugs. Tiered by capability first, then a catch-all for anything upstream adds later.

# Cursor's strongest reasoning slug -> the judgment capability the operator binds.
s#`claude-fable-[0-9.-]+(-(thinking-)?[a-z]+)?`#your strongest judgment model#g
# Cursor's second reasoning family -> the same judgment capability.
s#`claude-opus-[0-9.-]+(-(thinking-)?[a-z]+)?`#your strongest judgment model#g
# Cursor's instruction-following slug -> the instruction-following capability.
s#`gpt-[0-9.]+-sol-[a-z]+`#your strongest instruction-following model#g
# Cursor's fast coding slug, with or without an effort suffix -> the fast code capability.
s#`grok-[0-9.]+-([a-z]+-)?fast(-[a-z]+)?`#your fast code model#g
# The same family under Cursor's provider prefix, effort token in the middle.
s#`cursor-grok-[0-9.]+-([a-z]+-)?fast`#your fast code model#g
# The same tiers where the rule-file example writes a role value with no backticks. Anchored to
# the end of a `<role>: <slug>` line, which is the only place upstream writes a bare slug.
s#: claude-(fable|opus)-[0-9.-]+(-(thinking-)?[a-z]+)?$#: your strongest judgment model#
s#: gpt-[0-9.]+-sol-[a-z]+$#: your strongest instruction-following model#
s#: grok-[0-9.]+-([a-z]+-)?fast(-[a-z]+)?$#: your fast code model#
# Catch-all for a slug no tier above knows. Two hyphen groups required, so an illustrative
# `gpt-4` rename example is not a prescription and survives. omp-port reports what this rewrote.
s#`(claude|gpt|grok|gemini|opus)-[a-z0-9.]+-[a-z0-9.-]+`#your configured model for this role#g

## 3. The task wire. Cursor's Task parameters -> omp's task tool fields.

# `subagent_type: "X"` (Cursor's agent selector) -> omp's `agent` field.
s#`subagent_type: "([^"]+)"`#`agent`: `\1`#g
s#`subagent_type: generalPurpose`#`agent`: `task` (omp's general-purpose bundled agent)#g
s#`subagent_type`: `generalPurpose`#`agent`: `task` (omp's general-purpose bundled agent)#g
s#`subagent_type`#`agent`#g
s#subagent_type#agent#g
# `generalPurpose` (Cursor's built-in general agent) -> `task`, omp's bundled general agent.
s#`generalPurpose`#`task` (omp's general-purpose bundled agent)#g
s#generalPurpose#`task` (omp's general-purpose bundled agent)#g
# Cursor's one-parameter background spawn -> omp batches every spawn in one tasks[] array.
s#\*\*Defaults for every `Task` call\.\*\* `run_in_background: true`,#**Defaults for every `Task` call.** One `task` call with all items in `tasks[]`, batched in parallel,#
s#`run_in_background: true`#one `task` call with all items in `tasks[]` (batched in parallel)#g
# Cursor's readonly spawn mode -> posture in the brief, because omp's task wire has no such field.
s#`readonly`: `true`#read-only posture. The brief grants only Glob, Grep, and Read, and forbids writes#g
s#agent mode \(readonly strips MCP\)#full tools per spawn#g
s#agent mode \(`readonly: false`\)#full tools per spawn#g
s#`readonly`: `false` \(agent mode\)\. \*\*Do not use readonly/Ask mode\.\*\* It strips MCP access, which disables#Full tools per spawn. There is no `readonly` field and no Ask mode on omp's task wire, so nothing strips MCP access, which would otherwise disable#
s#`readonly`: `false` \(agent mode\)\.#Full tools per spawn.#g
s#Readonly strips MCPs\.#There is no such field on omp's task wire, so nothing strips MCPs.#g
s#Readonly/Ask mode strips MCPs and defeats that\.#There is no such mode on omp's task wire, so nothing strips MCPs.#
s#Spawn one readonly judge subagent on that model\.#Spawn one judge subagent whose brief grants read tools only.#
s#readonly: true#read-only posture, granted in the brief#g
# Cursor's ask tool -> `ask`, omp's tool name.
s#`AskQuestion`#`ask`#g
s#AskQuestion#`ask`#g
s#`allow_multiple: true`#`allowMultiple: true`#g
# Cursor's per-role model rule file -> the keyed override map in omp's config.
s#`~/\.cursor/rules/pstack-models\.mdc`#`task.agentModelOverrides` in `~/.omp/agent/config.yml`#g
s#~/\.cursor/rules/pstack-models\.mdc#`task.agentModelOverrides` in `~/.omp/agent/config.yml`#g
# Cursor's Task-spawn slug enumeration and hypothetical models API -> `omp models`.
s#Enumerate the model slugs you can pass to a `Task` subagent in this session\. That is the dependable source\. If Cursor also exposes a models API or CLI that lists the user's entitled models, prefer it for completeness\.#Read `skill://pstack-omp` and inspect the live tools and schemas. On an OMP task runtime, use `omp models` when available to list configured models and effort selectors, then read the saved per-role configuration. On another runtime, use its exposed discovery and configuration contract. Model selection is runtime configuration, never a per-call task field.#
# Cursor's blocking watch mode -> the same hazard, named with omp's blocking primitive too.
s#Reaching for `drive` inside a phase agent stops that agent finishing its turn\.#Blocking on `drive`, or on `hub` `op: "wait"`, inside a phase agent stops that agent finishing its turn.#
# Cursor's Task `model` argument -> omp has no per-call field, only the keyed override map.
s#\(omit Task `model`\)#(leave it out of `task.agentModelOverrides`)#g
s#If the configured value is `inherit-parent` or `auto`, omit `model` instead\.#If the configured value is `inherit-parent` or `auto`, leave that reviewer out of `task.agentModelOverrides` instead.#
s#For a model race, name each arm's model up front\.#For a model race, give each arm its own agent file and its own `task.agentModelOverrides` entry.#
# Cursor writes an always-applied rule file; omp writes two keys in its own config.
s#Tell the user the rule was written and that it applies to new sessions\.#Tell the user which entries were written and that they apply to new sessions.#
s#Per-role lines in the `/setup-pstack` rule override#Per-role entries written by `/setup-pstack` override#g
/^alwaysApply: true$/d
# Cursor agent frontmatter `is_background` -> omp does not model it.
/^is_background: true$/d
# omp gates nested spawning per agent definition, which Cursor has no counterpart for.
/^name: poteto-agent$/a spawns: "*"
# The router and its agent must name the omp levers file themselves, not only the pin reminder,
# so an unpinned read of skill://poteto-mode or a spawned poteto-agent still finds it.
s|^## Non-negotiables$|## Non-negotiables\n\n**Read `skill://omp-mechanics` right after this file.** It holds the omp-specific levers every step below assumes, and it is the port's only hand-written skill.|
s#Reads the `poteto-mode` skill's `SKILL.md` in full before any work, including its inline Principles index\.#Reads the `poteto-mode` skill's `SKILL.md` in full before any work, including its inline Principles index, then `skill://omp-mechanics`.#
# Cursor derives a mode skill's registry name from a display title; omp uses the slug.
s#name: Poteto Mode#name: poteto-mode#

## 4. Cloud agents. Cursor runs them on its own VMs; omp runs isolated subagents on this machine.

s#`environment: "cloud"`#`isolated: true`#g
s#the full Task schema including `environment`#the full Task schema including `isolated`#g
# `cloud_base_branch` is not accepted by omp's task tool; a worktree on that base is the answer.
s#When a worker must start from a non-default pushed branch, pass `cloud_base_branch`\.#When a worker must start from a non-default base, create its `git worktree` on that base first and point the worker at that path.#
s#One Cursor cloud agent#One isolated subagent (`isolated: true`)#g
s#each a Cursor cloud agent#an isolated subagent (`isolated: true`)#g
s#Cloud agents cannot read the local store, so their briefs inline what they need or point at repo paths\.#An isolated worker runs on this machine in its own worktree with no conversation history, so its brief inlines what it needs or points at absolute paths.#
# Cursor's cloud dashboard -> `hub`, omp's live agent and job roster.
s#the cloud agent's status in the Cursor dashboard#agent state from `hub` `op: "list"` and `hub` `op: "jobs"`#
# Cursor's cloud PR tooling defaults to draft; omp's github tool defaults to ready.
s#Cloud-agent PR tools default to draft, so set `draft: false` on every PR creation call\.#omp's `github` tool opens a ready PR from `op: "pr_create"` unless you pass `draft: true`, so leave that flag off.#
s#Each live lane runs on its own cloud VM at the PR head\.#Each live lane runs in its own subagent at the PR head, asking for a private worktree with `isolated: true`.#
s#Fan out N parallel cloud workers\.#Fan out N parallel workers.#
s#N is total workers, not the cloud concurrency limit\.#N is total workers. `task.maxConcurrency` in `~/.omp/agent/config.yml` caps how many run at once.#
# Cursor hands out a cloud-agent URL; omp's prior-run handles are internal URIs.
s#cloud-agent URL#prior agent's `history://<id>` or `agent://<id>`#g
# Cursor's local-versus-cloud split -> shared parent checkout versus a private worktree.
s#cloud spawns#isolated spawns#g
s#its spawn budget with the cloud default and the local exception list#its spawn budget with the isolated default and the shared-checkout exception list#
s#Restacks run in cloud\. A local restack at this scale takes the laptop down\.#Restacks run in an isolated subagent with its own worktree, never in the parent checkout.#
s#After a Cursor restart: local agents are dead, cloud work is not\.#An omp restart stops every agent. Resuming the session rebuilds its subagents as parked rows that `hub` `op: "send"` revives, except isolated ones, which leave only a `history://<id>` transcript.#
s#reattach cloud work by PR and branch rather than agent id#reattach pushed work by PR and branch rather than agent id#
s#a Cursor restart#an omp restart#g
s#cloud agent#isolated subagent#g
s#Cloud agent#Isolated subagent#g

## 5. Wake mechanisms. Cursor's `/loop` builtin and cloud sleeper -> omp's `/loop`, hub, systemd.

s#Drive a long or stubborn hunt with Cursor's `/loop` command\.#Drive a long or stubborn hunt with omp's `/loop`, which re-submits the same prompt after every yield. State the exit condition as a shell command and pass it as `--until '<cmd>'`, which gates each iteration on that command's exit status.#
s#Pick the wake mechanism using Cursor's `/loop` command \(a built-in, not a pstack skill\)\.#Pick the wake mechanism. In session, omp's `/loop [count|duration] [--while|--until '<cmd>'] [prompt]` re-submits the prompt after every yield and gates each iteration on a shell command's exit status. A wake that must land out of session runs under a `hub` supervised watcher or a systemd user timer.#
s#A local root arms each tick as a real terminal `/loop`\. The loop uses a monitored-shell 30-minute sleep and emits an output-notification sentinel\.#A root in session arms each tick with omp's `/loop`, which re-submits the tick prompt after every yield.#
s#A cloud root uses the existing cloud-sleeper wake chain instead\.#A wake that has to land out of session runs under a `hub` supervised watcher or a systemd user timer instead.#
s#In a local session, a real terminal `/loop`\. In a cloud root, a cloud-sleeper wake chain\.#In session, omp's `/loop`. For a wake that must land out of session, a `hub` supervised watcher or a systemd user timer.#
s#Run `drive` and `background` under `/loop` in dynamic mode\.#Run `drive` and `background` under omp's `/loop` while `loop.mode` is `prompt`, or under a `hub` supervised watcher when the wake must land out of session.#
s#Hold the watch under `/loop` in dynamic mode\.#Hold the watch under omp's `/loop` while `loop.mode` is `prompt`, or under a `hub` supervised watcher when the wake must land out of session.#
s#`/loop` per component until the diff is zero\.#Hold a `hub` watcher or a systemd timer per component until the diff is zero.#
s#a frontier watcher wake \(arm it via the loop skill, with a long heartbeat fallback\)#a frontier watcher wake (hold it under a `hub` watcher or a systemd timer, with a long fallback heartbeat)#
s#"/loop until X"#"run until X"#g
# Cursor's `/goal` is on by default; omp ships it behind a settings gate.
s#arm a `/goal` with the full program objective\.#arm a `/goal` with the full program objective. omp's `/goal` is native but gated, so turn on `goal.enabled` in settings first. Since 18.0.2 the tool registers lazily, so turning it on mid-session also works.#g
s#arm a `/goal` with this exact text\.#arm a `/goal` with this exact text. omp's `/goal` is native but gated, so turn on `goal.enabled` in settings first. Since 18.0.2 the tool registers lazily, so turning it on mid-session also works.#

# Cursor /loop 1h is an hourly wake; OMP duration bounds a run, not its cadence.
s#arm(s)? `/loop 1h` with a prompt that runs this tick#arm\1 an hourly root-controlled timer with a prompt that runs this tick. Cursor's `/loop 1h` denotes this cadence; OMP's duration argument does not. Use only a scheduler or supervised process exposed by the live runtime, and report the missing wake capability when none exists#g
s#`/loop` works in local and cloud roots\.#Resolve the hourly wake through `skill://pstack-omp`; do not assume an out-of-session scheduler exists.#
s#arm the audit tick as `/loop 1h` with the tick prompt below#arm an hourly root-controlled timer with the tick prompt below. The upstream `/loop 1h` means an hourly cadence, not OMP's total run duration; detect an available scheduler or supervised process through the live runtime and report a missing wake capability#g
s#Re-read the execution playbook from trunk\. Audit the operation against it#Re-read the execution playbook from its loaded skill location. Audit the operation against it#g
## 6. cursor-team-kit. Cursor's companion plugin -> omp's built-in tools.

# `/deslop` -> the `unslop` skill plus `omp cleanse` for diagnostics.
s#the `deslop` skill from the `cursor-team-kit` plugin \(`/deslop`\)#the `unslop` skill (`skill://unslop`) plus `omp cleanse --all` for diagnostics#g
s#Run `/deslop` from `cursor-team-kit` over the diff before commit\.#Run the `unslop` skill (`skill://unslop`) plus `omp cleanse --all` over the diff before commit. A bare `omp cleanse` opens an interactive picker and blocks.#
s#`/deslop`#the `unslop` skill (`skill://unslop`) plus `omp cleanse --all`#g
# `control-ui` / `control-cli` -> `browser`, `computer`, and `hub` process ops plus bash.
s#`control-ui` or `control-cli` runtime verification \(from `cursor-team-kit`\)#`browser` or `computer` for UIs, or `hub` process ops plus bash for CLIs and TUIs#
s#\(`control-cli` or `control-ui` from `cursor-team-kit` as the change demands\)#(`browser` or `computer` for UIs, `hub` process ops plus bash for CLIs and TUIs, as the change demands)#
s#\(`control-ui` or `control-cli` from `cursor-team-kit` as the change demands\)#(`browser` or `computer` for UIs, `hub` process ops plus bash for CLIs and TUIs, as the change demands)#
s#Drive through `control-ui` or `control-cli` from `cursor-team-kit`\.#Drive through `browser` or `computer` for UIs, and `hub` process ops plus bash for CLIs and TUIs.#
s#Browser, Electron, and web UIs use `control-ui` from `cursor-team-kit`\. CLIs and TUIs use `control-cli` from `cursor-team-kit`\.#Browser, Electron, and web UIs use the `browser` eval prelude, and native desktop UIs use `computer`. Both are code in an `eval` cell and not tools. CLIs and TUIs use `hub` process ops plus bash.#
s#`cursor-team-kit` publishes `control-cli` \(CLIs and TUIs\) and `control-ui` \(browser / Electron / web UIs\)\.#omp provides the levers directly. `hub` process ops plus bash drive CLIs and TUIs, the `browser` eval prelude drives browser, Electron, and web UIs over CDP, and the `computer` prelude drives native desktop. Both preludes are code in an `eval` cell and neither is a tool with its own schema.#
s#\*\*Control skill\.\*\* Pick it by surface\.#**Control surface.** Pick it by surface.#
s#through the control skill's commands#through the control surface's own calls#
s#`control-ui`#the `browser` eval prelude#g
s#`control-cli`#`hub` process ops plus bash#g
s#`cursor-team-kit`#omp's built-in tools#g
s#cursor-team-kit#omp's built-in tools#g

## 7. create-skill. Cursor's SKILL.md authoring builtin -> pstack's own authoring playbook.

# The playbook cannot route to itself, so its step 1 states the omp authoring path directly.
s#^1\. Use the \*\*create-skill\*\* skill \(Cursor's built-in for authoring SKILL\.md files\)\.$#1. Write the SKILL.md yourself with `write` or `edit`. omp's `manage_skill` writes only under `~/.omp/agent/managed-skills` and never touches a user-authored skill. Give it YAML frontmatter with `name` matching its directory, a `description` naming what the skill does and when to reach for it, and `disable-model-invocation: true` so it stays out of the per-turn index.#
s#the \*\*create-skill\*\* skill \(Cursor's built-in for authoring SKILL\.md files\)#the **authoring-a-skill** playbook (`playbooks/authoring-a-skill.md`)#g
s#A `create-skill`-style#An `authoring-a-skill`-style#g
s#Cursor's built-in `create-skill` skill#the `authoring-a-skill` playbook#g
s#Cursor's built-in `create-skill`#the `authoring-a-skill` playbook#g
s#`create-skill`'s#the `authoring-a-skill` playbook's#g
s#new skill via create-skill:#new skill via authoring-a-skill:#g
s#draft a new skill via create-skill#draft a new skill via the authoring-a-skill playbook#g
s#via create-skill \+ unslop#via the authoring-a-skill playbook + unslop#g
s#`create-skill`#the `authoring-a-skill` playbook#g

## 8. Transcripts. Cursor's per-project transcript directory -> omp's session store.

s#`~/\.cursor/projects/<slug>/agent-transcripts/<uuid>/<uuid>\.jsonl`#the session store, by default `~/.omp/agent/sessions/<encoded-cwd>/<timestamp>_<session-id>.jsonl`#
s#where `<slug>` is the workspace path with the leading slash dropped and each "/" turned into "-" \(so `/Users/you/proj` becomes `Users-you-proj`\)#where `<encoded-cwd>` is the cwd with $HOME stripped and each "/" turned into "-" (so `~/proj` becomes `-proj`)#
s#Every line is one chat message\.#Every line is one JSON object. The first is a fixed-width `type:title` slot, the second a `type:session` header, and the rest messages whose roles are camelCase (`toolResult`, not `tool_result`).#
s#the active workspace's `agent-transcripts/` directory#the session transcript tree `~/.omp/agent/sessions/<encoded-cwd>/*.jsonl`, with subagent sidecars at `<session-stem>/<AgentId>.jsonl`#g
s#the workspace's `agent-transcripts/` directory#the session transcript tree `~/.omp/agent/sessions/<encoded-cwd>/*.jsonl`, with subagent sidecars at `<session-stem>/<AgentId>.jsonl`#g
s#local transcripts under `agent-transcripts/`#local transcripts under `~/.omp/agent/sessions/<encoded-cwd>/`#
s#`~/\.cursor/projects/\*/`#sibling `~/.omp/agent/sessions/<other-cwd>/` buckets#g
s#<agent-transcripts>#~/.omp/agent/sessions/<encoded-cwd>#g
# Cursor kept three historical transcript layouts; omp writes one.
s#Three transcript layouts: legacy flat \(`<id>\.jsonl`\), current nested \(`<id>/<id>\.jsonl`\), and subagent \(`<parent>/subagents/<child>\.jsonl`\)\.#One transcript layout. A flat `<timestamp>_<session-id>.jsonl` per session in the bucket, with `<AgentId>.jsonl` sidecars in the sibling directory named for that stem, and one further subdirectory per nesting level whose files carry the full dotted id.#
s#For each candidate, read the first JSONL line and check that `message\.content\[0\]\.text` contains the conversation's opening user prompt\.#The first line of an omp transcript is a fixed-width `type:title` slot and the second a `type:session` header, neither of them a message. For each candidate, scan for the first `type:message` line with `role:user` and check that its text contains the conversation's opening user prompt.#
# Cursor's skill roots -> omp's workspace, user, and plugin skill roots.
s#~/\.cursor/skills/#~/.omp/agent/skills/#g
s#\.cursor/skills/#.omp/skills/#g
s#, or plugin-installed paths under `~/\.cursor/plugins/`#, or plugin-installed paths under `~/.omp/plugins/node_modules/`#g
# Cursor's worktree path convention -> whatever path the local tool manages.
s#misses one that lives at `\.cursor/worktrees/myrepo/x`#misses one that lives at a tool-managed path like `.worktrees/myrepo/x`#
# Cursor's pinned-chat sidebar -> omp's live roster plus the session store.
s#The pinned and active chats are the real artifact \(principle-prove-it-works\)\. Get that set from the user or sidebar and cross-check every candidate\. The lever has marked `safe` a worktree the user had pinned, so the pinned set wins\.#The live omp sessions are the real artifact (principle-prove-it-works). Get that set from `hub` `op: "list"` plus the session store at `~/.omp/agent/sessions/<encoded-cwd>/`, confirm it with the user, and cross-check every candidate. The lever has marked `safe` a worktree a live session still owned, so the live set wins.#
s#report whether the chat is pinned or ongoing and which worktrees it touches#report whether the session is still live and which worktrees it touches#
s#A pinned chat spawns arena and repro trees into sibling worktrees via background subagents, and those are in use even when their names never hit the sidebar\.#A live session spawns arena and repro trees into sibling worktrees via background subagents, and those are in use even when `hub` `op: "list"` never names them.#
# Cursor exposes enabled MCP servers as a directory; omp lists them in one config file.
s#Before spawning investigators, list the available MCPs from the Cursor environment\. Use the available-tools map when present\. Otherwise inspect the `mcps/` directory Cursor exposes for enabled MCP servers\.#Before spawning investigators, list the available MCPs from the session environment. Use the available-tools map when present. Otherwise read `~/.omp/agent/mcp.json` for enabled MCP servers.#
# Cursor resumes an idle agent to reach it; omp messages it and leaves it running.
s#Agents are spawned, resumed, and drained only through the Task tool\.#Agents are spawned and drained only through the Task tool, and resumed only through `hub` messaging.#
# Bugbot is a Cursor product, so the rubric names what plays its part on omp.
s#^Use this reference when the Babysit playbook \(`\.\./playbooks/babysit\.md`\) handles Bugbot or review-automation comments\.#Use this reference when the Babysit playbook (`../playbooks/babysit.md`) handles Bugbot or review-automation comments. Bugbot is Cursor's hosted review product, so without it this rubric applies to whatever review bot posts on your PRs, including omp's own `security-reviewer`.#
# Net for any Cursor home path a later upstream commit introduces.
s#~/\.cursor/#~/.omp/#g


s#mention once that a Custom Mode keeps it on#mention once that each new task should explicitly invoke `/poteto-mode` on OMP#
s#No `task.agentModelOverrides` in `~/.omp/agent/config.yml` means `/setup-pstack` hasn't run for this user, so every role uses its default model\.#Check `task.agentModelOverrides` and `modelRoles` in `~/.omp/agent/config.yml` through the active adapter. Saved role choices remain authoritative; a missing pstack entry alone does not prove setup never ran, and an unconfigured task role inherits the parent model.#
s#When the model rule is missing and it matters#When no saved pstack role configuration is found and it matters#
s#every role keeps its default model until they run `/setup-pstack`#saved choices stay in effect, and unconfigured task roles inherit the parent model until configured with `/setup-pstack`#g
s#1\. Install with `/add-plugin pstack` in chat, or from Customize in the sidebar\.#1. Follow the OMP port's installation instructions at `https://github.com/deLiseLINO/pstack-omp`. Do not run Cursor's plugin command or change an installed plugin without authorization.#
s#It asks for a reasoning budget, maps a model to each role, and writes a rule\. The rule applies to new chats\.#It asks for a reasoning budget, maps detected models to roles, and updates the pstack entries in OMP configuration without replacing unrelated or saved user choices. Configuration applies to new sessions.#
s#A role set to `auto` or `inherit-parent` runs on the chat's model, which saves tokens when the chat runs on Auto or a cheaper model\.#A role set to `auto` or `inherit-parent` uses the parent chat model on task runtimes; the active adapter defines the corresponding behavior on other runtimes. A cheaper parent can reduce cost.#
s#^pstack is built for Cursor\. Its skills use the Agent Skills format,.*#This fork ports pstack's Agent Skills and workflows to OMP. `skill://pstack-omp` owns live dispatch, model configuration, and lifecycle mechanics. Inspect the exposed tools and schemas; do not assume per-task model fields, Custom Modes, cloud machines, or an out-of-session wake service.#
s#- Enter on `/poteto-mode` attaches the skill to one message\. It fades as the chat moves on\.#- Invoke `/poteto-mode` explicitly at the start of each task and read its playbook. Do not assume a slash invocation permanently attaches it to later turns.#
s#^- Option\+Enter on Mac or Alt\+Enter on Windows, or Use as Mode from the skill entry, makes it a Custom Mode\..*#- OMP does not use Cursor's keyboard shortcuts or Custom Mode UI. Keep the current playbook and gates explicit throughout the task.#
s#^- Cursor's docs list Custom Modes in the Agents Window and the CLI\..*#- When the subject changes, start the new task with `/poteto-mode` and match a fresh playbook.#
s#Link \[Cursor's skills docs\]\(https://cursor.com/docs/skills\) when this comes up\.#Link the OMP port's README at `https://github.com/deLiseLINO/pstack-omp` when this comes up; read `skill://pstack-omp` for execution mechanics.#
s#`/poteto-mode` already uses `poteto-agent` for the subagents its playbook steps spawn\. To get the same style from a subagent of your own, spawn it with `agent`: `poteto-agent`\.#Resolve subagent roles through `skill://pstack-omp` and the live roster. Use the optional `poteto-agent` only when discovered; otherwise give an available worker a standalone brief that loads `poteto-mode`.#
s#can start Cursor's own skill for the same job instead#can select another installed skill for the same job instead#
s#Cursor's Plan Mode works alongside it\.#Use the active runtime's planning mode only when exposed and compatible with the required work.#
s#It was started with Enter\. Start it as a Custom Mode, or start each task with `/poteto-mode`\.#Explicitly invoke `/poteto-mode` for each new task and keep the current playbook in context; do not rely on Cursor's Custom Mode UI.#
s#The rule from `/setup-pstack` applies to new chats\. Start one\.#The role configuration from `/setup-pstack` applies to new sessions. Start one and inspect resolved model metadata.#
s#Give each agent its own worktree, or run them as (cloud agents|isolated subagents), which each get their own machine\.#Give each writer its own worktree or verified runtime isolation. OMP workers share this machine, so separate ports and build output too.#
s#as cloud agents#as isolated workers on this machine#g
s#The links here point into the installed plugin, which the user may not be able to open, so give the user the file's public copy: `https://github.com/cursor/plugins/blob/main/pstack/` followed by its path\.#Read the actual installed sibling skill before recommending it. Public source copies live at `https://github.com/cursor/plugins/blob/main/pstack/` followed by the path. Guide links below are Cursor source, not installed OMP instructions; `skill://pstack-omp` takes precedence for all execution mechanics. Use the OMP fork's README for installation and configuration.#
s#\]\(\.\./\.\./docs/guide/([^)]*)\)#](https://github.com/cursor/plugins/blob/main/pstack/docs/guide/\1)#g
s#\]\(\.\./\.\./README\.md\)#](https://github.com/deLiseLINO/pstack-omp)#g
s#Detects your available models and writes an always-applied rule that overrides the skill defaults\.#Detects available models through the active adapter and updates the pstack-owned role configuration, preserving saved user choices and unrelated settings.#
# New PR tools retain upstream tracking semantics, but draft fields must exist in the schema.
s#A built-in PR tool can default to draft, so set `draft: false` on every creation call through it\.#A built-in PR tool can default to draft. Inspect its live schema and instructions, explicitly request a ready PR using supported fields, and mark it ready through that tool if needed. Pass `draft: false` only when the schema exposes that field.#


## 9. Install paths. pstack is vendored in Cursor's monorepo and installed as a plugin on omp.
## Order is load-bearing: the trunk-read rewrites and the checklist append run before the
## generic pstack/skills/ rewrite, which is guarded so it cannot re-match its own output.

# One product-repo line survives, so check-plan.mjs's `git show origin/main:` marker stays real.
\%^  - \[ \] `git show origin/main:pstack/skills/<each other leaf skill the program uses>`$%a\
  - [ ] `git show origin/main:<each skill or doc the product repo vendors itself>`
s#re-read this playbook from trunk with `git show origin/main:pstack/#re-read this playbook from its install path, `~/.omp/plugins/node_modules/pstack/#g
s#Re-read the execution playbook from trunk and the armed /goal#Re-read the execution playbook from its install path and the armed /goal#g
s#`git show origin/main:<control skill path>`#the omp doc for the control surface, such as `omp://tools/browser.md`, remembering that `browser` and `computer` are eval preludes rather than tools#
s#`git show origin/main:pstack/#`~/.omp/plugins/node_modules/pstack/#g
s#([^/])pstack/skills/#\1~/.omp/plugins/node_modules/pstack/skills/#g
# Cursor's npm scope for skill tooling -> the port's own scope.
s#@cursor-skill/#@omp-skill/#g
# Cursor auto-attaches a skill on a file-glob match; omp carries `globs` as metadata only.
s#^paths: \[#globs: [#
