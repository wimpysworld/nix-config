# Crisp rendering

Use this reference when you create an Ebitengine application, or change layout, text, UI, image scaling, or final presentation.
Also use it to diagnose blurry rendering. It applies to pixel-art games with sharp UI, and they do not need a low-resolution game screen.
All reference paths are relative to the skill root.

## Contents

- [The principle](#the-principle)
- [Give the screen enough pixels](#give-the-screen-enough-pixels)
- [Choose where each layer is rendered](#choose-where-each-layer-is-rendered)
- [Rasterise text at its displayed size](#rasterise-text-at-its-displayed-size)
- [Choose sampling and placement deliberately](#choose-sampling-and-placement-deliberately)
- [Keep input consistent and verify](#keep-input-consistent-and-verify)
- [Sources](#sources)

## The principle

Render detail at the resolution where it is displayed.
Trace the complete path from assets and glyph rasterisation, through intermediate images, to the display.
A low-resolution stage anywhere in that path discards detail, and later scaling cannot recover it.
High-DPI support is one part of this, together with sampling and transforms.

Keep intentional pixel art and the requested presentation.
Sharp rendering does not mean that you disable antialiasing or force nearest-neighbour filtering on every image.

## Give the screen enough pixels

`LayoutF` receives outside dimensions in device-independent pixels (DIP), and it returns logical screen dimensions.
The image that `Draw` receives uses those logical dimensions, rounded up.
An implementation of `LayoutF` alone does not give high resolution.
For display-resolution rendering, return the outside dimensions times `ebiten.Monitor().DeviceScaleFactor()`.

Adapt this pattern to the existing game. It uses `math` and `ebiten`:

```go
type Game struct {
	displayScale float64
	screenWidth  float64
	screenHeight float64
}

func (g *Game) Layout(outsideWidth, outsideHeight int) (int, int) {
	panic("Layout is not called when LayoutF is implemented")
}

func (g *Game) LayoutF(outsideWidth, outsideHeight float64) (float64, float64) {
	g.displayScale = ebiten.Monitor().DeviceScaleFactor()
	g.screenWidth = math.Max(1, outsideWidth*g.displayScale)
	g.screenHeight = math.Max(1, outsideHeight*g.displayScale)
	return g.screenWidth, g.screenHeight
}
```

`ebiten.Game` still requires `Layout`.
Keep the floating-point dimensions for transforms. When you need the real image bounds, use `screen.Bounds()`.

The image that `Draw` receives is the intermediate game screen of Ebitengine. The engine then presents it to the final display.
When that image matches the display resolution, the final step does not enlarge a game screen of lower resolution.

Read the device scale during layout, so that the game can follow a supported change of display scale.
Do not cache the scale only at startup.
When you want native-resolution rendering, do not enable the browser-specific `RunGameOptions.DisableHiDPI`.

## Choose where each layer is rendered

- **Display-resolution scene and UI.** Draw directly into the high-resolution screen.
  Transform world or DIP coordinates into screen coordinates, and rasterise scalable content at that resolution.
  No extra game offscreen is necessary.
- **Fixed design coordinates with sharp rendering.** Keep the simulation and the layout in design units, but transform geometry into the high-resolution screen.
  Fixed coordinates do not require a raster image of fixed resolution.
- **Intentional pixel art, or a layer with its own size.** Render that layer into a reusable offscreen at the resolution that you choose.
  Composite it to the high-resolution screen, then draw sharp UI and text at screen resolution.
  This architecture is optional. Not every game needs it.

For an aspect-preserving fit from design or layer dimensions `(w, h)` into logical screen dimensions `(W, H)`, use `s = min(W/w, H/h)`.
Use the offsets `((W-w*s)/2, (H-h*s)/2)`. Scale first, then translate.
Choose integer scaling, cropping, or stretching only when the intended presentation needs it. Fill the letterbox areas as necessary.

Reuse offscreens. Make them again only when their necessary resolution changes.
Clear them each frame, unless you keep their content on purpose.
Effects and cached UI also need an explicit resolution policy.
If you render a whole UI to a small texture and enlarge it, you lose the benefit of the high-resolution screen.

## Rasterise text at its displayed size

With `text/v2.GoTextFace`, set `Size` in destination pixels, and reuse the `GoTextFaceSource`.
For UI sized in DIP, multiply the font size, the positions, and the line spacing by the display scale.
For text sized in design units, use the design-to-screen scale of the viewport instead.
When that viewport scale already includes the device scale, do not multiply by the device scale again.

For example, with a loaded `fontSource`, and `text/v2` imported as `text`:

```go
face := &text.GoTextFace{
	Source: fontSource,
	Size:   20 * g.displayScale,
}
var op text.DrawOptions
op.GeoM.Translate(16*g.displayScale, 16*g.displayScale)
op.LineSpacing = 24 * g.displayScale
text.Draw(screen, "Score: 100", face, &op)
```

Do not also scale these glyphs by `g.displayScale` through `GeoM`.
A geometry transform enlarges rasterised glyphs. It does not request new glyph detail.
For the same reason, an enlarged bitmap debug font does not become a high-resolution vector font.
Use bitmap fonts where you want their pixelated appearance.

A `GoTextFace.Size` that changes continuously makes glyph images at many sizes.
For an animated zoom, think about rendering at a suitable larger size and scaling down, as the godoc of the face suggests.
This is a trade-off between quality and cache. It is not a reason to rasterise all static UI at a small size.

## Choose sampling and placement deliberately

- `FilterNearest` keeps hard texel boundaries. Integer magnification and aligned placement suit exact pixel art.
  Fractional magnification can give pixels of different widths, or shimmer.
- `FilterPixelated` keeps a pixelated appearance at non-integer scales. Use it for pixelated layers when you want that presentation.
  It cannot recover source detail that is missing, and it does not make downsampling lossless.
- `FilterLinear` suits smooth imagery and resampling, but an enlarged small source can look soft. First supply enough source resolution.
  Linear minification can use mipmaps. Do not disable mipmaps everywhere to get sharpness, because that causes aliasing.

Do not downscale and upscale again and again through intermediate textures.
Examine the final presentation transform, and also the options of each `DrawImage`.
Use `FinalScreenDrawer` only when you need custom final sampling. The legacy `SetScreenFilterEnabled` switch is deprecated.
In Ebitengine at the pinned revision, the screen filter is enabled by default.
With the filter enabled, `DefaultDrawFinalScreen` chooses nearest for integer scales, linear for minification, and pixelated for other magnification.
When you disable the legacy screen filter, Ebitengine uses nearest at every scale.

Check placement in destination pixels. Pixel art and thin axis-aligned features can need deliberate alignment there.
Rounding design coordinates before you scale them does not guarantee alignment.
Do not snap all motion or all text to pixels. Subpixel placement and antialiasing can be intentional.
A filter change cannot repair a rasterisation stage of low resolution.

## Keep input consistent and verify

Ebitengine cursor and touch positions already use logical screen coordinates. Do not multiply them by the device scale again.
For UI defined in DIP, divide by the display scale.
For design or game coordinates, invert the viewport transform: `x = (screenX-offsetX)/s`, `y = (screenY-offsetY)/s`.
Include any additional camera transforms, and reject letterbox hits where that is correct.
Calculate the mapping from the current layout state in `Update`. Do not depend on an earlier `Draw`.
If a custom `FinalScreenDrawer` changes the supplied presentation transform, include that change in the input mapping too.
The input conversion of the engine uses its default presentation transform.

Check standard and high-density displays, fractional scaling, resizing, aspect ratio changes, and monitor changes where the platform supports them.
Examine the output at its real display size, because an enlarged preview can add its own blur.
Verify the intended UI size, glyph detail, pixel-art presentation, thin edges, and hit targets.
If you cannot test a display environment, state that limit.

Compile application changes against the target Ebitengine version, especially before you use `FilterPixelated` or other newer APIs.
If performance needs effects or game layers at lower resolution, keep the resolution policy explicit.

## Sources

Use the godoc and source of the target version for API and platform behaviour. These links are pinned to the upstream revision.

- [Display scaling guide](https://github.com/tinne26/etxt/blob/main/docs/display-scaling.md):
  UI sizing and game-relative text scaling. Its renderer examples use `etxt`.
- [Layout and presentation contracts](https://github.com/hajimehoshi/ebiten/blob/345100b0e4b75ed7e06d2a1cd84571814a5e6140/run.go): `LayoutFer`,
  `FinalScreenDrawer`, and `RunGameOptions`.
- [Final presentation](https://github.com/hajimehoshi/ebiten/blob/345100b0e4b75ed7e06d2a1cd84571814a5e6140/gameforui.go): `DefaultDrawFinalScreen`.
- [Filters](https://github.com/hajimehoshi/ebiten/blob/345100b0e4b75ed7e06d2a1cd84571814a5e6140/graphics.go) and [image options](https://github.com/hajimehoshi/ebiten/blob/345100b0e4b75ed7e06d2a1cd84571814a5e6140/image.go).
- [Text face sizing](https://github.com/hajimehoshi/ebiten/blob/345100b0e4b75ed7e06d2a1cd84571814a5e6140/text/v2/gotext.go) and [text drawing](https://github.com/hajimehoshi/ebiten/blob/345100b0e4b75ed7e06d2a1cd84571814a5e6140/text/v2/layout.go).
- [Input coordinates](https://github.com/hajimehoshi/ebiten/blob/345100b0e4b75ed7e06d2a1cd84571814a5e6140/input.go) and [high-DPI example](https://github.com/hajimehoshi/ebiten/blob/345100b0e4b75ed7e06d2a1cd84571814a5e6140/examples/highdpi/main.go).
