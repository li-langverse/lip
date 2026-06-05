# Release notes: 2026-06-05 — lip git install toy consumer

**Status:** Ready for review  
**Repo:** li-langverse/lip  
**PH / REQ:** phase 8b git deps + toy fixtures  

---

## Summary (one sentence)

`lip install` from git URLs with monorepo `subdir` vendors **li-toy-registry** for **pkg_toy_consumer**, with smoke coverage and documented `source.type = "git"` publish payloads.

## Changed

| Area | What |
|------|------|
| `fixtures/pkg_toy_consumer/` | Consumer depending on `li-toy-registry` via git + `subdir` |
| `scripts/toy-git-install-smoke.sh` | Offline `file://` (default) or GitHub smoke |
| `scripts/lip-common.sh` | Git `subdir` extraction after clone |
| `scripts/lip` | `lip add --subdir` |
| `docs/git-install.md` | Git install, publish source, limitations, path fallback |
| `fixtures/pkg_toy_registry/PUBLISH.md` | `source.type = "git"` registry payload |

## Smoke command

```bash
cd lip && ./scripts/toy-git-install-smoke.sh
```

## Limitations

See [docs/git-install.md](../git-install.md#limitations-honest).
