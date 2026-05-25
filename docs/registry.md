# Registry

## v1 — GitHub-first (today)

There is **no central registry server** in production yet. Publishing is **GitHub-based**:

1. Push your package to a GitHub repo (`[package.repository].url` in `li.toml`).
2. Run `lip publish` (or `lip publish --github`) after `lic build` + `lit test --coverage`.
3. `lip` records metadata in **`lip/registry/index.json`** with a **`source: { type: "git", url, tag }`** pointer (for discoverability).
4. If `gh` is authenticated, `lip publish` also creates a **GitHub Release** tag `v{version}` on the package repo.

Consumers use **`lip add NAME git=https://github.com/org/pkg --tag v0.1.0`** or path deps for monorepos.

## Local filesystem index

`lip publish --registry PATH` writes only to a filesystem `index.json` under `PATH` (used in CI fixtures). The JSON shape matches the REST API fields (`tree_digest`, `proof_digest`, `coverage_pct`, optional `source`).

## Central DB on lidb (PH-DB-4)

The **v2 central registry** stores the index in **lidb** (Li-native Postgres-shaped engine), not in `index.json` and **not in SQLite**.

| Store | Role |
|-------|------|
| **lidb native** | Production path: WAL/heap engine, `migrations/001_registry.sql`, `liorm.execute` plans |
| **SQLite** | **PH-DB-1 smoke only** (`lidb` embed bridge) — not a ship target; remove when native exec lands |
| **`index.json`** | GitHub-first / filesystem publish until central DB is live |

