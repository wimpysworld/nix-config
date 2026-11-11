-- 01_hello_list_tracks.lua
-- The "hello world" of ReaScript. Prints every track name to the console.
-- Safe: it only reads, it changes nothing.
--
-- How to run:
--   1. Copy this file into REAPER's Scripts folder
--      (Options > Show REAPER resource path).
--   2. Actions > Show action list > New action > Load ReaScript, pick this file.
--   3. Run it. A console window lists your tracks.

local track_count = reaper.CountTracks(0)

reaper.ShowConsoleMsg("This project has " .. track_count .. " track(s):\n")

for i = 0, track_count - 1 do
  local track = reaper.GetTrack(0, i)
  -- GetTrackName returns: ok, name
  local ok, name = reaper.GetTrackName(track)
  if name == "" then name = "(unnamed)" end
  reaper.ShowConsoleMsg("  " .. (i + 1) .. ". " .. name .. "\n")
end

if track_count == 0 then
  reaper.ShowConsoleMsg("  (no tracks yet - add a couple and run this again)\n")
end
