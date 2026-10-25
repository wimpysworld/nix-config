# Fuzzel emoji data

The package installs an immutable catalogue at `share/fuzzel-emoji/master.json`.
Unicode supplies every accepted sequence, name, group, subgroup, version, and display order.
Only fully-qualified entries enter the catalogue. Components and alternate qualification forms do not enter it.

## Contract

`schemaVersion` is `1`. `sources` records URLs, checksums, versions, licences, and annotation sources.
`emojis` contains one record per base emoji, in Unicode order.

| Field | Meaning |
| --- | --- |
| `id` | Exact code points in uppercase hexadecimal, joined by hyphens. Variation selectors remain present. |
| `emoji` | Default sequence, including the yellow form where applicable. |
| `name` | Exact Unicode name. |
| `keywords` | Deduplicated, case-folded search phrases. The generator changes `_` and whitespace to ordinary spaces. |
| `group`, `subgroup` | Exact Unicode group and subgroup names. |
| `emojiVersion` | Unicode emoji version as a string, without the `E` prefix. |
| `skinTones` | Available single-person mappings: `light`, `medium-light`, `medium`, `medium-dark`, and `dark`. |
| `tonePolicy` | `default` prohibits tone selection. `single` permits available named mappings. |
| `variants` | Tone variants in Unicode order, with exact sequence metadata and a `tones` array. |

The runtime must use `emoji` for yellow/default or an unavailable tone.
Multi-person records have `tonePolicy: "default"` and an empty `skinTones` object.
Their combinations remain in `variants`, not in standalone picker rows.
Each variant has `id`, `emoji`, `name`, `group`, `subgroup`, `emojiVersion`, and `tones`.
The `tones` array lists modifiers in sequence order, including repeated tones.
The same default-only policy applies to handshake and family records.

Emojibase supplies explicit base-to-variant relationships. The generator never creates relationships by removing modifiers or variation selectors.
It validates each accepted variant against Unicode and checks that tone metadata matches the sequence.
Unaccepted annotation entries do not enter the output. Missing coverage, ambiguous mappings, and duplicate sequences fail the build.

## Keywords and licences

Emojibase supplies English annotations from CLDR (Common Locale Data Repository) 49 beta 1.
Emojilib adds legacy search synonyms. Neither source can replace Unicode names or add accepted sequences.

`keyword-overrides.json` preserves the useful differences from the former embedded script:
`fish` for both whales, `shrek` for troll, and removal of `whale2`.
The comparison used emojilib 4.0.0, the source of the old catalogue.
Other differences were whitespace changes or removals that emojilib 4.0.3 already contains.
The generator normalises whitespace without a duplicate catalogue.

`sources.json` pins each download and records its role.
`licenses/` contains both upstream MIT notices and the Unicode licence.
`schema.json` documents the machine-readable contract.

## Validation

The package runs Python standard-library boundary tests in `checkPhase`.
The tests check qualification, exact metadata, ordering, complete coverage, keyword merges, explicit tone mappings, and rejection of invalid inputs.
No desktop process runs during generation or testing.

Run `just build-pkg fuzzel-emoji-data`.
