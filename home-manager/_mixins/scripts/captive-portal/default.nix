{ pkgs, ... }:
let
  inherit (pkgs.stdenv) isLinux;
  captive-portal = pkgs.writeShellApplication {
    name = "captive-portal";
    runtimeInputs = with pkgs; [
      gawk
      iproute2
      xdg-utils
    ];
    text = builtins.readFile ./captive-portal.sh;
  };
in
{
  home.packages = with pkgs; lib.optionals isLinux [ captive-portal ];
}
