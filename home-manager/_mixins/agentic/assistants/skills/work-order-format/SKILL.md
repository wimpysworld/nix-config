
# Work Order Format

The contract for the one cycle work order document. `work-order-create` writes the document, `work-order-update` patches it, and both follow this contract exactly.

## Title and parent

Title the document `<user first name>'s Cycle <n> work order`. Parent the document on the cycle: `save_document` takes `cycle` set to the number and `team` set to disambiguate it.

## Section order

1. The wave sections, in wave number order.
2. `## Sequencing`.
3. `## Timing` - omit when empty.
4. `## Impact` - optional, see [Impact](#impact).
5. `## Deferred` - omit when empty.

## Waves

Heading form: `## Wave <n> ⇉ <dependency line>`. The dependency line is one of:

- `starts immediately`
- `needs Wave <a>` - list every prerequisite wave.

When the wave is independent of another unfinished wave, append `, runs parallel with Wave <m>`. For example: `## Wave 3 ⇉ needs Wave 1, runs parallel with Wave 2`.

The waves are strictly parallel. Every issue in a wave runs in parallel with every other issue in that wave:

- No sequencing prose inside a bullet. A sequential dependency forces the issue into a later wave.
- Issue-level constraints live under `## Sequencing`.
- Two issues that edit the same package or files never share a wave.

## Issue bullets

```markdown
* [<issue key>](https://linear.app/<workspace>/issue/<issue key>) <issue title> - <size on the `sizing` scale>. <One-line reason it is in this wave.>
```

Write every issue key as a markdown link, in a bullet and in `## Sequencing` and `## Timing` prose. The commands write the document through the Linear API, which stores a plain key as plain text, so a plain key is not clickable. Linear adds an automatic status indicator only to a key typed in the editor, so the document tracks no completion state of its own.

## Impact

Include the section only when an evidence review measured the issues. Never stub it, estimate, or rate an issue without evidence. An issue with no measurement gets no bullet, and a deferred issue keeps none.

Open with one line that names the evidence date and the data window. Then add one bullet per measured issue, in wave order:

```markdown
* [<issue key>](https://linear.app/<workspace>/issue/<issue key>) - <rating>. <Measured evidence in one or two sentences, with the figure and its denominator.>
```

Ratings:

- `High` - a measured, direct effect on the outcome the work order targets.
- `Medium` - a measured, partial effect on that outcome.
- `Low` - a measured effect that is small or off that outcome.
- `Enabling` - no direct effect, but other ordered work or measurement depends on it.

## Deferred entries

```markdown
* [<issue key>](https://linear.app/<workspace>/issue/<issue key>) - <date> - <one-line reason it was deferred>
```

## Stable numbering

Never renumber an existing wave. When a wave empties, remove its section and never reuse its number. A new wave takes the next unused number and appends at the end.
