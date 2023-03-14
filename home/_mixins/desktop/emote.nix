{ config, pkgs, ... }: {
  home = {
    packages = with pkgs; [
      emote
    ];
    file = {
      "${config.xdg.configHome}/autostart/emote.desktop".text = "
[Desktop Entry]
Name=Emote
Type=Application
Comment=Modern popup emoji picker
Exec=emote
Categories=Utility;GTK;
Keywords=emoji
Icon=${pkgs.emote}/share/emote/static/logo.svg
Terminal=false
StartupNotify=false";
    };
  };
}
