# demo-app

Minimal Li application showing **project-local installs** (Python `venv` style).

```bash
cd lip/examples/demo-app
../../scripts/lip install
../../scripts/lip build
```

### Registry dep (when `pkg-ok` is published on lip.lilangverse.xyz)

```bash
lip add pkg_ok registry=https://lip.lilangverse.xyz/v1 --version 0.1.0
lip install
```

See [docs/project-environment.md](../../docs/project-environment.md).
