{
  lib,
  pkgs ? null,
}:
let
  # Read a file, stripping trailing whitespace
  readFile = path: lib.trim (builtins.readFile path);

  # Read a file if it exists, otherwise return an empty string. Used for
  # optional per-platform headers such as `header.pi.yaml`, where absence
  # means "use defaults".
  readOptionalFile = path: if builtins.pathExists path then readFile path else "";

  # Compose with YAML frontmatter: ---\n{header}\n---\n\n{body}\n
  # Adds blank line after frontmatter and trailing newline
  composeWithFrontmatter = header: body: "---\n${header}\n---\n\n${body}\n";

  # Default Pi subagent header lines. Each generated agent inherits these
  # unless `header.pi.yaml` provides an override (sparse-override semantics:
  # YAML uses the last occurrence of a duplicate key).
  piAgentDefaultLines = [
    "systemPromptMode: append"
    "inheritProjectContext: false"
    "inheritSkills: true"
    "maxSubagentDepth: 0"
  ];

  # Discover directories in a path
  discoverDirs =
    path:
    if builtins.pathExists path then
      lib.filterAttrs (_name: type: type == "directory") (builtins.readDir path)
    else
      { };

  # Base path for all assistant files
  basePath = ./.;

  # ============ AGENTS ============

  # Discover all agent directories
  agentDirs = discoverDirs (basePath + "/agents");

  # Compose a single agent for a specific platform using the provided prompt.
  composeAgentFromPrompt =
    platform: agentName: prompt:
    let
      agentPath = basePath + "/agents/${agentName}";
      description = readFile (agentPath + "/description.txt");
      headerPath = agentPath + "/header.${platform}.yaml";
    in
    if platform == "pi" then
      # Pi: header.pi.yaml is optional. Inject `name` and `description`,
      # then the four hardcoded subagent defaults, then any sparse overrides
      # from header.pi.yaml verbatim.
      let
        rawHeader = readOptionalFile headerPath;
        baseLines = [
          "name: ${agentName}"
          "description: ${builtins.toJSON description}"
        ]
        ++ piAgentDefaultLines;
        lines = baseLines ++ lib.optional (rawHeader != "") rawHeader;
      in
      composeWithFrontmatter (lib.concatStringsSep "\n" lines) prompt
    else
      let
        header = readFile headerPath;
        # Inject description from description.txt into header
        headerWithDescription = "description: \"${description}\"\n${header}";
      in
      composeWithFrontmatter headerWithDescription prompt;

  # Compose a single agent for a specific platform.
  composeAgent =
    platform: agentName:
    let
      agentPath = basePath + "/agents/${agentName}";
      prompt = readFile (agentPath + "/prompt.md");
    in
    composeAgentFromPrompt platform agentName prompt;

  # Generate all agents for a platform
  # Returns attrset: { agentName = "composed content"; ... }
  composeAgents = platform: lib.mapAttrs (name: _: composeAgent platform name) agentDirs;

  sortedAgentNames = lib.sort (a: b: a < b) (builtins.attrNames agentDirs);
  escapeMarkdownTableCell =
    value:
    lib.replaceStrings
      [
        "|"
        "\n"
      ]
      [
        "\\|"
        " "
      ]
      value;

  # ============ COMMANDS ============

  # Discover commands for a specific agent
  discoverAgentCommands = agentName: discoverDirs (basePath + "/agents/${agentName}/commands");

  # Discover standalone commands
  standaloneCommandDirs = discoverDirs (basePath + "/commands");

  # Compose a Pi command markdown using the provided body. Used by
  # `default.nix` for agent-scoped commands that wrap the body with
  # subagent-launch boilerplate before emitting frontmatter, and internally
  # by `composeCommand` for standalone commands.
  composePiCommandFromPrompt =
    agentName: cmdName: body:
    let
      cmdPath =
        if agentName != null then
          basePath + "/agents/${agentName}/commands/${cmdName}"
        else
          basePath + "/commands/${cmdName}";
      description = readFile (cmdPath + "/description.txt");
      rawHeader = readOptionalFile (cmdPath + "/header.pi.yaml");
      lines = [
        "description: ${builtins.toJSON description}"
      ]
      ++ lib.optional (rawHeader != "") rawHeader;
    in
    composeWithFrontmatter (lib.concatStringsSep "\n" lines) body;

  # Compose a single command for a specific platform
  # agentName is null for standalone commands
  composeCommand =
    platform: agentName: cmdName:
    let
      cmdPath =
        if agentName != null then
          basePath + "/agents/${agentName}/commands/${cmdName}"
        else
          basePath + "/commands/${cmdName}";
      prompt = readFile (cmdPath + "/prompt.md");
    in
    if platform == "pi" then
      composePiCommandFromPrompt agentName cmdName prompt
    else
      let
        description = readFile (cmdPath + "/description.txt");
        rawHeader = readFile (cmdPath + "/header.${platform}.yaml");
        # Inject description from description.txt into header
        header = "description: \"${description}\"\n${rawHeader}";
        # Check if this command should use Task tool for subagent execution
        useTask = lib.hasInfix "use-task: true" rawHeader;
      in
      if platform == "claude" && agentName != null && useTask then
        # Claude Code with agent + use-task: instruct to use Task tool for subagent
        composeWithFrontmatter header ''
          Use the Task tool to launch the ${agentName} agent for the following task:

          ${prompt}''
      else if platform == "claude" && agentName != null then
        # Claude Code with agent (no use-task): prepend @agent on its own line before body
        composeWithFrontmatter header "@${agentName}\n\n${prompt}"
      else
        # All other cases: standard frontmatter + prompt
        composeWithFrontmatter header prompt;

  # Generate all commands for a platform (both agent-specific and standalone)
  # Returns attrset: { cmdName = "composed content"; ... }
  composeCommands =
    platform:
    let
      # Agent commands
      agentCommands = lib.foldlAttrs (
        acc: agentName: _:
        let
          cmdDirs = discoverAgentCommands agentName;
          cmds = lib.mapAttrs (cmdName: _: composeCommand platform agentName cmdName) cmdDirs;
        in
        acc // cmds
      ) { } agentDirs;

      # Standalone commands
      standaloneCmds = lib.mapAttrs (
        cmdName: _: composeCommand platform null cmdName
      ) standaloneCommandDirs;
    in
    agentCommands // standaloneCmds;

  # ============ SKILLS ============

  # Discover all candidate skill directories, then keep only those containing
  # a SKILL.md. Stray empty directories under skills/ are ignored so they do
  # not break evaluation. `meet-the-agents` is generated below from the agent
  # registry, so a stale static directory is ignored if it exists.
  physicalSkillDirs = lib.removeAttrs (lib.filterAttrs (
    name: _: builtins.pathExists (basePath + "/skills/${name}/SKILL.md")
  ) (discoverDirs (basePath + "/skills"))) [ "meet-the-agents" ];

  meetTheAgentsSkillContent =
    let
      agentLines = lib.concatStringsSep "\n" (
        map (
          agentName:
          let
            agentPath = basePath + "/agents/${agentName}";
            description = escapeMarkdownTableCell (readFile (agentPath + "/description.txt"));
          in
          "- **${agentName}**: ${description}"
        ) sortedAgentNames
      );
    in
    ''
      ---
      name: meet-the-agents
      description: Registry of available specialist agents and their task domains. Load when delegating a task, selecting an agent, or unsure which agent to use.
      user-invocable: false
      ---

      ## Agents

      ${agentLines}

      ## Routing

      Delegate before parent-thread discovery. Put unknown files, searches, and web checks in `Research scope`.

      Priority rules:
      - Nix, NixOS, Home Manager, nix-darwin, flakes, or `.nix` files: dexter.
      - Source-code security: dibble. Infrastructure security: batfink.
      - Non-Nix implementation from a defined plan: donatello.
      - Prompts, skills, commands, or instruction files: rosey.

      Delegation prompt fields: `Task`, `Context`, `Research scope`, `Output format`, `Response discipline`.
      `Response discipline`: dense, no preamble, no task restatement, raw artefacts when requested.
    '';

  generatedSkills = {
    meet-the-agents = {
      content = lib.trim meetTheAgentsSkillContent;
      path =
        if pkgs != null then
          pkgs.writeTextDir "SKILL.md" meetTheAgentsSkillContent
        else
          throw "composeSkills requires pkgs to materialise generated skills";
      extras = { };
    };
  };

  skillDirs = physicalSkillDirs // {
    meet-the-agents = "generated";
  };

  # Compose a single skill into a structured value:
  #   - content: the SKILL.md body (verbatim, trimmed)
  #   - path:    the source skill directory in the Nix store (used to copy
  #              the entire tree wholesale for Claude Code and OpenCode)
  #   - extras:  attrset of sibling entries beside SKILL.md ({ name = type; ... })
  #              so callers (e.g. the Codex activation script) can deploy
  #              supporting files and subdirectories generically
  composeSkill =
    skillName:
    let
      skillPath = basePath + "/skills/${skillName}";
      entries = builtins.readDir skillPath;
      extras = lib.filterAttrs (name: _: name != "SKILL.md") entries;
    in
    {
      content = readFile (skillPath + "/SKILL.md");
      path = skillPath;
      inherit extras;
    };

  # Generate all skills
  # Returns attrset: { skillName = { content; path; extras; }; ... }
  composeSkills = generatedSkills // lib.mapAttrs (name: _: composeSkill name) physicalSkillDirs;

  # ============ GLOBAL INSTRUCTIONS ============

  composeInstructions =
    platform:
    let
      instructionsPath = basePath + "/instructions";
      header = readFile (instructionsPath + "/header.${platform}.yaml");
      body = readFile (instructionsPath + "/global.md");
    in
    composeWithFrontmatter header body;

in
{
  # Agent composition functions
  inherit composeAgents composeAgent composeAgentFromPrompt;

  # Command composition functions
  inherit composeCommands composeCommand composePiCommandFromPrompt;

  # Instructions composition
  inherit composeInstructions;

  # Skills composition
  inherit composeSkills;

  # Discovery helpers (useful for debugging)
  inherit
    agentDirs
    standaloneCommandDirs
    discoverAgentCommands
    skillDirs
    ;
}
