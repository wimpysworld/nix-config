{ pkgs, ... }:
let
  switch-home = pkgs.writeShellApplication {
    name = "switch-home";
    runtimeInputs = with pkgs; [
      bc
      coreutils-full
      nh
    ];
    text = builtins.readFile ./switch-home.sh;
  };
in
{
  home.packages = with pkgs; [ switch-home ];
}
