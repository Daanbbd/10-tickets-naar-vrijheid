#!/usr/bin/env python3
"""Serveert build/web over HTTPS op het LAN, zodat je telefoon de build kan openen.

Godot 4.7 weigert te starten buiten een secure context: `getMissingFeatures()`
in de HTML-shell checkt `window.isSecureContext` en meldt anders alleen
"Secure Context - Check web server configuration (use HTTPS)". Localhost is
secure, een LAN-IP over http niet — dus een build die op je Mac via 127.0.0.1
prima draait komt op je telefoon niet voorbij het laadscherm.

Vandaar TLS. Het script maakt een eigen mini-CA en een servercertificaat
daaronder, en biedt de CA over gewoon http aan zodat je telefoon hem kan
ophalen en vertrouwen. Daarna is er geen waarschuwing meer.

    python3 tools/serve_web.py [poort]
    python3 tools/serve_web.py --http    # zonder TLS

`--http` heeft twee toepassingen: een snelle controle op 127.0.0.1 (dat geldt
als secure context), en draaien achter een proxy die zelf TLS termineert met
een echt certificaat — `tailscale serve` of een tunnel. In dat tweede geval is
de origin https en dus secure, en is het zelfgetekende spoor hierboven niet
nodig.
"""

import http.server
import socket
import ssl
import subprocess
import sys
import threading
from pathlib import Path

WORTEL = Path(__file__).resolve().parent.parent / "build" / "web"
CERTMAP = Path(__file__).resolve().parent.parent / "build" / "cert"

# Apple stelt sinds iOS 13 harde eisen aan servercertificaten, en bij een
# overtreding weigert Safari zónder doorklik-optie: je krijgt geen "bezoek deze
# website" maar een blokkade. Wat hieronder dus niet weg mag:
#
#   * subjectAltName met het IP erin; de CN wordt volledig genegeerd
#   * extendedKeyUsage met serverAuth
#   * SHA-256 of beter, RSA minimaal 2048 bits
#   * geldigheid maximaal 398 dagen
#
# En de CA moet echt een CA zijn (basicConstraints CA:TRUE): iOS toont alleen
# root-certificaten onder Certificaatvertrouwen. Een los self-signed
# servercertificaat installeert wel, maar is daar niet aan te zetten.
DAGEN = "397"


def sh(*args: str) -> None:
    try:
        subprocess.run(args, check=True, capture_output=True, text=True)
    except FileNotFoundError:
        sys.exit("openssl niet gevonden; start met --http en test op 127.0.0.1")
    except subprocess.CalledProcessError as e:
        sys.exit(f"openssl faalde:\n{e.stderr}")


def certificaten(ip: str) -> tuple[Path, Path, Path]:
    """Maakt zo nodig een CA plus servercertificaat. Geeft (cert, key, ca).

    Alles staat onder build/, en die map is genegeerd — er staan privésleutels
    tussen en die horen niet in de geschiedenis.
    """
    CERTMAP.mkdir(parents=True, exist_ok=True)
    ca, ca_key = CERTMAP / "ca.pem", CERTMAP / "ca.key"
    cert, key = CERTMAP / f"{ip}.pem", CERTMAP / f"{ip}.key"
    if all(p.exists() for p in (ca, ca_key, cert, key)):
        return cert, key, ca

    print(f"Certificaten maken voor {ip} ...")

    if not (ca.exists() and ca_key.exists()):
        sh("openssl", "req", "-x509", "-newkey", "rsa:2048", "-sha256",
           "-days", DAGEN, "-nodes", "-keyout", str(ca_key), "-out", str(ca),
           "-subj", "/CN=10 Tickets LAN-test CA",
           "-addext", "basicConstraints=critical,CA:TRUE",
           "-addext", "keyUsage=critical,keyCertSign,cRLSign")

    csr = CERTMAP / f"{ip}.csr"
    ext = CERTMAP / f"{ip}.ext"
    ext.write_text(
        f"subjectAltName=IP:{ip},IP:127.0.0.1,DNS:localhost\n"
        "extendedKeyUsage=serverAuth\n"
        "keyUsage=digitalSignature,keyEncipherment\n"
        "basicConstraints=critical,CA:FALSE\n")

    sh("openssl", "req", "-newkey", "rsa:2048", "-nodes",
       "-keyout", str(key), "-out", str(csr), "-subj", f"/CN={ip}")
    sh("openssl", "x509", "-req", "-in", str(csr),
       "-CA", str(ca), "-CAkey", str(ca_key), "-CAcreateserial",
       "-out", str(cert), "-days", DAGEN, "-sha256", "-extfile", str(ext))

    csr.unlink(missing_ok=True)
    ext.unlink(missing_ok=True)
    return cert, key, ca


