# The fuzzel-emoji build runs these tests through emoji.nix postCheck.
import importlib.util
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from unittest.mock import patch

HELPER, ENTRY, CONFIG, MASTER = map(Path, sys.argv[1:5])
sys.argv[1:] = []
spec = importlib.util.spec_from_file_location("emoji", HELPER)
assert spec is not None and spec.loader is not None
emoji = importlib.util.module_from_spec(spec)
spec.loader.exec_module(emoji)

FAKE = r"""
import json
import os
from pathlib import Path
import sys

root = Path(os.environ["FAKE_ROOT"])
name = Path(sys.argv[0]).name

def log(event):
    with (root / "events").open("a", encoding="utf-8") as stream:
        stream.write(json.dumps(event) + "\n")

if name == "fuzzel":
    queue = json.loads((root / "queue").read_text())
    choice = queue.pop(0)
    (root / "queue").write_text(json.dumps(queue))
    log({"command": name, "args": sys.argv[1:], "input": sys.stdin.read()})
    if choice.get("mutate"):
        state = Path(os.environ["XDG_STATE_HOME"]) / "fuzzel-emoji/tone"
        state.parent.mkdir(parents=True, exist_ok=True)
        state.write_text("dark\n")
        for cache in (Path(os.environ["XDG_CACHE_HOME"]) / "fuzzel-emoji").glob("*.tsv"):
            cache.write_text("corrupt\n")
    log({"command": "menu-exit"})
    sys.stdout.write(choice.get("output", ""))
    status = choice.get("status", 0)
    if status < 0:
        os.kill(os.getpid(), -status)
    sys.exit(status)
log({"command": name, "args": sys.argv[1:]})
"""


class PickerTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        binary = self.root / "bin"
        binary.mkdir()
        for name in ("fuzzel", "wtype", "wl-copy"):
            command = binary / name
            command.write_text(f"#!{sys.executable}\n" + FAKE)
            command.chmod(0o755)
        self.master = self.root / "master.json"
        self.master.write_text(
            json.dumps(
                {
                    "schemaVersion": 1,
                    "sources": {},
                    "emojis": [
                        {
                            "id": "1F44B",
                            "emoji": "👋",
                            "name": "waving hand",
                            "keywords": ["hello", "goodbye"],
                            "group": "People & Body",
                            "subgroup": "hand-fingers-open",
                            "emojiVersion": "0.6",
                            "skinTones": dict(
                                zip(
                                    emoji.TONES[1:],
                                    ["👋🏻", "👋🏼", "👋🏽", "👋🏾", "👋🏿"],
                                    strict=True,
                                )
                            ),
                        },
                        {
                            "id": "1F600",
                            "emoji": "😀",
                            "name": "grinning face",
                            "keywords": ["happy"],
                            "group": "Smileys & Emotion",
                            "subgroup": "face-smiling",
                            "emojiVersion": "1.0",
                            "skinTones": {},
                        },
                        {
                            "id": "1F91D",
                            "emoji": "🤝",
                            "name": "handshake",
                            "keywords": ["agreement"],
                            "group": "People & Body",
                            "subgroup": "hands",
                            "emojiVersion": "3.0",
                            "skinTones": {},
                        },
                    ],
                }
            )
        )
        self.env = {
            **os.environ,
            "HOME": str(self.root / "home"),
            "XDG_STATE_HOME": str(self.root / "state"),
            "XDG_CACHE_HOME": str(self.root / "cache"),
            "PATH": os.pathsep.join(
                [str(binary), str(Path(sys.executable).parent), os.environ["PATH"]]
            ),
            "FAKE_ROOT": str(self.root),
            "FUZZEL_EMOJI_HELPER": str(HELPER.resolve()),
            "FUZZEL_EMOJI_MASTER": str(self.master),
            "FUZZEL_EMOJI_CONFIG": str(CONFIG.resolve()),
        }
        self.state = self.root / "state/fuzzel-emoji/tone"

    def run_picker(self, choices, *args, expected_status=0):
        (self.root / "queue").write_text(json.dumps(choices))
        (self.root / "events").write_text("")
        result = subprocess.run(
            ["bash", "-euo", "pipefail", str(ENTRY), *args],
            env=self.env,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, expected_status, result.stderr)
        self.assertEqual(result.stdout, "")
        if expected_status != 0:
            self.assertIn("fuzzel-emoji:", result.stderr)
        self.events = [
            json.loads(line) for line in (self.root / "events").read_text().splitlines()
        ]
        self.assertEqual(json.loads((self.root / "queue").read_text()), [])
        return [event for event in self.events if event["command"] == "fuzzel"]

    def assert_output(self, glyph):
        self.assertEqual(
            self.events[-3:],
            [
                {"command": "menu-exit"},
                {"command": "wtype", "args": [glyph]},
                {"command": "wl-copy", "args": [glyph]},
            ],
        )

    def assert_no_output(self):
        self.assertFalse(
            any(event["command"] in ("wtype", "wl-copy") for event in self.events)
        )

    def test_search_hidden_fields_and_output_order(self):
        menus = self.run_picker([{"output": "3\n"}])
        self.assert_output("👋")
        rows = menus[0]["input"].splitlines()
        self.assertEqual(len(rows), 6)
        # Nerd Fonts glyphnames.json: cod-sparkle_filled, md-folder_table, md-cog.
        # https://raw.githubusercontent.com/ryanoasis/nerd-fonts/v3.5.1/glyphnames.json
        self.assertEqual(
            rows[:3],
            ["\uec21 New\t", "\U000f12e3 Browse\t", "\U000f0493 Settings\t"],
        )
        self.assertEqual([row.split("\t")[1] for row in rows[:3]], ["", "", ""])
        label, search, *_ = rows[3].split("\t")
        self.assertEqual(label, "👋 waving hand")
        for term in ("hello", "People & Body", "hand-fingers-open"):
            self.assertNotIn(term, label)
            self.assertIn(term, search)
        for flag in (
            "--index",
            "--only-match",
            "--with-nth=1",
            "--match-nth=2",
            "--match-mode=exact",
            "--width=48",
            "--prompt=󰞅 ",
        ):
            self.assertIn(flag, menus[0]["args"])
        self.assertIn("--no-sort", menus[0]["args"])
        self.assertIn("execute-input=none", CONFIG.read_text())
        self.assertIn("include=", CONFIG.read_text())
        self.run_picker([{"output": "5\n"}])
        self.assert_output("🤝")

    def test_cancel_custom_exit_and_invalid_indexes(self):
        invalid = [
            "",
            "-1\n",
            "6\n",
            "01\n",
            "1\n0\n",
            " 0\n",
            "0 \n",
            "custom\n",
            "９\n",
            "999999999999999999\n",
            "0\n\n",
        ]
        for output in invalid:
            with self.subTest(output=output):
                self.run_picker([{"output": output}], expected_status=1)
                self.assert_no_output()
        for status in (1, 2, 10, 19, -15):
            self.run_picker(
                [{"output": "0\n", "status": status}],
                expected_status=0 if status == 2 else 1,
            )
            self.assert_no_output()
        self.assertFalse(self.state.exists())

    def test_tone_menu_persistence_and_fallback(self):
        choices = (
            ("yellow", "👋", "Default yellow"),
            ("light", "👋🏻", "Light"),
            ("medium-light", "👋🏼", "Medium light"),
            ("medium", "👋🏽", "Medium"),
            ("medium-dark", "👋🏾", "Medium dark"),
            ("dark", "👋🏿", "Dark"),
        )
        for index, (tone, glyph, _) in enumerate(choices):
            menus = self.run_picker([{"output": f"{index}\n"}], "--tone")
            self.assertIn("--no-sort", menus[0]["args"])
            self.assertEqual(
                menus[0]["input"].splitlines(),
                [f"{sample} {label}\t{sample} {label}" for _, sample, label in choices],
            )
            self.assert_no_output()
            self.assertEqual(self.state.read_text(), tone + "\n")
            self.run_picker([{"output": "3\n"}])
            self.assert_output(glyph)
            self.run_picker([{"output": "4\n"}])
            self.assert_output("😀")
            self.run_picker([{"output": "5\n"}])
            self.assert_output("🤝")
        self.run_picker([{"status": 2}], "--tone")
        self.assert_no_output()
        self.assertEqual(self.state.read_text(), "dark\n")
        self.run_picker([{"output": "6\n"}], "--tone", expected_status=1)
        self.assertEqual(self.state.read_text(), "dark\n")
        self.state.write_text("invalid")
        self.run_picker([{"output": "3\n"}])
        self.assert_output("👋")

    def test_browser_back_and_shared_projection(self):
        self.run_picker([], "--tone", "medium")
        search = self.run_picker([{"output": "3\n"}])[0]["input"].splitlines()[3]
        menus = self.run_picker(
            [
                {"output": "0\n"},
                {"output": "0\n"},
                {"output": "0\n"},
                {"output": "1\n"},
                {"output": "0\n"},
                {"output": "1\n"},
                {"output": "1\n"},
            ],
            "--browse",
        )
        for menu in menus:
            self.assertIn("--no-sort", menu["args"])
            self.assertIn("--with-nth=1", menu["args"])
            self.assertIn("--match-nth=2", menu["args"])
            self.assertIn("--match-mode=exact", menu["args"])
        self.assertEqual(
            menus[0]["input"].splitlines(),
            ["People & Body\tPeople & Body", "Smileys & Emotion\tSmileys & Emotion"],
        )
        self.assertEqual(
            menus[1]["input"].splitlines(),
            [
                "\U000f17b3 Back\tBack",
                "hand-fingers-open\thand-fingers-open",
                "hands\thands",
            ],
        )
        self.assertEqual(menus[-1]["input"].splitlines()[0], "\U000f17b3 Back\tBack")
        self.assertEqual(menus[-1]["input"].splitlines()[1], search)
        self.assert_output("👋🏽")

    def test_browser_escape_returns_one_level_until_exit(self):
        for depth in range(3):
            choices = [{"output": "0\n"}, {"output": "1\n"}][:depth]
            menus = self.run_picker(choices + [{"status": 2}] * (depth + 1), "--browse")
            self.assertEqual(len(menus), 2 * depth + 1)
            for index in range(depth):
                self.assertEqual(menus[index]["input"], menus[-index - 1]["input"])
            self.assert_no_output()

    def test_failures_stop_at_every_level(self):
        routes = (
            ((), []),
            ((), [0]),
            ((), [1]),
            ((), [1, 1]),
            ((), [1, 1, 1]),
            ((), [2]),
            (("--browse",), []),
            (("--browse",), [0]),
            (("--browse",), [0, 1]),
            (("--tone",), []),
        )
        failures = (
            {"status": 1, "output": "0\n"},
            {"status": 10, "output": "0\n"},
            {"status": 19, "output": "1\n"},
            {"status": -15},
            {"output": "999\n"},
            {"output": "invalid\n"},
            {"output": ""},
        )
        for args, route in routes:
            for failure in failures:
                with self.subTest(args=args, route=route, failure=failure):
                    choices = [{"output": f"{index}\n"} for index in route]
                    menus = self.run_picker(
                        choices + [failure], *args, expected_status=1
                    )
                    self.assertEqual(len(menus), len(route) + 1)
                    self.assert_no_output()
                    self.assertFalse(self.state.exists())

    def test_snapshot_survives_state_and_cache_changes(self):
        self.run_picker([{"output": "3\n", "mutate": True}])
        self.assert_output("👋")
        self.run_picker([], "--tone", "yellow")
        self.run_picker(
            [
                {"output": "0\n", "mutate": True},
                {"output": "1\n"},
                {"output": "1\n"},
            ],
            "--browse",
        )
        self.assert_output("👋")

    def test_root_actions_escape_returns_to_root(self):
        for action in range(3):
            menus = self.run_picker(
                [{"output": f"{action}\n"}, {"status": 2}, {"status": 2}]
            )
            self.assertEqual(menus[0]["input"], menus[2]["input"])
            self.assert_no_output()
            self.assertFalse(self.state.exists())

    def test_nested_escape_returns_exactly_one_level(self):
        menus = self.run_picker([{"output": "1\n"}] * 3 + [{"status": 2}] * 4)
        self.assertEqual(len(menus), 7)
        for index in range(3):
            self.assertEqual(menus[index]["input"], menus[-index - 1]["input"])
        self.assert_no_output()

    def test_escape_preserves_tone_snapshot_and_index(self):
        for route in ([2], [0], [1, 1, 1]):
            self.run_picker([], "--tone", "medium")
            choices = [
                {"output": f"{index}\n", "mutate": offset == len(route) - 1}
                for offset, index in enumerate(route)
            ]
            menus = self.run_picker(
                choices + [{"status": 2}] * len(route) + [{"output": "3\n"}]
            )
            self.assertEqual(menus[0]["input"], menus[-1]["input"])
            self.assertEqual(self.state.read_text(), "dark\n")
            self.assert_output("👋🏽")

    def test_new_and_browse_back_return_to_root(self):
        for action in (0, 1):
            menus = self.run_picker(
                [{"output": f"{action}\n"}, {"output": "0\n"}, {"status": 2}]
            )
            self.assertEqual(menus[0]["input"], menus[2]["input"])
            self.assertEqual(menus[1]["input"].splitlines()[0], "\U000f17b3 Back\tBack")
            self.assert_no_output()
        self.run_picker(
            [{"output": "1\n"}, {"output": "1\n"}, {"output": "1\n"}, {"output": "1\n"}]
        )
        self.assert_output("👋")
        self.run_picker([{"output": "0\n"}, {"output": "1\n"}])
        self.assert_output("🤝")

    def test_settings_refresh_search_new_and_browse(self):
        routes = (
            ([{"status": 2}], None),
            ([{"output": "3\n"}], "👋🏿"),
            ([{"output": "0\n"}, {"output": "3\n"}], "👋🏿"),
            (
                [
                    {"output": "1\n"},
                    {"output": "1\n"},
                    {"output": "1\n"},
                    {"output": "1\n"},
                ],
                "👋🏿",
            ),
        )
        for choices, glyph in routes:
            self.run_picker([], "--tone", "yellow")
            menus = self.run_picker([{"output": "2\n"}, {"output": "5\n"}] + choices)
            self.assertEqual(self.state.read_text(), "dark\n")
            self.assertTrue(menus[0]["input"].splitlines()[3].startswith("👋 "))
            self.assertTrue(menus[2]["input"].splitlines()[3].startswith("👋🏿 "))
            if glyph is None:
                self.assert_no_output()
            else:
                self.assert_output(glyph)
                self.assertEqual(
                    [e["command"] for e in self.events if e["command"] != "fuzzel"],
                    ["menu-exit"] * len(menus) + ["wtype", "wl-copy"],
                )

    def test_new_numeric_releases_and_stable_tone_snapshot(self):
        data = json.loads(self.master.read_text())
        template = data["emojis"][0]
        versions = (
            "10.2",
            "11.0",
            "14.0",
            "9.0",
            "10.10",
            "14.0",
            "13.0",
            "12.0",
            "11.0",
        )
        data["emojis"] = [
            {
                **template,
                "id": str(index),
                "name": f"hand {index}",
                "emojiVersion": version,
            }
            for index, version in enumerate(versions)
        ]
        self.master.write_text(json.dumps(data))
        self.run_picker([], "--tone", "medium")
        menus = self.run_picker([{"output": "0\n", "mutate": True}, {"output": "1\n"}])
        self.assert_output("👋🏽")
        root = [line.split("\t") for line in menus[0]["input"].splitlines()[3:]]
        recent = [line.split("\t") for line in menus[1]["input"].splitlines()[1:]]
        self.assertEqual(
            [row[5] for row in recent], ["2", "5", "6", "7", "1", "8", "4"]
        )
        for row in recent:
            original = root[int(row[5])]
            self.assertEqual(row[0], f"{original[6]} · {original[0]}")
            self.assertEqual(row[1:], original[1:])
        self.assertIn("--no-sort", menus[1]["args"])

    def test_legacy_cache_is_not_reused_and_actions_are_not_projections(self):
        with patch.dict(os.environ, self.env):
            self.assertGreater(emoji.PROJECTION_VERSION, 1)
            with patch.object(emoji, "PROJECTION_VERSION", 1):
                rows = emoji.projection(self.master, "yellow")
            legacy = next((self.root / "cache/fuzzel-emoji").glob("*.tsv"))
            old_text = "".join("\t".join(row[:6]) + "\n" for row in rows)
            legacy.write_text(old_text)
            self.assertEqual(emoji.projection(self.master, "yellow"), rows)
            self.assertEqual(legacy.read_text(), old_text)
            self.assertEqual(len(list(legacy.parent.glob("*.tsv"))), 2)
            invalid = [old_text, "\uec21 New\t\n"]
            invalid.extend(
                "\t".join((*rows[0][:6], version)) + "\n"
                for version in ("", "18", "18.x", "18.0.1")
            )
            for text in invalid:
                with self.subTest(text=text), self.assertRaises(ValueError):
                    emoji.parse_projection(text)

    def test_cache_identity_reuse_and_repair(self):
        with patch.dict(os.environ, self.env):
            first = emoji.projection(self.master, "yellow")
            cache_dir = self.root / "cache/fuzzel-emoji"
            cache = next(cache_dir.glob("*.tsv"))
            before = cache.stat().st_mtime_ns
            self.assertEqual(emoji.projection(self.master, "yellow"), first)
            self.assertEqual(cache.stat().st_mtime_ns, before)
            copy = self.root / "different-store-path.json"
            shutil.copyfile(self.master, copy)
            emoji.projection(copy, "yellow")
            emoji.projection(self.master, "dark")
            with patch.object(
                emoji, "PROJECTION_VERSION", emoji.PROJECTION_VERSION + 1
            ):
                emoji.projection(self.master, "yellow")
            data = json.loads(copy.read_text())
            data["schemaVersion"] = 2
            copy.write_text(json.dumps(data))
            with patch.object(emoji, "SCHEMA_VERSION", 2):
                emoji.projection(copy, "yellow")
            self.assertEqual(len(list(cache_dir.glob("*.tsv"))), 5)
            cache.write_text("broken\n")
            self.assertEqual(emoji.projection(self.master, "yellow"), first)
            self.assertEqual(cache.read_text().count("\n"), 3)

    def test_atomic_writes_and_xdg_fallbacks(self):
        target = self.root / "atomic/tone"
        with ThreadPoolExecutor(max_workers=6) as pool:
            list(
                pool.map(
                    lambda tone: emoji.atomic_write(target, tone * 1000), emoji.TONES
                )
            )
        self.assertIn(target.read_text(), [tone * 1000 for tone in emoji.TONES])
        self.assertEqual(list(target.parent.iterdir()), [target])
        with patch.dict(
            os.environ, {**self.env, "XDG_STATE_HOME": "", "XDG_CACHE_HOME": ""}
        ):
            self.assertEqual(
                emoji.xdg_path("XDG_STATE_HOME", ".local/state"),
                self.root / "home/.local/state/fuzzel-emoji",
            )
            self.assertEqual(
                emoji.xdg_path("XDG_CACHE_HOME", ".cache"),
                self.root / "home/.cache/fuzzel-emoji",
            )

    def test_real_master_projection_and_browser(self):
        with MASTER.open(encoding="utf-8") as stream:
            data = json.load(stream)
        with patch.dict(os.environ, self.env):
            for tone in emoji.TONES:
                rows = emoji.projection(MASTER, tone)
                self.assertEqual(len(rows), len(data["emojis"]))
                for row, entry in zip(rows, data["emojis"], strict=True):
                    self.assertEqual(row[5], entry["id"])
                    self.assertEqual(row[6], entry["emojiVersion"])
                    self.assertEqual(
                        row[2], entry["skinTones"].get(tone, entry["emoji"])
                    )
                    if entry.get("tonePolicy") == "default":
                        self.assertEqual(row[2], entry["emoji"])
                latest = sorted(
                    {
                        tuple(map(int, entry["emojiVersion"].split(".")))
                        for entry in data["emojis"]
                    },
                    reverse=True,
                )[:5]
                expected = [
                    entry
                    for version in latest
                    for entry in data["emojis"]
                    if tuple(map(int, entry["emojiVersion"].split("."))) == version
                ]
                recent = emoji.recent_rows(rows)
                self.assertEqual(
                    [row[5] for row in recent], [entry["id"] for entry in expected]
                )
                for row, entry in zip(recent, expected, strict=True):
                    self.assertEqual(
                        row[2], entry["skinTones"].get(tone, entry["emoji"])
                    )
        self.env["FUZZEL_EMOJI_MASTER"] = str(MASTER)
        search = self.run_picker([{"output": "3\n"}])[0]["input"].splitlines()[3]
        menus = self.run_picker(
            [
                {"output": "0\n"},
                {"output": "1\n"},
                {"output": "1\n"},
            ],
            "--browse",
        )
        self.assertEqual(menus[-1]["input"].splitlines()[1], search)
        self.assert_output(data["emojis"][0]["emoji"])

    def test_help_never_types_or_copies(self):
        self.run_picker([], "--help")
        self.assert_no_output()
        self.run_picker([], "--tone", "--help")
        self.assert_no_output()
        self.assertFalse(self.state.exists())

    def test_bad_master_never_opens_menu_or_outputs(self):
        self.master.write_text('{"schemaVersion": 99, "emojis": []}')
        result = subprocess.run(
            ["bash", "-euo", "pipefail", str(ENTRY)],
            env=self.env,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.root / "events").exists())


if __name__ == "__main__":
    unittest.main()
