# mora-knode agent pod — operator guide

Run an external AI agent against the mora-knode work stack via REST +
local Gitea, in a self-contained docker container. This image bundles
CrewAI, the API + workflow context, and a one-shot scaffold script;
the LLM CLI itself (Claude Code, Codex, ...) is not bundled — install
whatever you have a subscription for.

See [ADR-010](../docs/architecture/ADR-010-self-hosted-infra.md) for
the design decision.

## Quick start

Prerequisite: the work stack is up (`docker compose up -d` from the
repo root) and you have created an agent identity + raw token in the
mora-knode UI (`/agents` → "+ Add").

```
# 1. Build the image (once)
docker build -t mora-agent-pod -f docker/agent-pod.Dockerfile .

# 2. Start a pod (Manager role, with a host-mounted worktree)
docker run -d --name pod-manager-a \
  -e MORA_KNODE_API=http://host.docker.internal:5163 \
  -e MORA_KNODE_AGENT_ID=<resource-id> \
  -e MORA_KNODE_AGENT_TOKEN=mk_<...> \
  -e MORA_KNODE_AGENT_ROLE=manager \
  -v "$PWD/worktree-manager-a:/work" \
  mora-agent-pod

# 3. Look at the entrypoint output (env / health / token check)
docker logs pod-manager-a

# 4. First-time scaffold (writes /work/.env, .claude/agents/manager.md,
#    crewai-recipe/, README-pod.md)
docker exec pod-manager-a mora-pod-scaffold --role manager

# 5. Install your paired LLM CLI inside the pod
docker exec -it pod-manager-a bash
#   inside:
npm install -g @anthropic-ai/claude-code      # if Claude Pro
# or
npm install -g @openai/codex                  # if ChatGPT Pro

# 6a. Drive the pod via your CLI:
claude    # uses .claude/agents/manager.md as the sub-agent
# 6b. Or run the bundled CrewAI scaffold loop:
cd /work/crewai-recipe && python main.py
```

## What's IN the image

| Layer | What | Why |
|---|---|---|
| Base | `debian:12-slim` | Small, predictable, plenty of glibc compatibility |
| Runtime | Python 3 + Node.js 20 + git + curl + ssh + jq | What every modern AI tooling pipeline ends up needing |
| Framework | CrewAI (~=0.140) | Default Layer 1 framework per agent-operations.md §8 |
| Context | `/opt/mora-knode-context/` | API reference + workflow guide + sub-agent templates + CrewAI recipe |
| Helper | `/usr/local/bin/mora-pod-scaffold` | One shot to populate `/work` per role |
| Helper | `/usr/local/bin/agent-pod-entrypoint` | Boot-time env / health / token checks |

## What's NOT IN the image (deliberately)

- **The paired LLM CLI** (`@anthropic-ai/claude-code`, `@openai/codex`,
  Cursor CLI, ...). Subscriptions are per-operator and per-account,
  and the choice is not mora-knode's to make ([ADR-005](../docs/architecture/ADR-005-mora-knode-does-not-orchestrate-llms.md)).
  Install one inside the pod, or mount the host binary:
  ```
  docker run -v $(which claude):/usr/local/bin/claude:ro ...
  ```
- **.NET / Flutter SDK**. Most pods don't rebuild mora-knode itself —
  they only call its API. If you need to build mora-knode from inside
  the pod, install the SDK on demand or fork this Dockerfile.

## Worktree mounts

Each pod gets its own `/work` host-mounted from a separate directory so
two pods don't fight over the same `.claude/agents/`, `.env`, or git
worktree:

```
docker run -v $PWD/worktree-manager-a:/work    mora-agent-pod ...
docker run -v $PWD/worktree-developer-b:/work  mora-agent-pod ...
```

If the pod will operate on the mora-knode source itself (e.g. a
Developer pod fixing a bug), make `/work` a freshly checked out copy
of the repo (`git clone http://host.docker.internal:3000/<...>/mora-knode.git /work` after entering the pod).

## Data isolation in `mora_knode_work`

mora-knode runs a single DB; pods share it. Use prefixes when creating
demo / sandbox data so the operator can filter pod activity from real
work:

- `[smoke-<run>] ...` for one-shot E2E checks
- `[pod-<name>-test] ...` for a pod's own scratchpad

Real dogfooding work stays unprefixed (the in-app project
"mora-knode itself" + its MK-N tree).

## Customising the image

The image is a starting point — fork it freely. Common variations:

- Add `.NET SDK 10` for pods that build mora-knode itself.
- Add Flutter SDK for pods that build the frontend.
- Pin `CrewAI~=0.X` to the version your operator scripts assume.
- Pre-install your paired CLI if you don't mind tying the image to a
  subscription.

## Updating the bundled context

`/opt/mora-knode-context/` is plain markdown copied from `docs/`. When
the API or workflow changes, the simplest path is to update both the
canonical `docs/...` file and the bundled copy under
`docker/agent-pod-context/...` in the same commit, then rebuild the
image. A follow-up task will introduce a sync script.
