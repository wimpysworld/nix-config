{
  lib,
  noughtyLib,
  pkgs,
  ...
}:
lib.mkIf (noughtyLib.hostHasTag "mongodb") {
  services.mongodb = {
    enable = true;
    package = lib.mkDefault pkgs.mongodb-ce;
  };

  environment.shellAliases.mongodb-log = "journalctl _SYSTEMD_UNIT=mongodb.service";
}
