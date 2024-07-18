{ pkgs, ... }:
let
  default-input = pkgs.writeShellApplication {
    name = "default-input";
    runtimeInputs = with pkgs; [
      coreutils-full
      gnugrep
      gnused
      pulseaudio
    ];
    text = builtins.readFile ./default-input.sh;
  };
in
{
  home.packages = with pkgs; [ default-input ];
}
