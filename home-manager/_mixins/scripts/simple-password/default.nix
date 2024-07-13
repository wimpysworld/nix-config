{ pkgs, ... }:
let
  simple-password = pkgs.writeShellApplication {
    name = "simple-password";
    runtimeInputs = with pkgs; [ coreutils-full ];
    text = builtins.readFile ./simple-password.sh;
  };
in
{
  home.packages = with pkgs; [ simple-password ];
}
