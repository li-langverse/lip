# Release notes: 2026-05-25 — PH-DB native stack + realtime docs

**Status:** Ready for review  
**Repo:** li-langverse/lip  
**PH / REQ:** PH-DB-4, PH-DB-7 (realtime doc only)  
**Author:** PH-DB merge coordinator

---

## Summary

Documents lidb-native registry deployment (no SQLite ship path), `stack-full` profile for realtime, and optional cross-repo WS port probe in `ph-db-registry-e2e-cross-repo.sh`.

## Agent continuation

1. Read: `docs/registry.md` (profiles table), `docs/integration/ph-db-registry-e2e.md` section **D**
2. Run: `./scripts/ph-db-registry-e2e-cross-repo.sh mock`; after lis merge: `LIP_E2E_REALTIME=1 ./scripts/ph-db-registry-e2e-cross-repo.sh stack`
3. Then: merge lis `profiles/stack-full.toml` + PH-DB-7 broker; re-run with `LIP_E2E_REALTIME_REQUIRED=1`
4. Blocked on: lis/lidb native engine PRs; `stack-full.toml` not in lis `main` yet

## Changed

| Area | What | Evidence |
|------|------|----------|
| Docs | `docs/registry.md` — native lidb, profiles, stack-full realtime | manual |
| Docs | `docs/integration/ph-db-registry-e2e.md` — section D, ports | manual |
| Script | `scripts/ph-db-registry-e2e-cross-repo.sh` — `stack`, `realtime`, env probes | `mock` mode local |

## Not changed

- `scripts/registry_client.py` HTTP publish semantics
- lis/lidb runtime: SQLite smoke backend may still run in lidb PH-DB-1
- Production DNS/TLS and OAuth publishers
- PG wire protocol (PH-DB-6)

## Breaking changes

None.

## Security

N/A — documentation and optional loopback TCP/WS probe; `LIP_E2E_REALTIME_REQUIRED=0` default skips closed ports.

## Performance

N/A

## Downstream

| Repo | Action |
|------|--------|
| **lis** | Add `profiles/stack-full.toml`; bind realtime **54323** |
| **lidb** | Remove sqlite smoke when native exec merges |

## CHANGELOG entry (paste into Unreleased)

- PH-DB: native lidb + `stack-full` realtime docs; optional realtime WS probe in cross-repo E2E script.
