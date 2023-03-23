{ config, desktop, pkgs, ... }: {
  imports = [
    ./celluloid.nix
    ./dconf-editor.nix
    ./emote.nix
    ./meld.nix
    (./. + "/${desktop}.nix")
  ];

  fonts.fontconfig.enable = true;
  home.packages = with pkgs; [
    (nerdfonts.override { fonts = [ "FiraCode" "UbuntuMono"]; })
    work-sans
    joypixels
    ubuntu_font_family
  ];
  # Accept the joypixels license
  nixpkgs.config.joypixels.acceptLicense = true;

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
