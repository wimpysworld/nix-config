{
  config,
  inputs,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  inherit (pkgs.stdenv.hostPlatform) system;
  piPackage = inputs.llm-agents.packages.${system}.pi;
  piMcpAdapterVersion = "2.5.4";
  piMcpAdapterSource = "npm:pi-mcp-adapter@${piMcpAdapterVersion}";

  # Pi's npm package installer uses global npm operations. Nix's default npm
  # global prefix is the read-only store, so give Pi a user-owned prefix while
  # keeping the npm binary itself from Nixpkgs.
  piNpmPackage = pkgs.writeShellApplication {
    name = "pi-npm";
    runtimeInputs = [ pkgs.nodejs ];
    text = ''
      export NPM_CONFIG_PREFIX="${config.home.homeDirectory}/.pi/agent/npm-global"
      exec npm "$@"
    '';
  };

  piSettings = {
    # Versioned Pi package specs are pinned and skipped by `pi update`.
    packages = [ piMcpAdapterSource ];
    npmCommand = [ "${piNpmPackage}/bin/pi-npm" ];
  };

  piMcpConfig = {
    settings = {
      # Keep Pi's MCP surface to the adapter proxy tool. Project-level
      # `.pi/mcp.json` can override these settings when a project needs a
      # deliberately wider tool surface.
      directTools = false;
      disableProxyTool = false;
      autoAuth = false;
      sampling = false;
      samplingAutoApprove = false;
    };
    # The adapter reads the shared server definitions from
    # `~/.config/mcp/mcp.json`; this Home Manager-owned file only carries
    # Pi-specific adapter settings.
    mcpServers = { };
  };
in
lib.mkIf (noughtyLib.userHasTag "developer") {
  home = {
    packages = [
      piPackage
      piNpmPackage
    ];
    file = {
      ".pi/agent/settings.json".text = builtins.toJSON piSettings;
      ".pi/agent/mcp.json".text = builtins.toJSON piMcpConfig;
    };
  };
}
