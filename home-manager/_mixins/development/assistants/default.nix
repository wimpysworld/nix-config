{
  config,
  lib,
  ...
}:
let
  inherit (config.noughty) host;
  readFileTrim = path: lib.trim (builtins.readFile path);
  extractYamlField =
    field: path:
    if !(builtins.pathExists path) then
      null
    else
      let
        prefix = "${field}:";
        matches = lib.filter (line: lib.hasPrefix prefix (lib.trim line)) (
          lib.splitString "\n" (builtins.readFile path)
        );
      in
      if matches == [ ] then
        null
      else
        let
          value = lib.trim (lib.removePrefix prefix (lib.trim (builtins.head matches)));
        in
        if value == "" then null else value;

  # Platform-specific paths
  vscodeUserDir =
    if host.is.linux then
      "${config.xdg.configHome}/Code/User"
    else if host.is.darwin then
      "${config.home.homeDirectory}/Library/Application Support/Code/User"
    else
      throw "Unsupported platform";

  copilotCliDir = "${config.xdg.configHome}/.copilot";
  codexDir =
    if config.home.preferXdgDirectories then
      "${config.xdg.configHome}/codex"
    else
      "${config.home.homeDirectory}/.codex";
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

  # ============ SKILLS ============

  skills = compose.composeSkills;

  # Generate home.file entries for Claude Code skills
  # Each skill goes in ~/.claude/skills/<name>/SKILL.md
  mkClaudeSkillFiles = lib.mapAttrs' (name: content: {
    name = "${config.home.homeDirectory}/.claude/skills/${name}/SKILL.md";
    value.text = content;
  }) skills;

  # Generate home.file entries for OpenCode skills
  # Each skill goes in ~/.config/opencode/skills/<name>/SKILL.md
  mkOpencodeSkillFiles = lib.mapAttrs' (name: content: {
    name = "${config.xdg.configHome}/opencode/skills/${name}/SKILL.md";
    value.text = content;
  }) skills;

  # Collect all Codex agent name -> TOML content pairs.
  # codex-rs discovers agent roles by scanning the agents/ directory for .toml
  # files using file_type().is_file(), which returns false for symlinks on Linux.
  # home.file creates symlinks, so agents written via home.file are invisible.
  # Content is written as real files via the activation script below.
  codexAgents = lib.mapAttrs (
    name: _:
    let
      agentPath = ./agents + "/${name}";
      description = readFileTrim (agentPath + "/description.txt");
      prompt = readFileTrim (agentPath + "/prompt.md");
    in
    ''
      name = ${builtins.toJSON name}
      description = ${builtins.toJSON description}
      developer_instructions = ${builtins.toJSON prompt}
    ''
  ) compose.agentDirs;

  # Activation script that writes Codex agent files as real files (not symlinks).
  codexAgentsActivationScript =
    let
      agentCmds = lib.concatStringsSep "\n" (
        lib.mapAttrsToList (
          name: content:
          let
            escaped = lib.escapeShellArg content;
          in
          ''printf '%s' ${escaped} > "${codexDir}/agents/${name}.toml"''
        ) codexAgents
      );
    in
    ''
      # Write Codex agent files as real files (not symlinks).
      # codex-rs skips symlinked .toml files during agent role discovery.
      mkdir -p "${codexDir}/agents"
      ${agentCmds}
    '';

  # Build a Codex skill file (SKILL.md) for a command.
  # Custom prompt support was removed from codex-rs in March 2026. Commands
  # are instead deployed as skills under $CODEX_HOME/skills/ and invoked with
  # $skill-name in the TUI. Each skill requires name and description frontmatter.
  # For agent-scoped commands, the agent's own prompt.md is embedded directly so
  # the skill carries the full persona - codex-rs has no runtime agent resolution.
  mkCodexSkillText =
    skillName: agentName: cmdPath:
    let
      description = readFileTrim (cmdPath + "/description.txt");
      prompt = readFileTrim (cmdPath + "/prompt.md");
      body =
        if agentName == null then
          prompt
        else
          let
            agentPrompt = readFileTrim (./agents + "/${agentName}/prompt.md");
          in
          ''
            ${agentPrompt}

            ## Task

            ${prompt}
          '';
    in
    ''
      ---
      name: ${builtins.toJSON skillName}
      description: ${builtins.toJSON description}
      ---

      ${body}
    '';

  # Collect all Codex skill name -> content pairs: shared skills + standalone
  # command skills + agent-scoped command skills.
  codexSkills =
    skills
    // lib.mapAttrs' (
      cmdName: _:
      let
        cmdPath = ./commands + "/${cmdName}";
      in
      {
        name = cmdName;
        value = mkCodexSkillText cmdName null cmdPath;
      }
    ) compose.standaloneCommandDirs
    // lib.foldlAttrs (
      acc: agentName: _:
      let
        commandDirs = compose.discoverAgentCommands agentName;
      in
      acc
      // lib.mapAttrs' (
        cmdName: _:
        let
          cmdPath = ./agents + "/${agentName}/commands/${cmdName}";
          skillName = "${agentName}-${cmdName}";
        in
        {
          name = skillName;
          value = mkCodexSkillText skillName agentName cmdPath;
        }
      ) commandDirs
    ) { } compose.agentDirs;

  # Activation script that writes Codex skills as real files.
  # codex-rs scans for SKILL.md using entry.file_type() which does NOT follow
  # symlinks on Linux - it returns the type of the symlink itself. The scanner
  # only follows symlinked directories, not symlinked files; it skips symlinked
  # SKILL.md files entirely. home.file creates symlinks, so skills written via
  # home.file are invisible to codex. Writing real files via activation avoids
  # this limitation - same technique used for Copilot CLI above.
  codexSkillsActivationScript =
    let
      skillCmds = lib.concatStringsSep "\n" (
        lib.mapAttrsToList (
          name: content:
          let
            escaped = lib.escapeShellArg content;
          in
          ''
            mkdir -p "${codexDir}/skills/${name}"
            printf '%s' ${escaped} > "${codexDir}/skills/${name}/SKILL.md"''
        ) codexSkills
      );
    in
    ''
      # Write Codex skill files as real files (not symlinks).
      # codex-rs skips symlinked SKILL.md files during discovery.
      ${skillCmds}
    '';

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
      skillCmds = lib.concatStringsSep "\n" (
        lib.mapAttrsToList (
          name: content:
          let
            escaped = lib.escapeShellArg content;
          in
          ''
            mkdir -p "${copilotCliDir}/skills/${name}"
            printf '%s' ${escaped} > "${copilotCliDir}/skills/${name}/SKILL.md"''
        ) skills
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

      # Write skill files
      ${skillCmds}
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
{
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
    // mkCodeCompanionPromptFiles
    # Claude Code skill files
    // mkClaudeSkillFiles
    # OpenCode skill files
    // mkOpencodeSkillFiles;

    # Copilot CLI: files copied via activation script (not symlinks)
    # Copilot CLI doesn't follow symlinks due to security concerns
    activation.copilotFiles = lib.hm.dag.entryAfter [ "writeBoundary" ] copilotCliActivationScript;
    # Codex skills and agents: written as real files via activation script (not symlinks).
    # codex-rs uses file_type().is_file() for discovery, which returns false for symlinks
    # on Linux. home.file creates symlinks, so both are invisible without this workaround.
    activation.codexFiles = lib.mkIf config.programs.codex.enable (
      lib.hm.dag.entryAfter [ "writeBoundary" ] (
        codexSkillsActivationScript + codexAgentsActivationScript
      )
    );
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
