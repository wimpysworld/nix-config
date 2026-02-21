{
  config,
  lib,
  ...
}:
let
  inherit (config.noughty) host;
  currentDir = ./.; # Represents the current directory
  isDirectoryAndNotTemplate = name: type: type == "directory" && name != "_template";
  directories = lib.filterAttrs isDirectoryAndNotTemplate (builtins.readDir currentDir);
  importDirectory = name: import (currentDir + "/${name}");
in
{
  imports = lib.mapAttrsToList (name: _: importDirectory name) directories;

  services = {
    fwupd.enable = lib.mkDefault host.is.workstation;
    hardware.bolt.enable = !host.is.iso;
    irqbalance = lib.mkIf (!config.services.qemuGuest.enable) {
      enable = true;
    };
    smartd.enable = !host.is.iso;
  };
}
