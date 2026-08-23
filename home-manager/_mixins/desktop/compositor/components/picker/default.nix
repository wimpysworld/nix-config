{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  compositor =
    if host.is.linux && host.is.workstation then
      lib.attrByPath [
        host.desktop
      ] null (import ../../../../../../lib/wayland-compositors.nix).compositors
    else
      null;
  fuzzelPicker = pkgs.writeShellApplication {
    name = "fuzzel-picker";
    runtimeInputs = with pkgs; [
      hyprpicker
      fyi
      wl-clipboard
    ];
    text = builtins.readFile ./fuzzel-picker.sh;
  };
in
lib.mkIf
  (host.is.linux && host.is.workstation && compositor != null && compositor.capabilities.picker)
  {
    # hyprpicker is a colour picker for Wayland compositors.
    home.packages = with pkgs; [
      fuzzelPicker
      hyprpicker
    ];
  }
