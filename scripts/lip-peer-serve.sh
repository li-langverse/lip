#!/usr/bin/env bash
# Serve local package blobs for P2P seeding; announces digests to registry.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lip-common.sh
source "$ROOT/scripts/lip-common.sh"

REGISTRY="${LIP_REGISTRY_URL:-${LIP_REGISTRY:-https://lip.lilangverse.xyz/v1}}"
BLOB_DIR="${LIP_PEER_BLOB_DIR:-${HOME}/.local/share/lip/blobs}"
PORT="${LIP_PEER_PORT:-8765}"
TTL="${LIP_PEER_TTL_SEC:-3600}"
INTERVAL="${LIP_PEER_ANNOUNCE_SEC:-300}"

usage() {
  cat <<EOF
Usage: lip peer serve [--port N] [--blob-dir DIR] [--registry URL]

  Serves PUT/GET /v1/blobs/{digest} from BLOB_DIR and periodically POSTs
  /v1/peers/announce to the registry (requires LIP_REGISTRY_TOKEN).

Env: LIP_PEER_PORT, LIP_PEER_BLOB_DIR, LIP_REGISTRY_URL, LIP_REGISTRY_TOKEN
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --port) PORT="$2"; shift 2 ;;
    --blob-dir) BLOB_DIR="$2"; shift 2 ;;
    --registry) REGISTRY="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "lip peer serve: unknown $1" >&2; usage >&2; exit 1 ;;
  esac
done

mkdir -p "$BLOB_DIR"
export LIP_BLOB_DIR="$BLOB_DIR"
export LI_DATA_DIR="$BLOB_DIR/../peer-data"
export LI_REGISTRY_MOCK=1
export LI_REGISTRY_DEV_TOKEN="${LIP_REGISTRY_TOKEN:-dev-token}"
export LI_JWT_SECRET="${LI_JWT_SECRET:-dev-secret}"

LIS_ROOT="${LIS_ROOT:-$ROOT/../lis}"
if [[ ! -f "$LIS_ROOT/routes/registry/server.py" ]]; then
  echo "lip peer serve: lis registry server not found at $LIS_ROOT" >&2
  exit 1
fi

ENDPOINT="http://127.0.0.1:${PORT}/v1"

announce_loop() {
  while true; do
    sleep "$INTERVAL"
    mapfile -t digests < <(find "$BLOB_DIR/sha256" -type f 2>/dev/null | while read -r f; do
      base="$(basename "$f")"
      prefix="$(basename "$(dirname "$f")")"
      echo "sha256:${prefix}${base}"
    done)
    [[ ${#digests[@]} -eq 0 ]] && continue
    python3 - "$REGISTRY" "$ENDPOINT" "$TTL" "${digests[@]}" <<'PY'
import json, os, sys, urllib.request
reg, endpoint, ttl, *digests = sys.argv[1:]
body = {"endpoint": endpoint, "digests": digests, "ttl_sec": int(ttl), "capacity_bytes": 0}
req = urllib.request.Request(
    reg.rstrip("/") + ("/v1/peers/announce" if not reg.rstrip("/").endswith("/v1") else "/peers/announce"),
    data=json.dumps(body).encode(),
    headers={"Content-Type": "application/json", "Authorization": f"Bearer {os.environ.get('LIP_REGISTRY_TOKEN','')}"},
    method="POST",
)
try:
    urllib.request.urlopen(req, timeout=30)
except Exception as e:
    print(f"lip peer serve: announce failed: {e}", file=sys.stderr)
PY
  done
}

echo "lip peer serve: blobs=$BLOB_DIR port=$PORT registry=$REGISTRY"
announce_loop &
ANN_PID=$!
trap 'kill $ANN_PID 2>/dev/null || true' EXIT
cd "$LIS_ROOT"
export PYTHONPATH="$LIS_ROOT${PYTHONPATH:+:$PYTHONPATH}"
exec python3 routes/registry/server.py --host 0.0.0.0 --port "$PORT"
