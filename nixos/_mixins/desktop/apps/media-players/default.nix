{
  desktop,
  hostname,
  isInstall,
  lib,
  pkgs,
  username,
  ...
}:
let
  installFor = [ "martin" ];
in
lib.mkIf (isInstall) {
  environment.systemPackages =
    with pkgs;
    [ celluloid ] ++ lib.optionals (builtins.elem username installFor) [ tartube ];

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
