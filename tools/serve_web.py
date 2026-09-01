#!/usr/bin/env python3
"""Serveert build/web over HTTPS op het LAN, zodat je telefoon de build kan openen.

Godot 4.7 weigert te starten buiten een secure context: `getMissingFeatures()`
in de HTML-shell checkt `window.isSecureContext` en meldt anders "Secure Context
- Check web server configuration (use HTTPS)". Alleen localhost en https gelden
als secure, dus een LAN-IP over http komt niet voorbij het laadscherm — ook al
werkt datzelfde adres op je Mac via 127.0.0.1 prima.

Vandaar TLS met een zelfgetekend certificaat. Safari waarschuwt daarover; via
"Toon details" → "deze website bezoeken" kom je erdoor, en daarna is de origin
https en dus secure.

Python's http.server kent .wasm niet op macOS; zonder die mimetype weigert de
browser instantiateStreaming.

    python3 tools/serve_web.py [poort]
    python3 tools/serve_web.py --http    # zonder TLS, alleen voor 127.0.0.1
"""

import http.server
import socket
import ssl
import subprocess
import sys
from pathlib import Path

WORTEL = Path(__file__).resolve().parent.parent / "build" / "web"
CERTMAP = Path(__file__).resolve().parent.parent / "build" / "cert"


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


def certificaat(ip: str) -> tuple[Path, Path]:
    """Maakt zo nodig een zelfgetekend certificaat voor dit IP.

    De subjectAltName is de reden dat dit met de hand gaat en niet met een
    losse -subj: iOS negeert sinds versie 13 de CN volledig en kijkt alleen
    naar de SAN. Zonder IP in de SAN weigert Safari ook ná het doorklikken.

    Het certificaat en de sleutel staan onder build/, en die map is genegeerd —
    een privésleutel hoort niet in de geschiedenis.
    """
    CERTMAP.mkdir(parents=True, exist_ok=True)
    cert, key = CERTMAP / f"{ip}.pem", CERTMAP / f"{ip}.key"
    if cert.exists() and key.exists():
        return cert, key

    print(f"Certificaat maken voor {ip} ...")
    try:
        subprocess.run(
            ["openssl", "req", "-x509", "-newkey", "rsa:2048", "-sha256",
             "-days", "365", "-nodes",
             "-keyout", str(key), "-out", str(cert),
             "-subj", f"/CN={ip}",
             "-addext", f"subjectAltName=IP:{ip},IP:127.0.0.1,DNS:localhost"],
            check=True, capture_output=True, text=True)
    except FileNotFoundError:
        sys.exit("openssl niet gevonden; start met --http en test op 127.0.0.1")
    except subprocess.CalledProcessError as e:
        sys.exit(f"openssl faalde:\n{e.stderr}")
    return cert, key


if __name__ == "__main__":
    args = [a for a in sys.argv[1:]]
    tls = "--http" not in args
    poort = next((int(a) for a in args if a.isdigit()), 8060)

    if not (WORTEL / "index.html").exists():
        sys.exit(f"Geen build gevonden in {WORTEL}. Exporteer eerst.")

    ip = lan_ip()
    server = http.server.ThreadingHTTPServer(
        ("0.0.0.0", poort),
        lambda *a, **kw: Handler(*a, directory=str(WORTEL), **kw),
    )

    if tls:
        cert, key = certificaat(ip)
        ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        ctx.load_cert_chain(certfile=cert, keyfile=key)
        server.socket = ctx.wrap_socket(server.socket, server_side=True)
        print(f"\nOpen op je telefoon:  https://{ip}:{poort}/index.html")
        print("Safari waarschuwt over het certificaat: "
              "Toon details -> deze website bezoeken.\n")
    else:
        print(f"\nZonder TLS. Godot start alleen op http://127.0.0.1:{poort}"
              f"/index.html\n")

    server.serve_forever()
