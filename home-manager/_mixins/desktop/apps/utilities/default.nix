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
      pika-backup
      usbimager
      vaults
    ];
}
