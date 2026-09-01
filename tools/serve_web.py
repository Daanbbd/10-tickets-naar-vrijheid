#!/usr/bin/env python3
"""Serveert build/web op het LAN, zodat je telefoon de build kan openen.

Python's http.server kent .wasm niet op macOS en zet geen COOP/COEP-headers.
Zonder de juiste mimetype weigert de browser instantiateStreaming; de headers
staan erbij voor het geval de threaded variant ooit terugkomt.

    python3 tools/serve_web.py [poort]
"""

import http.server
import socket
import sys
from pathlib import Path

WORTEL = Path(__file__).resolve().parent.parent / "build" / "web"


class Handler(http.server.SimpleHTTPRequestHandler):
    extensions_map = {
        **http.server.SimpleHTTPRequestHandler.extensions_map,
        ".wasm": "application/wasm",
        ".js": "text/javascript",
        ".pck": "application/octet-stream",
    }

    def end_headers(self):
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def log_message(self, formaat, *args):
        sys.stderr.write("%s\n" % (formaat % args))


def lan_ip() -> str:
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(("8.8.8.8", 80))
        return s.getsockname()[0]
    finally:
        s.close()


if __name__ == "__main__":
    poort = int(sys.argv[1]) if len(sys.argv) > 1 else 8060
    if not (WORTEL / "index.html").exists():
        sys.exit(f"Geen build gevonden in {WORTEL}. Exporteer eerst.")
    http.server.SimpleHTTPRequestHandler.directory = str(WORTEL)
    server = http.server.ThreadingHTTPServer(
        ("0.0.0.0", poort),
        lambda *a, **kw: Handler(*a, directory=str(WORTEL), **kw),
    )
    print(f"Open op je telefoon:  http://{lan_ip()}:{poort}/index.html")
    server.serve_forever()
