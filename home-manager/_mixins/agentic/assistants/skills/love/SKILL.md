---
name: love
description: "Load when working with LÖVE 2D, the LÖVE engine, love2d, .love archives, Lua 5.1/LuaJIT 2.1 game development, or LÖVE callbacks, modules, conf.lua, and packaging."
---

# LÖVE Skill

## Role

Use expert LÖVE 2D judgement across the LÖVE 11.x API, Lua 5.1/LuaJIT 2.1 idioms, game loop callbacks, graphics, audio, physics, input, filesystem, threads, math, shaders, packaging, and performance. Target the LÖVE runtime semantics, not stock Lua: assume LuaJIT, 1-based indexing, and the LÖVE event loop unless told otherwise.

## References

Verify callback names, module functions, enums, and constants against the current LÖVE wiki or Context7 before recommending APIs. Names move between versions (notably 0.10 → 11.x); do not rely on memory.

| Need                           | Source                                                                                                                                            |
| ------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| LÖVE API surface and callbacks | Context7 `love2d` docs, `love.*` module references                                                                                                |
| Library APIs                   | Library README/source (HUMP, anim8, bump, STI, etc); Shove (https://github.com/Oval-Tutu/shove); smiti18n (https://github.com/Oval-Tutu/smiti18n) |
| Platform packaging             | bootstrap-love2d-project (https://github.com/Oval-Tutu/bootstrap-love2d-project); LÖVE wiki "Game Distribution" page                              |

## Runtime model

- Entry points: `love.load`, `love.update(dt)`, `love.draw`, `love.quit`, `love.run` (override only for custom loops).
- Input callbacks: `love.keypressed/released`, `love.mousepressed/released/moved/wheelmoved`, `love.textinput`, `love.touchpressed/released/moved`, `love.gamepadpressed/released/axis`, `love.joystick*`.
- Window/system: `love.resize`, `love.focus`, `love.visible`, `love.displayrotated`, `love.lowmemory`, `love.threaderror`, `love.errorhandler`.
- `dt` is seconds since the last frame. Multiply all movement, timers, and physics steps by `dt`; never assume a fixed framerate.
- `conf.lua` configures `t.window`, `t.modules`, `t.identity`, `t.version`, `t.console`, and `t.audio`. Disable unused modules (`t.modules.physics = false`, etc.) to cut startup cost when packaging.
- Project layout: `main.lua` and `conf.lua` at the root; package as a `.love` zip (no top-level folder) for distribution, or fuse with the LÖVE binary per platform.

## Graphics

- Coordinate origin is top-left, y grows down. Use `love.graphics.push/pop/translate/rotate/scale` for transforms; reset state explicitly after custom blend modes, shaders, or canvases.
- Draw order matters: clear with `love.graphics.clear` only inside `love.draw` or canvas passes; do not call it from `update`.
- Batch sprites with `SpriteBatch`, text with `Text`, and static geometry with `Mesh` to cut draw calls.
- Canvases: create once, reuse; `setCanvas(nil)` to restore the screen; respect canvas formats and MSAA capability via `love.graphics.getCanvasFormats`.
- Shaders are GLSL ES with LÖVE-injected uniforms (`TransformMatrix`, `ProjectionMatrix`, `love_PixelColor`, `VaryingTexCoord`). Validate with `love.graphics.newShader` error returns.
- Use `love.graphics.setDefaultFilter("nearest", "nearest")` for pixel art; pair with integer scaling.
- Colours in 11.x are 0-1 floats. Old 0-255 code from 0.10 will look black; convert when porting.

## Audio

- `love.audio.newSource(path, "static" | "stream")`. Use `"static"` for short sfx (decoded once), `"stream"` for music.
- Reuse static sources for repeated sfx; for overlapping playback either `:clone()` or use `love.audio.play(source, true)` style pooling.
- Spatial audio uses 3D position/velocity; set `:setRelative(true)` for HUD-attached sounds.
- Honour `love.audio.setVolume` master and per-source `:setVolume` separately; expose both as user settings.

## Input

- Poll continuous state with `love.keyboard.isDown`, `love.mouse.isDown`, `love.joystick:isGamepadDown`. Use callbacks for edge events.
- Use `love.keyboard.setKeyRepeat` deliberately; default is off.
- `love.textinput` provides UTF-8 text; do not derive text from `keypressed`.
- For gamepads, prefer `gamepad*` callbacks (SDL mappings) over raw `joystick*` axes/buttons.

## Filesystem

- `love.filesystem` is sandboxed. Read access covers the game source (zip or directory); write access only the save directory (`love.filesystem.getSaveDirectory`).
- Use `love.filesystem.read/write/append/lines`, not stock `io.*`, for portability and sandbox compliance.
- Identity (`t.identity` in `conf.lua` or `love.filesystem.setIdentity`) controls the save directory name; set it before any writes.
- `love.filesystem.load(path)` returns a chunk; prefer it over `loadstring`/`loadfile` for sandboxed code.

## Threads, channels, timers

- `love.thread.newThread(source)` runs Lua in isolation; share via `love.thread.getChannel(name)` with `push/pop/demand/peek/supply`.
- Only thread-safe LÖVE modules are available inside threads: `love.filesystem`, `love.image`, `love.sound`, `love.data`, `love.timer`, `love.system`, `love.event`, `love.thread`. No graphics/audio/window calls.
- `love.timer.getDelta`, `getFPS`, `getTime`, and `sleep` cover frame timing; for fixed-step logic, accumulate `dt` and step in fixed slices.

## Physics

- `love.physics` wraps Box2D. Set the meter with `love.physics.setMeter` before creating worlds; Box2D works in metres, not pixels.
- World step: `world:update(dt)`. Use callbacks via `world:setCallbacks(beginContact, endContact, preSolve, postSolve)`.
- Bodies are `"static"`, `"dynamic"`, or `"kinematic"`. Apply forces/impulses, do not teleport dynamic bodies without `body:setAwake(true)`.

## Math and data

- `love.math.random*`, `love.math.newRandomGenerator`, and `love.math.noise` are deterministic and seedable; prefer them over stock `math.random` for reproducibility.
- `love.data` provides `pack/unpack`, `encode/decode` (base64, hex), `compress/decompress` (lz4, zlib, gzip), and `hash` (md5, sha1, sha256, sha512).

## Performance

- Profile before optimising: `love.timer.getFPS`, `love.graphics.getStats` (drawcalls, canvasswitches, textures, fonts, images, drawcallsbatched).
- Cut draw calls with SpriteBatch, Text, ParticleSystem, and atlas textures; avoid per-frame `newImage`/`newFont`.
- Reuse tables; avoid per-frame allocations in hot loops; LuaJIT inlining benefits from monomorphic call sites.
- Prefer locals for module functions inside hot loops (`local sin = math.sin`).
- Use `love.graphics.setCanvas` to render expensive static content once, then draw the canvas each frame.

## Packaging

- `.love` is a zip with `main.lua` at the root. Test with `love path/to/game.love`.
- Windows: concatenate `love.exe` + `.love` then ship the LÖVE DLLs from the same release.
- macOS: copy `.love` into `LÖVE.app/Contents/Resources/`, update `Info.plist` (`CFBundleIdentifier`, `CFBundleName`), then re-sign.
- Linux: AppImage via the official LÖVE AppImage or Flatpak `org.love2d.love`.
- Android/iOS use the love-android and love-ios projects; track LÖVE version compatibility for each.
- Strip unused modules in `conf.lua` to shrink runtime memory and startup.

## Common gotchas

- 0-255 colour code from LÖVE 0.10 must be divided by 255 for 11.x.
- `love.graphics.print` ignores the current font's line height unless you use `printf` with a wrap limit.
- `Image:setFilter("nearest", "nearest", 0)` per-image overrides the default filter.
- `love.event.quit` only triggers after the current frame; do not assume immediate exit.
- `require` paths use dots, not slashes, and are rooted at the game directory.
- Modifying tables while iterating with `pairs`/`ipairs` corrupts iteration; build a removal list and apply after the loop.

## Lua 5.1 / LuaJIT constraints

- No `goto`, no integer division `//`, no bitwise operators in the language. Use `bit` (LuaJIT built-in: `bit.band`, `bor`, `bxor`, `lshift`, `rshift`, `arshift`, `bnot`).
- No `__pairs`/`__ipairs` metamethods, no `table.pack`/`table.unpack` (use `unpack`), no integer subtype.
- String escapes: no `\z`, no `\xNN` in pure 5.1 (LuaJIT accepts `\xNN`); prefer `string.char` for portability.
- `#t` is only defined for sequences (no nil holes); track length explicitly for sparse arrays.
- Use `local M = {}` modules returning the table; avoid `module(...)` (deprecated).
- FFI (`require("ffi")`) is LuaJIT-only and bypasses the LÖVE sandbox; use it sparingly and never with untrusted input.

## Constraints

- Never use Lua 5.2+ language features (`goto`, `//`, bitwise operators, `_ENV`, `table.unpack`).
- Never assume a fixed framerate; always scale by `dt`.
- Never call graphics, window, or audio modules from threads.
- Never write outside `love.filesystem` save directory; never `os.execute` or stock `io.open` for game data.
- Never recommend libraries without verifying current API and LÖVE version compatibility.
- Preserve the project's existing architecture (plain tables / OOP / ECS); do not impose a new pattern unless asked.
