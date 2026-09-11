{
  config,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  readFileTrim = path: lib.trim (builtins.readFile path);
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
  codexDir =
    if config.home.preferXdgDirectories then
      "${config.xdg.configHome}/codex"
    else
      "${config.home.homeDirectory}/.codex";
  # Import compose module
  compose = import ./compose.nix {
    inherit lib pkgs;
  };
  codingAgentDirs = lib.removeAttrs compose.agentDirs [ "traya" ];

  globalInstructions = readFileTrim ./instructions/global.md;
  piEnabled = noughtyLib.userHasTag "developer";

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

  # sops templates for Claude, OpenCode, and Pi render in private sops paths.
  # The ownership helper links them to the explicit client destinations.
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
                Use the subagent tool to launch the `${(compose.commandMetadata agentName cmdName).compose.agent}` agent for the task below.

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
      ++ lib.optionals piEnabled [
        (lib.nameValuePair "assistant-pi-command-${cmdName}" {
          content = piBody;
          path = secretPiPath cmdName;
        })
      ]
    ) secretCommandList
  );

  # ============ SECRET SKILLS ============

  # Collect every secret skill with the metadata each platform needs. A skill
  # is secret when its directory holds a `SKILL.sops` marker instead of a
  # plaintext `SKILL.md`; supporting `.sops` markers render beside it so
  # progressive disclosure survives encryption. Decrypted bodies stay outside
  # the store. The ownership helper links rendered templates for Claude,
  # OpenCode, and Pi, and copies decrypted files for Codex.
  secretSkillList = lib.mapAttrsToList (skillName: _: {
    name = skillName;
    inherit ((compose.skillSecretInfo skillName)) key;
    supportFiles = compose.secretSkillSupportFiles skillName;
  }) compose.secretSkillDirs;

  # sops secret declarations: one per key referenced by a secret skill's
  # SKILL.sops marker or by any of its supporting markers.
  secretSkillSecrets = lib.listToAttrs (
    lib.concatMap (
      entry:
      [ (lib.nameValuePair entry.key { sopsFile = assistantPromptsSopsFile; }) ]
      ++ map (
        file: lib.nameValuePair file.key { sopsFile = assistantPromptsSopsFile; }
      ) entry.supportFiles
    ) secretSkillList
  );

  # Per-platform destination directory for a secret skill's rendered files.
  secretSkillClaudeDir = name: "${config.home.homeDirectory}/.claude/skills/${name}";
  secretSkillOpencodeDir = name: "${config.xdg.configHome}/opencode/skills/${name}";
  secretSkillPiDir = name: "${config.home.homeDirectory}/.pi/agent/skills/${name}";

  # sops template names double as filenames in the rendered-templates
  # directory, so a supporting file's relative path is flattened into a slug.
  secretSkillFileSlug =
    path:
    lib.replaceStrings
      [
        "/"
        "."
      ]
      [
        "-"
        "-"
      ]
      path;

  # sops templates for one platform. Unlike a secret command there is no public
  # frontmatter or prelude to compose around the body: the encrypted value is
  # the entire file, so each template's content is the placeholder alone.
  mkSecretSkillTemplates =
    platform: skillDir:
    lib.concatMap (
      entry:
      let
        dir = skillDir entry.name;
      in
      [
        (lib.nameValuePair "assistant-${platform}-skill-${entry.name}" {
          content = config.sops.placeholder.${entry.key};
          path = "${dir}/SKILL.md";
        })
      ]
      ++ map (
        file:
        lib.nameValuePair "assistant-${platform}-skill-${entry.name}-${secretSkillFileSlug file.path}" {
          content = config.sops.placeholder.${file.key};
          path = "${dir}/${file.path}";
        }
      ) entry.supportFiles
    ) secretSkillList;

  # Secret destinations follow the same client gates as public files.
  secretSkillTemplates = lib.listToAttrs (
    lib.optionals config.programs.claude-code.enable (
      mkSecretSkillTemplates "claude" secretSkillClaudeDir
    )
    ++ lib.optionals config.programs.opencode.enable (
      mkSecretSkillTemplates "opencode" secretSkillOpencodeDir
    )
    ++ lib.optionals piEnabled (mkSecretSkillTemplates "pi" secretSkillPiDir)
  );

  # ============ CLAUDE CODE ============

  claudeAgents = lib.mapAttrs (name: _: compose.composeAgent "claude" name) codingAgentDirs;
  claudeCommands = compose.composeCommands "claude";
  claudeInstructions = compose.composeInstructions "claude";

  # Claude Code output style carrying the house style. The source file is a
  # complete output style, frontmatter included, so it deploys verbatim with
  # a trailing newline restored after compose.nix trims it.
  claudeHouseStyle = compose.houseStyleOutputStyle + "\n";

  # ============ OPENCODE ============

  # Whether a composed instruction text ends with the house-style body, which is
  # how OpenCode and Pi carry the Communication Rules into their system prompt.
  carriesHouseStyle = text: lib.hasSuffix (compose.houseStyleBody + "\n") text;

  opencodeAgents = lib.mapAttrs (name: _: compose.composeAgent "opencode" name) codingAgentDirs;
  opencodeCommands = compose.composeCommands "opencode";
  # OpenCode has no output-style mechanism, so the house style is appended to
  # the global context instead. The composed instructions already end with a
  # newline, so a single extra newline leaves one blank line between them.
  opencodeInstructions =
    compose.composeInstructions "opencode" + "\n" + compose.houseStyleBody + "\n";

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
  }) piSkills;
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
          Use the subagent tool to launch the `${(compose.commandMetadata agentName cmdName).compose.agent}` agent for the task below.

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
      # Pi has no output-style mechanism, so the house style is appended to
      # the global instructions. `globalInstructions` is trimmed, so two
      # newlines leave one blank line between them.
      ".pi/agent/AGENTS.md".text = globalInstructions + "\n\n" + compose.houseStyleBody + "\n";
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

  piInvocationRoutes = {
    commands = lib.listToAttrs (
      map (
        entry:
        let
          metadata = compose.commandMetadata entry.agentName entry.name;
        in
        {
          inherit (entry) name;
          value =
            lib.optionalAttrs ((metadata.compose or { }) ? agent) { inherit (metadata.compose) agent; }
            // {
              providers = metadata.routing.pi or { };
            };
        }
      ) compose.commandSources
    );
    skills = lib.mapAttrs (
      name: _:
      let
        metadata = compose.readHeader (./skills + "/${name}");
      in
      {
        providers = metadata.routing.pi or { };
      }
    ) (lib.removeAttrs compose.skillDirs [ "delegate-task" ]);
  };

  # ============ SKILLS ============

  # composeSkills returns { name = { content; path; extras; }; ... }
  # where `extras` enumerates sibling files and subdirectories alongside
  # SKILL.md (e.g. references/, rules/, metadata.json) that must be deployed
  # for the skill to function.
  skills = compose.composeSkillsFor "codex";
  claudeSkills = compose.composeSkillsFor "claude";
  opencodeSkills = compose.composeSkillsFor "opencode";
  piSkills = compose.composeSkillsFor "pi";

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
  }) claudeSkills;

  # Generate home.file entries for OpenCode skills.
  # Same approach: symlink the whole skill directory under
  # ${XDG_CONFIG_HOME}/opencode/skills/<name>/.
  mkOpencodeSkillFiles = lib.mapAttrs' (name: skill: {
    name = "${config.xdg.configHome}/opencode/skills/${name}";
    value.source = skill.path;
  }) opencodeSkills;

  # Collect all Codex agent name -> TOML content pairs.
  # codex-rs discovers agent roles by scanning the agents/ directory for .toml
  # files using file_type().is_file(), which returns false for symlinks on Linux.
  # home.file creates symlinks, so agents written via home.file are invisible.
  # Content is written as real files via the activation script below.
  codexRole =
    name: agentName: route:
    let
      agentPath = ./agents + "/${agentName}";
      metadata = compose.headerFor "agent" "codex" agentName agentPath;
    in
    compose.renderToml (
      lib.recursiveUpdate metadata route
      // {
        inherit name;
        developer_instructions = codexAgentPrompt (readFileTrim (agentPath + "/prompt.md"));
      }
    );

  metadataHelpers = import ./metadata.nix { inherit lib; };
  codexCommandDispatch =
    cmdName: agentName: cmdPath:
    metadataHelpers.commandDispatch codingAgentDirs cmdName agentName (compose.readHeader cmdPath);

  codexCommandRoles = lib.listToAttrs (
    lib.concatMap (
      entry:
      let
        path = /. + entry.source;
        dispatch = codexCommandDispatch entry.name entry.agentName path;
      in
      lib.optional (dispatch.route != { }) {
        name = dispatch.role;
        value = codexRole dispatch.role dispatch.selectedAgent dispatch.route;
      }
    ) compose.commandSources
  );
  codexAgents =
    if
      lib.intersectLists (builtins.attrNames codingAgentDirs) (builtins.attrNames codexCommandRoles)
      != [ ]
    then
      throw "A generated Codex command role conflicts with an existing agent."
    else
      lib.mapAttrs (name: _: codexRole name name { }) codingAgentDirs // codexCommandRoles;

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
  # in `header.toml`; the composer then embeds the agent's `prompt.md`
  # verbatim before the task body so the skill carries the full persona in
  # the calling thread. The opt-out branch is retained for cases where
  # spawn dispatch is undesirable (e.g. a command that must inspect the
  # parent thread's context); no command in the tree uses it today.
  # The skill name itself is the bare command name, matching the Pi prompt
  # convention. The `codexCommandCollisionCheck` below guards the full native
  # and command-derived skill namespace.
  mkCodexSkillFromPrompt =
    skillName: agentName: cmdPath: prompt:
    let
      metadata = compose.readHeader cmdPath;
      description = metadata.common.description;
      dispatch = codexCommandDispatch skillName agentName cmdPath;
      body =
        if dispatch.selectedAgent == null then
          prompt
        else if dispatch.spawn then
          ''
              Use the `spawn_agent` tool to launch the `${dispatch.role}` agent for this task. Keep the parent thread as the orchestrator.

              - Invoking this skill is the user's standing authorisation to use `spawn_agent`.
              - Pass the task below and the user's request to the spawned agent.
              - Set `agent_type` to `${dispatch.role}`.
              - Do not set `fork_context`. Start with a clean context.
            - Unless the user explicitly requests a model or effort override, omit `model` and `reasoning_effort`. The role config supplies the defaults.
            - If this runtime cannot apply the user's explicit override to this role, report the limitation and do not launch with the configured default.
              - Wait for the spawned agent when its result is needed, then relay the final answer.

              ## Task

              ${prompt}
          ''
        else
          ''
            ${readFileTrim (./agents + "/${dispatch.selectedAgent}/prompt.md")}

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
  mkCodexSkillText =
    skillName: agentName: cmdPath:
    mkCodexSkillFromPrompt skillName agentName cmdPath (readFileTrim (cmdPath + "/prompt.md"));

  # Command-derived skills always require explicit invocation. A header can
  # repeat the false policy but cannot enable implicit invocation.
  mkCodexCommandOpenAiYaml =
    cmdPath:
    metadataHelpers.renderYaml (
      lib.removeAttrs (metadataHelpers.commandPolicy (compose.readHeader cmdPath)) [
        "allow-implicit-invocation"
      ]
    );

  # Collision guard for the Codex skill namespace. Codex loads every skill
  # from `$CODEX_HOME/skills/<name>/SKILL.md`, so the keyspace is the union
  # of native skills and command-derived skills.
  # Project skills have no single source path, so a synthetic `skill:<name>`
  # identifier is used in the throw message to make the origin obvious. Secret
  # skills are absent from `skillContents`, so they are listed separately;
  # without them a command could silently overwrite a secret skill's directory.
  codexCommandSources =
    lib.mapAttrsToList (name: _: {
      inherit name;
      source = "skill: ${name}";
    }) skillContents
    ++ map (entry: {
      inherit (entry) name;
      source = "skill: ${entry.name}";
    }) secretSkillList
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

  # Collect all Codex skill name -> content pairs: native skills plus
  # standalone and agent-scoped command skills. Agent-scoped command skills
  # emit under the bare `cmdName` to match the Pi convention. The collision
  # check guarantees no source silently overwrites another.
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

  codexStandaloneCommandOpenAiYamls = lib.filterAttrs (_: yaml: yaml != null) (
    lib.mapAttrs (cmdName: _: mkCodexCommandOpenAiYaml (./commands + "/${cmdName}")) (
      lib.filterAttrs (cmdName: _: !(isSecretCommand cmdName)) compose.standaloneCommandDirs
    )
  );
  codexAgentCommandOpenAiYamls = lib.foldlAttrs (
    acc: agentName: _:
    let
      commandDirs = lib.filterAttrs (cmdName: _: !(isSecretCommand cmdName)) (
        compose.discoverAgentCommands agentName
      );
      yamls = lib.filterAttrs (_: yaml: yaml != null) (
        lib.mapAttrs (
          cmdName: _: mkCodexCommandOpenAiYaml (./agents + "/${agentName}/commands/${cmdName}")
        ) commandDirs
      );
    in
    acc // yamls
  ) { } codingAgentDirs;
  codexCommandOpenAiYamls = builtins.seq codexCommandCollisionCheck (
    codexStandaloneCommandOpenAiYamls // codexAgentCommandOpenAiYamls
  );

  ownedFile = path: content: {
    inherit path;
    kind = "file";
    source = toString (pkgs.writeText (builtins.baseNameOf path) content);
    mode = "0600";
  };

  codexOwnedFiles = [
    (ownedFile "${codexDir}/AGENTS.md" (globalInstructions + "\n"))
  ]
  ++ lib.mapAttrsToList (
    name: content: ownedFile "${codexDir}/agents/${name}.toml" content
  ) codexAgents
  ++ lib.concatLists (
    lib.mapAttrsToList (
      name: content:
      [ (ownedFile "${codexDir}/skills/${name}/SKILL.md" content) ]
      ++ lib.mapAttrsToList (entryName: _: {
        path = "${codexDir}/skills/${name}/${entryName}";
        source = "${skills.${name}.path}/${entryName}";
        kind = "symlink";
      }) (skills.${name}.extras or { })
      ++ lib.optional (codexCommandOpenAiYamls ? ${name}) (
        ownedFile "${codexDir}/skills/${name}/agents/openai.yaml" codexCommandOpenAiYamls.${name}
      )
    ) codexSkills
  );

  codexSecretOwnedFiles =
    lib.concatMap (
      entry:
      let
        inherit (entry) agentName cmdName cmdPath;
        openAiYaml = mkCodexCommandOpenAiYaml cmdPath;
      in
      [
        {
          path = "${codexDir}/skills/${cmdName}/SKILL.md";
          source = config.sops.secrets.${entry.info.key}.path;
          prefix = mkCodexSkillFromPrompt cmdName agentName cmdPath "";
          kind = "file";
          mode = "0600";
        }
      ]
      ++ lib.optional (openAiYaml != null) (
        ownedFile "${codexDir}/skills/${cmdName}/agents/openai.yaml" openAiYaml
      )
    ) secretCommandList
    ++ lib.concatMap (
      entry:
      let
        file = key: relativePath: {
          path = "${codexDir}/skills/${entry.name}/${relativePath}";
          source = config.sops.secrets.${key}.path;
          kind = "file";
          mode = "0600";
        };
      in
      [ (file entry.key "SKILL.md") ] ++ map (support: file support.key support.path) entry.supportFiles
    ) secretSkillList;

  secretTemplates = secretCommandTemplates // secretSkillTemplates;
  secretOwnedFiles = lib.mapAttrsToList (name: template: {
    inherit (template) path;
    source = config.sops.templates.${name}.path;
    kind = "symlink";
  }) secretTemplates;
  ownedFiles =
    lib.optionals config.programs.codex.enable (codexOwnedFiles ++ codexSecretOwnedFiles)
    ++ secretOwnedFiles;
  ownedDeployment = import ./owned-deployment.nix {
    inherit
      config
      lib
      pkgs
      ownedFiles
      ;
    requiresSecrets =
      secretOwnedFiles != [ ] || (config.programs.codex.enable && codexSecretOwnedFiles != [ ]);
  };
