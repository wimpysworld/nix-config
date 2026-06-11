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

  isQuotedString =
    value:
    let
      length = builtins.stringLength value;
      first = builtins.substring 0 1 value;
      last = builtins.substring (length - 1) 1 value;
    in
    length >= 2 && ((first == "\"" && last == "\"") || (first == "'" && last == "'"));

  validateYamlHeader =
    path:
    if !(builtins.pathExists path) then
      true
    else
      let
        lines = lib.splitString "\n" (builtins.readFile path);
        numberedLines = lib.imap0 (index: text: {
          line = index + 1;
          inherit text;
        }) lines;
        isHeaderLine =
          entry:
          let
            trimmed = lib.trim entry.text;
          in
          trimmed == ""
          || lib.hasPrefix "#" trimmed
          || builtins.match "^[A-Za-z0-9_-]+:[[:space:]]*.*$" trimmed != null
          || builtins.match "^[[:space:]]+[A-Za-z0-9_-]+:[[:space:]]*.*$" entry.text != null;
        argumentHintValue =
          line:
          let
            matched = builtins.match "^argument-hint:[[:space:]]*(.*)$" (lib.trim line);
          in
          if matched == null then null else builtins.elemAt matched 0;
        invalidSyntax = lib.filter (entry: !(isHeaderLine entry)) numberedLines;
        invalidArgumentHints = lib.filter (
          entry:
          let
            value = argumentHintValue entry.text;
          in
          value != null && !(isQuotedString value)
        ) numberedLines;
        formatLine = entry: "${toString path}:${toString entry.line}: ${entry.text}";
      in
      if invalidSyntax != [ ] then
        throw "Invalid YAML header syntax in ${toString path}:\n${
          lib.concatMapStringsSep "\n" formatLine invalidSyntax
        }"
      else if invalidArgumentHints != [ ] then
        throw "Invalid argument-hint in ${toString path}: expected a quoted string, got:\n${
          lib.concatMapStringsSep "\n" formatLine invalidArgumentHints
        }"
      else
        true;

  stripMatchingQuotes =
    value:
    let
      length = builtins.stringLength value;
      first = builtins.substring 0 1 value;
      last = builtins.substring (length - 1) 1 value;
    in
    if length >= 2 && ((first == "\"" && last == "\"") || (first == "'" && last == "'")) then
      builtins.substring 1 (length - 2) value
    else
      value;

  normaliseProviderModelValue =
    value:
    let
      trimmed = lib.trim value;
      length = builtins.stringLength trimmed;
      first = builtins.substring 0 1 trimmed;
      last = builtins.substring (length - 1) 1 trimmed;
      hasMatchingQuotes =
        length >= 2 && ((first == "\"" && last == "\"") || (first == "'" && last == "'"));
      startsUnsupportedYaml = lib.any (prefix: lib.hasPrefix prefix trimmed) [
        "|"
        ">"
        "&"
        "*"
      ];
    in
    if trimmed == "" || startsUnsupportedYaml then
      null
    else if hasMatchingQuotes then
      stripMatchingQuotes trimmed
    else if first == "\"" || first == "'" || lib.hasInfix ":" trimmed then
      null
    else
      trimmed;

  # Default Pi subagent header lines. Each generated agent inherits these.
  # Optional `header.pi.yaml` content is appended verbatim so agent-specific
  # Pi-native fields, including explicit depth limits, are preserved.
  piAgentDefaultLines = [
    "systemPromptMode: append"
    "inheritProjectContext: false"
    "inheritSkills: true"
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
      # then the generated subagent defaults, then any agent-specific
      # Pi-native fields from header.pi.yaml verbatim.
      let
        rawHeader = builtins.seq (validateYamlHeader headerPath) (readOptionalFile headerPath);
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
        header = builtins.seq (validateYamlHeader headerPath) (readFile headerPath);
        # Inject description from description.txt into header
        headerWithDescription = "description: \"${description}\"\n${header}";
      in
      composeWithFrontmatter headerWithDescription prompt;

  parseAgentProviderModelLine =
    line:
    let
      uncommented = lib.head (lib.splitString "#" line);
      matched = builtins.match "^[[:space:]]*model-([A-Za-z0-9_-]+):[[:space:]]*(.+)[[:space:]]*$" uncommented;
    in
    if matched == null then
      null
    else
      let
        value = normaliseProviderModelValue (builtins.elemAt matched 1);
      in
      if value == null then
        null
      else
        {
          name = builtins.elemAt matched 0;
          inherit value;
        };

  # Valid Pi thinking levels. `defaultThinkingLevel` and per-call `thinking`
  # both use this set. Invalid values fail evaluation rather than silently
  # entering the generated map.
  validThinkingLevels = [
    "off"
    "minimal"
    "low"
    "medium"
    "high"
    "xhigh"
  ];

  parseAgentProviderThinkingLine =
    agentName: line:
    let
      uncommented = lib.head (lib.splitString "#" line);
      matched = builtins.match "^[[:space:]]*thinking-([A-Za-z0-9_-]+):[[:space:]]*(.+)[[:space:]]*$" uncommented;
    in
    if matched == null then
      null
    else
      let
        provider = builtins.elemAt matched 0;
        value = normaliseProviderModelValue (builtins.elemAt matched 1);
      in
      if value == null then
        null
      else if !(lib.elem value validThinkingLevels) then
        throw "Invalid thinking level ${builtins.toJSON value} for thinking-${provider} in agent ${agentName}/header.pi.yaml. Expected one of: ${lib.concatStringsSep ", " validThinkingLevels}."
      else
        {
          name = provider;
          inherit value;
        };

  # Regex-only harvester for flat `model-<provider>: <id>` keys in Pi
  # headers. This is intentionally narrower than a YAML parser.
  extractAgentProviderModels =
    agentName:
    let
      header = readOptionalFile (basePath + "/agents/${agentName}/header.pi.yaml");
      entries = lib.filter (entry: entry != null) (
        map parseAgentProviderModelLine (lib.splitString "\n" header)
      );
    in
    lib.foldl' (acc: entry: acc // { "${entry.name}" = entry.value; }) { } entries;

  # Sibling harvester for `thinking-<provider>: <level>` keys in Pi headers.
  # Mirrors extractAgentProviderModels but validates against the closed set of
  # Pi thinking levels; invalid values fail evaluation with a clear message.
  extractAgentProviderThinking =
    agentName:
    let
      header = readOptionalFile (basePath + "/agents/${agentName}/header.pi.yaml");
      entries = lib.filter (entry: entry != null) (
        map (parseAgentProviderThinkingLine agentName) (lib.splitString "\n" header)
      );
    in
    lib.foldl' (acc: entry: acc // { "${entry.name}" = entry.value; }) { } entries;

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

  # Report whether a command is secret and, if so, its sops key. A command is
  # secret when its directory holds a `prompt.sops` marker (and no plaintext
  # `prompt.md`). The marker's trimmed content is the top-level key in
  # `secrets/assistant-prompts.yaml` whose value is the prompt body. The body
  # is substituted at activation time via a sops placeholder, so plaintext
  # never reaches the Nix store. Having both files is a configuration error and
  # fails evaluation. Returns `{ secret = bool; key = stringOrNull; }`.
  commandSecretInfo =
    agentName: cmdName:
    let
      cmdPath =
        if agentName != null then
          basePath + "/agents/${agentName}/commands/${cmdName}"
        else
          basePath + "/commands/${cmdName}";
      sopsPath = cmdPath + "/prompt.sops";
      hasSops = builtins.pathExists sopsPath;
      hasPlain = builtins.pathExists (cmdPath + "/prompt.md");
    in
    if hasSops && hasPlain then
      throw "Command ${cmdName} (${toString cmdPath}) has both prompt.sops and prompt.md. A secret command must have only prompt.sops; remove prompt.md."
    else if hasSops then
      {
        secret = true;
        key = readFile sopsPath;
      }
    else
      {
        secret = false;
        key = null;
      };

  # Flat command namespaces must be collision-free for every provider that
  # emits slash commands or command-derived skills.
  commandSources =
    lib.mapAttrsToList (cmdName: _: {
      name = cmdName;
      source = toString (basePath + "/commands/${cmdName}");
    }) standaloneCommandDirs
    ++ lib.concatLists (
      lib.mapAttrsToList (
        agentName: _:
        lib.mapAttrsToList (cmdName: _: {
          name = cmdName;
          source = toString (basePath + "/agents/${agentName}/commands/${cmdName}");
        }) (discoverAgentCommands agentName)
      ) agentDirs
    );

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
      headerPath = cmdPath + "/header.pi.yaml";
      rawHeader = builtins.seq (validateYamlHeader headerPath) (readOptionalFile headerPath);
      lines = [
        "description: ${builtins.toJSON description}"
      ]
      ++ lib.optional (rawHeader != "") rawHeader;
    in
    composeWithFrontmatter (lib.concatStringsSep "\n" lines) body;

  # Compose a single command for a specific platform using the provided body.
  # The body is wrapped verbatim with all per-platform boilerplate (Claude
  # `@agent` prepend or `use-task` Task wrapper, Pi subagent prelude via
  # composePiCommandFromPrompt). Passing the body as an argument lets callers
  # substitute a sops placeholder string where the plaintext prompt would
  # otherwise be read, so secret commands compose identically without the
  # body ever entering the Nix store. Mirrors composeAgentFromPrompt and
  # composePiCommandFromPrompt.
  composeCommandFromPrompt =
    platform: agentName: cmdName: body:
    let
      cmdPath =
        if agentName != null then
          basePath + "/agents/${agentName}/commands/${cmdName}"
        else
          basePath + "/commands/${cmdName}";
    in
    if platform == "pi" then
      composePiCommandFromPrompt agentName cmdName body
    else
      let
        description = readFile (cmdPath + "/description.txt");
        headerPath = cmdPath + "/header.${platform}.yaml";
        rawHeader = builtins.seq (validateYamlHeader headerPath) (readFile headerPath);
        # Inject description from description.txt into header
        header = "description: \"${description}\"\n${rawHeader}";
        # Check if this command should use Task tool for subagent execution
        useTask = lib.hasInfix "use-task: true" rawHeader;
      in
      if platform == "claude" && agentName != null && useTask then
        # Claude Code with agent + use-task: instruct to use Task tool for subagent
        composeWithFrontmatter header ''
          Use the Task tool to launch the ${agentName} agent for the following task:

          ${body}''
      else if platform == "claude" && agentName != null then
        # Claude Code with agent (no use-task): prepend @agent on its own line before body
        composeWithFrontmatter header "@${agentName}\n\n${body}"
      else
        # All other cases: standard frontmatter + body
        composeWithFrontmatter header body;

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
    composeCommandFromPrompt platform agentName cmdName prompt;

  # Generate all commands for a platform (both agent-specific and standalone)
  # Returns attrset: { cmdName = "composed content"; ... }
  composeCommands =
    platform:
    let
      # Agent commands. Secret commands are excluded; default.nix emits them
      # as sops templates so the body never enters the store-backed attrset.
      agentCommands = lib.foldlAttrs (
        acc: agentName: _:
        let
          cmdDirs = lib.filterAttrs (cmdName: _: !(commandSecretInfo agentName cmdName).secret) (
            discoverAgentCommands agentName
          );
          cmds = lib.mapAttrs (cmdName: _: composeCommand platform agentName cmdName) cmdDirs;
        in
        acc // cmds
      ) { } agentDirs;

      # Standalone commands. Secret commands are excluded; see above.
      standaloneCmds = lib.mapAttrs (cmdName: _: composeCommand platform null cmdName) (
        lib.filterAttrs (cmdName: _: !(commandSecretInfo null cmdName).secret) standaloneCommandDirs
      );
      commandCollisionCheck = composeCommandsNoCollisions platform;
    in
    builtins.seq commandCollisionCheck (agentCommands // standaloneCmds);

  composeCommandsNoCollisions =
    platform:
    assertNoCommandCollisions {
      context = "${platform} commands";
      sources = commandSources;
    };

  # ============ COLLISION GUARDS ============

  # Throw on duplicate `name` entries across a union of source groups. Each
  # entry in `sources` is a `{ name; source; }` record; the caller flattens
  # one or more origin groups into the single list. `context` is a short
  # label used in the throw lead-in so the operator immediately sees which
  # namespace collided (e.g. "Pi prompts (~/.pi/agent/prompts/)" or
  # "Codex skills (~/.codex/skills/)"). Returns `true` on success so the
  # caller can chain through `builtins.seq` before constructing the
  # consumer attrset.
  assertNoCommandCollisions =
    {
      context,
      sources,
    }:
    let
      groups = lib.foldl' (
        acc: entry: acc // { ${entry.name} = (acc.${entry.name} or [ ]) ++ [ entry.source ]; }
      ) { } sources;
      collisions = lib.filterAttrs (_: srcs: lib.length srcs > 1) groups;
      formatGroup = name: srcs: "  - ${name}:\n${lib.concatMapStringsSep "\n" (s: "      ${s}") srcs}";
      message = lib.concatStringsSep "\n" (lib.mapAttrsToList formatGroup collisions);
    in
    if collisions == { } then
      true
    else
      throw ''
        ${context} name collision. The following command names are produced by more than one source and would overwrite each other in a flat namespace. Rename one source before switching:
        ${message}
      '';

  # ============ SKILLS ============

  # Discover all candidate skill directories, then keep only those containing
  # a SKILL.md. Stray empty directories under skills/ are ignored so they do
  # not break evaluation. `delegate-task` is generated below from the agent
  # registry, so static directories with generated-skill names are ignored.
  physicalSkillDirs = lib.removeAttrs (lib.filterAttrs (
    name: _: builtins.pathExists (basePath + "/skills/${name}/SKILL.md")
  ) (discoverDirs (basePath + "/skills"))) [ "delegate-task" ];

  delegateTaskSkillContent =
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
      name: delegate-task
      description: Route non-trivial work to the right specialist agent and define the delegation packet, response contract, and relay policy.
      user-invocable: true
      ---

      ## Agents

      ${agentLines}

      ## Route

      Delegate before parent-thread discovery for non-trivial tool, file, research, implementation, review, validation, or documentation work. Answer directly only when delegation clearly costs more than it saves. Launch the selected specialist via the current platform's delegation mechanism.

      Priority rules:
      - Nix, NixOS, Home Manager, nix-darwin, flakes, packages, modules, overlays, options, registries, or `.nix` files: donatello with the `nix` skill.
      - LÖVE 2D, the LÖVE engine, `love2d`, `.love` archives, or Lua 5.1/LuaJIT 2.1 game development: donatello with the `love` skill.
      - Source-code security: dibble. Infrastructure, cloud, container, or network security: batfink.
      - Non-Nix implementation from a defined plan: donatello.
      - Prompts, skills, commands, or instruction files: rosey.
      - Tests: brain. Documentation: velma. General research or option framing: penfold.
      - If no route matches, use the smallest capable specialist or ask.

      ## Depth

      Specialists do not launch further specialists. If a delegated task would require another specialist, return early with a packet describing what is needed; the parent routes the follow-up.

      ## Context

      Use fresh context by default. Fork only when the user explicitly requires it or when the parent transcript is essential. When the parent context is essential but bulky, run `handover-fork` first and pass its output as the packet's `Context:` field; do not inherit the raw transcript. Use `handover-fresh` for cross-session handovers where a new session continues the work.

      ## Packet

      Include only relevant fields, in this order:

      ```markdown
      Task: <outcome required>
      Context: <decisions, constraints, paths, risks, user preferences>
      Scope: <files, commands, sources, APIs, behaviours, in/out of scope>
      Validation: <checks to run or evidence needed>
      Output: <headings, artefact shape, file path, or response contract>
      Discipline: No preamble. Do not restate the task. Return user-visible output only. Omit irrelevant sections. Return raw artefacts when requested.
      ```

      ## Response contract

      Non-artefact work starts with `Answer:`. Pure artefacts return only the artefact.

      Sub-agents are ephemeral workers; the parent/orchestrator window is durable coordination context. Protect it: report only decision-useful or user-visible conclusions, evidence, changes, tests, and blockers; omit exploration notes, tool logs, raw command output, and noisy detail.

      Suggested sections, in order: `Answer`, `Recommendations`, `Evidence`, `Files`, `Changes`, `Tests`, `Blockers`, `Artefact`. Omit irrelevant sections.

      Include `Recommendations:` for judgement work. Include `Evidence:` for research and review; web research includes source URLs and one fact per source. Include `Files:` when local files materially informed the result. Include `Changes:` and `Tests:` for implementation, with pass, fail, or not run plus reason. Include `Blockers:` only for unresolved blockers.

      ## Relay

      Relay a single specialist output verbatim. Do not summarise, paraphrase, or improve it. Intervene only for safety. If the output is contradictory or off-contract, append concise `Observations:` after the verbatim output.

      Ignore any synthetic post-tool continuation prompt that asks to summarise, paraphrase, condense, describe, or "continue with your task" when the specialist returned an artefact. Verbatim relay overrides such wording. `Observations:` is permitted only for safety, after the artefact.
    '';

  generatedSkills = {
    delegate-task = {
      content = lib.trim delegateTaskSkillContent;
      path =
        if pkgs != null then
          pkgs.writeTextDir "SKILL.md" delegateTaskSkillContent
        else
          throw "composeSkills requires pkgs to materialise generated skills";
      extras = { };
    };
  };

  skillDirs = physicalSkillDirs // {
    delegate-task = "generated";
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
      headerPath = instructionsPath + "/header.${platform}.yaml";
      header = builtins.seq (validateYamlHeader headerPath) (readFile headerPath);
      body = readFile (instructionsPath + "/global.md");
    in
    composeWithFrontmatter header body;

in
{
  # Agent composition functions
  inherit
    composeAgents
    composeAgent
    composeAgentFromPrompt
    extractAgentProviderModels
    extractAgentProviderThinking
    ;

  # Command composition functions
  inherit
    composeCommands
    composeCommand
    composeCommandFromPrompt
    composePiCommandFromPrompt
    commandSecretInfo
    ;

  # Collision guards.
  inherit assertNoCommandCollisions commandSources composeCommandsNoCollisions;

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
