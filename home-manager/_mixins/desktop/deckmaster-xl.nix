{ config, username, ... }:
{
  # https://github.com/muesli/deckmaster
  imports = [
    ../console/deckmaster.nix
  ];
  
  home.file = {
    "${config.xdg.configHome}/autostart/deskmaster-xl.desktop".text = "
      [Desktop Entry]
      Name=Deckmaster XL
      Comment=Deckmaster XL
      Type=Application
      Exec=deckmaster -deck /home/${username}/Studio/StreamDeck/Deckmaster-xl/main.deck
      Categories=
      Terminal=false
      NoDisplay=true
      StartupNotify=false";
  };
}
