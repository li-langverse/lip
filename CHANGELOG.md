# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added

- Minimal GitHub Pages handbook (`site/`, `.github/workflows/pages.yml`) with master-plan and provability-gaps cross-links.
- PH-DB-4: validate production registry URL placeholder (`scripts/validate-production-registry-url.sh`, `LIP_REGISTRY_PRODUCTION_URL`).
- PH-DB-4: automated `lip publish` → lis registry E2E (`scripts/registry-e2e.sh`, CI via `LIS_REPO`).
- PH-DB: native lidb deployment docs (`docs/registry.md`) — no SQLite ship path, `stack-full` + realtime WS **54323**.
- PH-DB: cross-repo E2E `stack`/`realtime` modes and `LIP_E2E_REALTIME` WS probe (`scripts/ph-db-registry-e2e-cross-repo.sh`).
- PH-DB: cross-repo registry publish E2E doc (`docs/integration/ph-db-registry-e2e.md`).
- `lip publish --registry URL` HTTP client (PH-DB-4): POST publish with `tree_digest`, `proof_digest`, `coverage_pct`; mock-server integration test; lidb/lis deployment docs.
- Agent-kit sync and release-notes policy (roadmap v1.1.0).
