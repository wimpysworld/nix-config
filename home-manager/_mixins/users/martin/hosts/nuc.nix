{ lib, ... }: {
  imports = [
    ../../../services/maestral.nix
    ../../../services/syncthing.nix
  ];
  services.kbfs.enable = lib.mkForce false;
}
