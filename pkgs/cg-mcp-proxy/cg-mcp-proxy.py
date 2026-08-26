#!/usr/bin/env python3
"""Bridge a stdio MCP client to a Chainguard MCP server over HTTP.

Every coding agent can start a stdio MCP server, so this program makes the
Chainguard MCP servers reachable from all of them with one definition. It reads
JSON-RPC messages on stdin, forwards each one over HTTP, and writes the replies
to stdout.

It exists for the token, not for the transport. Those servers use an OAuth flow
that registers a client per session, and that registration does not outlive the
session. An agent caches the registration and re-sends it, so later
re-authentication fails with "invalid client_id".

The servers accept a bearer token whose audience is the resource URL, so this
program asks chainctl for one instead. A token lasts one hour and a session can
run longer, so the token is re-minted when it comes within
REFRESH_MARGIN_SECONDS of its expiry. Passing a header once at start is what
every off-the-shelf proxy does, and it is exactly what fails here.
"""

from __future__ import annotations

import argparse
import base64
import http.client
import json
import subprocess
import sys
import threading
import time
import urllib.error
import urllib.request
from typing import cast, final

# Re-mint this far ahead of the expiry. chainctl returns its cached token until
# the token nears expiry, so an early ask costs almost nothing.
REFRESH_MARGIN_SECONDS = 300
MINT_TIMEOUT_SECONDS = 30
REQUEST_TIMEOUT_SECONDS = 120
# A tool call can be slow, so requests are not serialised. The cap keeps a
# runaway client from opening an unbounded number of sockets.
MAX_CONCURRENT_REQUESTS = 8

# JSON-RPC error code for a server-side fault, from the JSON-RPC 2.0 spec.
INTERNAL_ERROR = -32603


@final
class Minter:
    """Hold one audience token and replace it before it expires."""

    def __init__(self, audience: str) -> None:
        self._audience = audience
        self._lock = threading.Lock()
        self._token: str | None = None
        self._expires_at = 0.0

    def token(self, force: bool = False) -> str:
        with self._lock:
            fresh = self._token is not None and time.time() < (
                self._expires_at - REFRESH_MARGIN_SECONDS
            )
            if fresh and not force:
                return cast(str, self._token)
            token = self._mint()
            self._token = token
            self._expires_at = self._expiry_of(token)
            return token

    def _mint(self) -> str:
        # The shared chainctl config is enough for every environment. The token
        # cache is keyed by audience and holds the issuer that signed it, so a
        # staging audience returns a token from the staging issuer with no extra
        # flags. Only "auth login" needs a config file of its own, because it
        # persists --api and --issuer into whichever config it uses.
        command = ["chainctl", "auth", "token", "--audience", self._audience]
        result = subprocess.run(
            command,
            capture_output=True,
            text=True,
            timeout=MINT_TIMEOUT_SECONDS,
            stdin=subprocess.DEVNULL,
            check=False,
        )
        token = result.stdout.strip()
        if result.returncode != 0 or not token:
            detail = result.stderr.strip()[:200] or "chainctl printed no token"
            raise RuntimeError(f"cannot mint a token for {self._audience}: {detail}")
        return token

    @staticmethod
    def _expiry_of(token: str) -> float:
        """Read the expiry from the token itself.

        chainctl prints no expiry, and the exp claim is the only statement of it
        that cannot drift from the token. A token that carries no readable exp is
        treated as already old, so the next request mints again.
        """
        try:
            part = token.split(".")[1]
            part += "=" * (-len(part) % 4)
            claims = cast(dict[str, object], json.loads(base64.urlsafe_b64decode(part)))
            return float(cast(int, claims["exp"]))
        except Exception:  # noqa: BLE001
            return 0.0


