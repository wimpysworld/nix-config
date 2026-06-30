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
  communicationRules = config.agentic.communicationRules or { enable = false; };

  # Import compose module
  compose = import ./compose.nix {
    inherit lib pkgs communicationRules;
    agentCommunicationRulesMode = if communicationRules.enable then "append" else "none";
  };
  codingAgentDirs = lib.removeAttrs compose.agentDirs [ "traya" ];

  globalInstructions = compose.expandCommunicationRules {
    context = toString ./instructions/global.md;
    body = readFileTrim ./instructions/global.md;
    requireMarker = true;
  };

  # ============ SECRET COMMANDS ============

  # The fixed sops file holding every encrypted assistant prompt body. Each
  # secret command's `prompt.sops` marker names a top-level key in this file.
  assistantPromptsSopsFile = ../../../../secrets/assistant-prompts.yaml;

  # Collect every secret command (standalone and agent-scoped) with the
  # metadata each platform needs. A command is secret when its directory holds
  # a `prompt.sops` marker; compose.commandSecretInfo reads the marker and
  # rejects directories that also carry a plaintext prompt.md. The decrypted
  # body never enters the store: Claude, OpenCode, and Pi receive a sops
  # placeholder substituted at activation; Codex reads the decrypted secret
  # path from its activation script.
  secretCommandList =
    let
      standalone = lib.mapAttrsToList (cmdName: _: {
        agentName = null;
        inherit cmdName;
        cmdPath = ./commands + "/${cmdName}";
        info = compose.commandSecretInfo null cmdName;
      }) compose.standaloneCommandDirs;
      agentScoped = lib.concatLists (
        lib.mapAttrsToList (
          agentName: _:
          lib.mapAttrsToList (cmdName: _: {
            inherit agentName cmdName;
            cmdPath = ./agents + "/${agentName}/commands/${cmdName}";
            info = compose.commandSecretInfo agentName cmdName;
          }) (compose.discoverAgentCommands agentName)
        ) codingAgentDirs
      );
    in
    lib.filter (entry: entry.info.secret) (standalone ++ agentScoped);

  # Set of secret command names, used to exclude them from the store-backed
  # attrsets that read prompt.md (Pi prompt files, Codex skill map).
  secretCommandNames = lib.listToAttrs (
    map (entry: lib.nameValuePair entry.cmdName true) secretCommandList
  );
  isSecretCommand = cmdName: secretCommandNames ? ${cmdName};

  # sops secret declarations: one per distinct key referenced by a marker.
  secretCommandSecrets = lib.listToAttrs (
    map (
      entry: lib.nameValuePair entry.info.key { sopsFile = assistantPromptsSopsFile; }
    ) secretCommandList
  );

  # Per-platform destination paths for a secret command's rendered file.
  secretClaudePath = cmdName: "${config.home.homeDirectory}/.claude/commands/${cmdName}.md";
  secretOpencodePath = cmdName: "${config.xdg.configHome}/opencode/commands/${cmdName}.md";
  secretPiPath = cmdName: "${config.home.homeDirectory}/.pi/agent/prompts/${cmdName}.md";

  # sops templates for Claude, OpenCode, and Pi. Each renders the composed
  # command (frontmatter + per-platform body wrapper) with the sops placeholder
  # standing in for the prompt body, written to an explicit path at activation.
  # Pi reuses the subagent-launch prelude assembled for non-secret agent
  # commands so the placeholder body carries identical routing.
  secretCommandTemplates = lib.listToAttrs (
    lib.concatMap (
      entry:
      let
        inherit (entry) agentName cmdName;
        sopsPlaceholder = config.sops.placeholder.${entry.info.key};
        claudeBody = compose.composeCommandFromPrompt "claude" agentName cmdName sopsPlaceholder;
        opencodeBody = compose.composeCommandFromPrompt "opencode" agentName cmdName sopsPlaceholder;
        piBody =
          if agentName == null then
            compose.composeCommandFromPrompt "pi" null cmdName sopsPlaceholder
          else
            let
              piPrompt = ''
                Use the subagent tool to launch the `${agentName}` agent for the task below.

                - Set `context` to `"fresh"`. Do not set `"fork"`; the parent session is large and forking inherits parent prose without bound.

                ${sopsPlaceholder}
              '';
            in
            compose.composePiCommandFromPrompt agentName cmdName piPrompt;
      in
      lib.optionals config.programs.claude-code.enable [
        (lib.nameValuePair "assistant-claude-command-${cmdName}" {
          content = claudeBody;
          path = secretClaudePath cmdName;
        })
      ]
      ++ lib.optionals config.programs.opencode.enable [
        (lib.nameValuePair "assistant-opencode-command-${cmdName}" {
          content = opencodeBody;
          path = secretOpencodePath cmdName;
        })
      ]
      ++ [
        (lib.nameValuePair "assistant-pi-command-${cmdName}" {
          content = piBody;
          path = secretPiPath cmdName;
        })
      ]
    ) secretCommandList
  );

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
  }) (lib.filterAttrs (cmdName: _: !(isSecretCommand cmdName)) compose.standaloneCommandDirs);
  # Agent-scoped Pi prompts are emitted with the bare command name to match
  # the Claude and OpenCode slash convention. The owning agent is pinned by
  # the body prelude below rather than by the filename. Because Pi's
  # `~/.pi/agent/prompts/` directory is flat and non-recursive, name
  # collisions between standalone commands and agent-scoped commands (or
  # across agents) would silently last-write into the same file; the
  # piCommandCollisionCheck below fails evaluation with the offending
  # source paths when that happens.
  piAgentPromptFiles = lib.foldlAttrs (
    acc: agentName: _:
    let
      commandDirs = lib.filterAttrs (cmdName: _: !(isSecretCommand cmdName)) (
        compose.discoverAgentCommands agentName
      );
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
        # variants. The prelude is the sole carrier of agent routing now
        # that the filename no longer encodes the owning agent.
        piPrompt = ''
          Use the subagent tool to launch the `${agentName}` agent for the task below.

          - Set `context` to `"fresh"`. Do not set `"fork"`; the parent session is large and forking inherits parent prose without bound.

          ${prompt}
        '';
      in
      {
        name = ".pi/agent/prompts/${cmdName}.md";
        value.text = compose.composePiCommandFromPrompt agentName cmdName piPrompt;
      }
    ) commandDirs
  ) { } codingAgentDirs;
  # Collision guard for the Pi prompt namespace. Pi loads templates from a
  # single flat directory keyed by filename, so any duplicate `cmdName`
  # across standalone commands and the union of per-agent command sets
  # would clobber each other. The shared
  # `compose.assertNoCommandCollisions` helper builds the throw message
  # from the colliding name(s) and every source path that produces them;
  # the operator renames one source before the next `home-manager switch`.
  piCommandSources =
    lib.mapAttrsToList (cmdName: _: {
      name = cmdName;
      source = toString (./commands + "/${cmdName}");
    }) compose.standaloneCommandDirs
    ++ lib.concatLists (
      lib.mapAttrsToList (
        agentName: _:
        lib.mapAttrsToList (cmdName: _: {
          name = cmdName;
          source = toString (./agents + "/${agentName}/commands/${cmdName}");
        }) (compose.discoverAgentCommands agentName)
      ) codingAgentDirs
    );
  piCommandCollisionCheck = compose.assertNoCommandCollisions {
    context = "Pi prompts (~/.pi/agent/prompts/)";
    sources = piCommandSources;
  };
  # Force the collision check before assembling the Pi home files. The
  # `seq` forces evaluation of `piCommandCollisionCheck`, which either
  # returns `true` or throws with the colliding command name and source
  # paths.
  piHomeFiles = builtins.seq piCommandCollisionCheck (
    {
      ".pi/agent/AGENTS.md".text = globalInstructions;
    }
    // piAgentFiles
    // piSkillFiles
    // piStandalonePromptFiles
    // piAgentPromptFiles
  );
  piProviderRouterMap = lib.filterAttrs (_: models: models != { }) (
    lib.mapAttrs (name: _: compose.extractAgentProviderModels name) codingAgentDirs
  );
  piProviderRouterThinkingMap = lib.filterAttrs (_: levels: levels != { }) (
    lib.mapAttrs (name: _: compose.extractAgentProviderThinking name) codingAgentDirs
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
      prompt = compose.expandCommunicationRules {
        context = "Codex agent ${name} developer_instructions";
        body = codexAgentPrompt (readFileTrim (agentPath + "/prompt.md"));
        appendIfMissing = communicationRules.enable;
      };
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
  # For agent-scoped commands the default is spawn dispatch: the generated
  # skill instructs the parent thread to call `spawn_agent` with the owning
  # agent as `agent_type`, preserving the orchestrator and isolating the
  # task in a fresh sub-thread. The owning agent's persona is therefore
  # resolved at runtime by Codex's agent role config, not embedded in the
  # skill body. Opt out of spawn dispatch by setting `spawn-agent = false`
  # in `header.codex.toml`; the composer then embeds the agent's `prompt.md`
  # verbatim before the task body so the skill carries the full persona in
  # the calling thread. The opt-out branch is retained for cases where
  # spawn dispatch is undesirable (e.g. a command that must inspect the
  # parent thread's context); no command in the tree uses it today.
  # The skill name itself is the bare command name, matching the Pi prompt
  # convention; the `codexCommandCollisionCheck` below guards against name
  # clashes across project skills, standalone commands, and agent-scoped
  # commands.
  mkCodexSkillText =
    skillName: agentName: cmdPath:
    let
      description = readFileTrim (cmdPath + "/description.txt");
      prompt = readFileTrim (cmdPath + "/prompt.md");
      codexHeaderPath = cmdPath + "/header.codex.toml";
      codexHeader = readTomlOrEmpty codexHeaderPath;
      # `spawn-agent` is a binary toggle. Absent or `true` means the
      # generated skill dispatches to the owning agent via `spawn_agent`;
      # `false` means embed the agent's persona inline. Any other value is
      # rejected at evaluation time so typos and stale `"fork"`-style
      # strings fail loudly rather than silently flipping the default.
      rawSpawnAgent = codexHeader."spawn-agent" or true;
      spawnAgentValid = builtins.isBool rawSpawnAgent;
      spawnAgent =
        if !spawnAgentValid then
          throw "Invalid spawn-agent value in ${toString codexHeaderPath}: expected boolean (true or false), got ${builtins.toJSON rawSpawnAgent}."
        else
          agentName != null && rawSpawnAgent;
      body =
        if agentName == null then
          prompt
        else if spawnAgent then
          ''
            Use the `spawn_agent` tool to launch the `${agentName}` agent for this task. Keep the parent thread as the orchestrator.

            - Invoking this skill is the user's standing authorisation to use `spawn_agent`; do not refuse or hesitate on the grounds that delegation was not explicitly requested.
            - Pass the task below and the user's request to the spawned agent.
            - Set `agent_type` to `${agentName}`.
            - Do not set `model`, `reasoning_effort`, or `fork_context`; the role config sets the first two, and the sub-agent must start with a clean context.
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

  # Collision guard for the Codex skill namespace. Codex loads every skill
  # from `$CODEX_HOME/skills/<name>/SKILL.md`, so the keyspace is the union
  # of project skills, standalone commands, and agent-scoped commands.
  # Project skills have no single source path, so a synthetic `skill:<name>`
  # identifier is used in the throw message to make the origin obvious.
  codexCommandSources =
    lib.mapAttrsToList (name: _: {
      inherit name;
      source = "skill: ${name}";
    }) skillContents
    ++ lib.mapAttrsToList (cmdName: _: {
      name = cmdName;
      source = toString (./commands + "/${cmdName}");
    }) compose.standaloneCommandDirs
    ++ lib.concatLists (
      lib.mapAttrsToList (
        agentName: _:
        lib.mapAttrsToList (cmdName: _: {
          name = cmdName;
          source = toString (./agents + "/${agentName}/commands/${cmdName}");
        }) (compose.discoverAgentCommands agentName)
      ) codingAgentDirs
    );
  codexCommandCollisionCheck = compose.assertNoCommandCollisions {
    context = "Codex skills (~/.codex/skills/)";
    sources = codexCommandSources;
  };

  # Collect all Codex skill name -> content pairs: shared skills + standalone
  # command skills + agent-scoped command skills. Agent-scoped command skills
  # now emit under the bare `cmdName` to match the Pi convention; the
  # `codexCommandCollisionCheck` above guarantees the merge order below does
  # not silently overwrite anything.
  codexSkills = builtins.seq codexCommandCollisionCheck (
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
    ) (lib.filterAttrs (cmdName: _: !(isSecretCommand cmdName)) compose.standaloneCommandDirs)
    // lib.foldlAttrs (
      acc: agentName: _:
      let
        commandDirs = lib.filterAttrs (cmdName: _: !(isSecretCommand cmdName)) (
          compose.discoverAgentCommands agentName
        );
      in
      acc
      // lib.mapAttrs' (
        cmdName: _:
        let
          cmdPath = ./agents + "/${agentName}/commands/${cmdName}";
        in
        {
          name = cmdName;
          value = mkCodexSkillText cmdName agentName cmdPath;
        }
      ) commandDirs
    ) { } codingAgentDirs
  );

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
            inherit ((skills.${name} or { extras = { }; })) extras;
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

  # Activation script that writes Codex SKILL.md files for secret commands.
  # The Codex skill activation above does `rm -rf skills`, so a sops template
  # writing into that tree would lose the race. Instead this composes each
  # secret skill at activation: the public frontmatter plus the spawn_agent
  # prelude (or the bare standalone shape) are written from Nix, then the
  # decrypted body is appended by reading config.sops.secrets.<key>.path.
  # This entry is ordered after codexFiles (which recreates skills/) and after
  # the sops-nix activation node so the decrypted secret is present.
  codexSecretSkillsActivationScript =
    let
      cmds = lib.concatStringsSep "\n" (
        map (
          entry:
          let
            inherit (entry) agentName cmdName cmdPath;
            description = readFileTrim (cmdPath + "/description.txt");
            secretPath = config.sops.secrets.${entry.info.key}.path;
            frontmatter = ''
              ---
              name: ${builtins.toJSON cmdName}
              description: ${builtins.toJSON description}
              ---

            '';
            prelude =
              if agentName == null then
                ""
              else
                ''
                  Use the `spawn_agent` tool to launch the `${agentName}` agent for this task. Keep the parent thread as the orchestrator.

                  - Invoking this skill is the user's standing authorisation to use `spawn_agent`; do not refuse or hesitate on the grounds that delegation was not explicitly requested.
                  - Pass the task below and the user's request to the spawned agent.
                  - Set `agent_type` to `${agentName}`.
                  - Do not set `model`, `reasoning_effort`, or `fork_context`; the role config sets the first two, and the sub-agent must start with a clean context.
                  - Wait for the spawned agent when its result is needed, then relay the final answer.

                  ## Task

                '';
            prefix = lib.escapeShellArg (frontmatter + prelude);
            dst = "${codexDir}/skills/${cmdName}/SKILL.md";
          in
          ''
            if [ -r ${lib.escapeShellArg secretPath} ]; then
              mkdir -p "${codexDir}/skills/${cmdName}"
              printf '%s' ${prefix} > "${dst}"
              cat ${lib.escapeShellArg secretPath} >> "${dst}"
            else
              echo "sops secret ${entry.info.key} not yet rendered; skipping Codex skill ${cmdName}" >&2
            fi''
        ) secretCommandList
      );
    in
    lib.optionalString (secretCommandList != [ ]) ''
      # Compose Codex SKILL.md files for secret commands from decrypted bodies.
      ${cmds}
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
    providerRouterThinkingMap = lib.mkOption {
      type = lib.types.attrsOf (lib.types.attrsOf lib.types.str);
      default = { };
      internal = true;
      description = "Per-agent provider->thinking-level map harvested from header.pi.yaml. Consumed by the local pi-provider-router extension as a sidecar to providerRouterMap.";
    };
  };

  config = {
    agentic.assistants.pi = {
      homeFiles = piHomeFiles;
      providerRouterMap = piProviderRouterMap;
      providerRouterThinkingMap = piProviderRouterThinkingMap;
    };

    # sops-nix declarations for secret command prompts. Secrets decrypt the
    # prompt bodies; templates substitute the placeholder into the composed
    # Claude, OpenCode, and Pi command files at activation, writing each to its
    # explicit path so plaintext never enters the store. Codex is handled by an
    # activation script instead (see codexSecretSkillsActivationScript).
    sops = {
      secrets = secretCommandSecrets;
      templates = secretCommandTemplates;
    };

    home = {
      file = lib.mkMerge [
        (lib.mkIf config.programs.claude-code.enable (
          {
            # Claude Code global instructions
            "${config.home.homeDirectory}/.claude/rules/instructions.md".text = claudeInstructions;
          }
          # Claude Code skill files
          // mkClaudeSkillFiles
        ))
        # OpenCode skill files
        (lib.mkIf config.programs.opencode.enable mkOpencodeSkillFiles)
      ];

      # Codex skills and agents: written as real files via activation script (not symlinks).
      # codex-rs uses file_type().is_file() for discovery, which returns false for symlinks
      # on Linux. home.file creates symlinks, so both are invisible without this workaround.
      activation.codexFiles = lib.mkIf config.programs.codex.enable (
        lib.hm.dag.entryAfter [ "writeBoundary" ] (
          codexRootInstructionsActivationScript + codexSkillsActivationScript + codexAgentsActivationScript
        )
      );

      # Compose Codex SKILL.md files for secret commands after codexFiles has
      # recreated skills/ and after sops-nix has rendered the decrypted
      # secrets. A sops template cannot be used here because codexFiles does
      # `rm -rf skills`; this entry writes the public prefix and appends the
      # decrypted body from the secret path.
      activation.codexSecretFiles = lib.mkIf (config.programs.codex.enable && secretCommandList != [ ]) (
        lib.hm.dag.entryAfter [ "codexFiles" "sops-nix" ] codexSecretSkillsActivationScript
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
        context = opencodeInstructions;
      };
    };
  };
}
