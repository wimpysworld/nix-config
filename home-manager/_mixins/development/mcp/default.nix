{
  config,
  lib,
  pkgs,
  ...
}:
let
  username = config.noughty.user.name;
  host = config.noughty.host;
  mcpSopsFile = ../../../../secrets/mcp.yaml;
  vscodeUserDir =
    if host.is.linux then
      "${config.xdg.configHome}/Code/User"
    else if host.is.darwin then
      "/Users/${username}/Library/Application Support/Code/User"
    else
      throw "Unsupported platform";

  # Import shared MCP server definitions
  mcpServerDefs = import ./servers.nix { inherit config pkgs; };
  inherit (mcpServerDefs) mcpServers opencodeServers copilotMcpServers;
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
        set -gx JINA_API_KEY (cat ${config.sops.secrets.JINA_API_KEY.path} 2>/dev/null; or echo "")
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
        export JINA_API_KEY=$(cat ${config.sops.secrets.JINA_API_KEY.path} 2>/dev/null || echo "")
        export SEMGREP_APP_TOKEN=$(cat ${config.sops.secrets.SEMGREP_APP_TOKEN.path} 2>/dev/null || echo "")
      '';
    };
    opencode = lib.mkIf config.programs.opencode.enable {
      enableMcpIntegration = true;
      settings = {
        mcp = opencodeServers;
      };
    };
    vscode = lib.mkIf config.programs.vscode.enable {
      profiles.default = {
        userSettings = {
          "chat.mcp.assisted.nuget.enabled" = false;
          "chat.mcp.autostart" = "newAndOutdated";
          "chat.mcp.gallery.enabled" = true;
        };
      };
    };
    zed-editor = lib.mkIf config.programs.zed-editor.enable {
      extensions = [
        "mcp-server-context7"
        #"mcp-server-firecrawl"
        "svelte-mcp"
      ];
      userSettings = {
        context_servers = {
          cloudflare = {
            command = "${pkgs.nodejs_24}/bin/npx";
            args = [
              "-y"
              "mcp-remote"
              "https://docs.mcp.cloudflare.com/mcp"
            ];
          };
          exa = {
            command = "${pkgs.nodejs_24}/bin/npx";
            args = [
              "-y"
              "mcp-remote"
              "https://mcp.exa.ai/mcp"
            ];
          };
          nixos = {
            command = "${pkgs.mcp-nixos}/bin/mcp-nixos";
            args = [ ];
          };
          jina = {
            command = "${pkgs.nodejs_24}/bin/npx";
            args = [
              "-y"
              "mcp-remote"
              "https://mcp.jina.ai/v1?exclude_tools=deduplicate_strings,expand_query,parallel_search_arxiv,parallel_search_ssrn,parallel_search_web,show_api_key,search_arxiv,search_jina_blog,search_ssrn,search_web"
            ];
          };
        };
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
      GITHUB_TOKEN = {
        sopsFile = mcpSopsFile;
      };
      GOOGLE_CSE_API_KEY = {
        sopsFile = mcpSopsFile;
      };
      GOOGLE_CSE_ENGINE_ID = {
        sopsFile = mcpSopsFile;
      };
      JINA_API_KEY = {
        sopsFile = mcpSopsFile;
      };
      SEMGREP_APP_TOKEN = {
        sopsFile = mcpSopsFile;
      };
    };
    # MCP servers - used by other agents
    templates."mcp-config.json" = {
      content = builtins.toJSON { inherit mcpServers; };
      path = "${config.xdg.configHome}/mcp/mcp.json";
    };

    # MCP servers - used by VSCode which expects "servers" key not "mcpServers"
    templates."vscode-mcp-config.json" = lib.mkIf config.programs.vscode.enable {
      content = builtins.toJSON { servers = mcpServers; };
      path = "${vscodeUserDir}/mcp.json";
    };

    # MCP servers - used by GitHub Copilot CLI
    # NOTE: Copilot CLI uses ~/.config/.copilot/ (hidden folder inside .config)
    templates."copilot-cli-mcp-config.json" = {
      content = builtins.toJSON { mcpServers = copilotMcpServers; };
      path = "${config.xdg.configHome}/.copilot/mcp-config.json";
    };
  };
}
