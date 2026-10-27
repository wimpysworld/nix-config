{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
in
lib.mkIf (host.is.linux && host.is.workstation) {
  home.packages = with pkgs; [
    alsa-utils
    playerctl
    pulseaudio
    pulsemixer
    pwvucontrol
  ];
}
