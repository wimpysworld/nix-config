import http.server
import json
import os
import subprocess
import sys
import tempfile
import threading
from pathlib import Path


def response(request, auth_present):
    method = request["method"]
    if method == "initialize":
        result = {"protocolVersion": request["params"]["protocolVersion"], "capabilities": {"tools": {}},
                  "serverInfo": {"name": "synthetic", "version": "1"}}
    elif method == "tools/list":
        result = {"tools": [{"name": "echo", "description": "Return a synthetic URL.", "inputSchema": {
            "type": "object", "properties": {"url": {"type": "string", "format": "uri"}}, "required": ["url"]}}]}
    elif method == "tools/call":
        value = {"url": request["params"]["arguments"]["url"], "authPresent": auth_present}
        result = {"content": [{"type": "text", "text": json.dumps(value)}], "structuredContent": value}
    else:
        result = {}
    return {"jsonrpc": "2.0", "id": request["id"], "result": result}


def serve():
    for line in sys.stdin:
        request = json.loads(line)
        if "id" in request:
            print(json.dumps(response(request, os.environ.get("FAKE_TOKEN") == "synthetic-only")), flush=True)


class HttpServer(http.server.BaseHTTPRequestHandler):
    credentials = {"/linear": "synthetic-linear", "/context7": "synthetic-context7"}

    def log_message(self, format, *args):
        pass

    def do_POST(self):
        expected = self.credentials.get(self.path)
        if expected is None or self.headers.get("Authorization") != f"Bearer {expected}":
            self.send_error(401, "Synthetic credential rejected")
            return
        request = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
        if "id" not in request:
            self.send_response(202)
            self.end_headers()
            return
        body = json.dumps(response(request, True)).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


def invoke(binary, config, root, environment, arguments):
    return subprocess.run([binary, "--config", str(config), *arguments], cwd=root, env=environment,
                          capture_output=True, text=True, timeout=30, check=False)


def check_server(binary, config, root, environment, server):
    for arguments in (
        ["list", f"{server}.echo", "--schema", "--json", "--no-oauth"],
        ["call", f"{server}.echo", "--args", '{"url":"https://example.invalid/test"}', "--output", "json", "--no-oauth"],
    ):
        result = invoke(binary, config, root, environment, arguments)
        if result.returncode != 0:
            raise AssertionError("Synthetic MCPorter invocation failed")
        payload = json.loads(result.stdout)
        assert not payload.get("error") and not payload.get("isError"), "MCPorter returned an error with exit status zero"
        if arguments[0] == "list":
            assert '"format": "uri"' in json.dumps(payload)
        else:
            assert payload["url"] == "https://example.invalid/test"
            assert payload["authPresent"] is True


def check(binary):
    with tempfile.TemporaryDirectory() as temporary:
        root = Path(temporary).resolve()
        (root / "config").mkdir()
        (root / "config/mcporter.json").write_text("invalid ambient configuration")
        config = root / "dedicated.json"
        servers = {"synthetic": {
            "command": sys.executable, "args": [str(Path(__file__).resolve()), "--server"],
            "env": {"FAKE_TOKEN": "${MOLTIS_TEST_TOKEN}"}}}
        environment = {"HOME": str(root), "PATH": "/usr/bin:/bin", "MOLTIS_TEST_TOKEN": "synthetic-only"}
        with http.server.ThreadingHTTPServer(("127.0.0.1", 0), HttpServer) as httpd:
            for name, variable in (("linear", "LINEAR_API_KEY"), ("context7", "CONTEXT7_API_KEY")):
                servers[name] = {
                    "url": f"http://127.0.0.1:{httpd.server_port}/{name}",
                    "headers": {"Authorization": f"Bearer ${{{variable}}}"},
                }
                environment[variable] = HttpServer.credentials[f"/{name}"]
            config.write_text(json.dumps({"imports": [], "mcpServers": servers}))
            thread = threading.Thread(target=httpd.serve_forever)
            thread.start()
            try:
                for server in servers:
                    check_server(binary, config, root, environment, server)
                for variable in ("LINEAR_API_KEY", "CONTEXT7_API_KEY"):
                    missing = environment.copy()
                    del missing[variable]
                    server = "linear" if variable == "LINEAR_API_KEY" else "context7"
                    result = invoke(binary, config, root, missing,
                                    ["list", server, "--json", "--no-oauth"])
                    assert variable in result.stdout + result.stderr
                    assert "error" in (result.stdout + result.stderr).lower()
            finally:
                httpd.shutdown()
                thread.join()
        print("MCPorter synthetic schema, arguments, environment, HTTP headers and config isolation checks passed.")


if __name__ == "__main__":
    if sys.argv[1] == "--server":
        serve()
    else:
        check(sys.argv[1])
