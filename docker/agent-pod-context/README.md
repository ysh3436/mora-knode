# mora-knode agent pod context

This directory is **mounted into every pod at `/opt/mora-knode-context/`**.
It is the bot's first-time orientation pack: API spec, operating patterns,
sub-agent starting points, and a runnable CrewAI recipe.

The files here are kept in sync with the canonical sources under
`docs/` of the mora-knode repo so the pod always reflects the live API
and workflow.

## What's in here

| File / dir | What it is | Source of truth |
|---|---|---|
| `api-reference.md` | REST endpoints + auth + wire format the pod calls | [docs/api/external-agent-api.md](../../docs/api/external-agent-api.md) |
| `workflow-guide.md` | Operating patterns (plan / queue / git) | [docs/dogfooding/agent-operations.md](../../docs/dogfooding/agent-operations.md) |
| `sub-agent-templates/manager.md` | `.claude/agents/manager.md` starting point | (template) |
| `sub-agent-templates/developer.md` | `.claude/agents/developer.md` starting point | (template) |
| `sub-agent-templates/researcher.md` | `.claude/agents/researcher.md` starting point | (template) |
| `sub-agent-templates/qa.md` | `.claude/agents/qa.md` starting point | (template) |
| `crewai-recipe/agents.yaml` | CrewAI agent definitions for the 4 roles | (template) |
| `crewai-recipe/tasks.yaml` | CrewAI task patterns (plan / claim / report) | (template) |
| `crewai-recipe/main.py` | Runnable entry — `python main.py` starts the pod loop | (template) |

## How the pod uses it

1. **Entrypoint** (`/usr/local/bin/agent-pod-entrypoint`) prints a one-screen
   welcome that points at `mora-pod-scaffold` and the paired-CLI install.
2. **`mora-pod-scaffold --role <role>`** copies the chosen sub-agent
   template into `/work/.claude/agents/<role>.md`, copies
   `crewai-recipe/` into `/work/crewai-recipe/`, and writes a `.env`
   from the pod's environment variables.
3. The bot (Claude Code, Codex, or your CrewAI script) reads
   `api-reference.md` + `workflow-guide.md` to learn the protocol, then
   either runs through `.claude/agents/<role>.md` (Claude Code) or via
   `crewai run` (CrewAI) — either way it talks to the work stack at
   `$MORA_KNODE_API`.

## Updating

When the API or the workflow changes, regenerate the bundled copies
from the live docs and rebuild the image. The simplest pipeline is to
keep the files here as plain copies and refresh them on every release;
a follow-up task will introduce a `docker/agent-pod-context/sync.sh`
script that does this automatically. (For now: edit by hand to mirror
the canonical docs.)
