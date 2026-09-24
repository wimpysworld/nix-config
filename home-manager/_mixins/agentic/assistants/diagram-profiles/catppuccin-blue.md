<!-- diagram-design-profile
name: Catppuccin Blue
slug: catppuccin-blue
source-url: https://catppuccin.com/palette/
created: 2026-09-13
updated: 2026-09-13
notes: Home Manager managed. Latte light and Mocha dark, Blue focal colour with bounded secondary accents.
-->
# Style Guide

## Contents

- [Tokens](#tokens)
- [Typography](#typography)
- [Geometry and node treatment](#geometry-and-node-treatment)
- [Generated output](#generated-output)
- [Terminal variant](#terminal-variant)

## Tokens

Use light unless the request explicitly selects dark. Light uses Latte. Dark uses Mocha.
Do not infer mode from the desktop, terminal, browser, time, or `prefers-color-scheme`.
Use the exact paired colours. Do not invert colours.

### Semantic roles

| Role | Purpose | Default (light) | Default (dark) |
|---|---|---|---|
| `paper` | Background and masks, Base | `@latte.base@` | `@mocha.base@` |
| `paper-2` | Secondary containers, Mantle | `@latte.mantle@` | `@mocha.mantle@` |
| `ink` | Primary text and strokes, Text | `@latte.text@` | `@mocha.text@` |
| `muted` | Secondary text and arrows, Subtext 1 | `@latte.subtext1@` | `@mocha.subtext1@` |
| `soft` | Sublabels, Subtext 0 | `@latte.subtext0@` | `@mocha.subtext0@` |
| `rule` | Decorative hairlines, Surface 0 | `@latte.surface0@` | `@mocha.surface0@` |
| `rule-solid` | Decorative borders, Surface 2 | `@latte.surface2@` | `@mocha.surface2@` |
| `accent` | One or two focal elements, Blue | `@latte.blue@` | `@mocha.blue@` |
| `accent-tint` | Blue fill over opaque paper | `rgba(30,102,245,0.08)` | `rgba(137,180,250,0.10)` |
| `link` | Links and external arrows, Blue | `@latte.blue@` | `@mocha.blue@` |
| `card` | Cards and backend nodes, Base | `@latte.base@` | `@mocha.base@` |
| `on-accent` | Large text on solid Blue, Base | `@latte.base@` | `@mocha.base@` |
| `navigation` | Section marks, Mauve / Lavender | `@latte.mauve@` | `@mocha.lavender@` |
| `comparison` | Comparison rules and large measures, Teal | `@latte.teal@` | `@mocha.teal@` |
| `structure` | Process rules and code edges, Mauve | `@latte.mauve@` | `@mocha.mauve@` |
| `decoration` | Decorative edges only, Peach | `@latte.peach@` | `@mocha.peach@` |
| `status-success` | Labelled success, Green | `@latte.green@` | `@mocha.green@` |
| `status-warning` | Labelled warning, Yellow | `@latte.yellow@` | `@mocha.yellow@` |
| `status-danger` | Labelled failure, Red | `@latte.red@` | `@mocha.red@` |

The palette follows the [Catppuccin style guide](https://github.com/catppuccin/catppuccin/blob/main/docs/style-guide.md).
Home Manager uses `lib/catppuccin-palette.json` for both flavours. Tint opacity is a local design choice.
Use `ink` or `muted` for essential boundaries and chart axes. Surface colours do not guarantee 3:1 contrast.
Check text against its actual background. Require 4.5:1 for normal text and 3:1 for essential graphical marks.
Latte `soft` and blue each fall below 4.5:1 against `paper`.
Use `ink` or `muted` when `soft` or `link` lacks contrast on any selected background, including `paper`.
In Latte, use `ink` text on `accent-tint` instead of normal text on solid blue.
Underline text links. Use labels or weight to distinguish focal arrows from links.
Interpret upstream coral references as `accent`, not orange.

Keep Blue for focal nodes, links and the key action. Keep the two-element focal limit, including any secondary focal emphasis.
Choose at most one secondary role per diagram: `navigation`, `comparison`, `structure` or `decoration`.
Use that role for incidental rules or section marks, not every heading, node or connector.
Keep node labels, captions, sources and footer text neutral. A short metadata rule can use the selected secondary role.
Quiet diagrams need no secondary accent. Green, Yellow and Red are for labelled status, never decoration or unrelated series.
In a slide, match its secondary accent. Do not add a second accent inside the diagram.

Latte Blue, Teal and Peach contrast against Base is approximately 4.34:1, 3.31:1 and 2.64:1 respectively.
Do not use these colours for small text. Add a contrasting outline when Peach identifies an essential mark.
Latte Mauve is approximately 4.79:1 on Base but 4.45:1 on Mantle. Keep small panel labels neutral.
Use the selected roles as aliases for official palette values, not replacement hues. Check overrides against each actual surface.

### Series palette

Use these colours only for charts with distinct series. Reserve blue for the focal series.

| Token | Light | Dark | Notes |
|---|---|---|---|
| `series-1` | `@latte.lavender@` | `@mocha.lavender@` | Lavender |
| `series-2` | `@latte.mauve@` | `@mocha.mauve@` | Mauve |
| `series-3` | `@latte.peach@` | `@mocha.peach@` | Peach |
| `series-4` | `@latte.teal@` | `@mocha.teal@` | Teal |
| `series-5` | `@latte.sapphire@` | `@mocha.sapphire@` | Sapphire |

Use fills at 0.18 opacity in light and 0.22 in dark. Keep outlines opaque and labels in `ink`.
Add labels, marker shapes, or dash patterns so that colour is not the only distinction.
When a series lacks 3:1 contrast, add an `ink` outline. Preserve official colours and the chart's series limit.
Series colours identify categories, not success or failure. Multiple colours are for necessary data distinctions, never decorative accents.

## Typography

| Role | Family | Size | Weight | Usage |
|---|---|---|---|---|
| `title` | Work Sans | 1.75rem | 600 | Page H1 |
| `node-name` | Work Sans | 12px | 600 | Human-readable labels |
| `sublabel` | Fira Code | 9px | 400 | Port, protocol, URL, field type |
| `eyebrow` | Fira Code | 7-8px | 500, tracked 0.18em, uppercase | Type tags, axis labels |
| `arrow-label` | Fira Code | 8px | 400, tracked 0.06em | Arrow annotations |
| `callout` | Work Sans *italic* | 14px | 400 | Editorial asides only |

Load this Google Fonts link in every generated diagram instead of the installed guide's link:

```html
<link href="https://fonts.googleapis.com/css2?family=Work+Sans:ital,wght@0,400;0,500;0,600;1,400&family=Fira+Code:wght@400;500;600&family=Noto+Sans+KR:wght@400;500;600&family=Noto+Sans+TC:wght@400;500;600&display=swap" rel="stylesheet">
```

Pair Work Sans and Fira Code with the installed Noto CJK fallback stacks and keep the Korean and Chinese label rules.
Keep CJK labels at least 12px. Use the installed Noto fallbacks and width rules.
Use Work Sans for names and Fira Code for technical content. Do not substitute JetBrains Mono.
Offline fallback fonts can change layout. Without rendered checks, report exact-font verification as untested.

## Geometry and node treatment

Preserve the installed 4px grid, 0.8/1/1.2 strokes, 4/6/8 radii, orthogonal connectors, and complexity limits.

| Type | Fill | Stroke |
|---|---|---|
| `focal` | `accent-tint` | `accent` |
| `backend` | `card` | `ink` |
| `store` | `ink @ 0.05` | `muted` |
| `external` | `ink @ 0.03` | `muted` |
| `input` | `muted @ 0.10` | `soft` |
| `optional` | `ink @ 0.02` | `muted`, dashed `4,3` |
| `security` | `accent @ 0.05` | `accent`, dashed `4,4` |

Calculate translucent fills from the selected flavour. Place an opaque local-background mask below each translucent node.
Use `card` for summary cards, `rule` for decorative borders, 6px radius, and no shadows.

## Generated output

Use templates for geometry, not colours. Replace inherited colours in CSS, inline styles, SVG fills, strokes, arrowheads, cards, dots, and masks.
CSS variables alone do not replace hard-coded SVG attributes. Masks must be opaque and match the surface below them.
Inspect the generated file for stale template colours and transparent masks before the self-check.
Resolve CSS variables to concrete values for standalone SVG exports. Do not modify installed templates or examples.

## Terminal variant

The explicit terminal variant is a separate fixed style, not Mocha mode.
Load the installed `references/primitive-terminal.md` and its template. Preserve its palette and monospace typography.
Do not apply Catppuccin replacements to terminal output. Explain that terminal output does not use the selected profile.
