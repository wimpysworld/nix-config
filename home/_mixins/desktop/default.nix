{ config, desktop, pkgs, ... }: {
  imports = [
    (./celluloid.nix)
    (./emote.nix)
    (./. + "/${desktop}.nix")
  ];

  home.file = {
    "${config.xdg.configHome}/autostart/enable-flathub.desktop".text = "
[Desktop Entry]
Name=Enable Flathub
Comment=Enable Flathub
Type=Application
Exec=flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
Categories=
Terminal=false
NoDisplay=true
StartupNotify=false";
  };
}
