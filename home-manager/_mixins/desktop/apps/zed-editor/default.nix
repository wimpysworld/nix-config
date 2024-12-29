{
  lib,
  pkgs,
  username,
  ...
}:
let
  installFor = [ "martin" ];
  inherit (pkgs.stdenv) isLinux;
in
lib.mkIf (lib.elem username installFor && isLinux) {
  catppuccin.zed.enable = true;
  home = {
    packages = with pkgs; [ unstable.zed-editor ];
  };
}
