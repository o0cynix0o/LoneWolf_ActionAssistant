#!/usr/bin/env python3
"""Local HTTP server for the Lone Wolf web migration scaffold."""

from __future__ import annotations

import argparse
import json
import mimetypes
import os
import subprocess
import sys
import threading
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import unquote, urlparse


ROOT = Path(__file__).resolve().parents[1]
WEB_ROOT = ROOT / "web" / "frontend"
BOOKS_ROOT = ROOT / "books"
STATE_LOCK = threading.RLock()


class LoneWolfSession:
    """Owns a long-lived PowerShell session for API-backed web state."""

    def __init__(self, repo_root: Path) -> None:
        self.repo_root = repo_root
        self.script_path = repo_root / "web" / "lw_api_session.ps1"
        self.process: subprocess.Popen[str] | None = None
        self.stderr_lines: list[str] = []
        self.stderr_lock = threading.RLock()
        self._start()

    def _start(self) -> None:
        if self.process and self.process.poll() is None:
            return

        command = [
            "pwsh",
            "-NoProfile",
            "-File",
            str(self.script_path),
        ]
        self.process = subprocess.Popen(
            command,
            cwd=self.repo_root,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            encoding="utf-8",
            bufsize=1,
        )

        if self.process.stderr is not None:
            thread = threading.Thread(target=self._read_stderr, daemon=True)
            thread.start()

        self.request({"action": "bootstrap"})

    def _read_stderr(self) -> None:
        assert self.process is not None
        assert self.process.stderr is not None
        for line in self.process.stderr:
            clean = line.strip()
            if not clean:
                continue
            with self.stderr_lock:
                self.stderr_lines.append(clean)
                self.stderr_lines = self.stderr_lines[-20:]

    def request(self, payload: dict) -> dict:
        self._start()
        assert self.process is not None
        assert self.process.stdin is not None
        assert self.process.stdout is not None

        if self.process.poll() is not None:
            raise RuntimeError("Lone Wolf engine session is not running.")

        message = json.dumps(payload, ensure_ascii=True)
        self.process.stdin.write(message + "\n")
        self.process.stdin.flush()

        response_line = self.process.stdout.readline()
        if not response_line:
            raise RuntimeError("No response from Lone Wolf engine session.")

        try:
            response = json.loads(response_line)
        except json.JSONDecodeError as exc:
            raise RuntimeError(f"Invalid engine response: {response_line.strip()}") from exc

        if self.stderr_lines:
            with self.stderr_lock:
                response["stderr"] = list(self.stderr_lines)

        return response

    def close(self) -> None:
        process = self.process
        self.process = None
        if process is None:
            return

        try:
            if process.stdin is not None and not process.stdin.closed:
                process.stdin.close()
        except OSError:
            pass

        try:
            process.wait(timeout=5)
            return
        except subprocess.TimeoutExpired:
            pass

        try:
            process.terminate()
            process.wait(timeout=5)
            return
        except (OSError, subprocess.TimeoutExpired):
            pass

        try:
            process.kill()
            process.wait(timeout=5)
        except OSError:
            pass


SESSION = LoneWolfSession(ROOT)


class LoneWolfHandler(BaseHTTPRequestHandler):
    server_version = "LoneWolfHTTP/0.1"

    def log_message(self, format: str, *args) -> None:  # noqa: A003
        return

    def send_json(self, data: dict, status: int = 200) -> None:
        body = json.dumps(data, indent=2).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self) -> None:  # noqa: N802
        parsed = urlparse(self.path)
        if parsed.path == "/api/state":
            with STATE_LOCK:
                response = SESSION.request({"action": "state"})
            self.send_json(response)
            return
        if parsed.path == "/api/saves":
            with STATE_LOCK:
                response = SESSION.request({"action": "state"})
            payload = response.get("payload", {})
            self.send_json({"ok": True, "saves": payload.get("saves", [])})
            return
        self.serve_static(parsed.path)

    def do_POST(self) -> None:  # noqa: N802
        parsed = urlparse(self.path)
        if parsed.path == "/api/shutdown":
            self.send_json({"ok": True, "message": "Server shutdown requested."})
            threading.Thread(target=self.server.shutdown, daemon=True).start()
            return

        if parsed.path != "/api/action":
            self.send_json({"ok": False, "message": "Not found."}, HTTPStatus.NOT_FOUND)
            return

        length = int(self.headers.get("Content-Length") or 0)
        try:
            payload = json.loads(self.rfile.read(length).decode("utf-8") or "{}")
        except json.JSONDecodeError:
            self.send_json({"ok": False, "message": "Invalid JSON."}, HTTPStatus.BAD_REQUEST)
            return

        try:
            with STATE_LOCK:
                response = SESSION.request(payload)
        except Exception as exc:  # noqa: BLE001
            self.send_json({"ok": False, "message": str(exc)}, HTTPStatus.BAD_REQUEST)
            return

        status = HTTPStatus.OK if response.get("ok", False) else HTTPStatus.BAD_REQUEST
        self.send_json(response, status)

    def serve_static(self, raw_path: str) -> None:
        relative = unquote(raw_path.lstrip("/"))
        if not relative:
            target = WEB_ROOT / "index.html"
        else:
            target = None
            if relative.startswith("web/frontend/"):
                target = (ROOT / relative).resolve()
            elif relative.startswith("books/"):
                target = (ROOT / relative).resolve()
            elif relative == "favicon.ico":
                self.send_error(HTTPStatus.NOT_FOUND)
                return
            else:
                target = (WEB_ROOT / relative).resolve()

        try:
            target.relative_to(ROOT)
        except ValueError:
            self.send_error(HTTPStatus.FORBIDDEN)
            return

        if target.is_dir():
            target = target / "index.html"
        if not target.exists() or not target.is_file():
            self.send_error(HTTPStatus.NOT_FOUND)
            return

        content_type = mimetypes.guess_type(str(target))[0] or "application/octet-stream"
        data = target.read_bytes()
        self.send_response(HTTPStatus.OK)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)


def main() -> int:
    parser = argparse.ArgumentParser(description="Lone Wolf web migration scaffold")
    parser.add_argument("--host", default="localhost")
    parser.add_argument("--port", type=int, default=int(os.environ.get("LONEWOLF_HTTP_PORT", "8797")))
    parser.add_argument("--quiet", action="store_true", help="Do not print the startup URL.")
    args = parser.parse_args()

    server = ThreadingHTTPServer((args.host, args.port), LoneWolfHandler)
    if not args.quiet:
        print(f"Lone Wolf web app: http://{args.host}:{args.port}", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        SESSION.close()
        server.server_close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
