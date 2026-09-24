# Authoring

## Contents

- [Narrative and layout](#narrative-and-layout)
- [Split panels and image-led slides](#split-panels-and-image-led-slides)
- [Figures and supporting media](#figures-and-supporting-media)
- [Markdown source](#markdown-source)
- [Speaker notes](#speaker-notes)
- [Assets and fonts](#assets-and-fonts)

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
Preserve the presenter's voice and the Catppuccin colour roles when adapting a reusable slide form.
Do not copy reference talks' wording, artwork, or colours without separate authority.

## Split panels and image-led slides

Use inset `two-column` content when two related groups need a shared heading, gutter, and ordinary slide metadata.
Use full-height `split` when two panels need independent headings, alignment, or an image beside text.
Keep exactly two panels and follow the layout guide's safe areas and limits.
Use the narrow panel for a short title or image, not dense content.
When panels change position, check both the crop and source reading order.

Split slides hide global headers, footers, and pagination.
Put optional local source labels or links in `panel-source` below the associated content, within the two-line limit.
Put credits for an image-only `panel-cover` in the text panel or evidence record.
Keep required visible citations on the slide, even when other source details stay in the evidence record.

Prefer the original `visual` caption when the image is busy or the explanation needs a solid background.
Use a visual overlay for a short opening or statement when quiet image space leaves the subject visible.
Place text within the documented safe area, clear of faces, chart labels, and essential image details.
Use the optional scrim only when it preserves essential detail and gives sufficient text contrast.
If the scrim conceals evidence, choose `split` instead.
Never place text over a `panel-cover` image.

Use `visual-image` for an image-only slide when the visual itself supports the takeaway.
Use its foreground image element, not decorative Marp background syntax, for meaningful media.
Give the image useful alternative text and explain its meaning in the spoken notes and accompanying transcript.
If attribution must be visible, choose a caption or split rather than an image-only form.
Copy exact markup from the layout guide and inspect the specimen for examples in both palettes.

## Figures and supporting media

Compose these tools within existing layouts, not a new family for each content type.

| Need | Tool | Authoring rule |
| --- | --- | --- |
| Heading above a chart, diagram, or screenshot | `media-figure` | Use one heading line, a contained figure, and one caption line. |
| Before/after across consecutive slides | `figure-pair` on both slides | Keep fixed bounds, image dimensions, crop, scale, axes, and caption line count identical. |
| Short list with aligned icons | `icon-list` and `list-icon` | Use three or four short rows whose words carry the meaning without icons. |
| Supporting gallery or portraits | Optional `media-strip` | Use three images, preserve faces, and keep essential evidence readable outside thumbnails. |

Treat charts and diagrams as meaningful content, not decoration.
Give each useful alternative text and a nearby conclusion in the heading, caption, or adjacent text.
Keep units, baseline, state labels, and sources explicit.
For paired visuals, update each image's alternative text and label its state outside the data.
Contain charts, diagrams, logos, and screenshots so that all essential edges and labels remain visible.
Use cover crops only for photographs whose subject and context survive the crop.

## Markdown source

Copy the chosen starter and inspect its frontmatter before editing.
Keep `marp: true` and `theme: catppuccin-slides` in the deck frontmatter.
Set title, author, description, and language metadata where supported by the installed Marp version.
Separate slides with `---`.

Use local directives for slide-specific changes, so that styles do not affect later slides unexpectedly.
For example, `<!-- _paginate: false -->` hides pagination only on the current slide.
Copy palette and layout class syntax from the starter and layout guide.
Preserve both the palette class and layout class when assigning slide classes.
Keep Blue as the brand anchor. Use at most one secondary accent from the theme's layout roles on a slide.

Use Markdown headings, lists, images, tables, and fenced code blocks before custom HTML.
If a layout requires HTML, inspect the markup and enable HTML only for trusted deck content.
Keep essential content out of CSS pseudo-elements and decorative backgrounds.

## Speaker notes

Write the words that the presenter will say as ordinary HTML comments on the relevant slide.
Use complete, sayable sentences that add an explanation, example, or meaning beyond the visible bullets.
Do not repeat the slide text as a script.
Use natural spoken transitions, not stage directions such as "Point out" or "Transition:".
Omit file paths unless the audience needs to hear them.

Use selective `**bold**` phrases to help the presenter scan the script, roughly one per sentence or every other sentence.
Emphasise key phrases, not whole sentences or labels.
Keep the script understandable without rendered emphasis.
Text exports can retain literal Markdown markers instead of bold styling.

Apply the Communication Rules and `writing-well`.
Use `contribution-voice` for its cut pass and plain brevity only.
Do not apply its public-post budgets or no-bold-label format rule to private speaker notes.
Cut repetition and unnecessary examples without removing qualifications that change the claim.

```markdown
# Recommend the smaller pilot

Test the change with one team before wider adoption.

<!--
A **small pilot** lets us test the change without asking every team to adopt it.
We need to agree what success means before we start.
Then we can use the result to decide whether to **continue, revise, or stop**.
-->
```

Keep Marp directive comments separate from notes.
Keep timing budgets, pronunciation guidance, and evidence or source records in the deck plan or a separate evidence appendix.
Retain necessary factual qualifications in the speech, including sample limits and illustrative rather than measured results.
Keep required visible citations on slides, but do not read source records aloud unless the audience needs them.
Use a provisional rate of **120 spoken words per minute**, with pauses, questions, and transitions reserved in the plan.
Count the spoken words without Markdown markers, then rehearse and adjust the budget to the presenter.
Do not fill the entire slot with uninterrupted speech.
Do not put secrets in notes. Exported HTML and PowerPoint can expose notes to recipients.
Keep a separate notes text export when notes are a deliverable.

## Assets and fonts

Store deck assets beside the Markdown with stable relative paths.
When copying layout examples, copy each used file from `assets/images/` into the deck's `images/` directory.
Copy `assets/theme/catppuccin.css` into the deck's `theme/` directory for direct Marp commands.
Check every relative path from the copied deck, not from the skill directory.
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
