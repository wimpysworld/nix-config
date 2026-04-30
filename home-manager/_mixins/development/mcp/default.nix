{
  config,
  lib,
  pkgs,
  ...
}:
let
  mcpSopsFile = ../../../../secrets/mcp.yaml;
  # Import shared MCP server definitions.
  mcpServerDefs = import ./servers.nix { inherit config pkgs; };
  inherit (mcpServerDefs) opencodeServers;

  # Secrets that aren't tied to any active MCP server but still need to be
  # decrypted to disk and exported into the shell. SEMGREP_APP_TOKEN is used
  # by the security scanner skill, not by any MCP server. The disabled
  # *_API_KEY entries belong to firecrawl and mcp-google-cse and stay
  # declared so flipping their global `enabled` flag back on does not need
  # a sops-rekey round-trip.
  additionalSecrets = [
    "FIRECRAWL_API_KEY"
    "GOOGLE_CSE_API_KEY"
    "GOOGLE_CSE_ENGINE_ID"
    "SEMGREP_APP_TOKEN"
  ];

  # Union of canonical-derived secrets (currently CONTEXT7_API_KEY) and the
  # hand-maintained additional set. Drives both `sops.secrets` declarations
  # and the shell init exports below.
  allSecrets = lib.unique (mcpServerDefs.requiredSecrets ++ additionalSecrets);

  fishExport =
    var: "set -gx ${var} (cat ${config.sops.secrets.${var}.path} 2>/dev/null; or echo \"\")";
  bashExport =
    var: "export ${var}=$(cat ${config.sops.secrets.${var}.path} 2>/dev/null || echo \"\")";
in
{
  programs = {
    fish = {
      shellInit = ''
        # Export MCP secrets from sops
        ${lib.concatMapStringsSep "\n" fishExport allSecrets}
      '';
    };
    bash = {
      initExtra = ''
        # Export MCP secrets from sops
        ${lib.concatMapStringsSep "\n" bashExport allSecrets}
      '';
    };
    opencode = lib.mkIf config.programs.opencode.enable {
      enableMcpIntegration = true;
      settings = {
        mcp = opencodeServers;
      };
    };
    zed-editor = lib.mkIf config.programs.zed-editor.enable {
      extensions = mcpServerDefs.zedExtensions;
      userSettings = {
        context_servers = mcpServerDefs.zedContextServers;
      };
    };
  };
  sops = {
    secrets = lib.genAttrs allSecrets (_: {
      sopsFile = mcpSopsFile;
    });
    # MCP servers - used by other agents
    templates."mcp-config.json" = {
      content = builtins.toJSON { mcpServers = mcpServerDefs.claudeServers; };
      path = "${config.xdg.configHome}/mcp/mcp.json";
    };
  };
}
