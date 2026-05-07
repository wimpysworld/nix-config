{
  config,
  lib,
  pkgs,
  ...
}:
let
  readFileTrim = path: lib.trim (builtins.readFile path);
  readFileTrimIfExists = path: if builtins.pathExists path then readFileTrim path else "";
  readTomlOrEmpty =
    path: if builtins.pathExists path then builtins.fromTOML (builtins.readFile path) else { };
  codexAgentPrompt =
    prompt:
    lib.replaceStrings
      [
        "Task tool"
        "Permitted tools: Task tool for delegation, direct conversation"
      ]
      [
        "`spawn_agent` tool"
        "Permitted tools: `spawn_agent` for delegation, direct conversation"
      ]
      prompt;
  tomlMultilineLiteral =
    value: if lib.hasInfix "'''" value then builtins.toJSON value else "'''\n${value}\n'''";
  renderCodexAgentToml =
    {
      name,
      description,
      developerInstructions,
      header ? "",
    }:
    ''
      ${lib.optionalString (header != "") "${header}\n"}
      name = ${builtins.toJSON name}
      description = ${builtins.toJSON description}
      developer_instructions = ${tomlMultilineLiteral developerInstructions}
    '';
  codexDir =
    if config.home.preferXdgDirectories then
      "${config.xdg.configHome}/codex"
    else
      "${config.home.homeDirectory}/.codex";
  # Import compose module
  compose = import ./compose.nix { inherit lib pkgs; };
  codingAgentDirs = lib.removeAttrs compose.agentDirs [ "traya" ];

  globalInstructions = readFileTrim ./instructions/global.md;

  # ============ CLAUDE CODE ============

  claudeAgents = lib.mapAttrs (name: _: compose.composeAgent "claude" name) codingAgentDirs;
  claudeCommands = compose.composeCommands "claude";
  claudeInstructions = compose.composeInstructions "claude";

  # ============ OPENCODE ============

  opencodeAgents = lib.mapAttrs (name: _: compose.composeAgent "opencode" name) codingAgentDirs;
  opencodeCommands = compose.composeCommands "opencode";
  opencodeInstructions = compose.composeInstructions "opencode";

  # ============ PI AGENT ============

  # Pi agent prompts replace Claude's "Task tool" wording with Pi's
  # "subagent tool" terminology so subagent invocation prose is platform-
  # appropriate. The transformation is applied to the agent prompt body
  # before composition; command bodies are unchanged because the subagent-
  # launch boilerplate for agent-scoped commands is composed below.
  piAgentPrompt =
    prompt:
    lib.replaceStrings
      [
        "Task tool"
        "Permitted tools: Task tool for delegation, direct conversation"
      ]
      [
        "subagent tool"
        "Permitted tools: subagent tool for delegation, direct conversation"
      ]
      prompt;
  piAgentFiles = lib.mapAttrs' (
    name: _:
    let
      agentPath = ./agents + "/${name}";
      prompt = readFileTrim (agentPath + "/prompt.md");
    in
    {
      name = ".pi/agent/agents/${name}.md";
      value.text = compose.composeAgentFromPrompt "pi" name (piAgentPrompt prompt);
    }
  ) codingAgentDirs;
  piSkillFiles = lib.mapAttrs' (name: skill: {
    name = ".pi/agent/skills/${name}";
    value.source = skill.path;
  }) skills;
  piStandalonePromptFiles = lib.mapAttrs' (cmdName: _: {
    name = ".pi/agent/prompts/${cmdName}.md";
    value.text = compose.composeCommand "pi" null cmdName;
  }) compose.standaloneCommandDirs;
  piAgentPromptFiles = lib.foldlAttrs (
    acc: agentName: _:
    let
      commandDirs = compose.discoverAgentCommands agentName;
    in
    acc
    // lib.mapAttrs' (
      cmdName: _:
      let
        cmdPath = ./agents + "/${agentName}/commands/${cmdName}";
        prompt = readFileTrim (cmdPath + "/prompt.md");
        # Wrap the command body with Pi's subagent-launch prelude. The
        # prelude is Pi-specific and mirrors how the Codex side wraps
        # spawn_agent guidance around skill bodies; see compose.nix's
        # claude branch for the symmetric `@<agent>` and `use-task`
        # variants.
        piPrompt = ''
          Use the subagent tool to launch the `${agentName}` agent for the task below.

          ${prompt}
        '';
      in
      {
        name = ".pi/agent/prompts/${agentName}-${cmdName}.md";
        value.text = compose.composePiCommandFromPrompt agentName cmdName piPrompt;
      }
    ) commandDirs
  ) { } codingAgentDirs;
  piHomeFiles = {
    ".pi/agent/AGENTS.md".text = globalInstructions;
  }
  // piAgentFiles
  // piSkillFiles
  // piStandalonePromptFiles
  // piAgentPromptFiles;
  piProviderRouterMap = lib.filterAttrs (_: models: models != { }) (
    lib.mapAttrs (name: _: compose.extractAgentProviderModels name) codingAgentDirs
  );

  # ============ SKILLS ============

  # composeSkills returns { name = { content; path; extras; }; ... }
  # where `extras` enumerates sibling files and subdirectories alongside
  # SKILL.md (e.g. references/, rules/, metadata.json) that must be deployed
  # for the skill to function.
  skills = compose.composeSkills;

  # Codex's activation script expects { name = "SKILL.md content"; ... } so
  # it can merge in command-derived skill texts. Project skills only.
  skillContents = lib.mapAttrs (_: skill: skill.content) skills;

  # Generate home.file entries for Claude Code skills.
  # Symlink the entire skill directory so SKILL.md plus all supporting files
  # and subdirectories (references/, rules/, metadata.json, ...) deploy as
  # a single tree under ~/.claude/skills/<name>/.
  mkClaudeSkillFiles = lib.mapAttrs' (name: skill: {
    name = "${config.home.homeDirectory}/.claude/skills/${name}";
    value.source = skill.path;
  }) skills;

  # Generate home.file entries for OpenCode skills.
  # Same approach: symlink the whole skill directory under
  # ${XDG_CONFIG_HOME}/opencode/skills/<name>/.
  mkOpencodeSkillFiles = lib.mapAttrs' (name: skill: {
    name = "${config.xdg.configHome}/opencode/skills/${name}";
    value.source = skill.path;
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
      prompt = codexAgentPrompt (readFileTrim (agentPath + "/prompt.md"));
      header = readFileTrimIfExists (agentPath + "/header.codex.toml");
    in
    renderCodexAgentToml {
      inherit name description;
      developerInstructions = prompt;
      inherit header;
    }
  ) codingAgentDirs;

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
      rm -rf "${codexDir}/agents"
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
      codexHeader = readTomlOrEmpty (cmdPath + "/header.codex.toml");
      spawnAgent = agentName != null && (codexHeader."spawn-agent" or false);
      body =
        if agentName == null then
          prompt
        else if spawnAgent then
          ''
            Use the `spawn_agent` tool to launch the `${agentName}` agent for this task. Keep the parent thread as the orchestrator.

            - Pass the task below and the user's request to the spawned agent.
            - Set `agent_type` to `${agentName}`.
            - Do not set `model` or `reasoning_effort`; the Codex agent role config sets them.
            - Wait for the spawned agent when its result is needed, then relay the final answer.

            ## Task

            ${prompt}
          ''
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
    skillContents
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
    ) { } codingAgentDirs;

  # Activation script that writes Codex skills as real files.
  # codex-rs scans for SKILL.md using entry.file_type() which does NOT follow
  # symlinks on Linux - it returns the type of the symlink itself. The scanner
  # only follows symlinked directories, not symlinked files; it skips symlinked
  # SKILL.md files entirely. home.file creates symlinks, so skills written via
  # home.file are invisible to codex. Writing real files via activation avoids
  # this limitation.
  #
  # Supporting entries beside SKILL.md (e.g. references/, rules/, metadata.json)
  # are symlinked into place. The scanner only inspects SKILL.md itself for the
  # is_file() check, and it does follow symlinked directories, so symlinks for
  # extras are safe and avoid copying large reference trees.
  codexSkillsActivationScript =
    let
      skillCmds = lib.concatStringsSep "\n" (
        lib.mapAttrsToList (
          name: content:
          let
            escaped = lib.escapeShellArg content;
            # Project skills carry `extras`; command-derived skills do not
            # appear in `skills` and so contribute nothing here.
            extras = (skills.${name} or { extras = { }; }).extras;
            extrasCmds = lib.concatStringsSep "\n" (
              lib.mapAttrsToList (
                entryName: _:
                let
                  src = "${skills.${name}.path}/${entryName}";
                  dst = "${codexDir}/skills/${name}/${entryName}";
                in
                "ln -sfn ${lib.escapeShellArg src} ${lib.escapeShellArg dst}"
              ) extras
            );
          in
          ''
            mkdir -p "${codexDir}/skills/${name}"
            printf '%s' ${escaped} > "${codexDir}/skills/${name}/SKILL.md"
            ${extrasCmds}''
        ) codexSkills
      );
    in
    ''
      # Write Codex skill files as real files (not symlinks).
      # codex-rs skips symlinked SKILL.md files during discovery; supporting
      # entries (subdirectories and sibling files) are symlinked into the
      # skill directory beside the real SKILL.md.
      rm -rf "${codexDir}/skills"
      ${skillCmds}
    '';

  codexRootInstructionsActivationScript =
    let
      escaped = lib.escapeShellArg globalInstructions;
    in
    ''
      # Write Codex root instructions from the canonical global prompt.
      mkdir -p "${codexDir}"
      printf '%s\n' ${escaped} > "${codexDir}/AGENTS.md"
    '';

in
{
  options.agentic.assistants.pi = {
    homeFiles = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      internal = true;
      description = "Home Manager file entries for Pi Agent assistant resources.";
    };
    providerRouterMap = lib.mkOption {
      type = lib.types.attrsOf (lib.types.attrsOf lib.types.str);
      default = { };
      internal = true;
      description = "Per-agent provider->modelId map harvested from header.pi.yaml. Consumed by the local pi-provider-router extension.";
    };
  };

  config = {
    agentic.assistants.pi = {
      homeFiles = piHomeFiles;
      providerRouterMap = piProviderRouterMap;
    };

    home = {
      file = {
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
      activation.codexFiles = lib.mkIf config.programs.codex.enable (
        lib.hm.dag.entryAfter [ "writeBoundary" ] (
          codexRootInstructionsActivationScript + codexSkillsActivationScript + codexAgentsActivationScript
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
  };
}
