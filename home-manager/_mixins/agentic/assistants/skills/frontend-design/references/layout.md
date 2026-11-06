# Layout

Modified adaptation of Impeccable's `layout.md`. Source and licence details are in the skill's provenance.

Layout communicates reading order, grouping, and task priority. Preserve the established visual system while correcting structure.

## Diagnose

Inspect the rendered page before changing spacing.
At reduced detail, identify the primary element, secondary element, and major groups in order.
Check whether containers compensate for weak proximity or unclear content relationships.
Compare density with task frequency and decision complexity.
Check whether repeated cards hold genuinely equivalent content.

Name the intended reading path, groups, spacing rhythm, and responsive changes before editing.
Choose the simplest structure that expresses those relationships.

## Apply

- Group by meaning and separate distinct groups clearly.
- Use the project's spacing scale rather than unrelated local values.
- Keep repeated roles consistent while allowing different priorities to have different weight.
- Prefer `gap` when it expresses spacing between siblings directly.
- Reflow or collapse content according to importance, without hiding essential tasks.
- Keep visual, document, and focus order consistent.
- Correct optical alignment after inspecting the render.

Repetition supports recognition. Variation needs a content or task reason.

## Verify

Inspect narrow, intermediate, and wide layouts, plus both sides of changed breakpoints.
Check long text, empty content, sticky elements, overlays, zoom, and horizontal overflow.
Confirm that the primary task remains clear and that touch targets remain usable.
Check keyboard traversal against the visible reading order.
Record the viewport and element for each defect instead of declaring that the layout looks correct.
