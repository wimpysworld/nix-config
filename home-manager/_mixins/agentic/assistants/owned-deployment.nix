{
  config,
  lib,
  pkgs,
  ownedFiles,
  requiresSecrets,
}:
let
  home = config.home.homeDirectory;
  stateDir = "${config.xdg.stateHome}/agentic/assistants";
  package = import ./owned-files { inherit pkgs; };
  spec = {
    version = 1;
    inherit home stateDir;
    configHome = config.xdg.configHome;
    roots = lib.unique [
      "${home}/.codex"
      "${config.xdg.configHome}/codex"
      "${home}/.claude"
      "${config.xdg.configHome}/opencode"
      "${home}/.pi/agent"
    ];
    files = ownedFiles;
    retire = lib.optional (
      home == "/home/martin" && config.noughty.host.name == "zannah"
    ) "${home}/.pi/agent/agents/traya.md";
  };
  specFile = pkgs.writeText "assistant-owned-files.json" (builtins.toJSON spec);
in
{
  inherit spec requiresSecrets;
  activation = {
    captureAssistantOwnership =
      lib.hm.dag.entryBetween [ "sops-nix" "linkGeneration" ] [ "writeBoundary" ]
        ''
          run ${pkgs.python3}/bin/python ${./owned-files/bootstrap.py} ${specFile} \
            --old-generation "''${oldGenPath:-}" \
            --output ${lib.escapeShellArg "${stateDir}/bootstrap.json"}
        '';
    assistantOwnedFiles =
      lib.hm.dag.entryAfter
        [
          "writeBoundary"
          "linkGeneration"
          "captureAssistantOwnership"
          "sops-nix"
          "refreshSopsNix"
        ]
        ''
          run ${lib.getExe package} ${specFile} \
            --bootstrap-manifest ${lib.escapeShellArg "${stateDir}/bootstrap.json"}
        '';
  };
}
