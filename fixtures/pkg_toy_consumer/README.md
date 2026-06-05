# li-toy-consumer

Fixture package that depends on **li-toy-registry** via a **git** URL (monorepo `subdir`).

Used by `lip/scripts/toy-git-install-smoke.sh`. Not for production installs.

## Git dependency shape

```toml
[dependencies]
li_toy_registry = { git = "https://github.com/li-langverse/lip", tag = "main", subdir = "fixtures/pkg_toy_registry" }
```

Local smoke (no network):

```bash
export TOY_GIT_URL="file://$(cd ../.. && pwd)"   # lip repo root
./scripts/toy-git-install-smoke.sh
```

## Import / lic 8a

After `lip install`, the dependency is vendored at `.li/vendor/li_toy_registry/`. Recent `lic` resolves `import li_toy_registry` via that vendor tree when the `[dependencies]` entry is `git = ...`.

**Fallback (always works):** vendor copy + path dep:

```bash
lip install
# In li.toml, replace the git line with:
# li_toy_registry = { path = ".li/vendor/li_toy_registry" }
lip build
```

## License

Apache-2.0 OR MIT
