#!/usr/bin/env python3
"""Toy registry smoke tests (li-toy-registry @ 0.0.1)."""
from __future__ import annotations

import json
import os
import urllib.error
import urllib.request

BASE = os.environ.get("LIP_REGISTRY_URL", "http://127.0.0.1:54321/v1").rstrip("/")
TOKEN = os.environ.get("LIP_REGISTRY_TOKEN", "test-token")
NAME = "li-toy-registry"
VERSION = "0.0.1"
TREE = "sha256:" + ("e" * 64)
PROOF = "sha256:" + ("f" * 64)


def call(
    method: str,
    path: str,
    body: dict | None = None,
    *,
    expect: int | None = None,
) -> tuple[int, dict]:
    url = f"{BASE}{path}"
    data = json.dumps(body).encode() if body is not None else None
    headers = {"Content-Type": "application/json"}
    if TOKEN:
        headers["Authorization"] = f"Bearer {TOKEN}"
    req = urllib.request.Request(url, data=data, method=method, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            raw = resp.read()
            if expect is not None and resp.status != expect:
                raise SystemExit(f"expected HTTP {expect}, got {resp.status} for {method} {path}")
            return resp.status, json.loads(raw) if raw else {}
    except urllib.error.HTTPError as e:
        detail = e.read().decode("utf-8", errors="replace")
        if expect is not None and e.code == expect:
            return e.code, json.loads(detail) if detail.strip() else {}
        raise SystemExit(f"{method} {path} -> HTTP {e.code}: {detail}") from e


def main() -> None:
    body = {
        "version": VERSION,
        "tree_digest": TREE,
        "proof_digest": PROOF,
        "coverage_pct": 85.0,
    }
    call("POST", f"/packages/{NAME}/versions", body, expect=201)
    call("POST", f"/packages/{NAME}/versions", body, expect=409)
    call("POST", f"/packages/{NAME}/versions", {**body, "version": "0.0.0"}, expect=409)
    call("POST", "/packages/registry/versions", body, expect=403)
    call("POST", f"/packages/{NAME}/{VERSION}/yank", {"reason": "smoke"}, expect=200)
    _status, listed = call("GET", f"/packages?name={NAME}")
    if any(row.get("version") == VERSION for row in listed.get("packages", [])):
        raise SystemExit("yanked version still appears in default package list")
    call("GET", f"/packages/{NAME}/{VERSION}", expect=410)
    req = urllib.request.Request(
        f"{BASE}/packages/{NAME}",
        method="DELETE",
        headers={"Authorization": f"Bearer {TOKEN}"} if TOKEN else {},
    )
    try:
        urllib.request.urlopen(req, timeout=15)
    except urllib.error.HTTPError as e:
        if e.code != 501:
            raise SystemExit(f"DELETE expected 501, got {e.code}") from e
    else:
        raise SystemExit("DELETE expected 501")
    print("toy-registry-smoke: ok")


if __name__ == "__main__":
    main()
