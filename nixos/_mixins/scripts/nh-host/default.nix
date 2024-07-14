{ pkgs, ... }:
let
  nh-host = pkgs.writeShellApplication {
    name = "nh-host";
    runtimeInputs = with pkgs; [
      bc
      coreutils-full
      nh
    ];
    text = builtins.readFile ./nh-host.sh;
  };
in
{
  environment.systemPackages = with pkgs; [ nh-host ];
  programs.fish.shellAliases = {
    build-host = "nh-host build";
    switch-host = "nh-host switch";
  };
}
