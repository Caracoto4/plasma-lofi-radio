#!/usr/bin/env python3
"""lofi-nowplaying — publish the track lofiradio.ru is currently playing.

The Icecast stream carries the song title in-band as `StreamTitle='Artist - Title'`
(one metadata block per `icy-metaint` audio bytes). Qt's multimedia backend does
not expose it, so this tiny sidecar reads it straight from the socket and serves
it as JSON on localhost for the Plasma widget.

Endpoints:
    GET /nowplaying.json   {"artist": ..., "title": ..., "station": ..., "updated": ...}
    GET /health            "ok"

Stdlib only, no dependencies.
"""
from __future__ import annotations

import json
import os
import re
import socket
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

STREAM_HOST = "live.lofiradio.ru"
STREAM_PORT = 8000
STREAM_PATH = "/lofi_mp3_128"
USER_AGENT = "lofiplayer-widget/2.0"

HTTP_HOST = "127.0.0.1"
HTTP_PORTS = (8731, 8732, 8733)

CONNECT_TIMEOUT = 10.0
READ_TIMEOUT = 20.0
TITLE_RE = re.compile(rb"StreamTitle='(.*?)';", re.S)

STATE_LOCK = threading.Lock()
STATE = {
    "raw": "",
    "artist": "",
    "title": "",
    "station": "LoFi Radio",
    "stream": "http://%s:%d%s" % (STREAM_HOST, STREAM_PORT, STREAM_PATH),
    "updated": 0,
    "connected": False,
}


def log(message: str) -> None:
    print("lofi-nowplaying: %s" % message, flush=True)


def parse_title(raw: str):
    """Split `Artist - Title` the way the widget displays it."""
    text = raw.strip()
    if not text or text.lower() in ("unknown", "null"):
        return "", ""
    parts = re.split(r"\s+[-\u2013\u2014|]\s+", text, maxsplit=1)
    if len(parts) == 2 and parts[0] and parts[1]:
        return parts[0].strip(), parts[1].strip()
    return "", text


def publish(raw: str) -> None:
    artist, title = parse_title(raw)
    with STATE_LOCK:
        STATE["raw"] = raw.strip()
        STATE["artist"] = artist
        STATE["title"] = title
        STATE["updated"] = int(time.time())
        STATE["connected"] = True


def snapshot() -> bytes:
    with STATE_LOCK:
        payload = dict(STATE)
    return json.dumps(payload, ensure_ascii=False).encode("utf-8")


def follow_stream() -> None:
    """Connect, read the icy headers, then publish every metadata block."""
    request = (
        "GET %s HTTP/1.1\r\n"
        "Host: %s:%d\r\n"
        "User-Agent: %s\r\n"
        "Icy-MetaData: 1\r\n"
        "Connection: keep-alive\r\n"
        "\r\n" % (STREAM_PATH, STREAM_HOST, STREAM_PORT, USER_AGENT)
    )
    with socket.create_connection((STREAM_HOST, STREAM_PORT), timeout=CONNECT_TIMEOUT) as sock:
        sock.settimeout(READ_TIMEOUT)
        sock.sendall(request.encode("ascii"))

        header = b""
        while b"\r\n\r\n" not in header:
            chunk = sock.recv(4096)
            if not chunk:
                raise ConnectionError("no response headers")
            header += chunk
        head, _, pending = header.partition(b"\r\n\r\n")

        meta_interval = 0
        for line in head.decode("utf-8", "replace").splitlines():
            if line.lower().startswith("icy-metaint:"):
                meta_interval = int(line.split(":", 1)[1].strip())
        if meta_interval <= 0:
            raise ConnectionError("server did not enable icy metadata")

        log("connected to the stream, icy-metaint=%d" % meta_interval)
        last_published = ""

        while True:
            while len(pending) < meta_interval + 1:
                chunk = sock.recv(32768)
                if not chunk:
                    raise ConnectionError("stream closed")
                pending += chunk

            pending = pending[meta_interval:]          # drop the audio
            meta_len = pending[0] * 16
            pending = pending[1:]
            while len(pending) < meta_len:
                chunk = sock.recv(32768)
                if not chunk:
                    raise ConnectionError("stream closed")
            block, pending = pending[:meta_len], pending[meta_len:]

            match = TITLE_RE.search(block)
            if match:
                raw = match.group(1).decode("utf-8", "replace").strip()
                if raw and raw != last_published:
                    last_published = raw
                    publish(raw)
                    artist, title = parse_title(raw)
                    log("now playing: %s - %s" % (artist, title))


def stream_worker() -> None:
    delay = 2.0
    while True:
        try:
            follow_stream()
            delay = 2.0
        except Exception as exc:  # noqa: BLE001 - keep the service alive
            with STATE_LOCK:
                STATE["connected"] = False
            log("reconnecting after error: %s" % exc)
            time.sleep(delay)
            delay = min(delay * 2, 30.0)


class Handler(BaseHTTPRequestHandler):
    server_version = "lofi-nowplaying/2.0"

    def _send(self, body: bytes, content_type: str) -> None:
        self.send_response(200)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        # the widget runs from a file:// origin, so allow the cross-origin read
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self) -> None:  # noqa: N802 - http.server API
        path = self.path.split("?", 1)[0]
        if path in ("/nowplaying.json", "/", "/nowplaying"):
            self._send(snapshot(), "application/json; charset=utf-8")
        elif path == "/health":
            self._send(b"ok\n", "text/plain; charset=utf-8")
        else:
            self.send_error(404, "not found")

    def do_OPTIONS(self) -> None:  # noqa: N802 - http.server API
        self.send_response(204)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Headers", "*")
        self.end_headers()

    def log_message(self, fmt, *args):  # keep the journal quiet
        pass


def start_http_server() -> ThreadingHTTPServer:
    last_error = None
    for port in HTTP_PORTS:
        try:
            server = ThreadingHTTPServer((HTTP_HOST, port), Handler)
            server.daemon_threads = True
            log("serving http://%s:%d/nowplaying.json" % (HTTP_HOST, port))
            return server
        except OSError as exc:
            last_error = exc
            log("port %d busy (%s)" % (port, exc))
    raise SystemExit("no free port in %s: %s" % (HTTP_PORTS, last_error))


def main() -> int:
    log("starting (pid %d)" % os.getpid())
    server = start_http_server()
    threading.Thread(target=stream_worker, name="stream", daemon=True).start()
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
