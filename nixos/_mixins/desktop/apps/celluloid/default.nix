{
  desktop,
  isInstall,
  lib,
  pkgs,
  ...
}:
lib.mkIf isInstall {
  environment.systemPackages = with pkgs; [ celluloid ];

  programs = {
    dconf.profiles.user.databases = [
      {
        settings = with lib.gvariant; {
          "io/github/celluloid-player/celluloid" =
            lib.optionalAttrs (desktop != "gnome") { csd-enable = false; }
            // {
              dark-theme-enable = true;
            };
        };
      }
    ];
  };
}
