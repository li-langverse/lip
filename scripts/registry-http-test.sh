#!/usr/bin/env bash
# PH-DB-4: registry HTTP client + mock server (no lic/lit required).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MOCK_LOG="$(mktemp)"
MOCK_STATE="$(mktemp)"
export REGISTRY_MOCK_STATE="$MOCK_STATE" LIP_REGISTRY_TOKEN="test-token"
trap 'kill "${MOCK_PID:-}" 2>/dev/null || true; rm -f "$MOCK_LOG" "$MOCK_STATE"' EXIT

python3 "$ROOT/scripts/registry_mock_server.py" 0 >"$MOCK_LOG" 2>&1 &
MOCK_PID=$!
MOCK_PORT=""
for _ in $(seq 1 50); do
  MOCK_PORT="$(sed -n 's/.*http:\/\/127.0.0.1:\([0-9]*\).*/\1/p' "$MOCK_LOG" | head -1)"
  [[ -n "$MOCK_PORT" ]] && break
  sleep 0.1
done
[[ -n "$MOCK_PORT" ]] || { echo "registry-http-test: mock failed" >&2; cat "$MOCK_LOG" >&2; exit 1; }

python3 "$ROOT/scripts/registry_client.py" \
  "http://127.0.0.1:${MOCK_PORT}" pkg-ok 0.1.0 \
  sha256:cb77ba3f3295336993fcef7d4194f3dc45312a3c4df723bf29c56c428e184a9b \
  sha256:2018a38c6da1b2a76cb5a095f4158030ecffdb5a83afe2b6bca1af2989b12867 100.0

python3 - "$MOCK_STATE" <<'PY'
import json, pathlib, sys
data = json.loads(pathlib.Path(sys.argv[1]).read_text())
assert data and data[-1]["name"] == "pkg-ok"
for f in ("tree_digest", "proof_digest", "coverage_pct"):
    assert f in data[-1]
PY

echo "registry-http-test: ok"
