# Disclaimer

Mora Knode is provided as-is. The source code is published for portfolio review only — see [LICENSE](LICENSE). This document supplements that notice with operational disclaimers specific to the AI-agent host model.

## 1. Autonomous AI agent actions

External AI agents connected to mora-knode through the Agent Identity & API ([ADR-004](docs/architecture/ADR-004-agent-identity-and-api.md)) may take autonomous actions including but not limited to:

- creating Git branches and commits
- opening pull requests
- modifying task schedules and matrix assignments
- submitting plans for review
- changing task statuses and resource assignments

You are responsible for monitoring agent outputs. mora-knode provides the orchestration scaffolding (plan gate, RBAC, audit trail). It does not guarantee that agents will not make mistakes, take unintended actions, or produce defective work.

## 2. Your responsibilities

You are solely responsible for:

- **Plans you approve.** Once a plan is approved through the Plan Gate ([ADR-002](docs/architecture/ADR-002-manager-approval-gate.md)), the consequences of its execution belong to you, not to mora-knode.
- **RBAC permissions you grant.** If you grant `approve plan` permission to an agent and that agent approves a destructive plan, the consequences belong to you.
- **Your LLM contracts and costs.** mora-knode does not call LLMs and does not know what your agents pay, which models they use, or where their data is sent ([ADR-005](docs/architecture/ADR-005-mora-knode-does-not-orchestrate-llms.md)).
- **Your data.** Backups, security, encryption at rest, and regulatory compliance (GDPR, SOC 2, HIPAA, PIPA, etc.) are your responsibility on self-hosted deployments.
- **Compliance with each external agent tool's terms of service.** Claude Code, Cursor, Cline, OpenHands, and other tools have their own ToS that govern your use of them; mora-knode does not negotiate or warrant those terms.

## 3. mora-knode's responsibility (limited)

To the limited extent any responsibility is asserted, it concerns only the correctness of mora-knode's own orchestration logic — that the plan gate enforces approval, that RBAC denies unauthorized actions, that the audit trail records changes. The source is otherwise published as-is, with no warranty of any kind.

mora-knode is **not** responsible for:

- LLM responses, hallucinations, or biases from any model
- behavior of external agent tools (Claude Code, Cursor, Cline, custom bots, etc.)
- consequences of approvals, RBAC grants, or matrix configurations you choose to make
- losses caused by your bypassing built-in safeguards
- third-party services your agents connect to (Git hosts, APIs, integrations)

## 4. Safeguards — do not bypass

mora-knode includes safety mechanisms whose bypass voids the limited responsibility above:

- 5-revision plan limit
- Human-only `approve plan` permission by default
- Audit trail (`ScheduleChangeLog.ChangedBy`)
- Destructive Git command guards recommended at the agent-tool level (see [agent-operations.md §5](docs/dogfooding/agent-operations.md))

If you patch external agent tools to skip these gates, grant `approve plan` permission to an agent without independent review, or disable audit logging, the consequences are yours and not mora-knode's.

## 5. Production usage warning

mora-knode is in active development through M5 (2026-12 ~ 2027-01). Until then it is **not certified for production use**. Use in production environments — including but not limited to systems handling critical infrastructure, financial transactions, healthcare data, or personally identifiable information — is at your own risk and may require additional safeguards, contracts, and licensing not yet provided by mora-knode.

## 6. No warranty for dogfooding metrics

Any metrics published in this repository — revision counts, matrix utilization, plan accuracy, or other figures from the maintainer's dogfooding — are illustrative only. They do not guarantee similar results in your environment, with your agents, on your hardware, or under your workload.

## Future updates

A formal EULA and SLA will be drafted at M5 (general availability), with legal review covering Korean, US, and EU jurisdictions. Until then, this document is the authoritative supplemental disclaimer.

— maintained by ysh, NilPop · 2026~
