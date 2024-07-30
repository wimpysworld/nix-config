{
  hostname,
  lib,
  pkgs,
  ...
}:
let
  installOn = [
    "phasma"
    "vader"
  ];
  name = builtins.baseNameOf (builtins.toString ./.);
  shellApplication = pkgs.writeShellApplication {
    inherit name;
    runtimeInputs = with pkgs; [
      bc
      coreutils-full
      gnugrep
      gnused
      playerctl
      pulseaudio
      pulsemixer
    ];
    text = builtins.readFile ./${name}.sh;
  };
in
lib.mkIf (builtins.elem hostname installOn) { home.packages = with pkgs; [ shellApplication ]; }
