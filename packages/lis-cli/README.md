# lis-cli

Meta-package that vendors [li-langverse/lis](https://github.com/li-langverse/lis) with `lip install`.

```bash
cd lip/packages/lis-cli
../../scripts/lip install
./.li/vendor/lis/scripts/install-lis.sh
lis http validate .li/vendor/lis/profiles/httpd/majico-staging.toml
```

For offline dev, replace the git dependency with `lis = { path = "../../../lis" }`.
