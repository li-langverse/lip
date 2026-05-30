# Release notes: 2026-05-25 — PH-DB registry E2E integration doc

**Status:** Ready for review  
**Repo:** li-langverse/lip  
**PH / REQ:** PH-DB-4  
**Author:** PH-DB merge coordinator

---

## Summary

Adds cross-repo integration guide for `lip publish --registry` against lis mock and future lidb-backed registry.

## Agent continuation

1. Read: `docs/integration/ph-db-registry-e2e.md`
2. Run: section **A** after merging lip #14; section **B** after lis #5/#6
3. Then: align OpenAPI/DDL checklist with lidb migrations on every contract change
4. Blocked on: lis/lidb PR merges; lip #14 CI bootstrap fix

## Changed

| Area | What | Evidence |
|------|------|----------|
| Docs | `docs/integration/ph-db-registry-e2e.md` | manual runbook |
| Release | this file | policy |

## Not changed

- `scripts/registry_client.py` — still on PR #14 branch only
- lis/lidb runtime wiring

## Breaking changes

None.

## Security

N/A — documentation only; reminds loopback-only stubs.

## Performance

N/A

## Downstream

- **lis:** port and profile names must match doc when routes merge
- **lidb:** migration filenames referenced in checklist