@final
class Forwarder:
    """Send one JSON-RPC message to the server and return its replies."""

    def __init__(self, url: str, minter: Minter) -> None:
        self._url = url
        self._minter = minter
        self._lock = threading.Lock()
        self._session: str | None = None

    def send(self, message: bytes) -> list[str]:
        # A 401 is the one fault worth retrying. The token can expire between
        # the check above and the request arriving, and a stale token is also
        # what a clock skew looks like from here.
        try:
            return self._post(message, self._minter.token())
        except urllib.error.HTTPError as error:
            if error.code != 401:
                raise
        return self._post(message, self._minter.token(force=True))

    def _post(self, message: bytes, token: str) -> list[str]:
        headers = {
            "Authorization": "Bearer " + token,
            "Content-Type": "application/json",
            "Accept": "application/json, text/event-stream",
        }
        with self._lock:
            session = self._session
        if session is not None:
            headers["Mcp-Session-Id"] = session

        request = urllib.request.Request(
            self._url, data=message, method="POST", headers=headers
        )
        with cast(
            http.client.HTTPResponse,
            urllib.request.urlopen(request, timeout=REQUEST_TIMEOUT_SECONDS),
        ) as response:
            # A stateless server sends no session id, and these Chainguard
            # servers do not. Recording it when present keeps the proxy correct
            # for a server that does use one.
            given = response.headers.get("Mcp-Session-Id")
            if given:
                with self._lock:
                    self._session = given
            content_type = response.headers.get("Content-Type", "")
            # 202 answers a notification and carries no body.
            if response.status == 202:
                return []
            body = response.read().decode(errors="replace")
        return decode(body, content_type)


def decode(body: str, content_type: str) -> list[str]:
    """Return each JSON-RPC message in a response body.

    These servers answer a single request with an SSE stream carrying one
    "message" event, so the payload has to come out of the data lines. A plain
    JSON body is passed through, which keeps the proxy correct for a server that
    does not use SSE.
    """
    stripped = body.strip()
    if not stripped:
        return []
    if "text/event-stream" not in content_type and not stripped.startswith("event:"):
        return [stripped]
    messages: list[str] = []
    for block in stripped.split("\n\n"):
        data = [
            line[len("data:") :].strip()
            for line in block.splitlines()
            if line.startswith("data:")
        ]
        if data:
            messages.append("".join(data))
    return messages


@final
class Writer:
    """Serialise writes to stdout, because workers run in parallel."""

    def __init__(self) -> None:
        self._lock = threading.Lock()

    def write(self, line: str) -> None:
        with self._lock:
            _ = sys.stdout.write(line + "\n")
            _ = sys.stdout.flush()


def error_reply(request_id: object, detail: str) -> str:
    return json.dumps(
        {
            "jsonrpc": "2.0",
            "id": request_id,
            "error": {"code": INTERNAL_ERROR, "message": detail},
        }
    )


def handle(raw: str, forwarder: Forwarder, writer: Writer) -> None:
    try:
        parsed = cast(dict[str, object], json.loads(raw))
    except ValueError:
        print(f"cg-mcp-proxy: dropped a line that is not JSON: {raw[:120]}",
              file=sys.stderr)
        return

    request_id = parsed.get("id")
    try:
        for message in forwarder.send(raw.encode()):
            writer.write(message)
    except Exception as error:  # noqa: BLE001
        detail = f"{type(error).__name__}: {error!s:.200}"
        print(f"cg-mcp-proxy: {detail}", file=sys.stderr)
        # A notification carries no id and expects no reply, so a failure there
        # is logged and nothing more. Answering a request keeps the client from
        # waiting for a reply that will never come.
        if request_id is not None:
            writer.write(error_reply(request_id, detail))


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    _ = parser.add_argument("url", help="MCP endpoint, for example https://cgr.dev/mcp")
    _ = parser.add_argument(
        "--audience",
        default=None,
        metavar="URL",
        help="token audience, defaulting to the endpoint URL",
    )
    arguments = parser.parse_args(argv)
    url = cast(str, arguments.url)
    audience = cast("str | None", arguments.audience) or url

    minter = Minter(audience)
    forwarder = Forwarder(url, minter)
    writer = Writer()
    limit = threading.BoundedSemaphore(MAX_CONCURRENT_REQUESTS)
    workers: list[threading.Thread] = []

    def run(raw: str) -> None:
        try:
            handle(raw, forwarder, writer)
        finally:
            limit.release()

    # MCP frames stdio messages as one JSON object per line.
    for line in sys.stdin:
        raw = line.strip()
        if not raw:
            continue
        _ = limit.acquire()
        worker = threading.Thread(target=run, args=(raw,), daemon=True)
        workers.append(worker)
        worker.start()
        workers = [w for w in workers if w.is_alive()]

    for worker in workers:
        worker.join(timeout=REQUEST_TIMEOUT_SECONDS)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
