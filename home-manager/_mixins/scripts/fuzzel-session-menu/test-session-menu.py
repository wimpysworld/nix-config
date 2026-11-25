# The fuzzel-session-menu build runs these tests through default.nix postCheck.
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
if name == "fuzzel":
    menu = sys.stdin.read()
    (root / "menu.json").write_text(json.dumps(menu.splitlines()))
    (root / "fuzzel-args.json").write_text(json.dumps(args))
    choice = os.environ["CHOICE"]
    if choice == "keyboard":
        print(next(row for row in menu.splitlines() if row.endswith("Keyboard shortcuts")))
    elif choice == "virtualcam":
        print(next(row for row in menu.splitlines() if "Virtualcam" in row))
    elif choice == "airplane":
        print(next(row for row in menu.splitlines() if "Airplane Mode" in row))
    else:
        print(choice)
    sys.exit(int(os.environ.get("STATUS", "0")))
if name == "virtualcam" and args == ["status"]:
    sys.exit(int(os.environ.get("VIRTUALCAM_STATUS", "1")))
if name == "airplane-mode" and args == ["available"]:
    sys.exit(int(os.environ.get("AIRPLANE_AVAILABLE", "0")))
if name == "airplane-mode" and args == ["status"]:
    sys.exit(int(os.environ.get("AIRPLANE_STATUS", "1")))
with (root / "calls").open("a") as stream:
    stream.write(" ".join([name, *args]) + "\n")
"""


class SessionMenuTests(unittest.TestCase):
    def launch(
        self,
        available=False,
        choice="",
        status=0,
        virtualcam=False,
        virtualcam_status=1,
        airplane=False,
        airplane_available=0,
        airplane_status=1,
        extra_commands=(),
    ):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            binary = root / "bin"
            binary.mkdir()
            commands = ["fuzzel", *extra_commands]
            if available:
                commands.append("fuzzel-keybindings")
            if virtualcam:
                commands.append("virtualcam")
            if airplane:
                commands.append("airplane-mode")
            for name in commands:
                command = binary / name
                command.write_text(f"#!{sys.executable}\n" + FAKE)
                command.chmod(0o755)
            result = subprocess.run(
                [BASH, SCRIPT],
                env={
                    **os.environ,
                    "PATH": str(binary),
                    "FAKE_ROOT": str(root),
                    "CHOICE": choice,
                    "STATUS": str(status),
                    "VIRTUALCAM_STATUS": str(virtualcam_status),
                    "AIRPLANE_AVAILABLE": str(airplane_available),
                    "AIRPLANE_STATUS": str(airplane_status),
                },
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            menu = json.loads((root / "menu.json").read_text())
            fuzzel_args = json.loads((root / "fuzzel-args.json").read_text())
            calls = (
                (root / "calls").read_text().splitlines()
                if (root / "calls").exists()
                else []
            )
            return menu, calls, fuzzel_args

    def test_unavailable_launcher_is_hidden(self):
        menu, calls, _ = self.launch(available=False)
        self.assertFalse(any(row.endswith("Keyboard shortcuts") for row in menu))
        self.assertEqual(calls, [])

    def test_available_launcher_opens_read_only_help(self):
        menu, calls, _ = self.launch(available=True, choice="keyboard")
        self.assertEqual(sum(row.endswith("Keyboard shortcuts") for row in menu), 1)
        self.assertEqual(calls, ["fuzzel-keybindings"])

    def test_cancel_and_arbitrary_input_do_not_launch_help(self):
        for choice, status in (("", 2), ("fuzzel-keybindings", 0)):
            with self.subTest(choice=choice, status=status):
                _, calls, _ = self.launch(available=True, choice=choice, status=status)
                self.assertEqual(calls, [])

    def test_virtualcam_hidden_when_unavailable(self):
        menu, calls, _ = self.launch(available=False, virtualcam=False)
        self.assertFalse(any("Virtualcam" in row for row in menu))
        self.assertEqual(calls, [])

    def test_virtualcam_off_and_on_labels_toggle(self):
        cases = [
            (1, "\U000f05df Virtualcam \uf204"),
            (0, "\U000f0100 Virtualcam \uf205"),
        ]
        for virtualcam_status, expected in cases:
            with self.subTest(virtualcam_status=virtualcam_status):
                menu, calls, _ = self.launch(
                    available=False,
                    choice="virtualcam",
                    virtualcam=True,
                    virtualcam_status=virtualcam_status,
                )
                self.assertIn(expected, menu)
                self.assertEqual(calls, ["virtualcam toggle"])

    def test_airplane_mode_visibility_and_toggle(self):
        menu, _, _ = self.launch(airplane=True, airplane_available=1)
        self.assertFalse(any("Airplane Mode" in row for row in menu))

        cases = [
            (1, "\U000f001e Airplane Mode \uf204"),
            (0, "\U000f001d Airplane Mode \uf205"),
        ]
        for airplane_status, expected in cases:
            with self.subTest(airplane_status=airplane_status):
                menu, calls, _ = self.launch(
                    choice="airplane",
                    airplane=True,
                    airplane_available=0,
                    airplane_status=airplane_status,
                )
                self.assertEqual(menu[0], expected)
                self.assertEqual(calls, ["airplane-mode toggle"])

    def test_menu_order_and_dynamic_lines(self):
        menu, _, fuzzel_args = self.launch(
            available=True,
            virtualcam=True,
            airplane=True,
            extra_commands=(
                "fuzzel-wifi",
                "fuzzel-picker",
                "fuzzel-connections",
                "fuzzel-layout",
            ),
        )
        labels = [row.split(" ", 1)[1] if row else "" for row in menu]
        self.assertEqual(
            labels,
            [
                "Airplane Mode \uf204",
                "WiFi",
                "Bluetooth",
                "Audio",
                "Virtualcam \uf204",
                "Screenshot",
                "Colour Picker",
                "Session",
                "",
                "Connections",
                "Control Center",
                "Window Layout",
                "Keyboard shortcuts",
            ],
        )
        self.assertIn(f"--lines={len(menu)}", fuzzel_args)


if __name__ == "__main__":
    unittest.main()
