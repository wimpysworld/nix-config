{ pkgs, ... }:
let
  nh-home = pkgs.writeShellApplication {
    name = "nh-home";
    runtimeInputs = with pkgs; [
      bc
      coreutils-full
      nh
    ];
    text = builtins.readFile ./nh-home.sh;
  };
in
{
  home.packages = with pkgs; [ nh-home ];
  programs.fish.shellAliases = {
    build-home = "nh-home build";
    switch-home = "nh-home switch";
  };
}
