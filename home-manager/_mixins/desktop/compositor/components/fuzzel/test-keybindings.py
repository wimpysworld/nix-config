# The fuzzel-keybindings build runs these tests through keybindings.nix postCheck.
import configparser
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

HELPER, CONFIG = map(Path, sys.argv[1:3])
sys.argv[1:] = []
FAKE = r"""
import json
import os
import sys
from pathlib import Path

root = Path(os.environ["FAKE_ROOT"])
trace = root / "calls.jsonl"
with trace.open("a") as stream:
    stream.write(json.dumps({"args": sys.argv[1:], "input": sys.stdin.read()}) + "\n")
responses = json.loads(os.environ["FAKE_RESPONSES"])
index = len(trace.read_text().splitlines()) - 1
if index >= len(responses):
    sys.exit(99)
output, status = responses[index]
sys.stdout.write(output)
sys.exit(status)
"""


class KeyboardHelpTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        binary = self.root / "bin"
        binary.mkdir()
        fuzzel = binary / "fuzzel"
        fuzzel.write_text(f"#!{sys.executable}\n" + FAKE)
        fuzzel.chmod(0o755)
        self.env = {**os.environ, "PATH": str(binary), "FAKE_ROOT": str(self.root)}
        self.entries = [
            {
                "description": "Move window left",
                "keys": "Super+Shift+Left",
                "category": "Windows",
                "keywords": ["west", "tile"],
            },
            {
                "description": "Open terminal",
                "keys": "Super+Return",
                "category": "Application",
            },
        ]

    def launch(self, entries=None, output="1\n", status=0, responses=None):
        catalogue = self.root / "entries.json"
        catalogue.write_text(json.dumps(self.entries if entries is None else entries))
        (self.root / "calls.jsonl").write_text("")
        result = subprocess.run(
            [sys.executable, str(HELPER), str(catalogue), str(CONFIG)],
            env={
                **self.env,
                "FAKE_RESPONSES": json.dumps(
                    responses if responses is not None else [(output, status)]
                ),
            },
            capture_output=True,
            text=True,
            check=False,
            timeout=10,
        )
        self.assertEqual(result.stdout, "")
        self.calls = [
            json.loads(line)
            for line in (self.root / "calls.jsonl").read_text().splitlines()
        ]
        call = dict(self.calls[0])
        if entries != []:
            call["input"] = call["input"].split("\n", 1)[1]
        return result, call

    def test_display_and_hidden_search(self):
        result, call = self.launch()
        self.assertEqual(result.returncode, 0, result.stderr)
        rows = [line.split("\t") for line in call["input"].splitlines()]
        self.assertEqual(len(rows), len(self.entries))
        key_width = max(len(entry["keys"]) for entry in self.entries)
        description_width = max(len(entry["description"]) for entry in self.entries)
        for entry, (label, search) in zip(reversed(self.entries), rows, strict=True):
            for key in ("keys", "description", "category"):
                self.assertIn(entry[key], label)
                self.assertIn(entry[key], search)
            self.assertEqual(
                label,
                f"{entry['keys']:<{key_width}}  "
                f"{entry['description']:<{description_width}}  {entry['category']}",
            )
            self.assertEqual(
                search,
                " ".join(
                    [
                        f"{entry['keys']}  {entry['description']}  {entry['category']}",
                        *entry.get("keywords", []),
                    ]
                ),
            )
            for alias in entry.get("keywords", []):
                self.assertNotIn(alias, label)
                self.assertIn(alias, search)
        for argument in (
            "--dmenu",
            "--index",
            "--only-match",
            "--with-nth=1",
            "--match-nth=2",
            "--match-mode=exact",
            "--cache=/dev/null",
            "--prompt=󰌌 ",
            f"--config={CONFIG}",
        ):
            self.assertIn(argument, call["args"])
        config = configparser.ConfigParser()
        config.read(CONFIG)
        self.assertTrue(config["main"]["include"].endswith("/fuzzel/fuzzel.ini"))
        self.assertEqual(config["key-bindings"]["execute-input"], "none")

    def test_stable_category_blocks_and_unknown_categories_last(self):
        categories = [
            "Application",
            "Menu",
            "Session",
            "Capture",
            "Audio",
            "Media",
            "Display",
            "Workspaces",
            "Windows",
            "Resize Windows",
            "Keyboard",
            "Other",
        ]
        entries = [
            {"keys": str(index), "description": category, "category": category}
            for index, category in enumerate(
                list(reversed(categories)) + categories[::2] + categories[1::2]
            )
        ]
        result, call = self.launch(
            entries=entries, responses=[("0\n", 0), ("", 2), ("", 2)]
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        group_rows = [
            line.split("\t") for line in self.calls[1]["input"].splitlines()[1:]
        ]
        self.assertEqual([search for _, search in group_rows], categories)
        glyphs = [
            "\U000f003b",
            "\U000f035c",
            "\U000f11ef",
            "\U000f13b4",
            "\U000f057e",
            "\U000f127a",
            "\U000f00df",
            "\U000f11d9",
            "\U000f08c6",
            "\U000f01be",
            "",
            "",
        ]
        self.assertEqual(
            [label for label, _ in group_rows],
            [
                f"{glyph} {category}" if glyph else category
                for glyph, category in zip(glyphs, categories, strict=True)
            ],
        )
        labels = [line.split("\t")[0] for line in call["input"].splitlines()]
        expected = [
            entry
            for category in categories
            for entry in entries
            if entry["category"] == category
        ]
        self.assertEqual(
            [label.split()[0] for label in labels],
            [entry["keys"] for entry in expected],
        )

    def test_release_and_resize_terms_are_hidden(self):
        entries = [
            {
                "keys": "Super",
                "description": "Toggle application grid",
                "category": "Application",
                "keywords": ["release"],
            },
            {
                "keys": "Caps Lock",
                "description": "Show Caps Lock state",
                "category": "Keyboard",
                "keywords": ["release"],
            },
            {
                "keys": "Left",
                "description": "Resize window left",
                "category": "Resize Windows",
                "keywords": ["resize mode"],
            },
        ]
        result, call = self.launch(entries=entries)
        self.assertEqual(result.returncode, 0, result.stderr)
        rows = [line.split("\t") for line in call["input"].splitlines()]
        for entry, (label, search) in zip(
            [entries[0], entries[2], entries[1]], rows, strict=True
        ):
            self.assertTrue(label.startswith(f"{entry['keys']:<9}  "))
            self.assertNotIn(" · ", label)
            for keyword in entry["keywords"]:
                self.assertNotIn(keyword, label)
                self.assertIn(keyword, search)
            self.assertNotIn(" (release)", label)
            self.assertNotIn(" (resize mode)", label)

    def test_unicode_display_width(self):
        entries = [
            {"keys": "Super+←", "description": "Cafe\u0301", "category": "Arrows"},
            {"keys": "界", "description": "Wide 界", "category": "Wide"},
            {"keys": "e\u0301", "description": "Short", "category": "Combining"},
        ]
        result, call = self.launch(entries=entries)
        self.assertEqual(result.returncode, 0, result.stderr)
        labels = [line.split("\t")[0] for line in call["input"].splitlines()]
        self.assertEqual(
            labels,
            [
                "Super+←  Cafe\u0301     Arrows",
                "e\u0301        Short    Combining",
                "界       Wide 界  Wide",
            ],
        )

    def test_content_width_is_bounded_without_truncating_columns(self):
        for length in (60, 140):
            with self.subTest(length=length):
                entries = [
                    {"keys": "K" * length, "description": "D", "category": "C"},
                    {"keys": "K", "description": "D" * 10, "category": "C"},
                ]
                result, call = self.launch(entries=entries)
                self.assertEqual(result.returncode, 0, result.stderr)
                labels = [line.split("\t")[0] for line in call["input"].splitlines()]
                self.assertEqual(labels[0], "K" * length + "  D           C")
                self.assertEqual(labels[1], "K" + " " * (length + 1) + "D" * 10 + "  C")
                self.assertIn(f"--width={min(len(labels[0]), 120)}", call["args"])

    def test_empty_catalogue(self):
        result, call = self.launch(entries=[], output="0\n")
        self.assertEqual(result.returncode, 0, result.stderr)
        rows = call["input"].splitlines()
        self.assertEqual(len(rows), 1)
        label, search = rows[0].split("\t")
        self.assertTrue(label)
        self.assertEqual(label, search)
        self.assertIn("--width=56", call["args"])

    def test_selection_and_cancellation_are_inert(self):
        marker = self.root / "executed"
        self.entries[0]["description"] = f"$(touch {marker})"
        for responses in (
            [("1", 0)],
            [("2\n", 0)],
            [("", 2)],
            [(f"touch {marker}\n", 2)],
            [("0\n", 0), ("2\n", 0), ("1\n", 0)],
        ):
            with self.subTest(responses=responses):
                result, _ = self.launch(responses=responses)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(len(self.calls), len(responses))
                self.assertFalse(marker.exists())

    def test_invalid_indices_and_exit_codes_stop_at_each_level(self):
        marker = self.root / "executed"
        invalid = [
            (output, 0)
            for output in (
                "",
                "-1\n",
                "+1\n",
                "01\n",
                " 0\n",
                "0 \n",
                "0\n\n",
                "1\n0\n",
                "1.0\n",
                "９\n",
                "3\n",
                "999\n",
                "9" * 100,
                f"$(touch {marker})\n",
            )
        ] + [("0\n", status) for status in (1, 3, 10, 127)]
        for prefix in ([], [("0\n", 0)], [("0\n", 0), ("1\n", 0)]):
            for response in invalid:
                with self.subTest(prefix=prefix, response=response):
                    result, _ = self.launch(responses=prefix + [response])
                    self.assertEqual(result.returncode, 1)
                    self.assertEqual(len(self.calls), len(prefix) + 1)
                    self.assertIn("Fuzzel", result.stderr)
                    self.assertFalse(marker.exists())

    def test_browse_back_and_escape_reset_queries(self):
        for back in (("0\n", 0), ("ignored on cancel", 2)):
            with self.subTest(back=back):
                responses = [("0\n", 0), ("2\n", 0), back, back, ("", 2)]
                result, _ = self.launch(responses=responses)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(len(self.calls), 5)
                root, groups, entries, groups_again, root_again = self.calls
                self.assertEqual(root, root_again)
                self.assertEqual(groups, groups_again)
                self.assertEqual(
                    groups["input"],
                    "\U000f17b3 Back\tBack\n"
                    "\U000f003b Application\tApplication\n"
                    "\U000f08c6 Windows\tWindows\n",
                )
                self.assertTrue(root["input"].startswith("\U000f09f9 Browse\tBrowse\n"))
                self.assertNotIn("--no-sort", root["args"])
                self.assertEqual(
                    entries["input"].splitlines(),
                    ["\U000f17b3 Back\tBack", root["input"].splitlines()[2]],
                )
                for call in self.calls:
                    self.assertFalse(
                        any(arg.startswith("--filter") for arg in call["args"])
                    )
                    self.assertIn("--cache=/dev/null", call["args"])
                    self.assertIn("--only-match", call["args"])
                for call in (groups, entries):
                    self.assertIn("--no-sort", call["args"])

    def test_groups_keep_full_catalogue_columns_and_hidden_aliases(self):
        self.entries[0].update(description="Close window", keywords=["quit", "exit"])
        self.entries[1]["description"] = "Open a terminal with a long description"
        result, _ = self.launch(responses=[("0\n", 0), ("2\n", 0), ("1\n", 0)])
        self.assertEqual(result.returncode, 0, result.stderr)
        root, _, group = self.calls
        self.assertEqual(group["input"].splitlines()[1], root["input"].splitlines()[2])
        for call in (root, group):
            label, search = call["input"].splitlines()[-1].split("\t")
            for alias in ("quit", "exit"):
                self.assertNotIn(alias, label)
                self.assertIn(alias, search)
        self.assertEqual(
            [arg for arg in root["args"] if arg.startswith("--width=")],
            [arg for arg in group["args"] if arg.startswith("--width=")],
        )
        result, _ = self.launch(responses=[("0\n", 0), ("1\n", 0), ("1\n", 0)])
        self.assertEqual(result.returncode, 0, result.stderr)
        root, _, group = self.calls
        self.assertEqual(group["input"].splitlines()[1], root["input"].splitlines()[1])

    def test_record_separators_cannot_inject_rows_or_metadata(self):
        entries = [
            {
                "keys": "Super+Return\r\n",
                "description": "Open\tterminal\x00info\x1fvalue",
                "category": "Apps\u2028Other",
                "keywords": ["shell\nextra\tfield\x00"],
            }
        ]
        result, call = self.launch(
            entries=entries, responses=[("0\n", 0), ("1\n", 0), ("1\n", 0)]
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        rows = call["input"].splitlines()
        self.assertEqual(len(rows), 1)
        self.assertEqual(len(rows[0].split("\t")), 2)
        self.assertNotIn("\x00", rows[0])
        self.assertNotIn("\x1f", rows[0])
        self.assertEqual(self.calls[2]["input"].splitlines()[1:], rows)
        self.assertEqual(len(self.calls[1]["input"].splitlines()), 2)

    def test_launcher_failure_is_reported(self):
        result, _ = self.launch(status=1)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Fuzzel exited", result.stderr)


if __name__ == "__main__":
    unittest.main()
