{ desktop, lib, pkgs, ... }:
let
  inherit (pkgs.stdenv) isLinux;
in
lib.mkIf isLinux {
  home.packages = with pkgs; [
    celluloid
  ];

  # Only disable CSD on non-GNOME desktops
  dconf.settings = with lib.hm.gvariant; {
    "io/github/celluloid-player/celluloid" = lib.optionalAttrs (desktop != "gnome") {
      csd-enable = false;
    } // {
      dark-theme-enable = true;
    };
  };
}
