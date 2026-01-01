{
  config,
  inputs,
  lib,
  pkgs,
  username,
  ...
}:
let
  inherit (pkgs.stdenv) isLinux isDarwin;
  installFor = [ "martin" ];
  # https://github.com/numtide/nix-ai-tools
  claudePackage =
    if isLinux then
      inputs.nix-ai-tools.packages.${pkgs.stdenv.hostPlatform.system}.claude-code
    else if isDarwin then
      pkgs.unstable.claude-code
    else
      pkgs.claude-code;
in
lib.mkIf (lib.elem username installFor) {
  programs = {
    claude-code = {
      enable = true;
      #commands = {
      #  fix-issue = ./fips-compliance-source-code-analysis.md;
      #};
      mcpServers = {
        context7 = {
          type = "http";
          url = "https://mcp.context7.com/mcp";
        };
        nixos = {
          type = "stdio";
          command = "mcp-nixos";
        };
        svelte = {
          type = "http";
          url = "https://mcp.svelte.dev/mcp";
        };
      };
      package = claudePackage;
    };
    vscode = lib.mkIf config.programs.vscode.enable {
      profiles.default = {
        extensions = with pkgs; [
          vscode-marketplace.anthropic.claude-code
        ];
      };
    };
  };
}
