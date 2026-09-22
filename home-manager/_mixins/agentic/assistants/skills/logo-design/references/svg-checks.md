# SVG checks

Inspect the source before rendering, including supplied artwork and files changed by an optimiser or export tool.

## Source safety

Prefer a static, self-contained SVG with geometry, fills, strokes, and necessary local definitions.

- Reject `DOCTYPE`, entity declarations, and external XML entities before parsing untrusted input.
- Use a local XML parser with external entity resolution and network access disabled.
- Check that the document parses and that its root is `svg` in the SVG namespace.
- Inspect elements and attributes with namespace awareness, not only a text search.
- Reject scripts, event-handler attributes such as `onload`, and `foreignObject`.
- Reject embedded HTML, executable payloads, and active content hidden in data URLs.
- Inspect `href`, `xlink:href`, CSS `url()`, `@import`, font sources, and XML processing instructions.
- Permit required fragment references only when each target resolves inside the same SVG.
- Reject remote URLs, file URLs, external resource paths, and embedded documents.
- Inspect animation elements for changes to references or attributes.
- For static logo output, omit animation rather than depending on renderer-specific restrictions.

Keep harmless namespace declarations distinct from resource URLs.
A declaration such as `xmlns="http://www.w3.org/2000/svg"` does not request a network resource.

When a supplied file fails these checks, preserve the original without opening it in a renderer.
Create a separate static replacement only within the task's edit authority.
When removal changes intended artwork, ask for a safe source or a decision on the affected element.

These checks do not make sanitisation a sandbox or prove that every renderer is safe.
Use the approved renderer's isolation and resource restrictions as well.
Do not disable restrictions to make a file render.

## Geometry and portability

Check `viewBox` numbers, positive dimensions, aspect ratio, and the intended visible bounds.
Check unique IDs and all references to gradients, masks, clips, and reusable elements.
Inspect clipping, filter extents, stroke scaling, transparency, and accumulated transforms in the rendered result.
Do not infer visual correctness from valid XML alone.

For text, verify that the renderer has the intended font and glyphs.
Check actual letter forms and spacing for fallback substitution.
Record font names and unresolved usage or distribution rights.
Do not embed or package fonts without permission.
When an outlined copy is required, compare its appearance with the editable text master.
Outlining does not establish font rights.

## Accessibility by use

Choose labels for the delivery context rather than adding the same metadata everywhere.
For informative inline SVG, use an accessible name through `aria-labelledby` and a corresponding `title`, with `role="img"` where appropriate.
Add `desc` only when further explanation helps.
Keep label IDs unique when multiple copies appear on one page.
For an HTML `img`, provide suitable `alt` text in the embedding markup.
For a linked logo, name the link's destination or action in context.
When the logo is purely decorative or repeats an adjacent accessible label, hide the duplicate from assistive technology.
Do not rely on internal SVG metadata to label every embedding method.
Report when the embedding context is unknown instead of claiming complete accessibility verification.
