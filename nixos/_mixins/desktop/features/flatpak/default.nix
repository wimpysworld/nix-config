{ desktop, hostname, lib, pkgs, ... }:
let
  inherit (pkgs.stdenv) isLinux;
  isInstall = if (builtins.substring 0 4 hostname != "iso-") then true else false;
in
lib.mkIf isLinux {
  services = {
    flatpak = lib.mkIf (isInstall) {
      enable = true;
      # By default nix-flatpak will add the flathub remote;
      # Therefore Appcenter is only added when the desktop is Pantheon
      remotes = lib.mkIf (desktop == "pantheon") [{
        name = "appcenter";
        location = "https://flatpak.elementary.io/repo.flatpakrepo";
      }];
      update.auto = {
        enable = true;
        onCalendar = "weekly";
      };
    };
  };
}
