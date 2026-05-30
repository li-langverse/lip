#!/usr/bin/env bash
set -euo pipefail

lip_root() {
  cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd
}

lip_find_lic() {
  local root="$1"
  if [[ -n "${LIC:-}" && -x "$LIC" ]]; then
    echo "$LIC"
    return 0
  fi
  for p in "${LI_REPO:-}" "$root/../li" "$root/../lic"; do
    [[ -n "$p" && -x "$p/build/compiler/lic/lic" ]] && echo "$p/build/compiler/lic/lic" && return 0
  done
  return 1
}

lip_find_lit() {
  local root="$1"
  if [[ -x "$root/../lit/scripts/lit" ]]; then
    echo "$root/../lit/scripts/lit"
    return 0
  fi
  if [[ -x "$root/scripts/lit" ]]; then
    echo "$root/scripts/lit"
    return 0
  fi
  for p in "${LI_REPO:-}" "$root/../li"; do
    [[ -x "$p/scripts/lit" ]] && echo "$p/scripts/lit" && return 0
  done
  return 1
}

lip_tree_digest() {
  local dir="$1"
  python3 - "$dir" <<'PY'
import hashlib, os, sys
root = sys.argv[1]
h = hashlib.sha256()
for dirpath, _, files in sorted(os.walk(root)):
    for name in sorted(files):
        if name.startswith('.') or '/.git/' in dirpath:
            continue
        p = os.path.join(dirpath, name)
        rel = os.path.relpath(p, root)
        if rel.startswith('.git') or rel.startswith('build/') or rel == 'li.lock':
            continue
        h.update(rel.encode())
        with open(p, 'rb') as f:
            h.update(f.read())
print(h.hexdigest())
PY
}

lip_proof_digest() {
  local lic="$1" pkg="$2"
  local vc
  vc="$("$lic" verify "$pkg/src/lib.li" 2>/dev/null | sha256sum | awk '{print $1}')" || vc="unproved"
  echo "sha256:$vc"
}

# True when --registry value is an HTTP(S) registry API base (not a filesystem path).
lip_registry_is_url() {
  case "$1" in
    http://*|https://*) return 0 ;;
    *) return 1 ;;
  esac
}
