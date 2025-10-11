{
  config,
  isInstall,
  isWorkstation,
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
    fwupd.enable = lib.mkDefault isWorkstation;
    hardware.bolt.enable = isInstall;
    irqbalance = lib.mkIf (!config.services.qemuGuest.enable) {
      enable = true;
    };
    smartd.enable = isInstall;
  };
}
