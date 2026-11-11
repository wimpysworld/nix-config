-- 04_humanize_selected_midi.lua
-- Nudges velocity and timing on the selected MIDI notes so a programmed part
-- feels less rigid. Open a MIDI item in the editor, select some notes, then run.
--
-- It only touches notes you have selected, and it wraps everything in one undo step.

----------------------------------------------------------------------
-- Settings
local VELOCITY_RANGE = 8     -- random velocity change, plus or minus this
local TIMING_RANGE_TICKS = 10 -- random timing shift in MIDI ticks, plus or minus this
----------------------------------------------------------------------

local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
if not take then
  reaper.ShowMessageBox("Open a MIDI item in the MIDI editor and select some notes first.",
    "claude-composer-reaper", 0)
  return
end

reaper.Undo_BeginBlock()

-- Simple random helper returning an integer in [-range, range].
local function jitter(range)
  return math.random(-range, range)
end

local _, note_count = reaper.MIDI_CountEvts(take)
local changed = 0

for i = 0, note_count - 1 do
  local ok, selected, muted, startppq, endppq, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
  if ok and selected then
    -- Velocity stays within 1-127.
    local new_vel = math.max(1, math.min(127, vel + jitter(VELOCITY_RANGE)))
    -- Shift start and end together so note length is preserved.
    local shift = jitter(TIMING_RANGE_TICKS)
    local new_start = math.max(0, startppq + shift)
    local new_end = endppq + shift
    reaper.MIDI_SetNote(take, i, selected, muted, new_start, new_end, chan, pitch, new_vel, true)
    changed = changed + 1
  end
end

reaper.MIDI_Sort(take)
reaper.Undo_EndBlock("Humanize selected MIDI", -1)

reaper.ShowConsoleMsg("Humanized " .. changed .. " selected note(s).\n")

-- Ideas to ask the assistant for next:
--  "make the timing jitter only ever push notes late, never early"
--  "scale the velocity jitter by how loud each note already is"
