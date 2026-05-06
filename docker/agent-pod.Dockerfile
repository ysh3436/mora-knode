# Standard base for an external AI agent pod that talks to the
# mora-knode work stack via REST + Gitea via git push.
#
# What's IN
#   - Debian 12 slim + Python 3 + Node.js + npm + git + curl + ssh + jq
#   - CrewAI (pip install crewai) — first-class Layer 1 runtime
#   - Bundled context at /opt/mora-knode-context/
#       api-reference.md           — REST spec the bot calls
#       workflow-guide.md          — operating patterns (plan / queue / git)
#       sub-agent-templates/*.md   — Claude Code .claude/agents/ starting points
#       crewai-recipe/             — agents.yaml / tasks.yaml / main.py sample
#   - /usr/local/bin/mora-pod-scaffold — one shot to populate /work
#   - ENTRYPOINT script: env validation + mora-knode health check + token check
#
# What's NOT IN (intentionally — ADR-005, ADR-010)
#   - The paired LLM CLI. Subscriptions are per-user (Claude Pro,
#     ChatGPT Pro, Cursor Pro, ...) so the operator picks one and installs
#     it after first boot:
#         npm install -g @anthropic-ai/claude-code   # Claude Pro
#         npm install -g @openai/codex                # ChatGPT Pro
#         pip install <self-hosted-agent>             # custom
#     Or mount the host binary:
#         docker run -v $(which claude):/usr/local/bin/claude:ro ...
#   - .NET / Flutter SDK. Most pods don't rebuild mora-knode itself; if
#     yours does, install on demand inside the pod or fork this image.
#
# Build
#   docker build -t mora-agent-pod -f docker/agent-pod.Dockerfile .
#
# Run (Claude Code on Claude Pro)
#   docker run -d --name pod-manager-a \
#     -e MORA_KNODE_API=http://host.docker.internal:5163 \
#     -e MORA_KNODE_AGENT_ID=<resource id> \
#     -e MORA_KNODE_AGENT_TOKEN=mk_<...> \
#     -e MORA_KNODE_AGENT_ROLE=manager \
#     -v "$PWD/worktree-a:/work" \
#     mora-agent-pod
#   docker exec -it pod-manager-a bash
#   # inside:
#   mora-pod-scaffold --role manager
#   npm install -g @anthropic-ai/claude-code
#   claude

FROM debian:12-slim

ENV DEBIAN_FRONTEND=noninteractive \
    PIP_NO_CACHE_DIR=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    NODE_MAJOR=20

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        git \
        jq \
        nodejs \
        npm \
        openssh-client \
        python3 \
        python3-pip \
        python3-venv \
 && rm -rf /var/lib/apt/lists/*

# CrewAI is the 1순위 Layer 1 framework on this image. Pinning a major
# version (~=0.140) keeps the bundled recipe runnable; bump as CrewAI
# stabilises new APIs.
RUN pip install --break-system-packages "crewai~=0.140"

# Bundled context: read by the bot on first boot to learn the API +
# the dogfooding workflow. Kept in /opt so /work stays purely user data.
COPY docker/agent-pod-context/ /opt/mora-knode-context/

# Scaffold script: docker exec mora-pod-scaffold --role <role>
# populates /work with .claude/agents + .env + crewai recipe sample.
COPY docker/agent-pod-scaffold.py /usr/local/bin/mora-pod-scaffold
RUN chmod +x /usr/local/bin/mora-pod-scaffold

# Entrypoint: validates env, checks mora-knode reachability + token,
# prints a one-screen welcome that points the operator at scaffold +
# paired-CLI install.
COPY docker/agent-pod-entrypoint.sh /usr/local/bin/agent-pod-entrypoint
RUN chmod +x /usr/local/bin/agent-pod-entrypoint

WORKDIR /work
ENTRYPOINT ["/usr/local/bin/agent-pod-entrypoint"]
CMD ["sleep", "infinity"]
