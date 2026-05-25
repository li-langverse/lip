# Release notes: 2026-05-25 — production-registry-url-validate

**Status:** Ready for review  
**Repo:** li-langverse/lip  
**PR:** (feat/production-registry-validate)  
**PH / REQ:** PH-DB-4  
**Author:** agent

---

## Summary (one sentence)

Adds `scripts/validate-production-registry-url.sh` to verify `lip publish --registry` contract against `https://registry.li-langverse.example` without network POST.

## Agent continuation (required)

1. Read: `docs/registry.md` production validation section
2. Run: `./scripts/validate-production-registry-url.sh`; CI sets `LIP_VALIDATE_PRODUCTION_FULL=1` after `lic` build
3. Then: human production smoke after `lis` host is live
4. Blocked on: production DNS/TLS — human

## Changed (specific)

| Area | What | Evidence |
|------|------|----------|
| CI | `scripts/validate-production-registry-url.sh` + `scripts/ci.sh` | local script exit 0 |
| Docs | `docs/registry.md` validation snippet | doc |

## Not changed (scope fence)

- `registry_client.py` HTTP POST behavior — unchanged
- `registry-e2e.sh` local lis E2E — separate PR/branch

## Breaking changes

None.

## Security

N/A — no tokens in script; dry-run only when `LIP_VALIDATE_PRODUCTION_FULL=1`.

## Performance

N/A.

## Downstream

| Repo | Action |
|------|--------|
| roadmap | `ph-db-status.md` §5 references this script |

## CHANGELOG entry (paste into Unreleased)

- **PH-DB-4:** validate production registry URL placeholder in CI (`validate-production-registry-url.sh`).
