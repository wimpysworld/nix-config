# Frontend Design

Build intentional browser interfaces whose content, hierarchy, and visual character serve the user's task.

Adapted from Anthropic's pinned `frontend-design` skill, with selected Impeccable guidance. This is a modified work, not an upstream copy.
See [provenance and local changes](references/provenance.md) for source mapping and licences.

## Establish the direction

1. Read the brief, project instructions, existing pages, design tokens, components, and assets.
2. Identify the audience, subject, primary task, and evidence that the page must communicate.
3. Preserve the existing brand, framework, design system, and working behaviour unless the user authorises their replacement.
4. Resolve only missing decisions that materially change the result. Do not reopen settled choices.
5. Load `web-interface-guidelines` for browser implementation and accessibility requirements.
6. For a new page or redesign, read [new work](references/new-work.md).

Choose a compact direction before coding: colour roles, type roles, reading order, primary action, and one characteristic visual decision.
Use existing tokens where the project supplies them. For a new system, name the small palette and type scale explicitly.
Check that each choice follows the subject and brief, not a habitual template.
An explicit brief takes precedence over aesthetic preferences in this skill.

## Compose with restraint

- Put the most useful, characteristic content first: a clear statement, image, demonstration, or task surface.
- Make the primary action and reading order clear before adding decoration.
- Give each heading, label, border, card, and accent a distinct information job.
- Remove labels and subheadings that repeat adjacent content without helping navigation or comprehension.
- Group related content through proximity before adding containers. Use numbering only when order has meaning.
- Concentrate visual emphasis. Keep supporting content quieter without reducing its readability.
- Use repetition for equivalent content, not to force unlike content into identical cards.
- Preserve a brand's chosen fonts and palette. No typeface, colour scheme, or layout is banned by default.
- Use motion to explain changes or direct attention. Respect reduced motion and keep content available without animation.
- For structural changes, read [layout](references/layout.md). For type changes, read [typography](references/typeset.md).

Typography carries hierarchy and character. Use the fewest families and roles that clearly distinguish the content.
Keep ordinary prose below 80 characters per line, then tune measure and leading against the rendered face.
Use labels, capitals, accent words, and decorative rules only where their information role or brand context justifies them.

Write from the visitor's perspective. Name actions by their result and keep that name consistent through the flow.
Use verified product facts. Mark demonstration data as synthetic and never invent claims, testimonials, or adoption figures.
Make errors explain recovery and empty states explain the next useful action.

## Build and inspect

Use the project's existing implementation and validation paths. Check selector conflicts, asset loading, and the deployed base path.
For a critique, read [critique](references/critique.md). Before delivery, read [polish](references/polish.md).
Judge the rendered hierarchy before reading automated findings. Then combine visual and mechanical evidence.
Fix causes at the narrowest correct level without replacing the design identity during polish.

## Rendered-page delivery gate

For a created or changed page, complete [rendered verification](references/verification.md) before presenting it as complete or review-ready.
This gate requires browser inspection, computed contrast, responsive checks, and keyboard interaction on the actual output.
Source inspection, build success, palette arithmetic, and screenshots alone do not satisfy the gate.

If browser verification is unavailable, finish independent source work and report the precise blocker and remaining checks.
Label the result unverified and not review-ready. Do not transfer unfinished verification to the user as a completed delivery.
Do not install tools, dispatch agents, or activate configuration merely because this skill names a check.

Pure advice, concept discussion, and source-only reviews do not require a running page.
State their evidence limits without claiming rendered quality. When those tasks produce a page, the delivery gate applies.

Report changed sources, the design decision, verification evidence, fixes, and any remaining blocker.
For skill maintenance, use the [trigger scenarios](references/evaluations.md).
