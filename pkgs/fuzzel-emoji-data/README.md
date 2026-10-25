# Fuzzel emoji data

The package installs an immutable catalogue at `share/fuzzel-emoji/master.json`.
Unicode supplies every accepted sequence, name, group, subgroup, version, and display order.
Only fully-qualified entries enter the catalogue. Components and alternate qualification forms do not enter it.

## Contract

`schemaVersion` is `2`. This version requires build-generated presentation fields. `sources` records URLs, checksums, versions, licences, and annotation sources.
`emojis` contains one record per base emoji, in Unicode order.

| Field | Meaning |
| --- | --- |
| `id` | Exact code points in uppercase hexadecimal, joined by hyphens. Variation selectors remain present. |
| `emoji` | Default sequence, including the yellow form where applicable. |
| `name` | Exact Unicode name. |
| `displayName` | Unicode name with one leading prefix matching `^[A-Za-z]+:\s*` removed, followed by the presentation cleanup below. |
| `keywords` | Merged source phrases after overrides, phrase deduplication, case folding, and conversion of `_` and whitespace to ordinary spaces. Presentation cleanup leaves these phrases unchanged. |
| `searchKeywords` | Build-generated source enrichment words, deduplicated against normalised `displayName` and earlier words. Group and subgroup values are never appended. |
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

## Presentation and search

Presentation cleanup applies only to `displayName` and `searchKeywords`, before comparison and deduplication.
It converts curly single quotes U+2018/U+2019 to ASCII apostrophes and curly double quotes U+201C/U+201D to ASCII double quotes.
It converts en dashes U+2013 and em dashes U+2014 to ASCII hyphens, including the dash in scores such as `5-0`.
Alphabetic word tokens lose trailing colons. These words can contain internal apostrophes or hyphens.
For example, `walking:` and `walking` become one word, as do `heart:` and `heart`.
Internal colons, times such as `12:30`, emoticons such as `:D` and `:)`, and symbols such as `+1` remain intact.
Accents remain intact, and existing ASCII aliases remain distinct. The generator does not apply accent folding, transliteration, or Unicode NFKC normalisation.
Official names, merged source keywords, provenance, and emoji sequences remain unchanged.

The generator compares words with case folding and conservative boundary punctuation removal.
It trims Unicode bracket and quotation categories `Ps`, `Pe`, `Pi`, and `Pf`, plus `. , ; ! ? ' " … 、 。 ， ； ！ ？`.
It keeps internal punctuation, other symbols, and tokens with no letters or numbers, including emoticons.
Different forms such as `ticket` and `tickets` stay distinct.
The first occurrence keeps its cleaned spelling and position. Display text keeps its case, spacing, and repeated words after presentation cleanup.
Control characters become spaces before enrichment words are split.
Search enrichment excludes tokens whose comparison key is exactly `143`. Other numbers and tokens that contain `143` remain eligible.
Merged source `keywords` retain `143` for provenance. This exclusion does not change official names or display names.

Deduplication uses `displayName`, not the official `name`.
The display regex `^[A-Za-z]+:\s*` removes one leading ASCII alphabetic word, its colon, and any following whitespace.
It accepts `flag:`, `man:`, `woman:`, `person:`, and arbitrary words such as `Foo:`, with or without separator whitespace.
The prefix rule does not match internal colons, multiword prefixes, or prefixes with digits.
The separate trailing-colon cleanup still applies to alphabetic word tokens.
Before deduplication, the generator replaces the same prefix pattern in each enrichment phrase with the prefix word and a space.
Removed display prefixes remain searchable even when source annotations omit them or overrides remove the official name from `keywords`.
Deduplication retains each prefix word once across the description and search words, without colon tags.
The original `keywords` retain their merged phrases, including any prefixes.
The generator never appends or splits group and subgroup values for search.
Words such as `Activities` and `face` remain eligible when source keywords supply them.
The separate `group` and `subgroup` fields remain unchanged for browsing.

The runtime selects the tone, builds menu rows, and caches the projection.
Labels use the selected glyph and `displayName`. Search text joins that label and `searchKeywords` without word cleanup.
The runtime still replaces control characters to protect menu row boundaries.
Schema version 2 and projection version 5 invalidate earlier caches.
Presentation cleanup does not change either format version. A regenerated catalogue has a new store path, which invalidates its projection cache.

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
The tests check qualification, exact metadata, ordering, complete coverage, source keyword merges, presentation cleanup, explicit tone mappings, and rejection of invalid inputs.
The picker build runs its non-graphical tests through `emoji.nix` `postCheck`, including field consumption and cache invalidation.
No desktop process runs during generation or testing.

Run `just build-pkg fuzzel-emoji-data`.
