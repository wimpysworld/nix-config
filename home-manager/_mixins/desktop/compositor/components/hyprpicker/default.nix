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
  # hyprpicker is a color picker for Hyprland
  home = {
    packages = with pkgs; [
      hyprpicker
    ];
  };
}
