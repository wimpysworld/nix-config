{ config, hostname, lib, pkgs, ... }:
let
  inherit (pkgs.stdenv) isLinux;
  isStreamstation = if (hostname == "phasma" || hostname == "vader") then true else false;
in
{
  # Deckmaster and the utilities I bind to the Stream Deck
  home = lib.mkIf (isStreamstation) {
    file."/Studio/OBS/config/obs-studio/.keep".text = "";
    packages = with pkgs; [
      alsa-utils
      bc
      deckmaster
      hueadm
      notify-desktop
      obs-cli
      obs-cmd
      piper-tts
      playerctl
      pulsemixer
    ];
  };

  # Linux specific configuration
  systemd.user.tmpfiles = lib.mkIf isLinux {
    rules =  lib.mkIf isStreamstation [
      "L+ ${config.home.homeDirectory}/.config/obs-studio/ - - - - ${config.home.homeDirectory}/Studio/OBS/config/obs-studio/"
    ];
  };
}
