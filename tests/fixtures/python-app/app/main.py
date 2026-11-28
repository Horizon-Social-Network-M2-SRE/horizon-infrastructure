"""Tiny HTTP service: GET /health answers 200."""

from http.server import BaseHTTPRequestHandler, HTTPServer


def health() -> dict[str, str]:
    return {"status": "ok"}


class Handler(BaseHTTPRequestHandler):
    def do_GET(self) -> None:
        code = 200 if self.path == "/health" else 404
        self.send_response(code)
        self.end_headers()


if __name__ == "__main__":
    HTTPServer(("0.0.0.0", 8000), Handler).serve_forever()
