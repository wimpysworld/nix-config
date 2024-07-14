{ pkgs, ... }:
let
  disrun = pkgs.writeShellApplication {
    name = "disrun";
    runtimeInputs = with pkgs; [
      coreutils-full
      util-linux
    ];

    text = builtins.readFile ./disrun.sh;
  };
in
{
  home.packages = with pkgs; [ disrun ];
}
