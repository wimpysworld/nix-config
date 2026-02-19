{
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  name = builtins.baseNameOf (builtins.toString ./.);
  shellApplication = pkgs.writeShellApplication {
    inherit name;
    runtimeInputs = with pkgs; [
      coreutils
      gnugrep
      gnused
      pipewire
      procps
      pulsemixer
    ];
    text = builtins.readFile ./${name}.sh;
  };
in
lib.mkIf (noughtyLib.isHost [
  "phasma"
  "vader"
]) { home.packages = with pkgs; [ shellApplication ]; }
