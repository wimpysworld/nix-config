"""Boundary tests run in the fuzzel-emoji-data package checkPhase."""

import copy
import json
import os
import re
import unittest
from pathlib import Path

from generate import (
    TONES,
    codepoint_id,
    enrichment_words,
    generate,
    parse_catalogue,
    presentation_text,
    word_key,
)


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

    def test_unwanted_search_token_preserves_numbers_and_source_metadata(self):
        before = self.build()
        self.annotations[0]["tags"] += ["143", "hello 143 bye", "(143)"]
        inputs = copy.deepcopy((self.catalogue, self.annotations))
        after = self.build()
        self.assertEqual((self.catalogue, self.annotations), inputs)
        self.assertIn("143", after[0]["keywords"])
        self.assertIn("hello 143 bye", after[0]["keywords"])
        for original, filtered in zip(before, after, strict=True):
            self.assertEqual(
                {key: value for key, value in original.items() if key != "keywords"},
                {key: value for key, value in filtered.items() if key != "keywords"},
            )
        self.assertEqual(
            enrichment_words("", ["143 100 +1 -1 12:30 5-0 1143 1430 x143 143x +143 143-2", "(143)"]),
            ["100", "+1", "-1", "12:30", "5-0", "1143", "1430", "x143", "143x", "+143", "143-2"],
        )
        self.catalogue["👋"]["name"] = "143 waving hand"
        named = self.build()[0]
        self.assertEqual(named["name"], "143 waving hand")
        self.assertEqual(named["displayName"], "143 waving hand")

    def test_display_prefixes_and_search_preserve_source_metadata(self):
        cases = [
            ("flag: United Kingdom", "United Kingdom", "flag"),
            ("man: red hair", "red hair", "man"),
            ("woman: red hair", "red hair", "woman"),
            ("person: red hair", "red hair", "person"),
            ("Foo:  Mixed  CASE!", "Mixed  CASE!", "foo"),
            ("Flag:Example", "Example", "flag"),
            ("person:\t red hair", "red hair", "person"),
            ("Foo: bar: Detail", "bar Detail", "foo"),
            ("black flag", "black flag", None),
            ("red hair: detail", "red hair detail", None),
            ("two words: Detail", "two words Detail", None),
            ("foo2: Detail", "foo2: Detail", None),
            ("2foo: Detail", "2foo: Detail", None),
            ("éclair: Detail", "éclair Detail", None),
            (" Foo: Detail", " Foo Detail", None),
        ]
        for name, display_name, prefix in cases:
            for tags in ([], [prefix, prefix.upper(), f"{prefix} {prefix}"] if prefix else []):
                with self.subTest(name=name, tags=tags):
                    _, catalogue = parse_catalogue(unicode_text([("🏴", "fully-qualified", name)]))
                    catalogue["🏴"]["name"] = name
                    annotations = [{"emoji": "🏴", "label": name, "tags": tags}]
                    before = copy.deepcopy((catalogue, annotations))
                    row = generate(catalogue, annotations, {}, {})[0]
                    self.assertEqual((catalogue, annotations), before)
                    for field, value in catalogue["🏴"].items():
                        self.assertEqual(row[field], value)
                    self.assertEqual(row["displayName"], display_name)
                    self.assertEqual(
                        row["keywords"],
                        list(dict.fromkeys([" ".join(name.split()).casefold(), *[tag.casefold() for tag in tags]])),
                    )
                    if prefix:
                        self.assertEqual(row["searchKeywords"].count(prefix), 1)
                        self.assertNotIn(f"{prefix}:", row["searchKeywords"])

    def test_enrichment_prefixes_without_synonyms_and_overridden_names(self):
        self.catalogue["👋"]["name"] = "person: red hair"
        self.annotations[0].update(label="alternate", tags=[
            "man: red hair", "woman:blue eyes", "Foo: extra", "foo FOO",
            "internal colon: detail", "two words: detail", "foo2: detail", ":D +1",
        ])
        row = generate(self.catalogue, self.annotations, {}, {
            "👋": {"remove": ["person: red hair"]},
        })[0]
        self.assertEqual(row["displayName"], "red hair")
        self.assertNotIn("person: red hair", row["keywords"])
        self.assertIn("woman:blue eyes", row["keywords"])
        self.assertEqual(row["searchKeywords"], [
            "alternate", "man", "woman", "blue", "eyes", "foo", "extra",
            "internal", "colon", "detail", "two", "words", "foo2:", ":d", "+1",
            "person",
        ])

    def test_word_comparison_preserves_symbols_and_internal_punctuation(self):
        cases = {
            "“TiCkEt,”": "ticket",
            "【TICKET】": "ticket",
            "ticket！": "ticket",
            "Straße": "strasse",
            "ticket…": "ticket",
            "'ticket;'": "ticket",
            ":D": ":d",
            "+1": "+1",
            "1": "1",
            ":-)": ":-)",
            ":)": ":)",
            "!!!": "!!!",
            "&": "&",
            "-1": "-1",
            "ticket:": "ticket",
            "hand-fingers-open": "hand-fingers-open",
            "can't": "can't",
        }
        for word, expected in cases.items():
            with self.subTest(word=word):
                self.assertEqual(word_key(word), expected)
        self.assertEqual(
            enrichment_words("D 1", [":D +1 :) :-) !!! &", ":d +1 :) &"]),
            [":D", "+1", ":)", ":-)", "!!!", "&"],
        )

    def test_enrichment_preserves_description_variants_and_first_occurrences(self):
        self.catalogue["👋"].update(
            name="Admission  tickets (Tickets)",
            group="Tickets & Entertainment",
            subgroup="event entrance event",
        )
        self.annotations[0].update(
            label="“ADMISSION,” ticket tickets",
            tags=["entrance ticket", "Entrance ENTERTAINMENT entertainment", "【tickets】"],
        )
        row = generate(self.catalogue, self.annotations, {}, {})[0]
        self.assertEqual(row["displayName"], "Admission  tickets (Tickets)")
        self.assertEqual(row["searchKeywords"], ["ticket", "entrance", "entertainment"])
        self.assertIn("entrance ticket", row["keywords"])
        self.assertIn("entrance entertainment entertainment", row["keywords"])
        self.assertEqual(row["group"], "Tickets & Entertainment")
        self.assertEqual(row["subgroup"], "event entrance event")
        self.assertEqual(
            enrichment_words("admission tickets", ["admission ticket tickets entrance ticket"]),
            ["ticket", "entrance"],
        )
        self.assertEqual(
            enrichment_words("ticket", ["“Entrance,” entrance TICKETS tickets"]),
            ['"Entrance,"', "TICKETS"],
        )
        self.assertEqual(enrichment_words("ticket", ["hello\u0000there hello\u2028ticket"]), ["hello", "there"])

    def test_presentation_quotes_dashes_and_accents_preserve_source_fields(self):
        name = "person: C\u00f4te d\u2019Ivoire \u201cquoted\u201d 5\u20130"
        label = "Cote d'Ivoire \u2018hello\u2019 \u201cnew\u201d end\u2014to\u2014end"
        tags = ["d\u2018Ivoire", '"new" new', "end-to-end", "caf\u00e9 cafe", "\uff21 \ufb01"]
        self.catalogue["👋"]["name"] = name
        self.annotations[0].update(label=label, tags=tags)
        before = copy.deepcopy((self.catalogue, self.annotations))
        row = generate(self.catalogue, self.annotations, {}, {})[0]
        self.assertEqual((self.catalogue, self.annotations), before)
        for field, value in self.catalogue["👋"].items():
            self.assertEqual(row[field], value)
        self.assertEqual(row["keywords"], [name.casefold(), label.casefold(), *[tag.casefold() for tag in tags]])
        self.assertEqual(row["displayName"], 'C\u00f4te d\'Ivoire "quoted" 5-0')
        self.assertEqual(row["searchKeywords"], [
            "person", "cote", "'hello'", '"new"', "end-to-end", "caf\u00e9", "cafe", "\uff41", "fi",
        ])
        self.assertEqual(presentation_text("\uff21 \ufb01"), "\uff21 \ufb01")
        self.assertEqual(enrichment_words("", ["caf\u00e9 cafe", "CAFE CAF\u00c9"]), ["caf\u00e9", "cafe"])

    def test_trailing_word_colons_preserve_internal_colons_and_symbols(self):
        self.assertEqual(
            presentation_text("walking: heart:: caf\u00e9: can't: red-haired: 12:30 a:b foo2: :D :) :-) +1 ..."),
            "walking heart caf\u00e9 can't red-haired 12:30 a:b foo2: :D :) :-) +1 ...",
        )
        self.assertEqual(
            enrichment_words("walking: d'Ivoire 5-0", [
                "walking heart: heart", "d\u2019Ivoire 5\u20130", "heart::",
                "12:30 a:b :D :) :-) +1 ...",
            ]),
            ["heart", "12:30", "a:b", ":D", ":)", ":-)", "+1", "..."],
        )

    def test_categories_are_not_injected_or_removed_from_source_keywords(self):
        self.catalogue["👋"].update(group="Activities", subgroup="face-smiling")
        self.annotations[0].update(label="waving hand", tags=[])
        without_categories = generate(self.catalogue, self.annotations, {}, {})[0]
        self.assertEqual(without_categories["searchKeywords"], [])
        self.annotations[0]["tags"] = ["Activities", "face-smiling", "face"]
        with_categories = generate(self.catalogue, self.annotations, {}, {})[0]
        self.assertEqual(with_categories["searchKeywords"], ["activities", "face-smiling", "face"])
        for row in (without_categories, with_categories):
            self.assertEqual(row["group"], "Activities")
            self.assertEqual(row["subgroup"], "face-smiling")

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
            self.assertEqual(row["displayName"], presentation_text(re.sub(r"^[A-Za-z]+:\s*", "", row["name"])))
            keys = [word_key(word) for word in row["searchKeywords"]]
            self.assertNotIn("143", keys)
            self.assertEqual(len(keys), len(set(keys)))
            self.assertTrue(set(keys).isdisjoint(word_key(word) for word in row["displayName"].split()))
            fields = row["keywords"]
            prefix = re.match(r"^([A-Za-z]+):\s*", row["name"])
            if prefix:
                word = prefix.group(1).casefold()
                self.assertEqual(keys.count(word), 1)
                self.assertNotIn(f"{word}:", keys)
                fields = [*fields, word]
            self.assertEqual(
                row["searchKeywords"],
                enrichment_words(row["displayName"], fields),
            )
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
