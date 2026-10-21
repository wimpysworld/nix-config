# Kage shaders

Write, review, debug, and port Kage shaders for Ebitengine.
This covers `//kage:unit pixels`, `ebiten.NewShader`, `DrawTrianglesShader`, `DrawRectShader`, and the `Fragment(dstPos vec4, src0Pos vec2, color vec4) vec4` entry point.
All reference paths are relative to the skill root.

## Contents

- [Overview](#overview)
- [Non-negotiables](#non-negotiables)
- [The coordinate model](#the-coordinate-model)
- [Normalising to 0..1](#normalising-to-01)
- [Sampling](#sampling)
- [Sampling more than one source image](#sampling-more-than-one-source-image)
- [Always use the pixel unit](#always-use-the-pixel-unit)
- [Premultiplied alpha](#premultiplied-alpha)
- [What Kage is not](#what-kage-is-not)
- [Migrating an existing shader](#migrating-an-existing-shader)
- [Verifying a shader compiles](#verifying-a-shader-compiles)
- [Related references and sources](#related-references-and-sources)

## Overview

Kage is the shading language of Ebitengine. It looks like Go. At runtime, Ebitengine translates it into GLSL, GLSL ES, HLSL, MSL, or PSSL.

These three facts break ports from every other shading language:

1. **An image is a sub-rectangle of a larger atlas texture.** The coordinates that go to and from a Kage shader are absolute positions on that atlas.
   They are not positions in the image, and they are not `0..1`.
2. **Destination and source images are usually on different atlases**, at different origins. Thus, a destination coordinate is not a source coordinate.
3. **Always write in the pixel unit** (`//kage:unit pixels`). The texel unit is legacy.

All the rules below come from those three facts.

## Non-negotiables

Check each item before you declare a shader done.

- [ ] `//kage:unit pixels` is present, on its own line, exactly once.
- [ ] Every coordinate that you scale, divide, rotate, mirror, tile, or wrap is first made relative to the origin. The origin is added back after.
- [ ] Every sampling argument is in the coordinate space of **source image 0**, never in that of image N.
- [ ] The returned `vec4` is premultiplied alpha (each of `.r/.g/.b` ≤ `.a`).
- [ ] There is no integer literal division in a float context (`2/3` is `0`).
- [ ] `DrawRectShader`: every non-nil source image is exactly `width`×`height`.
- [ ] The shader compiles. Run the `go test` check in [Verifying a shader compiles](#verifying-a-shader-compiles).

## The coordinate model

An `*ebiten.Image` is a region of a bigger internal texture (an atlas). Three region pairs describe that placement, all in pixels:

| Region | Origin | Size | Whole texture |
|---|---|---|---|
| Destination | `imageDstOrigin()` | `imageDstSize()` | `imageDstTextureSize()` |
| Source N (0..3) | `imageSrcNOrigin()` | `imageSrcNSize()` | `imageSrcNTextureSize()` |

Ordinary pixel-unit sampling uses the origin and the size.
The whole-texture sizes convert between pixels and texels, and a manual migration of a texel-unit calculation needs exactly that.
`imageSrcNTextureSize` is new in v2.10. `imageDstTextureSize` was deprecated in v2.6, and v2.10 brings it back.

These regions describe **whole images**, not the area that a draw call covers.
The destination region is the bounds of the destination image.
Thus, a `DrawRectShader(w, h, ...)` rectangle placed by a `GeoM` translation is a sub-region of it. So is a triangle fan that covers part of the screen.
As a result, `dstPos.xy - imageDstOrigin()` is local to the image, not local to the draw, and `imageDstSize()` is not the extent of the draw.

When you must position or scale an effect relative to what you draw, drive it from `src0Pos`.
`src0Pos` is interpolated from the vertices, and thus it follows the geometry.
Alternatively, pass the origin and the size of the draw as uniforms.

The `Fragment` entry point receives absolute positions on those textures:

```go
func Fragment(dstPos vec4, src0Pos vec2, color vec4) vec4
```

- `dstPos.xy` is the position of the fragment on the **destination** texture. Only `.xy` has a meaning. Ignore `.z` and `.w`.
- `src0Pos` is the interpolated position on **source texture 0**.
  It comes from `Vertex.SrcX`/`SrcY`, converted to the texture coordinates of image 0.
  If `Images[0]` is nil, `SrcX`/`SrcY` go through with no conversion.
- `color` for `DrawTrianglesShader` is the interpolated `Vertex.ColorR/G/B/A`, which are four arbitrary interpolated floats.
  For `DrawRectShader`, it is `DrawRectShaderOptions.ColorScale`.
  It is `vec4(1)` only because a zero-value `ColorScale` is (1, 1, 1, 1).
- An optional fourth `custom vec4` parameter receives `Vertex.Custom0..Custom3` (`DrawTrianglesShader` only, Ebitengine v2.8+).

You can omit any trailing parameters. `func Fragment() vec4` is legal.

## Normalising to 0..1

Neither `dstPos` nor `src0Pos` is guaranteed to start at zero.
Sometimes one does: an image can be at the origin of its texture.
Also, `DrawTrianglesShader` with `Images[0] == nil` passes `SrcX`/`SrcY` through with no change.
This is why it is the most common porting bug.
Code that divides a raw coordinate by a size looks correct until the image is at a different position on an atlas.

```go
// WRONG: dstPos.xy is atlas-absolute, so uv is offset by the atlas origin.
uv := dstPos.xy / imageDstSize()
```

First subtract the origin. When you convert a normalised value into a position, add the origin back:

```go
// Destination image, normalized to 0..1.
dstUV := (dstPos.xy - imageDstOrigin()) / imageDstSize()

// Source image 0, normalized to 0..1.
srcUV := (src0Pos - imageSrc0Origin()) / imageSrc0Size()

// Back to a samplable position on source image 0.
pos := srcUV*imageSrc0Size() + imageSrc0Origin()
```

`imageSrc0Size()` is zero when `DrawTrianglesShader` runs with `Images[0] == nil`.
Then `SrcX`/`SrcY` reach the shader with no conversion, and no source region is set. Thus, normalisation by that size divides by zero.
In that case, pass the size that you mean as a uniform.
`DrawRectShader` is safe without an image, because in the pixel unit it makes source region 0 from the drawn rectangle.

`imageDstSize()` is the destination *image*. Thus, `dstUV` normalises over the image, not over the area that you draw.
A ported `fragCoord/iResolution` usually means the area that you draw.
The two are the same only when the draw covers the whole destination image.
For `DrawRectShader`, the coordinate of the drawn area is `srcUV`. Source region 0 spans the drawn rectangle, and `GeoM` does not change it.
In other cases, pass the origin and the size of the draw as uniforms. Read `references/kage-recipes.md`.

The same subtract, transform, and add sequence applies to *any* operation on a coordinate that is not a translation, not only to division.
Examples are `floor(p/cell)*cell` for pixelation, `mod` for tiling, a rotation matrix, and a mirror. Do these operations in the space relative to the origin.

## Sampling

```go
imageSrc0At(pos vec2) vec4                   // returns vec4(0) outside the image region
imageSrc0UnsafeAt(pos vec2) vec4             // faster; undefined outside the image region
imageSrcNAtFromSrc0Pos(pos vec2) vec4        // N >= 1; returns vec4(0) outside the image region
imageSrcNUnsafeAtFromSrc0Pos(pos vec2) vec4  // N >= 1; faster; undefined outside the image region
```

Sampling is always nearest-neighbour. Inside a shader, there is no linear filter, no mipmap, and no wrap mode.
`ebiten.Filter` and `ebiten.Address` apply to `DrawImage`/`DrawTriangles`, not to a custom shader.
Write clamping, repeating, and interpolation yourself. Read `references/kage-recipes.md`.

The `UnsafeAt` forms do not do the region bounds check. Thus, their result outside the source region is undefined.
It depends on the position and the backend. It can be atlas padding, the pixels of a neighbouring image, zero, or something completely different.
Use these forms only where the position is provably inside the region, for example after a clamp or a wrap.

## Sampling more than one source image

For N ≥ 1, the functions are `imageSrcNAtFromSrc0Pos` and `imageSrcNUnsafeAtFromSrc0Pos`. Their names state the rule.
They **take a position in the coordinate space of source image 0**.
The implementation moves the position to image N: it fetches `pos - imageSrc0Origin() + imageSrcNOrigin()`.
`imageSrcNAtFromSrc0Pos` returns `vec4(0)` outside `[imageSrc0Origin(), imageSrc0Origin() + imageSrcNSize())`.
`imageSrcNAt` and `imageSrcNUnsafeAt` are the same functions with their old names, deprecated as of v2.10.

Thus, all four slots share one coordinate space, and the normal argument for each of them is `src0Pos`.
Pixel (x, y) of image 0 aligns with pixel (x, y) of image N, whatever atlases they are on and whatever their sizes:

```go
return imageSrc0At(src0Pos) * imageSrc1AtFromSrc0Pos(src0Pos).a
```

Different sizes need no correction. Where image N is smaller than image 0, `imageSrcNAtFromSrc0Pos` returns `vec4(0)`.

You need arithmetic only when you want a *different* mapping on purpose, for example to stretch a smaller mask across all of image 0.
That is a scaling choice, not a size correction. The origin that you add back is still that of image 0:

```go
uv := (src0Pos - imageSrc0Origin()) / imageSrc0Size()
src0PosForStretchedSrc1 := uv*imageSrc1Size() + imageSrc0Origin() // note: Src0Origin, not Src1Origin
return imageSrc1AtFromSrc0Pos(src0PosForStretchedSrc1)
```

If you add `imageSrc1Origin()` there, you make the classic bug.
The function applies the origin internally, so a second addition counts the atlas offset twice, and it samples an unrelated part of the atlas.
`imageSrcNOrigin()` for N ≥ 1 is almost never correct in a sampling expression. The important origin is `imageSrc0Origin()`.

## Always use the pixel unit

Put this on its own line. By convention, it goes immediately above `package main`:

```go
//kage:unit pixels
```

If you omit it, Kage selects the legacy texel unit.
Then `src0Pos` and every origin and size value become texels of the **atlas** texture (0..1 across the whole atlas, not across your image).
Also, `DrawTrianglesShader`/`DrawRectShader` panic when the source images have different sizes.
A file can contain a maximum of one `//kage:unit` directive.

The texel-unit helpers `imageSrcRegionOnTexture()`, `imageDstRegionOnTexture()`, and the index-less `imageSrcTextureSize()` are deprecated as of v2.6.
Do not add them. When you port old Kage code, replace them:

| Deprecated | Replacement |
|---|---|
| `imageSrcRegionOnTexture()` | `imageSrc0Origin()`, `imageSrc0Size()` |
| `imageDstRegionOnTexture()` | `imageDstOrigin()`, `imageDstSize()` |
| `imageSrcTextureSize()` | `imageSrc0TextureSize()` (v2.10+) |

## Premultiplied alpha

Ebitengine uses premultiplied alpha everywhere, shaders included.

- Sampling returns premultiplied colours.
- The `vec4` that you return must be premultiplied: `rgb ≤ a` for each component.
  Nothing clamps it for you. A colour that is not valid renders as a blend that is too bright and washed out.
- To fade, scale the whole vector: `return clr * 0.5`. Never use `clr.a *= 0.5`.
- To tint, multiply: `return clr * vec4(1, 0.5, 0.5, 1)`.
- A shader that you port from a straight-alpha source needs its final colour premultiplied: `return vec4(rgb*a, a)`.
  A correction of only the output is not sufficient if the original also calculated on straight-alpha samples, because sampling always gives you premultiplied samples.
  Whether the samples of the original were straight depends on its texture data and its own conventions, not on its language.
- An RGB operation can stay in premultiplied space when it commutes with premultiplication, that is, when `F(a*rgb) == a*F(rgb)` across the alpha range in use.
  A scale of the whole `vec4` (a fade) qualifies, because it keeps the straight RGB and scales only alpha.
  A constant tint for each channel with an alpha factor of 1 also qualifies.
- `mix` does not qualify, although it looks linear.
  Over premultiplied values, it interpolates in premultiplied space, and this is not the straight-RGB result that the original calculated.
  The exception is when the two alphas are equal, because then the two results agree.
  It is not source-over compositing either. `mix` is interpolation, not a blend operator.
- `+` has no equal-alpha exception, because addition has no output-alpha policy of its own.
  A sum of two premultiplied `vec4` values also adds their alphas, and that larger alpha scales the straight RGB that you get back.
  For example, two colours at `a = 0.5` add to `a = 1`, with straight RGB at half the sum in straight space.
  Find out from the original whether it kept, maximised, clamped, or separately calculated its output alpha, and reproduce that policy deliberately.
- Nonlinearity alone is not the criterion.
  Common failures are gamma correction, contrast curves with a fixed pivot, most `pow` exponents, and thresholds against a fixed nonzero value.
  A positively homogeneous operation, for example a `min`/`max` for each channel against zero, commutes although it is not linear.
- Judge HSV and HSL case by case against `F(a*rgb) == a*F(rgb)`. Do not assume that they fail, and do not assume that they behave the same.
  A conversion followed by its own inverse is the identity in both, so it commutes. A change to the form of value or lightness usually does not.
- In HSV, saturation is `(max-min)/max`, and hue is a ratio. Thus, positive scaling does not change them, and only value carries the scale.
  An operation that changes only hue and saturation commutes, if the concrete implementation adds no offset and no fixed-value step.
- In HSL, saturation is `(max-min)/(max+min)` below `L = 0.5`, and `(max-min)/(2-max-min)` above it.
  The first form does not change with scale. The fixed white point makes the second form depend on scale, and scaling can move a colour across the boundary between them.
  A multiplication of saturation by a constant commutes, because that white point cancels between the forward and inverse formulas.
  But this is true only while the whole operation stays homogeneous, with no offset, no fixed assignment, and no clamp.
  The usual `min(s*k, 1)` breaks it when the straight-space saturation reaches the limit and the saturation from premultiplied RGB does not.
  A saturation curve or a fixed saturation does not commute either.
  Evaluate each HSL operation on its own. If you did not, unpremultiply.
- To convert, unpremultiply, calculate, and premultiply again. Guard the division: `rgb := clr.rgb / max(clr.a, 1e-6)`.
  Convert each time that you did not prove equivalence.

The worked example below uses a straight `(1, 0, 0)` at `a = 1` and a straight `(0, 0, 1)` at `a = 0.25`.
`(0, 0, 1, 0.25)` is not a legal premultiplied colour, because blue is more than alpha:

| | first | second | `mix(…, 0.5)` |
|---|---|---|---|
| straight | `(1,0,0) a=1` | `(0,0,1) a=0.25` | `(0.5,0,0.5) a=0.625` |
| premultiplied | `(1,0,0,1)` | `(0,0,0.25,0.25)` | `(0.5,0,0.125,0.625)` |

The premultiplied result unpremultiplies to straight `(0.8, 0, 0.2)`.
The straight result premultiplies to `(0.3125, 0, 0.3125, 0.625)`.
The two results disagree because the alphas are different.

## What Kage is not

Kage is a small subset of the syntax of Go. It is not Go, and it is not GLSL. Upstream verified this list against the Ebitengine repository.

**Available:** `bool`, `int`, `float`, `vec2`/`vec3`/`vec4`, `ivec2`/`ivec3`/`ivec4`, `mat2`/`mat3`/`mat4` (column-major), and fixed-size arrays.
Also swizzling (`.xyzw`, `.rgba`, `.stpq`, not mixed) and `[i]` indexing, top-level helper functions with multiple return values, and `const`.
Also `if`/`else`, `break`/`continue`, the full builtin math library, `discard()`, and `frontfacing()` (v2.9+).

**Not available:** `struct`, `switch`, `goto`, `defer`, `go`, `init`, `import`, methods, nested functions and closures, strings, slices, maps, and pointers.
Recursion passes the compiler of Kage, but the target shading languages reject it, so it fails at draw time. Do not use it.

**Rules that cause errors:**

- **Loops have constant bounds.** The only accepted forms are `for i := <const>; i <op> <const>; i <op>= <const> { }` (ops `< <= > >= == !=` and `+= -= ++ --`).
  As of v2.10, `for i := range <constant int>` and `for i, v := range <array>` are also accepted.
  There is no `for cond { }`, and no bound that a uniform controls.
  To change the count at runtime, loop to a constant upper bound and `break` on a uniform.
- **Globals must be exported, and exported globals are uniforms.** `var Time float` declares a uniform. `var t float` is a compile error.
  The shader cannot assign uniforms, and uniforms cannot have initial values. `const` globals can use any case.
- **There is no implicit int↔float conversion**, the same as in Go. `var f float = i` fails. Write `float(i)`.
  `%` is not defined on floats. Use `mod(x, y)`.
- **`2/3` is `0`.** Untyped constant division follows the rules of Go, so `color.r >= 2/3` compares against zero with no warning. Write `2.0/3.0`.
- **`float` has no guaranteed precision.** It is the `float` of the target language at its highest available precision.
  On GLES, this is the `highp` that the driver gives.
  Do not rely on a specific mantissa width, and do not port a shader that packs data into float bits.
- **`len` takes only an array.** Some third-party documents suggest `len(vec4)`, which is like Go but is not correct.
- **There are exactly 4 source images**, `imageSrc0*` through `imageSrc3*`.
- **There is no vertex entry point.** Kage compiles a fragment shader. Ebitengine does the vertex transformation.
  A function that you name `Vertex` is an ordinary helper, and nothing calls it.

## Migrating an existing shader

1. **First, read the original for its coordinate assumptions.**
   Find whether it uses `0..1` UVs or pixel coordinates.
   Find whether it uses a bottom-left origin (Shadertoy, OpenGL) or a top-left origin (Ebitengine, Direct3D), and whether it needs a resolution or aspect-ratio uniform.
2. **Translate the coordinate preamble, not only the body.** Replace the UV derivation of the original with the form relative to the origin above.
   `gl_FragCoord`/`fragCoord` becomes `dstPos.xy - imageDstOrigin()`, and `iResolution` becomes `imageDstSize()`, *when the draw covers the whole destination image*.
   In other cases, work from `src0Pos`/`imageSrc0Size()`, or pass the origin and the size of the draw as uniforms.
   A bottom-left origin needs `uv.y = 1 - uv.y`.
3. **Translate the body** with the tables in `references/kage-porting.md`.
4. **Write unbounded loops again** with a constant bound and a `break`.
5. **Correct the output** to premultiplied alpha.
6. **Move `#define`s to `const`, and `uniform`s to exported globals.**
7. **Do a compile check**, then render and compare against the original.

Port the coordinate handling first, and verify it alone before you port the effect.
Return `vec4(dstUV, 0, 1)`, and confirm a clean red and green ramp across the image.
A missing origin causes almost every bug where the effect is offset, tiles incorrectly, or works only when the image is the whole atlas.

## Verifying a shader compiles

`ebiten.NewShader` compiles Kage with no GPU, window, or display. Thus, a plain `go test` is the fastest check:

```go
package shaders_test

import (
	"os"
	"testing"

	"github.com/hajimehoshi/ebiten/v2"
)

func TestShaderCompiles(t *testing.T) {
	src, err := os.ReadFile("effect.kage")
	if err != nil {
		t.Fatal(err)
	}
	if _, err := ebiten.NewShader(src); err != nil {
		t.Fatal(err)
	}
}
```

The test reports errors as `line:column: message` against the source.

The check has two limits:

- It validates only Kage. The graphics driver does the translation to GLSL/HLSL/MSL on first use.
  Thus, rejections at backend level (recursion, limits of a specific driver) occur at draw time, not here.
- It cannot find a wrong result. For that, render with a headless run (`references/headless-run.md`), and compare pixels.

A real `.kage` file needs no build constraint, because the Go toolchain ignores the extension.
`//go:build ignore` above the `//kage:unit` directive is only for Kage source with a `.go` extension, so that Go tooling skips it.
`examples/shader/*.go` in the Ebitengine repository does this.

## Related references and sources

- `references/kage-porting.md`: a construct-by-construct translation table for GLSL, Shadertoy, HLSL, and Godot, and the CPU-side calls that these ports need.
- `references/kage-recipes.md`: Kage snippets to copy for clamp and repeat addressing, bilinear sampling, normalisation helpers, cross-image remapping, pixelation, blur, and branchless selectors.
- <https://ebitengine.org/en/documents/shader.html>: the official language reference, with the complete list of builtin functions.
- <https://github.com/tinne26/kage-desk/tree/main/docs>: tutorials and more pitfalls.
