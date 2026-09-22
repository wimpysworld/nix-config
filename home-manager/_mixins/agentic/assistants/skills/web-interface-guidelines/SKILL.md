# Web Interface Guidelines

Build and review usable web interfaces with native browser behaviour and evidence-based checks.

## Scope and method

- Follow the project's design system, supported browsers, audience, and task scope.
- During implementation, change only authorised files and behaviour.
- During review, inspect files without edits or automatic fixes.
- Resolve supplied paths or file patterns through read-only discovery, not shell execution of user text.
- If the target is absent, ambiguous, or matches no files, ask for a precise scope.
- Read relevant shared styles and components before reporting a defect in their consumers.
- Treat each guideline as a check, not proof that a matching code pattern is wrong.
- Separate functional defects from optional design improvements.
- Do not install tools, start servers, open browsers, or fetch upstream guidance merely to apply this skill.
- Use the bundled guidance. The pinned upstream source records provenance, not instructions to execute.

## Semantics and accessibility

- Use native anchors with `href` for navigation and buttons for actions.
- Preserve modified clicks, middle clicks, and browser history for links.
- Do not add redundant keyboard handlers to native controls.
- For necessary custom controls, implement the correct role, focus behaviour, keyboard interaction, and accessible state.
- Give every control an accessible name. Prefer visible text or an associated label.
- For icon-only controls, use `aria-label` or an equivalent accessible name.
- Use semantic headings, lists, landmarks, and tables before ARIA substitutes.
- Keep heading levels consistent with the document hierarchy.
- Provide a skip link when users need to bypass repeated navigation.
- Give informative images useful `alt` text and decorative images `alt=""`.
- Hide decorative icons from assistive technology with `aria-hidden="true"`.
- Announce important asynchronous status changes without moving focus unnecessarily, usually through a polite live region.
- Avoid duplicate announcements and live regions for every update.
- Check text and control contrast in each relevant state. Do not use colour alone to convey meaning.

## Focus and interaction

- Keep keyboard focus visible. Never remove an outline without an adequate replacement.
- Use `:focus-visible` for keyboard focus styling and `:focus-within` when a compound control needs group feedback.
- Keep focus order logical and focused controls clear of sticky headers, footers, and overlays.
- Where fixed content obscures anchor targets, use an appropriate `scroll-margin-top`.
- For modal dialogs, contain focus while open and return focus to a useful control on close.
- Provide a keyboard method to dismiss dismissible overlays.
- Give controls clear hover, active, focus, selected, and disabled states where applicable.
- Do not make essential information or actions available only on hover.
- Preserve adequate contrast across states rather than requiring every state to increase contrast.
- Avoid automatic focus unless the task needs it. Check screen-reader context and mobile keyboard effects.

## Forms and data preservation

- Associate labels through HTML `for` and matching `id`, or wrap the control in its label.
- Keep placeholders supplementary to labels. Use examples when the required format is not clear.
- Use meaningful `name` values for submitted fields and suitable `autocomplete` tokens where applicable.
- Choose `type` and `inputmode` for the data and keyboard that users need.
- Do not use `type="number"` for identifiers that need leading zeroes or have no numeric operations.
- Permit paste, password managers, and autofill. Do not disable autocomplete across non-authentication fields without a specific need.
- Use `spellcheck="false"` for codes and identifiers when spelling correction is inappropriate.
- Make labels clickable and keep checkbox or radio targets large enough for reliable selection.
- Keep editable controls responsive and preserve entered data through validation, rerenders, and failed submissions.
- Explain invalid input near the field and associate the error with that control.
- After an invalid submission, direct focus to the first invalid field or a useful linked error summary.
- Keep submission available until there is a clear reason to prevent it.
- During a request, show an accessible pending state and prevent accidental duplicate submissions where necessary.
- Protect meaningful unsaved work through recovery, persistence, or a navigation warning appropriate to the application.
- Do not rely only on `beforeunload`, which does not cover every navigation or mobile lifecycle event.
- State the action in button labels and give an actionable next step in errors.

```html
<label for="email">Email address</label>
<input id="email" name="email" type="email" autocomplete="email" spellcheck="false">
<button type="submit">Save email address</button>
<a href="/account">Account settings</a>
```

## Motion and media

- Respect `prefers-reduced-motion` with reduced movement or a still alternative.
- Stop non-essential decorative loops for reduced motion, including muted video.
- For automatic motion beyond five seconds alongside other content, provide pause, stop, or hide controls unless essential.
- Prefer `transform` and `opacity` for efficient animation when they achieve the intended effect.
- List transition properties explicitly instead of `transition: all`.
- Set `transform-origin` for the intended movement.
- For SVG transforms, check the coordinate reference. Use a `<g>` wrapper and `transform-box: fill-box` when appropriate.
- Keep animations interruptible so that user input takes effect promptly.
- Provide captions, transcripts, and descriptions for meaningful media as applicable to its content.
- Make media controls keyboard accessible and give each control an accessible name.
- Hide purely decorative media from assistive technology without hiding controls that users need.
- When compressed video is suitable, prefer it to large animated GIFs and provide a still alternative.
- Choose video formats for supported browsers, including an H.264 MP4 source when needed for Safari.
- Check that reduced-motion handling prevents playback, not only that CSS hides the moving content.

