{ pkgs, ... }: {
  imports = [
    ../services/flatpak.nix
    ../services/sane.nix
  ];

  # Add additional apps and include Yaru for syntax highlighting
  environment.systemPackages = with pkgs; [
    appeditor
    celluloid
    gthumb
    formatter
    torrential
    yaru-theme
  ];

  # Add GNOME Disks, Pantheon Tweaks and Seahorse
  programs = {
    gnome-disks.enable = true;
    pantheon-tweaks.enable = true;
    seahorse.enable = true;
  };

  systemd.services.configure-appcenter-repo = {
    wantedBy = ["multi-user.target"];
    path = [ pkgs.flatpak ];
    script = ''
      flatpak remote-add --if-not-exists appcenter https://flatpak.elementary.io/repo.flatpakrepo
    '';
  };
}
