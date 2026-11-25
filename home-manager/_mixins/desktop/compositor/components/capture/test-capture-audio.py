# The fuzzel-capture build runs these mocked tests through default.nix postCheck.
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from typing import Any

SCRIPT, BASH = sys.argv[1:3]
sys.argv[1:] = []
SOURCE = Path(SCRIPT).read_text().split('case "${1:-menu}" in\n')[0]
FAKE = r"""
import json
import os
import sys
from pathlib import Path

root = Path(os.environ["FAKE_ROOT"])
config = json.loads((root / "config").read_text())
name = Path(sys.argv[0]).name
args = sys.argv[1:]
with (root / "calls").open("a") as stream:
    stream.write(json.dumps([name, *args]) + "\n")
if name == "pactl":
    if args == ["--format=json", "list", "sources"]:
        print(config["sources"])
        sys.exit(config.get("list_status", 0))
    if args == ["get-default-source"]:
        print((root / "default").read_text())
        sys.exit(config.get("default_status", 0))
    if args == ["get-default-sink"]:
        print("speakers")
    elif args == ["list", "short", "sources"]:
        print("1\tspeakers.monitor\tdriver\tspec\tRUNNING")
    else:
        sys.exit(90)
elif name == "swayosd-client":
    if "late_default" in config:
        (root / "default").write_text(config["late_default"])
elif name == "recorder":
    (root / "recorder-args").write_text(json.dumps(args))
    status = config.get("recorder_status", 0)
    if status:
        print("Pulse source disappeared", file=sys.stderr, flush=True)
    else:
        (root / "recorder-started").touch()
    (root / "ready").write_text("ready\n")
    sys.exit(status)
elif name == "fyi":
    sys.exit(config.get("notify_status", 0))
elif name == "wlr-randr":
    if args == ["--json"]:
        print(json.dumps(config.get("outputs", [])))
        sys.exit(0)
    sys.exit(92)
else:
    sys.exit(91)
"""
HARNESS = r"""
sleep_until_ms() { :; }
sleep() { :; }
refresh_waybar() { :; }
is_expected_recorder() { [[ -f "$FAKE_ROOT/recorder-started" ]]; }
is_same_process_running() { return 1; }
get_process_start_time() {
  if [[ "$1" != "$$" ]]; then
    IFS= read -r _ < "$FAKE_ROOT/ready"
    [[ -f "$FAKE_ROOT/recorder-started" ]] || return 1
  fi
  printf '123\n'
}
start_recording "${CAPTURE_MODE:-output}" "${CAPTURE_TARGET:-test-output}" test-output
"""


def source(name, monitor: object = "", state="RUNNING"):
    return {"name": name, "monitor_source": monitor, "state": state}


