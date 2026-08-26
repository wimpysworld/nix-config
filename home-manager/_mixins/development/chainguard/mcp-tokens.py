#!/usr/bin/env python3
"""Give Claude Code a working token for each Chainguard MCP server.

Those servers use an OAuth flow that registers a client per session, and that
registration does not outlive the session. Claude Code caches the registration
and re-sends it, so later re-authentication fails with "invalid client_id", and
clicking Authenticate in /mcp never recovers.

This program skips registration. The servers accept a bearer token whose
audience is the resource URL, and chainctl mints one from the refresh token it
already holds, so this program mints one token per server and copies it into
Claude Code's credential store.

It creates no tokens of its own and it starts no login. cg-tokens and the
chainctl-auth-refresh unit own that work, so a missing credential is reported
with the login that fixes it and is not an error.
"""

from __future__ import annotations

import argparse
import base64
import json
import os
import shutil
import stat
import subprocess
import sys
import urllib.error
import urllib.request
from typing import cast

# chainctl decides for itself whether a missing credential is fatal or worth
# prompting for, and a prompt with its output redirected waits for a code nobody
# can see. Every mint is capped so that a wait becomes a named failure.
MINT_TIMEOUT_SECONDS = 30
PROBE_TIMEOUT_SECONDS = 30

PROBE_BODY = json.dumps(
    {
        "jsonrpc": "2.0",
        "id": 1,
        "method": "initialize",
        "params": {
            "protocolVersion": "2025-06-18",
            "capabilities": {},
            "clientInfo": {"name": "mcp-tokens", "version": "1"},
        },
    }
).encode()


