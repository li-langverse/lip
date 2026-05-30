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

lip_install_deps() {
  local pkg="$1" lic="$2"
  mkdir -p "$pkg/.li/vendor"
  while read -r name kind src dst tag; do
    [[ -z "$name" ]] && continue
    rm -rf "$dst"
    if [[ "$kind" == path ]]; then
      cp -R "$src" "$dst"
    elif [[ "$kind" == git ]]; then
      mkdir -p "$dst"
      if [[ -d "$dst/.git" ]]; then
        git -C "$dst" fetch --depth 1 origin 2>/dev/null || true
        if [[ -n "$tag" ]]; then
          git -C "$dst" checkout "$tag" 2>/dev/null || git -C "$dst" checkout "origin/$tag" 2>/dev/null || true
        fi
      else
        if [[ -n "$tag" ]]; then
          git clone --depth 1 --branch "$tag" "$src" "$dst"
        else
          git clone --depth 1 "$src" "$dst"
        fi
      fi
    else
      echo "lip install: unknown source kind $kind for $name" >&2
      exit 1
    fi
    echo "lip install: $name -> $dst ($kind)"
    if [[ -f "$dst/scripts/install-lis.sh" ]]; then
      bash "$dst/scripts/install-lis.sh" || true
    fi
    if [[ -f "$dst/src/lib.li" ]]; then
      "$lic" build "$dst/src/lib.li" -o /dev/null 2>/dev/null || true
    fi
  done < <(python3 - "$pkg/li.toml" "$pkg" <<'PY'
import pathlib, re, sys
toml, pkg = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
t = toml.read_text()
block = re.search(r'\[dependencies\](.*?)(?:\[|\Z)', t, re.S)
if not block:
    sys.exit(0)
for line in block.group(1).splitlines():
    line = line.strip()
    if not line or line.startswith("#"):
        continue
    m = re.match(r'(\w+)\s*=\s*\{\s*path\s*=\s*"([^"]+)"', line)
    if m:
        name, rel = m.group(1), m.group(2)
        src = (toml.parent / rel).resolve()
        dst = pkg / ".li" / "vendor" / name
        print(name, "path", src, dst, "")
        continue
    m = re.match(
        r'(\w+)\s*=\s*\{\s*git\s*=\s*"([^"]+)"(?:\s*,\s*tag\s*=\s*"([^"]+)")?',
        line,
    )
    if m:
        name, url, tag = m.group(1), m.group(2), m.group(3) or ""
        dst = pkg / ".li" / "vendor" / name
        print(name, "git", url, dst, tag)
PY
)
}

# True when --registry value is an HTTP(S) registry API base (not a filesystem path).
lip_registry_is_url() {
  case "$1" in
    http://*|https://*) return 0 ;;
    *) return 1 ;;
  esac
}
