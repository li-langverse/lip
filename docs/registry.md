# Registry

## v1 — GitHub-first (today)

There is **no central registry server** in production yet. Publishing is **GitHub-based**:

1. Push your package to a GitHub repo (`[package.repository].url` in `li.toml`).
2. Run `lip publish` (or `lip publish --github`) after `lic build` + `lit test --coverage`.
3. `lip` records metadata in **`lip/registry/index.json`** with a **`source: { type: "git", url, tag }`** pointer (for discoverability).
4. If `gh` is authenticated, `lip publish` also creates a **GitHub Release** tag `v{version}` on the package repo.

Consumers use **`lip add NAME git=https://github.com/org/pkg --tag v0.1.0`** or path deps for monorepos.

## Local filesystem index

`lip publish --registry PATH` writes only to a filesystem index (used in CI fixtures). The JSON shape matches the REST API fields (`tree_digest`, `proof_digest`, `coverage_pct`, optional `source`).

## Central DB on lidb (PH-DB-4)

The **v2 central registry** stores the index in **lidb** (Li-native Postgres-shaped engine), not in `index.json`.

| Artifact | Role |
|----------|------|
| [`registry/schema/registry-v1.sql`](../registry/schema/registry-v1.sql) | Canonical DDL (`packages`, `package_versions`, `publishers`, `attestations`, `yanks`, `blocklist`) |
| [`lidb` `migrations/001_registry.sql`](https://github.com/li-langverse/lidb) | Same tables applied by `lis db migrate` (PH-DB-1) |
| [`registry/api/openapi-stub.yaml`](../registry/api/openapi-stub.yaml) | REST contract for registry service v1 |

**Data model (summary):**

- **`packages`** — canonical name + optional `pkg_id` (e.g. `PKG-pkg-ok`)
- **`package_versions`** — `tree_digest`, `proof_digest`, `coverage_pct`, signatures, git `source_*`, SPDX/repository URLs
- **`publishers`** — ed25519 keys for manifest signing (Phase 8c)
- **`attestations`** — CI / repro attestation digests tied to a version
- **`yanks`** — withdrawn versions (excluded from default `lip install` resolution)
- **`blocklist`** — blocked package names, publisher keys, or digests

Active versions are exposed through the `registry_active_versions` view (non-yanked, non-blocklisted).

**`lip publish` (registry mode, future):** after local gates pass, POST `PublishRequest` to the registry API (see OpenAPI). Until the server ships, use `--registry PATH` or `--github`.

## REST API

OpenAPI 3 spec: [`registry/api/openapi-stub.yaml`](../registry/api/openapi-stub.yaml).

| Method | Path | Purpose |
|--------|------|---------|
| `GET` | `/v1/packages` | List versions (`name`, pagination, `include_yanked`) |
| `GET` | `/v1/packages/{name}/{version}` | Fetch one version |
| `POST` | `/v1/packages/{name}/versions` | Publish (auth required) |
| `POST` | `/v1/packages/{name}/{version}/yank` | Yank (auth required) |

Publish body **must** include `tree_digest`, `proof_digest`, and `coverage_pct` (same as `registry/index.json` and `li.lock`).

## Domain deployment (placeholder)

Production hostname (replace when DNS is wired):

- **API:** `https://registry.li-langverse.example/v1`
- **Local dev:** `http://127.0.0.1:54322/v1` via **`lis db start`** with `profiles/registry-min.toml`

Deployment stack (target):

1. **`lis db start --profile registry-min`** — embedded lidb + registry HTTP on port **54322**
2. **TLS** termination at edge (Caddy/nginx) for `registry.li-langverse.example`
3. **Publisher auth** — bearer tokens mapped to `publishers.key_id` (OIDC later)

Until PH-DB-4 lands, keep using GitHub-first publish; the schema and OpenAPI are the contract for implementation and benchmarks (`tier_db_registry`).
