#!/usr/bin/env bash
# Registry E2E against pkg_toy_registry: publish, duplicate 409, yank, list excludes yanked.
#
# Usage (from lip/):
#   ./scripts/toy-registry-smoke.sh
#
# Env:
#   LIS_REPO              — lis checkout (default: ../lis)
#   LI_REGISTRY_MOCK=1    — mock store (default: 1)
#   LIP_REGISTRY_TOKEN    — bearer (default: test-token)
#   TOY_SMOKE_START_MOCK  — start lis server (default: 1)
#   LI_E2E_SKIP=1         — skip (exit 0)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=lip-common.sh
source "$ROOT/scripts/lip-common.sh" 2>/dev/null || true

if [[ "${LI_E2E_SKIP:-}" == "1" || "${LI_E2E_SKIP:-}" == "true" ]]; then
  echo "toy-registry-smoke: skipped (LI_E2E_SKIP)"
  exit 0
fi

LIS_ROOT="${LIS_REPO:-}"
if [[ -z "$LIS_ROOT" ]]; then
  for p in "$ROOT/../lis"; do
    if [[ -f "$p/routes/registry/server.py" ]]; then
      LIS_ROOT="$p"
      break
    fi
  done
fi
if [[ -z "$LIS_ROOT" || ! -f "$LIS_ROOT/routes/registry/server.py" ]]; then
  echo "toy-registry-smoke: skip — lis not found (set LIS_REPO)" >&2
  exit 0
fi

FIXTURE="$ROOT/fixtures/pkg_toy_registry"
if [[ ! -f "$FIXTURE/li.toml" ]]; then
  echo "toy-registry-smoke: missing fixture $FIXTURE" >&2
  exit 1
fi

python3 "$ROOT/scripts/publish_allowlist.py" "$FIXTURE"

export LIP_REGISTRY_TOKEN="${LIP_REGISTRY_TOKEN:-test-token}"
export LI_REGISTRY_DEV_TOKEN="${LI_REGISTRY_DEV_TOKEN:-$LIP_REGISTRY_TOKEN}"
export LI_REGISTRY_MOCK="${LI_REGISTRY_MOCK:-1}"
export LI_REGISTRY_QUIET=1
export PYTHONPATH="$LIS_ROOT${PYTHONPATH:+:$PYTHONPATH}"

LI_DATA_DIR="$(mktemp -d)"
LI_API_PORT="$(python3 -c 'import socket;s=socket.socket();s.bind(("127.0.0.1",0));print(s.getsockname()[1]);s.close()')"
export LI_DATA_DIR LI_API_PORT
export LIP_REGISTRY_URL="http://127.0.0.1:${LI_API_PORT}/v1"

MOCK_PID=""
cleanup() {
  if [[ -n "$MOCK_PID" ]] && kill -0 "$MOCK_PID" 2>/dev/null; then
    kill "$MOCK_PID" 2>/dev/null || true
    wait "$MOCK_PID" 2>/dev/null || true
  fi
  rm -rf "$LI_DATA_DIR"
}
trap cleanup EXIT

if [[ "${TOY_SMOKE_START_MOCK:-1}" == "1" ]]; then
  python3 "$LIS_ROOT/routes/registry/server.py" --port "$LI_API_PORT" &
  MOCK_PID=$!
  for _ in $(seq 1 40); do
    curl -sf "http://127.0.0.1:${LI_API_PORT}/health" >/dev/null 2>&1 && break
    sleep 0.1
  done
fi

exec python3 "$ROOT/scripts/toy_registry_smoke.py"
