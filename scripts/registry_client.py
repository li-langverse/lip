#!/usr/bin/env python3
"""HTTP client for Li package registry API (PH-DB-4).

Posts PublishRequest to POST /v1/packages/{name}/versions per registry/api/openapi-stub.yaml.
"""
from __future__ import annotations

import hashlib
import io
import json
import os
import sys
import tarfile
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any


def normalize_base_url(url: str) -> str:
    """Ensure registry base ends with /v1 (OpenAPI servers[].url)."""
    base = url.rstrip("/")
    if not base.endswith("/v1"):
        base = f"{base}/v1"
    return base


def package_artifact_bytes(pkg_dir: str | Path) -> tuple[bytes, str]:
    """Build deterministic package tarball; returns (bytes, sha256 digest)."""
    root = Path(pkg_dir)
    buf = io.BytesIO()
    with tarfile.open(fileobj=buf, mode="w|gz") as tar:
        for dirpath, _, files in sorted(os.walk(root)):
            for name in sorted(files):
                if name.startswith("."):
                    continue
                path = Path(dirpath) / name
                rel = path.relative_to(root).as_posix()
                if rel.startswith(".git/") or rel.startswith("build/") or rel == "li.lock":
                    continue
                info = tarfile.TarInfo(name=rel)
                data = path.read_bytes()
                info.size = len(data)
                info.mtime = 0
                info.mode = 0o644
                tar.addfile(info, io.BytesIO(data))
    data = buf.getvalue()
    digest = hashlib.sha256(data).hexdigest()
    return data, f"sha256:{digest}"


def upload_blob(
    base_url: str,
    digest: str,
    data: bytes,
    *,
    token: str | None = None,
    timeout: float = 120.0,
) -> dict[str, Any]:
    """Upload artifact bytes to PUT /v1/blobs/{digest}."""
    base = normalize_base_url(base_url)
    if not digest.startswith("sha256:"):
        digest = f"sha256:{digest}"
    url = f"{base}/blobs/{digest}"
    headers = {"Content-Type": "application/vnd.li.package+tar"}
    tok = token if token is not None else os.environ.get("LIP_REGISTRY_TOKEN", "")
    if tok:
        headers["Authorization"] = f"Bearer {tok}"
    req = urllib.request.Request(url, data=data, headers=headers, method="PUT")
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            raw = resp.read().decode("utf-8")
            return json.loads(raw) if raw.strip() else {}
    except urllib.error.HTTPError as e:
        detail = e.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"registry blob upload failed: HTTP {e.code} {e.reason}: {detail}") from e
    except urllib.error.URLError as e:
        raise RuntimeError(f"registry blob upload failed: {e.reason}") from e


def publish_version(
    base_url: str,
    name: str,
    *,
    version: str,
    tree_digest: str,
    proof_digest: str,
    coverage_pct: float,
    token: str | None = None,
    artifact_digest: str | None = None,
    source: dict[str, Any] | None = None,
    extra: dict[str, Any] | None = None,
    timeout: float = 30.0,
) -> dict[str, Any]:
    """Publish one package version to the registry HTTP API."""
    base = normalize_base_url(base_url)
    if not tree_digest.startswith("sha256:"):
        tree_digest = f"sha256:{tree_digest}"
    body: dict[str, Any] = {
        "version": version,
        "tree_digest": tree_digest,
        "proof_digest": proof_digest,
        "coverage_pct": float(coverage_pct),
    }
    if source:
        body["source"] = source
    if artifact_digest:
        if not artifact_digest.startswith("sha256:"):
            artifact_digest = f"sha256:{artifact_digest}"
        body["artifact_digest"] = artifact_digest
    if extra:
        body.update(extra)

    url = f"{base}/packages/{name}/versions"
    data = json.dumps(body).encode("utf-8")
    headers = {"Content-Type": "application/json", "Accept": "application/json"}
    tok = token if token is not None else os.environ.get("LIP_REGISTRY_TOKEN", "")
    if tok:
        headers["Authorization"] = f"Bearer {tok}"

    req = urllib.request.Request(url, data=data, headers=headers, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            raw = resp.read().decode("utf-8")
            return json.loads(raw) if raw.strip() else {}
    except urllib.error.HTTPError as e:
        detail = e.read().decode("utf-8", errors="replace")
        raise RuntimeError(
            f"registry publish failed: HTTP {e.code} {e.reason}: {detail}"
        ) from e
    except urllib.error.URLError as e:
        raise RuntimeError(f"registry publish failed: {e.reason}") from e


def main(argv: list[str] | None = None) -> int:
    """CLI: registry_client.py BASE_URL NAME VERSION TREE PROOF COV [json-extra]"""
    args = argv if argv is not None else sys.argv[1:]
    if len(args) < 6:
        print(
            "usage: registry_client.py BASE_URL NAME VERSION TREE_DIGEST PROOF_DIGEST COVERAGE_PCT",
            file=sys.stderr,
        )
        return 2
    base, name, version, tree, proof, cov_s = args[:6]
    extra = json.loads(args[6]) if len(args) > 6 else None
    result = publish_version(
        base,
        name,
        version=version,
        tree_digest=tree,
        proof_digest=proof,
        coverage_pct=float(cov_s),
        extra=extra,
    )
    print(json.dumps(result, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
