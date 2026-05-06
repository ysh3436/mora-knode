# Docker — work stack + agent pod

Two pieces, one workflow:

1. **`docker-compose.yml`** spins up the **work stack** (mongo + backend +
   frontend + Gitea). One stack, always-on, single source of truth for
   in-app tasks / agent tokens / plans / git remote.
2. **`agent-pod.Dockerfile`** builds the **AI agent pod** image — the
   container an external agent (CrewAI + paired CLI) lives in. dev /
   test isolation lives at the pod level, not in extra mora-knode
   stacks. See [agent-pod-README.md](agent-pod-README.md).

Both decisions are recorded in
[ADR-010](../docs/architecture/ADR-010-self-hosted-infra.md).

## Quick start

```bash
cp .env.example .env       # in the repo root, gitignored
docker compose up -d
```

When healthy:

| Service  | URL                                       |
|----------|-------------------------------------------|
| frontend | http://localhost:8081                     |
| backend  | http://localhost:5163  (`/health` returns `{"status":"ok"}`) |
| mongo    | mongodb://localhost:27017                 |
| Gitea    | http://localhost:3000  (web), :2222 (ssh) |

First boot pulls images and builds backend + frontend (~5–10 min on a
slow link). Subsequent `up` cycles reuse the cache.

```bash
docker compose up -d --build       # rebuild after code changes
docker compose down                # stop, keep volumes
docker compose down -v             # stop and wipe data — careful, work DB lives here
```

## Environment overrides

All runtime configuration flows through env vars. Edit `.env` in the
repo root (gitignored — see `.env.example` for the template):

| var               | default                  | meaning |
|-------------------|--------------------------|---------|
| `MONGO_DB`        | `mora_knode_work`        | database name on the mongo instance |
| `MONGO_PORT`      | `27017`                  | host port for mongo |
| `BACKEND_PORT`    | `5163`                   | host port for backend |
| `FRONTEND_PORT`   | `8081`                   | host port for frontend |
| `GITEA_HTTP_PORT` | `3000`                   | host port for Gitea web / HTTP git |
| `GITEA_SSH_PORT`  | `2222`                   | host port for Gitea SSH git |
| `MORA_KNODE_API`  | `http://localhost:5163`  | API base URL **baked into the frontend bundle at build time** |

## Gitea — first-run setup

Gitea uses SQLite (volume `gitea-data`) — fine for a 1-person dogfooding
loop. To upgrade later: stop the stack, swap the env to point at a
postgres service, restore from backup. Out of scope for v1.

```bash
# 1. Open http://localhost:3000 in a browser → install screen.
#    Defaults are mostly fine; pick your admin username + password.

# 2. Create the mirror repo:
#    UI → '+' → New repository → owner=<you>, name=mora-knode

# 3. Add the local Gitea as a git remote and push:
git remote add gitea http://localhost:3000/<you>/mora-knode.git
git push gitea master
```

Gitea's HTTP API (port 3000) is enough for the dogfooding loop. SSH
(port 2222) is provided for completeness but the Windows firewall may
block it; HTTP works around this.

## Cutover — retiring the host mongod

If you used to run mongod directly on the host with a `mora_knode_dev`
database, migrate it into the docker mongo as `mora_knode_work` once.
This is a one-shot procedure, ~30 minutes. Roll-back is C.7 below.

```powershell
# C.1  preflight: confirm host mongod is up + dump
mongosh --eval "db.runCommand({ping:1})"
mongosh mora_knode_dev --eval "db.getCollectionNames().forEach(c => print(c, db[c].countDocuments()))"
mkdir tools\backups\cutover-2026-05-NN

# C.2  backup
mongodump --db mora_knode_dev --out tools\backups\cutover-2026-05-NN\

# C.3  free port 27017 + start docker mongo only
net stop MongoDB
copy .env.example .env
docker compose up -d mongo
docker compose ps          # mongo: healthy

# C.4  restore into the docker mongo, renaming dev -> work
mongorestore --port 27017 `
  --nsInclude="mora_knode_dev.*" `
  --nsFrom="mora_knode_dev.*" `
  --nsTo="mora_knode_work.*" `
  tools\backups\cutover-2026-05-NN\
mongosh --port 27017 mora_knode_work --eval "db.getCollectionNames().forEach(c => print(c, db[c].countDocuments()))"

# C.5  start the rest of the stack + verify data preserved
docker compose up -d
curl http://localhost:5163/health
curl http://localhost:5163/api/projects | python -c "import json,sys; print([p['name'] for p in json.load(sys.stdin)])"
# expect: 'mora-knode itself' is in the list

# C.6  retire the host mongod permanently
#      services.msc → MongoDB Server → Startup type = Disabled
#      (do not uninstall — keep it as a fallback for a few weeks)

# C.7  rollback (only if C.4 / C.5 fail)
docker compose down
net start MongoDB
dotnet run --project src\backend
```

## Running an agent pod alongside

Once the work stack is up and an agent identity has been issued in the
mora-knode UI, build and run the pod image — see
[agent-pod-README.md](agent-pod-README.md) for the full operator
workflow. Short version:

```bash
docker build -t mora-agent-pod -f docker/agent-pod.Dockerfile .

docker run -d --name pod-developer-a \
  -e MORA_KNODE_API=http://host.docker.internal:5163 \
  -e MORA_KNODE_AGENT_ID=<resource-id> \
  -e MORA_KNODE_AGENT_TOKEN=mk_<...> \
  -e MORA_KNODE_AGENT_ROLE=developer \
  -v "$PWD/worktree-a:/work" \
  mora-agent-pod
```

The pod's entrypoint validates the env, hits `$MORA_KNODE_API/health`,
verifies the token, and points at `mora-pod-scaffold` for `/work`
setup.

## What this stack does NOT include

- **Replica set / authentication on mongo** — local-dev defaults; do
  not expose port 27017 outside the host without putting auth on first.
- **CI / build pipeline** — not in scope until M3.
- **Reverse proxy / TLS** — frontend hits backend on the host port
  directly. Add a proxy when you stop pointing dev browsers at
  `localhost`.
- **dev / test stacks of mora-knode itself** — see ADR-010: isolation
  for AI work moved to pod level (multiple `mora-agent-pod` containers
  with different worktree mounts and prefix conventions in the work
  DB) rather than spawning extra mora-knode stacks.
