# Rendered verification

This local delivery gate strengthens the adapted upstream guidance. It applies to created or changed browser pages and components.

## Inspect the actual output

1. Build or serve through the project's authorised workflow at its actual base path.
2. Open the result with available browser tools and confirm that styles, fonts, images, and required scripts load.
3. Inspect screenshots of the first viewport and the remaining page at narrow, intermediate, and wide widths.
4. Inspect both sides of relevant breakpoints and check for clipping, overlap, and unintended horizontal scrolling.
5. Repeat in every supported theme, including both light and dark when the page supports both.
6. Compare the result with the brief, established design system, primary task, and intended hierarchy.

Do not add a second theme merely to satisfy this check when the product supports only one.
Check affected states and shared components, not only the hero or the current screenshot.

## Measure contrast

Read computed foreground colours, background colours, font size, and weight from rendered elements in each supported theme.
Resolve inherited backgrounds, transparency, overlays, and state styles before calculating contrast.
For gradients and images, measure the actual background behind the text across its occupied area.
When that background cannot be measured reliably, correct the surface or report the unresolved check.

Use the Web Content Accessibility Guidelines (WCAG) AA contrast thresholds:

| Content | Minimum ratio |
| --- | --- |
| Ordinary text | 4.5:1 |
| Large text, at least 24 CSS pixels, or bold text at least 18.67 CSS pixels | 3:1 |
| Required control boundaries, state indicators, and meaningful graphics against adjacent colours | 3:1 |

Check secondary copy, navigation, links, labels, buttons, form states, and focus indicators where present.
Inspect hover, focus, active, and error states that change colours.
Record the selector, theme, state, computed colours, ratio, and applicable threshold for each failure.
Distinguish genuine WCAG exemptions, such as inactive controls, from active content styled to look disabled.
Do not claim that a palette passes when actual elements use different tokens, opacity, or backgrounds.

## Exercise the page

- Traverse the primary path with the keyboard and confirm visible focus and logical order.
- Activate links, menus, disclosure controls, forms, and theme controls that the page supplies.
- Check accessible names and semantics through the browser's accessibility view or equivalent inspection.
- Check text zoom and representative long content without losing actions or meaning.
- Check reduced-motion behaviour when motion exists.
- Inspect console errors and missing assets that affect the page.

## Close the gate

Fix failures and rerun the affected checks against the final output.
Record the target, browser, viewport sizes, themes, checked states, screenshots, contrast results, and interaction results.
Keep evidence in the task's authorised output location and reference it in the handoff.
Do not claim browser coverage that the available browser did not provide.

If tools or runtime access block verification, name the failed capability, observed error, and exact remaining checks.
Return the source work as unverified and not review-ready, with the next action needed to clear the blocker.
Do not describe missing browser checks as optional polish or claim completion from source checks.
