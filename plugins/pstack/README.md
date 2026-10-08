# pstack for oh-my-pi

Lauren Tan's pstack methodology, ported to omp. 53 skills, 23 playbooks, 24 principle
leaves, the `poteto-mode` pin, and the `poteto-agent` and `comment-sicko` agents.
51 skills are built from upstream; `omp-mechanics` and `pstack-omp` are port adapters.

## Install

```
/marketplace add deLiseLINO/pstack-omp
/marketplace install pstack@pstack-omp
```

That loads the 53 skills and the `potetomode` extension. The two agents are optional.
On omp 18.1.13 a marketplace plugin's `agents/` directory is scanned only through the
`claude-plugins` discovery provider, and enabling that provider also loads every Claude Code
plugin cached under `~/.claude/plugins`. Link the agents into omp's native root instead:

```
mkdir -p ~/.omp/agent/agents
ln -s ../../plugins/node_modules/pstack/agents/poteto-agent.md  ~/.omp/agent/agents/poteto-agent.md
ln -s ../../plugins/node_modules/pstack/agents/comment-sicko.md ~/.omp/agent/agents/comment-sicko.md
```

`node_modules/pstack` is the symlink the marketplace install maintains, so `/marketplace upgrade`
moves the agents with it. Check with a fresh session:

```
omp -p --no-session --thinking off "Do not call any tool. List every agent name in the task tool's Available Agents section."
```

Use these optional agents only when the live roster lists them; otherwise the adapter maps the role to an available worker.

Then `/poteto-mode on`, or `alt+shift+t`, or `omp -p --poteto '...'` for headless runs.

## What differs from upstream

Cursor mechanics are mapped to the live OMP tools. Writers use verified runtime isolation
when available. Long-running work requires an exposed watcher or scheduler; OMP's
`/loop` duration is not an hourly interval. The runtime adapter resolves transcript access
and model routing without replacing saved operator choices.

`PORTING.md` at the repo root records every substitution and the re-sync procedure.

## Model for the agent

`poteto-agent` ships model-free and inherits your chat model. To pin it, add
`model: "@poteto"` to the agent file and bind `poteto` in `modelRoles`. An unbound
alias fails the spawn, so bind before you add. `/setup-pstack` walks through it.

## Version 0.15.15

The port includes `/correct`, `/benchmark-checklist`, `/poteto-help`, and
`principle-explain-the-number`. Follow-ups use fresh workers unless costly checkout,
uncommitted changes, or live process state requires retaining the owner.
