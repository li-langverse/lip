# Release notes: 2026-05-28 — lip-git-install-lis-cli

**Status:** Ready for review  
**Repo:** li-langverse/lip  
**PR:** cursor/lip-git-install-lis-cli-3861  
**PH / REQ:** phase 8 package manager  
**Author:** agent

---

## Summary (one sentence)

`lip install` clones git dependencies into `.li/vendor` and adds `packages/lis-cli` to install the lis staging supervisor from GitHub.

## Agent continuation (required)

1. Read: `packages/lis-cli/README.md`, `scripts/lip-common.sh` (`lip_install_deps`)
2. Run: `cd packages/lis-cli && ../../scripts/lip install` (requires network + git)
3. Then: `./.li/vendor/lis/scripts/install-lis.sh` and follow lis `docs/staging-majico.md`
4. Blocked on: `lic` on PATH for packages with `src/lib.li` — N/A for lis-cli (shell-only vendor)

## Changed (specific)

| Area | What | Evidence |
|------|------|----------|
| Scripts | `lip_install_deps` path + git | manual `lip install` |
| Package | `packages/lis-cli/` | README |
| Registry | `registry/index.json` lis-cli entry | index schema |

## Not changed (scope fence)

- `lip publish` to remote registry API — still local index + GitHub releases
- Lockfile recording of git resolved SHAs — future work

## Breaking changes

None.

## Security

Git clone uses `--depth 1`; verify tags before production install.

## Performance

N/A.

## Downstream

| Repo | Action |
|------|--------|
| lis | `packages/lis-cli` mirror; staging docs reference lip install |
