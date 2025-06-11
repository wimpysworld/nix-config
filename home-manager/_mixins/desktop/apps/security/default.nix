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
lib.mkIf (isLinux && lib.elem username installFor) { 
  home.packages = with pkgs; [ 
    _1password-gui  
    yubioath-flutter
  ];
}