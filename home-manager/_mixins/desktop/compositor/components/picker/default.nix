{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
in
lib.mkIf host.is.workstation {
  # hyprpicker is a colour picker for Wayland compositors.
  home = {
    packages = with pkgs; [
      hyprpicker
    ];
  };
}
