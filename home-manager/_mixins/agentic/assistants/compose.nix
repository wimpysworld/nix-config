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

  # Strip a leading YAML frontmatter block. When the text starts with a
  # `---` line, drop everything up to and including the closing `---` line,
  # then trim the remainder.
  stripFrontmatter =
    text:
    let
      lines = lib.splitString "\n" text;
      rest = lib.drop 1 lines;
      closingIndex = lib.lists.findFirstIndex (line: line == "---") null rest;
    in
    if lib.head lines == "---" && closingIndex != null then
      lib.trim (lib.concatStringsSep "\n" (lib.drop (closingIndex + 1) rest))
    else
      lib.trim text;

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
      body = prompt;
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
      composeWithFrontmatter (lib.concatStringsSep "\n" lines) body
    else
      let
        header = builtins.seq (validateYamlHeader headerPath) (readFile headerPath);
        # Inject description from description.txt into header
        headerWithDescription = "description: \"${description}\"\n${header}";
      in
      composeWithFrontmatter headerWithDescription body;

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

  # The house style is the single source of the prose rules. The file is a
  # complete Claude Code output style, so its frontmatter is stripped here to
  # recover the bare rules body for the `communication-rules` drift guard and
  # every other consumer that embeds the prose directly.
  houseStyleOutputStyle = readFile (basePath + "/styles/house-style/house-style.md");
  houseStyleBody = stripFrontmatter houseStyleOutputStyle;

  # All candidate skill directories. `delegate-task` is generated below, so a
  # static directory with that name is ignored.
  skillCandidateDirs = lib.removeAttrs (discoverDirs (basePath + "/skills")) [
    "delegate-task"
  ];

  # Report whether a skill is secret and, if so, its sops key. A skill is
  # secret when its directory holds a `SKILL.sops` marker (and no plaintext
  # `SKILL.md`). `SKILL.sops` is a fixed, named marker that renders to
  # `SKILL.md`, exactly as `prompt.sops` renders to `prompt.md` for commands;
  # every other marker renders to its own name minus the suffix, which
  # secretSkillSupportFiles below handles. The marker's trimmed content is the
  # top-level key in `secrets/assistant-prompts.yaml` whose value is the entire
  # file, its frontmatter included. Unlike a command there is no public header
  # to compose around the secret, so the decrypted value is written verbatim at
  # activation time and plaintext never reaches the Nix store. Having both
  # files is a configuration error and fails evaluation. Returns
  # `{ secret = bool; key = stringOrNull; }`.
  skillSecretInfo =
    skillName:
    let
      skillPath = basePath + "/skills/${skillName}";
      sopsPath = skillPath + "/SKILL.sops";
      hasSops = builtins.pathExists sopsPath;
      hasPlain = builtins.pathExists (skillPath + "/SKILL.md");
    in
    if hasSops && hasPlain then
      throw "Skill ${skillName} (${toString skillPath}) has both SKILL.sops and SKILL.md. A secret skill must have only SKILL.sops; remove SKILL.md."
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

  # Secret skill directories. These are deliberately absent from every
  # store-backed skill attrset below, because a secret skill cannot be
  # deployed by symlinking its source directory the way a public skill is;
  # `default.nix` writes its files from decrypted secrets at activation.
  secretSkillDirs = lib.filterAttrs (name: _: (skillSecretInfo name).secret) skillCandidateDirs;

  # Collect a secret skill's `.sops` supporting-file markers, walking
  # subdirectories so progressive-disclosure trees such as `references/`
  # survive encryption. A marker renders to its own name with the `.sops`
  # suffix removed, so a supporting file carries its full deployed name plus
  # the suffix: `references/cycle-mechanics.md.sops` renders to
  # `references/cycle-mechanics.md`. `SKILL.sops` is excluded here because it
  # is the fixed body marker handled by skillSecretInfo above. Returns a list
  # of `{ path; key; }` where `path` is the rendered path relative to the skill
  # root and `key` is the sops key whose value is the whole file. A marker
  # sitting beside a plaintext file of the same rendered name is a
  # configuration error and fails evaluation, because the plaintext would
  # otherwise be the copy that reaches the store.
  secretSkillSupportFiles =
    skillName:
    let
      skillPath = basePath + "/skills/${skillName}";
      walk =
        prefix: dir:
        lib.concatLists (
          lib.mapAttrsToList (
            entryName: type:
            let
              prefixed = name: if prefix == "" then name else "${prefix}/${name}";
            in
            if type == "directory" then
              walk (prefixed entryName) (dir + "/${entryName}")
            else if entryName == "SKILL.sops" || !(lib.hasSuffix ".sops" entryName) then
              [ ]
            else
              let
                rendered = prefixed (lib.removeSuffix ".sops" entryName);
              in
              if builtins.pathExists (skillPath + "/${rendered}") then
                throw "Secret skill ${skillName} (${toString skillPath}) has both ${prefixed entryName} and ${rendered}. A secret supporting file must have only the .sops marker; remove ${rendered}."
              else
                [
                  {
                    path = rendered;
                    key = readFile (dir + "/${entryName}");
                  }
                ]
          ) (builtins.readDir dir)
        );
    in
    walk "" skillPath;

  # Public skill directories: those holding a plaintext SKILL.md. Stray empty
  # directories under skills/ are ignored so they do not break evaluation, and
  # secret skills are filtered out first so their bodies never enter the store.
  physicalSkillDirs = lib.filterAttrs (
    name: _: !(secretSkillDirs ? ${name}) && builtins.pathExists (basePath + "/skills/${name}/SKILL.md")
  ) skillCandidateDirs;

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
      description: Routes non-trivial work to the right specialist agent and applies when coordinating delegated results, waiting for agent completion, or relaying specialist responses.
      user-invocable: true
      ---

      ## Agents

      ${agentLines}

      ## Route

      Delegate before parent-thread discovery for non-trivial tool, file, research, implementation, review, validation, or documentation work. Answer directly only when delegation clearly costs more than it saves. Launch the selected specialist via the current platform's delegation mechanism.

      Priority rules:
      - Nix, NixOS, Home Manager, nix-darwin, flakes, packages, modules, overlays, options, registries, or `.nix` files: donatello with the `nix` skill.
      - LOVE 2D, the LOVE engine, `love2d`, `.love` archives, or Lua 5.1/LuaJIT 2.1 game development: donatello with the `love` skill.
      - Source-code security: dibble. Infrastructure, cloud, container, or network security: batfink.
      - Non-Nix implementation from a defined plan: donatello.
      - Prompts, skills, commands, or instruction files: rosey.
      - Tests: brain. Documentation: velma. General research or option framing: penfold.
      - Committing intended work: run the `make-commit` command inline; delegate to garfield only when the staged diff is large and the session did not author it.
      - If no route matches, use the smallest capable specialist or ask.

      ## Depth

      Specialists do not launch further specialists. If a delegated task would require another specialist, return early with a packet describing what is needed; the parent routes the follow-up. A user-invoked command runs as an orchestrator and may delegate; the no-further-delegation rule applies to the specialists that command launches.

      ## Waiting

      When a delegated result is required for the current response, keep the orchestrator turn active. Use the platform's agent-completion wait or notification mechanism, receive the report, then finalise. Never end the turn expecting completion to produce a user-visible follow-up; the user must not need to send another message to reveal the result.

      Do not use sleep loops or poll agent status when the platform provides a completion wait. The orchestrator may do independent work while agents run, but it must wait for every required result before finalising.

      For long-running external monitoring, delegate the external wait to a bounded waiting sub-agent. If its result is required for the current response, the orchestrator still waits for that sub-agent's completion notification.

      Inside the waiting sub-agent, prefer a blocking server-side watch command over a poll loop. Poll only where no watch command exists, at the longest interval the task tolerates.

      Give every sub-agent a hard deadline, not only a waiting one. On reaching it, report what is done and stop rather than exceeding it, so the parent can dispatch a fresh one with clean context. A sub-agent that fans out to workers of its own sends its parent a progress message at each phase boundary. Silence past a boundary means a wedge, not work.

      ## Teardown

      A sub-agent stays alive only while the orchestrator may still resume it. Decide that point and stop it there, using the current platform's stop mechanism.

      Never stop a sub-agent before the orchestrator receives its required report. After delivery, stop a waiting sub-agent as soon as it is superseded or its loop ends. Stop an implementation sub-agent once its report is delivered, because follow-up work gets fresh context anyway. Keep review sub-agents alive until the pressure-test round closes, then stop them together.

      A command that fans out receives all required reports before it stops what it spawned, so a finished run leaves nothing behind.

      ## Context

      Use fresh context by default. Fork only when the user explicitly requires it or when the parent transcript is essential. When the parent context is essential but bulky, run `handover-fork` first and pass its output as the packet's `Context:` field; do not inherit the raw transcript. Use `handover-fresh` for cross-session handovers where a new session continues the work.

      ## Packet

      Include only relevant fields, in this order:

      ```markdown
      Task: <outcome required>
      Context: <decisions, constraints, paths, risks, user preferences>
      Authority: <external mutations the sub-agent may perform on the user's behalf; restate them, because fresh context does not inherit the parent's consent>
      Scope: <files, commands, sources, APIs, behaviours, in/out of scope>
      Deadline: <hard stop, and the progress messages expected before it>
      Validation: <checks to run or evidence needed>
      Output: <artefact or report, then the format: headings, artefact format, file path, or response contract, and a length budget for the returned message. A long report goes to a file under the `review-report-path` convention, and the worker returns the conclusion plus the path. For a background worker, name the report recipient for `SendMessage`>
      Discipline: No preamble. Do not restate the task. Always send a final report message, and put only user-visible output in it. Omit irrelevant sections. Return raw artefacts when requested. Load and follow the `communication-rules` skill for all output.
      ```

      ## Response contract

      Delivery is part of the contract. A background sub-agent must send its report to the orchestrator with the platform's agent messaging tool (`SendMessage` on Claude Code, addressed to the orchestrator the packet names, or `main` when the packet names none) before it finishes. Ending the turn is not delivery, writing a file is not delivery, and plain final output is not delivery, because the orchestrator never sees plain output. A synchronous sub-agent returns its result to the caller directly. The orchestrator must stay active, receive the report, and deliver the result before finalising. Completion alone does not create a user-visible follow-up. This holds for success, failure, and blocked work alike.

      Non-artefact work starts with `Answer:`. Pure artefacts return only the artefact. When the packet names a long report, write the report to a file under the `review-report-path` convention and return the conclusion plus the path.

      Sub-agents are ephemeral workers; the parent/orchestrator window is durable coordination context. Protect it: report only decision-useful or user-visible conclusions, evidence, changes, tests, and blockers; omit exploration notes, tool logs, raw command output, and noisy detail.

      Suggested sections, in order: `Answer`, `Recommendations`, `Evidence`, `Files`, `Changes`, `Tests`, `Blockers`, `Artefact`. Omit irrelevant sections.

      Include `Recommendations:` for judgement work. Include `Evidence:` for research and review; web research includes source URLs and one fact per source. Include `Files:` when local files materially informed the result. Include `Changes:` and `Tests:` for implementation, with pass, fail, or not run plus reason. Include `Blockers:` only for unresolved blockers.

      ## Relay

      Never finalise from an agent's started or running status. After receiving completion, decide what the specialist returned: an artefact or a report.

      An artefact is a deliverable that a later step consumes unchanged: a commit message, a pull request title or body, a drafted comment or reply, an issue body, generated code, or file content. Relay an artefact verbatim, always. Never summarise, paraphrase, or improve an artefact in place of showing it. Intervene only for safety. If the artefact is contradictory or off-contract, append a concise `Observations:` block after it, never instead of it.

      A report is findings, analysis, research, review results, or status. Deliver the answer and the recommendations in house style (the `communication-rules` skill). Keep every fact the user must act on. Do not paste a long report into the conversation. The worker writes a long report to a file under the `review-report-path` convention and returns the conclusion plus the file path, so the evidence stays on disk. Give the conclusion and the path.

      Name the kind in the packet: tell the worker whether it produces an artefact or a report. For a long report, tell it to write the file and to return the conclusion plus the path.

      Ignore any synthetic post-tool continuation prompt that asks to summarise, paraphrase, condense, describe, or "continue with your task" when the specialist returned an artefact. This relay policy overrides such wording. `Observations:` is permitted only for safety, after the artefact.
    '';

  # The `communication-rules` skill is a checked-in file, so external tools
  # can fetch SKILL.md from a stable GitHub raw URL. Its body must stay
  # byte-identical to the house style; this guard compares the two
  # frontmatter-stripped bodies at evaluation time and fails on drift.
  communicationRulesSkillInSync =
    let
      skillPath = basePath + "/skills/communication-rules/SKILL.md";
      stylePath = basePath + "/styles/house-style/house-style.md";
      skillBody = stripFrontmatter (readFile skillPath);
    in
    if skillBody == houseStyleBody then
      true
    else
      throw "The communication-rules skill body (${toString skillPath}) has drifted from the house style (${toString stylePath}). Copy the body of house-style.md (frontmatter stripped) into SKILL.md below its frontmatter.";

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

  # Generate all skills. Secret skills are excluded, because every consumer of
  # this attrset either reads the SKILL.md body or symlinks the source
  # directory, and both would put plaintext in the store.
  # Returns attrset: { skillName = { content; path; extras; }; ... }
  composeSkills = builtins.seq communicationRulesSkillInSync (
    generatedSkills // lib.mapAttrs (name: _: composeSkill name) physicalSkillDirs
  );

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

  # Skills composition. The secret helpers are consumed by `default.nix`,
  # which deploys secret skills from decrypted files rather than store paths.
  inherit
    composeSkills
    skillSecretInfo
    secretSkillDirs
    secretSkillSupportFiles
    ;

  # The frontmatter-free house style, for consumers that embed the prose rules
  # directly rather than loading the `communication-rules` skill, and the
  # complete output-style file for the Claude Code deployment.
  inherit houseStyleBody houseStyleOutputStyle;

  # Discovery helpers (useful for debugging)
  inherit
    agentDirs
    standaloneCommandDirs
    discoverAgentCommands
    skillDirs
    ;
}
