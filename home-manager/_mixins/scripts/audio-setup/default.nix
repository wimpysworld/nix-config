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
      pipewire
      playerctl
      procps
      rhythmbox
    ];
    text = builtins.readFile ./${name}.sh;
  };
in
lib.mkIf (noughtyLib.isHost [
  "phasma"
  "vader"
]) { home.packages = with pkgs; [ shellApplication ]; }
