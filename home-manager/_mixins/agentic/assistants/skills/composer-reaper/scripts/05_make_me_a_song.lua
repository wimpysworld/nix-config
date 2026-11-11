-- 05_make_me_a_song.lua
-- The "novice mode" headline of claude-composer-reaper.
-- Builds a complete multi-track song in REAPER from one click: drums, bass,
-- chords and melody, with section markers and the tempo set for you. It loads
-- REAPER's stock ReaSynth on the melodic tracks so it makes sound immediately.
--
-- HOW TO RUN
--   1. Open an empty project (or one you don't mind adding tracks to).
--   2. Run this script from the action list.
--   3. Press play. You have a song skeleton. Swap instruments and edit to taste.
--
-- HOW TO CUSTOMISE WITHOUT CODING
--   Change GENRE and KEY below, or just ask your AI assistant things like
--   "make the chorus melody busier" or "add a half-time bridge" and it will
--   edit this file for you. Everything is one undo step (Ctrl+Z) if you dislike it.
--
-- NOTE ON DRUMS: the drum track is written as General MIDI drum notes on
-- channel 10. ReaSynth cannot play a real kit, so the drum track is left for
-- you to point at a drum sampler or VSTi (Kontakt, MT Power Drum Kit, etc.).
-- The notes are correct GM mapping, so any GM drum instrument will just work.

----------------------------------------------------------------------
-- SETTINGS (change these)
local GENRE = "synthwave"  -- lofi | house | synthwave | ambient | rock
local KEY_ROOT = 57        -- root note. 57 = A, 60 = C, 62 = D, etc.
----------------------------------------------------------------------

-- Scale shapes (semitone steps from the root).
local SCALES = {
  major = {0, 2, 4, 5, 7, 9, 11},
  minor = {0, 2, 3, 5, 7, 8, 10},
}

-- Triad shapes.
local TRIAD = { maj = {0, 4, 7}, min = {0, 3, 7} }

-- Genre presets. Each progression entry is {root offset from key, quality}.
-- Drum pattern beats are 1-based within a 4/4 bar (kick/snare); hats are eighths.
local GENRES = {
  synthwave = {
    tempo = 92, scale = "minor",
    progression = { {0,"min"}, {8,"maj"}, {3,"maj"}, {10,"maj"} },  -- i VI III VII
    kick = {1, 3}, snare = {2, 4}, hats = true, melody_sections = {"Chorus"},
  },
  lofi = {
    tempo = 75, scale = "minor",
    progression = { {0,"min"}, {5,"min"}, {8,"maj"}, {3,"maj"} },    -- i iv VI III
    kick = {1, 3}, snare = {3}, hats = true, melody_sections = {"Verse","Chorus"},
  },
  house = {
    tempo = 124, scale = "minor",
    progression = { {0,"min"}, {8,"maj"}, {3,"maj"}, {10,"maj"} },
    kick = {1, 2, 3, 4}, snare = {2, 4}, hats = true, melody_sections = {"Chorus"},
  },
  ambient = {
    tempo = 70, scale = "major",
    progression = { {0,"maj"}, {5,"maj"}, {9,"min"}, {7,"maj"} },    -- I IV vi V
    kick = {1}, snare = {}, hats = false, melody_sections = {"Verse","Chorus"},
  },
  rock = {
    tempo = 120, scale = "major",
    progression = { {0,"maj"}, {7,"maj"}, {9,"min"}, {5,"maj"} },    -- I V vi IV
    kick = {1, 3}, snare = {2, 4}, hats = true, melody_sections = {"Chorus"},
  },
}

-- Arrangement: section name and length in bars. Markers are placed at each start.
local ARRANGEMENT = {
  {"Intro", 4}, {"Verse", 8}, {"Chorus", 8},
  {"Verse", 8}, {"Chorus", 8}, {"Outro", 4},
}

local g = GENRES[GENRE]
if not g then
  reaper.ShowMessageBox("Unknown GENRE '" .. GENRE .. "'. Try: lofi, house, synthwave, ambient, rock.",
    "claude-composer-reaper", 0)
  return
end

local scale = SCALES[g.scale]
math.randomseed(math.floor(reaper.time_precise() * 1000))

----------------------------------------------------------------------
-- Helpers

local function makeTrack(name, r, gcol, b)
  local idx = reaper.CountTracks(0)
  reaper.InsertTrackAtIndex(idx, true)
  local tr = reaper.GetTrack(0, idx)
  reaper.GetSetMediaTrackInfo_String(tr, "P_NAME", name, true)
  reaper.SetMediaTrackInfo_Value(tr, "I_CUSTOMCOLOR", reaper.ColorToNative(r, gcol, b) | 0x1000000)
  return tr
end

local function addSynth(tr)
  reaper.TrackFX_AddByName(tr, "ReaSynth", false, -1)
end

-- Create one MIDI item spanning the whole song on a track; return its take.
local function fullItem(tr, totalQN)
  local endTime = reaper.TimeMap2_QNToTime(0, totalQN)
  local item = reaper.CreateNewMIDIItemInProj(tr, 0, endTime, false)
  return reaper.GetActiveTake(item)
end

local function note(take, startQN, lenQN, pitch, vel, chan)
  local sppq = reaper.MIDI_GetPPQPosFromProjQN(take, startQN)
  local eppq = reaper.MIDI_GetPPQPosFromProjQN(take, startQN + lenQN)
  reaper.MIDI_InsertNote(take, false, false, sppq, eppq, chan or 0, pitch, vel, false)
end

----------------------------------------------------------------------
-- Build

reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)

