# Marp presentations

Create an editable Markdown deck, then verify its rendered exports against the audience and delivery needs.

## Decide and plan

1. Read the supplied brief, existing deck, and applicable project instructions.
2. Establish the purpose, audience, desired action, speaking time, venue, and required exports.
3. Ask only about missing decisions that change the content or delivery.
4. Agree on a writable output directory before file creation or rendering.
5. Preserve existing decks and exports unless replacement is authorised.
6. Write a deck plan before slides: sequence, takeaway, evidence, layout, and speaking time for each slide.

Default to 16:9 Catppuccin Latte with a blue accent. Use Mocha for an explicit dark request.
Use both palettes only when the brief needs a deliberate section contrast.
Keep Markdown as the source of truth, including when the user requests PowerPoint.

## Author

Read [authoring](references/authoring.md) before creating or revising slides.
Read [accessibility](references/accessibility.md) before choosing colour, type, or media.
Resolve bundled paths from this skill directory, not the working directory.

- Start from `assets/starters/latte.md`, `assets/starters/mocha.md`, or `assets/starters/mixed.md`.
- Choose image-led slides and full-height split panels explicitly when the content needs them, not only text-led starter forms.
- Read the [layout guide](assets/layouts.md) for selection rules, copyable markup, and content limits. Use its actual classes.
- Use `assets/theme/catppuccin.css`, whose theme id is `catppuccin-slides`.
- Use `assets/specimen.md` to check theme coverage, not as the narrative for a finished deck.
- Copy required resources into the approved project directory. Never modify the installed skill.
- Keep each slide focused on one takeaway. Write a concise spoken script for each slide, not slide text or delivery instructions.
- Follow the speaker-note contract in [authoring](references/authoring.md), including selective bold phrases and separate timing and evidence records.
- Load `communication-rules` and `writing-well` for notes. Load `contribution-voice` for its cut pass only, not public-post budgets or format restrictions.

## Render, inspect, revise

Read [export and validation](references/export-validation.md) before rendering.
Use `scripts/export.py` with `--input` and `--out` as that reference describes.
For reviewed layouts from the starters or layout guide, pass `--trusted-local-assets` to render their HTML wrappers and local images.
Do not use that flag for unreviewed Markdown or assets.
Do not assume that a successful conversion proves visual quality, offline operation, accessibility, or editable PowerPoint fidelity.

Inspect every slide in the rendered deck, including notes and each palette used.
Fix overflow, weak hierarchy, illegible labels, missing assets, and unexpected font substitution in the source.
Render again after each revision and check every requested output.
When inspection tools are unavailable, name the untested checks rather than claiming visual approval.

## Deliver

Return the Markdown, theme, required assets, and requested exports with their paths.
State which outputs passed rendering, visual inspection, and offline checks separately.
Disclose experimental editable PPTX limits, notes behaviour, missing dependencies, and any untested target application.
Include the exact export command and the next action for unresolved checks.
