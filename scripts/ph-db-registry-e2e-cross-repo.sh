#!/usr/bin/env bash
# PH-DB cross-repo registry publish E2E (lip + lis + lidb).
# Orchestrates mock path (A) and lis listener path (B) from docs/integration/ph-db-registry-e2e.md.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LIS_ROOT="${LIS_ROOT:-$(cd "$ROOT/../lis" 2>/dev/null && pwd || true)}"
LIDB_ROOT="${LIDB_ROOT:-$(cd "$ROOT/../lidb" 2>/dev/null && pwd || true)}"

MODE="${1:-mock}"
REGISTRY_URL="${REGISTRY_URL:-http://127.0.0.1:54321}"
MOCK_PORT="${MOCK_PORT:-54322}"

run_mock() {
  echo "== PH-DB E2E A: lip in-process mock =="
  cd "$ROOT"
  chmod +x scripts/registry-http-test.sh scripts/registry_mock_server.py 2>/dev/null || true
  ./scripts/registry-http-test.sh
}

run_lis() {
  if [[ -z "$LIS_ROOT" || ! -d "$LIS_ROOT" ]]; then
    echo "LIS_ROOT not found (expected sibling ../lis checkout)" >&2
    exit 1
  fi
  echo "== PH-DB E2E B: lis registry API + lip publish =="
  export LI_REGISTRY_API=1
  export LI_REGISTRY_MOCK="${LI_REGISTRY_MOCK:-1}"
  export LIP_REGISTRY_TOKEN="${LIP_REGISTRY_TOKEN:-dev-stub-token}"
  cd "$LIS_ROOT"
  if [[ ! -x ./bin/lis ]]; then
    echo "lis CLI missing at $LIS_ROOT/bin/lis" >&2
    exit 1
  fi
  ./bin/lis db start &
  LIS_PID=$!
  trap 'kill "$LIS_PID" 2>/dev/null || true' EXIT
  sleep 2
  curl -sf "$REGISTRY_URL/v1/openapi.yaml" | head -n 3
  cd "$ROOT"
  lip publish --registry "$REGISTRY_URL" --dry-run
  lip publish --registry "$REGISTRY_URL"
  curl -sf "$REGISTRY_URL/v1/packages" | head
}

run_lidb_check() {
  if [[ -z "$LIDB_ROOT" || ! -d "$LIDB_ROOT" ]]; then
    echo "skip lidb checks (LIDB_ROOT unset)"
    return 0
  fi
  echo "== PH-DB E2E C: lidb security + pytest (optional) =="
  cd "$LIDB_ROOT"
  if [[ -x ./scripts/run_tests.sh ]]; then
    ./scripts/run_tests.sh
  else
    echo "lidb run_tests.sh not found; skip"
  fi
}

case "$MODE" in
  mock) run_mock ;;
  lis) run_lis ;;
  lidb) run_lidb_check ;;
  all)
    run_mock
    run_lis
    run_lidb_check
    ;;
  *)
    echo "usage: $0 [mock|lis|lidb|all]" >&2
    exit 2
    ;;
esac

echo "PH-DB cross-repo E2E ($MODE) finished OK"