reaper.SetCurrentBPM(0, g.tempo, true)

local total_bars = 0
for _, sec in ipairs(ARRANGEMENT) do total_bars = total_bars + sec[2] end
local total_qn = total_bars * 4

-- Tracks
local tDrums  = makeTrack("Drums",  200,  80,  80)
local tBass   = makeTrack("Bass",    80, 120, 200)
local tChords = makeTrack("Chords", 120, 180,  90)
local tMelody = makeTrack("Melody", 220, 180,  70)

addSynth(tBass); addSynth(tChords); addSynth(tMelody)
-- Drums left for a real kit (see header note).

local dTake = fullItem(tDrums, total_qn)
local bTake = fullItem(tBass, total_qn)
local cTake = fullItem(tChords, total_qn)
local mTake = fullItem(tMelody, total_qn)

-- GM drum notes
local KICK, SNARE, HAT = 36, 38, 42
local DRUM_CH = 9  -- channel 10

-- Walk the arrangement bar by bar.
local bar = 0
local prog_i = 0
for _, sec in ipairs(ARRANGEMENT) do
  local sec_name, sec_bars = sec[1], sec[2]

  -- Section marker at this bar's start (in seconds).
  local sec_time = reaper.TimeMap2_QNToTime(0, bar * 4)
  reaper.AddProjectMarker2(0, false, sec_time, 0, sec_name, -1, 0)

  local wants_melody = false
  for _, ms in ipairs(g.melody_sections) do if ms == sec_name then wants_melody = true end end
  local light = (sec_name == "Intro" or sec_name == "Outro")

  for b = 1, sec_bars do
    local bar_qn = bar * 4
    prog_i = prog_i + 1
    local chord = g.progression[((prog_i - 1) % #g.progression) + 1]
    local chord_root = KEY_ROOT + chord[1]
    local triad = TRIAD[chord[2]]

    -- Chords: hold the triad for the whole bar.
    for _, off in ipairs(triad) do
      note(cTake, bar_qn, 4, chord_root + off, 70, 0)
    end

    -- Bass: root note, eighth notes (skip in light sections for space).
    if not light then
      for eighth = 0, 7 do
        note(bTake, bar_qn + eighth * 0.5, 0.5, chord_root - 12, 80, 0)
      end
    else
      note(bTake, bar_qn, 4, chord_root - 12, 70, 0)
    end

    -- Drums.
    if not (light and sec_name == "Intro") then
      for _, beat in ipairs(g.kick)  do note(dTake, bar_qn + (beat-1), 0.25, KICK,  100, DRUM_CH) end
      for _, beat in ipairs(g.snare) do note(dTake, bar_qn + (beat-1), 0.25, SNARE,  90, DRUM_CH) end
      if g.hats then
        for eighth = 0, 7 do note(dTake, bar_qn + eighth * 0.5, 0.25, HAT, 70, DRUM_CH) end
      end
    end

    -- Melody: one scale note per beat in melody sections.
    if wants_melody then
      for beat = 0, 3 do
        local deg = scale[math.random(1, #scale)]
        local octave = (math.random(0, 1) == 1) and 12 or 0
        note(mTake, bar_qn + beat, 0.75, KEY_ROOT + deg + 12 + octave, 85, 0)
      end
    end

    bar = bar + 1
  end
end

reaper.MIDI_Sort(dTake); reaper.MIDI_Sort(bTake)
reaper.MIDI_Sort(cTake); reaper.MIDI_Sort(mTake)

reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()
reaper.Undo_EndBlock("Make me a song (" .. GENRE .. ")", -1)

reaper.ShowConsoleMsg(
  "Built a " .. GENRE .. " song: " .. total_bars .. " bars at " .. g.tempo .. " BPM.\n" ..
  "Tracks: Drums (load a kit), Bass, Chords, Melody (ReaSynth loaded).\n" ..
  "Press play. Then edit, or ask your assistant to change the arrangement.\n")
