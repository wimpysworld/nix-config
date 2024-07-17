{ pkgs, ... }:
let
  get-cider-volume = pkgs.writeShellApplication {
    name = "get-cider-volume";
    runtimeInputs = with pkgs; [
      bc
      coreutils-full
      gnugrep
      gnused
      playerctl
      pulseaudio
      pulsemixer
    ];
    text = builtins.readFile ./get-cider-volume.sh;
  };
in
{
  home.packages = with pkgs; [ get-cider-volume ];
}
