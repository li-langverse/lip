#!/usr/bin/env bash
# Guard: CI must pin LLVM 22 to match lic LI_LLVM_VERSION_MAJOR.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WF="$ROOT/.github/workflows/ci.yml"
[[ -f "$WF" ]] || { echo "check-ci-llvm-pin: missing $WF" >&2; exit 1; }
if grep -qE 'llvm-18|clang-18|llvm@18' "$WF"; then
  echo "check-ci-llvm-pin: $WF still references LLVM 18 (lic requires 22)" >&2
  exit 1
fi
if ! grep -q 'llvm-22' "$WF"; then
  echo "check-ci-llvm-pin: $WF must reference llvm-22" >&2
  exit 1
fi
echo "check-ci-llvm-pin: ok (LLVM 22)"
