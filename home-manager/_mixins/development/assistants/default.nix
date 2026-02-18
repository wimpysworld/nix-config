{
  config,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  username = config.noughty.user.name;
  inherit (pkgs.stdenv) isLinux isDarwin;

  # Platform-specific paths
  vscodeUserDir =
    if isLinux then
      "${config.xdg.configHome}/Code/User"
    else if isDarwin then
      "/Users/${username}/Library/Application Support/Code/User"
    else
      throw "Unsupported platform";

  copilotCliDir = "${config.xdg.configHome}/.copilot";
  nvimConfigDir = "${config.xdg.configHome}/nvim";

  # Import compose module
  compose = import ./compose.nix { inherit lib; };

  # ============ CLAUDE CODE ============

  claudeAgents = compose.composeAgents "claude";
  claudeCommands = compose.composeCommands "claude";
  claudeInstructions = compose.composeInstructions "claude";

  # ============ OPENCODE ============

  opencodeAgents = compose.composeAgents "opencode";
  opencodeCommands = compose.composeCommands "opencode";
  opencodeInstructions = compose.composeInstructions "opencode";

  # ============ COPILOT (VSCODE & CLI) ============

  copilotAgents = compose.composeAgents "copilot";
  copilotCommands = compose.composeCommands "copilot";
  copilotInstructions = compose.composeInstructions "copilot";

  # Generate VSCode file entries for agents and commands
  mkVscodeAgentFiles = lib.mapAttrs' (name: content: {
    name = "${vscodeUserDir}/prompts/${name}.agent.md";
    value.text = content;
  }) copilotAgents;

  mkVscodeCommandFiles = lib.mapAttrs' (name: content: {
    name = "${vscodeUserDir}/prompts/${name}.prompt.md";
    value.text = content;
  }) copilotCommands;

  # Copilot CLI activation script (copies files as real files, not symlinks)
  copilotCliActivationScript =
    let
      agentCmds = lib.concatStringsSep "\n" (
        lib.mapAttrsToList (
          name: content:
          let
            escaped = lib.escapeShellArg content;
          in
          ''printf '%s' ${escaped} > "${copilotCliDir}/agents/${name}.agent.md"''
        ) copilotAgents
      );
      commandCmds = lib.concatStringsSep "\n" (
        lib.mapAttrsToList (
          name: content:
          let
            escaped = lib.escapeShellArg content;
          in
          ''printf '%s' ${escaped} > "${copilotCliDir}/prompts/${name}.prompt.md"''
        ) copilotCommands
      );
    in
    ''
      # Create Copilot CLI directories
      mkdir -p "${copilotCliDir}/agents"
      mkdir -p "${copilotCliDir}/prompts"

      # Write agent files
      ${agentCmds}

      # Write command files
      ${commandCmds}

      # Write instructions file
      printf '%s' ${lib.escapeShellArg copilotInstructions} > "${copilotCliDir}/copilot-instructions.md"
    '';

  # ============ CODECOMPANION ============

  codecompanionAgents = compose.composeAgents "codecompanion";
  codecompanionCommands = compose.composeCommands "codecompanion";

  # CodeCompanion rules: agents go in ~/.config/nvim/rules/
  mkCodeCompanionRuleFiles = lib.mapAttrs' (name: content: {
    name = "${nvimConfigDir}/rules/${name}.md";
    value.text = content;
  }) codecompanionAgents;

  # CodeCompanion prompts: commands go in ~/.config/nvim/prompts/codecompanion/
  mkCodeCompanionPromptFiles = lib.mapAttrs' (name: content: {
    name = "${nvimConfigDir}/prompts/codecompanion/${name}.md";
    value.text = content;
  }) codecompanionCommands;

in
lib.mkIf (noughtyLib.isUser [ "martin" ]) {
  home = {
    file = {
      # Claude Code global instructions
      "${config.home.homeDirectory}/.claude/rules/instructions.md".text = claudeInstructions;

      # VSCode Copilot global instructions
      "${vscodeUserDir}/prompts/copilot.instructions.md".text = copilotInstructions;
      # Dummy prompt for VSCode compatibility
      "${vscodeUserDir}/prompts/dummy.prompt.md".text = copilotInstructions;
    }
    # VSCode agent and command files
    // mkVscodeAgentFiles
    // mkVscodeCommandFiles
    # CodeCompanion rules and prompts
    // mkCodeCompanionRuleFiles
    // mkCodeCompanionPromptFiles;

    # Copilot CLI: files copied via activation script (not symlinks)
    # Copilot CLI doesn't follow symlinks due to security concerns
    activation.copilotFiles = lib.hm.dag.entryAfter [ "writeBoundary" ] copilotCliActivationScript;
  };

  programs = {
    claude-code = lib.mkIf config.programs.claude-code.enable {
      # Custom agents (auto-generated from agents/ directory)
      agents = claudeAgents;

      # Reusable commands (auto-generated from commands/ directories)
      commands = claudeCommands;
    };

    opencode = lib.mkIf config.programs.opencode.enable {
      # Custom agents (auto-generated from agents/ directory)
      agents = opencodeAgents;

      # Reusable commands (auto-generated from commands/ directories)
      commands = opencodeCommands;

      # Global rules
      rules = opencodeInstructions;
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
