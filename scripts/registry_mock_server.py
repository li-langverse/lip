#!/usr/bin/env python3
"""Minimal registry HTTP stub for lip integration tests (PH-DB-4)."""
from __future__ import annotations

import json
import os
import pathlib
import re
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import urlparse

PUBLISH_RE = re.compile(r"^/v1/packages/([a-z][a-z0-9_-]*)/versions$")


class RegistryMockHandler(BaseHTTPRequestHandler):
    published: list[dict] = []

    def log_message(self, fmt: str, *args: object) -> None:
        return

    def _json(self, code: int, obj: dict) -> None:
        body = json.dumps(obj).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_POST(self) -> None:
        parsed = urlparse(self.path)
        m = PUBLISH_RE.match(parsed.path)
        if not m:
            self._json(404, {"error": "not_found", "message": f"unknown path {parsed.path}"})
            return
        auth = self.headers.get("Authorization", "")
        if not auth.startswith("Bearer "):
            self._json(401, {"error": "unauthorized", "message": "missing bearer token"})
            return
        length = int(self.headers.get("Content-Length", "0"))
        raw = self.rfile.read(length).decode("utf-8")
        try:
            body = json.loads(raw)
        except json.JSONDecodeError:
            self._json(400, {"error": "bad_request", "message": "invalid JSON"})
            return
        for field in ("version", "tree_digest", "proof_digest", "coverage_pct"):
            if field not in body:
                self._json(
                    400,
                    {"error": "bad_request", "message": f"missing required field {field}"},
                )
                return
        name = m.group(1)
        entry = {"name": name, **body}
        type(self).published.append(entry)
        state_path = os.environ.get("REGISTRY_MOCK_STATE")
        if state_path:
            pathlib.Path(state_path).write_text(
                json.dumps(type(self).published, indent=2) + "\n"
            )
        self._json(
            201,
            {
                "name": name,
                "version": body["version"],
                "published_at": "2026-05-25T00:00:00Z",
                "index_url": f"http://127.0.0.1:{self.server.server_port}/v1/packages/{name}/{body['version']}",
            },
        )


def main() -> int:
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 0
    httpd = HTTPServer(("127.0.0.1", port), RegistryMockHandler)
    host, actual_port = httpd.server_address
    print(f"registry-mock listening on http://{host}:{actual_port}", flush=True)
    httpd.serve_forever()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
