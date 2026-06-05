#!/usr/bin/env bash
# Git install smoke: lip install li-toy-registry into pkg_toy_consumer.
#
# Usage (from lip/):
#   ./scripts/toy-git-install-smoke.sh
#
# Env:
#   TOY_GIT_URL     — override git remote (default: file://$LIP_ROOT for offline)
#   TOY_GIT_TAG     — branch/tag for clone (default: main)
#   TOY_GIT_SUBDIR  — monorepo package path (default: fixtures/pkg_toy_registry)
#   LIC             — lic binary (auto-detected)
#   LI_E2E_SKIP=1   — skip (exit 0)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=lip-common.sh
source "$ROOT/scripts/lip-common.sh"
chmod +x "$ROOT/scripts/lip" "$ROOT/scripts/lip-common.sh"

if [[ "${LI_E2E_SKIP:-}" == "1" || "${LI_E2E_SKIP:-}" == "true" ]]; then
  echo "toy-git-install-smoke: skipped (LI_E2E_SKIP)"
  exit 0
fi

command -v git >/dev/null 2>&1 || {
  echo "toy-git-install-smoke: skip — git not on PATH" >&2
  exit 0
}

FIXTURE="$ROOT/fixtures/pkg_toy_consumer"
[[ -f "$FIXTURE/li.toml" ]] || {
  echo "toy-git-install-smoke: missing fixture $FIXTURE" >&2
  exit 1
}

LIP_ROOT="$(cd "$ROOT" && pwd)"
TOY_GIT_URL="${TOY_GIT_URL:-file://${LIP_ROOT}}"
TOY_GIT_SUBDIR="${TOY_GIT_SUBDIR:-fixtures/pkg_toy_registry}"

if [[ "$TOY_GIT_URL" == file://* ]]; then
  git -C "$LIP_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
    echo "toy-git-install-smoke: file:// smoke requires lip checkout to be a git repo" >&2
    exit 1
  }
  TOY_GIT_TAG="${TOY_GIT_TAG:-main}"
else
  TOY_GIT_TAG="${TOY_GIT_TAG:-main}"
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
cp -R "$FIXTURE/." "$WORK/"
rm -rf "$WORK/.li"

python3 - "$WORK/li.toml" "$TOY_GIT_URL" "$TOY_GIT_TAG" "$TOY_GIT_SUBDIR" <<'PY'
import pathlib, re, sys
p, url, tag, subdir = pathlib.Path(sys.argv[1]), sys.argv[2], sys.argv[3], sys.argv[4]
t = p.read_text()
t = re.sub(
    r'li_toy_registry\s*=\s*\{[^}]+\}',
    f'li_toy_registry = {{ git = "{url}", tag = "{tag}", subdir = "{subdir}" }}',
    t,
    count=1,
)
p.write_text(t)
PY

echo "==> toy-git-install-smoke: lip install ($TOY_GIT_URL @ $TOY_GIT_TAG, subdir=$TOY_GIT_SUBDIR)"
(cd "$WORK" && "$ROOT/scripts/lip" install)

VENDOR="$WORK/.li/vendor/li_toy_registry"
[[ -f "$VENDOR/src/lib.li" ]] || {
  echo "toy-git-install-smoke: vendor missing $VENDOR/src/lib.li" >&2
  exit 1
}
grep -q 'def toy_registry_ping' "$VENDOR/src/lib.li" || {
  echo "toy-git-install-smoke: vendored lib.li unexpected" >&2
  exit 1
}
echo "toy-git-install-smoke: vendor ok"

LIC="$(lip_find_lic "$ROOT" || true)"
if [[ -n "$LIC" && -x "$LIC" ]]; then
  echo "==> toy-git-install-smoke: lip build (lic import)"
  export LIC
  (cd "$WORK" && "$ROOT/scripts/lip" build)
  echo "toy-git-install-smoke: build ok"
else
  echo "toy-git-install-smoke: skip lip build (lic not found — set LIC)"
fi

echo "toy-git-install-smoke: ok"
