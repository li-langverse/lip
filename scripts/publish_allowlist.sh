#!/usr/bin/env bash
set -euo pipefail
PKG_DIR="${1:?usage: publish_allowlist.sh PACKAGE_DIR}"
fail=0
while IFS= read -r -d '' f; do
  rel="${f#"$PKG_DIR"/}"; rel="${rel#./}"
  [[ -z "$rel" ]] && continue
  [[ "$rel" == li.lock ]] && continue
  [[ "$rel" == .li/* ]] && continue
  if echo "$rel" | grep -qE '\.(py|js|ts|exe|dll|so|zip|tar|gz|png|jpg)$|/\.env$|/vendor/|/node_modules/|/build/|/\.git/'; then
    echo "publish_allowlist: forbidden: $rel" >&2; fail=1; continue
  fi
  case "$rel" in
    li.toml|README.md|PUBLISH.md|CHANGELOG.md) continue ;;
    src/*.li|li-tests/*/*.li) continue ;;
    scripts/*.sh) continue ;;
    LICENSE|LICENSE-*|SECURITY.md) continue ;;
    *) echo "publish_allowlist: not allowlisted: $rel" >&2; fail=1 ;;
  esac
done < <(find "$PKG_DIR" -type f ! -path '*/.git/*' -print0)
[[ "$fail" -eq 0 ]] || exit 1
echo publish_allowlist: ok
