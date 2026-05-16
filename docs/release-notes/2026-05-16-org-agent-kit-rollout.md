# Release notes: 2026-05-16 — org-agent-kit-rollout

**Status:** Released  
**Repo:** li-langverse/lip  
**PH / REQ:** PH-8b / meta-governance  
**Author:** agent

---

## Summary

Adopted roadmap agent-kit v1.1.0 (PR-only, release-notes rule/skill/hook), `scripts/sync-agent-kit.sh`, CHANGELOG, and PR template.

## Agent continuation

1. Read: [roadmap release-notes policy](https://github.com/li-langverse/roadmap/blob/main/docs/ecosystem/release-notes.md)
2. On merge-worthy PRs: update `CHANGELOG.md` + dated `docs/release-notes/` before `gh pr create`
3. After roadmap `agent-kit/` changes: `./scripts/sync-agent-kit.sh`
4. Blocked on: none

## Changed

| Area | What | Evidence |
|------|------|----------|
| Agent-kit | `.cursor/` rules, skills, hooks | `scripts/expected-agent-kit-version` → 1.1.0 |
| Docs | `AGENTS.md`, `docs/release-notes/README.md` | PR-only + sync instructions |
| CI hygiene | PR template release-notes checklist | `.github/pull_request_template.md` |

## Not changed

- `lip` CLI behavior, registry protocol, package resolution — **not** in this rollout
- `lic` compiler / Lean gate — unchanged

## Breaking changes

None.

## Security

N/A — agent scaffolding only.

## Performance

N/A.

## Downstream

| Repo | Action |
|------|--------|
| lit, lis | Already rolled out in same batch |

## CHANGELOG entry

```markdown
### Added
- Agent-kit v1.1.0 sync, release-notes scaffolding, PR template (org rollout)
```
