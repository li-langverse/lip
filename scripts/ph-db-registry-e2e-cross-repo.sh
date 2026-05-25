#!/usr/bin/env bash
# PH-DB cross-repo registry publish E2E (lip + lis + lidb).
# Orchestrates mock path (A), lis listener (B), stack-full + realtime (D) from docs/integration/ph-db-registry-e2e.md.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LIS_ROOT="${LIS_ROOT:-$(cd "$ROOT/../lis" 2>/dev/null && pwd || true)}"
LIDB_ROOT="${LIDB_ROOT:-$(cd "$ROOT/../lidb" 2>/dev/null && pwd || true)}"

MODE="${1:-mock}"
REGISTRY_URL="${REGISTRY_URL:-http://127.0.0.1:54321}"
MOCK_PORT="${MOCK_PORT:-54322}"
LI_REALTIME_PORT="${LI_REALTIME_PORT:-54323}"
LIP_BIN="${LIP_BIN:-lip}"

probe_realtime_ws() {
  local port="${LI_REALTIME_PORT}"
  local required="${LIP_E2E_REALTIME_REQUIRED:-0}"
  echo "== PH-DB E2E: realtime WS probe (127.0.0.1:${port}) =="
  if python3 - "$port" <<'PY'
import socket
import sys

port = int(sys.argv[1])
s = socket.socket()
s.settimeout(2)
try:
    s.connect(("127.0.0.1", port))
except OSError:
    sys.exit(1)
finally:
    s.close()
sys.exit(0)
PY
  then
    echo "realtime: TCP ${port} open (broker listening)"
    if [[ "${LIP_E2E_REALTIME_WS:-}" == "1" ]]; then
      python3 - "$port" <<'PY' || exit 1
import socket
import sys

port = int(sys.argv[1])
key = b"dGVzdA=="  # stub apikey
req = (
    f"GET /socket/websocket?apikey={key.decode()}&vsn=1.0.0 HTTP/1.1\r\n"
    f"Host: 127.0.0.1:{port}\r\n"
    "Upgrade: websocket\r\n"
    "Connection: Upgrade\r\n"
    "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\n"
    "Sec-WebSocket-Version: 13\r\n"
    "\r\n"
).encode()
s = socket.create_connection(("127.0.0.1", port), timeout=2)
s.sendall(req)
resp = s.recv(256)
s.close()
if b"101" not in resp and b"websocket" not in resp.lower():
    sys.exit(1)
print("realtime: WebSocket upgrade response ok")
PY
    fi
    return 0
  fi
  if [[ "$required" == "1" ]]; then
    echo "realtime: port ${port} not reachable (LIP_E2E_REALTIME_REQUIRED=1)" >&2
    exit 1
  fi
  echo "realtime: skip (port ${port} not listening — OK in CI until lis PH-DB-7)"
}

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
  local profile="${LI_PROFILE:-registry-min}"
  echo "== PH-DB E2E B: lis registry API (${profile}) + lip publish =="
  export LI_REGISTRY_API=1
  export LI_REGISTRY_MOCK="${LI_REGISTRY_MOCK:-1}"
  export LIP_REGISTRY_TOKEN="${LIP_REGISTRY_TOKEN:-dev-stub-token}"
  cd "$LIS_ROOT"
  if [[ ! -x ./bin/lis ]]; then
    echo "lis CLI missing at $LIS_ROOT/bin/lis" >&2
    exit 1
  fi
  ./bin/lis db start --profile "$profile" &
  LIS_PID=$!
  trap 'kill "$LIS_PID" 2>/dev/null || true; ./bin/lis db stop 2>/dev/null || true' EXIT
  sleep 2
  curl -sf "$REGISTRY_URL/v1/openapi.yaml" | head -n 3
  cd "$ROOT"
  "$LIP_BIN" publish --registry "$REGISTRY_URL" --dry-run
  "$LIP_BIN" publish --registry "$REGISTRY_URL"
  curl -sf "$REGISTRY_URL/v1/packages" | head
  if [[ "${LIP_E2E_REALTIME:-}" == "1" ]]; then
    probe_realtime_ws
  fi
}

run_stack() {
  export LI_PROFILE=stack-full
  export LIP_E2E_REALTIME="${LIP_E2E_REALTIME:-1}"
  run_lis
}

run_realtime() {
  probe_realtime_ws
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
  stack) run_stack ;;
  realtime) run_realtime ;;
  lidb) run_lidb_check ;;
  all)
    run_mock
    run_lis
    if [[ "${LIP_E2E_REALTIME:-}" == "1" ]]; then
      probe_realtime_ws
    fi
    run_lidb_check
    ;;
  *)
    echo "usage: $0 [mock|lis|stack|realtime|lidb|all]" >&2
    echo "  LIP_E2E_REALTIME=1     probe WS port after lis/stack (default port ${LI_REALTIME_PORT})" >&2
    echo "  LIP_E2E_REALTIME_REQUIRED=1  fail if realtime port closed" >&2
    echo "  LIP_E2E_REALTIME_WS=1  send minimal WebSocket upgrade after TCP probe" >&2
    exit 2
    ;;
esac

echo "PH-DB cross-repo E2E ($MODE) finished OK"
