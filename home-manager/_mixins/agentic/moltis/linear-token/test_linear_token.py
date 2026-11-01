# Run by checks.x86_64-linux.moltis-tools.
import concurrent.futures
import contextlib
import http.client
import http.server
import importlib
import io
import json
import os
import subprocess
import sys
import tempfile
import threading
import time
import unittest
import urllib.parse
import urllib.request
from pathlib import Path
from unittest.mock import MagicMock, patch

import linear_token as token


class TokenTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.client_id = self.root / "client-id"
        self.secret = self.root / "client-secret"
        for path, value in ((self.client_id, "synthetic-id"), (self.secret, "synthetic-secret")):
            path.write_text(value)
            path.chmod(0o400)
        self.cache = self.root / "cache"
        self.issuer = patch.object(token, "request_token", return_value=("synthetic-token", 2592000)).start()
        self.addCleanup(patch.stopall)

    def get(self):
        return token.access_token(self.client_id, self.secret, self.cache)

    def expire_in(self, seconds):
        path = self.cache / "token.json"
        data = json.loads(path.read_text())
        data["expires_at"] = time.time() + seconds
        path.write_text(json.dumps(data))

    def test_renewal_cache_and_private_modes(self):
        self.assertEqual(self.get(), "synthetic-token")
        self.assertEqual(self.get(), "synthetic-token")
        self.issuer.assert_called_once_with("synthetic-id", "synthetic-secret")
        self.assertEqual(self.cache.stat().st_mode & 0o777, 0o700)
        for name in ("lock", "token.json"):
            self.assertEqual((self.cache / name).stat().st_mode & 0o777, 0o600)
        self.expire_in(token.RENEW_BEFORE - 1)
        self.issuer.return_value = ("synthetic-replacement", 2592000)
        self.assertEqual(self.get(), "synthetic-replacement")
        self.assertEqual(self.issuer.call_count, 2)

    def test_parallel_calls_issue_one_token(self):
        with concurrent.futures.ThreadPoolExecutor(max_workers=8) as executor:
            values = list(executor.map(lambda _: self.get(), range(16)))
        self.assertEqual(set(values), {"synthetic-token"})
        self.assertEqual(self.issuer.call_count, 1)

    def test_identity_and_secret_changes_never_reuse_previous_token(self):
        for identity in ("zannah", "skrye", "traya"):
            self.client_id.chmod(0o600)
            self.client_id.write_text(identity)
            self.issuer.return_value = ("synthetic-" + identity, 2592000)
            self.assertEqual(self.get(), "synthetic-" + identity)
        self.secret.chmod(0o600)
        self.secret.write_text("rotated-synthetic-secret")
        self.issuer.side_effect = ValueError("sensitive upstream failure")
        with self.assertRaises(ValueError):
            self.get()
        self.assertEqual(self.issuer.call_count, 4)

    def test_failure_preserves_valid_cache_but_rejects_expired_token(self):
        self.get()
        self.expire_in(token.RENEW_BEFORE - 1)
        before = (self.cache / "token.json").read_bytes()
        self.issuer.side_effect = ValueError("sensitive upstream failure")
        output = io.StringIO()
        with contextlib.redirect_stderr(output):
            self.assertEqual(self.get(), "synthetic-token")
        self.assertNotIn("sensitive", output.getvalue())
        self.assertEqual((self.cache / "token.json").read_bytes(), before)
        self.expire_in(token.MIN_VALIDITY)
        with self.assertRaises(ValueError):
            self.get()

    def test_corrupt_and_unsafe_cache_fail_closed(self):
        self.get()
        path = self.cache / "token.json"
        original = path.read_text()
        for content in ("invalid", "[]", '{"access_token":"x","expires_at":NaN}'):
            path.write_text(content)
            with self.assertRaises(ValueError):
                self.get()
        path.write_text(original)
        path.chmod(0o644)
        with self.assertRaises(ValueError):
            self.get()
        path.unlink()
        path.symlink_to(self.secret)
        with self.assertRaises(OSError):
            self.get()
        self.assertEqual(self.secret.read_text(), "synthetic-secret")
        self.assertEqual(self.issuer.call_count, 1)

    def test_unsafe_directory_and_lock_are_rejected(self):
        self.cache.mkdir(mode=0o755)
        with self.assertRaises(ValueError):
            self.get()
        self.cache.chmod(0o700)
        (self.cache / "lock").symlink_to(self.secret)
        with self.assertRaises(OSError):
            self.get()
        self.issuer.assert_not_called()

    def test_atomic_write_failure_preserves_previous_token(self):
        self.get()
        self.expire_in(10)
        before = (self.cache / "token.json").read_bytes()
        with patch.object(token.os, "replace", side_effect=OSError("synthetic disk failure")), self.assertRaises(OSError):
            self.get()
        self.assertEqual((self.cache / "token.json").read_bytes(), before)
        self.assertEqual(sorted(p.name for p in self.cache.iterdir()), ["lock", "token.json"])

    def test_mcporter_never_receives_or_requests_linear_credentials(self):
        args = ["mcporter", "/dedicated.json", "/mcporter"]
        self.issuer.side_effect = ValueError("synthetic outage")
        with patch.dict(os.environ, {"LINEAR_API_KEY": "personal", "MCPORTER_CONFIG": "/personal.json"}):
            for command in (["list", "exa"], ["list"], ["--help"], ["call", "linear.echo"]):
                with self.subTest(command=command), patch.object(token.os, "execve") as execute:
                    token.main(args + command)
                    binary, argv, environment = execute.call_args.args
                    self.assertEqual(binary, "/mcporter")
                    self.assertEqual(argv, [binary, "--config", "/dedicated.json", *command, "--no-oauth"])
                    self.assertNotIn("LINEAR_API_KEY", environment)
                    self.assertEqual(environment["MCPORTER_CONFIG"], "/dedicated.json")
            self.assertEqual(os.environ["LINEAR_API_KEY"], "personal")
        self.issuer.assert_not_called()
        self.assertFalse(self.cache.exists())
        for flag in (["--config", "/personal.json"], ["--config=/personal.json"]):
            with patch.object(token.os, "execve") as execute:
                with self.assertRaises(ValueError):
                    token.main(args + flag)
                execute.assert_not_called()

    def test_only_linear_proxy_receives_token_and_renews(self):
        args = ["linear-server", str(self.client_id), str(self.secret), str(self.cache),
                "/proxy", "https://example.invalid/mcp"]
        with patch.dict(os.environ, {"LINEAR_API_KEY": "personal", "API_ACCESS_TOKEN": "personal"}):
            for value in ("synthetic-first", "synthetic-second"):
                self.issuer.return_value = (value, 2592000)
                with patch.object(token.os, "execve") as execute:
                    token.main(args)
                    binary, argv, environment = execute.call_args.args
                    self.assertEqual(argv, [binary, "--transport", "streamablehttp", args[-1]])
                    self.assertEqual(environment["API_ACCESS_TOKEN"], value)
                    self.assertNotIn("LINEAR_API_KEY", environment)
                self.expire_in(0)
            self.issuer.side_effect = ValueError("synthetic outage")
            with patch.object(token.os, "execve") as execute, self.assertRaises(ValueError):
                token.main(args)
            execute.assert_not_called()

    def test_missing_credentials_fail_without_sensitive_output(self):
        result = subprocess.run(
            [sys.executable, token.__file__, "linear-server", str(self.root / "missing"), str(self.secret),
             str(self.cache), "/must-not-run", "https://example.invalid/mcp"],
            capture_output=True, text=True, timeout=5, check=False,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(result.stdout, "")
        self.assertNotIn("synthetic", result.stderr)
        self.assertNotIn(str(self.root), result.stderr)
        self.assertNotIn("Traceback", result.stderr)


class EndpointTests(unittest.TestCase):
    def request(self, response):
        opener = MagicMock()
        opener.open.return_value.__enter__.return_value.read.return_value = json.dumps(response).encode()
        with patch.object(token.urllib.request, "build_opener", return_value=opener):
            result = token.request_token("synthetic-id&=", "synthetic-secret&=")
        request = opener.open.call_args.args[0]
        self.assertEqual(request.full_url, "https://api.linear.app/oauth/token")
        self.assertEqual(request.get_method(), "POST")
        self.assertEqual(urllib.parse.parse_qs(request.data.decode()), {
            "grant_type": ["client_credentials"], "client_id": ["synthetic-id&="],
            "client_secret": ["synthetic-secret&="], "scope": [token.SCOPE],
        })
        self.assertEqual(opener.open.call_args.kwargs["timeout"], 20)
        return result

    def test_form_encoding_and_response_validation(self):
        valid = {"access_token": "synthetic-token", "expires_in": 2592000, "token_type": "Bearer"}
        self.assertEqual(self.request(valid), ("synthetic-token", 2592000))
        for change in ({"access_token": ""}, {"access_token": "bad\ntoken"}, {"expires_in": True},
                       {"expires_in": -1}, {"expires_in": 3600}, {"token_type": "Basic"}):
            with self.subTest(change=change), self.assertRaises(ValueError):
                self.request(valid | change)

    def test_redirects_never_forward_credentials(self):
        with self.assertRaises(ValueError):
            token.NoRedirect().redirect_request(
                urllib.request.Request(token.TOKEN_URL), io.BytesIO(), 307, "",
                http.client.HTTPMessage(), "https://example.invalid",
            )


def transport_check(binary, proxy):
    fixture_directory = str(Path(__file__).resolve().parent.parent / "mcp-cli-migration")
    sys.path.insert(0, fixture_directory)
    fixture = importlib.import_module("test_mcporter")
    assert fixture.__file__ is not None
    fixture_directory = str(Path(fixture.__file__).parent)
    HttpServer, check_server = fixture.HttpServer, fixture.check_server

    with tempfile.TemporaryDirectory() as temporary:
        root = Path(temporary)
        client_id, secret, cache = root / "id", root / "secret", root / "cache"
        for path in (client_id, secret):
            path.write_text("synthetic-" + path.name)
            path.chmod(0o400)
        config = root / "dedicated.json"
        wrapper = root / "mcporter"
        prologue = (f"#!{sys.executable}\nimport sys\n"
                    f"sys.path.insert(0, {str(Path(token.__file__).parent)!r})\nimport linear_token\n")
        wrapper.write_text(prologue + f"linear_token.main({['mcporter', str(config), binary]!r} + sys.argv[1:])\n")
        wrapper.chmod(0o700)
        issuer = root / "issuer.json"
        issuer.write_text('null')
        requests = root / "issuer-requests"
        server = root / "linear-server"
        unrelated = root / "unrelated.py"
        unrelated.write_text(
            "import os, sys\n"
            "assert 'LINEAR_API_KEY' not in os.environ\n"
            "assert 'API_ACCESS_TOKEN' not in os.environ\n"
            f"sys.path.insert(0, {fixture_directory!r})\n"
            "from test_mcporter import serve\nserve()\n")
        environment = {"HOME": temporary, "PATH": os.defpath, "LINEAR_API_KEY": "personal-must-not-be-used"}
        with http.server.ThreadingHTTPServer(("127.0.0.1", 0), HttpServer) as httpd:
            server_args = ['linear-server', str(client_id), str(secret), str(cache), proxy,
                           f"http://127.0.0.1:{httpd.server_port}/linear"]
            server.write_text(prologue + "import json\nfrom pathlib import Path\n"
                              "def issue(*args):\n"
                              f"    with open({str(requests)!r}, 'a') as stream: stream.write('request\\n')\n"
                              f"    value = json.loads(Path({str(issuer)!r}).read_text())\n"
                              "    if value is None: raise ValueError('synthetic outage')\n"
                              "    return value, 2592000\n"
                              "linear_token.request_token = issue\n"
                              f"linear_token.main({server_args!r})\n")
            server.chmod(0o700)
            config.write_text(json.dumps({"imports": [], "mcpServers": {
                "linear": {"command": str(server), "lifecycle": "ephemeral"},
                **{name: {"command": sys.executable, "args": [str(unrelated)],
                          "env": {"FAKE_TOKEN": "synthetic-only"}}
                   for name in ("exa", "cloudflare-api")},
            }}))
            thread = threading.Thread(target=httpd.serve_forever)
            thread.start()
            try:
                def invoke(arguments):
                    return fixture.invoke(str(wrapper), config, root, environment, arguments)

                for name in ("exa", "cloudflare-api"):
                    check_server(str(wrapper), config, root, environment, name)
                for arguments in (["--help"], ["config", "list"], ["exa", "--json"],
                                  ["--log-level", "error", "describe", "exa.echo", "--json"],
                                  ["call", "--server", "exa", "--tool", "echo", "url:https://example.invalid"],
                                  ['exa.echo(url: "https://example.invalid/linear")']):
                    result = invoke(arguments)
                    assert result.returncode == 0, (arguments, result.stderr)
                assert not requests.exists(), "Unrelated commands contacted the Linear issuer"
                result = invoke(["list", "linear", "--json"])
                assert 'error' in (result.stdout + result.stderr).lower()
                assert requests.exists(), "Linear did not attempt app authentication"
                result = invoke(["list", "--json"])
                payload = json.loads(result.stdout)
                statuses = {entry['name']: entry['status'] for entry in payload['servers']}
                assert statuses['exa'] == statuses['cloudflare-api'] == 'ok', payload
                assert statuses['linear'] != 'ok', payload
                for value in ("synthetic-first", "synthetic-second"):
                    HttpServer.credentials["/linear"] = value
                    path = cache / "token.json"
                    if path.exists():
                        data = json.loads(path.read_text())
                        data["expires_at"] = 0
                        path.write_text(json.dumps(data))
                    issuer.write_text(json.dumps(value))
                    check_server(str(wrapper), config, root, environment, "linear")
                    for arguments in (["linear", "--json"],
                                      ["call", "--server", "linear", "--tool", "echo",
                                       "url:https://example.invalid/test"],
                                      ['linear.echo(url: "https://example.invalid/test")'],
                                      ["list", "--json"]):
                        result = invoke(arguments)
                        assert result.returncode == 0, (arguments, result.stderr)
                        assert '"isError": true' not in result.stdout
                    assert json.loads((cache / "token.json").read_text())["access_token"] == value
            finally:
                httpd.shutdown()
                thread.join()
    print("Moltis server isolation, issuer outage, CLI routing and token renewal checks passed.")


if __name__ == "__main__":
    if len(sys.argv) == 3:
        transport_check(sys.argv[1], sys.argv[2])
    else:
        unittest.main()
