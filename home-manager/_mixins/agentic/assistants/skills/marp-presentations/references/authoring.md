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
