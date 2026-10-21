# Using Ebitengine

Ebitengine is a 2D game engine for Go. This skill covers sharp rendering, efficient drawing, Kage shaders, and headless runs.

> **Freshness.** Upstream wrote this guidance against Ebitengine at commit `345100b0e4b75ed7e06d2a1cd84571814a5e6140`.
> `exp/vmhost` is experimental, and its API can change. If this guidance disagrees with the source, **the source wins**.
> Use the godoc and source of the target Ebitengine version for API and platform behaviour.
> Report drift to the user. Do not edit the installed skill.

## Core facts

These facts apply to every Ebitengine task.

- **Render detail at the resolution where it is displayed.** Implement `LayoutF` and return the outside dimensions times `ebiten.Monitor().DeviceScaleFactor()`.
  A low-resolution stage anywhere in the path loses detail that later scaling cannot recover.
- **The number of Go drawing calls is not the number of GPU draw commands.** Ebitengine packs eligible images into automatic texture atlases and merges compatible successive draws.
  Check the real commands with `-tags=ebitenginedebug` before you change drawing code for performance.
- **Kage coordinates are atlas-absolute, in pixels.** Put `//kage:unit pixels` in every shader.
  Subtract the image origin before you scale a coordinate, and add the origin back after.
- **Ebitengine uses premultiplied alpha everywhere**, shaders included. A shader must return a premultiplied `vec4`.
- **Prefer a headless run** for screenshots, golden-image tests, and input repros. An app built with `-tags ebitenginevmguest` runs as an `exp/vmhost` guest of a hidden host.
  The host driver is `scripts/headless-driver/main.go`. A Guigui app is an `ebiten.Game`, so the same procedure applies to it.
- **Compile against the target Ebitengine version** before you use a newer API such as `FilterPixelated` or `imageSrcNAtFromSrc0Pos`.

## References

All reference paths in this skill are relative to the skill root. Read the reference for the task before you write code.

| Task | Reference |
| --- | --- |
| A new app, layout, text, UI, image scaling, final presentation, blurry output, pixel art, high-DPI displays, input coordinates | `references/crisp-rendering.md` |
| Drawing code, sprites, offscreen passes, batching, texture atlases, unmanaged images, rendering performance | `references/efficient-rendering.md` |
| A headless run with no display or visible window: screenshots, golden images, input injection, multi-tick repros, audio checks | `references/headless-run.md` and `scripts/headless-driver/main.go` |
| Writing, reviewing, or debugging a Kage shader: coordinate model, sampling, premultiplied alpha, language limits, a compile check | `references/kage-shaders.md` |
| Porting a shader from GLSL, Shadertoy, HLSL, Unity, or Godot to Kage, and the CPU-side draw call | `references/kage-porting.md` |
| Kage snippets: normalisation, addressing modes, bilinear sampling, pixelation, blur, branchless selectors, debugging ramps | `references/kage-recipes.md` |

For a shader port, read `references/kage-shaders.md` first, then `references/kage-porting.md`.
