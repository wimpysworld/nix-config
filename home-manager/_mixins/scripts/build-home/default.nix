{ pkgs, ... }:
let
  build-home = pkgs.writeShellApplication {
    name = "build-home";
    runtimeInputs = with pkgs; [
      bc
      coreutils-full
      nh
    ];
    text = builtins.readFile ./build-home.sh;
  };
in
{
  home.packages = with pkgs; [ build-home ];
}
