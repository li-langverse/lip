# Publish metadata — PKG-li-toy-registry

| Field | Value |
|-------|--------|
| **PKG id** | `PKG-li-toy-registry` |
| **Registry name** | `li-toy-registry` |
| **Version** | `0.0.1` (semver) |
| **Maintainer** | li-langverse |

## Gates

| Gate | Required |
|------|----------|
| `lic build` | Yes |
| Registry `coverage_pct` ≥ 80 | Yes |
| `tree_digest` prefix `sha256:` | Yes |

## GitHub publish (`lip publish --github`)

When `[package.repository].url` is set, `lip publish --github` records a **git source pointer** in the registry index (filesystem `registry/index.json` or HTTP registry API):

```json
"source": {
  "type": "git",
  "url": "https://github.com/li-langverse/lip",
  "tag": "v0.0.1"
}
```

The HTTP publish payload uses the same shape (`source.type`, `source.url`, `source.tag`) via `registry_client.publish_version(..., source=...)`. Consumers install with:

```bash
lip add li_toy_registry git=https://github.com/li-langverse/lip --tag v0.0.1 --subdir fixtures/pkg_toy_registry
lip install
```

Monorepo packages must set `subdir` in `li.toml` (or `lip add --subdir`) so `lip install` copies only the package tree into `.li/vendor/<name>/`.
