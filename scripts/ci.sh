#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LI_REPO="${LI_REPO:-}"
if [[ -z "$LI_REPO" ]]; then
  for p in "$ROOT/../li-language" "$ROOT/../li"; do
    if [[ -f "$p/scripts/build.sh" ]]; then LI_REPO="$p"; break; fi
  done
fi
if [[ -z "$LI_REPO" ]]; then
  echo "ci: set LI_REPO or clone li-language beside lip" >&2
  exit 1
fi
export LLVM_DIR="${LLVM_DIR:-}"
if [[ -z "$LLVM_DIR" ]] && command -v brew >/dev/null 2>&1; then
  b="$(brew --prefix llvm@18 2>/dev/null)/lib/cmake/llvm"
  [[ -d "$b" ]] && export LLVM_DIR="$b"
fi
(cd "$LI_REPO" && ./scripts/build.sh)
export LIC="$LI_REPO/build/compiler/lic/lic"
mkdir -p "$ROOT/build"
chmod +x "$ROOT/scripts/bootstrap_lip.sh" "$ROOT/scripts/bootstrap_lit.sh"
export LI_REPO
"$ROOT/scripts/bootstrap_lip.sh"
"$ROOT/scripts/bootstrap_lit.sh"
echo "ci: ok"
