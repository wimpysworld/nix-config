# Porting shaders to Kage

Translate GLSL, Shadertoy, HLSL, Unity, and Godot shaders to Kage, construct by construct.
First read the coordinate model in `references/kage-shaders.md`. This file is the mechanical translation layer.
All reference paths are relative to the skill root.

## Contents

- [Program structure](#program-structure)
- [Coordinates](#coordinates)
- [Sampling](#sampling)
- [Builtin functions](#builtin-functions)
- [Control flow](#control-flow)
- [Types](#types)
- [Output colour](#output-colour)
- [Shadertoy specifics](#shadertoy-specifics)
- [HLSL and Unity specifics](#hlsl-and-unity-specifics)
- [The CPU side](#the-cpu-side)

## Program structure

| Source | Kage |
|---|---|
| `#version 330` and similar | Nothing. Remove it. |
| a vertex shader | Nothing. Ebitengine does the vertex transformation. |
| `uniform float iTime;` | `var Time float` (an exported global is a uniform) |
| `#define PI 3.14159` | `const PI = 3.14159` |
| `varying` / `in` / `out` | `Fragment` parameters and the return value |
| `void mainImage(out vec4 o, in vec2 c)` | `func Fragment(dstPos vec4, src0Pos vec2, color vec4) vec4` |
| `gl_FragColor = c;` / `fragColor = c;` | `return c` |
| `struct Ray { ... }` | Not supported. Pass the components separately, or use an array. |
| `#ifdef` / `#include` | Not supported. There is no preprocessor. |

## Coordinates

| Source | Kage |
|---|---|
| `gl_FragCoord.xy` (window pixels) | `dstPos.xy - imageDstOrigin()` † |
| `iResolution.xy` | `imageDstSize()` † |
| `fragCoord/iResolution.xy` (0..1 uv) | `(dstPos.xy - imageDstOrigin()) / imageDstSize()` † |
| `vTexCoord` / `v_texCoord` (0..1 uv) | `(src0Pos - imageSrc0Origin()) / imageSrc0Size()` |
| `SCREEN_UV`, `UV` (Godot) | As above, destination and source respectively |
| bottom-left origin | The origin of Ebitengine is top-left: `uv.y = 1 - uv.y` |
| `gl_FrontFacing` | `frontfacing()` (v2.9+) |
| `discard;` | `discard()` |

† These rows are correct when the draw covers the whole destination image.
The destination region is the destination *image*, not the rectangle or the triangles that you draw.
Thus, under a `GeoM` translation or a draw with partial coverage, they give coordinates local to the image, and the size of the image, not of the draw.
For a partial draw, derive the coordinates from `src0Pos`, which is interpolated from the vertices.
Alternatively, pass the origin and the size of the draw as uniforms.

Aspect correction such as `uv = (fragCoord - 0.5*iResolution.xy)/iResolution.y` translates directly when you replace `fragCoord` and `iResolution`.
The same condition applies: both sides are then in pixels local to the image.

## Sampling

| Source | Kage |
|---|---|
| `texture(iChannel0, uv)` / `texture2D(tex, uv)` | `imageSrc0At(uv*imageSrc0Size() + imageSrc0Origin())` |
| `texture(tex, vTexCoord)`, where uv is the uv of the fragment | `imageSrc0At(src0Pos)` |
| a second sampler at the same uv | `imageSrc1AtFromSrc0Pos(src0Pos)` ‡, for any size, because every slot shares the space of image 0 |
| a second sampler stretched over image 0 | `imageSrc1AtFromSrc0Pos(uv*imageSrc1Size() + imageSrc0Origin())` ‡ |
| `textureSize(tex, 0)` | `imageSrc0Size()` (the image, and `imageSrc0TextureSize()` is the atlas) |
| `texelFetch(tex, ivec2(x, y), 0)` | `imageSrc0At(vec2(x, y) + imageSrc0Origin())` |
| `textureLod`, mipmaps, `textureGrad` | Not available |
| `GL_CLAMP_TO_EDGE` / `GL_REPEAT` sampler state | Write it in the shader. Read `references/kage-recipes.md`. |
| linear filtering | Write it in the shader. Sampling is always nearest. |
| out-of-range sampling | The `At` forms give `vec4(0)`. The `UnsafeAt` forms are undefined. |

‡ `imageSrcNAtFromSrc0Pos` and `imageSrcNUnsafeAtFromSrc0Pos` (N ≥ 1) are new in v2.10.
Before v2.10, use `imageSrcNAt` and `imageSrcNUnsafeAt`. They are the same functions with their old names, and they still work, but they are deprecated.

An offset of a sample by whole pixels needs no origin arithmetic, because the origin cancels.
`imageSrc0At(src0Pos + vec2(1, 0))` is the neighbouring texel.
Only a *scale* of a coordinate needs the subtract, transform, and add sequence.

## Builtin functions

These functions have the same name and the same behaviour: `sin cos tan asin acos atan pow exp log exp2 log2
sqrt inversesqrt abs sign floor ceil fract mod min max clamp mix step smoothstep
length distance dot cross normalize faceforward reflect refract transpose fwidth`.

| Source | Kage |
|---|---|
| `atan(y, x)` (two-argument) | `atan2(y, x)`, in the same order |
| `dFdx` / `dFdy` | `dfdx` / `dfdy` |
| `radians(d)` / `degrees(r)` | Not available. Use `d*3.14159265/180` and `r*180/3.14159265`. |
| `trunc`, `round`, `roundEven`, `modf` | Not available. Compose them from `floor`/`ceil`/`sign`/`fract`. |
| `sinh`, `cosh`, `tanh` | Not available. Write them out. |
| `inverse`, `determinant`, `outerProduct`, `matrixCompMult` | Not available |
| `lessThan`, `greaterThan`, `all`, `any`, `not` | Not available. Compare the components, or use `step`. |
| `isnan`, `isinf` | Not available |
| `floatBitsToInt`, `packHalf2x16`, bitfield operations | Not available |
| `mix(a, b, bvec)` | Not available. `mix` takes only a float or vector `t`. |
| `x % y` on floats | `mod(x, y)` (in Kage, `%` is only for integers) |
| `cond ? a : b` | `if`/`else`, or `mix(b, a, step(...))` |
| `float x = intExpr;` | `x := float(intExpr)`, because there is no implicit conversion |

`length`, `dot`, `normalize`, and similar functions work on `vec2`/`vec3`/`vec4` as in GLSL. `cross` is only for `vec3`.

## Control flow

| Source | Kage |
|---|---|
| `for (int i = 0; i < N; i++)` with constant `N` | `for i := 0; i < N; i++ { }` |
| `for (...)` with a uniform bound | A constant upper bound, plus `if i >= Bound { break }` |
| `while (cond)` / `do { } while` | Not available. Write it again as a bounded `for` with `break`. |
| `switch` | An `if`/`else if` chain |
| recursion | Not available in the target languages. Remove the recursion. |

The classic Kage loop must be exactly `for <var> := <const>; <var> <op> <const>; <var> <op>= <const> { }`.
The bounds and the step are constants. They are not uniforms, and they are not calculated values.

## Types

| Source | Kage |
|---|---|
| `float`, `int`, `bool` | The same. The precision of `float` is not guaranteed. |
| `vec2/3/4`, `ivec2/3/4`, `mat2/3/4` | The same. Matrices are column-major. |
| `bvec2/3/4`, `uint`, `uvec*`, `double` | Not available |
| `sampler2D` as a variable or parameter | Not available. Images are the fixed slots 0..3. |
| `vec4 a[4];` | `var a [4]vec4` |
| arrays of samplers, dynamic sampler indexing | Not available |

Swizzles work the same (`.xyzw`, `.rgba`, `.stpq`), and you cannot mix the groups.

## Output colour

Ebitengine expects **premultiplied alpha**. A shader written for straight alpha ends with a line such as `fragColor = vec4(rgb, a);`. That line becomes:

```go
return vec4(rgb*a, a)
```

A shader that returns `.rgb` with no scale while `.a` changes is a straight-alpha shader. It looks wrong when Ebitengine composites it.

The inputs need the same attention. Sampling always returns premultiplied samples.
The GLSL `texture()` has no alpha convention, because it returns the stored texel.
Thus, what is important is what the texture data and the calculations of the original assumed.
If they assumed straight alpha, convert before any straight-RGB calculation: `rgb := clr.rgb / max(clr.a, 1e-6)`.
Then premultiply the result before you return it.

Only operations that commute with premultiplication can skip the conversion, that is, operations where `F(a*rgb) == a*F(rgb)` over the alpha range in use.
A scale of the whole `vec4` qualifies, and so does a constant tint for each channel with an alpha factor of 1.
`mix` does not qualify. Over premultiplied colours, it interpolates in premultiplied space.
This is different from the straight-RGB result of the original when the alphas are different, and it agrees when they are equal.
`+` has no such exception. A sum of premultiplied values also adds the alphas.
Thus, you must reproduce it together with the output-alpha policy that the original used.

Nonlinearity alone is not the criterion.
Common failures include gamma, contrast curves with a fixed pivot, most `pow` exponents, and thresholds against a fixed nonzero value.
Judge HSV and HSL individually, and do not assume that they behave the same.
In HSV, positive scaling does not change hue and saturation, and only value carries the scale.
Thus, an operation on hue and saturation commutes, if it adds no offset and no fixed-value step.
In HSL, saturation is `(max-min)/(max+min)` below `L = 0.5`, and `(max-min)/(2-max-min)` above it. The fixed white point in that second form makes it depend on scale.

A multiplication of saturation by a constant commutes only while the operation stays homogeneous, with no offset, no fixed assignment, and no clamp.
Thus, the usual `min(s*k, 1)` is sufficient to break it.
A saturation curve or a fixed saturation does not commute at all.
A change to the form of value or lightness usually does not commute either.
Convert, unless you proved equivalence.

## Shadertoy specifics

| Shadertoy | Kage |
|---|---|
| `iResolution` | `imageDstSize()` (a `vec2`, with no `.z`), if the draw covers the whole image |
| `iTime`, `iTimeDelta`, `iFrame` | Your own uniforms, updated each tick |
| `iMouse` | Your own `vec2`/`vec4` uniform from `ebiten.CursorPosition` |
| `iChannel0..3` | Source images 0..3 |
| `iChannelResolution[N].xy` | `imageSrcNSize()` |
| `iDate`, `iSampleRate`, `iChannelTime` | Your own uniforms |
| bottom-left origin | Flip it: `uv.y = 1 - uv.y` |
| `mainImage(out fragColor, in fragCoord)` | `Fragment`, which returns the colour |
| cubemaps, 3D textures, buffers, sound shaders | Not supported |

By convention, Shadertoy shaders are opaque, and `fragColor.a` is often 1. Thus, a direct port usually needs no alpha work.
If the effect fades, apply the premultiplication.

## HLSL and Unity specifics

| HLSL | Kage |
|---|---|
| `float2/3/4`, `int2/3/4` | `vec2/3/4`, `ivec2/3/4` |
| `float4x4` | `mat4`. For the uniform layout, read **The CPU side** below. |
| `tex2D(s, uv)` / `t.Sample(s, uv)` | `imageSrc0At(...)` |
| `lerp`, `frac`, `saturate`, `atan2`, `ddx`, `ddy` | `mix`, `fract`, `clamp(x, 0, 1)`, `atan2`, `dfdx`, `dfdy` |
| `mul(M, v)` | `M * v` |
| `mul(v, M)` | `v * M` |
| `SV_Position` | `dstPos` |
| `cbuffer` fields | Individual exported globals |
| `[unroll]`, `[loop]`, semantics, register bindings | Remove them. |

Do not transpose a matrix only because the source is HLSL.
HLSL storage can be row-major or column-major, and this depends on declarations and compiler flags.
What is important is the order of the flat array that your CPU code already builds. Change that order only if it is row-major.
Multiplication is a separate question from storage, and the `mul` rows above cover it.

## The CPU side

You set uniform values through the draw options.
Values must be of a numeric or boolean type, or a slice or array of one, flattened linearly.
A `vec4` is 4 floats, a `mat4` is 16, and a `[4]vec4` is 16.
A uniform that is not in the map is zero. A wrong length or type causes a panic.

Matrices are flattened **column-major**, one column after another.
A `mat2` with the logical rows `[[a, b], [c, d]]` is supplied as `[]float32{a, c, b, d}`.
`mat3` and `mat4` follow the same column-by-column rule.
Use this layout whatever the active graphics backend is. Ebitengine does the DirectX conversion internally.
Thus, never transpose because of the backend that the game uses at that time.

### `DrawRectShader`

This is the simplest call, and it is sufficient for an effect on the full screen or a full image.
Every non-nil source image must be exactly `width`×`height`, and `src0Pos` runs across that rectangle.
This is also true when `Images[0]` is nil, because the pixel unit makes source region 0 from the rectangle.

```go
op := &ebiten.DrawRectShaderOptions{}
op.Images[0] = src
op.Uniforms = map[string]any{
	"Time": float32(t),
}
dst.DrawRectShader(src.Bounds().Dx(), src.Bounds().Dy(), shader, op)
```

### `DrawTrianglesShader32`

Use this call when source images have different sizes from each other or from the destination area, or when the geometry is not an axis-aligned rectangle.
Set both `DstX`/`DstY` and `SrcX`/`SrcY`.
`SrcX`/`SrcY` are in the bounds of source image 0, so a sub-image does not start at `(0, 0)`.

```go
db := dst.Bounds()
sb := src.Bounds()
vs := []ebiten.Vertex{
	{DstX: float32(db.Min.X), DstY: float32(db.Min.Y), SrcX: float32(sb.Min.X), SrcY: float32(sb.Min.Y), ColorR: 1, ColorG: 1, ColorB: 1, ColorA: 1},
	{DstX: float32(db.Max.X), DstY: float32(db.Min.Y), SrcX: float32(sb.Max.X), SrcY: float32(sb.Min.Y), ColorR: 1, ColorG: 1, ColorB: 1, ColorA: 1},
	{DstX: float32(db.Min.X), DstY: float32(db.Max.Y), SrcX: float32(sb.Min.X), SrcY: float32(sb.Max.Y), ColorR: 1, ColorG: 1, ColorB: 1, ColorA: 1},
	{DstX: float32(db.Max.X), DstY: float32(db.Max.Y), SrcX: float32(sb.Max.X), SrcY: float32(sb.Max.Y), ColorR: 1, ColorG: 1, ColorB: 1, ColorA: 1},
}
is := []uint32{0, 1, 2, 1, 2, 3}

op := &ebiten.DrawTrianglesShaderOptions{}
op.Images[0] = src
op.Images[1] = mask
op.Uniforms = map[string]any{"Time": float32(t)}
dst.DrawTrianglesShader32(vs, is, shader, op)
```

`ColorR/G/B/A` reach the shader as the `color vec4` parameter, interpolated and with no interpretation.
With `DrawTrianglesShader`, they are four arbitrary floats, not a colour multiplier.
With `DrawRectShader`, that parameter carries `DrawRectShaderOptions.ColorScale`, which is `vec4(1)` only when it stays at its zero value.
`Custom0..Custom3` reach an optional fourth `custom vec4` parameter (v2.8+).

Compile the shader once, and reuse it. Do not call `ebiten.NewShader` for each frame.
