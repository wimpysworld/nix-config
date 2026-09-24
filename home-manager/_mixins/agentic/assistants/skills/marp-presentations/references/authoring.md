# Authoring

## Narrative and layout

Make the opening explain why the audience needs the talk.
Order evidence so that each slide supports the next decision.
End with a specific action, decision, or retained lesson.
Budget time for questions and transitions instead of deriving duration from slide count alone.

Choose layouts for the content, not for decoration.
Read the bundled `assets/layouts.md` from the skill root for the supported syntax.

| Content | Layout intent | Check |
| --- | --- | --- |
| Opening or section change | Title with one clear promise | The audience knows the subject and stakes |
| One conclusion | Statement with supporting evidence | The title states the conclusion |
| Two alternatives | Parallel comparison | Both sides use the same criteria |
| Process or system | Diagram with a short explanation | Labels and reading order remain clear |
| Quantitative evidence | Chart or key number | Units, baseline, date, and source are visible |
| Demonstration | Screenshot or short code sample | The relevant detail is legible at presentation size |
| Closing | Decision or next action | The owner and action are explicit where known |

Vary layouts when the content changes. Keep repeated content types visually consistent.
Remove detail or split the slide before reducing type size.
Use diagrams as editable assets where possible, with a static fallback for each export.

## Markdown source

Copy the chosen starter and inspect its frontmatter before editing.
Keep `marp: true` and `theme: catppuccin-slides` in the deck frontmatter.
Set title, author, description, and language metadata where supported by the installed Marp version.
Separate slides with `---`.

Use local directives for slide-specific changes, so that styles do not affect later slides unexpectedly.
For example, `<!-- _paginate: false -->` hides pagination only on the current slide.
Copy palette and layout class syntax from the starter and layout guide.
Preserve both the palette class and layout class when assigning slide classes.
Do not override the theme's blue accent with unrelated colours.

Use Markdown headings, lists, images, tables, and fenced code blocks before custom HTML.
If a layout requires HTML, inspect the markup and enable HTML only for trusted deck content.
Keep essential content out of CSS pseudo-elements and decorative backgrounds.

## Speaker notes

Write speaker notes as ordinary HTML comments on the relevant slide:

```markdown
# Recommend the smaller pilot

Test the change with one team before wider adoption.

<!--
Explain the pilot's success criteria and name the decision needed today.
Allow two minutes for questions.
-->
```

Keep Marp directive comments separate from notes.
Include transitions, timing, pronunciation, and evidence that the speaker needs but the audience does not need on screen.
Do not put secrets in notes. Exported HTML and PowerPoint can expose notes to recipients.
Keep a separate notes text export when notes are a deliverable.

## Assets and fonts

Store deck assets beside the Markdown with stable relative paths.
Record image provenance, licences, attribution, and any authorised edits.
Crop deliberately without removing context that changes the meaning.
Use descriptive alternative text for meaningful images and a written explanation for complex charts.

Prefer local assets over remote images, web fonts, embeds, or live charts.
Do not download or embed restricted resources without permission.
For an offline deck, replace live content with an approved static representation.

Use an available font with an explicit fallback stack.
For identical offline typography, embed a licensed font and verify that the font loads from the exported HTML.
System fonts avoid network requests but do not guarantee identical metrics on another computer.
Check code glyphs, mathematical symbols, and non-Latin text in the actual renderer.
Keep font licences with distributed font files.
