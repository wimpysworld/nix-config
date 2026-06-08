{
  lib,
  noughtyLib,
  pkgs,
  ...
}:
# Housekeeping note: mongod's stdout/stderr lands in journald (capped by the
# global `services.journald` policy in nixos/default.nix) and the on-disk
# dataset on current hosts is small, so no per-service log rotation or
# WiredTiger cache cap is set here. Revisit if a host ever runs MongoDB as a
# primary store with multi-GB working sets.
lib.mkIf (noughtyLib.hostHasTag "mongodb") {
  services.mongodb = {
    enable = true;
    package = lib.mkDefault pkgs.mongodb-ce;
  };

  environment.shellAliases.mongodb-log = "journalctl _SYSTEMD_UNIT=mongodb.service";
}
