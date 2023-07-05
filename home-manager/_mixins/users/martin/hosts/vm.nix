{ lib, ... }: {
  imports = [
    ../../../services/mpris-proxy.nix
    ../../../services/syncthing.nix
  ];
  services.kbfs.enable = lib.mkForce false;
}
