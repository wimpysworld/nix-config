{ lib, ... }: {
  imports = [
    ../../../services/keybase.nix
    ../../../services/maestral.nix
    ../../../services/syncthing.nix
  ];
}
