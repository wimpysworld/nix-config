# JSFX effects

Use JSFX for small audio effects, MIDI processors, and meters inside REAPER.
Write a text file in a writable project directory before the user loads a copy under the REAPER `Effects/` directory.
Do not change a managed effect in place.

```text
desc:My Effect
slider1:8<0,32,1>Amount

@init
@slider
@block
@sample
```

| Section | Purpose |
| --- | --- |
| `@init` | Initial state when the effect loads. |
| `@slider` | Recalculate settings when a slider changes. |
| `@block` | Process a block, including MIDI events. |
| `@sample` | Process each audio sample. |

Check syntax and API details against the [official JSFX documentation](https://www.reaper.fm/sdk/js/js.php).
The starter `jsfx/velocity_randomizer.jsfx` changes non-zero note-on velocities and forwards other MIDI messages.
Place it before an instrument. It does not create sound by itself.

For MIDI tools, preserve channels, event offsets, note-off messages, and unrelated controller messages.
Clamp note-on velocity to 1 through 127 when a note must remain audible.
Do not turn a note-on into a velocity-zero note-off by accident.

For audio effects, check gain, clipping, feedback bounds, and CPU cost.
Avoid allocations or unnecessary calculations in per-sample work.
Compilation does not prove sound quality. Report which checks ran and leave listening checks to the user when live playback is outside scope.
