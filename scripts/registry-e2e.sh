#!/usr/bin/env bash
# PH-DB-4 gap #4: lip publish --registry against lis registry API (automated E2E).
#
# Starts lis routes/registry/server.py on LI_API_PORT (default 54321), runs
# `lip publish --registry http://127.0.0.1:54321`, asserts HTTP 201 + GET version.
#
# Env:
#   LI_E2E_SKIP=1     — skip (exit 0)
#   LIS_REPO          — lis checkout (default: ../lis)
#   LI_API_PORT       — registry listener (default: 54321)
#   LIP_REGISTRY_TOKEN — bearer for publish (default: test-token)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=lip-common.sh
source "$ROOT/scripts/lip-common.sh"

if [[ "${LI_E2E_SKIP:-}" == "1" || "${LI_E2E_SKIP:-}" == "true" ]]; then
  echo "registry-e2e: skipped (LI_E2E_SKIP)"
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
  echo "registry-e2e: skip — lis registry server not found (clone li-langverse/lis beside lip or set LIS_REPO)" >&2
  exit 0
fi

LIC="$(lip_find_lic "$ROOT")" || {
  echo "registry-e2e: lic not found (build lic or set LIC)" >&2
  exit 1
}
LIT="$(lip_find_lit "$ROOT")" || {
  echo "registry-e2e: lit not found (checkout lit beside lip)" >&2
  exit 1
}
export LIC LIP_REGISTRY_TOKEN="${LIP_REGISTRY_TOKEN:-test-token}"
export LI_REPO="${LI_REPO:-${LIC%/build/compiler/lic/lic}}"
export LI_REPO_ROOT="${LI_REPO_ROOT:-$LI_REPO}"
export PATH="$(dirname "$LIT"):${PATH}"

LI_API_PORT="${LI_API_PORT:-54321}"
LI_DATA_DIR="$(mktemp -d)"
WORK_PKG="$(mktemp -d)"
export LI_DATA_DIR LI_REGISTRY_QUIET=1
export LI_REGISTRY_MOCK=1
export LI_REGISTRY_DEV_TOKEN="${LIP_REGISTRY_TOKEN}"
export LI_JWT_SECRET="${LI_JWT_SECRET:-test-jwt-secret}"
export PYTHONPATH="$LIS_ROOT${PYTHONPATH:+:$PYTHONPATH}"

cleanup() {
  if [[ -n "${SERVER_PID:-}" ]] && kill -0 "$SERVER_PID" 2>/dev/null; then
    kill "$SERVER_PID" 2>/dev/null || true
    wait "$SERVER_PID" 2>/dev/null || true
  fi
  rm -rf "$LI_DATA_DIR" "$WORK_PKG"
}
trap cleanup EXIT

cp -a "$ROOT/fixtures/pkg_ok/." "$WORK_PKG/"
python3 - "$WORK_PKG/li.toml" <<'PY'
import pathlib, re, sys
p = pathlib.Path(sys.argv[1])
text = p.read_text()
text = re.sub(r'version = "0\.1\.0"', 'version = "0.2.0"', text, count=1)
p.write_text(text)
PY

python3 "$LIS_ROOT/routes/registry/server.py" --port "$LI_API_PORT" &
SERVER_PID=$!

BASE="http://127.0.0.1:${LI_API_PORT}"
ready=false
for _ in $(seq 1 50); do
  if curl -sf "${BASE}/health" >/dev/null 2>&1; then
    ready=true
    break
  fi
  sleep 0.1
done
if [[ "$ready" != true ]]; then
  echo "registry-e2e: lis registry failed to start on port ${LI_API_PORT}" >&2
  exit 1
fi

NAME="pkg-ok"
VER="0.2.0"

echo "registry-e2e: lip publish -> ${BASE}"
(cd "$WORK_PKG" && "$ROOT/scripts/lip" publish --registry "$BASE")

echo "registry-e2e: GET /v1/packages/${NAME}/${VER}"
body="$(curl -sf "${BASE}/v1/packages/${NAME}/${VER}")"
python3 - "$body" "$NAME" "$VER" <<'PY'
import json, sys
raw, name, ver = sys.argv[1], sys.argv[2], sys.argv[3]
data = json.loads(raw)
assert data.get("name") == name, data
assert data.get("version") == ver, data
assert "tree_digest" in data and data["tree_digest"].startswith("sha256:")
assert "proof_digest" in data
PY

echo "registry-e2e: POST duplicate version expects 409"
tree="$(python3 -c "import json,sys; print(json.loads(sys.argv[1])['tree_digest'])" "$body")"
proof="$(python3 -c "import json,sys; print(json.loads(sys.argv[1])['proof_digest'])" "$body")"
cov="$(python3 -c "import json,sys; print(json.loads(sys.argv[1])['coverage_pct'])" "$body")"
code="$(curl -s -o /dev/null -w '%{http_code}' -X POST "${BASE}/v1/packages/${NAME}/versions" \
  -H "Authorization: Bearer ${LIP_REGISTRY_TOKEN}" \
  -H 'Content-Type: application/json' \
  -d "{\"version\":\"${VER}\",\"tree_digest\":\"${tree}\",\"proof_digest\":\"${proof}\",\"coverage_pct\":${cov}}")"
if [[ "$code" != "409" ]]; then
  echo "registry-e2e: expected HTTP 409 on duplicate publish, got ${code}" >&2
  exit 1
fi

echo "registry-e2e: ok"
