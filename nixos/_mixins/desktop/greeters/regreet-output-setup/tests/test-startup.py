#!/usr/bin/env python3
"""Test startup with fixture outputs, without a Wayland connection."""

import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

import tomllib

SCRIPT = Path(__file__).resolve().parents[1] / "regreet-output-setup.sh"
FAKE = r"""
import json
import os
from pathlib import Path
import sys
import time

root = Path(os.environ["FIXTURE_DIR"])
behaviour = os.environ.get("BEHAVIOUR", "")
args = sys.argv[1:]
with (root / "calls").open("a") as stream:
    stream.write(json.dumps(args) + "\n")
if args == ["--json"]:
    applied = (root / "applied").exists()
    if behaviour == "query-failure" or (applied and behaviour == "verify-failure"):
        sys.exit(1)
    if behaviour == "query-timeout":
        time.sleep(30)
    if behaviour == "invalid-json":
        print("not JSON")
    else:
        print((root / ("after.json" if applied else "before.json")).read_text())
    sys.exit(0)
if behaviour == "apply-failure":
    sys.exit(1)
outputs = json.loads((root / "before.json").read_text())
by_name = {output["name"]: output for output in outputs}
index = 0
while index < len(args):
    arg = args[index]
    if arg == "--output":
        index += 1
        output = by_name[args[index]]
    elif arg in ("--on", "--off"):
        output["enabled"] = arg == "--on"
    elif arg == "--mode":
        index += 1
        def mode_name(mode):
            refresh = round(mode["refresh"] * 1000) / 1000
            suffix = f"@{refresh:g}Hz" if refresh else ""
            return f'{mode["width"]}x{mode["height"]}{suffix}'
        assert args[index] in [mode_name(mode) for mode in output["modes"]]
    elif arg == "--pos":
        index += 1
        assert args[index] == "0,0"
        output["position"] = {"x": 0, "y": 0}
    elif arg == "--scale":
        index += 1
        assert args[index] == "1"
        output["scale"] = 1
    else:
        raise AssertionError(f"Unexpected argument: {arg}")
    index += 1
if behaviour == "verify-multiple":
    for output in outputs:
        output["enabled"] = True
elif behaviour == "verify-wrong":
    for output in outputs:
        output["enabled"] = not output["enabled"]
elif behaviour == "verify-empty":
    outputs = []
elif behaviour == "verify-position":
    for output in outputs:
        output["position"] = {"x": 50, "y": 0}
(root / "after.json").write_text(json.dumps(outputs))
(root / "applied").touch()
"""


def mode(width=1920, height=1080, refresh: float = 60, **flags):
    return dict(width=width, height=height, refresh=refresh, **flags)


def output(name, enabled=False, modes=None):
    return {
        "name": name,
        "enabled": enabled,
        "modes": modes if modes is not None else [mode(preferred=True)],
    }


