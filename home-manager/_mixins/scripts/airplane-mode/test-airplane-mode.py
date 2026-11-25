# The airplane-mode build runs these mocked tests through default.nix postCheck.
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT, BASH = sys.argv[1:3]
sys.argv[1:] = []

FAKE = r"""
import json
import os
import sys
from pathlib import Path

root = Path(os.environ["FAKE_ROOT"])
name = Path(sys.argv[0]).name
args = sys.argv[1:]
with (root / "calls").open("a") as stream:
    stream.write(json.dumps([name, *args]) + "\n")

if name == "rfkill":
    state_file = root / "rfkill.json"
    devices = json.loads(state_file.read_text())
    if args[:1] == ["-J"]:
        print(json.dumps({"rfkilldevices": devices}))
        sys.exit(0)
    if args[:1] == ["block"]:
        target = args[1]
        for dev in devices:
            if target == "all" or dev["type"] == target:
                dev["soft"] = "blocked"
        state_file.write_text(json.dumps(devices))
        sys.exit(0)
    if args[:1] == ["unblock"]:
        target = args[1]
        for dev in devices:
            if target == "all" or dev["type"] == target:
                dev["soft"] = "unblocked"
        state_file.write_text(json.dumps(devices))
        sys.exit(0)
    sys.exit(90)
elif name == "fyi":
    sys.exit(0)
else:
    sys.exit(91)
"""


def make_env(root: Path, binary: Path) -> dict[str, str]:
    return {
        "PATH": str(binary) + os.pathsep + os.environ["PATH"],
        "HOME": str(root),
        "XDG_STATE_HOME": str(root / "state"),
        "FAKE_ROOT": str(root),
    }


class AirplaneModeTests(unittest.TestCase):
    def run_cmd(self, root: Path, binary: Path, *args: str):
        return subprocess.run(
            [BASH, SCRIPT, *args],
            env=make_env(root, binary),
            capture_output=True,
            text=True,
            timeout=10,
            check=False,
        )

    def setup_fake(self, root: Path, devices):
        binary = root / "bin"
        binary.mkdir()
        for name in ("rfkill", "fyi"):
            command = binary / name
            command.write_text(f"#!{sys.executable}\n" + FAKE)
            command.chmod(0o755)
        (root / "rfkill.json").write_text(json.dumps(devices))
        return binary

    def test_unavailable_when_no_wlan_or_bluetooth(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            binary = self.setup_fake(root, [])
            self.assertNotEqual(self.run_cmd(root, binary, "available").returncode, 0)
            self.assertNotEqual(self.run_cmd(root, binary, "status").returncode, 0)

    def test_toggle_saves_and_restores_only_previously_unblocked_radios(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            devices = [
                {"id": 0, "type": "wlan", "soft": "unblocked", "hard": "unblocked"},
                {"id": 1, "type": "bluetooth", "soft": "blocked", "hard": "unblocked"},
            ]
            binary = self.setup_fake(root, devices)

            self.assertEqual(self.run_cmd(root, binary, "available").returncode, 0)
            self.assertNotEqual(self.run_cmd(root, binary, "status").returncode, 0)

            enable = self.run_cmd(root, binary, "toggle")
            self.assertEqual(enable.returncode, 0, enable.stderr)
            self.assertEqual(self.run_cmd(root, binary, "status").returncode, 0)
            saved = (root / "state" / "airplane-mode" / "unblocked").read_text().splitlines()
            self.assertEqual(saved, ["wlan"])

            disable = self.run_cmd(root, binary, "toggle")
            self.assertEqual(disable.returncode, 0, disable.stderr)
            self.assertNotEqual(self.run_cmd(root, binary, "status").returncode, 0)

            after = json.loads((root / "rfkill.json").read_text())
            self.assertEqual(after[0]["soft"], "unblocked")
            self.assertEqual(after[1]["soft"], "blocked")

    def test_disable_without_saved_state_unblocks_all(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            devices = [
                {"id": 0, "type": "wlan", "soft": "blocked", "hard": "unblocked"},
                {"id": 1, "type": "bluetooth", "soft": "blocked", "hard": "unblocked"},
            ]
            binary = self.setup_fake(root, devices)

            self.assertEqual(self.run_cmd(root, binary, "status").returncode, 0)
            disable = self.run_cmd(root, binary, "toggle")
            self.assertEqual(disable.returncode, 0, disable.stderr)
            after = json.loads((root / "rfkill.json").read_text())
            self.assertEqual([d["soft"] for d in after], ["unblocked", "unblocked"])


if __name__ == "__main__":
    unittest.main()
