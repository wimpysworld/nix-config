{ config, pkgs, username, ... }:
{
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
      bc
      deckmaster
      hueadm
      libnotify
      unstable.obs-cli
      playerctl
    ];
  };
}
