{
  config,
  lib,
  ...
}:
let
  inherit (config.noughty) host;
  compositor =
    if host.is.linux && host.is.workstation then
      lib.attrByPath [ host.desktop ] null (import ../../../../lib/wayland-compositors.nix).compositors
    else
      null;
in
{
  imports = [
    ./components/avizo
    ./components/capture
    ./components/fuzzel
    ./components/kanshi
    ./components/picker
    ./components/rofi
    ./components/swaync
    ./components/veila
    ./components/waybar
    ./components/wleave
    ./components/wpaperd
    ./hyprland
    ./wayfire
  ];

  config = lib.mkIf (compositor != null) {
    wayland.systemd.target = compositor.sessionTarget;
  };
}
