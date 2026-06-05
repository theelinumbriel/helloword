#!/usr/bin/env python3
"""Tiny zero-dependency static server for helloword.

Run:  python3 serve.py
Then open http://localhost:8000 (or $PORT) in your browser.

Sends no-cache headers so the browser always loads the latest version
(otherwise an app-mode window can get pinned to a stale index.html).
Set HELLOWORD_NOOPEN=1 to skip auto-opening a browser (used by the launchers).
"""
import http.server
import socketserver
import os
import webbrowser

PORT = int(os.environ.get("PORT", 8000))
os.chdir(os.path.dirname(os.path.abspath(__file__)))


class Handler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0")
        self.send_header("Pragma", "no-cache")
        self.send_header("Expires", "0")
        super().end_headers()

    def send_header(self, key, value):
        # Drop the default Last-Modified so browsers can't do a 304 revalidate
        if key.lower() == "last-modified":
            return
        super().send_header(key, value)

    def log_message(self, *args):
        pass  # quiet


if __name__ == "__main__":
    socketserver.TCPServer.allow_reuse_address = True
    with socketserver.TCPServer(("127.0.0.1", PORT), Handler) as httpd:
        url = f"http://localhost:{PORT}"
        print(f"helloword is running at {url}")
        print("Press Ctrl+C to stop.")
        if os.environ.get("HELLOWORD_NOOPEN") != "1":
            try:
                webbrowser.open(url)
            except Exception:
                pass
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\nStopped.")
