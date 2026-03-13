import json
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlparse


ROOT = Path(__file__).resolve().parents[1]
DASHBOARD_DIR = ROOT / "dashboard"
JSON_PATH = DASHBOARD_DIR / "ocr_benchmark_dashboard.json"
HTML_PATH = DASHBOARD_DIR / "ocr_benchmark_dashboard.html"
WORKER_STATE_PATH = DASHBOARD_DIR / "baseline_worker_state.json"


def read_json(path: Path) -> dict:
    if not path.exists():
        return {}
    return json.loads(path.read_text(encoding="utf-8"))


class Handler(BaseHTTPRequestHandler):
    def _json(self, payload, code=HTTPStatus.OK):
        blob = json.dumps(payload).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(blob)))
        self.end_headers()
        try:
            self.wfile.write(blob)
        except ConnectionAbortedError:
            return

    def _serve_file(self, path: Path, content_type: str):
        if not path.exists():
            self.send_error(HTTPStatus.NOT_FOUND)
            return
        raw = path.read_bytes()
        self.send_response(HTTPStatus.OK)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(raw)))
        self.end_headers()
        try:
            self.wfile.write(raw)
        except ConnectionAbortedError:
            return

    def do_GET(self):
        parsed = urlparse(self.path)
        if parsed.path in ("/", "/ocr_benchmark_dashboard.html"):
            return self._serve_file(HTML_PATH, "text/html; charset=utf-8")
        if parsed.path == "/ocr_benchmark_dashboard.json":
            return self._serve_file(JSON_PATH, "application/json; charset=utf-8")
        if parsed.path == "/api/status":
            return self._json(
                {
                    "dashboard": read_json(JSON_PATH),
                    "worker": read_json(WORKER_STATE_PATH),
                }
            )
        self.send_error(HTTPStatus.NOT_FOUND)


def main():
    server = ThreadingHTTPServer(("127.0.0.1", 8765), Handler)
    print("Dashboard server running at http://127.0.0.1:8765/ocr_benchmark_dashboard.html")
    server.serve_forever()


if __name__ == "__main__":
    main()
