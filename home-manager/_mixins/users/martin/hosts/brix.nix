{ lib, ... }: {
  imports = [
    ../../../services/keybase.nix
    ../../../services/syncthing.nix
  ];
}
