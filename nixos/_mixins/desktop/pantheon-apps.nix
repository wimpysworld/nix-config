{ pkgs, ... }: {
  imports = [
    ../services/flatpak.nix
    ../services/sane.nix
  ];

  # Add additional apps and include Yaru for syntax highlighting
  environment.systemPackages = with pkgs; [
    appeditor                   # elementary OS menu editor
    celluloid                   # Video Player
    gthumb                      # Image Viewer
    formatter                   # elementary OS filesystem formatter
    gnome.simple-scan           # Scanning
    torrential                  # elementary OS torrent client
    yaru-theme
  ];

  # Add GNOME Disks, Pantheon Tweaks and Seahorse
  programs = {
    gnome-disks.enable = true;
    pantheon-tweaks.enable = true;
    seahorse.enable = true;
  };
}