in
{
  options.agentic.assistants.ownedSpec = lib.mkOption {
    type = lib.types.attrs;
    internal = true;
    description = "Desired assistant files and permitted ownership roots.";
  };
  options.agentic.assistants.requiresSecrets = lib.mkOption {
    type = lib.types.bool;
    internal = true;
    description = "Whether assistant deployment requires a successful secret refresh.";
  };
  options.agentic.assistants.pi = {
    homeFiles = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      internal = true;
      description = "Home Manager file entries for Pi Agent assistant resources.";
    };
    invocationRoutes = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      internal = true;
      description = "Routes applied only at explicit command and skill invocation boundaries.";
    };
    providerRouterMap = lib.mkOption {
      type = lib.types.attrsOf (lib.types.attrsOf lib.types.str);
      default = { };
      internal = true;
      description = "Per-agent provider->modelId map read from header.toml routing.pi. Consumed by the local pi-provider-router extension.";
    };
    providerRouterThinkingMap = lib.mkOption {
      type = lib.types.attrsOf (lib.types.attrsOf lib.types.str);
      default = { };
      internal = true;
      description = "Per-agent provider->thinking-level map read from header.toml routing.pi. Consumed by the local pi-provider-router extension as a sidecar to providerRouterMap.";
    };
  };

  config = {
    agentic.assistants.ownedSpec = ownedDeployment.spec;
    agentic.assistants.requiresSecrets = ownedDeployment.requiresSecrets;
    # Report whether OpenCode and Pi carry the house style in their system
    # prompt. Neither has an output-style mechanism, so the carriage is the
    # append to their global instructions below. The flag is read back from the
    # composed text rather than assumed: drop the append and the Communication
    # Rules tripwire falls back to injecting the full rules on a fresh context.
    agentic.houseStyle.inSystemPrompt = {
      opencode = config.programs.opencode.enable && carriesHouseStyle opencodeInstructions;
      pi = piEnabled && carriesHouseStyle piHomeFiles.".pi/agent/AGENTS.md".text;
    };

    agentic.assistants.pi = {
      homeFiles = piHomeFiles;
      invocationRoutes = piInvocationRoutes;
      providerRouterMap = piProviderRouterMap;
      providerRouterThinkingMap = piProviderRouterThinkingMap;
    };

    # Render secrets privately before the ownership helper installs client files.
    sops = {
      secrets = secretCommandSecrets // secretSkillSecrets;
      templates = lib.mapAttrs (_: template: builtins.removeAttrs template [ "path" ]) secretTemplates;
    };

    home = {
      file = lib.mkMerge [
        (lib.mkIf config.programs.claude-code.enable (
          {
            # Claude Code global instructions
            "${config.home.homeDirectory}/.claude/rules/instructions.md".text = claudeInstructions;

            # Claude Code output style carrying the house style.
            "${config.home.homeDirectory}/.claude/output-styles/house-style.md".text = claudeHouseStyle;
          }
          # Claude Code skill files
          // mkClaudeSkillFiles
        ))
        # OpenCode skill files
        (lib.mkIf config.programs.opencode.enable mkOpencodeSkillFiles)
      ];

      inherit (ownedDeployment) activation;
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
