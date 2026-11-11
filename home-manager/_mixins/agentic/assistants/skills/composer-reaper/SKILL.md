# Composer for REAPER

Compose music, write REAPER scripts, and produce editable projects or audio with the tools already available.

Explain the musical result before the code. Prefer Lua for ReaScript because REAPER includes it.

## Choose the workflow

Read the matching reference before work. Resolve bundled paths from this skill's directory, not the current project directory.

| Task | Reference |
| --- | --- |
| Compose a song, loop, or arrangement | [Composition](references/composition.md) |
| First ReaScript | [Getting started](references/getting-started.md) |
| Write or debug Lua, EEL2, or Python scripts | [ReaScript](references/reascript.md) |
| Control the open project through MCP | [Live control](references/live-control.md) and [Bridge recovery](references/bridge-recovery.md) |
| Build an audio or MIDI effect | [JSFX](references/jsfx.md) |
| Separate stems, convert humming, or use music tools | [Music tools](references/music-tools.md) |
| Render a mix or prepare release files | [Release exports](references/release-exports.md) |
| Check imported files and known limits | [Provenance](references/provenance.md) |

## Compose and deliver

1. Establish the genre, mood, tempo, key, length, and required output from the request.
2. When details are optional, choose sensible defaults and state them.
3. Analyse supplied samples or MIDI before choosing harmony and arrangement.
4. Generate note data with a script, with explicit beat positions, lengths, velocities, and channels.
5. Choose live REAPER, an offline renderer, or a new `.RPP` project according to available tools.
6. Check the result and deliver the project, MIDI, or audio with its generator and any missing instrument requirements.

For an editable starting arrangement, use `scripts/05_make_me_a_song.lua`.
Set `GENRE` and `KEY_ROOT` in a writable copy, never in the installed skill.
The script adds drums, bass, chords, melody, section markers, and tempo.
It loads ReaSynth on melodic tracks, but the drum track needs a separate drum instrument.

## Preserve the session

- Confirm the intended project before live edits. Inspect first, then make only the requested changes.
- Save a project copy before new scripts change existing work.
- Wrap generated ReaScript edits in `Undo_BeginBlock` and `Undo_EndBlock`.
- Pair `PreventUIRefresh(1)` with `PreventUIRefresh(-1)` and `UpdateArrange`, including error paths.
- Check API names against REAPER's documentation. Prefer native actions over duplicate implementations.
- Run dependent MCP edits sequentially. Re-read indices after track, item, or note changes.
- After a timeout, inspect the result before retrying. A timeout does not prove that the edit failed.
- Do not delete tracks, discard project tabs, clear bridge files, or terminate REAPER as automatic recovery.
- Use a new output path. Get consent before overwriting audio, projects, or other user files.

Use the existing MCP connection. Do not install another server, replace the bridge, or edit client configuration for this skill.
If live control is unavailable, continue with scripts or offline files.
The bundled Swift renderer works only on macOS. It overwrites its output, so use a confirmed unused path.

## Bundled starters

| File | Behaviour |
| --- | --- |
| `scripts/01_hello_list_tracks.lua` | Lists tracks without project edits. |
| `scripts/02_color_and_route_by_name.lua` | Colours matching tracks. Despite its name, it does not route or create folders. |
| `scripts/03_generate_chord_progression.lua` | Adds four chords at the edit cursor on the selected track. |
| `scripts/04_humanize_selected_midi.lua` | Changes selected note timing and velocity. Review the boundary limit in provenance first. |
| `scripts/05_make_me_a_song.lua` | Adds a genre-based arrangement and changes project tempo. |
| `scripts/render_midi_macos.swift` | Renders General MIDI through Apple's DLS synthesiser. |
| `jsfx/velocity_randomizer.jsfx` | Changes note-on velocity before an instrument. |

Read each starter before adapting it. Keep edits and build outputs in a writable project directory.
Do not run bundled scripts merely to validate skill installation.
