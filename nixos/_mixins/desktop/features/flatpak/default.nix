{
  desktop,
  isInstall,
  lib,
  username,
  ...
}:
let
  installFor = [ "martin" ];
in
lib.mkIf (lib.elem username installFor || desktop == "gnome" || desktop == "pantheon") {
  services = {
    flatpak = lib.mkIf isInstall {
      enable = true;
      # By default nix-flatpak will add the flathub remote;
      # Therefore Appcenter is only added when the desktop is Pantheon
      remotes = lib.mkIf (desktop == "pantheon") [
        {
          name = "appcenter";
          location = "https://flatpak.elementary.io/repo.flatpakrepo";
        }
      ];
      update.auto = {
        enable = true;
        onCalendar = "weekly";
      };
    };
  };
}
