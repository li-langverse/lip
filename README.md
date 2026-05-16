# lip — Li package manager and test tooling

Official ecosystem repository for the [Li](https://github.com/li-langverse/li-language) programming language.

| Tool | Role |
|------|------|
| **lip** | Resolve, fetch, lock, and publish packages (`li.toml` / `li.lock`) |
| **lit** | Run package tests and enforce **≥ 80%** line coverage (CLI v1) |

The compiler (`lic`) lives in [**li-langverse/li-language**](https://github.com/li-langverse/li-language). This repo pins a `lic` version via [`li-toolchain.toml`](li-toolchain.toml).

## Quick start

```bash
cd ../li-language && ./scripts/build.sh
cd ../lip
export LIC=../li-language/build/compiler/lic/lic
./scripts/bootstrap_lip.sh
./scripts/bootstrap_lit.sh
./build/lip --version
```

## License

Apache-2.0 OR MIT
