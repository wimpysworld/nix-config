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
      lib.filterAttrs (name: type: type == "directory") (builtins.readDir path)
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
    in
    if platform == "codecompanion" then
      # CodeCompanion: markdown header + blank line + prompt (no frontmatter delimiters)
      (readFile (agentPath + "/header.codecompanion.md")) + "\n" + prompt + "\n"
    else
      let
        header = readFile (agentPath + "/header.${platform}.yaml");
      in
      composeWithFrontmatter header prompt;

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
      header = readFile (cmdPath + "/header.${platform}.yaml");
    in
    if platform == "codecompanion" then
      # CodeCompanion: YAML frontmatter + ## user + escaped content
      composeWithFrontmatter header "\n## user\n\n${escapeHeadings prompt}"
    else if platform == "claude" && agentName != null then
      # Claude Code with agent: prepend @agent on its own line before body
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

  # Discovery helpers (useful for debugging)
  inherit agentDirs standaloneCommandDirs discoverAgentCommands;

  # CodeCompanion Lua config generator
  inherit mkRulesConfig;
}
