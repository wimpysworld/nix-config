{ pkgs, ... }:
let
  default-output = pkgs.writeShellApplication {
    name = "default-output";
    runtimeInputs = with pkgs; [
      coreutils-full
      gnugrep
      gnused
      pulseaudio
    ];
    text = builtins.readFile ./default-output.sh;
  };
in
{
  home.packages = with pkgs; [ default-output ];
}
