{ lib, ... }: {
  imports = [
    ../../../services/syncthing.nix
  ];
  services.kbfs.enable = lib.mkForce false;
}