class StartupTests(unittest.TestCase):
    def run_startup(
        self, outputs, behaviour="", success=True, primary=("eDP-1", 1920, 1080, 60)
    ):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            fake = root / "wlr-randr"
            fake.write_text(f"#!{sys.executable}\n" + FAKE)
            fake.chmod(0o755)
            session = root / "regreet"
            session.write_text(
                f"#!{sys.executable}\n"
                "import os\nfrom pathlib import Path\n"
                'Path(os.environ["FIXTURE_DIR"], "started").touch()\n'
            )
            session.chmod(0o755)
            (root / "before.json").write_text(json.dumps(outputs))
            env = dict(os.environ, FIXTURE_DIR=temporary, BEHAVIOUR=behaviour)
            env["PATH"] = temporary + os.pathsep + os.environ["PATH"]
            env.pop("WAYLAND_DISPLAY", None)
            env.pop("WAYLAND_SOCKET", None)
            result = subprocess.run(
                ["bash", str(SCRIPT), *map(str, primary), str(session)],
                env=env,
                capture_output=True,
                text=True,
                timeout=12,
                check=False,
            )
            self.assertEqual(result.returncode == 0, success, result.stderr)
            self.assertEqual((root / "started").exists(), success, result.stderr)
            calls = [
                json.loads(line) for line in (root / "calls").read_text().splitlines()
            ]
            self.assertLessEqual(len(calls), 3)
            return calls, result.stderr

    def test_primary_present_and_unregistered_disabled(self):
        calls, _ = self.run_startup(
            [output("DP-3", True), output("HDMI-A-9", True), output("eDP-1")]
        )
        self.assertEqual(
            calls,
            [
                ["--json"],
                [
                    "--output",
                    "eDP-1",
                    "--on",
                    "--mode",
                    "1920x1080@60Hz",
                    "--pos",
                    "0,0",
                    "--scale",
                    "1",
                    "--output",
                    "DP-3",
                    "--off",
                    "--output",
                    "HDMI-A-9",
                    "--off",
                ],
                ["--json"],
            ],
        )

    def test_reframe_registry_primary_and_fallback(self):
        registry = SCRIPT.parents[5] / "lib" / "registry-systems.toml"
        hosts = tomllib.loads(registry.read_text())
        hosts = {
            name: host
            for name, host in hosts.items()
            if "reframe" in host.get("tags", []) and len(host.get("displays", [])) > 1
        }
        self.assertTrue(hosts, "Expected a multi-monitor ReFrame fixture")
        for name, host in hosts.items():
            displays = host["displays"]
            primary = next(display for display in displays if display.get("primary"))
            settings = (
                primary["output"],
                primary["width"],
                primary["height"],
                primary.get("refresh", 60),
            )
            outputs = [
                output(
                    display["output"],
                    True,
                    [
                        mode(
                            display["width"],
                            display["height"],
                            display.get("refresh", 60),
                        )
                    ],
                )
                for display in reversed(displays)
            ]
            for connected in (
                outputs,
                [o for o in outputs if o["name"] != settings[0]],
            ):
                with self.subTest(host=name, connected=[o["name"] for o in connected]):
                    calls, _ = self.run_startup(connected, primary=settings)
                    selected = (
                        settings[0]
                        if len(connected) == len(outputs)
                        else min(o["name"] for o in connected)
                    )
                    self.assertEqual(calls[0], ["--json"])
                    self.assertEqual(calls[-1], ["--json"])
                    self.assertEqual(calls[1][1], selected)
                    self.assertEqual(calls[1][5:9], ["--pos", "0,0", "--scale", "1"])
                    self.assertEqual(
                        calls[1][9:],
                        [
                            arg
                            for other in sorted(o["name"] for o in connected)
                            if other != selected
                            for arg in ("--output", other, "--off")
                        ],
                    )

    def test_enabled_fallback_sorted(self):
        calls, log = self.run_startup(
            [output("DP-9", True), output("DP-1"), output("DP-3", True)]
        )
        self.assertEqual(calls[1][1], "DP-3")
        self.assertIn("Primary eDP-1 is absent. Using DP-3.", log)

    def test_first_available_fallback_sorted(self):
        calls, _ = self.run_startup([output("DP-9"), output("DP-3")])
        self.assertEqual(calls[1][1], "DP-3")

    def test_supported_configured_mode_over_current(self):
        calls, _ = self.run_startup(
            [
                output(
                    "eDP-1",
                    True,
                    [
                        mode(1280, 720, current=True),
                        mode(),
                    ],
                )
            ]
        )
        self.assertEqual(calls[1][4], "1920x1080@60Hz")

    def test_unsupported_configured_mode(self):
        cases = [
            (
                [mode(1280, 720, current=True), mode(2560, 1440, preferred=True)],
                "1280x720@60Hz",
            ),
            ([mode(1280, 720), mode(2560, 1440, preferred=True)], "2560x1440@60Hz"),
            ([mode(2560, 1440), mode(1280, 720)], "1280x720@60Hz"),
            ([mode(refresh=59.940002)], "1920x1080@59.94Hz"),
            ([mode(refresh=0)], "1920x1080"),
        ]
        for modes, expected in cases:
            with self.subTest(expected=expected):
                calls, _ = self.run_startup([output("eDP-1", modes=modes)])
                self.assertEqual(calls[1][4], expected)

    def test_no_outputs(self):
        calls, log = self.run_startup([], success=False)
        self.assertEqual(calls, [["--json"]])
        self.assertIn("No connected outputs.", log)

    def test_no_modes(self):
        calls, _ = self.run_startup([output("eDP-1", modes=[])], success=False)
        self.assertEqual(calls, [["--json"]])

    def test_failures_never_start_regreet(self):
        for behaviour in [
            "query-failure",
            "invalid-json",
            "apply-failure",
            "verify-failure",
            "verify-multiple",
            "verify-wrong",
            "verify-empty",
            "verify-position",
        ]:
            with self.subTest(behaviour=behaviour):
                calls, _ = self.run_startup(
                    [output("eDP-1"), output("DP-3", True)],
                    behaviour,
                    success=False,
                )
                expected_calls = 3
                if behaviour in ("query-failure", "invalid-json"):
                    expected_calls = 1
                elif behaviour == "apply-failure":
                    expected_calls = 2
                self.assertEqual(len(calls), expected_calls)

    def test_query_timeout(self):
        calls, _ = self.run_startup([output("eDP-1")], "query-timeout", success=False)
        self.assertEqual(calls, [["--json"]])

    def test_invalid_output_data(self):
        for outputs in [{}, [output("eDP-1"), output("eDP-1")], [output("bad\nname")]]:
            with self.subTest(outputs=outputs):
                self.run_startup(outputs, success=False)


if __name__ == "__main__":
    for tool in ["bash", "jq", "timeout"]:
        if shutil.which(tool) is None:
            raise SystemExit(f"Missing test dependency: {tool}")
    unittest.main()
