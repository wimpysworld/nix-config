{ lib, ... }: {
  imports = [
    ../../../services/mpris-proxy.nix
    ../../../services/syncthing.nix
  ];
}
