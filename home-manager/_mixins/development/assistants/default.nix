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
  vscodeUserDir =
    if isLinux then
      "${config.xdg.configHome}/Code/User"
    else if isDarwin then
      "/Users/${username}/Library/Application Support/Code/User"
    else
      throw "Unsupported platform";

  # Read directory and filter for agent/prompt files
  allFiles = builtins.readDir ./.;
  agentFiles = lib.filterAttrs (
    name: type: type == "regular" && lib.hasSuffix ".agent.md" name
  ) allFiles;
  promptFiles = lib.filterAttrs (
    name: type: type == "regular" && lib.hasSuffix ".prompt.md" name
  ) allFiles;

  # Import helper modules
  claudeCodeHelpers = import ./claude-code.nix { inherit lib; };
  opencodeHelpers = import ./opencode.nix { inherit lib; };
  copilotHelpers = import ./copilot.nix {
    inherit config lib agentFiles;
  };

  # Helper to generate VSCode file entries
  mkVscodeFiles =
    files:
    lib.mapAttrs' (name: _: {
      name = "${vscodeUserDir}/prompts/${name}";
      value.text = builtins.readFile (./. + "/${name}");
    }) files;
in
lib.mkIf (lib.elem username installFor) {
  home = {
    file =
      {
        # Special files
        "${vscodeUserDir}/prompts/copilot.instructions.md".text =
          builtins.readFile ./copilot.instructions.md;
        "${vscodeUserDir}/prompts/dummy.prompt.md".text = builtins.readFile ./copilot.instructions.md;

        # Claude Code rules (manual placement for 25.11 compatibility)
        "${config.home.homeDirectory}/.claude/rules/instructions.md".text =
          builtins.readFile ./copilot.instructions.md;
      }
      # VSCode: auto-generated agent and prompt files
      // mkVscodeFiles agentFiles
      // mkVscodeFiles promptFiles;
    # GitHub Copilot CLI: files copied via activation script (see home.activation below)

    # Copy Copilot CLI files as real files (not symlinks)
    # Note: Copilot CLI doesn't follow symlinks due to security concerns
    activation.copilotFiles = lib.hm.dag.entryAfter [ "writeBoundary" ] copilotHelpers.mkCopilotFileCmds;
  };
  programs = {
    claude-code = lib.mkIf config.programs.claude-code.enable {
      # Custom agents (auto-generated from *.agent.md files)
      # Claude Code requires 'name' field in frontmatter
      agents = claudeCodeHelpers.mkClaudeCodeAgents claudeCodeHelpers.transformForClaudeCodeAgent agentFiles;

      # Reusable commands (auto-generated from *.prompt.md files)
      commands = claudeCodeHelpers.mkClaudeFiles claudeCodeHelpers.transformForClaudeCode promptFiles ".prompt";
    };
    opencode = lib.mkIf config.programs.opencode.enable {
      # Custom agents (auto-generated from *.agent.md files)
      agents = opencodeHelpers.mkOpenCodeAgents opencodeHelpers.transformForOpenCodeAgent agentFiles;

      # Reusable commands (auto-generated from *.prompt.md files)
      # Preserves agent: field in frontmatter, replaces ${input:*} with $ARGUMENTS
      commands = opencodeHelpers.mkOpenCodeCommands opencodeHelpers.transformForOpenCodeCommand promptFiles;

      # Global rules from copilot.instructions.md
      rules = builtins.readFile ./copilot.instructions.md;
    };
    vscode = lib.mkIf config.programs.vscode.enable {
      profiles.default = {
        userSettings = {
          "github.copilot.chat.commitMessageGeneration.instructions" = [
            {
              file = "${vscodeUserDir}/prompts/create-conventional-commit.prompt.md";
            }
          ];
        };
      };
    };
  };
}
