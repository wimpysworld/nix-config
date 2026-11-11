# Live REAPER control

Use the configured Model Context Protocol (MCP) server. Discover its current tool names and schemas before sending calls.

This repository uses `twelvetake-reaper-mcp` through stdio on NixOS studio workstations.
Its file bridge is `Scripts/reaper_mcp_bridge.lua` under the REAPER resource directory.
The wrapper sets `REAPER_BRIDGE_DIR` to the managed `Scripts/mcp_bridge_data` directory.
Home Manager supplies the bridge, analyser effect, and startup integration.
Do not run an upstream installer, change `__startup.lua`, or launch a second bridge instance.

The upstream skill describes `shiehn/total-reaper-mcp` and its `dsl_*` tools.
Those names and schemas are not the TwelveTake API. Do not send upstream DSL calls to the configured server.

## Tool mapping

These signatures were checked against the packaged TwelveTake 1.11.0 source.
Use the connected tool schema if the installed version differs.

| Operation | TwelveTake tool | Units or limits |
| --- | --- | --- |
| Inspect the project | `get_project_summary`, `get_all_tracks` | Read-only project checks. |
| Read or set tempo | `get_tempo`, `set_tempo(bpm)` | Beats per minute. Inspect tempo markers first. |
| Add a track | `insert_track(index, name)` | Zero-based index, omitted index appends. |
| Create a MIDI item | `create_midi_item(track_index, position, length)` | Position and length are seconds. Read the returned item index. |
| Insert notes | `add_midi_notes_batch(track_index, item_index, notes)` | Notes use `pitch`, `velocity`, `start_beat`, `length_beats`, optional `channel`. |
| Inspect notes | `get_midi_notes(track_index, item_index)` | Re-read after edits because note indices can change. |
| Add an instrument | `track_fx_add_by_name(track_index, fx_name, position)` | Use the installed plugin's exact name. |
| Set track level | `set_track_volume(track_index, volume_db)` | Decibels, not linear amplitude. |
| Render audio | `render_project(output_path, ...)` | Absolute output path, times in seconds, `overwrite=false` by default. |

Note beats are relative to the item start. MIDI channels are zero-based, so channel 10 is `9`.
For `track_fx_add_by_name`, require `ret >= 0`. An `ok: true` response with `ret: -1` does not prove insertion.
At constant tempo, seconds equal quarter-note beats multiplied by `60 / bpm`.
For tempo changes, use verified REAPER time-map functions or generate a Lua script instead of this formula.

## Live sequence

1. Read the project summary and track list without creating a test track.
2. Confirm that the active project matches the user's intended session.
3. Inspect existing instruments, tempo, routing, and selections.
4. Create tracks sequentially, checking each response before dependent calls.
5. Create each item once, then batch its note data into that item.
6. Read the resulting notes and track state before rendering.
7. Render to a new path only when audio output is requested.

TwelveTake wraps mutating tools in undo steps. Separate tool calls do not form one whole-session undo step.
Do not assume that retrying note insertion is idempotent.
ReaSynth supplies a basic melodic sound, not a General MIDI drum kit.
Use an installed drum sampler or deliver drum MIDI with the missing instrument stated.

Rendering uses the project's existing settings, including normalisation, limiting, fades, trim, and pad.
Inspect the response's `processing`, `silent`, and `sound_starts_s` fields before claiming a successful audio result.
A plugin that still loads samples can render silence. Do not start repeated renders without checking the result.
