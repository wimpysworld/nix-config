# Typography

Modified adaptation of Impeccable's `typeset.md`. Source and licence details are in the skill's provenance.

Improve hierarchy and reading inside the established identity. Do not replace confirmed typefaces during a local correction.

## Diagnose

Identify the existing families, weights, roles, and loading strategy.
Check whether headings, body copy, labels, and metadata differ clearly without multiplying unnecessary roles.
Inspect actual font rendering and computed styles, not only CSS declarations.
Test long headings, missing weights, fallback fonts, zoom, and narrow containers.

## Apply

- Use the fewest roles and families that communicate the required hierarchy.
- Combine size, weight, spacing, and colour deliberately. Do not make size carry every distinction.
- Start ordinary body text near `1rem` and tune against the project, audience, and rendering.
- Aim for roughly 45-75 characters per prose line, with leading tuned to the face and width.
- Preserve browser zoom and user font settings.
- Keep equivalent roles consistent across pages, states, and themes.
- Load only used assets and weights, with readable fallbacks.
- Use tabular figures and code faces where the content benefits.

Treat `text-wrap: balance` and `text-wrap: pretty` as progressive enhancements, not requirements for comprehension.
Use manual heading breaks only between meaningful phrases and verify them at each affected width.
Remove redundant labels before inventing smaller type styles to accommodate them.

## Verify

Inspect wrapping, measure, loading shifts, and hierarchy at the supported widths.
Check text against its actual background in each supported theme and state.
Do not compensate for weak hierarchy with faint text that fails contrast.