def parse_arguments(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    _ = parser.add_argument(
        "--audience",
        action="append",
        default=[],
        metavar="URL",
        help="MCP resource URL to mint a token for; repeat per server",
    )
    _ = parser.add_argument(
        "--credentials",
        default=os.path.expanduser("~/.claude/.credentials.json"),
        metavar="PATH",
        help="Claude Code credential store to update",
    )
    _ = parser.add_argument(
        "--quiet",
        action="store_true",
        help="report only changes and faults, for a timer",
    )
    return parser.parse_args(argv)


def mint(audience: str) -> str | None:
    """Return a token for one audience from the local chainctl cache.

    The shared chainctl config is enough for every environment. The token cache
    is keyed by audience and holds the issuer that signed each entry, so a
    staging audience returns a token from the staging issuer with no extra
    flags. Only "auth login" needs a config file of its own, because it persists
    --api and --issuer into whichever config it uses.
    """
    command = ["chainctl", "auth", "token", "--audience", audience]
    try:
        result = subprocess.run(
            command,
            capture_output=True,
            text=True,
            timeout=MINT_TIMEOUT_SECONDS,
            stdin=subprocess.DEVNULL,
            check=False,
        )
    except subprocess.TimeoutExpired:
        return None
    token = result.stdout.strip()
    if result.returncode != 0 or not token:
        return None
    return token


def probe(url: str, token: str) -> tuple[str, str]:
    """Put a token to its server before it is stored.

    An "initialize" call is the cheapest request that exercises the auth
    middleware, and it needs no session. Storing a token that the server rejects
    would leave Claude Code failing with no clue why.

    The result is "ok", "rejected" or "unreachable". Only 401 and 403 name the
    token as the fault. Every other outcome, including a read timeout, says
    nothing about the token, so the token is left unwritten and the next run
    tries again.
    """
    request = urllib.request.Request(
        url,
        data=PROBE_BODY,
        method="POST",
        headers={
            "Authorization": "Bearer " + token,
            "Content-Type": "application/json",
            "Accept": "application/json, text/event-stream",
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=PROBE_TIMEOUT_SECONDS):
            return "ok", ""
    except urllib.error.HTTPError as error:
        detail = error.read()[:80].decode(errors="replace").strip()
        status = "rejected" if error.code in (401, 403) else "unreachable"
        return status, f"HTTP {error.code} {detail}"
    except Exception as error:  # noqa: BLE001
        return "unreachable", f"{type(error).__name__}: {error!s:.80}"


def expires_at_ms(token: str) -> int:
    """Read the expiry from the token.

    chainctl prints no expiry, and the exp claim is the only statement of it
    that cannot drift from the token itself.
    """
    part = token.split(".")[1]
    part += "=" * (-len(part) % 4)
    claims = cast(dict[str, object], json.loads(base64.urlsafe_b64decode(part)))
    return int(cast(int, claims["exp"])) * 1000


def save(path: str, store: dict[str, object]) -> str:
    """Replace the credential store atomically, keeping its mode.

    A credentials file must not widen to whatever the umask allows.
    """
    backup = path + ".bak-mcp-tokens"
    mode = stat.S_IMODE(os.stat(path).st_mode)
    _ = shutil.copy2(path, backup)
    temporary = path + ".tmp"
    descriptor = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, mode)
    with os.fdopen(descriptor, "w") as handle:
        json.dump(store, handle)
    os.replace(temporary, path)
    return backup


def main(argv: list[str]) -> int:
    arguments = parse_arguments(argv)
    # Every option is read once into a typed name here, because argparse hands
    # back an untyped namespace and the rest of the program stays checkable.
    quiet = cast(bool, arguments.quiet)
    credentials = cast(str, arguments.credentials)
    audiences = cast(list[str], arguments.audience)

    def say(message: str) -> None:
        if not quiet:
            print(message)

    if not os.path.isfile(credentials):
        say(f"⊚ {credentials} does not exist. Start Claude Code once first.")
        return 0

    tokens: dict[str, str] = {}
    missing: list[str] = []
    for audience in audiences:
        token = mint(audience)
        if token is None:
            missing.append(audience)
            continue
        tokens[audience] = token

    # A missing credential is the state between one daily login and the next, so
    # it names its own fix and exits zero. Only a rejected token is a fault.
    # One login covers every environment, so one message covers every audience.
    if missing:
        say("◍ No usable credential for:")
        for audience in missing:
            say(f"    {audience}")
        say("⊚ Run cg-tokens, or cg-tokens-headless over SSH.")

    if not tokens:
        return 0

    with open(credentials) as handle:
        store = cast(dict[str, object], json.load(handle))

    # Entries are matched on serverUrl, not on the store's own keys. Claude Code
    # keys each one "<serverName>|<hash>", and that hash is not derivable from
    # the server name or its URL, so an entry cannot be created from outside.
    entries = cast(
        dict[str, dict[str, object]], store.setdefault("mcpOAuth", {})
    )
    by_url: dict[str, str] = {
        str(entry["serverUrl"]): key
        for key, entry in entries.items()
        if "serverUrl" in entry
    }

    written: list[str] = []
    rejected: list[tuple[str, str]] = []
    unreachable: list[tuple[str, str]] = []
    absent: list[str] = []
    for audience, token in sorted(tokens.items()):
        key = by_url.get(audience)
        if key is None:
            absent.append(audience)
            continue
        name = str(entries[key].get("serverName", audience))
        # chainctl returns the cached token until it nears expiry, so most runs
        # find the store already correct. Skipping those keeps a timer cheap and
        # leaves the file and its backup alone.
        if entries[key].get("accessToken") == token:
            continue
        status, why = probe(audience, token)
        if status == "rejected":
            rejected.append((name, why))
            continue
        if status == "unreachable":
            unreachable.append((name, why))
            continue
        entries[key]["accessToken"] = token
        entries[key]["expiresAt"] = expires_at_ms(token)
        written.append(name)

    for name in written:
        say(f"✔ {name} accepted the token, and the store now holds it.")
    for name, why in unreachable:
        say(f"◍ {name} did not answer, so its token is unwritten: {why}")
    for name, why in rejected:
        print(f"✘ ERROR! {name} rejected the token: {why}", file=sys.stderr)
    advice = "Authenticate it once through /mcp in Claude Code, then run mcp-tokens again."
    for audience in absent:
        say(f"⊚ {audience} has no entry yet. {advice}")

    if written:
        backup = save(credentials, store)
        say(f"✔ Wrote {len(written)} token(s). Previous store kept at {backup}")
        say("⊚ Run /mcp reconnect in Claude Code so it reads the new tokens.")

    # Only a rejection is a fault. A server that did not answer is retried by
    # the next run, so it must not make a timer unit fail.
    return 1 if rejected else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