class Handler(http.server.SimpleHTTPRequestHandler):
    """Python's http.server kent .wasm niet op macOS, en zonder die mimetype
    weigert de browser instantiateStreaming."""

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


class CaHandler(http.server.BaseHTTPRequestHandler):
    """Biedt de CA aan over gewoon http.

    Dit moet zonder TLS, anders heb je het certificaat nodig om het certificaat
    te kunnen ophalen. De mimetype is wat iOS laat aanbieden om het als profiel
    te installeren; met text/plain opent Safari het als tekst.
    """

    ca_pad: Path = None

    def do_GET(self):
        data = self.ca_pad.read_bytes()
        self.send_response(200)
        self.send_header("Content-Type", "application/x-x509-ca-cert")
        self.send_header("Content-Disposition",
                         'attachment; filename="tickets-lan-ca.crt"')
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def log_message(self, formaat, *args):
        sys.stderr.write("[ca] %s\n" % (formaat % args))


def lan_ip() -> str:
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(("8.8.8.8", 80))
        return s.getsockname()[0]
    finally:
        s.close()


def main() -> None:
    args = sys.argv[1:]
    tls = "--http" not in args
    poort = next((int(a) for a in args if a.isdigit()), 8060)

    if not (WORTEL / "index.html").exists():
        sys.exit(f"Geen build gevonden in {WORTEL}. Exporteer eerst.")

    ip = lan_ip()
    server = http.server.ThreadingHTTPServer(
        ("0.0.0.0", poort),
        lambda *a, **kw: Handler(*a, directory=str(WORTEL), **kw))

    if not tls:
        print(f"""
Zonder TLS op poort {poort}.

Godot eist een secure context, dus dit werkt op http://127.0.0.1:{poort}/index.html
of achter een proxy die zelf TLS termineert. Voor die tweede route:

    tailscale serve --bg {poort}
    tailscale serve status        # geeft je de https-URL

Een LAN-IP over http komt niet voorbij het laadscherm.
""", flush=True)
        server.serve_forever()
        return

    cert, key, ca = certificaten(ip)
    ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    ctx.load_cert_chain(certfile=cert, keyfile=key)
    server.socket = ctx.wrap_socket(server.socket, server_side=True)

    CaHandler.ca_pad = ca
    ca_poort = poort + 1
    ca_srv = http.server.ThreadingHTTPServer(("0.0.0.0", ca_poort), CaHandler)
    threading.Thread(target=ca_srv.serve_forever, daemon=True).start()

    print(f"""
STAP 1 — certificaat installeren (eenmalig, op de telefoon)

    http://{ip}:{ca_poort}/tickets-lan-ca.crt

  Sta downloaden toe. Dan: Instellingen -> Profiel gedownload -> Installeer.
  Daarna Instellingen -> Algemeen -> Info -> Certificaatvertrouwen en zet
  "10 Tickets LAN-test CA" aan. Die tweede stap wordt het vaakst vergeten,
  en zonder hem blijft het certificaat onvertrouwd.

STAP 2 — spelen

    https://{ip}:{poort}/index.html

  Zet je stap 1 over, dan kun je ook door de waarschuwing heen klikken:
  Toon details -> deze website bezoeken.

Opruimen na de test: Instellingen -> Algemeen -> VPN en apparaatbeheer ->
profiel verwijderen. En `rm -rf build/cert` op de Mac.
""", flush=True)

    server.serve_forever()


if __name__ == "__main__":
    main()
