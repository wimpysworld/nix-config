{ pkgs, ... }:
let
  nh-all = pkgs.writeShellApplication {
    name = "nh-all";
    runtimeInputs = with pkgs; [ coreutils-full ];
    text = builtins.readFile ./nh-all.sh;
  };
in
{
  environment.systemPackages = with pkgs; [ nh-all ];
  programs.fish.shellAliases = {
    build-all = "nh-all build";
    switch-all = "nh-all switch";
  };
}
