{
  inputs,
  lib,
  pkgs,
  ...
}:
let
  name = builtins.baseNameOf (builtins.toString ./.);
  hushmicPackage = import ../../desktop/apps/hushmic/package.nix { inherit inputs lib pkgs; };
  shellApplication = pkgs.writeShellApplication {
    inherit name;
    runtimeInputs =
      (with pkgs; [
        coreutils
        gnugrep
        gnused
        pulseaudio
      ])
      ++ lib.optional (hushmicPackage != null) hushmicPackage;
    text = builtins.readFile ./${name}.sh;
  };
in
{
  home.packages = [ shellApplication ];
}
