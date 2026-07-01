{ lib, ... }:
let
  currentDir = ./.;
  serverScripts = [
    "dl"
    "noughty"
    "purge-root-nix-profiles"
  ];
  isDirectoryAndNotTemplate = name: type: type == "directory" && name != "_template";
  directories = lib.filterAttrs isDirectoryAndNotTemplate (builtins.readDir currentDir);
  importDirectory = name: import (currentDir + "/${name}");
  importScript =
    name:
    args@{
      config,
      inputs,
      lib,
      noughtyLib,
      pkgs,
      ...
    }:
    let
      scriptArgs = args // {
        inherit inputs noughtyLib pkgs;
      };
      scriptModule = importDirectory name scriptArgs;
    in
    if builtins.elem name serverScripts then
      scriptModule
    else
      lib.mkIf config.noughty.host.is.workstation scriptModule;
in
{
  imports = lib.mapAttrsToList (name: _: importScript name) directories;
}
