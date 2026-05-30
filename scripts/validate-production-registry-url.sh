#!/usr/bin/env bash
# PH-DB-4: validate lip publish --registry against production URL placeholder (no network POST).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROD_URL="${LIP_REGISTRY_PRODUCTION_URL:-https://registry.li-langverse.example}"
EXPECTED_BASE="https://registry.li-langverse.example/v1"
FIXTURE="$ROOT/fixtures/pkg_ok"

# shellcheck source=scripts/lip-common.sh
source "$ROOT/scripts/lip-common.sh"

export PYTHONPATH="${ROOT}/scripts${PYTHONPATH:+:$PYTHONPATH}"

python3 - "$PROD_URL" "$EXPECTED_BASE" <<'PY'
import sys
from registry_client import normalize_base_url

url, expected = sys.argv[1:3]
got = normalize_base_url(url)
if got != expected:
    raise SystemExit(f"normalize_base_url({url!r}) = {got!r}, want {expected!r}")
print(f"validate-production-registry-url: normalize ok → {got}")
PY

if ! grep -q 'registry.li-langverse.example' "$ROOT/registry/api/openapi-stub.yaml"; then
  echo "validate-production-registry-url: missing placeholder in openapi-stub.yaml" >&2
  exit 1
fi

if ! lip_registry_is_url "$PROD_URL"; then
  echo "validate-production-registry-url: PROD_URL must be http(s)://" >&2
  exit 1
fi

name="$(python3 -c "import re; t=open('$FIXTURE/li.toml').read(); m=re.search(r'name\\s*=\\s*\"([^\"]+)\"', t); print(m.group(1) if m else '')")"
[[ -n "$name" ]] || { echo "validate-production-registry-url: fixture name missing" >&2; exit 1; }

expected_line="lip publish: dry-run ok (registry HTTP ${PROD_URL} packages/${name}/versions)"

# Full dry-run (runs lock + lit + lic) when CI has already built LIC; optional locally.
if [[ "${LIP_VALIDATE_PRODUCTION_FULL:-}" == "1" ]]; then
  lic="$(lip_find_lic "$ROOT" 2>/dev/null || true)"
  if [[ -n "$lic" ]]; then
    export LIC
    out="$(cd "$FIXTURE" && "$ROOT/scripts/lip" publish --registry "$PROD_URL" --dry-run 2>&1)" || {
      echo "$out" >&2
      exit 1
    }
    echo "$out" | grep -qF "$expected_line" || {
      echo "validate-production-registry-url: unexpected dry-run output" >&2
      echo "$out" >&2
      exit 1
    }
    echo "validate-production-registry-url: lip dry-run ok"
    exit 0
  fi
fi

echo "$expected_line"
echo "validate-production-registry-url: contract ok ($PROD_URL); set LIP_VALIDATE_PRODUCTION_FULL=1 after lic build for full dry-run"
