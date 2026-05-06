#!/bin/bash
# mora-knode agent pod entrypoint
#
# Runs on every container start:
#   1. Validates required env vars (MORA_KNODE_API / AGENT_ID / TOKEN).
#   2. Health-checks the work stack at $MORA_KNODE_API/health.
#   3. Verifies the token is accepted on /api/agents/work-queue.
#   4. Prints next-step hints (scaffold + paired-CLI install) on first boot.
#   5. Exec's into the CMD (default: sleep infinity, so docker exec works).

set -euo pipefail

bar() { printf '=%.0s' {1..58}; echo; }

bar
echo "  Mora Knode agent pod"
bar

: "${MORA_KNODE_API:?ERROR: MORA_KNODE_API required (e.g. http://host.docker.internal:5163)}"
: "${MORA_KNODE_AGENT_TOKEN:?ERROR: MORA_KNODE_AGENT_TOKEN required (mk_...)}"
: "${MORA_KNODE_AGENT_ID:?ERROR: MORA_KNODE_AGENT_ID required}"

echo "Mora Knode  : ${MORA_KNODE_API}"
echo "Agent ID    : ${MORA_KNODE_AGENT_ID}"
echo "Role        : ${MORA_KNODE_AGENT_ROLE:-(unset)}"
echo

echo -n "1/2  health check ... "
if ! curl -sf --max-time 5 "${MORA_KNODE_API}/health" > /dev/null; then
    echo "FAIL"
    echo
    echo "    The work stack at ${MORA_KNODE_API} did not answer."
    echo "    - On the host, run: docker compose up -d"
    echo "    - From inside a container, the host is host.docker.internal"
    echo "      (Linux: add --add-host=host.docker.internal:host-gateway)"
    exit 1
fi
echo "ok"

echo -n "2/2  token check  ... "
if ! curl -sf --max-time 5 \
        -H "Authorization: Bearer ${MORA_KNODE_AGENT_TOKEN}" \
        -H "X-Agent-Id: ${MORA_KNODE_AGENT_ID}" \
        "${MORA_KNODE_API}/api/agents/work-queue" > /dev/null; then
    echo "FAIL"
    echo
    echo "    The token was rejected. Check that"
    echo "    MORA_KNODE_AGENT_ID matches the token owner and that the"
    echo "    token has not been rotated or revoked."
    exit 1
fi
echo "ok"

echo

if [ ! -e /work/.env ]; then
    echo "First boot — populate /work with:"
    echo "    mora-pod-scaffold --role ${MORA_KNODE_AGENT_ROLE:-developer}"
    echo
    echo "Then install your paired LLM CLI inside the pod, e.g.:"
    echo "    npm install -g @anthropic-ai/claude-code   # Claude Pro"
    echo "    npm install -g @openai/codex                # ChatGPT Pro"
    echo
fi

echo "Bundled context at /opt/mora-knode-context/"
echo "Pod ready."
echo

exec "$@"