| Artifact | Role |
|----------|------|
| [`registry/schema/registry-v1.sql`](../registry/schema/registry-v1.sql) | Canonical DDL (`packages`, `package_versions`, `publishers`, `attestations`, `yanks`, `blocklist`) |
| [`lidb` `migrations/001_registry.sql`](https://github.com/li-langverse/lidb) | Same tables applied by `lis db migrate` (PH-DB-1) |
| [`registry/api/openapi-stub.yaml`](../registry/api/openapi-stub.yaml) | REST contract for registry service v1 |
| [`scripts/registry_client.py`](../scripts/registry_client.py) | `lip publish --registry URL` HTTP client (POST publish) |

**Data model (summary):**

- **`packages`** — canonical name + optional `pkg_id` (e.g. `PKG-pkg-ok`)
- **`package_versions`** — `tree_digest`, `proof_digest`, `coverage_pct`, signatures, git `source_*`, SPDX/repository URLs
- **`publishers`** — ed25519 keys for manifest signing (Phase 8c)
- **`attestations`** — CI / repro attestation digests tied to a version
- **`yanks`** — withdrawn versions (excluded from default `lip install` resolution)
- **`blocklist`** — blocked package names, publisher keys, or digests

Active versions are exposed through the `registry_active_versions` view (non-yanked, non-blocklisted).

## `lip publish --registry` (HTTP client)

After local gates pass (`lip lock`, `lit test --coverage`, `lic build`), **`lip publish --registry URL`** posts a **PublishRequest** to the registry API:

| Flag / env | Purpose |
|------------|---------|
| `--registry URL` | Registry API base (`http://127.0.0.1:54322` or `…/v1`); `http(s)://` selects HTTP mode |
| `--registry PATH` | Filesystem index only (no HTTP) |
| `LIP_REGISTRY_TOKEN` | Bearer token for `POST /v1/packages/{name}/versions` |
| `--dry-run` | Skip index write / HTTP POST; print intended target |

Required JSON fields (OpenAPI): `version`, `tree_digest`, `proof_digest`, `coverage_pct` (from lock + `.lit/coverage_pct.txt`).

Implementation: [`scripts/registry_client.py`](../scripts/registry_client.py) — `publish_version()` → `POST {base}/v1/packages/{name}/versions`.

Integration tests start [`scripts/registry_mock_server.py`](../scripts/registry_mock_server.py) and assert the mock received digests + coverage.

## REST API

OpenAPI 3 spec: [`registry/api/openapi-stub.yaml`](../registry/api/openapi-stub.yaml).

| Method | Path | Purpose |
|--------|------|---------|
| `GET` | `/v1/packages` | List versions (`name`, pagination, `include_yanked`) |
| `GET` | `/v1/packages/{name}/{version}` | Fetch one version |
| `POST` | `/v1/packages/{name}/versions` | Publish (auth required) |
| `POST` | `/v1/packages/{name}/{version}/yank` | Yank (auth required) |

Publish body **must** include `tree_digest`, `proof_digest`, and `coverage_pct` (same as `registry/index.json` and `li.lock`).

## lidb + lis deployment flow

### Profiles

| Profile | Purpose | Ports (default) |
|---------|---------|-----------------|
| **`registry-min`** | Registry OLTP only — lidb in-process, REST API, migrations | API **54321**, DB wire **54322** |
| **`stack-full`** | Registry + **realtime** (PH-DB-7) + optional auth/storage flags | API **54321**, DB **54322**, realtime WS **54323** |

`stack-full` is defined in **lis** `profiles/stack-full.toml` (lands with lis PH-DB-5…7 PRs). Until then, use **`registry-min`** for publish E2E; enable realtime probe with `LIP_E2E_REALTIME=1` when the broker is up.

### Registry-min (publish path today)

```bash
# 1. Start embedded native lidb + registry HTTP
lis db start --profile registry-min
# Registry API: http://127.0.0.1:54321/v1  (not 54322 — that is Postgres wire)

# 2. Apply schema (first run or after lidb upgrade)
lis db migrate --profile registry-min

# 3. Issue a publisher token (dev profile maps to publishers.key_id)
export LIP_REGISTRY_TOKEN="$(lis registry token --profile registry-min)"

# 4. Publish from a package repo after gates
cd my-package && lic build && lit test --coverage
lip publish --registry http://127.0.0.1:54321

# 5. Verify index
curl -s "http://127.0.0.1:54321/v1/packages?name=my-package" | jq .
```

### Stack-full (registry + realtime)

```bash
# 1. Full vertical bundle (lidb native + registry REST + realtime broker)
lis db start --profile stack-full
lis db migrate --profile stack-full

# 2. Publish (same as registry-min)
export LIP_REGISTRY_TOKEN="$(lis registry token --profile stack-full)"
lip publish --registry http://127.0.0.1:54321

# 3. Realtime (WebSocket) — Supabase-shaped path
#    ws://127.0.0.1:54323/socket/websocket?apikey=...&vsn=1.0.0
# Cross-repo E2E: LIP_E2E_REALTIME=1 ./scripts/ph-db-registry-e2e-cross-repo.sh stack
```

**Production deployment (target):**

1. **lidb** — Li-native engine (no SQLite); `registry-v1.sql` / `migrations/001_registry.sql` applied via `lis db migrate`.
2. **lis** — `lis db start --profile stack-full` (or `registry-min` for registry-only); HTTP behind TLS at edge.
3. **Edge** — Caddy/nginx terminates TLS for `registry.li-langverse.example`, proxies API + realtime WS.
4. **Auth** — bearer tokens → `publishers.key_id`; OIDC for org publishers (later).
5. **Consumers** — `lip add NAME registry=https://registry.li-langverse.example/v1` (resolver wiring follows central install PH).

| Environment | Registry API base | Realtime WS | Notes |
|-------------|-------------------|-------------|--------|
| Local registry-min | `http://127.0.0.1:54321/v1` | — | `lis db start --profile registry-min` |
| Local stack-full | `http://127.0.0.1:54321/v1` | `ws://127.0.0.1:54323/socket/websocket` | `lis db start --profile stack-full` |
| CI mock | ephemeral port | optional TCP probe | `registry_mock_server.py`; realtime skip unless `LIP_E2E_REALTIME=1` |
| Production | `https://registry.li-langverse.example/v1` | `wss://…/socket/websocket` | DNS + TLS when wired |

Until the **lis** registry service ships in production, use **GitHub-first** publish (`lip publish --github`) or filesystem `--registry PATH`; the schema, OpenAPI, and HTTP client are the contract for **tier_db_registry** benchmarks.
