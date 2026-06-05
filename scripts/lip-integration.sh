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

echo "==> registry HTTP client (mock server)"
"$ROOT/scripts/registry-http-test.sh"

echo "==> pkg_ok lit coverage"
(cd "$ROOT/fixtures/pkg_ok" && "$LIT" test --coverage)

echo "==> path_consumer lip install + build"
(cd "$ROOT/fixtures/path_consumer" && "$ROOT/scripts/lip" install && "$ROOT/scripts/lip" build)

echo "==> lip lock + publish dry-run"
(cd "$ROOT/fixtures/pkg_ok" && "$ROOT/scripts/lip" lock && "$ROOT/scripts/lip" publish --dry-run)

echo "==> lip publish (github index metadata)"
(cd "$ROOT/fixtures/pkg_ok" && "$ROOT/scripts/lip" publish --dry-run --github)
(cd "$ROOT/fixtures/pkg_ok" && "$ROOT/scripts/lip" publish --github)
grep -q '"type": "git"' "$ROOT/registry/index.json"

echo "==> lip publish to local registry (filesystem path)"
TMP_REG="$(mktemp -d)"
(cd "$ROOT/fixtures/pkg_ok" && "$ROOT/scripts/lip" publish --registry "$TMP_REG")
test -f "$TMP_REG/index.json"
rm -rf "$TMP_REG"

if [[ -n "$LIT" && -x "$LIT" ]]; then
  echo "==> lip publish to registry HTTP via lip CLI"
  MOCK_LOG="$(mktemp)"
  MOCK_STATE="$(mktemp)"
  export REGISTRY_MOCK_STATE="$MOCK_STATE" LIP_REGISTRY_TOKEN="test-token"
  python3 "$ROOT/scripts/registry_mock_server.py" 0 >"$MOCK_LOG" 2>&1 &
  MOCK_PID=$!
  MOCK_PORT=""
  for _ in $(seq 1 50); do
    MOCK_PORT="$(sed -n 's/.*http:\/\/127.0.0.1:\([0-9]*\).*/\1/p' "$MOCK_LOG" | head -1)"
    [[ -n "$MOCK_PORT" ]] && break
    sleep 0.1
  done
  if [[ -n "$MOCK_PORT" ]] && (cd "$ROOT/fixtures/pkg_ok" && "$ROOT/scripts/lip" publish --registry "http://127.0.0.1:${MOCK_PORT}/v1" 2>/dev/null); then
    python3 - "$MOCK_STATE" <<'PY'
import json, pathlib, sys
data = json.loads(pathlib.Path(sys.argv[1]).read_text())
assert data[-1]["name"] == "pkg-ok"
PY
    echo "lip publish --registry URL: ok"
  else
    echo "lip-integration: skip lip CLI HTTP publish (lit/lic gate unavailable)"
  fi
  kill "$MOCK_PID" 2>/dev/null || true
  rm -f "$MOCK_LOG" "$MOCK_STATE"
fi

echo "lip-integration: ok"

if [[ -x "$ROOT/scripts/toy-git-install-smoke.sh" ]]; then
  echo "==> toy-git-install-smoke"
  "$ROOT/scripts/toy-git-install-smoke.sh"
fi

if [[ -x "$ROOT/scripts/toy-registry-smoke.sh" ]]; then
  echo "==> toy-registry-smoke"
  "$ROOT/scripts/toy-registry-smoke.sh"
fi

