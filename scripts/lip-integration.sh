#!/usr/bin/env bash
# Integration tests for lip (8b–8d exit gate).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=lip-common.sh
source "$ROOT/scripts/lip-common.sh"
chmod +x "$ROOT/scripts/lip" "$ROOT/scripts/lip-common.sh"
LIC="$(lip_find_lic "$ROOT")"
LIT="$(lip_find_lit "$ROOT" || true)"
export LI_REPO_ROOT="${LI_REPO:-$ROOT/../li}"
export LIC

echo "==> pkg_ok lit coverage"
(cd "$ROOT/fixtures/pkg_ok" && "$LIT" test --coverage)

echo "==> path_consumer lip install + build"
(cd "$ROOT/fixtures/path_consumer" && "$ROOT/scripts/lip" install && "$ROOT/scripts/lip" build)

echo "==> lip lock + publish dry-run"
(cd "$ROOT/fixtures/pkg_ok" && "$ROOT/scripts/lip" lock && "$ROOT/scripts/lip" publish --dry-run)

echo "==> lip publish to local registry"
(cd "$ROOT/fixtures/pkg_ok" && "$ROOT/scripts/lip" publish --registry "$ROOT/registry")
test -f "$ROOT/registry/index.json"

echo "lip-integration: ok"