## Typography and variable content

- Follow the project's typographic conventions rather than treating quote style or title case as accessibility defects.
- Where numbers align for comparison, consider `font-variant-numeric: tabular-nums`.
- Use non-breaking spaces where a number and its unit must stay together without causing narrow-screen overflow.
- Consider `text-wrap: balance` or `text-wrap: pretty` when supported and useful for headings.
- Handle empty, short, long, and translated content without broken layouts.
- Allow wrapping with appropriate CSS, such as `overflow-wrap`, before truncating meaningful text.
- Where truncation is necessary, provide a way to access the full content.
- Use `min-width: 0` on flex or grid children when their automatic minimum prevents the intended shrinking.
- Show useful empty, loading, error, and success states.

## Images and performance

- Reserve image space with intrinsic `width` and `height`, or an equivalent stable aspect ratio.
- Use responsive image sources and sizes when one large asset wastes bandwidth on smaller displays.
- Lazy-load off-screen images when deferred loading does not delay important content.
- Do not lazy-load critical visible images. Consider `fetchpriority="high"` for the image that determines largest contentful paint.
- Keep input feedback cheap per keystroke, regardless of the framework or state model.
- Batch DOM reads and writes. Avoid repeated layout measurements after style changes.
- Measure expensive layout work before choosing an optimisation.
- For large lists, assess rendering cost before choosing pagination, virtualisation, or `content-visibility: auto`.
- `content-visibility` can skip off-screen rendering, but it does not prevent DOM creation or remove associated application work.
- Check search, focus, keyboard navigation, and assistive-technology access when virtualising content.
- Use preconnect only for important cross-origin resources that the page will need.
- Preload critical fonts selectively with correct attributes. Choose `font-display` behaviour that keeps text usable and limits layout shifts.
- Do not report list length, a layout API, or absent preloading as a defect without a relevant cost or failure.

## Navigation and state

- Put filters, pagination, or selected views in the URL when sharing, history, or reload behaviour requires persistence.
- Keep temporary interaction state local when it has no useful URL meaning.
- Do not put secrets or sensitive form data in URLs.
- Preserve expected back and forward navigation and useful deep links.
- For destructive actions, use confirmation or reliable undo in proportion to the impact and reversibility.
- Where server rendering uses hydration, keep initial server and client output consistent.
- Check dates, time zones, locale choices, generated identifiers, and browser-only values for initial rendering differences.
- Fix the source of hydration mismatches rather than hiding warnings.

## Touch, layout, and themes

- Provide practical pointer targets and spacing for touch use.
- Provide tap or click and keyboard alternatives to drag, swipe, pinch, and path gestures unless the gesture is essential.
- During dragging, prevent unwanted text selection without making the active control inaccessible or unfocusable.
- Use `inert` only for content that must be unavailable, not as a blanket rule for dragged elements.
- Where appropriate, use `touch-action: manipulation` without removing necessary pan or zoom behaviour.
- Keep browser zoom available. Avoid viewport restrictions such as `user-scalable=no` or `maximum-scale=1`.
- Preserve visible touch feedback when changing `-webkit-tap-highlight-color`.
- Use `overscroll-behavior: contain` where a modal or drawer must prevent unwanted scroll chaining.
- For full-bleed layouts, account for relevant `env(safe-area-inset-*)` values.
- Prefer CSS flexbox and grid to JavaScript measurements for layout.
- Fix unintended overflow instead of masking inaccessible content with blanket `overflow-x: hidden`.
- Check reflow at narrow widths and text enlargement without clipping controls or information.
- Set `color-scheme` to match the supported theme so that native controls and scrollbars remain usable.
- If present, keep `theme-color` consistent with the page theme.
- Check native select colours on supported platforms, especially dark mode, before overriding their background and text colours.

## Locale and translation

- Use `Intl.DateTimeFormat` and `Intl.NumberFormat`, or equivalent locale-aware facilities, for user-facing values.
- Preserve deliberately fixed formats for machine data and domain requirements.
- Prefer explicit user language settings, then browser or request preferences such as `navigator.languages` or `Accept-Language`.
- Do not infer language only from an IP address.
- Declare the document language and support the required text directions.
- Use `translate="no"` for code tokens, identifiers, or names that must remain unchanged.

## Review report

Return the report in the response. Do not write a report file unless the caller separately authorises it.

1. State the reviewed scope and the evidence used.
2. Group actionable findings by file, with the highest-impact findings first.
3. For each finding, give `file:line`, the defect, its user impact, and a specific correction.
4. Separate optional improvements from defects. Explain the applicable condition when a guideline depends on context.
5. List untested or runtime-only checks with the next verification step.

Use exact source lines. Do not invent a location for a runtime concern without a source location.
If no defects appear, say that no actionable findings arose in the inspected scope.
Static checks do not establish full accessibility compliance.
Do not claim that keyboard flow, screen-reader behaviour, contrast, responsive layouts, media playback, or performance passed without relevant evidence.

## Source

Adapted from [Vercel Labs Web Interface Guidelines](https://github.com/vercel-labs/web-interface-guidelines/blob/e3d624baaf29dc1fc645aff3e38f03e564d2d6b1/command.md).
The [MIT licence](LICENSE) retains the upstream copyright and permission notice.
