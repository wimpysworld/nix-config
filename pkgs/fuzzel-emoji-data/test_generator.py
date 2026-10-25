"""Boundary tests run in the fuzzel-emoji-data package checkPhase."""

import copy
import json
import os
import unittest
from pathlib import Path

from generate import TONES, codepoint_id, generate, parse_catalogue


def unicode_text(rows):
    header = "# Version: 18.0\n# group: People & Body\n# subgroup: hand-fingers-open\n"
    return header + "\n".join(
        f"{' '.join(f'{ord(c):04X}' for c in emoji)} ; {status} # {emoji} E1.0 {name}"
        for emoji, status, name in rows
    )


class GeneratorTests(unittest.TestCase):
    def setUp(self):
        self.rows = [
            ("👋", "fully-qualified", "waving hand"),
            ("👋🏻", "fully-qualified", "waving hand: light skin tone"),
            ("👋🏿", "fully-qualified", "waving hand: dark skin tone"),
            ("🧑‍🤝‍🧑", "fully-qualified", "people holding hands"),
            ("🧑🏻‍🤝‍🧑🏿", "fully-qualified", "people holding hands: light skin tone, dark skin tone"),
        ]
        _, self.catalogue = parse_catalogue(unicode_text(self.rows))
        self.annotations = [
            {"emoji": "👋", "label": "annotation name", "tags": ["Hello", "bye"], "skins": [
                {"emoji": "👋🏻", "tone": 1},
                {"emoji": "👋🏿", "tone": 5},
                {"emoji": "👋︎", "tone": 1},
            ]},
            {"emoji": "🧑‍🤝‍🧑", "label": "people holding hands", "skins": [
                {"emoji": "🧑🏻‍🤝‍🧑🏿", "tone": [1, 5]},
            ]},
            {"emoji": "🏻", "label": "component"},
        ]

    def build(self, annotations=None, overrides=None):
        return generate(
            self.catalogue,
            self.annotations if annotations is None else annotations,
            {"👋": ["HELLO", "good_bye", "good\u00a0bye"]},
            {} if overrides is None else overrides,
        )

    def test_unicode_metadata_order_and_explicit_mapping(self):
        records = self.build()
        self.assertEqual([entry["emoji"] for entry in records], ["👋", "🧑‍🤝‍🧑"])
        for field, value in self.catalogue["👋"].items():
            self.assertEqual(records[0][field], value)
        self.assertEqual(records[0]["skinTones"], {"light": "👋🏻", "dark": "👋🏿"})
        self.assertEqual(records[1]["tonePolicy"], "default")
        self.assertEqual(records[1]["skinTones"], {})
        self.assertEqual(records[1]["variants"][0]["emoji"], "🧑🏻‍🤝‍🧑🏿")
        self.assertEqual(records, self.build())

    def test_keywords_merge_normalise_deduplicate_and_override(self):
        keywords = self.build(overrides={"👋": {"add": ["local", "HELLO"], "remove": ["bye"]}})[0]["keywords"]
        self.assertEqual(keywords.count("hello"), 1)
        self.assertEqual(keywords.count("good bye"), 1)
        self.assertIn("local", keywords)
        self.assertNotIn("bye", keywords)

    def test_qualification_and_exact_variation_selectors(self):
        text = unicode_text([
            ("☹️", "fully-qualified", "frowning face"),
            ("☹", "unqualified", "frowning face"),
            ("🏻", "component", "light skin tone"),
        ])
        _, catalogue = parse_catalogue(text)
        self.assertEqual(list(catalogue), ["☹️"])
        self.assertNotEqual(codepoint_id("☹️"), codepoint_id("☹"))

    def test_malformed_duplicate_and_mismatched_unicode_rows_fail(self):
        text = unicode_text(self.rows)
        for invalid in (text + "\ninvalid", text + "\n" + text.splitlines()[-1], text.replace("# 👋 E", "# 😀 E", 1)):
            with self.subTest(invalid=invalid), self.assertRaises(ValueError):
                parse_catalogue(invalid)

    def test_missing_annotations_and_unmapped_modifiers_fail(self):
        with self.assertRaises(ValueError):
            self.build(annotations=self.annotations[1:])
        annotations = copy.deepcopy(self.annotations)
        skin = annotations[0]["skins"].pop(0)
        annotations.append({**skin, "label": "orphan"})
        with self.assertRaises(ValueError):
            self.build(annotations=annotations)

    def test_invalid_tone_metadata_fails(self):
        for tone in (0, 6, True, [], [1, 5], "light", 5):
            annotations = copy.deepcopy(self.annotations)
            annotations[0]["skins"][0]["tone"] = tone
            with self.subTest(tone=tone), self.assertRaises(ValueError):
                self.build(annotations=annotations)

    def test_duplicate_annotations_and_unaccepted_parents_fail(self):
        annotations = copy.deepcopy(self.annotations)
        annotations.append(annotations[0])
        with self.assertRaises(ValueError):
            self.build(annotations=annotations)
        annotations = copy.deepcopy(self.annotations)
        annotations[0]["emoji"] = "not an emoji"
        with self.assertRaises(ValueError):
            self.build(annotations=annotations)

    def test_unknown_or_variant_overrides_fail(self):
        for override in ({"unknown": {"add": ["local"]}}, {"👋🏻": {"add": ["local"]}}, {"👋": {"typo": []}}):
            with self.subTest(override=override), self.assertRaises(ValueError):
                self.build(overrides=override)


@unittest.skipUnless(os.environ.get("EMOJI_MASTER"), "Package build supplies the generated catalogue")
class CatalogueTests(unittest.TestCase):
    def test_generated_output_covers_only_unicode_with_exact_metadata(self):
        master = json.loads(Path(os.environ["EMOJI_MASTER"]).read_text(encoding="utf-8"))
        version, catalogue = parse_catalogue(Path(os.environ["EMOJI_UNICODE"]).read_text(encoding="utf-8"))
        self.assertEqual(master["sources"]["unicode"]["version"], version)
        covered = []
        order = {emoji: index for index, emoji in enumerate(catalogue)}
        records = master["emojis"]
        self.assertEqual([order[row["emoji"]] for row in records], sorted(order[row["emoji"]] for row in records))
        for row in records:
            self.assertEqual(len(row["keywords"]), len(set(row["keywords"])))
            if row["tonePolicy"] == "default":
                self.assertFalse(row["skinTones"])
            children = {child["emoji"]: child for child in row["variants"]}
            self.assertLessEqual(row["skinTones"].keys(), set(TONES))
            for tone, emoji in row["skinTones"].items():
                self.assertEqual(children[emoji]["tones"], [tone])
            for entry in [row, *row["variants"]]:
                emoji = entry["emoji"]
                self.assertIn(emoji, catalogue)
                for field, value in catalogue[emoji].items():
                    self.assertEqual(entry[field], value)
                covered.append(emoji)
        self.assertEqual(set(covered), set(catalogue))
        self.assertEqual(len(covered), len(set(covered)))


if __name__ == "__main__":
    unittest.main()
