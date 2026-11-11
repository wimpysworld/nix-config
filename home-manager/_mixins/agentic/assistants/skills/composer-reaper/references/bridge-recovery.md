# Bridge recovery and offline projects

Treat upstream bridge observations as diagnostic clues, not proof of the current server's behaviour.
The original notes describe a different server on macOS.

| Symptom | Check |
| --- | --- |
| Writes time out | A modal dialog, a long operation, or an unavailable bridge. |
| Tracks or tempo differ unexpectedly | The active project or tab changed. |
| A created track cannot be found | Project identity and current track indices. |
| Duplicate edits appear | A retry or concurrent mutation repeated an operation. |
| A bridge version error appears | The packaged server and running script versions differ. |

After a timeout, stop dependent mutations and perform a read-only project check.
Do not assume that cached state proves a healthy write path.
Ask the user to resolve a visible dialog when it blocks progress.
Do not dismiss dialogs, close tabs without saving, delete request files, or force-quit REAPER automatically.
Do not reinstall or reload the bridge to test an imported skill.

If live control remains unavailable, deliver a Lua script, MIDI file, or new `.RPP` project.
State that the user must verify the result in REAPER.

## Author a project file

Read a small project saved by the user's REAPER version as the syntax template.
Write a new file, never overwrite the open project.

- Preserve valid track, item, tempo, and marker structure from the template.
- Copy the instrument state only from an appropriate saved project, with fresh track and FX identifiers.
- Check that referenced plugins and media paths exist on the target system.
- For inline MIDI, follow the template's `HASDATA` tick resolution and `E` event representation.
- Sort events before calculating non-negative delta ticks. Include note-off events.

The upstream example uses `HASDATA 1 960 QN` and `E <delta-ticks> <status> <d1> <d2>`.
Treat 960 as that example's resolution, not a universal constant.
MIDI status and data bytes use hexadecimal in those event lines.
Validate the structure against a saved template before delivery. Plain-text generation alone does not prove playability.

## Offline audio

On macOS, the bundled Swift renderer uses AudioToolbox and Apple's DLS synthesiser.
It needs `swiftc` and the system soundbank. It produces a 44.1 kHz, 16-bit stereo WAV with a release tail.
Build and run a copy in the output directory, with a confirmed unused destination.

```sh
swiftc -O render_midi_macos.swift -o render_midi_macos
./render_midi_macos song.mid song.wav
```

On Linux, use an already available renderer and compatible soundfont, or deliver MIDI and a REAPER project.
Do not claim that the macOS renderer works on Linux. Do not install a renderer or download soundfonts without a separate request.
