import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path


def serve():
    for line in sys.stdin:
        request = json.loads(line)
        if "id" not in request:
            continue
        method = request["method"]
        if method == "initialize":
            result = {"protocolVersion": request["params"]["protocolVersion"], "capabilities": {"tools": {}},
                      "serverInfo": {"name": "synthetic", "version": "1"}}
        elif method == "tools/list":
            result = {"tools": [{"name": "echo", "description": "Return a synthetic URL.", "inputSchema": {
                "type": "object", "properties": {"url": {"type": "string", "format": "uri"}}, "required": ["url"]}}]}
        elif method == "tools/call":
            value = {"url": request["params"]["arguments"]["url"], "authPresent": os.environ.get("FAKE_TOKEN") == "synthetic-only"}
            result = {"content": [{"type": "text", "text": json.dumps(value)}], "structuredContent": value}
        else:
            result = {}
        print(json.dumps({"jsonrpc": "2.0", "id": request["id"], "result": result}), flush=True)


def check(binary):
    with tempfile.TemporaryDirectory() as temporary:
        root = Path(temporary).resolve()
        (root / "config").mkdir()
        (root / "config/mcporter.json").write_text("invalid ambient configuration")
        config = root / "dedicated.json"
        config.write_text(json.dumps({"imports": [], "mcpServers": {"synthetic": {
            "command": sys.executable, "args": [str(Path(__file__).resolve()), "--server"],
            "env": {"FAKE_TOKEN": "${MOLTIS_TEST_TOKEN}"}}}}))
        environment = {"HOME": str(root), "PATH": "/usr/bin:/bin", "MOLTIS_TEST_TOKEN": "synthetic-only"}
        for arguments in (
            ["list", "synthetic.echo", "--schema", "--json", "--no-oauth"],
            ["call", "synthetic.echo", "--args", '{"url":"https://example.invalid/test"}', "--output", "json", "--no-oauth"],
        ):
            result = subprocess.run([binary, "--config", str(config), *arguments], cwd=root, env=environment,
                                    capture_output=True, text=True, timeout=30, check=False)
            if result.returncode != 0:
                raise AssertionError("Synthetic MCPorter invocation failed")
            payload = json.loads(result.stdout)
            if arguments[0] == "list":
                assert '"format": "uri"' in json.dumps(payload)
            else:
                assert payload["url"] == "https://example.invalid/test"
                assert payload["authPresent"] is True
        print("MCPorter synthetic schema, arguments, environment and config isolation checks passed.")


if __name__ == "__main__":
    if sys.argv[1] == "--server":
        serve()
    else:
        check(sys.argv[1])
