{
  lib,
  pkgs,
  username,
  ...
}:
let
  inherit (pkgs.stdenv) isLinux;
  installFor = [ "martin" ];
in
lib.mkIf (builtins.elem username installFor) {
  home.packages =
    with pkgs;
    lib.optionals isLinux [
      _1password-gui
      cpu-x
      dconf-editor
      pika-backup
      usbimager
      vaults
    ];

  dconf = lib.mkIf isLinux {
    settings = with lib.hm.gvariant; {
      "ca/desrt/dconf-editor" = {
        show-warning = false;
      };
    };
  };
}
