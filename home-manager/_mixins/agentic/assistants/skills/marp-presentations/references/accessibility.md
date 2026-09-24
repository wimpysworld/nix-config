# Accessibility

## Colour and type

Check the actual foreground and background pair, including text over images and tinted panels.
Use at least 4.5:1 contrast for normal text and 3:1 for large text.
Large text means at least 18 pt, or 14 pt bold, under WCAG definitions.
For image overlays, require at least 4.5:1 for all text, including large titles, against the actual image and scrim.
Check every text area after each change to the image, crop, text position, palette, or scrim opacity.
Aim for stronger contrast and larger type for projected slides.
Use at least 3:1 contrast for essential chart marks and interface indicators against adjacent colours.

Treat Catppuccin colours as palette choices, not proof of accessible contrast.
Check Latte and Mocha separately, especially blue labels and text on blue fills.
Use the theme's contrasting text roles instead of assuming that white text works on every accent.
Pair colour with labels, line styles, shapes, or position.
Do not use red and green alone to explain outcomes.

Check type at the intended viewing distance, not only in a zoomed editor.
Avoid dense paragraphs, tiny footnotes, and long code lines.
Keep heading levels and reading order meaningful in the Markdown source.

## Images and media

Give each informative image useful alternative text.
Describe a chart's conclusion, axes, units, and important values in nearby text or an accompanying transcript.
Label chart comparisons with words such as Before and After, not colour alone.
Keep state labels outside the plotted data and use consistent axes and units.
For image-only slides, require meaningful alternative text and a transcript that explains the image's meaning and conclusion.
Use a foreground image for informative media, not only a decorative background.
Avoid essential information that exists only in a background image.
Provide captions and a transcript for speech in media.
Avoid autoplay, flashing effects, and motion that is necessary to understand a slide.
Use a static fallback for offline and printed exports.

## Delivery checks

Test HTML keyboard navigation, visible focus, and presenter controls.
Check zoom and a representative screen-reader reading order where tools are available.
Do not equate HTML semantics with an accessible exported PDF or PowerPoint file.
Ordinary Marp PowerPoint slides are images, which limits text selection, reading order, and alternative text.
PNG and JPEG exports also need accompanying text for non-visual access.
Experimental editable PowerPoint does not guarantee useful semantics or reading order.

Keep an accessible text alternative with the Markdown and notes when the exported format loses structure.
If tagged PDF or formal accessibility compliance is required, validate the actual output with suitable tools.
Report unsupported requirements and untested assistive technology explicitly.
Do not claim WCAG or PDF/UA compliance from contrast checks alone.

Contrast criteria: [WCAG 2.2](https://www.w3.org/TR/WCAG22/), sections 1.4.3 and 1.4.11.
