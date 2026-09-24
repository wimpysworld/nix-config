# Accessibility

## Colour and type

Check the actual foreground and background pair, including text over images and tinted panels.
Use at least 4.5:1 contrast for normal text and 3:1 for large text.
Large text means at least 18 pt, or 14 pt bold, under WCAG definitions.
For image overlays, require at least 4.5:1 for all text, including large titles, against the actual image and scrim.
Check every text area after each change to the image, crop, text position, palette, or scrim opacity.
Aim for stronger contrast and larger type for projected slides.
Use at least 3:1 contrast for essential chart marks and interface indicators against adjacent colours.

Treat Catppuccin colours as palette choices, not proof of accessible contrast.
Check Latte and Mocha separately, especially blue labels and text on blue fills.

| Heading role | Latte | Mocha |
| --- | --- | --- |
| `h1` Blue | `#1e66f5` | `#89b4fa` |
| `h2` Peach | Derived dark Peach `#b24608` | `#fab387` |
| `h3` Green | Derived dark Green `#235818` | `#a6e3a1` |

These heading roles meet 3:1 on their palette's Base and Mantle backgrounds at large-heading sizes.
Do not reuse Latte Blue for small text. Its large-heading contrast does not meet the 4.5:1 requirement for normal text.
Keep the raw palette values separate from derived heading colours.
Structural accents use other colour families, not Blue, Peach, or Green.

| Structural role | Latte | Mocha |
| --- | --- | --- |
| Yellow navigation | Derived `#865511` | `#f9e2af` |
| Pink general structure | Derived `#984d84` | `#f5c2e7` |
| Mauve technical boundaries | `#8839ef` | `#cba6f7` |
| Teal comparison rules | `#179299` | `#94e2d5` |

Yellow and Pink meet at least 5.59:1 and 4.98:1 respectively on Base across both palettes.
Keep the Latte derivatives for small navigation text and pagination. Raw Yellow and Pink are not substitutes.
Check small text at 4.5:1 and meaning-carrying non-text marks at 3:1 against their actual backgrounds.
Check both adjacent colours for boundaries, including code borders against the dark panel.
Purely decorative marks carry no essential information, but must still avoid heading colour families.
Keep labelled status and chart data roles separate from structural roles, even where they share a colour family.
Check every code token colour against its actual dark code panel at 4.5:1 or stronger, including comments and neutral fallback text.
Do not exempt code because a token is bold or coloured.
Use the theme's contrasting text roles instead of assuming that white text works on every accent.
Pair colour with labels, line styles, shapes, or position.
Do not use red and green alone to explain outcomes.

Check type at the intended viewing distance, not only in a zoomed editor.
Avoid dense paragraphs, tiny footnotes, and long code lines.
Keep heading levels and reading order meaningful in the Markdown source.

## Contrast review examples

| Case | Review |
| --- | --- |
| Latte ordinary and split slides | Check all three heading roles on Base and Mantle at 3:1. Keep small Blue labels neutral. |
| Mocha ordinary and split slides | Check the same heading hierarchy on both backgrounds. Check code tokens and comments against the code panel at 4.5:1. |
| Paired Latte/Mocha agenda and section slides | Compare agenda numbers and section eyebrows beside their Blue headings. Require visible Yellow separation in both palettes, not contrast alone. |
| Navigation and structural marks | Check small pagination at 4.5:1. Check meaning-carrying rules, arrows and focus outlines at 3:1 against adjacent colours. |
| Latte code slide | Check the dark code panel, not the surrounding light slide, for every token and the plain fallback at 4.5:1. |
| Full-bleed image in either palette | Keep copy neutral. Check each text area against the final crop and scrim at 4.5:1, including headings. |

Record the actual colour pair, minimum ratio, and any failed check for each reviewed case.

## Images and media

Give each informative image useful alternative text.
Describe a chart's conclusion, axes, units, and important values in nearby text or an accompanying transcript.
Label chart comparisons with words such as Before and After, not colour alone.
Keep state labels outside the plotted data and use consistent axes and units.
For image-only slides, require meaningful alternative text and a transcript that explains the image's meaning and conclusion.
Use a foreground image for informative media, not only a decorative background.
Avoid essential information that exists only in a background image.
Provide captions and a transcript for speech in media.
Avoid autoplay, flashing effects, and motion that is necessary to understand a slide.
Use a static fallback for offline and printed exports.

## Delivery checks

Test HTML keyboard navigation, visible focus, and presenter controls.
Check zoom and a representative screen-reader reading order where tools are available.
Do not equate HTML semantics with an accessible exported PDF or PowerPoint file.
Ordinary Marp PowerPoint slides are images, which limits text selection, reading order, and alternative text.
PNG and JPEG exports also need accompanying text for non-visual access.
Experimental editable PowerPoint does not guarantee useful semantics or reading order.

Keep an accessible text alternative with the Markdown and notes when the exported format loses structure.
If tagged PDF or formal accessibility compliance is required, validate the actual output with suitable tools.
Report unsupported requirements and untested assistive technology explicitly.
Do not claim WCAG or PDF/UA compliance from contrast checks alone.

Contrast criteria: [WCAG 2.2](https://www.w3.org/TR/WCAG22/), sections 1.4.3 and 1.4.11.
