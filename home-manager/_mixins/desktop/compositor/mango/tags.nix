# Tag mode for the registry displays. A multi-monitor host whose displays list
# `workspaces` pins each listed tag to its display. Every other host syncs the
# tags, so a tag switch views the same tag on every monitor.
{ host }:
let
  inherit (host) display;
  pinned = display.isMultiMonitor && builtins.any (d: d.workspaces != [ ]) host.displays;
in
{
  inherit pinned;
  synced = !pinned;

  # In pinned mode, the first display that lists a tag owns it.
  outputForTag =
    n:
    let
      owners = builtins.filter (d: builtins.elem n d.workspaces) host.displays;
    in
    if pinned && owners != [ ] then (builtins.head owners).output else null;
}
