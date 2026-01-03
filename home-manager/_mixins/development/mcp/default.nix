{
  config,
  lib,
  pkgs,
  username,
  ...
}:
let
  inherit (pkgs.stdenv) isLinux isDarwin;
  installFor = [ "martin" ];
  mcpSopsFile = ../../../../secrets/mcp.yaml;
  vscodeUserDir =
    if isLinux then
      "${config.xdg.configHome}/Code/User"
    else if isDarwin then
      "/Users/${username}/Library/Application Support/Code/User"
    else
      throw "Unsupported platform";

  # MCP server definitions
  # Uses config.sops.placeholder to inject secrets at activation time
  mcpServers = {
    # Servers without secrets
    nixos = {
      type = "stdio";
      command = "${pkgs.mcp-nixos}/bin/mcp-nixos";
    };
    svelte = {
      type = "http";
      url = "https://mcp.svelte.dev/mcp";
    };
    # Servers with secrets
    context7 = {
      type = "http";
      url = "https://mcp.context7.com/mcp";
      headers = {
        Authorization = "Bearer ${config.sops.placeholder.CONTEXT7_API_KEY}";
      };
    };
    firecrawl-mcp = {
      type = "http";
      url = "https://mcp.firecrawl.dev/${config.sops.placeholder.FIRECRAWL_API_KEY}/v2/mcp";
    };
    mcp-google-cse = {
      type = "stdio";
      command = "${pkgs.uv}/bin/uvx";
      args = [ "mcp-google-cse" ];
      env = {
        API_KEY = config.sops.placeholder.GOOGLE_CSE_API_KEY;
        ENGINE_ID = config.sops.placeholder.GOOGLE_CSE_ENGINE_ID;
      };
    };
  };

  # MCP servers for Copilot CLI - only supports stdio/local with required tools/args arrays
  copilotMcpServers = {
    # Servers without secrets
    nixos = {
      type = "stdio";
      command = "${pkgs.mcp-nixos}/bin/mcp-nixos";
      args = [ ];
      tools = [ "*" ];
    };
    svelte = {
      type = "stdio";
      command = "${pkgs.nodejs_24}/bin/npx";
      args = [
        "-y"
        "@sveltejs/mcp"
      ];
      tools = [ "*" ];
    };
    # Servers with secrets
    context7 = {
      type = "stdio";
      command = "${pkgs.nodejs_24}/bin/npx";
      args = [
        "-y"
        "@upstash/context7-mcp"
        "--api-key"
        config.sops.placeholder.CONTEXT7_API_KEY
      ];
      tools = [ "*" ];
    };
    firecrawl-mcp = {
      type = "stdio";
      command = "${pkgs.nodejs_24}/bin/npx";
      args = [
        "-y"
        "firecrawl-mcp"
      ];
      tools = [ "*" ];
      env = {
        FIRECRAWL_API_KEY = config.sops.placeholder.FIRECRAWL_API_KEY;
      };
    };
    mcp-google-cse = {
      type = "stdio";
      command = "${pkgs.uv}/bin/uvx";
      args = [ "mcp-google-cse" ];
      tools = [ "*" ];
      env = {
        API_KEY = config.sops.placeholder.GOOGLE_CSE_API_KEY;
        ENGINE_ID = config.sops.placeholder.GOOGLE_CSE_ENGINE_ID;
      };
    };
  };
in
lib.mkIf (lib.elem username installFor) {
  programs = {
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
        "mcp-server-brave-search"
        "mcp-server-firecrawl"
        "svelte-mcp"
      ];
      userSettings = {
        context_servers = {
          nixos = {
            command = "${pkgs.mcp-nixos}/bin/mcp-nixos";
            args = [ ];
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
      GOOGLE_CSE_API_KEY = {
        sopsFile = mcpSopsFile;
      };
      GOOGLE_CSE_ENGINE_ID = {
        sopsFile = mcpSopsFile;
      };
      BRAVE_SEARCH_API_KEY = {
        sopsFile = mcpSopsFile;
      };
    };
    # MCP servers - used by Claude Code
    templates."claude-mcp-config.json" = lib.mkIf config.programs.claude-code.enable {
      content = builtins.toJSON { inherit mcpServers; };
      path = "${config.home.homeDirectory}/.config/claude/mcp.json";
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
