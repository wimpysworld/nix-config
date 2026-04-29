{ config, lib, ... }:
let
  trayaBondSopsFile = ../../../../secrets/hermes-bond.yaml;
  trayaPromptTemplateName = "traya-prompt-with-bond";
  trayaClaudeAgentTemplateName = "traya-claude-agent";
  trayaOpencodeAgentTemplateName = "traya-opencode-agent";
  trayaCodexAgentTemplateName = "traya-codex-agent";
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

  codexDir =
    if config.home.preferXdgDirectories then
      "${config.xdg.configHome}/codex"
    else
      "${config.home.homeDirectory}/.codex";
  # Import compose module
  compose = import ./compose.nix { inherit lib; };

  trayaPromptWithBond = lib.trim ''
    ${builtins.readFile ./agents/traya/prompt.md}
    ${config.sops.placeholder.BOND_MD}
  '';
  trayaDescription = readFileTrim (./agents + "/traya/description.txt");

  # ============ CLAUDE CODE ============

  claudeAgents = lib.removeAttrs (compose.composeAgents "claude") [ "traya" ];
  claudeCommands = compose.composeCommands "claude";
  claudeInstructions = compose.composeInstructions "claude";

  # ============ OPENCODE ============

  opencodeAgents = lib.removeAttrs (compose.composeAgents "opencode") [ "traya" ];
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
  ) (lib.removeAttrs compose.agentDirs [ "traya" ]);

  # Activation script that writes Codex agent files as real files (not symlinks).
  codexAgentsActivationScript =
    let
      cleanupCmds = lib.concatStringsSep "\n" (
        lib.mapAttrsToList (name: _: ''rm -f "${codexDir}/agents/${name}.toml"'') codexAgents
      );
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
      ${cleanupCmds}
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
  # this limitation.
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
      rm -rf "${codexDir}/skills"
      ${skillCmds}
    '';

in
{
  sops = {
    secrets.BOND_MD = {
      sopsFile = trayaBondSopsFile;
      mode = "0400";
    };

    templates.${trayaPromptTemplateName} = {
      content = trayaPromptWithBond;
      mode = "0600";
    };

    templates.${trayaClaudeAgentTemplateName} = {
      content = compose.composeAgentFromPrompt "claude" "traya" trayaPromptWithBond;
      mode = "0600";
    };

    templates.${trayaOpencodeAgentTemplateName} = {
      content = compose.composeAgentFromPrompt "opencode" "traya" trayaPromptWithBond;
      mode = "0600";
    };

    templates.${trayaCodexAgentTemplateName} = {
      content = ''
        name = ${builtins.toJSON "traya"}
        description = ${builtins.toJSON trayaDescription}
        developer_instructions = '''
        ${trayaPromptWithBond}
        '''
      '';
      path = "${codexDir}/agents/traya.toml";
      mode = "0600";
    };
  };

  home = {
    file = {
      # Traya's prompt is rendered via sops-nix at activation time so the bond
      # is appended outside the Nix store. These entries symlink the tool paths
      # to the rendered files.
      "${config.home.homeDirectory}/.claude/agents/traya.md".source =
        config.lib.file.mkOutOfStoreSymlink
          config.sops.templates.${trayaClaudeAgentTemplateName}.path;
      "${config.xdg.configHome}/opencode/agent/traya.md".source =
        config.lib.file.mkOutOfStoreSymlink
          config.sops.templates.${trayaOpencodeAgentTemplateName}.path;

      # Claude Code global instructions
      "${config.home.homeDirectory}/.claude/rules/instructions.md".text = claudeInstructions;
    }
    # Claude Code skill files
    // mkClaudeSkillFiles
    # OpenCode skill files
    // mkOpencodeSkillFiles;

    # Codex skills and agents: written as real files via activation script (not symlinks).
    # codex-rs uses file_type().is_file() for discovery, which returns false for symlinks
    # on Linux. home.file creates symlinks, so both are invisible without this workaround.
    # Run this after sops-nix so Traya's rendered bonded agent file exists before
    # the copy step reads from the rendered templates directory.
    activation.codexFiles = lib.mkIf config.programs.codex.enable (
      lib.hm.dag.entryAfter [ "writeBoundary" "sops-nix" ] (
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
  };
}
