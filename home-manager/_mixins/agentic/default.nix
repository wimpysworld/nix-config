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
  aiSopsFile = ../../../secrets/ai.yaml;
  isDeveloper = noughtyLib.userHasTag "developer";
  isPersonalComputer =
    noughtyLib.isUser [ "martin" ] && host.kind == "computer" && !(noughtyLib.hostHasTag "policy");
  isWorkstationDeveloper = isDeveloper && host.is.workstation;
  chromiumEnabled = config.programs.chromium.enable || (host.is.linux && host.is.workstation);
  firefoxEnabled = config.programs.firefox.enable || (host.is.linux && host.is.workstation);
  browserAutomationEnabled = isWorkstationDeveloper && chromiumEnabled && firefoxEnabled;
in
{
  imports = lib.mapAttrsToList (name: _: importDirectory name) directories;

  options.agentic.personalComputer = lib.mkOption {
    type = lib.types.bool;
    default = isPersonalComputer;
    readOnly = true;
    internal = true;
    description = "Whether the current configuration is for Martin on a physical personal computer.";
  };

  config = lib.mkMerge [
    (lib.mkIf config.agentic.personalComputer {
      sops.secrets.ANTHROPIC_API_KEY = {
        sopsFile = aiSopsFile;
        mode = "0400";
      };
    })

    (lib.mkIf isDeveloper {
      home.packages = [
        pkgs.tcount
      ]
      ++ lib.optionals isWorkstationDeveloper [
        agentPackages.cubic
      ]
      ++ lib.optionals browserAutomationEnabled [
        agentPackages.agent-browser
      ];
    })
  ];
}
