{
  config,
  inputs,
  noughtyLib,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  currentDir = ./.;
  isDirectoryAndNotTemplate = name: type: type == "directory" && name != "_template";
  directories = lib.filterAttrs isDirectoryAndNotTemplate (builtins.readDir currentDir);
  importDirectory = name: import (currentDir + "/${name}");
  system = pkgs.stdenv.hostPlatform.system;
  chromiumEnabled = config.programs.chromium.enable || (host.is.linux && host.is.workstation);
  firefoxEnabled = config.programs.firefox.enable || (host.is.linux && host.is.workstation);
  browserAutomationEnabled = chromiumEnabled && firefoxEnabled;
in
{
  imports = lib.mapAttrsToList (name: _: importDirectory name) directories;
  config = lib.mkIf (noughtyLib.userHasTag "developer") {
    home.packages = lib.optionals browserAutomationEnabled [
      inputs.llm-agents.packages.${system}.agent-browser
    ];
  };
}
