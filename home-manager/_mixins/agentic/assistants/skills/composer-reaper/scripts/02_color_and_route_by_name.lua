-- 02_color_and_route_by_name.lua
-- Finds tracks whose name contains a keyword, colours them, and prints a summary.
-- This shows the loop that most REAPER utilities are built on:
-- count tracks, read each name, act on the ones that match.
--
-- Edit the two settings below, then run it.
-- It wraps everything in one undo step, so Ctrl+Z reverses the whole thing.

----------------------------------------------------------------------
-- Settings (change these)
local KEYWORD = "vox"        -- match tracks whose name contains this (case-insensitive)
local COLOR_R, COLOR_G, COLOR_B = 200, 60, 60   -- a warm red, 0-255 each
----------------------------------------------------------------------

reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)

-- REAPER wants a native colour value with the "custom colour" flag set (0x1000000).
local native_color = reaper.ColorToNative(COLOR_R, COLOR_G, COLOR_B) | 0x1000000

local matched = 0
local track_count = reaper.CountTracks(0)

for i = 0, track_count - 1 do
  local track = reaper.GetTrack(0, i)
  local ok, name = reaper.GetTrackName(track)
  if name:lower():find(KEYWORD:lower(), 1, true) then
    reaper.SetMediaTrackInfo_Value(track, "I_CUSTOMCOLOR", native_color)
    matched = matched + 1
  end
end

reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()
reaper.Undo_EndBlock("Colour tracks containing '" .. KEYWORD .. "'", -1)

reaper.ShowConsoleMsg("Coloured " .. matched .. " track(s) containing '" .. KEYWORD .. "'.\n")

-- Next step idea to ask the assistant for:
-- "extend this so the matched tracks are also moved into a folder track
--  called VOCALS and routed to a new bus called VOX BUS."
