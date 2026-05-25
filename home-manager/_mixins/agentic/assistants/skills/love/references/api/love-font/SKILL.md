---
name: love-font
description: Allows you to work with fonts. Use this skill when working with font operations, text display, text formatting, or any font-related operations in LÖVE games.
license: MIT
metadata:
  author: Ron Dekker <rondekker.nl>
---

## When to use this skill
Allows you to work with fonts. Use this skill when working with font operations, text display, text formatting, or any font-related operations in LÖVE games.

## Common use cases
- Loading and managing font files
- Rendering text with different styles and sizes
- Working with text formatting and layout
- Handling international text and Unicode characters
- Implementing custom text rendering effects

## Functions

- `love.font.newBMFontRasterizer` - Creates a new BMFont Rasterizer.
  - `love.font.newBMFontRasterizer(imageData: ImageData, glyphs: string, dpiscale: number) -> rasterizer: Rasterizer`: No description
  - `love.font.newBMFontRasterizer(fileName: string, glyphs: string, dpiscale: number) -> rasterizer: Rasterizer`: No description
- `love.font.newGlyphData(rasterizer: Rasterizer, glyph: number)`: Creates a new GlyphData.
- `love.font.newImageRasterizer(imageData: ImageData, glyphs: string, extraSpacing: number, dpiscale: number) -> rasterizer: Rasterizer`: Creates a new Image Rasterizer.
- `love.font.newRasterizer` - Creates a new Rasterizer.
  - `love.font.newRasterizer(filename: string) -> rasterizer: Rasterizer`: No description
  - `love.font.newRasterizer(data: FileData) -> rasterizer: Rasterizer`: No description
  - `love.font.newRasterizer(size: number, hinting: HintingMode, dpiscale: number) -> rasterizer: Rasterizer`: Create a TrueTypeRasterizer with the default font.
  - `love.font.newRasterizer(fileName: string, size: number, hinting: HintingMode, dpiscale: number) -> rasterizer: Rasterizer`: Create a TrueTypeRasterizer with custom font.
  - `love.font.newRasterizer(fileData: FileData, size: number, hinting: HintingMode, dpiscale: number) -> rasterizer: Rasterizer`: Create a TrueTypeRasterizer with custom font.
  - `love.font.newRasterizer(imageData: ImageData, glyphs: string, dpiscale: number) -> rasterizer: Rasterizer`: Creates a new BMFont Rasterizer.
  - `love.font.newRasterizer(fileName: string, glyphs: string, dpiscale: number) -> rasterizer: Rasterizer`: Creates a new BMFont Rasterizer.
- `love.font.newTrueTypeRasterizer` - Creates a new TrueType Rasterizer.
  - `love.font.newTrueTypeRasterizer(size: number, hinting: HintingMode, dpiscale: number) -> rasterizer: Rasterizer`: Create a TrueTypeRasterizer with the default font.
  - `love.font.newTrueTypeRasterizer(fileName: string, size: number, hinting: HintingMode, dpiscale: number) -> rasterizer: Rasterizer`: Create a TrueTypeRasterizer with custom font.
  - `love.font.newTrueTypeRasterizer(fileData: FileData, size: number, hinting: HintingMode, dpiscale: number) -> rasterizer: Rasterizer`: Create a TrueTypeRasterizer with custom font.

## Types

- `GlyphData`: A GlyphData represents a drawable symbol of a font Rasterizer.
  - `love.GlyphData.getAdvance() -> advance: number`: Gets glyph advance.
  - `love.GlyphData.getBearing() -> bx: number, by: number`: Gets glyph bearing.
  - `love.GlyphData.getBoundingBox() -> x: number, y: number, width: number, height: number`: Gets glyph bounding box.
  - `love.GlyphData.getDimensions() -> width: number, height: number`: Gets glyph dimensions.
  - `love.GlyphData.getFormat() -> format: PixelFormat`: Gets glyph pixel format.
  - `love.GlyphData.getGlyph() -> glyph: number`: Gets glyph number.
  - `love.GlyphData.getGlyphString() -> glyph: string`: Gets glyph string.
  - `love.GlyphData.getHeight() -> height: number`: Gets glyph height.
  - `love.GlyphData.getWidth() -> width: number`: Gets glyph width.

- `Rasterizer`: A Rasterizer handles font rendering, containing the font data (image or TrueType font) and drawable glyphs.
  - `love.Rasterizer.getAdvance() -> advance: number`: Gets font advance.
  - `love.Rasterizer.getAscent() -> height: number`: Gets ascent height.
  - `love.Rasterizer.getDescent() -> height: number`: Gets descent height.
  - `love.Rasterizer.getGlyphCount() -> count: number`: Gets number of glyphs in font.
  - `love.Rasterizer.getGlyphData(glyph: string) -> glyphData: GlyphData`: Gets glyph data of a specified glyph.
  - `love.Rasterizer.getHeight() -> height: number`: Gets font height.
  - `love.Rasterizer.getLineHeight() -> height: number`: Gets line height of a font.
  - `love.Rasterizer.hasGlyphs(glyph1: string or number, ...: string or number) -> hasGlyphs: boolean`: Checks if font contains specified glyphs.

## Enums

- `HintingMode`: True Type hinting mode.
  - `normal`: Default hinting. Should be preferred for typical antialiased fonts.
  - `light`: Results in fuzzier text but can sometimes preserve the original glyph shapes of the text better than normal hinting.
  - `mono`: Results in aliased / unsmoothed text with either full opacity or completely transparent pixels. Should be used when antialiasing is not desired for the font.
  - `none`: Disables hinting for the font. Results in fuzzier text.

## Examples

### Loading and using fonts
```lua
-- Load a font file
local font = love.graphics.newFont("arial.ttf", 24)

-- Set as default font
love.graphics.setFont(font)

-- Draw text
love.graphics.print("Hello World!", 100, 100)
```

### Text formatting
```lua
-- Create fonts with different styles
local titleFont = love.graphics.newFont(36)
local bodyFont = love.graphics.newFont(18)
local boldFont = love.graphics.newFont("bold.ttf", 20)

function love.draw()
  love.graphics.setFont(titleFont)
  love.graphics.print("Game Title", 100, 50)

  love.graphics.setFont(bodyFont)
  love.graphics.printf("This is a paragraph of text that will be wrapped to fit within the specified width.", 100, 150, 400, "left")

  love.graphics.setFont(boldFont)
  love.graphics.print("Important Message!", 100, 300)
end
```

## Best practices
- Load fonts during initialization to avoid runtime delays
- Use appropriate font sizes for different screen resolutions
- Consider memory usage when loading multiple fonts
- Handle font loading errors gracefully
- Test text rendering on target platforms

## Platform compatibility
- **Desktop (Windows, macOS, Linux)**: Full font support
- **Mobile (iOS, Android)**: Full support with some font limitations
- **Web**: Good support but some fonts may not be available
