{ config, lib, pkgs, ... }:
let
  inherit (pkgs.stdenv) isLinux;
in
lib.mkIf isLinux {
  # https://github.com/muesli/deckmaster
  home = {
    file = {
      "${config.xdg.configHome}/autostart/deskmaster-xl.desktop".text = "
        [Desktop Entry]
        Name=Deckmaster XL
        Comment=Deckmaster XL
        Type=Application
        Exec=deckmaster -deck ${config.home.homeDirectory}/Studio/StreamDeck/Deckmaster-xl/main.deck
        Categories=
        Terminal=false
        NoDisplay=true
        StartupNotify=false";
    };
    # Deckmaster and the utilities I bind to the Stream Deck
    packages = with pkgs; [
      alsa-utils
      bc
      deckmaster
      hueadm
      obs-cli
      piper-tts
      playerctl
      pulsemixer
    ];
  };
}
