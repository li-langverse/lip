# lip — Li package manager and test tooling

Official ecosystem repository for the [Li](https://github.com/li-langverse/li-language) programming language.

| Tool | Role |
|------|------|
| **lip** | Resolve, fetch, lock, and publish packages (`li.toml` / `li.lock`) |
| **lit** | Run package tests and enforce **≥ 80%** line coverage (CLI v1) |

The compiler (`lic`) lives in [**li-langverse/li-language**](https://github.com/li-langverse/li-language). This repo pins a `lic` version via [`li-toolchain.toml`](li-toolchain.toml) and builds `lip` / `lit` with it.

## Prerequisites

- LLVM 18, CMake, Ninja (same as [li-language getting started](https://github.com/li-langverse/li-language/blob/main/docs/getting-started.md))
- A built `lic` from **li-language** (or let `scripts/ci.sh` build it)

## Quick start (bootstrap)

```bash
# 1. Build lic in li-language (sibling checkout recommended)
cd ../li-language   # or ../li
./scripts/build.sh

# 2. Build lip + lit from this repo
cd ../lip
export LIC=../li-language/build/compiler/lic/lic   # adjust path
./scripts/bootstrap_lip.sh
./scripts/bootstrap_lit.sh

./build/lip --version
./build/lit --version
```

## Repository layout

```
lip/           # package manager (Li source)
lit/           # test runner + coverage gate (Li source)
registry/      # static index + publish CI (Phase 8d)
fixtures/      # sample packages for CI
docs/          # lip, lit, registry user docs
scripts/       # bootstrap + CI
```

## Docs

- **Live handbook:** https://li-langverse.github.io/lip/ (GitHub Pages; enable Actions Pages on first deploy)
- [docs/handbook.md](docs/handbook.md) — cross-links to master plan, provability gaps, benchmarks
- [docs/lip.md](docs/lip.md) · [docs/lit.md](docs/lit.md) · [docs/registry.md](docs/registry.md)

## Policy

- **Publish / registry install:** `lic build` (Lean proof gate) + **ed25519** manifest signature + **`lit test --coverage` ≥ 80%**
- **Hybrid deps:** git URLs day one; central registry recommended for discoverability

Normative plans: [li-language ecosystem docs](https://github.com/li-langverse/li-language/tree/main/docs/superpowers/plans/2026-05-16-li-package-manager-lip.md).

## License

Apache-2.0 OR MIT — see [LICENSE-APACHE](LICENSE-APACHE) and [LICENSE-MIT](LICENSE-MIT).
