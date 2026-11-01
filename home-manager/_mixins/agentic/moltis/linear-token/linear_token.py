import contextlib
import fcntl
import hashlib
import json
import math
import os
import signal
import stat
import sys
import time
import urllib.parse
import urllib.request
import uuid
from pathlib import Path

TOKEN_URL = "https://api.linear.app/oauth/token"
# Project/document changes and comment edits need write, not only create scopes.
SCOPE = "read,write"
RENEW_BEFORE = 86400
MIN_VALIDITY = 3600
MAX_RESPONSE = 65536


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise ValueError("Token endpoint redirect refused")


def check_private(fd, directory=False):
    info = os.fstat(fd)
    valid_type = stat.S_ISDIR(info.st_mode) if directory else stat.S_ISREG(info.st_mode)
    if (not valid_type or info.st_uid != os.getuid() or info.st_mode & 0o077
            or (not directory and info.st_nlink != 1)):
        raise ValueError("Unsafe credential storage")


def read_credential(path):
    # SOPS exposes credentials through symlinks to its current generation.
    with open(path, encoding="utf-8") as stream:
        check_private(stream.fileno())
        value = stream.read(16385).strip()
    if not value or len(value) > 16384 or "\x00" in value:
        raise ValueError("Invalid application credential")
    return value


def valid_token(value):
    return (isinstance(value, str) and 0 < len(value) <= 16384
            and all(33 <= ord(character) <= 126 for character in value))


def request_token(client_id, client_secret):
    body = urllib.parse.urlencode({
        "grant_type": "client_credentials", "client_id": client_id,
        "client_secret": client_secret, "scope": SCOPE,
    }).encode()
    request = urllib.request.Request(TOKEN_URL, data=body, headers={
        "Content-Type": "application/x-www-form-urlencoded",
        "Accept": "application/json",
    })
    with urllib.request.build_opener(NoRedirect).open(request, timeout=20) as response:
        raw = response.read(MAX_RESPONSE + 1)
    if len(raw) > MAX_RESPONSE:
        raise ValueError("Oversized token response")
    data = json.loads(raw)
    token = data.get("access_token")
    lifetime = data.get("expires_in")
    if (not valid_token(token) or type(lifetime) is not int or lifetime <= MIN_VALIDITY
            or data.get("token_type", "Bearer").lower() != "bearer"):
        raise ValueError("Invalid token response")
    return token, lifetime


def read_cache(directory):
    try:
        fd = os.open("token.json", os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK, dir_fd=directory)
    except FileNotFoundError:
        return {}
    with os.fdopen(fd) as stream:
        check_private(stream.fileno())
        raw = stream.read(MAX_RESPONSE + 1)
    if len(raw) > MAX_RESPONSE:
        raise ValueError("Oversized token cache")
    data = json.loads(raw)
    if (not isinstance(data, dict) or not valid_token(data.get("access_token"))
            or type(data.get("expires_at")) not in (float, int)
            or not math.isfinite(data["expires_at"])):
        raise ValueError("Invalid token cache")
    return data


def write_cache(directory, data):
    name = ".token-" + uuid.uuid4().hex
    fd = os.open(name, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600, dir_fd=directory)
    try:
        with os.fdopen(fd, "w") as stream:
            json.dump(data, stream)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(name, "token.json", src_dir_fd=directory, dst_dir_fd=directory)
    finally:
        with contextlib.suppress(FileNotFoundError):
            os.unlink(name, dir_fd=directory)


def access_token(client_id_path, client_secret_path, cache_path):
    client_id = read_credential(client_id_path)
    client_secret = read_credential(client_secret_path)
    identity = hashlib.sha256(json.dumps([client_id, client_secret, SCOPE]).encode()).hexdigest()
    Path(cache_path).mkdir(mode=0o700, parents=True, exist_ok=True)
    directory = os.open(cache_path, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    try:
        check_private(directory, directory=True)
        fd = os.open("lock", os.O_RDWR | os.O_CREAT | os.O_NOFOLLOW | os.O_NONBLOCK,
                     0o600, dir_fd=directory)
        with os.fdopen(fd, "r+") as lock:
            check_private(lock.fileno())
            fcntl.flock(lock, fcntl.LOCK_EX)
            cached = read_cache(directory)
            if cached.get("identity") != identity:
                cached = {}
            now = time.time()
            if cached.get("expires_at", 0) > now + RENEW_BEFORE:
                return cached["access_token"]
            try:
                token, lifetime = request_token(client_id, client_secret)
            except Exception:
                if cached.get("expires_at", 0) > time.time() + MIN_VALIDITY:
                    print("Moltis: Linear renewal failed. The current app token remains valid.", file=sys.stderr)
                    return cached["access_token"]
                raise
            write_cache(directory, {
                "identity": identity, "access_token": token, "expires_at": now + lifetime,
            })
            return token
    finally:
        os.close(directory)


def deadline(_signum, _frame):
    raise TimeoutError("Credential deadline exceeded")


def run_mcporter(arguments):
    config, binary, *args = arguments
    # A private wrapper must not load an interactive or project configuration.
    for index, arg in enumerate(args):
        if arg == "--config" and (index + 1 == len(args) or args[index + 1] != config):
            raise ValueError("Unexpected MCPorter configuration")
        if arg.startswith("--config=") and arg != "--config=" + config:
            raise ValueError("Unexpected MCPorter configuration")
    environment = os.environ.copy()
    environment.pop("LINEAR_API_KEY", None)
    environment["MCPORTER_CONFIG"] = config
    os.execve(binary, [binary, "--config", config, *args, "--no-oauth"], environment)


def run_linear_server(arguments):
    client_id, client_secret, cache, binary, url = arguments
    signal.signal(signal.SIGALRM, deadline)
    signal.alarm(30)
    try:
        token = access_token(client_id, client_secret, cache)
    finally:
        signal.alarm(0)
    environment = os.environ.copy()
    environment.pop("LINEAR_API_KEY", None)
    environment["API_ACCESS_TOKEN"] = token
    os.execve(binary, [binary, "--transport", "streamablehttp", url], environment)


def main(arguments):
    mode, *args = arguments
    if mode == "mcporter":
        run_mcporter(args)
    elif mode == "linear-server":
        run_linear_server(args)
    else:
        raise ValueError("Unknown wrapper mode")


if __name__ == "__main__":
    try:
        main(sys.argv[1:])
    except Exception:
        print("Moltis: MCP wrapper failed. No connection was started.", file=sys.stderr)
        sys.exit(1)
