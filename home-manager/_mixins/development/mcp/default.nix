{
  config,
  lib,
  pkgs,
  ...
}:
let
  mcpSopsFile = ../../../../secrets/mcp.yaml;
  # Import shared MCP server definitions
  mcpServerDefs = import ./servers.nix { inherit config pkgs; };
  # OpenCode now reads from the canonical renderer; the legacy
  # `mcpServerDefs.opencodeServers` alias remains in `servers.nix` until
  # phase 3 task 3.2 removes it.
  opencodeServers = mcpServerDefs.opencodeServersRendered;
in
{
  programs = {
    fish = {
      shellInit = ''
        # Export MCP secrets from sops
        set -gx CONTEXT7_API_KEY (cat ${config.sops.secrets.CONTEXT7_API_KEY.path} 2>/dev/null; or echo "")
        set -gx FIRECRAWL_API_KEY (cat ${config.sops.secrets.FIRECRAWL_API_KEY.path} 2>/dev/null; or echo "")
        set -gx GOOGLE_CSE_API_KEY (cat ${config.sops.secrets.GOOGLE_CSE_API_KEY.path} 2>/dev/null; or echo "")
        set -gx GOOGLE_CSE_ENGINE_ID (cat ${config.sops.secrets.GOOGLE_CSE_ENGINE_ID.path} 2>/dev/null; or echo "")
        set -gx SEMGREP_APP_TOKEN (cat ${config.sops.secrets.SEMGREP_APP_TOKEN.path} 2>/dev/null; or echo "")
      '';
    };
    bash = {
      initExtra = ''
        # Export MCP secrets from sops
        export CONTEXT7_API_KEY=$(cat ${config.sops.secrets.CONTEXT7_API_KEY.path} 2>/dev/null || echo "")
        export FIRECRAWL_API_KEY=$(cat ${config.sops.secrets.FIRECRAWL_API_KEY.path} 2>/dev/null || echo "")
        export GOOGLE_CSE_API_KEY=$(cat ${config.sops.secrets.GOOGLE_CSE_API_KEY.path} 2>/dev/null || echo "")
        export GOOGLE_CSE_ENGINE_ID=$(cat ${config.sops.secrets.GOOGLE_CSE_ENGINE_ID.path} 2>/dev/null || echo "")
        export SEMGREP_APP_TOKEN=$(cat ${config.sops.secrets.SEMGREP_APP_TOKEN.path} 2>/dev/null || echo "")
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
    secrets = {
      CONTEXT7_API_KEY = {
        sopsFile = mcpSopsFile;
      };
      FIRECRAWL_API_KEY = {
        sopsFile = mcpSopsFile;
      };
      GOOGLE_CSE_API_KEY = {
        sopsFile = mcpSopsFile;
      };
      GOOGLE_CSE_ENGINE_ID = {
        sopsFile = mcpSopsFile;
      };
      # JINA_API_KEY = {
      #   sopsFile = mcpSopsFile;
      # };
      SEMGREP_APP_TOKEN = {
        sopsFile = mcpSopsFile;
      };
    };
    # MCP servers - used by other agents
    templates."mcp-config.json" = {
      content = builtins.toJSON { mcpServers = mcpServerDefs.claudeServers; };
      path = "${config.xdg.configHome}/mcp/mcp.json";
    };
  };
}
