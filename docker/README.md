# Docker — coordination layer

Always-on stack that every AI worktree treats as ground truth. In-app
tasks, agent tokens, plans, work-queue all live in **one** Mongo. The
host's `dotnet run` / `flutter run` is still the fastest dev iteration
loop; this stack is for "stable env to point my AI at" + sharing +
eventual deployment.

## Quick start

```bash
docker compose -f docker-compose.dev.yml up
```

When healthy:
- frontend → http://localhost:8081
- backend → http://localhost:5163
- mongo → mongodb://localhost:27017

First boot pulls images and builds the backend / frontend (5–10 min on
slow links). Subsequent ups reuse the cache.

To rebuild after code changes:

```bash
docker compose -f docker-compose.dev.yml up --build
```

To stop and wipe DB:

```bash
docker compose -f docker-compose.dev.yml down -v
```

## Environment overrides

Either set in your shell or drop them in `.env` next to `docker-compose.dev.yml`
(gitignored — the example below is reference only):

| var              | default                       | meaning |
|------------------|-------------------------------|---------|
| `MONGO_DB`       | `mora_knode_dev`              | database name on the mongo instance |
| `MONGO_PORT`     | `27017`                       | host port for mongo (change to run a second stack) |
| `BACKEND_PORT`   | `5163`                        | host port for backend |
| `FRONTEND_PORT`  | `8081`                        | host port for frontend |
| `MORA_KNODE_API` | `http://localhost:5163`       | API base URL **baked into the frontend bundle at build time** — change it if hosting under a different domain |

Example `.env`:

```
MONGO_DB=mora_knode_dev
BACKEND_PORT=5163
FRONTEND_PORT=8081
```

## Running a parallel test stack (preview)

Once the work-queue endpoint lands (MK-82), each AI session can claim
work from the coordination stack and run its own throwaway test
environment alongside. The pattern:

```bash
# coordination (always on, real DB)
docker compose -p main -f docker-compose.dev.yml up -d

# isolated test stack — different project name + different ports + different DB
MONGO_PORT=27018 BACKEND_PORT=5263 FRONTEND_PORT=8181 MONGO_DB=mora_knode_test_a \
  docker compose -p test-a -f docker-compose.dev.yml up
```

`-p test-a` gives the second stack its own container/network/volume
namespace so they don't collide with the main one.

## Why these specific images

- **mongo:7** — matches the local dev convention. Volume `mongo-data`
  persists across `up` cycles (use `down -v` to wipe).
- **mcr.microsoft.com/dotnet/sdk:10.0 + aspnet:10.0** — multi-stage
  build keeps the runtime image slim. `appsettings.Local.json` is
  intentionally not copied; runtime config flows through env vars
  (`Mongo__ConnectionString`, `ASPNETCORE_ENVIRONMENT`).
- **ghcr.io/cirruslabs/flutter:stable** — official-ish flutter image
  with the SDK preinstalled. The `MORA_KNODE_API` arg is baked at
  *build time* because Flutter web reads `String.fromEnvironment` at
  compile, not runtime.
- **nginx:alpine** — tiny static server with SPA fallback (see
  `nginx.conf`).

## What's NOT in this stack

- No reverse proxy / ingress — frontend hits backend on the host port
  directly. Add a reverse proxy when you stop pointing dev browsers at
  `localhost`.
- No production-grade Mongo (no replica set, no auth) — this is a
  development environment.
- No CI integration — Phase 2+.
