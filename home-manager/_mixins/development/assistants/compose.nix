{ lib }:
let
  # Read a file, stripping trailing whitespace
  readFile = path: lib.trim (builtins.readFile path);

  # Compose with YAML frontmatter: ---\n{header}\n---\n\n{body}\n
  # Adds blank line after frontmatter and trailing newline
  composeWithFrontmatter = header: body: "---\n${header}\n---\n\n${body}\n";

  # Escape ## headings to ### for CodeCompanion (uses ## for section markers)
  escapeHeadings =
    content:
    let
      lines = lib.splitString "\n" content;
      escapeLine = line: if lib.hasPrefix "## " line then "#${line}" else line;
    in
    lib.concatStringsSep "\n" (map escapeLine lines);

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

  # Compose a single agent for a specific platform
  composeAgent =
    platform: agentName:
    let
      agentPath = basePath + "/agents/${agentName}";
      prompt = readFile (agentPath + "/prompt.md");
      description = readFile (agentPath + "/description.txt");
    in
    if platform == "codecompanion" then
      # CodeCompanion: markdown header + blank line + prompt (no frontmatter delimiters)
      (readFile (agentPath + "/header.codecompanion.md")) + "\n" + prompt + "\n"
    else
      let
        header = readFile (agentPath + "/header.${platform}.yaml");
        # Inject description from description.txt into header
        headerWithDescription = "description: \"${description}\"\n${header}";
      in
      composeWithFrontmatter headerWithDescription prompt;

  # Generate all agents for a platform
  # Returns attrset: { agentName = "composed content"; ... }
  composeAgents = platform: lib.mapAttrs (name: _: composeAgent platform name) agentDirs;

  # ============ COMMANDS ============

  # Discover commands for a specific agent
  discoverAgentCommands = agentName: discoverDirs (basePath + "/agents/${agentName}/commands");

  # Discover standalone commands
  standaloneCommandDirs = discoverDirs (basePath + "/commands");

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
      description = readFile (cmdPath + "/description.txt");
      rawHeader = readFile (cmdPath + "/header.${platform}.yaml");
      # Inject description from description.txt into header
      header = "description: \"${description}\"\n${rawHeader}";
      # Check if this command should use Task tool for subagent execution
      useTask = lib.hasInfix "use-task: true" rawHeader;
    in
    if platform == "codecompanion" then
      # CodeCompanion: YAML frontmatter + ## user + escaped content
      composeWithFrontmatter header "\n## user\n\n${escapeHeadings prompt}"
    else if platform == "claude" && agentName != null && useTask then
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

  # Discover all skill directories
  skillDirs = discoverDirs (basePath + "/skills");

  # Compose a single skill: read SKILL.md verbatim (no transformation needed)
  composeSkill = skillName: readFile (basePath + "/skills/${skillName}/SKILL.md");

  # Generate all skills
  # Returns attrset: { skillName = "SKILL.md content"; ... }
  composeSkills = lib.mapAttrs (name: _: composeSkill name) skillDirs;

  # ============ GLOBAL INSTRUCTIONS ============

  composeInstructions =
    platform:
    let
      instructionsPath = basePath + "/instructions";
      header = readFile (instructionsPath + "/header.${platform}.yaml");
      body = readFile (instructionsPath + "/global.md");
    in
    composeWithFrontmatter header body;

  # ============ CODECOMPANION RULES CONFIG ============

  # Generate Lua configuration for CodeCompanion rules registry
  # Returns Lua table defining all agent rules for CodeCompanion setup
  mkRulesConfig =
    { configDir }:
    let
      rulesDir = "${configDir}/rules";
      ruleEntries = lib.mapAttrsToList (
        agentName: _:
        let
          agentPath = basePath + "/agents/${agentName}";
          description = readFile (agentPath + "/description.txt");
        in
        ''
          ${agentName} = {
            description = "${description}",
            parser = "codecompanion",
            files = { "${rulesDir}/${agentName}.md" },
          },''
      ) agentDirs;
    in
    ''
      {
        ${lib.concatStringsSep "\n" ruleEntries}
      }'';

in
{
  # Agent composition functions
  inherit composeAgents composeAgent;

  # Command composition functions
  inherit composeCommands composeCommand;

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

  # CodeCompanion Lua config generator
  inherit mkRulesConfig;
}
