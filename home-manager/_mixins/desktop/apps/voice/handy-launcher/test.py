# The handy-managed package build runs this test through the launcher's check phase.
import json
import os
import selectors
import stat
import subprocess
import sys
import tempfile
import time
from pathlib import Path
from types import SimpleNamespace

launcher, managed_path, defaults_path = sys.argv[1:]
managed = json.loads(Path(managed_path).read_text())
defaults = json.loads(Path(defaults_path).read_text())["settings"]
assert not (managed.keys() & defaults.keys()), "settings ownership must be disjoint"


def event(process):
    assert process.stdout is not None
    buffer = getattr(process, "_event_buffer", b"")
    deadline = time.monotonic() + 10
    with selectors.DefaultSelector() as selector:
        selector.register(process.stdout, selectors.EVENT_READ)
        while b"\n" not in buffer:
            assert selector.select(max(0, deadline - time.monotonic())), "stub event timed out"
            chunk = os.read(process.stdout.fileno(), 4096)
            assert chunk, "stub exited without an event"
            buffer += chunk
    line, _, process._event_buffer = buffer.partition(b"\n")
    return json.loads(line)


read_fd, write_fd = os.pipe()
with os.fdopen(read_fd, "rb") as stdout, os.fdopen(write_fd, "wb", buffering=0) as writer:
    process = SimpleNamespace(stdout=stdout)
    writer.write(b'{"event":"first"}\n{"event":"second"}\n')
    assert event(process) == {"event": "first"}
    assert event(process) == {"event": "second"}
print("PASS: coalesced events remain readable while the writer stays open", flush=True)


with tempfile.TemporaryDirectory() as temporary:
    root = Path(temporary)
    env = os.environ | {
        "HOME": str(root / "home"),
        "XDG_DATA_HOME": str(root / "data with spaces"),
        "XDG_CONFIG_HOME": str(root / "config"),
        "HANDY_TEST_GATE": str(root / "gate"),
    }
    Path(env["HOME"]).mkdir()
    store = Path(env["XDG_DATA_HOME"]) / "com.pais.handy/settings_store.json"
    store.parent.mkdir(parents=True)
    os.mkfifo(env["HANDY_TEST_GATE"])

    def run(*args, **kwargs):
        return subprocess.run(
            [launcher, *args], env=env, capture_output=True, timeout=10, **kwargs
        )

    def start(*args):
        process = subprocess.Popen([launcher, *args], env=env, stdout=subprocess.PIPE)
        assert event(process) == {"event": "start", "args": list(args)}
        return process

    def ready(process):
        with open(env["HANDY_TEST_GATE"], "w") as gate:
            gate.write("x")
        assert event(process)["event"] == "ready"

    def stop(process):
        run("--test-exit", check=True)
        assert event(process) == {"event": "forward", "args": ["--test-exit"]}
        assert process.wait(timeout=10) == 0

    for invalid in (b"{broken", b"", b"{}", b"[]", b'{"settings":null}', b'{} {}'):
        store.write_bytes(invalid)
        assert run().returncode != 0
        assert store.read_bytes() == invalid
    print("PASS: malformed stores remain unchanged", flush=True)

    existing = {
        "settings": {
            **dict.fromkeys(managed, "local override"),
            "custom_words": ["local addition"],
            "selected_model": "interactive-model",
            "selected_microphone": "interactive microphone",
            "selected_output_device": "interactive output",
            "theme": "light",
            "bindings": {"transcribe": {"current_binding": "ctrl+space"}},
            "unrecognised": {"nested": [1, 2]},
        },
        "other_store_key": ["keep"],
    }
    store.write_text(json.dumps(existing))
    args = ["--start-hidden", "--debug", "argument with spaces", "quote'and\"unicode-λ"]
    process = start(*args)
    concurrent = subprocess.Popen(
        [launcher, "--toggle-transcription"], env=env, stdout=subprocess.PIPE
    )
    ready(process)
    assert concurrent.wait(timeout=10) == 0
    assert event(process) == {"event": "forward", "args": ["--toggle-transcription"]}
    merged = json.loads(store.read_text())
    assert {key: merged["settings"][key] for key in managed} == managed
    assert merged["other_store_key"] == existing["other_store_key"]
    for key, value in existing["settings"].items():
        if key not in managed and key != "bindings":
            assert merged["settings"][key] == value
    assert merged["settings"]["bindings"]["transcribe"]["current_binding"] == "ctrl+space"
    assert merged["settings"]["bindings"]["transcribe"]["default_binding"] == "ctrl+space"
    assert stat.S_IMODE(store.stat().st_mode) == 0o600
    print("PASS: managed precedence, word replacement, interactive data, concurrent start, arguments", flush=True)

    store.write_bytes(b"invalid but owned by the running app")
    before = store.stat()
    for args in (["--toggle-transcription"], ["--toggle-post-process"], ["--cancel"], [], ["space value", "λ"]):
        run(*args, check=True)
        assert event(process) == {"event": "forward", "args": args}
    assert store.read_bytes() == b"invalid but owned by the running app"
    assert store.stat().st_mtime_ns == before.st_mtime_ns
    print("PASS: existing-instance forwarding does not read or rewrite settings", flush=True)

    for args in (["--help"], ["--list-models"], ["--list-devices"], ["-f", "file with spaces.wav"], ["--transcribe-file=test.wav"]):
        result = run(*args, check=True)
        assert json.loads(result.stdout) == {"event": "start", "args": args}
        assert store.stat().st_mtime_ns == before.st_mtime_ns
    print("PASS: headless arguments bypass the settings merge", flush=True)
    stop(process)

    store.unlink()
    process = start()
    ready(process)
    fresh = json.loads(store.read_text())["settings"]
    assert fresh == defaults | managed
    stop(process)
    print("PASS: fresh store uses defaults then managed policy", flush=True)

    result = run("--test-start-failure")
    assert result.returncode == 7
    print("PASS: failed startup exits without waiting for a D-Bus owner", flush=True)

    before = store.read_bytes()
    unavailable = subprocess.run(
        [launcher],
        env=env | {"DBUS_SESSION_BUS_ADDRESS": "unix:path=/nonexistent-handy-test-bus"},
        capture_output=True,
        timeout=10,
    )
    assert unavailable.returncode != 0
    assert store.read_bytes() == before
    print("PASS: unavailable session bus prevents a settings rewrite", flush=True)

    target = root / "untouched.json"
    target.write_text('{"settings": {}}')
    store.unlink()
    store.symlink_to(target)
    assert run().returncode != 0
    assert target.read_text() == '{"settings": {}}'
    assert store.is_symlink()
    print("PASS: symlinked stores are rejected without changes", flush=True)
