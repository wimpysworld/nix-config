-- 03_generate_chord_progression.lua
-- Writes a 4-bar MIDI chord progression onto the selected track,
-- starting at the edit cursor. The "composer" starter.
--
-- Default progression is i - VI - III - VII in A minor (Am - F - C - G),
-- a common, good-sounding loop. Change the CHORDS table to taste.
--
-- How to run:
--   1. Select one track in REAPER and place the edit cursor where you want the MIDI to start.
--   2. Run this script. A 4-bar MIDI item appears with one chord per bar.
--   3. Assign an instrument to the track and play it.

----------------------------------------------------------------------
-- Settings
-- Each chord is a root MIDI note plus a list of semitone offsets.
-- 60 = middle C. 57 = A below it. Triads here: root, +3 or +4 (third), +7 (fifth).
local CHORDS = {
  { root = 57, offsets = {0, 3, 7} },  -- A minor
  { root = 53, offsets = {0, 4, 7} },  -- F major
  { root = 60, offsets = {0, 4, 7} },  -- C major
  { root = 55, offsets = {0, 4, 7} },  -- G major
}
local BEATS_PER_CHORD = 4   -- one bar of 4/4 per chord
local VELOCITY = 90         -- how hard the notes hit, 1-127
----------------------------------------------------------------------

local track = reaper.GetSelectedTrack(0, 0)
if not track then
  reaper.ShowMessageBox("Select a track first, then run this script.", "claude-composer-reaper", 0)
  return
end

reaper.Undo_BeginBlock()

-- Work out where to start, in quarter notes from the project start.
local cursor_time = reaper.GetCursorPosition()
local start_qn = reaper.TimeMap2_timeToQN(0, cursor_time)
local total_qn = #CHORDS * BEATS_PER_CHORD
local end_qn = start_qn + total_qn

-- Create the MIDI item. The final 'true' means we are giving positions in quarter notes.
local end_time = reaper.TimeMap2_QNToTime(0, end_qn)
local item = reaper.CreateNewMIDIItemInProj(track, cursor_time, end_time, false)
local take = reaper.GetActiveTake(item)

-- Insert each chord, one per BEATS_PER_CHORD block.
for i, chord in ipairs(CHORDS) do
  local chord_start_qn = start_qn + (i - 1) * BEATS_PER_CHORD
  local chord_end_qn = chord_start_qn + BEATS_PER_CHORD
  local start_ppq = reaper.MIDI_GetPPQPosFromProjQN(take, chord_start_qn)
  local end_ppq = reaper.MIDI_GetPPQPosFromProjQN(take, chord_end_qn)
  for _, offset in ipairs(chord.offsets) do
    local pitch = chord.root + offset
    -- MIDI_InsertNote(take, selected, muted, startppq, endppq, channel, pitch, velocity, noSort)
    reaper.MIDI_InsertNote(take, false, false, start_ppq, end_ppq, 0, pitch, VELOCITY, false)
  end
end

reaper.MIDI_Sort(take)
reaper.UpdateArrange()
reaper.Undo_EndBlock("Generate chord progression", -1)

reaper.ShowConsoleMsg("Wrote " .. #CHORDS .. " chords (" .. total_qn .. " beats) to the selected track.\n")

-- Ideas to ask the assistant for next:
--  "add a bassline track playing the root of each chord in eighth notes"
--  "make a version that picks chords from a key I give it"
--  "add a slider-style dialog so I can choose the velocity and number of bars"
