# Git dependencies (`lip add` / `lip install`)

Phase **8b** fetches git dependencies into `.li/vendor/<dep_name>/`. Phase **8d** publish can record a matching **`source: { type: "git", url, tag }`** pointer for discoverability.

## Add and install

```bash
# Remote monorepo package (li-toy-registry lives under lip/)
lip add li_toy_registry git=https://github.com/li-langverse/lip --tag main --subdir fixtures/pkg_toy_registry
lip install

# Local offline smoke (lip checkout must be a git repo)
lip add li_toy_registry "git=file://$(pwd)" --tag main --subdir fixtures/pkg_toy_registry
lip install
```

`lip install` clones with `git clone --depth 1` (and `--branch` when `tag` is set), then, when `subdir` is present, copies only that subdirectory into the vendor slot.

## Registry publish payload (`source.type = "git"`)

`lip publish --github` (or default publish when `[package.repository].url` is set) writes:

| Field | Example |
|-------|---------|
| `source.type` | `"git"` |
| `source.url` | `https://github.com/li-langverse/lip` |
| `source.tag` | `v0.0.1` (from package version) |

Filesystem index: `registry/index.json`. HTTP registry: POST body field `source` (see `scripts/registry_client.py`).

See `fixtures/pkg_toy_registry/PUBLISH.md` for the toy package walkthrough.

## Smoke test

```bash
# From lip/ — offline by default (file:// lip root)
./scripts/toy-git-install-smoke.sh

# Against GitHub (network + branch must exist)
TOY_GIT_URL=https://github.com/li-langverse/lip ./scripts/toy-git-install-smoke.sh
```

Fixture consumer: `fixtures/pkg_toy_consumer/`.

## Imports and lic 8a

After `lip install`, `lic` resolves `import <dep_name>` from `.li/vendor/<dep_name>/src/lib.li` when the matching `[dependencies]` entry uses `git = ...` (snake_case dep name, e.g. `li_toy_registry` for package `li-toy-registry`).

**Fallback (vendor copy + path dep)** — works on any `lic` that resolves path dependencies:

```bash
lip install
# Edit li.toml:
# li_toy_registry = { path = ".li/vendor/li_toy_registry" }
lip build
```

## Limitations (honest)

| Topic | Status |
|-------|--------|
| `li.lock` git resolved SHAs | Not recorded yet (path deps only in lock stub) |
| Sparse checkout / partial clone | Not supported — full repo clone, then `subdir` copy |
| `file://` URLs | Require target path to be a git work tree |
| `tag` field | Passed to `git clone --branch` (branch or tag name) |
| Unsigned git deps | No `trusted.git` enforcement yet (8c) |
| Third-party registry install | Policy: wait for **8a + 8c + 8e** before advertising broadly |
| Windows | Use Git Bash or WSL; `lip` is bash |
