# ReaScript

Translate the requested musical change into a small Lua script.

1. Inspect the selected tracks, items, or takes that the task will affect.
2. Define the selection rule, changes, and exclusions before writing the loop.
3. Validate required selections and dependencies before opening an undo block.
4. Use an undo block for project edits and balanced UI refresh calls for bulk work.
5. Sort MIDI after bulk note insertion or edits.
6. Print a brief result with `reaper.ShowConsoleMsg`.

For API confirmation, use `Help > ReaScript documentation` or the [official API reference](https://www.reaper.fm/sdk/reascript/reascripthelp.html).
Use `reaper.Main_OnCommand(id, 0)` for verified native actions.
Resolve extension actions with `reaper.NamedCommandLookup`, then check that the result is non-zero.

Keep musical time explicit. `TimeMap2_timeToQN` and `TimeMap2_QNToTime` convert between seconds and quarter notes.
Use `MIDI_GetPPQPosFromProjQN` to obtain take-relative MIDI tick positions.
Do not assume a fixed tick resolution or constant project tempo.

For errors, obtain the full REAPER console message and line number.
Check API spelling, extension availability, return values, and invalid selections before changing unrelated code.
Return the corrected file and explain its musical effect.

Useful starting requests:

- Colour tracks whose names contain `vox`, without changing their routing.
- Add four bars of supplied chords to the selected track at the edit cursor.
- Add a bass part from chord roots, with explicit rhythm and register.
- Humanise selected notes while preserving pitch, note length, and item boundaries.

After verification, the user can assign the script to a shortcut or toolbar button.
