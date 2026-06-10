#!/usr/bin/env bash
# Device OAuth login for lip registry — mints LIP_REGISTRY_TOKEN via browser approval.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lip-common.sh
source "${SCRIPT_DIR}/lip-common.sh" 2>/dev/null || true

REGISTRY_URL="${LIP_REGISTRY_URL:-https://lip.lilangverse.xyz/v1}"
REGISTRY_URL="${REGISTRY_URL%/}"
[[ "${REGISTRY_URL}" != */v1 ]] && REGISTRY_URL="${REGISTRY_URL}/v1"

JSON_MODE=0
SAVE=1
CRED_FILE="${LIP_CREDENTIALS_FILE:-${HOME}/.config/lip/credentials.toml}"

usage() {
  cat <<'EOF'
Usage: lip-login.sh [--device] [--json] [--no-save] [--url URL]

Device flow:
  1. POST /v1/auth/device/start
  2. Open verification_uri and approve user_code
  3. Poll until api token is returned
  4. Write [registry] token= to ~/.config/lip/credentials.toml

Env: LIP_REGISTRY_URL, LIP_CREDENTIALS_FILE
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --device) shift ;;
    --json) JSON_MODE=1; shift ;;
    --no-save) SAVE=0; shift ;;
    --url) REGISTRY_URL="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown arg: $1" >&2; usage; exit 1 ;;
  esac
done

api_post() {
  local path="$1"
  local body="${2:-{}}"
  curl -fsS -X POST "${REGISTRY_URL}${path}" \
    -H 'Content-Type: application/json' \
    -H 'Accept: application/json' \
    -d "${body}"
}

emit() {
  if [[ "$JSON_MODE" -eq 1 ]]; then
    printf '%s\n' "$1"
  else
    echo "$1" >&2
  fi
}

start="$(api_post '/auth/device/start' '{}')"
device_code="$(printf '%s' "$start" | python3 -c "import json,sys; print(json.load(sys.stdin)['device_code'])")"
user_code="$(printf '%s' "$start" | python3 -c "import json,sys; print(json.load(sys.stdin)['user_code'])")"
verification_uri="$(printf '%s' "$start" | python3 -c "import json,sys; print(json.load(sys.stdin)['verification_uri'])")"
interval="$(printf '%s' "$start" | python3 -c "import json,sys; print(json.load(sys.stdin).get('interval',5))")"

if [[ "$JSON_MODE" -eq 1 ]]; then
  printf '%s\n' "$(printf '{"verification_uri":%s,"user_code":%s,"device_code":%s}' \
    "$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$verification_uri")" \
    "$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$user_code")" \
    "$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$device_code")")"
else
  echo "Approve device login:"
  echo "  URI:  ${verification_uri}"
  echo "  Code: ${user_code}"
  if command -v xdg-open >/dev/null 2>&1; then
    xdg-open "${verification_uri}" >/dev/null 2>&1 || true
  elif command -v open >/dev/null 2>&1; then
    open "${verification_uri}" >/dev/null 2>&1 || true
  fi
fi

deadline=$(( $(date +%s) + 900 ))
token=""
while [[ $(date +%s) -lt $deadline ]]; do
  poll="$(api_post '/auth/device/poll' "$(printf '{"device_code":%s}' "$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$device_code")")" 2>/dev/null || true)"
  status="$(printf '%s' "$poll" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('status',''))" 2>/dev/null || echo "")"
  if [[ "$status" == "complete" ]]; then
    token="$(printf '%s' "$poll" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('token') or d.get('access_token') or '')" 2>/dev/null || echo "")"
    break
  fi
  sleep "${interval:-5}"
done

if [[ -z "$token" ]]; then
  emit '{"error":"timeout","message":"device login not approved in time"}'
  exit 1
fi

if [[ "$SAVE" -eq 1 ]]; then
  mkdir -p "$(dirname "$CRED_FILE")"
  if [[ -f "$CRED_FILE" ]] && grep -q '^\[registry\]' "$CRED_FILE" 2>/dev/null; then
    # shellcheck disable=SC2016
    python3 - "$CRED_FILE" "$token" <<'PY'
import re, sys
path, token = sys.argv[1], sys.argv[2]
text = open(path, encoding="utf-8").read()
if re.search(r'^token\s*=', text, re.M):
    text = re.sub(r'^token\s*=.*$', f'token = "{token}"', text, flags=re.M)
else:
    text = text.rstrip() + f'\ntoken = "{token}"\n'
open(path, "w", encoding="utf-8").write(text)
PY
  else
    cat >"$CRED_FILE" <<EOF
[registry]
url = "${REGISTRY_URL}"
token = "${token}"
EOF
    chmod 600 "$CRED_FILE" 2>/dev/null || true
  fi
fi

export LIP_REGISTRY_TOKEN="$token"
if [[ "$JSON_MODE" -eq 1 ]]; then
  python3 -c 'import json,os,sys; print(json.dumps({"status":"ok","token":os.environ["LIP_REGISTRY_TOKEN"],"credentials_file":sys.argv[1]}))' "$CRED_FILE"
else
  echo "Saved token to ${CRED_FILE}"
  echo "export LIP_REGISTRY_TOKEN=${token}"
fi
