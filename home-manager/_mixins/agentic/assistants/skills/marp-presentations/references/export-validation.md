# Export and validation

## Contents

- [Preflight](#preflight)
- [Bundled helper](#bundled-helper)
- [Marp formats](#marp-formats)
- [Self-contained offline HTML](#self-contained-offline-html)
- [Acceptance](#acceptance)

## Preflight

Read the bundled `scripts/export.py` before use to confirm its outputs, prerequisites, and overwrite behaviour.
Resolve the script path from the skill directory.
Check the installed Marp CLI version and its help before using version-dependent options.
Use the project's declared tools. Do not install packages or download browsers without authority.

HTML and notes conversion do not require a browser.
PDF, PowerPoint, PNG, and JPEG conversion require a supported browser.
Experimental editable PowerPoint also requires LibreOffice Impress.
Report missing dependencies per format instead of claiming that every export passed.
Inspect project configuration before execution because Marp configuration can contain executable JavaScript.

## Bundled helper

Set `SKILL_ROOT` to this skill's directory and use absolute input and output paths:

```sh
python3 "$SKILL_ROOT/scripts/export.py" --input "/approved/deck/deck.md" --out "/approved/deck/exports" --trusted-local-assets
```

Use a new output directory for each run. The helper refuses an existing destination.
The helper needs Python 3, Marp CLI, Fontconfig, Work Sans, and FiraCode Nerd Font Mono.
This repository installs Marp CLI and Fontconfig for workstation developers, not developer servers.
On a server without those tools, author Markdown but report that export remains untested.
Its default requests all supported formats, including experimental editable PowerPoint.
Check the installed helper's help before using optional arguments:

- `--formats` selects formats when only a subset is needed or optional dependencies are unavailable.
- `--trusted-local-assets` permits reviewed deck-local assets and HTML wrappers used by bundled layouts. It is not permission to read unrelated files. Do not pass it for unreviewed Markdown.
- `--browser-path` selects an installed browser executable.

Do not pass Marp CLI flags to the helper or assume undocumented filenames.
Check the helper's results against the requested formats.
Use direct Marp CLI conversion for requested options that the helper does not provide.

## Marp formats

The renderer's supported formats do not establish fidelity for every template or layout combination.
Starters demonstrate selected forms, while the layout guide and specimen cover additional forms.
Record checks for the actual deck and each requested format, not inferred approval from an HTML specimen render.

Use these native Marp CLI options, not helper options.
Keep the copied theme active with `--theme /approved/deck/theme/catppuccin.css` on direct render commands.
Specify distinct output paths with `-o` to avoid replacing another export.

| Deliverable | Marp CLI options | Limits and checks |
| --- | --- | --- |
| HTML | `-o deck.html` | Default Bespoke template supports presentation controls. External assets need separate offline preparation. |
| PDF | `--pdf -o deck.pdf` | Check page count and text. Use `--pdf-notes` only when note annotations are wanted. |
| PowerPoint | `--pptx -o deck.pptx` | Slides are rendered images, not editable objects. Presenter notes are supported. |
| Editable PowerPoint | `--pptx --pptx-editable -o deck-editable.pptx` | Experimental. Requires LibreOffice Impress. Presenter notes are not supported. |
| PNG, every slide | `--images png -o deck.png` | Produces numbered files. Check that the count matches the deck. |
| JPEG, every slide | `--images jpeg -o deck.jpg` | Produces numbered files. Check compression on text and charts. |
| Cover image | `--image png -o cover.png` or `--image jpeg -o cover.jpg` | Exports only the first slide. An image extension alone also exports only the first slide. |
| Notes text | `--notes -o notes.txt` | Plain text, not rendered Markdown. Check markers, slide order, and empty slide positions. |

For example, run this from the approved project directory after inspecting the deck and its assets:

```sh
marp deck.md --theme theme/catppuccin.css --pdf --allow-local-files -o exports/deck.pdf
```

Enable `--allow-local-files` only for trusted Markdown and approved local assets.
Never enable local access for unreviewed input that can read unrelated files.
Use `--html` only when trusted source layouts require HTML.

Editable PowerPoint can lose styling, change layout, produce incomplete slides, or fail on complex CSS.
Prefer ordinary PowerPoint when appearance matters more than object editing.
Keep editable PowerPoint separate and inspect it in the recipient's application before claiming fidelity.
Deliver notes separately with editable PowerPoint.
PDF note annotations and HTML presenter notes also need checks in the intended viewer.
Marp CLI 4.4.0 with Marp Core 4.3.0 preserves literal `**` markers in `--notes` output, without bold styling.
The starter test also preserves empty slide positions between `---` separators and excludes Marp directive comments.
Repeat this check after a version change.
Do not promise that text exports or presenter views render Markdown emphasis.

## Self-contained offline HTML

A single `.html` file is not proof that a deck is self-contained.
The helper's offline HTML contains embedded CSS, including heading and syntax styles.
Marp output can still refer to local files, remote images, web fonts, imported CSS, scripts, or nested SVG resources.

1. Inspect resource references in HTML, CSS, SVG, and any embedded media.
2. Embed approved assets and licensed fonts into the generated HTML, or use an export helper that verifies this step.
3. Resolve nested CSS imports and resource URLs, including resources inside SVGs.
4. Replace online embeds with static content when offline operation cannot preserve them.
5. Keep ordinary citation links, but distinguish optional navigation from resources needed to render the deck.
6. Copy only the final HTML into a separate directory with no adjacent source assets.
7. Open that copy in a fresh browser context with network access blocked and an empty cache.
8. Check every slide, font, image, and presentation control for failed requests or missing content.

Do not call a folder-dependent deck self-contained.
Do not call a cached online render an offline test.
If presenter view fails under `file://`, report that limit separately from basic offline slide viewing.
Keep Markdown and original assets editable, even when the HTML embeds copies.
Verify embedded foreground images in split panels, visual variants, figures, and strips, not only Marp backgrounds.
The helper rejects SVGs with nested external resources rather than flattening them automatically.
Distinguish optional source links from embedded assets. A local source link does not embed or distribute its target.

## Acceptance

Inspect every rendered slide at presentation size, not only a contact sheet or the source text.
Check clipping, line breaks, hierarchy, spacing, image crops, chart labels, code, and footers.
Check both palettes when the deck uses both.
Verify page order, count, notes, and metadata in each requested format.

For headings and code:

- Check that ordinary slides show distinct Blue `h1`, Peach `h2`, and Green `h3`, including Base and Mantle split panels.
- Apply the colour pairs, contrast thresholds, and review examples in the accessibility reference.
- Check recognised language fences for visible token colours in both palettes, on full-width code slides and inside split panels.
- Check all `section pre code` blocks, not only slides with the `code` layout.
- Check that unknown, unlabelled, `text`, and `plaintext` fences retain readable neutral text.
- Inspect keywords, strings, numbers, comments, and plain text where the chosen language emits those tokens.
- Check that heading and syntax colours survive in isolated offline HTML without external stylesheets.

For split panels and image-led slides:

- Check panel bounds, text safe areas, narrow-panel wrapping, and separation between the body and local sources.
- Check reversed panels for meaningful reading order and the intended physical widths.
- Check overlay text against the actual image and scrim at 4.5:1 or stronger, including titles and credits.
- Check that overlays and scrims leave faces, chart labels, and essential image details visible.
- Check cover crops at the final dimensions and focal position. Check contained images for complete edges and legible labels.
- Compare before/after slides consecutively for stable figure bounds, crop, scale, axes, and caption height.
- Check that paired visuals use non-colour state labels and alternative text that matches each state.
- Check image-only slides for useful alternative text and a matching explanation in notes and the accompanying transcript.
- Verify every used local image in the isolated offline HTML, including nested resource checks.

Compare PDF and ordinary PPTX visually with the inspected HTML, slide by slide, in the intended viewers.
Check panel positions, overlays, crops, fonts, heading colours, syntax colours, chart labels, and sources for parity.
Ordinary PPTX preserves syntax appearance as raster images, not editable code.
Inspect experimental editable PPTX separately for layout changes, missing content, or altered syntax colours in the target application.
If a format or viewer was not tested, report that limit rather than extending HTML approval to PDF or PPTX.

For speaker notes:

- Read each script aloud. Check complete sentences, natural transitions, and an explanation beyond the slide text.
- Reject stage directions, repeated bullets, unnecessary spoken file paths, timing budgets, and source records in note comments.
- Preserve factual qualifications in speech. Check sources and timing against the deck plan or separate evidence appendix.
- Check the provisional 120-word-per-minute budget, reserved pauses, and actual rehearsal time.
- Check selective `**bold**` phrases, roughly one per sentence or every other sentence, without whole-sentence emphasis.
- Export with `--notes`. Compare each note with its source slide, including empty positions and order.
- Check emphasis in the intended HTML presenter view. Record whether phrases appear bold, plain, or with literal markers.
- For ordinary PPTX, inspect the notes for each slide in the target application, including order, content, and emphasis behaviour.
- For experimental editable PPTX, deliver a separate notes export and verify its slide mapping. Do not promise embedded presenter notes.

Record text conversion separately from viewer checks. An untested presenter view or PowerPoint application remains untested.
Revise the source and repeat conversion after a defect fix.
Record the actual command, tool versions, export paths, and passed or untested checks.

Native option reference: [Marp CLI documentation](https://github.com/marp-team/marp-cli#basic-usage).
