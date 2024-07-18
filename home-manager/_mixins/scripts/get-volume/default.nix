{ pkgs, ... }:
let
  get-volume = pkgs.writeShellApplication {
    name = "get-volume";
    runtimeInputs = with pkgs; [
      coreutils-full
      pulsemixer
    ];
    text = builtins.readFile ./get-volume.sh;
  };
in
{
  home.packages = with pkgs; [ get-volume ];
}
