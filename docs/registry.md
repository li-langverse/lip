# Registry (v1 — GitHub-first)

There is **no central registry server** yet. Publishing is **GitHub-based**:

1. Push your package to a GitHub repo (`[package.repository].url` in `li.toml`).
2. Run `lip publish` (or `lip publish --github`) after `lic build` + `lit test --coverage`.
3. `lip` records metadata in **`lip/registry/index.json`** with a **`source: { type: "git", url, tag }`** pointer (for discoverability).
4. If `gh` is authenticated, `lip publish` also creates a **GitHub Release** tag `v{version}` on the package repo.

Consumers use **`lip add NAME git=https://github.com/org/pkg --tag v0.1.0`** or path deps for monorepos.

## Local / future registry server

`lip publish --registry PATH` writes only to a filesystem index (used in CI fixtures). A REST registry (`registry/api/`) is reserved for a later phase.
