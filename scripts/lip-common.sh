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

# True for remote hosted git remotes (https/http/git@/ssh). Rejects local paths and file://.
lip_is_hosted_git_url() {
  case "$1" in
    https://*|http://*|git@*|ssh://*) return 0 ;;
    *) return 1 ;;
  esac
}

# Apply credentials for known hosts; public hosted repos clone without tokens.
lip_git_auth_for_url() {
  local url="$1"
  lip_is_hosted_git_url "$url" || {
    echo "lip: git URL must be a hosted remote (https://, http://, git@, ssh://): $url" >&2
    return 1
  }
  if [[ "$url" == *gitlab.lilangverse.xyz* && -n "${GITLAB_TOKEN:-}" ]]; then
    git config --global url."https://oauth2:${GITLAB_TOKEN}@gitlab.lilangverse.xyz/".insteadOf "https://gitlab.lilangverse.xyz/" 2>/dev/null || true
  elif [[ "$url" == *github.com* && -n "${GH_TOKEN:-${GITHUB_TOKEN:-}}" ]]; then
    local gh="${GH_TOKEN:-${GITHUB_TOKEN:-}}"
    git config --global url."https://x-access-token:${gh}@github.com/".insteadOf "https://github.com/" 2>/dev/null || true
  fi
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
      lip_git_auth_for_url "$src"
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
