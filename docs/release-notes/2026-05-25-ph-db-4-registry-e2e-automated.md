# Release notes: 2026-05-25 — PH-DB-4 automated registry E2E

**PH / REQ:** PH-DB-4 / registry data platform (gap #4)

## Summary

Adds **`scripts/registry-e2e.sh`** to run **`lip publish --registry http://127.0.0.1:54321`** against the **lis** registry API, assert **HTTP 201** on publish, and **GET** returns the published version; wires into **`scripts/ci.sh`** and GHA when **lis** is checked out.

## Agent continuation

1. Read: `docs/registry.md` (Automated lis registry E2E), `scripts/registry-e2e.sh`.
2. Run: `./scripts/registry-e2e.sh` (needs `../lis` on `feat/ph-db-4-registry-routes` or later, plus built **lic**/**lit**).
3. Next: merge **lip #14** then this PR; rebase onto **main** when publish client lands; point GHA `lis` ref at `main` after **lis #6** merges.
4. Blocked: full lidb-backed registry until lidb engine + lis liorm wiring (PH-DB-1/2).

## Changed

| Path | What |
|------|------|
| `scripts/registry-e2e.sh` | Start lis listener, `lip publish`, GET + 201 asserts |
| `scripts/registry_client.py` | Require HTTP **201** on publish |
| `scripts/ci.sh` | Run `registry-http-test.sh` + `registry-e2e.sh` |
| `.github/workflows/ci.yml` | Checkout **lis**, `LIS_REPO` for CI |
| `docs/registry.md` | E2E runbook + env table |

## Not changed

- **lis** route handlers / mock store implementation (separate PR).
- Production registry DNS/TLS.
- `lip install` from central registry URL.

## Breaking

N/A — test-only + stricter client check (non-201 publish now errors).

## Security

N/A — loopback-only E2E; bearer stub unchanged.

## Performance

N/A — optional CI job step; skip with `LI_E2E_SKIP=1`.

## Downstream

- **lis** GHA ref `feat/ph-db-4-registry-routes` until registry routes merge to `main`.
