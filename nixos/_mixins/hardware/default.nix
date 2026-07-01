{
  config,
  lib,
  noughtyLib,
  ...
}:
let
  inherit (config.noughty) host;
  isOpenStack = noughtyLib.hostHasTag "openstack";
  disableGuestFirmware =
    isOpenStack || (host.is.vm && !host.is.iso && !host.gpu.hasAny && !host.network.wifi);
  currentDir = ./.; # Represents the current directory
  isDirectoryAndNotTemplate = name: type: type == "directory" && name != "_template";
  directories = lib.filterAttrs isDirectoryAndNotTemplate (builtins.readDir currentDir);
  importDirectory = name: import (currentDir + "/${name}");
in
{
  imports = lib.mapAttrsToList (name: _: importDirectory name) directories;

  config = {
    hardware = lib.mkIf disableGuestFirmware {
      enableAllFirmware = lib.mkOverride 900 false;
      enableRedistributableFirmware = lib.mkOverride 900 false;
    };

    services = {
      fwupd.enable = lib.mkDefault host.is.workstation;
      hardware.bolt.enable = lib.mkDefault host.hardware.thunderbolt;
      irqbalance = lib.mkIf (!config.services.qemuGuest.enable) {
        enable = lib.mkDefault (!isOpenStack);
      };
      smartd.enable = lib.mkDefault host.hardware.smart;
    };
  };
}
