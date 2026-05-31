#!/usr/bin/env python3
"""Validate package tree paths before lip publish (registry allowlist)."""
from __future__ import annotations

import os
import sys
from pathlib import Path

ALLOWED_FILES = frozenset(
    {
        "li.toml",
        "PUBLISH.md",
        "README.md",
        "src/lib.li",
    }
)

ALLOWED_PREFIXES = ("li-tests/",)

SKIP_DIRS = frozenset({".git", "build", ".lit", "__pycache__"})
SKIP_FILES = frozenset({"li.lock"})


def _rel_posix(path: Path, root: Path) -> str:
    return path.relative_to(root).as_posix()


def is_allowed_rel(rel: str) -> bool:
    if rel in ALLOWED_FILES:
        return True
    return any(rel.startswith(prefix) for prefix in ALLOWED_PREFIXES)


def find_violations(pkg_root: Path) -> list[str]:
    violations: list[str] = []
    for dirpath, dirnames, filenames in os.walk(pkg_root):
        dirnames[:] = sorted(
            d for d in dirnames if d not in SKIP_DIRS and not d.startswith(".")
        )
        for name in sorted(filenames):
            if name.startswith(".") or name in SKIP_FILES:
                continue
            full = Path(dirpath) / name
            rel = _rel_posix(full, pkg_root)
            if not is_allowed_rel(rel):
                violations.append(rel)
    return violations


def main(argv: list[str] | None = None) -> int:
    args = argv if argv is not None else sys.argv[1:]
    if len(args) != 1:
        print("usage: publish_allowlist.py PACKAGE_DIR", file=sys.stderr)
        return 2
    root = Path(args[0]).resolve()
    if not (root / "li.toml").is_file():
        print(f"publish_allowlist: missing li.toml in {root}", file=sys.stderr)
        return 1
    bad = find_violations(root)
    if bad:
        print("publish_allowlist: disallowed paths:", file=sys.stderr)
        for rel in bad:
            print(f"  - {rel}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
