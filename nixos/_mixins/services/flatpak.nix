{ desktop, lib, pkgs, ... }: {
  services.flatpak.enable = true;
  systemd.services.configure-flathub-repo = {
    wantedBy = ["multi-user.target"];
    path = [ pkgs.flatpak ];
    script = ''
      flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    '';
  };

  systemd.services.configure-appcenter-repo = lib.mkIf (desktop == "pantheon") {
    wantedBy = ["multi-user.target"];
    path = [ pkgs.flatpak ];
    script = ''
      flatpak remote-add --if-not-exists appcenter https://flatpak.elementary.io/repo.flatpakrepo
    '';
  };
}
