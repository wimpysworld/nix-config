# Kage recipes

Kage snippets to copy. Every snippet assumes `//kage:unit pixels`, and every snippet is written for atlas-relative coordinates.
Read the coordinate model in `references/kage-shaders.md` first. All reference paths are relative to the skill root.

## Contents

- [Normalisation](#normalisation)
- [Normalising over the drawn area](#normalising-over-the-drawn-area)
- [Transforming a coordinate](#transforming-a-coordinate)
- [Sampling another source image](#sampling-another-source-image)
- [Addressing modes](#addressing-modes)
- [Bilinear sampling](#bilinear-sampling)
- [Pixelation](#pixelation)
- [A loop count that a uniform controls](#a-loop-count-that-a-uniform-controls)
- [A separable kernel](#a-separable-kernel)
- [Premultiplied alpha](#premultiplied-alpha)
- [Branchless selectors](#branchless-selectors)
- [Debugging](#debugging)

## Normalisation

```go
// Destination position, normalized to 0..1 over the destination image.
func dstUV(dstPos vec4) vec2 {
	return (dstPos.xy - imageDstOrigin()) / imageDstSize()
}

// Source position, normalized to 0..1 over source image 0.
func srcUV(src0Pos vec2) vec2 {
	return (src0Pos - imageSrc0Origin()) / imageSrc0Size()
}

// The inverse: a 0..1 coordinate back to a samplable position on source 0.
func src0PosOf(uv vec2) vec2 {
	return uv*imageSrc0Size() + imageSrc0Origin()
}
```

The two source helpers need a source region that is not empty.
`imageSrc0Size()` is zero when `DrawTrianglesShader` runs with `Images[0] == nil`. In that case, pass the size as a uniform.
In the pixel unit, `DrawRectShader` makes source region 0 from the drawn rectangle. Thus, the helpers are safe there, with or without an image.

`dstUV` has no such precondition, but it normalises over the whole destination image, not over the area that you draw.
A ported `fragCoord/iResolution` almost always means the area that you draw.
The two agree only when the draw covers the whole destination image.
A `GeoM` translation, a rectangle smaller than the image, or a sub-image destination breaks the agreement, but the picture still looks correct.
The effect then stays fixed to the image, not to the quad.

## Normalising over the drawn area

For `DrawRectShader`, the `srcUV` above is already the coordinate of the drawn area. Source region 0 spans the drawn rectangle.
With an image, the region is the bounds of that image, and the image size must be the same as the rectangle size.
With `Images[0] == nil` in the pixel unit, Ebitengine makes the region `(0, 0)-(width, height)`.
In both cases, `src0Pos` runs from the origin of the region to its origin plus size across the quad. Thus, `srcUV` is 0..1 over the rectangle.
`GeoM` also does not change it. A rotation or scale of the draw moves `dstPos`, but the coordinates of the rectangle stay the same.
A shader written for a full-screen quad expects this behaviour.

```go
// fragCoord/iResolution, over the drawn rectangle.
func drawnUV(src0Pos vec2) vec2 {
	return (src0Pos - imageSrc0Origin()) / imageSrc0Size()
}

// fragCoord itself, in pixels from the rectangle's top-left corner.
func drawnPos(src0Pos vec2) vec2 {
	return src0Pos - imageSrc0Origin()
}
```

`DrawTrianglesShader` has no drawn rectangle to recover. `SrcX`/`SrcY` decide the mapping.
With `Images[0] == nil`, those values reach the shader with no conversion.
Thus, if you write 0 and 1 into them, `src0Pos` is the uv, and the shader needs no normalisation.

Sometimes the effect is fixed in destination space, for example a vignette with its centre on a moving quad.
Then pass the origin and the size of the draw as uniforms, and normalise `dstPos` against those.
No builtin reports them. `imageDstOrigin` and `imageDstSize` describe only the destination image.

## Transforming a coordinate

Subtract the origin, transform, and add the origin back. This is a rotation about the centre of the image:

```go
func rotateAroundCenter(src0Pos vec2, angle float) vec2 {
	p := src0Pos - imageSrc0Origin() - imageSrc0Size()/2
	s, c := sin(angle), cos(angle)
	p = vec2(p.x*c-p.y*s, p.x*s+p.y*c)
	return p + imageSrc0Size()/2 + imageSrc0Origin()
}
```

## Sampling another source image

Every slot shares the coordinate space of image 0. Thus, pass `src0Pos` with no change, whatever the sizes of the images.

```go
func Fragment(dstPos vec4, src0Pos vec2, color vec4) vec4 {
	return imageSrc0At(src0Pos) * imageSrc1AtFromSrc0Pos(src0Pos).a
}
```

`imageSrcNAtFromSrc0Pos` and `imageSrcNUnsafeAtFromSrc0Pos` (N ≥ 1) are new in v2.10.
`imageSrcNAt` and `imageSrcNUnsafeAt` are the same functions with their old names. They still work, but they are deprecated as of v2.10.

To stretch image 1 across image 0, and not align it pixel for pixel, normalise in the space of image 0.
Then scale by the size of image 1, and add the origin of **image 0**.
The result is still a position in the space of image 0, which is what `imageSrc1AtFromSrc0Pos` takes.

```go
func src0PosForStretchedSrc1(src0Pos vec2) vec2 {
	uv := (src0Pos - imageSrc0Origin()) / imageSrc0Size()
	return uv*imageSrc1Size() + imageSrc0Origin()
}
```

## Addressing modes

`imageSrc0At` and `imageSrcNAtFromSrc0Pos` return `vec4(0)` outside the image. These helpers give the other two behaviours:

```go
// Clamp to edge.
func clampToEdge(pos vec2) vec2 {
	const epsilon = 0.001
	origin := imageSrc0Origin()
	return clamp(pos, origin, origin+imageSrc0Size()-vec2(epsilon))
}

// Repeat.
func repeat(pos vec2) vec2 {
	origin := imageSrc0Origin()
	return mod(pos-origin, imageSrc0Size()) + origin
}
```

Both helpers give a position that is provably inside the region. `imageSrc0UnsafeAt` needs this precondition.
It does not do the bounds check, so its result outside the region is undefined.

## Bilinear sampling

Sampling is nearest-neighbour. When the draw scales up, interpolate manually.

```go
func bilinearAt(pos vec2) vec4 {
	p := pos - vec2(0.5)
	f := fract(p)
	base := floor(p) + vec2(0.5)
	tl := imageSrc0At(base)
	tr := imageSrc0At(base + vec2(1, 0))
	bl := imageSrc0At(base + vec2(0, 1))
	br := imageSrc0At(base + vec2(1, 1))
	return mix(mix(tl, tr, f.x), mix(bl, br, f.x), f.y)
}
```

When you sample all four taps with `imageSrc0At`, you get clamp-to-zero at the edges of the image.
Within half a pixel of a border, one or two taps are outside the region, and they contribute `vec4(0)`.
This shows as a dark or transparent fringe when the draw scales up.
For clamp-to-edge or repeat, apply the address transform to each tap. This also makes each tap provably inside the region:

```go
func bilinearClampedAt(pos vec2) vec4 {
	p := pos - vec2(0.5)
	f := fract(p)
	base := floor(p) + vec2(0.5)
	tl := imageSrc0UnsafeAt(clampToEdge(base))
	tr := imageSrc0UnsafeAt(clampToEdge(base + vec2(1, 0)))
	bl := imageSrc0UnsafeAt(clampToEdge(base + vec2(0, 1)))
	br := imageSrc0UnsafeAt(clampToEdge(base + vec2(1, 1)))
	return mix(mix(tl, tr, f.x), mix(bl, br, f.x), f.y)
}
```

For wrapping, use `repeat` in place of `clampToEdge`.

A clamp of the incoming `pos` once, before you derive the taps, is also a valid way to get clamp-to-edge.
But this works only against the **texel-centre** range, and `clampToEdge` does not calculate that range.
That helper clamps to the image region `[origin, origin+size)`.
A position clamped to `origin` puts the first tap at `origin-0.5`, outside the image, with a real interpolation weight.
The range that works is `[origin+0.5, origin+size-0.5]`:

```go
func clampToTexelCenters(pos vec2) vec2 {
	origin := imageSrc0Origin()
	return clamp(pos, origin+vec2(0.5), origin+imageSrc0Size()-vec2(0.5))
}
```

Interpolation stays in the interior.
At the far edge, the second tap of each pair is one texel after the last centre, with a weight of exactly zero.
Use input clamping together with `imageSrc0At`, because its `vec4(0)` causes no problem at weight zero.
Do not use it with `imageSrc0UnsafeAt`, because an undefined value multiplied by zero is not always zero.

## Pixelation

A constant cell size:

```go
const CellSize = 12.0

func Fragment(dstPos vec4, src0Pos vec2, color vec4) vec4 {
	origin := imageSrc0Origin()
	cell := floor((src0Pos-origin)/CellSize)*CellSize + vec2(CellSize/2)
	return imageSrc0At(cell + origin)
}
```

The average of the whole cell needs a loop, and the loop bound must be constant:

```go
const CellSize = 12.0

func Fragment(dstPos vec4, src0Pos vec2, color vec4) vec4 {
	origin := imageSrc0Origin()
	cell := floor((src0Pos-origin)/CellSize) * CellSize
	var acc vec4
	for y := 0.0; y < CellSize; y++ {
		for x := 0.0; x < CellSize; x++ {
			acc += imageSrc0At(cell + vec2(x, y) + origin)
		}
	}
	return acc / (CellSize * CellSize)
}
```

Here, `CellSize` must have an integer value. Otherwise, the loop count and the divisor disagree.

## A loop count that a uniform controls

Loop to a constant upper bound, and `break` on the uniform.

```go
var CellSize float

const MaxCellSize = 32.0

func Fragment(dstPos vec4, src0Pos vec2, color vec4) vec4 {
	// Flooring keeps cells on an integer grid: a fractional size puts adjacent
	// cell origins at fractional positions, so neighbouring cells sample
	// overlapping texels under nearest sampling. Clamping keeps the divisor
	// non-zero and the loop bound within the constant's reach.
	size := floor(clamp(CellSize, 1, MaxCellSize))
	origin := imageSrc0Origin()
	cell := floor((src0Pos-origin)/size) * size
	var acc vec4
	var n float
	for y := 0.0; y < MaxCellSize; y++ {
		if y >= size {
			break
		}
		for x := 0.0; x < MaxCellSize; x++ {
			if x >= size {
				break
			}
			acc += imageSrc0At(cell + vec2(x, y) + origin)
			n++
		}
	}
	return acc / n
}
```

With a quantised `size`, `n` always equals `size*size`.
A count of the samples is still useful, because it stays correct if you remove the `floor` to permit a smooth animated cell size.
In that case, the loop runs `ceil(size)` times on each axis.
Then expect cells that overlap, because the grid is no longer aligned to texels.

## A separable kernel

Offsets in whole pixels need no origin arithmetic, because the origin cancels.

```go
const Radius = 4

func blurH(pos vec2) vec4 {
	var acc vec4
	var weight float
	for i := -Radius; i <= Radius; i++ {
		w := 1.0 - abs(float(i))/(Radius+1)
		acc += imageSrc0At(pos+vec2(float(i), 0)) * w
		weight += w
	}
	return acc / weight
}
```

## Premultiplied alpha

```go
// Fade: scale the whole vector, never the alpha alone. Scaling all four
// components commutes with premultiplication, so this matches what the
// straight-alpha equivalent would produce.
func fade(clr vec4, t float) vec4 {
	return clr * t
}

// Round-trip to straight alpha, needed by any operation that does not commute
// with premultiplication — gamma among them — and by `mix` between samples
// whose alphas differ. Addition needs each input converted as well, but
// converting is not the whole fix: `+` defines no output alpha, so the port
// must also reproduce whatever policy the original used.
func withStraightRGB(clr vec4) vec4 {
	rgb := clr.rgb / max(clr.a, 1e-6)
	rgb = pow(rgb, vec3(1.0/2.2)) // whatever the computation is
	return vec4(rgb*clr.a, clr.a)
}

// A color written as 0..255 channels, premultiplied.
func rgba8(r, g, b, a float) vec4 {
	return vec4(r/255*(a/255), g/255*(a/255), b/255*(a/255), a/255)
}
```

## Branchless selectors

These selectors help when a branch diverges widely across a wavefront. For short branches, an ordinary `if` is correct.

```go
func whenGreaterOrEqual(a, b float) float { return step(b, a) }
func whenLess(a, b float) float           { return 1 - step(b, a) }
func whenEqual(a, b float) float          { return 1 - abs(sign(a-b)) }

// Pick a when sel is 0, b when sel is 1.
func pick(a, b vec4, sel float) vec4 {
	return mix(a, b, sel)
}
```

## Debugging

Before you port any effect, return a coordinate as a colour, and look at the result.
A correct destination ramp is black at the top-left of the destination *image*, red across, and green down.
If the draw covers only part of that image, the ramp spans the image, and the drawn area shows a part of it.

```go
func Fragment(dstPos vec4, src0Pos vec2, color vec4) vec4 {
	uv := (dstPos.xy - imageDstOrigin()) / imageDstSize()
	return vec4(uv, 0, 1)
}
```

If the ramp is offset or clipped, or the image looks correct only at some sizes, an origin is missing.
To check the source side in the same way, use `src0Pos`/`imageSrc0*` in place of the destination values.
