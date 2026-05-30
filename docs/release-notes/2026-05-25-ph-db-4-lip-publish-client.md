# Release notes: 2026-05-25 — ph-db-4-lip-publish-client

**Status:** Ready for review  
**Repo:** li-langverse/lip  
**PR:** (open on branch `feat/ph-db-4-lip-publish-client`)  
**PH / REQ:** PH-DB-4  
**Author:** agent

---

## Summary (one sentence)

Adds `lip publish --registry URL` HTTP client posting `proof_digest`, `coverage_pct`, and `tree_digest` to the OpenAPI publish endpoint, with mock-server integration tests and lidb/lis deployment docs.

## Agent continuation (required)

1. Read: `docs/registry.md`, `scripts/registry_client.py`, `registry/api/openapi-stub.yaml`
2. Run: `export LIC=… LIT=…; ./scripts/lip-integration.sh`
3. Then: wire **lis** registry-min HTTP handler to lidb inserts; add `lip install` registry resolver
4. Blocked on: production DNS/TLS for `registry.li-langverse.example` (human)

## Changed (specific)

| Area | What | Evidence |
|------|------|----------|
| CLI | `--registry URL` → HTTP POST; `PATH` → filesystem index | `scripts/lip`, `scripts/lip-common.sh` |
| Client | `publish_version()` OpenAPI publish body | `scripts/registry_client.py` |
| Tests | Mock registry server + integration assert digests | `scripts/registry_mock_server.py`, `scripts/lip-integration.sh` |
| Docs | lidb/lis start/migrate/token/publish flow | `docs/registry.md` |

## Not changed (scope fence)

- **lis** registry HTTP service implementation against lidb — **not** in this PR
- `lip install` central registry resolution — **not** in this PR
- ed25519 manifest signing enforcement on server — **not** in this PR

## Breaking changes

None.

## Security

N/A — client sends bearer token from `LIP_REGISTRY_TOKEN`; server auth validation is lis-side.

## Performance

N/A — single HTTP POST per publish; no bench delta.

## Downstream

| Repo | Action |
|------|--------|
| lis | implement publish handler + `registry token` for dev profile |
| lidb | keep `001_registry.sql` in sync with `registry/schema/registry-v1.sql` |

## CHANGELOG entry (paste into Unreleased)

```markdown
### Added
- `lip publish --registry URL` HTTP client (PH-DB-4): POST publish with `tree_digest`, `proof_digest`, `coverage_pct`; mock-server integration test; lidb/lis deployment docs ([#NNN](URL))
```
