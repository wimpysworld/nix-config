{ pkgs, ... }:
let
  ipad-volume = pkgs.writeShellApplication {
    name = "ipad-volume";
    runtimeInputs = with pkgs; [
      coreutils-full
      gnugrep
      pulsemixer
    ];
    text = builtins.readFile ./ipad-volume.sh;
  };
in
{
  home.packages = with pkgs; [ ipad-volume ];
}
