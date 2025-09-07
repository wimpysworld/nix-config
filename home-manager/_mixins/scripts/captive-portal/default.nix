{
  isLaptop,
  lib,
  pkgs,
  ...
}:
let
  inherit (pkgs.stdenv) isLinux;
  name = builtins.baseNameOf (builtins.toString ./.);
  shellApplication = pkgs.writeShellApplication {
    inherit name;
    runtimeInputs = with pkgs; [
      uutils-coreutils-noprefix
      gawk
      iproute2
      xdg-utils
    ];
    text = builtins.readFile ./${name}.sh;
  };
in
lib.mkIf (isLaptop && isLinux) { home.packages = with pkgs; [ shellApplication ]; }
