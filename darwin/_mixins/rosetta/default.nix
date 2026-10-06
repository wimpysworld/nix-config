{ lib, pkgs, ... }:
let
  installer = pkgs.writeShellApplication {
    name = "install-rosetta";
    text = builtins.readFile ./install-rosetta.sh;
  };
in
lib.mkIf pkgs.stdenv.hostPlatform.isAarch64 {
  system.activationScripts.extraActivation.text = lib.mkBefore ''
    if ! ${lib.getExe installer}; then
      echo "Rosetta setup failed. Activation stopped before Homebrew setup." >&2
      exit 1
    fi
  '';
}
