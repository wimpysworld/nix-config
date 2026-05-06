{
  config,
  lib,
  pkgs,
  ...
}:
let
  trayaBondSopsFile = ../../../../secrets/hermes-bond.yaml;
  trayaPromptTemplateName = "traya-prompt-with-bond";
  trayaClaudeAgentTemplateName = "traya-claude-agent";
  trayaOpencodeAgentTemplateName = "traya-opencode-agent";
  trayaCodexAgentTemplateName = "traya-codex-agent";
  tomlWriterPython = pkgs.python3.withPackages (ps: [ ps.tomli-w ]);
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
  trayaCodexAgentWriter = pkgs.writeText "write-traya-codex-agent.py" (
    builtins.concatStringsSep "\n" [
      "import pathlib"
      "import sys"
      "import tomllib"
      ""
      "import tomli_w"
      ""
      "def developer_instructions_toml(value):"
      "    if \"'''\" in value:"
      "        return tomli_w.dumps({\"developer_instructions\": value})"
      "    return \"developer_instructions = '''\\n\" + value + \"\\n'''\\n\""
      ""
      "def agent_toml(data):"
      "    data = dict(data)"
      "    developer_instructions = data.pop(\"developer_instructions\")"
      "    return tomli_w.dumps(data) + developer_instructions_toml(developer_instructions)"
      ""
      "prompt_path, description_path, header_path, bond_path, output_path, default_output_path = sys.argv[1:7]"
      "prompt = pathlib.Path(prompt_path).read_text(encoding=\"utf-8\").strip()"
      "prompt = prompt.replace(\"Task tool\", \"`spawn_agent` tool\")"
      "prompt = prompt.replace(\"Permitted tools: `spawn_agent` tool for delegation, direct conversation\", \"Permitted tools: `spawn_agent` for delegation, direct conversation\")"
      "description = pathlib.Path(description_path).read_text(encoding=\"utf-8\").strip()"
      "header = tomllib.loads(pathlib.Path(header_path).read_text(encoding=\"utf-8\"))"
      "bond = pathlib.Path(bond_path).read_text(encoding=\"utf-8\").strip()"
      "developer_instructions = prompt if not bond else f\"{prompt}\\n{bond}\""
      "agent = dict(header)"
      "agent.update({"
      "    \"name\": \"traya\","
      "    \"description\": description,"
      "    \"developer_instructions\": developer_instructions,"
      "})"
      "default_agent = dict(agent)"
      "default_agent[\"name\"] = \"default\""
      "for output_path, data in ((output_path, agent), (default_output_path, default_agent)):"
      "    output = pathlib.Path(output_path)"
      "    output.parent.mkdir(parents=True, exist_ok=True)"
      "    tmp = output.with_name(f\"{output.name}.tmp\")"
      "    tmp.write_text(agent_toml(data), encoding=\"utf-8\")"
      "    tmp.replace(output)"
    ]
    + "\n"
  );
  trayaCodexRootInstructionsWriter = pkgs.writeText "write-traya-codex-root-instructions.py" (
    builtins.concatStringsSep "\n" [
      "import pathlib"
      "import sys"
      ""
      "prompt_path, bond_path, output_path = sys.argv[1:4]"
      "prompt = pathlib.Path(prompt_path).read_text(encoding=\"utf-8\").strip()"
      "prompt = prompt.replace(\"Task tool\", \"`spawn_agent` tool\")"
      "prompt = prompt.replace(\"Permitted tools: `spawn_agent` tool for delegation, direct conversation\", \"Permitted tools: `spawn_agent` for delegation, direct conversation\")"
      "bond = pathlib.Path(bond_path).read_text(encoding=\"utf-8\").strip()"
      "content = prompt if not bond else f\"{prompt}\\n{bond}\""
      "output = pathlib.Path(output_path)"
      "output.parent.mkdir(parents=True, exist_ok=True)"
      "tmp = output.with_name(f\"{output.name}.tmp\")"
      "tmp.write_text(content + \"\\n\", encoding=\"utf-8\")"
      "tmp.chmod(0o600)"
      "tmp.replace(output)"
    ]
    + "\n"
  );

  # ============ CLAUDE CODE ============

  claudeAgents = lib.removeAttrs (compose.composeAgents "claude") [ "traya" ];
  claudeCommands = compose.composeCommands "claude";
  claudeInstructions = compose.composeInstructions "claude";

  # ============ OPENCODE ============

  opencodeAgents = lib.removeAttrs (compose.composeAgents "opencode") [ "traya" ];
  opencodeCommands = compose.composeCommands "opencode";
  opencodeInstructions = compose.composeInstructions "opencode";

  # ============ PI AGENT ============

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
  renderPiMarkdown = header: body: ''
    ---
    ${header}
    ---

    ${body}
  '';
  renderPiAgentMarkdown =
    {
      name,
      description,
      prompt,
    }:
    renderPiMarkdown (lib.concatStringsSep "\n" [
      "name: ${name}"
      "description: ${builtins.toJSON description}"
      "systemPromptMode: append"
      "inheritProjectContext: true"
      "inheritSkills: true"
      "maxSubagentDepth: 0"
    ]) (piAgentPrompt prompt);
  renderPiPromptMarkdown =
    {
      description,
      argumentHint ? null,
      prompt,
    }:
    let
      headerLines = [
        "description: ${builtins.toJSON description}"
      ]
      ++ lib.optional (argumentHint != null) "argument-hint: ${builtins.toJSON argumentHint}";
    in
    renderPiMarkdown (lib.concatStringsSep "\n" headerLines) prompt;
  piTrayaWriter = pkgs.writeText "write-traya-pi-agent.py" (
    builtins.concatStringsSep "\n" [
      "import pathlib"
      "import sys"
      ""
      "prompt_path, description_path, bond_path, output_path = sys.argv[1:5]"
      "prompt = pathlib.Path(prompt_path).read_text(encoding=\"utf-8\").strip()"
      "prompt = prompt.replace(\"Task tool\", \"subagent tool\")"
      "prompt = prompt.replace(\"Permitted tools: subagent tool for delegation, direct conversation\", \"Permitted tools: subagent tool for delegation, direct conversation\")"
      "description = pathlib.Path(description_path).read_text(encoding=\"utf-8\").strip()"
      "bond = pathlib.Path(bond_path).read_text(encoding=\"utf-8\").strip()"
      "body = prompt if not bond else f\"{prompt}\\n{bond}\""
      "content = \"---\\n\""
      "content += \"name: traya\\n\""
      "content += f\"description: {description!r}\\n\""
      "content += \"systemPromptMode: append\\n\""
      "content += \"inheritProjectContext: true\\n\""
      "content += \"inheritSkills: true\\n\""
      "content += \"maxSubagentDepth: 0\\n\""
      "content += \"---\\n\\n\""
      "content += body + \"\\n\""
      "output = pathlib.Path(output_path)"
      "output.parent.mkdir(parents=True, exist_ok=True)"
      "tmp = output.with_name(f\"{output.name}.tmp\")"
      "tmp.write_text(content, encoding=\"utf-8\")"
      "tmp.chmod(0o600)"
      "tmp.replace(output)"
    ]
    + "\n"
  );
  piAgents = lib.removeAttrs compose.agentDirs [ "traya" ];
  piAgentFiles = lib.mapAttrs' (
    name: _:
    let
      agentPath = ./agents + "/${name}";
      description = readFileTrim (agentPath + "/description.txt");
      prompt = readFileTrim (agentPath + "/prompt.md");
    in
    {
      name = ".pi/agent/agents/${name}.md";
      value.text = renderPiAgentMarkdown {
        inherit name description prompt;
      };
    }
  ) piAgents;
  piSkillFiles = lib.mapAttrs' (name: skill: {
    name = ".pi/agent/skills/${name}";
    value.source = skill.path;
  }) skills;
  piStandalonePromptFiles = lib.mapAttrs' (
    cmdName: _:
    let
      cmdPath = ./commands + "/${cmdName}";
      description = readFileTrim (cmdPath + "/description.txt");
      prompt = readFileTrim (cmdPath + "/prompt.md");
      argumentHint = extractYamlField "argument-hint" (cmdPath + "/header.claude.yaml");
    in
    {
      name = ".pi/agent/prompts/${cmdName}.md";
      value.text = renderPiPromptMarkdown {
        inherit description argumentHint prompt;
      };
    }
  ) compose.standaloneCommandDirs;
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
        description = readFileTrim (cmdPath + "/description.txt");
        prompt = readFileTrim (cmdPath + "/prompt.md");
        argumentHint = extractYamlField "argument-hint" (cmdPath + "/header.claude.yaml");
        piPrompt = ''
          Use the subagent tool to launch the `${agentName}` agent for the task below.

          ${prompt}
        '';
      in
      {
        name = ".pi/agent/prompts/${agentName}-${cmdName}.md";
        value.text = renderPiPromptMarkdown {
          inherit description argumentHint;
          prompt = piPrompt;
        };
      }
    ) commandDirs
  ) { } compose.agentDirs;
  piGlobalInstructions = readFileTrim ./instructions/global.md;
  piHomeFiles = {
    ".pi/agent/AGENTS.md".text = piGlobalInstructions;
  }
  // piAgentFiles
  // piSkillFiles
  // piStandalonePromptFiles
  // piAgentPromptFiles;
  piTrayaActivation = ''
    ${pkgs.python3}/bin/python ${piTrayaWriter} \
      ${./agents/traya/prompt.md} \
      ${./agents/traya/description.txt} \
      ${config.sops.secrets.BOND_MD.path} \
      "${config.home.homeDirectory}/.pi/agent/agents/traya.md"
  '';

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
  ) (lib.removeAttrs compose.agentDirs [ "traya" ]);

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
      ${tomlWriterPython}/bin/python ${trayaCodexAgentWriter} \
        ${./agents/traya/prompt.md} \
        ${./agents/traya/description.txt} \
        ${./agents/traya/header.codex.toml} \
        ${config.sops.secrets.BOND_MD.path} \
        "${codexDir}/agents/traya.toml" \
        "${codexDir}/agents/default.toml"
      chmod 600 "${codexDir}/agents/traya.toml"
      chmod 600 "${codexDir}/agents/default.toml"
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
    ) { } compose.agentDirs;

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

  codexRootInstructionsActivationScript = ''
    # Write Codex root instructions after sops-nix renders Traya's BOND secret.
    ${pkgs.python3}/bin/python ${trayaCodexRootInstructionsWriter} \
      ${./agents/traya/prompt.md} \
      ${config.sops.secrets.BOND_MD.path} \
      "${codexDir}/AGENTS.md"
    chmod 600 "${codexDir}/AGENTS.md"
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

    trayaActivation = lib.mkOption {
      type = lib.types.lines;
      default = "";
      internal = true;
      description = "Activation script that writes Traya's Pi Agent file outside the Nix store.";
    };
  };

  config = {
    agentic.assistants.pi = {
      homeFiles = piHomeFiles;
      trayaActivation = piTrayaActivation;
    };

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
        content = renderCodexAgentToml {
          name = "traya";
          description = trayaDescription;
          developerInstructions = codexAgentPrompt trayaPromptWithBond;
          header = readFileTrimIfExists (./agents + "/traya/header.codex.toml");
        };
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
      # Run this after sops-nix so Traya's BOND secret is available to the
      # activation-time Codex writers.
      activation.codexFiles = lib.mkIf config.programs.codex.enable (
        lib.hm.dag.entryAfter [ "writeBoundary" "sops-nix" ] (
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
