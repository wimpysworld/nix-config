# Efficient rendering

Use this reference when you write or change Ebitengine drawing code, arrange sprites or offscreen passes, or investigate rendering performance.
Apply it during implementation, before performance problems occur. All reference paths are relative to the skill root.

## Contents

- [The principle](#the-principle)
- [How texture atlases enable batching](#how-texture-atlases-enable-batching)
- [Unmanaged images](#unmanaged-images)
- [Keep compatible draws together](#keep-compatible-draws-together)
- [Kage builtins can add implicit uniforms](#kage-builtins-can-add-implicit-uniforms)
- [Account for offscreen passes](#account-for-offscreen-passes)
- [Verify the real commands](#verify-the-real-commands)
- [Sources](#sources)

## The principle

Design drawing around compatible successive commands and necessary render passes.
The number of Go drawing calls is not the number of GPU draw commands.
Keep the intended image when you improve batching.

## How texture atlases enable batching

A texture atlas is a large GPU texture that contains many smaller images in separate rectangular regions.
To draw an image, the GPU samples its region of that texture.
Thus, several sprites can use the same GPU texture, although their pixels and positions are different.

Ebitengine automatically packs eligible images into internal texture atlases, and it adjusts their texture coordinates when it draws.
A Go `*ebiten.Image` does not always own a separate GPU texture.
Applications draw with the coordinates of each image. Ebitengine controls its placement in the atlas.

For example, successive draws of a player image and a tree image can merge into one GPU command.
This occurs when both images are on the same atlas and the other drawing state is compatible.
The command samples a different region of the same texture for each sprite.
If their backing textures are different, the texture change splits the batch.
A shared atlas enables batching, but the state and order constraints below still apply.

A manually prepared sprite sheet helps to organise assets, but batching does not need it.
Images that you load separately can share an automatic atlas.
Atlas capacity, large images, and use as a render target can put images on separate backing textures.
Placement can change as the app uses images.
Do not assume that every image shares one atlas, and do not hard-code a portable atlas size.

## Unmanaged images

Most applications do not need unmanaged images. Leave `Unmanaged` at its default `false`.
To opt out of automatic atlas management is a tuning option that is rarely necessary, also for offscreen render targets.

To keep an image off the automatic atlas permanently, set `Unmanaged: true` in `NewImageOptions` passed to `NewImageWithOptions`.
Alternatively, set it in `NewImageFromImageOptions` passed to `NewImageFromImageWithOptions`.

Unmanaged images give explicit control of atlas participation for performance and memory tuning.
Separate unmanaged images cannot share an automatic atlas, so a switch between them as sources splits batches.
Repeated draws from the same unmanaged image, including its subimages, can still batch when the other state is compatible.
Unmanaged does not mean that batching is disabled.

Use unmanaged images only when a specific, measured performance or memory problem justifies control of atlas participation.
A render target that changes frequently is not, alone, a reason to enable it.
Verify the effect on commands and memory. It is not a general performance switch.

## Keep compatible draws together

Successive `DrawImage` calls batch most easily when their destination, blend, and filter are the same.
Different source `*ebiten.Image` values can still batch when they share an internal texture atlas.
Different positions, rotations, scales, and `ColorScale` values do not prevent batching on their own. Vertex data can hold these values.

With linear minification, different transforms can select different mipmap levels, and thus different backing source textures.
This can split batches, even when the original source image and the public drawing options are the same.

For `DrawTriangles`, also examine addressing and the other drawing options.
Do not assume that the same public options guarantee one GPU command.
The internal command merger compares the destination, the backing source textures, the shader, the blend, and the effective uniforms.
Buffer capacity can also split commands.
Thus, a change to the uniforms of a custom shader between objects can split draws, even with the same shader.
Changes to clipping and source regions can also change the effective state or the backend work.
When an exact batching condition is important, examine the target version.

- Group compatible draws only inside the order constraints.
  Overlapping sprites and alpha compositing usually depend on painter's order. You cannot freely sort opaque overlapping sprites by texture either.
- When dependencies permit it, finish a render pass before you switch destinations.
- Reuse image and shader resources. Do not allocate a new image for each sprite or each frame to decrease the apparent number of drawing calls.
- Use `ColorScale` for ordinary tint and opacity.
  Do not add a colour-matrix shader or varying uniforms for an operation that vertex colours already express.
- Do not replace ordinary sprite calls with manual triangle assembly only because there are many calls. First find out whether they already batch.
- Use `DrawTriangles32` / `DrawTrianglesShader32` with `uint32` indices for manually assembled meshes.
  The `uint16` versions convert indices to `uint32` internally, and they can address only 65536 vertices.

## Kage builtins can add implicit uniforms

The same user-supplied uniforms are not sufficient for shader draws to batch.
Some Kage builtins read internal uniforms that describe the images of each draw.
If those values are different between successive draws, they can split a batch, even with the same shader and the same backing textures.

- `imageSrcNOrigin()` and `imageSrcNSize()` read source-region uniforms.
  Different images or subimages on the same atlas can have different origins or sizes.
  In pixel-unit `DrawRectShader` calls without source image 0, `imageSrc0Size()` returns the requested rectangle size.
  Thus, when the shader uses this builtin, a change of that size can also split batches.
- `imageDstOrigin()` and `imageDstSize()` read destination-region uniforms.
- Texture-size builtins read uniforms for the size of the backing texture.
  These values do not always change when you switch between regions on the same atlas.
- Safe sampling such as `imageSrc0At()` implicitly reads the origin and size of the source region, to return transparent pixels outside the image.
  This adds region-dependent uniforms, even without an explicit origin or size query.
- Sampling from other source slots can also read origins, to convert coordinates from the space of source 0. This includes unsafe sampling.

The command queue puts these internal uniforms first.
Then `FilterUniformVariables` sets unused uniform variables to zero before the merger compares the uniform data.
Only the dependencies that stay are important. A call to a builtin does not always break batching.
The current filter tracks whole uniform variables.
Thus, a reference to one element of a source-region array keeps the whole array, not only that element.

In pixel-unit shaders, `imageSrc0UnsafeAt()` does not do the region bounds check, and it does not use the region uniforms.
Legacy texel-unit sampling also depends on texture-size uniforms to convert coordinates.
Use unsafe sampling only when every sampled position is guaranteed to stay inside the source image.
Otherwise, it can sample unrelated atlas content.
Do not remove bounds checks or image-coordinate calculations that correctness needs only to improve batching.
When you evaluate a shader change, check the real commands with the debug tag below.

## Account for offscreen passes

Ebitengine can move images that you draw into as render targets away from the atlases for source images.
Ebitengine can move eligible images back when their use changes. Thus, a managed offscreen is not permanently excluded from source atlases.
Do not assume that offscreens which you draw again frequently share the source atlas of the sprites.

An offscreen pass adds rendering and compositing work.
Use one when it has a concrete purpose, such as the resolution of a layer, an effect, or reusable content.
An offscreen for each object can fragment source textures and prevent batching.
Reuse offscreens, and resize them only when their necessary size changes.
Clear them when their earlier contents must not stay.

Arrange dependencies so that the app draws a layer before it samples it.
Do not alternate again and again between writing a source and drawing it into another image.
Avoid this when you can get the same result if you finish the source first.
Feedback effects can need separate ping-pong images.
It is not valid to draw an image onto itself, also through subimages of the same backing image.

Keep GPU readback (`At`, `ReadPixels`) out of drawing loops that run for each object.
Readback can force queued rendering to complete, and it transfers pixels to the CPU.
Keep CPU copies for CPU-side queries when that is correct.
Combine necessary pixel uploads. Do not build static image contents again each frame.

## Verify the real commands

Run the application with `-tags=ebitenginedebug` to examine internal graphics commands, for example `go run -tags=ebitenginedebug ./path/to/app`.
When you run it, follow the display or headless requirements of the project. For a headless run, read `references/headless-run.md`.

Examine a representative frame. Find which destinations, source textures, shaders, or state changes split compatible runs.
Compare before and after with the same scene.
Include offscreen and final presentation passes when you count work. A large sprite count can correctly give only a few commands.
The log describes internal commands, and they are not always individual backend draw calls.
One command can contain several destination regions that a backend draws separately.
When you compare work, check the logged count of destination regions.

Verify the rendered result, especially overlap, transparency, clipping, and effects.
Fewer commands alone do not prove that the app is faster. Overdraw, shader cost, pixel count, uploads, and CPU work can be larger costs.
Measure the relevant bottleneck before you add more complex rendering machinery.

## Sources

Use the godoc and source of the target project for behaviour that is specific to a version.
The performance article contains older API names and examples. The source links are pinned to the upstream revision.

- [Performance tips](https://ebitengine.org/en/documents/performancetips.html).
- [Image APIs](https://github.com/hajimehoshi/ebiten/blob/345100b0e4b75ed7e06d2a1cd84571814a5e6140/image.go): `DrawImage`, drawing options, uploads, readback.
- [Command merging](https://github.com/hajimehoshi/ebiten/blob/345100b0e4b75ed7e06d2a1cd84571814a5e6140/internal/graphicscommand/command.go):
  `CanMergeWithDrawTrianglesCommand`.
- [Command queue](https://github.com/hajimehoshi/ebiten/blob/345100b0e4b75ed7e06d2a1cd84571814a5e6140/internal/graphicscommand/commandqueue.go): effective
  uniforms, buffer limits, and enqueueing.
- [Kage builtin bridge](https://github.com/hajimehoshi/ebiten/blob/345100b0e4b75ed7e06d2a1cd84571814a5e6140/internal/graphics/shader.go): implicit image
  uniforms and sampling functions.
- [Shader uniform filtering](https://github.com/hajimehoshi/ebiten/blob/345100b0e4b75ed7e06d2a1cd84571814a5e6140/internal/shaderir/program.go):
  `FilterUniformVariables`.
- [Atlas implementation](https://github.com/hajimehoshi/ebiten/tree/345100b0e4b75ed7e06d2a1cd84571814a5e6140/internal/atlas): backing textures and allocation.
- [Mipmap selection](https://github.com/hajimehoshi/ebiten/blob/345100b0e4b75ed7e06d2a1cd84571814a5e6140/internal/mipmap/mipmap.go): source textures used for
  minification.