class CaptureAudioTests(unittest.TestCase):
    def launch(self, sources, default="mic", choice="microphone", **options):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            binary = root / "bin"
            binary.mkdir()
            for name in ("pactl", "swayosd-client", "recorder", "fyi", "wlr-randr"):
                command = binary / name
                command.write_text(f"#!{sys.executable}\n" + FAKE)
                command.chmod(0o755)
            config = {
                "sources": sources if isinstance(sources, str) else json.dumps(sources),
                **options,
            }
            os.mkfifo(root / "ready")
            (root / "config").write_text(json.dumps(config))
            (root / "default").write_text(default)
            state = root / "fuzzel-capture"
            state.mkdir()
            (state / "audio").write_text(choice)
            script = root / "capture.sh"
            script.write_text(
                "set -euo pipefail\n"
                + SOURCE.replace("@wlScreenrec@", str(binary / "recorder"))
                + HARNESS
            )
            env = {
                "PATH": str(binary) + os.pathsep + os.environ["PATH"],
                "HOME": str(root),
                "XDG_RUNTIME_DIR": str(root),
                "XDG_STATE_HOME": str(root),
                "XDG_VIDEOS_DIR": str(root / "videos"),
                "FAKE_ROOT": str(root),
            }
            if "capture_mode" in options:
                env["CAPTURE_MODE"] = options["capture_mode"]
            if "capture_target" in options:
                env["CAPTURE_TARGET"] = options["capture_target"]
            result = subprocess.run(
                [BASH, str(script)],
                env=env,
                capture_output=True,
                text=True,
                timeout=10,
                check=False,
            )
            calls = [
                json.loads(line) for line in (root / "calls").read_text().splitlines()
            ]
            args_file = root / "recorder-args"
            args = json.loads(args_file.read_text()) if args_file.exists() else []
            log = root / "fuzzel-capture.log"
            result.stderr += log.read_text() if log.exists() else ""
            self.assertFalse((root / "fuzzel-capture-countdown.state").exists())
            self.assertEqual(
                (root / "fuzzel-capture-recording.state").exists(),
                result.returncode == 0,
            )
            return result, calls, args

    def assert_started(self, sources, default="mic", **options):
        result, calls, args = self.launch(sources, default, **options)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(args)
        self.assertEqual(
            args[args.index("--audio-device") + 1], options.get("late_default", default)
        )
        self.assertIn("--audio", args)
        self.assertEqual(args[:2], ["--output", "test-output"])
        self.assertTrue(args[args.index("--filename") + 1].endswith(".mp4"))
        audio_calls = [i for i, call in enumerate(calls) if call[0] == "pactl"]
        countdown_calls = [
            i for i, call in enumerate(calls) if call[0] == "swayosd-client"
        ]
        self.assertEqual(len(countdown_calls), 15)
        self.assertGreater(min(audio_calls), max(countdown_calls))

    def assert_rejected(self, sources, default="mic", **options: Any):
        result, calls, args = self.launch(sources, default, **options)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(args, [])
        self.assertTrue(
            any(
                call[0] == "fyi" and "Screen Recording Failed" in call for call in calls
            )
        )

    def test_physical_default(self):
        self.assert_started([source("other"), source("mic")])

    def test_virtual_default_and_monitor_in_name(self):
        for name in ("virtual-input", "virtual.monitor.input"):
            with self.subTest(name=name):
                self.assert_started([source(name)], name)

    def test_suspended_source(self):
        self.assert_started([source("mic", state="SUSPENDED")])

    def test_real_monitor_default(self):
        for name in ("speakers.monitor", "innocent-name"):
            with self.subTest(name=name):
                self.assert_rejected(
                    [source(name, monitor="speakers"), source("mic")], name
                )

    def test_absent_default_and_missing_bluetooth_capture(self):
        for name in ("", "missing", "bluez_input.disconnected"):
            with self.subTest(name=name):
                self.assert_rejected([source("mic")], name)
        self.assert_rejected([])

    def test_default_changes_during_countdown(self):
        self.assert_started([source("old"), source("new")], "old", late_default="new")
        self.assert_rejected([source("old")], "old", late_default="gone")

    def test_pactl_failure_even_with_valid_output(self):
        for field in ("list_status", "default_status"):
            with self.subTest(field=field):
                options: dict[str, Any] = {field: 1}
                self.assert_rejected([source("mic")], **options)

    def test_malformed_or_unknown_metadata(self):
        for data in (
            "not json",
            "",
            "null",
            "{}",
            "[] []",
            [None],
            [{"name": "mic"}],
            [source("mic", monitor=None)],
            [source("mic", monitor=4294967295)],
            [source("mic", monitor=False)],
            [source("mic"), source("mic")],
            [{"name": "mic", "monitor_of_sink": 4294967295}],
        ):
            with self.subTest(data=data):
                self.assert_rejected(data)

    def test_control_characters_in_source_names_are_rejected(self):
        for name in ("mic\n", "mic\tinput", "mic\x00input", "mic\x7finput"):
            with self.subTest(name=name):
                self.assert_rejected([source(name)], name)

    def test_source_disappears_at_startup(self):
        result, calls, args = self.launch([source("mic")], recorder_status=42)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(args[args.index("--audio-device") + 1], "mic")
        self.assertTrue(
            any(
                "Pulse source disappeared" in call for call in calls if call[0] == "fyi"
            )
        )

    def test_notification_failure_still_stops(self):
        self.assert_rejected([], notify_status=3)

    def test_none_does_not_query_pulse(self):
        result, calls, args = self.launch("invalid", choice="none")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(any(call[0] == "pactl" for call in calls))
        self.assertNotIn("--audio", args)
        self.assertNotIn("--audio-device", args)

    def test_desktop_uses_sink_monitor(self):
        result, calls, args = self.launch([], choice="desktop")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(args[args.index("--audio-device") + 1], "speakers.monitor")
        self.assertEqual(
            [call[1:] for call in calls if call[0] == "pactl"],
            [["get-default-sink"], ["list", "short", "sources"]],
        )

    def test_unusual_name_is_one_exact_argument(self):
        name = "virtual.monitor-'quoted'\"\\$input; *"
        self.assert_started([source(name)], name)

    def test_encoding_defaults_and_audio_bitrate(self):
        result, _, args = self.launch([source("mic")])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(args[args.index("--codec") + 1], "avc")
        self.assertEqual(args[args.index("--encode-pixfmt") + 1], "nv12")
        self.assertEqual(
            args[args.index("--ffmpeg-encoder-options") + 1], "rc_mode=CQP,qp=26"
        )
        self.assertEqual(
            args[args.index("--ffmpeg-muxer-options") + 1], "movflags=+faststart"
        )
        self.assertEqual(args[args.index("--audio-bitrate") + 1], "16 kB")

        result, _, args = self.launch("invalid", choice="none")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn("--audio-bitrate", args)

    def test_rotated_output_uses_software_crf_and_swapped_downscale(self):
        outputs = [
            {
                "name": "test-output",
                "transform": "90",
                "scale": 1.0,
                "modes": [{"width": 2560, "height": 1440, "current": True}],
            }
        ]
        result, _, args = self.launch([], choice="none", outputs=outputs)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("--no-hw", args)
        self.assertEqual(args[args.index("--encode-pixfmt") + 1], "yuv420p")
        self.assertEqual(
            args[args.index("--ffmpeg-encoder-options") + 1], "crf=26,preset=veryfast"
        )
        self.assertEqual(args[args.index("--encode-resolution") + 1], "1080x1920")

    def test_proportional_resolution_cap_for_outputs_and_hidpi_regions(self):
        cases = [
            ("output", "test-output", 3440, 1440, 1.0, "2226x932"),
            ("output", "test-output", 2560, 2880, 1.0, "1358x1528"),
            ("output", "test-output", 2560, 1440, 1.0, "1920x1080"),
            ("output", "test-output", 1920, 1200, 1.0, None),
            ("geometry", "0,0 1280x800", 2560, 1600, 2.0, "1822x1138"),
            ("geometry", "100,100 800x600", 3440, 1440, 1.0, None),
        ]
        for mode, target, width, height, scale, expected in cases:
            with self.subTest(mode=mode, target=target, width=width, height=height, scale=scale):
                outputs = [
                    {
                        "name": "test-output",
                        "transform": "normal",
                        "scale": scale,
                        "modes": [{"width": width, "height": height, "current": True}],
                    }
                ]
                result, _, args = self.launch(
                    [],
                    choice="none",
                    outputs=outputs,
                    capture_mode=mode,
                    capture_target=target,
                )
                self.assertEqual(result.returncode, 0, result.stderr)
                if expected is None:
                    self.assertNotIn("--encode-resolution", args)
                else:
                    self.assertEqual(args[args.index("--encode-resolution") + 1], expected)

    def run_snippet(self, snippet, root):
        script = root / "snippet.sh"
        script.write_text(
            "set -euo pipefail\n"
            + SOURCE.replace("@wlScreenrec@", "/bin/true")
            + "refresh_waybar() { :; }\n"
            + snippet
        )
        return subprocess.run(
            [BASH, str(script)],
            env={
                "PATH": os.environ["PATH"],
                "HOME": str(root),
                "XDG_RUNTIME_DIR": str(root),
                "XDG_STATE_HOME": str(root),
                "XDG_VIDEOS_DIR": str(root / "videos"),
            },
            capture_output=True,
            text=True,
            timeout=10,
            check=False,
        )

    def test_recording_status_json_and_timer_toggle(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            # Idle state prints nothing so Waybar hides the module.
            idle = self.run_snippet("print_recording_status\n", root)
            self.assertEqual(idle.returncode, 0, idle.stderr)
            self.assertEqual(idle.stdout, "")

            # Active recording with default timer on shows leading space + mm:ss and tooltip.
            active_harness = (
                "is_expected_recorder() { return 0; }\n"
                "date() { printf '165\\n'; }\n"
                "printf '42 123 100\\n/tmp/clip.mp4\\n' > \"$recording_state_file\"\n"
                "print_recording_status\n"
            )
            on_result = self.run_snippet(active_harness, root)
            self.assertEqual(on_result.returncode, 0, on_result.stderr)
            payload_on = json.loads(on_result.stdout)
            self.assertEqual(payload_on["text"], " 01:05")
            self.assertEqual(
                payload_on["tooltip"],
                "󰑊  Screen recording (01:05). Click to stop.",
            )

            # Toggling timer off leaves text empty for a centred red dot while
            # keeping elapsed time in the hover tooltip.
            toggle_off = self.run_snippet("toggle_timer_choice\n", root)
            self.assertEqual(toggle_off.returncode, 0, toggle_off.stderr)
            self.assertEqual((root / "fuzzel-capture" / "timer").read_text().strip(), "off")

            off_result = self.run_snippet(active_harness, root)
            self.assertEqual(off_result.returncode, 0, off_result.stderr)
            payload_off = json.loads(off_result.stdout)
            self.assertEqual(payload_off["text"], "")
            self.assertEqual(
                payload_off["tooltip"],
                "󰑊  Screen recording (01:05). Click to stop.",
            )

            # Toggling again restores timer on.
            toggle_on = self.run_snippet("toggle_timer_choice\n", root)
            self.assertEqual(toggle_on.returncode, 0, toggle_on.stderr)
            self.assertEqual((root / "fuzzel-capture" / "timer").read_text().strip(), "on")


if __name__ == "__main__":
    unittest.main()
