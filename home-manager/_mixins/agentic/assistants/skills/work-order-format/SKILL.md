---
name: work-order-format
description: "Use when creating or updating a cycle work order document in Linear. Defines the document title and parent, the wave headings with dependency lines, the strict-parallel rule, the issue bullet and deferred entry forms, and stable wave numbering. Use whenever a command writes or patches a work order."
---

# Work Order Format

The contract for the one cycle work order document. `work-order-create` writes the document, `work-order-update` patches it, and both follow this contract exactly.

## Title and parent

Title the document `<user first name>'s Cycle <n> work order`. Parent the document on the cycle: `save_document` takes `cycle` set to the number and `team` set to disambiguate it.

## Section order

1. The wave sections, in wave number order.
2. `## Sequencing`.
3. `## Timing` - omit when empty.
4. `## Deferred` - omit when empty.

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
* <issue key> <issue title> - <size on the `sizing` scale>. <One-line reason it is in this wave.>
```

Write the issue key plain. Linear renders a plain key as a rich link with an automatic status indicator, so the document tracks no completion state of its own.

## Deferred entries

```markdown
* <issue key> - <date> - <one-line reason it was deferred>
```

## Stable numbering

Never renumber an existing wave. When a wave empties, remove its section and never reuse its number. A new wave takes the next unused number and appends at the end.
