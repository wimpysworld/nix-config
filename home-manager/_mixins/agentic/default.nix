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
  inherit (pkgs.stdenv.hostPlatform) system;
  agentPackages = inputs.llm-agents.packages.${system};
  isDeveloper = noughtyLib.userHasTag "developer";
  isWorkstationDeveloper = isDeveloper && host.is.workstation;
  chromiumEnabled = config.programs.chromium.enable || (host.is.linux && host.is.workstation);
  firefoxEnabled = config.programs.firefox.enable || (host.is.linux && host.is.workstation);
  browserAutomationEnabled = isWorkstationDeveloper && chromiumEnabled && firefoxEnabled;
in
{
  imports = lib.mapAttrsToList (name: _: importDirectory name) directories;
  config = lib.mkIf isDeveloper {
    home.packages = [
      pkgs.tcount
    ]
    ++ lib.optionals isWorkstationDeveloper [
      agentPackages.cubic
    ]
    ++ lib.optionals browserAutomationEnabled [
      agentPackages.agent-browser
    ];
  };
}
