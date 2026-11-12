#!/usr/bin/env python3
"""Registers the observer's GitHub App from github-app-manifest.json (ADR 19).

Serves a page on 127.0.0.1 that posts the manifest to GitHub, receives the
one-time code on the redirect, exchanges it for the App's credentials, and
writes them straight to Doppler work-graph/prd_work_graph. Nothing secret is
printed. Run it with Doppler logged in, then open the printed local URL.
"""

import html
import http.server
import json
import pathlib
import secrets
import subprocess
import sys
import urllib.parse
import urllib.request

PORT = 8765
DOPPLER = ["--project", "work-graph", "--config", "prd_work_graph"]
MANIFEST_PATH = pathlib.Path(__file__).resolve().parent.parent / "github-app-manifest.json"

state = secrets.token_urlsafe(32)
manifest = json.loads(MANIFEST_PATH.read_text())
manifest["redirect_url"] = f"http://127.0.0.1:{PORT}/callback"
done = False


def doppler_set(name: str, value: str) -> None:
    subprocess.run(
        ["doppler", "secrets", "set", name, *DOPPLER],
        input=value.encode(),
        stdout=subprocess.DEVNULL,
        check=True,
    )


def convert(code: str) -> dict:
    request = urllib.request.Request(
        f"https://api.github.com/app-manifests/{urllib.parse.quote(code)}/conversions",
        method="POST",
        headers={"Accept": "application/vnd.github+json", "X-GitHub-Api-Version": "2022-11-28"},
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.load(response)


class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, *_args) -> None:
        pass

    def reply(self, body: str, status: int = 200) -> None:
        self.send_response(status)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.end_headers()
        self.wfile.write(body.encode())

    def do_GET(self) -> None:
        global done
        url = urllib.parse.urlparse(self.path)
        if url.path == "/":
            action = "https://github.com/settings/apps/new?state=" + urllib.parse.quote(state)
            self.reply(
                f'<form id="f" method="post" action="{html.escape(action)}">'
                f'<input type="hidden" name="manifest" value="{html.escape(json.dumps(manifest))}">'
                "</form><script>document.getElementById('f').submit()</script>"
            )
            return
        if url.path != "/callback":
            self.reply("Not found", 404)
            return
        query = urllib.parse.parse_qs(url.query)
        if query.get("state") != [state] or "code" not in query:
            self.reply("State mismatch; nothing was stored.", 400)
            return
        app = convert(query["code"][0])
        doppler_set("GITHUB_APP_ID", str(app["id"]))
        doppler_set("GITHUB_APP_PRIVATE_KEY", app["pem"])
        doppler_set("GITHUB_WEBHOOK_SECRET", app["webhook_secret"])
        doppler_set("GITHUB_APP_CLIENT_SECRET", app["client_secret"])
        install = f"https://github.com/apps/{app['slug']}/installations/new"
        self.reply(
            f"<p>Registered <b>{html.escape(app['slug'])}</b>; credentials are in Doppler.</p>"
            f'<p>Next: <a href="{html.escape(install)}">install it</a> on the repositories to observe.</p>'
        )
        print(f"Registered App {app['slug']} (ID {app['id']}); credentials written to Doppler.")
        print(f"Install it: {install}")
        done = True


def main() -> None:
    server = http.server.HTTPServer(("127.0.0.1", PORT), Handler)
    print(f"Open http://127.0.0.1:{PORT}/ in the browser signed in to GitHub.")
    while not done:
        server.handle_request()


if __name__ == "__main__":
    sys.exit(main())
