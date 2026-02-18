{
  config,
  lib,
  ...
}:
let
  currentDir = ./.; # Represents the current directory
  isDirectoryAndNotTemplate = _name: type: type == "directory";
  directories = lib.filterAttrs isDirectoryAndNotTemplate (builtins.readDir currentDir);
  importDirectory = name: import (currentDir + "/${name}");
in
{
  imports = lib.mapAttrsToList (name: _: importDirectory name) directories;

  services = {
    fwupd.enable = lib.mkDefault config.noughty.host.is.workstation;
    hardware.bolt.enable = !config.noughty.host.is.iso;
    irqbalance = lib.mkIf (!config.services.qemuGuest.enable) {
      enable = true;
    };
    smartd.enable = !config.noughty.host.is.iso;
  };
}
