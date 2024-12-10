{
  lib,
  pkgs,
  username,
  ...
}:
let
  installFor = [ "martin" ];
in
lib.mkIf (builtins.elem username installFor) {
  home = {
    packages = with pkgs; [
      cider
      youtube-music
    ];
  };
}
