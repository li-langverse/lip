# Project environment (Python `venv` mental model)

`lip` gives each Li software project an **isolated dependency tree** — similar to Python's virtual environment + `pip`, but Li-native.

| Python | lip |
|--------|-----|
| `python -m venv .venv` | Project root with `li.toml` (no global install) |
| `source .venv/bin/activate` | `cd` into the project; tools resolve deps from here |
| `pip install -r requirements.txt` | `lip install` (reads `[dependencies]` in `li.toml`) |
| `pip install requests==2.31` | `lip add requests registry=https://lip.lilangverse.xyz/v1 --version 2.31.0` |
| `pip install -e ./local-lib` | `lip add mylib path=../local-lib` |
| `pip install git+https://…` | `lip add mylib git=https://github.com/org/lib.git --tag v1.0.0` |
| `site-packages/` | `.li/vendor/<name>/` (vendored sources) |
| `pip freeze` | `lip lock` → `li.lock` (tree digest, proof, coverage) |
| `python -m build` | `lip build` (`lic build` on `src/lib.li` or `src/main.li`) |

## Typical app workflow

```bash
# 1. New project (from lic checkout)
lip init my-app --kind binary

cd my-app

# 2. Add dependencies
lip add pkg_ok registry=https://lip.lilangverse.xyz/v1 --version 0.1.0
# or monorepo / git:
lip add pkg_ok path=../pkg_ok
lip add lis git=https://github.com/li-langverse/lis.git --tag main

# 3. Install into project-local vendor tree (like venv site-packages)
lip install

# 4. Build application
lip build

# 5. Lock reproducible state before publish
lip lock
```

## Registry URL

Homelab registry: **`https://lip.lilangverse.xyz/v1`**

```bash
curl -fsS https://lip.lilangverse.xyz/health
curl -fsS 'https://lip.lilangverse.xyz/v1/packages?limit=5'
```

Publish (maintainers):

```bash
export LIP_REGISTRY_TOKEN=…   # bearer for mutating routes
lip publish --registry https://lip.lilangverse.xyz/v1
```

## What lives in `.li/`

| Path | Role |
|------|------|
| `.li/vendor/` | Installed dependency trees (git clone or path copy) |
| `.li/publisher.key` | Optional ed25519 key for signed lockfiles / publish |

Do not commit `.li/vendor/` if you use git deps with tags — `li.lock` + `li.toml` are enough for CI (`lip install --locked` when wired).

## Example

See [`examples/demo-app/`](../examples/demo-app/) for a minimal consumer package using path and registry deps.
