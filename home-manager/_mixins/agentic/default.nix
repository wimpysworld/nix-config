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
  chromiumEnabled = config.programs.chromium.enable || (host.is.linux && host.is.workstation);
  firefoxEnabled = config.programs.firefox.enable || (host.is.linux && host.is.workstation);
  browserAutomationEnabled = chromiumEnabled && firefoxEnabled;
in
{
  imports = lib.mapAttrsToList (name: _: importDirectory name) directories;
  config = lib.mkIf (noughtyLib.userHasTag "developer") {
    home.packages = [
      agentPackages.cubic
      pkgs.tcount
    ]
    ++ lib.optionals browserAutomationEnabled [
      agentPackages.agent-browser
    ];
  };
}
