#!/usr/bin/env python3
import json
import os
import sys
import time
import urllib.error
import urllib.request
from http.server import HTTPServer, BaseHTTPRequestHandler
from socketserver import ThreadingMixIn
from urllib.parse import urlparse, parse_qs

OPENCODE_HOST = os.environ.get("OPENCODE_HOST", "127.0.0.1")
OPENCODE_PORT = os.environ.get("OPENCODE_PORT", "4096")
GATEWAY_HOST = os.environ.get("GATEWAY_HOST", "0.0.0.0")
GATEWAY_PORT = int(os.environ.get("GATEWAY_PORT", "8080"))
TIMEOUT = int(os.environ.get("REQUEST_TIMEOUT", "120"))

BASE = f"http://{OPENCODE_HOST}:{OPENCODE_PORT}"


def _json_req(method, path, body=None):
    url = f"{BASE}{path}"
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
            text = resp.read().decode()
            if not text:
                return None
            return json.loads(text)
    except urllib.error.HTTPError as e:
        err_body = e.read().decode() if e.fp else "{}"
        try:
            return json.loads(err_body)
        except json.JSONDecodeError:
            return {"_tag": "HTTPError", "status": e.code, "body": err_body}


def _extract_prompt_from_path(path: str, query) -> str | None:
    if "q" in query:
        return query["q"][0]
    parsed = path.rstrip("/")
    if parsed and parsed != "/":
        return parsed.lstrip("/")
    return None


def _call_opencode(prompt: str) -> str | None:
    session = _json_req("POST", "/api/session", {})
    if not session or "data" not in session:
        return None
    sid = session["data"]["id"]

    try:
        admit = _json_req("POST", f"/api/session/{sid}/prompt", {
            "prompt": {"text": prompt}
        })
        if not admit or "data" not in admit:
            return None

        deadline = time.time() + TIMEOUT
        while time.time() < deadline:
            msgs = _json_req("GET", f"/api/session/{sid}/message")
            if msgs and "data" in msgs:
                for m in reversed(msgs["data"]):
                    if m.get("type") == "assistant":
                        parts = []
                        for c in m.get("content", []):
                            if c.get("type") == "text":
                                parts.append(c.get("text", ""))
                        text = "".join(parts)
                        if text:
                            return text
            time.sleep(1)
        return None
    finally:
        try:
            _json_req("DELETE", f"/api/session/{sid}")
        except Exception:
            pass


class GatewayHandler(BaseHTTPRequestHandler):
    def _send_text(self, status, text):
        self.send_response(status)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.end_headers()
        if text is not None:
            self.wfile.write(text.encode())

    def _get_prompt(self) -> str | None:
        length = int(self.headers.get("Content-Length", 0))
        raw = self.rfile.read(length) if length > 0 else b""

        ct = (self.headers.get("Content-Type") or "").lower()

        if not raw:
            return _extract_prompt_from_path(self.path, parse_qs(urlparse(self.path).query))

        if "application/json" in ct:
            body = json.loads(raw)
            if isinstance(body, dict):
                return body.get("message") or body.get("prompt") or body.get("text")
            return str(body)

        if "application/x-www-form-urlencoded" in ct:
            params = parse_qs(raw.decode())
            for key in ("message", "prompt", "text", "q"):
                if key in params:
                    return params[key][0]

        return raw.decode().strip()

    def _handle(self):
        prompt = self._get_prompt()
        if not prompt:
            self._send_text(400, "error: no prompt provided\n")
            return

        try:
            result = _call_opencode(prompt)
        except urllib.error.URLError as e:
            self._send_text(502, f"error: cannot reach opencode serve ({e.reason})\n")
            return
        except Exception as e:
            self._send_text(500, f"error: {e}\n")
            return

        if result is None:
            self._send_text(504, "error: model did not return a response\n")
            return

        self._send_text(200, result)

    def do_GET(self):
        self._handle()

    def do_POST(self):
        self._handle()


class ThreadedHTTPServer(ThreadingMixIn, HTTPServer):
    allow_reuse_address = True
    daemon_threads = True


def main():
    server = ThreadedHTTPServer((GATEWAY_HOST, GATEWAY_PORT), GatewayHandler)
    print(f"gateway listening on {GATEWAY_HOST}:{GATEWAY_PORT} -> opencode at {BASE}")
    print(f"usage: curl -d 'your prompt' http://localhost:{GATEWAY_PORT}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nshutting down...")
        server.shutdown()


if __name__ == "__main__":
    main()
