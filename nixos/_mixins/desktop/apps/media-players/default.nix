{ desktop, hostname, lib, pkgs, username, ... }:
let
  installFor = [ "martin" ];
  isInstall = if (builtins.substring 0 4 hostname != "iso-") then true else false;
in
lib.mkIf (isInstall) {
  environment.systemPackages = with pkgs; [
    celluloid
  ] ++ lib.optionals (builtins.elem username installFor) [
    tartube
  ];

  programs = {
    dconf.profiles.user.databases = [{
      settings = with lib.gvariant; {
        "io/github/celluloid-player/celluloid" = lib.optionalAttrs (desktop != "gnome") {
          csd-enable = false;
        } // {
          dark-theme-enable = true;
        };
      };
    }];
  };
}
