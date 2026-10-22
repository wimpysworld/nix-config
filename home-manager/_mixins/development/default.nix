{
  config,
  noughtyLib,
  lib,
  pkgs,
  ...
}:
let
  currentDir = ./.;
  isDirectoryAndNotTemplate = name: type: type == "directory" && name != "_template";
  directories = lib.filterAttrs isDirectoryAndNotTemplate (builtins.readDir currentDir);
  importDirectory = name: import (currentDir + "/${name}");
  inherit (config.noughty) host;
  isDeveloper = noughtyLib.userHasTag "developer";
  isServerDeveloper = isDeveloper && host.is.server;
  hubPackages = with pkgs; [
    dconf2nix # Nix code from Dconf files
    tokei # Modern Unix `wc` for code
  ];
in
{
  imports = lib.mapAttrsToList (name: _: importDirectory name) directories;
  config = lib.mkIf isDeveloper {
    home = {
      packages = lib.optionals (!isServerDeveloper) hubPackages;
    };
  };
}
