# Previews and exports

Use the existing approved local toolchain, without adding packages or contacting remote services.

## Prepare

Confirm the requested format, dimensions, background, output path, and purpose from the brief.
For print, distinguish physical dimensions and resolution from pixel dimensions.
Read the available renderer's local help before selecting export flags.
Keep font lookup and resource loading local.
Do not run supplied scripts or enable active SVG content for convenience.

Render only files that pass the source checks in the skill's SVG reference.
For a comparison page, use a static local layout without scripts or remote styles.
Keep labels, size annotations, and background swatches out of production artwork.

## Export

Use explicit output dimensions and preserve the artwork's aspect ratio.
When the requested canvas has a different ratio, add agreed padding rather than stretching the mark.
Keep transparent and opaque backgrounds distinct.
Do not replace the editable master with a raster image wrapped inside SVG.
Do not create every possible icon size or format without a requested use.

For PNG, inspect the file's actual pixel dimensions and alpha channel after export.
For SVG, check the intrinsic dimensions, units, `viewBox`, and rendered bounds separately.
For PDF, inspect the page dimensions, clipping, and font handling.
Use a suitable installed inspection tool or file parser, not the filename or export command as proof.
Compare the exported file with the selected design at the intended display size.

When a required tool is absent, keep the completed source and report the missing export step.
Do not rename another file type to imply a successful conversion.

## Handover

List the editable master and requested exports with actual dimensions and background behaviour.
Identify an outlined copy separately from the editable text master.
State which files received visual inspection and which received only source checks.
For print, report unverified colour profiles or printer requirements instead of claiming production readiness.
Do not upload, publish, or replace deployed brand assets as part of local export.
