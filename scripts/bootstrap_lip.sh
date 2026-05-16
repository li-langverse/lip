#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LI_REPO="${LI_REPO:-}"
LIC="${LIC:-}"
if [[ -z "$LI_REPO" ]]; then
  for p in "$ROOT/../li-language" "$ROOT/../li"; do
    if [[ -f "$p/scripts/build.sh" ]]; then LI_REPO="$p"; break; fi
  done
fi
if [[ -z "$LIC" && -n "$LI_REPO" ]]; then
  LIC="$LI_REPO/build/compiler/lic/lic"
fi
if [[ ! -x "${LIC:-}" ]]; then
  echo "bootstrap_lip: build li-language first" >&2
  exit 1
fi
mkdir -p "$ROOT/build"
OUT="${1:-$ROOT/build/lip}"
(cd "$LI_REPO" && "$LIC" build "$ROOT/lip/main.li" -o "$OUT" --release)
"$OUT" --version
"$OUT" smoke
echo "bootstrap_lip: ok"
