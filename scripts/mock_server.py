#!/usr/bin/env python3
import argparse
import json
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


EVENTS = []
MAX_EVENTS = 500


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


class MockHandler(BaseHTTPRequestHandler):
    server_version = "GPSPingerMock/1.0"

    def log_message(self, fmt: str, *args) -> None:
        return

    def _write_json(self, payload: dict, status: int = 200) -> None:
        data = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self) -> None:
        if self.path == "/health":
            self._write_json({"ok": True, "timestamp": now_iso()})
            return

        if self.path == "/logs":
            self._write_json({"count": len(EVENTS), "events": EVENTS})
            return

        self._write_json({"error": "not found"}, status=404)

    def do_POST(self) -> None:
        if self.path != "/ping":
            self._write_json({"error": "not found"}, status=404)
            return

        content_length = int(self.headers.get("Content-Length", "0"))
        raw = self.rfile.read(content_length) if content_length > 0 else b""

        try:
            payload = json.loads(raw.decode("utf-8")) if raw else {}
        except json.JSONDecodeError:
            self._write_json({"error": "invalid json"}, status=400)
            return

        event = {
            "receivedAt": now_iso(),
            "path": self.path,
            "remoteAddress": self.client_address[0],
            "payload": payload,
        }
        EVENTS.append(event)
        if len(EVENTS) > MAX_EVENTS:
            del EVENTS[0 : len(EVENTS) - MAX_EVENTS]

        print(json.dumps(event), flush=True)
        self._write_json({"ok": True, "receivedAt": event["receivedAt"]})


def main() -> None:
    parser = argparse.ArgumentParser(description="Local mock server for GPSPinger.")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8787)
    args = parser.parse_args()

    server = ThreadingHTTPServer((args.host, args.port), MockHandler)
    print(f"Mock server listening on http://{args.host}:{args.port}", flush=True)
    print("POST /ping  | GET /logs  | GET /health", flush=True)

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
