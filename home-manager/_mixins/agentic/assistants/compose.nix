{
  lib,
  pkgs ? null,
  basePath ? ./.,
  gwsEnabled ? false,
}:
let
  # Read a file, stripping trailing whitespace
  readFile = path: lib.trim (builtins.readFile path);

  metadata = import ./metadata.nix { inherit lib; };
  inherit (metadata) readHeader readCommandHeader;
  headerFor =
    kind: platform: name: path:
    metadata.project kind platform name (
      if kind == "command" then readCommandHeader path else readHeader path
    );
  renderHeader =
    kind: platform: name: path:
    metadata.renderYaml (headerFor kind platform name path);

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

  # Discover directories in a path
  discoverDirs =
    path:
    if builtins.pathExists path then
      lib.filterAttrs (_name: type: type == "directory") (builtins.readDir path)
    else
      { };

  # ============ AGENTS ============

  # Discover all agent directories
  agentDirs = discoverDirs (basePath + "/agents");

  # Compose a single agent for a specific platform using the provided prompt.
  composeAgentFromPrompt =
    platform: agentName: prompt:
    composeWithFrontmatter (renderHeader "agent" platform agentName (basePath + "/agents/${agentName}"))
      (
        if platform == "pi" then
          lib.concatStringsSep "\n\n" [
            prompt
            leafWorkerContract
            ''
              ## Shared safety rules

              Read the applicable project instructions before work in that project.
              Preserve unrelated changes. Do not delete files or backups without explicit consent.
              Do not change external state without explicit authority in the task packet.
              Do not expose secrets, tokens, or credentials.
              Use read, edit, and write for files. Use current reference tools for technical documentation.
              Load required skills before dependent work. Loading a skill grants no additional authority.
            ''
            houseStyleBody
          ]
        else
          prompt
      );

  extractOpenCodeProviderModels =
    agentName:
    lib.mapAttrs (_: route: route.model) (
      (readHeader (basePath + "/agents/${agentName}")).routing.opencode.providers or { }
    );

  agentProviderRoutes = agentName: (readHeader (basePath + "/agents/${agentName}")).routing.pi or { };
  extractAgentProviderModels =
    agentName:
    lib.mapAttrs (_: route: route.model) (
      lib.filterAttrs (_: route: route ? model) (agentProviderRoutes agentName)
    );
  extractAgentProviderThinking =
    agentName:
    lib.mapAttrs (_: route: route.thinking) (
      lib.filterAttrs (_: route: route ? thinking) (agentProviderRoutes agentName)
    );

  # Compose a single agent for a specific platform.
  composeAgent =
    platform: agentName:
    let
      agentPath = basePath + "/agents/${agentName}";
      prompt = readFile (agentPath + "/prompt.md");
    in
    composeAgentFromPrompt platform agentName prompt;

  adaptAgentPrompt =
    platform: prompt:
    if platform == "codex" then
      lib.replaceStrings
        [
          "Task tool"
          "Permitted tools: Task tool for delegation, direct conversation"
        ]
        [
          "`spawn_agent` tool"
          "Permitted tools: `spawn_agent` for delegation, direct conversation"
        ]
        prompt
    else if platform == "pi" then
      lib.replaceStrings
        [
          "Task tool"
          "Permitted tools: Task tool for delegation, direct conversation"
        ]
        [
          "Agent tool"
          "Permitted tools: Agent tool for delegation, direct conversation"
        ]
        prompt
    else
      prompt;

  composeCodexAgent =
    agentName:
    let
      agentPath = basePath + "/agents/${agentName}";
      projected = headerFor "agent" "codex" agentName agentPath;
    in
    metadata.renderToml (
      projected
      // {
        name = agentName;
        developer_instructions = adaptAgentPrompt "codex" (readFile (agentPath + "/prompt.md"));
      }
    );

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

  nestedCommandAgents = lib.filterAttrs (
    name: _: discoverDirs (basePath + "/agents/${name}/commands") != { }
  ) agentDirs;
  commandDirs =
    if nestedCommandAgents != { } then
      throw "Commands must live under commands/<name>, not agents/<agent>/commands: ${lib.concatStringsSep ", " (builtins.attrNames nestedCommandAgents)}."
    else
      discoverDirs (basePath + "/commands");

  # Report whether a command is secret and, if so, its sops key. A command is
  # secret when its directory holds a `command.sops` marker (and no plaintext
  # `command.md`). The marker's trimmed content is the top-level key in
  # `secrets/assistant-prompts.yaml` whose value is the prompt body. The body
  # is substituted at activation time via a sops placeholder, so plaintext
  # never reaches the Nix store. Having both files is a configuration error and
  # fails evaluation. Returns `{ secret = bool; key = stringOrNull; }`.
  commandSecretInfo =
    cmdName:
    let
      cmdPath = commandPath cmdName;
      sopsPath = cmdPath + "/command.sops";
      hasSops = builtins.pathExists sopsPath;
      hasPlain = builtins.pathExists (cmdPath + "/command.md");
    in
    if hasSops && hasPlain then
      throw "Command ${cmdName} (${toString cmdPath}) has both command.sops and command.md. A secret command must have only command.sops; remove command.md."
    else if hasSops then
      {
        secret = true;
        key = readFile sopsPath;
      }
    else if !hasPlain then
      throw "Command ${cmdName} requires command.md or command.sops."
    else
      {
        secret = false;
        key = null;
      };

  # Flat command namespaces must be collision-free for every provider that
  # emits slash commands or command-derived skills.
  commandSources = lib.mapAttrsToList (name: _: {
    inherit name;
    source = toString (commandPath name);
  }) commandDirs;

  commandPath = cmdName: basePath + "/commands/${cmdName}";

  commandMetadata =
    cmdName:
    let
      header = readCommandHeader (commandPath cmdName);
      selectedAgent = header.compose.agent or null;
      projections = map (platform: metadata.commandExecution platform cmdName header) [
        "claude"
        "opencode"
        "codex"
        "pi"
      ];
    in
    if selectedAgent != null && !(agentDirs ? ${selectedAgent}) then
      throw "Unknown compose.agent ${selectedAgent} for command ${cmdName}."
    else if
      !(builtins.isString (header.common.description or null)) || lib.trim header.common.description == ""
    then
      throw "${toString (commandPath cmdName)}/command.toml: A non-empty common.description is required."
    else if
      !(lib.all (
        execution: !(execution.native ? argument-hint) || builtins.isString execution.native.argument-hint
      ) projections)
    then
      throw "${toString (commandPath cmdName)}/command.toml: Argument hints must be strings."
    else
      builtins.deepSeq projections (builtins.deepSeq (metadata.commandPolicy header) header);

  commandRegistry = lib.mapAttrs (name: _: {
    path = commandPath name;
    header = commandMetadata name;
    inherit ((commandSecretInfo name)) secret;
  }) commandDirs;

  composePiCommandFromPrompt =
    cmdName: body:
    composeWithFrontmatter (metadata.renderYaml (
      metadata.project "command" "pi" cmdName (commandMetadata cmdName)
    )) body;

  leafWorkerContract = ''
    You are a worker. Complete the assigned scope directly and return to the parent.
    Do not launch agents through sub-agent or task tools. Do not execute generated command launch wrappers.
    Loading a command or skill does not change your role. Follow its workflow body directly within the assigned scope.
    If more specialist work is necessary, complete independent assigned work first.
    Return a bounded request with the required scope and evidence to the parent. Do not launch that work yourself.
    Put the complete report in your final response. Use the runtime's native result delivery.
    A missing messaging tool is not a blocker when the runtime returns final responses to the parent.
  '';

  workerDispatchInstructions = ''
    Supply a bounded packet with the scope, exact arguments, existing authority, hard deadline, validation, and output contract.
    Include the worker instructions below in the child's task, not the parent's launch instructions.
    If the worker requests more specialist work, dispatch it from the coordinator and continue the original task.
    Use native final-response delivery. Require a separate messaging tool only when the runtime needs it and the worker has it.
  '';

  commandContextInstructions =
    source:
    lib.concatStringsSep "\n" (
      lib.filter (text: text != "") [
        (source.compose.coordinator.before-launch or "")
        (source.compose.coordinator.after-return or "")
      ]
    );

  composeCommandFromPrompt =
    platform: cmdName: body:
    let
      source = commandMetadata cmdName;
      execution = metadata.commandExecution platform cmdName source;
      inherit (execution) selectedAgent mode;
      header = metadata.renderYaml execution.native;
    in
    if mode == "caller-context" then
      composeWithFrontmatter header body
    else if mode == "claude-task" then
      composeWithFrontmatter header (
        lib.trim ''
          Use the Task tool to launch the ${selectedAgent} agent for the following task:

          ${workerDispatchInstructions}
          ${commandContextInstructions source}
          ## Task

          ${leafWorkerContract}
          ${body}
        ''
      )
    else if mode == "claude-agent" then
      composeWithFrontmatter header "@${selectedAgent}\n\n${body}"
    else if mode == "pi-agent" then
      composeWithFrontmatter header (
        lib.trim ''
          Use the Agent tool with `subagent_type: "${selectedAgent}"` for the task below.

          Set `inherit_context` to `false` and `run_in_background` to `true`.
          Supply a short `description` and put the task in `prompt`.
          ${workerDispatchInstructions}
          ${commandContextInstructions source}
          ## Task

          ${leafWorkerContract}
          ${body}
        ''
      )
    else if mode == "opencode-subtask" then
      composeWithFrontmatter header "${leafWorkerContract}\n${body}"
    else
      composeWithFrontmatter header body;

  composeCommand =
    platform: cmdName:
    composeCommandFromPrompt platform cmdName (readFile (commandPath cmdName + "/command.md"));

  composeCommands =
    platform:
    builtins.seq (composeCommandsNoCollisions platform) (
      lib.mapAttrs (cmdName: _: composeCommand platform cmdName) (
        lib.filterAttrs (_: entry: !entry.secret) commandRegistry
      )
    );

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
  # `SKILL.md`, exactly as `command.sops` replaces `command.md` for commands;
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
  allPhysicalSkillDirs = lib.filterAttrs (
    name: _: !(secretSkillDirs ? ${name}) && builtins.pathExists (basePath + "/skills/${name}/SKILL.md")
  ) skillCandidateDirs;
  physicalSkillDirs = lib.filterAttrs (
    name: _: !(lib.hasPrefix "gws-" name) || gwsEnabled
  ) allPhysicalSkillDirs;
  catalogueSkillDirs =
    allPhysicalSkillDirs
    // secretSkillDirs
    // {
      delegate-task = "generated";
    };

  delegateTaskSkillContent =
    let
      agentLines = lib.concatStringsSep "\n" (
        map (
          agentName:
          let
            agentPath = basePath + "/agents/${agentName}";
            description = escapeMarkdownTableCell (readHeader agentPath).common.description;
          in
          "- **${agentName}**: ${description}"
        ) sortedAgentNames
      );
    in
    ''
      ## Agents

      ${agentLines}

      ## Route

      Delegate before parent-thread discovery for non-trivial tool, file, research, implementation, review, validation, or documentation work. Answer directly only when delegation clearly costs more than it saves. Launch the selected specialist via the current platform's delegation mechanism.

      Priority rules:
      - Nix, NixOS, Home Manager, nix-darwin, flakes, packages, modules, overlays, options, registries, or `.nix` files: donatello with the `nix` skill.
      - Source-code security: dibble. Infrastructure, cloud, container, or network security: batfink.
      - Non-Nix implementation from a defined plan: donatello.
      - Prompts, skills, commands, or instruction files: rosey.
      - Tests: brain. Documentation: velma. General research or option framing: penfold.
      - Directly invoked `make-commit` and `make-pr`: one garfield worker. Supply intent, paths, exclusions, test evidence, and explicit mutation authority.
      - Keep explicit coordinator inline commit procedures in `address-code-review`, `implement-task`, and `babysit-pr`. Read their draft and commit bodies without launch wrappers. The coordinator retains index ownership. Never run concurrent index mutations.
      - After `make-pr` returns a verified URL, the coordinator offers `babysit-pr` and continues only after user consent. Garfield never launches monitoring.
      - If no route matches, use the smallest capable specialist or ask.

      ## Depth

      The coordinator dispatches workers. Workers complete their assigned scope directly and launch no agents through sub-agent or task tools. Loading a command or skill never changes a worker into a coordinator. Workers follow workflow bodies directly, without generated launch wrappers. If more specialist work is necessary, complete independent assigned work first. Return a bounded request with the required scope and evidence to the parent. The coordinator handles that request and continues the original task.

      ## Waiting

      Receive every required report before finalising the task. Use the platform's native completion mechanism. When completion cannot resume the coordinator, keep its turn active until the report arrives. Pi async completion resumes the coordinator through a native notification, so it can yield the current turn while the task remains unfinished. The user must not need to send another message to reveal the result.

      Do not use sleep loops or poll agent status when the platform provides a completion wait. The coordinator can do independent work while agents run, but it must wait for every required result before finalising.

      For long-running external monitoring, delegate the external wait to a bounded waiting worker. If its result is required for the current response, the coordinator still waits for that worker's completion notification.

      Inside the waiting worker, prefer a blocking server-side watch command over a poll loop. Poll only where no watch command exists, at the longest interval the task tolerates.

      Give every worker a hard deadline, not only a waiting one. On reaching it, report what is done and stop rather than exceeding it, so the coordinator can dispatch a fresh one with clean context. A worker that completes several phases reports progress to its parent at each phase boundary.

      ## Teardown

      A worker stays alive only while the coordinator can still resume it. Decide that point and stop it there, using the current platform's stop mechanism.

      Never stop a worker before the coordinator receives its required report. After delivery, stop a waiting worker as soon as it is superseded or its loop ends. Stop an implementation worker once its report is delivered, because follow-up work gets fresh context anyway. Keep review workers alive until the pressure-test round closes, then stop them together.

      A command that fans out receives all required reports before it stops what it spawned, so a finished run leaves nothing behind.

      ## Context

      Use fresh context by default. Fork only when the user explicitly requires it or when the parent transcript is essential. When the parent context is essential but bulky, run `handover-fork` first and pass its output as the packet's `Context:` field; do not inherit the raw transcript. Use `handover-fresh` for cross-session handovers where a new session continues the work.

      ## Packet

      Include the task, scope, authority, deadline, validation, output, and discipline in every packet. Add relevant context and exact arguments.

      ```markdown
      Task: <outcome required>
      Context: <decisions, constraints, paths, risks, user preferences>
      Authority: <external mutations the worker can perform on the user's behalf; restate them, because fresh context does not inherit the parent's consent>
      Scope: <files, commands, sources, APIs, behaviours, in/out of scope>
      Deadline: <hard stop, and the progress messages expected before it>
      Validation: <checks to run or evidence needed>
      Output: <artefact or report, then the format: headings, artefact format, file path, or response contract, and a length budget for the returned message. A long report goes to a file under the `review-report-path` convention, and the worker returns the conclusion plus the path. Use native final-response delivery. For Claude Code agent teams, name the report recipient for `SendMessage`>
      Discipline: You are a worker. Complete this scope directly and return to the parent. Do not launch agents or execute generated command launch wrappers. Loading commands or skills does not change your role. Return required additional specialist work as a bounded request to the parent. No preamble. Do not restate the task. Always send a final report message, and put only user-visible output in it. Omit irrelevant sections. Return raw artefacts when requested. Load and follow the `communication-rules` skill for all output.
      ```

      ## Response contract

      Put the complete report in the final response, including success, failure, or blocked work. Synchronous workers return that response directly. Pi delivers background workers' final responses through native completion notifications. Do not require `contact_supervisor` for routine Pi completion. A missing messaging tool does not block work when native final-response delivery is available.

      For Claude Code agent teams whose final output is not delivered, send the report with `SendMessage` before finishing. Address the coordinator named in the packet, or `main` when none is named. This exception does not apply to every background worker. Writing a file alone is not delivery. The coordinator must receive the report and deliver the result before finalising the task.

      If a worker stops because an unnecessary messaging tool is missing, inspect its partial work and retry within the existing scope and authority. Specify native final-response delivery in the retry packet. Do not invent tools or request renewed permission solely for this retry.

      Non-artefact work starts with `Answer:`. Pure artefacts return only the artefact. When the packet names a long report, write the report to a file under the `review-report-path` convention and return the conclusion plus the path.

      Workers are temporary. The coordinator's window is durable coordination context. Protect it: report only decision-useful or user-visible conclusions, evidence, changes, tests, and blockers; omit exploration notes, tool logs, raw command output, and noisy detail.

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

  generatedSkillsFor =
    platform:
    let
      content =
        composeWithFrontmatter
          (renderHeader "skill" platform "delegate-task" (basePath + "/skills/delegate-task"))
          (
            stripFrontmatter delegateTaskSkillContent
            + lib.optionalString (platform == "pi") ''

              ## Pi native delegation

              Use `Agent` with `subagent_type`, a short `description`, and the full packet in `prompt`.
              Set `inherit_context: false` unless the packet requires the parent transcript.
              Use `run_in_background: true` by default. Receive the completion notification before you use the result.
              Use `get_subagent_result` to read completed output and `steer_subagent` to send guidance to an active child.
              Resume a completed child with `Agent` and its `resume` identifier. Preserve the child's existing model and role.
              Completed children have no live process to stop. Use the native UI or RPC cancellation for active children.
              Deadlines in packets are instructions, not runtime timers. Use a tested cancellation path for a hard wall-clock limit.

              Use `SubagentWorkflow` for scripted parallel work and dependent stages.
              Supply `script`, `scriptPath`, or a saved workflow `name`. Start scripts with `export const meta = { name, description }`.
              Inside scripts, use `agent(prompt, { agentType })`, `parallel`, and `pipeline`. Name every specialist explicitly.
              Await every launch. A failed or skipped required child fails the workflow, even if a stage catches the error.
              The router limits each workflow to twelve active calls. The native runtime retains its 1000-call limit per workflow.
              The background pool, foreground pool, and each workflow have separate limits of twelve, not one global aggregate cap.
              Follow the shared coordinator limit of twelve active workers across all delegation tools and workflows combined.
              Native CPU-based capacity can lower workflow concurrency. Foreground resumes can exceed their pool limit.
              For reviews, follow `review-code` for selective verification. Return an empty findings array for clean results, never `null`.
              Launch saved workflows through the tool, not nested `workflow()` calls, so each script receives routing checks.
              Use separate sessions in separate checkouts for concurrent writers. Automatic worktrees are disabled because upstream cleanup can lose changes.
              Keep policy extensions enabled. Do not use isolated children, schedules, agent mentions, or slash-command launch shortcuts.
              Do not use the former `subagent`, `runs.run`, `runs.all`, `bg_wait`, or `subagent_supervisor` APIs.
            ''
          );
    in
    {
      delegate-task = {
        inherit content;
        path = buildSkillTree platform "delegate-task" (
          [
            {
              name = "SKILL.md";
              path = pkgs.writeText "SKILL.md" content;
            }
          ]
          ++ skillCompanionEntries platform (basePath + "/skills/delegate-task")
        );
        extras =
          lib.optionalAttrs (skillCompanionEntries platform (basePath + "/skills/delegate-task") != [ ])
            {
              agents = "directory";
            };
      };
    };

  skillDirs = physicalSkillDirs // {
    delegate-task = "generated";
  };

  skillCompanionEntries =
    platform: path:
    let
      companion =
        if platform == "codex" && builtins.pathExists (path + "/header.toml") then
          metadata.skillCompanion path
        else
          { };
    in
    lib.optional (companion != { }) {
      name = "agents/openai.yaml";
      path = pkgs.writeText "openai.yaml" (metadata.renderYaml companion + "\n");
    };

  skillTree =
    platform: path:
    lib.concatLists (
      lib.mapAttrsToList (
        name: type:
        let
          source = path + "/${name}";
        in
        if name == "header.toml" then
          [ ]
        else if type == "directory" then
          map (entry: entry // { name = "${name}/${entry.name}"; }) (skillTree platform source)
        else if name == "SKILL.md" && builtins.pathExists (path + "/header.toml") then
          [
            {
              inherit name;
              path = pkgs.writeText "SKILL.md" (
                composeWithFrontmatter (renderHeader "skill" platform (builtins.baseNameOf path) path) (
                  builtins.readFile source
                )
              );
            }
          ]
        else
          [
            {
              inherit name;
              path = source;
            }
          ]
      ) (builtins.readDir path)
    )
    ++ skillCompanionEntries platform path;

  # Codex follows directory links but skips SKILL.md file links during discovery.
  buildSkillTree =
    platform: skillName: entries:
    let
      tree = pkgs.linkFarm "${platform}-skill-${skillName}" entries;
    in
    if platform != "codex" then
      tree
    else
      tree.overrideAttrs (old: {
        buildCommand =
          old.buildCommand
          + lib.concatMapStringsSep "\n" (entry: ''
            cp --remove-destination -- ${lib.escapeShellArg "${entry.path}"} "$out"/${lib.escapeShellArg entry.name}
          '') (lib.filter (entry: builtins.baseNameOf entry.name == "SKILL.md") entries);
      });

  composeSkill =
    platform: skillName:
    let
      source = basePath + "/skills/${skillName}";
      companionEntries = skillCompanionEntries platform source;
      content = builtins.seq companionEntries (
        composeWithFrontmatter (renderHeader "skill" platform skillName source) (
          builtins.readFile (source + "/SKILL.md")
        )
      );
      extras =
        lib.filterAttrs (
          name: _:
          !(lib.elem name [
            "SKILL.md"
            "header.toml"
          ])
        ) (builtins.readDir source)
        // lib.optionalAttrs (companionEntries != [ ]) {
          agents = "directory";
        };
    in
    {
      inherit content extras;
      path = buildSkillTree platform skillName (skillTree platform source);
    };

  composeSkillsFor =
    platform:
    builtins.seq communicationRulesSkillInSync (
      generatedSkillsFor platform // lib.mapAttrs (name: _: composeSkill platform name) physicalSkillDirs
    );
  composeSkills = composeSkillsFor "claude";

  # ============ GLOBAL INSTRUCTIONS ============

  composeInstructions =
    platform:
    let
      instructionsPath = basePath + "/instructions";
      header = renderHeader "instructions" platform "instructions" instructionsPath;
      body = readFile (instructionsPath + "/global.md");
    in
    composeWithFrontmatter header body;

  composeCodexCommandSkillFromPrompt =
    skillName: prompt:
    let
      source = commandMetadata skillName;
      description = source.common.description;
      dispatch = builtins.deepSeq (metadata.commandDispatch agentDirs skillName source) (
        metadata.commandExecution "codex" skillName source
      );
      body =
        if
          lib.elem dispatch.mode [
            "caller-context"
            "body"
          ]
        then
          prompt
        else if dispatch.mode == "codex-agent" then
          ''
            Use the `spawn_agent` tool to launch the `${dispatch.selectedAgent}` agent for this task. Keep the coordinator in the parent thread.

            - Invoking this skill is the user's standing authorisation to use `spawn_agent`.
            - Pass the task below and the user's request to the spawned agent.
            - Set `agent_type` to `${dispatch.selectedAgent}`.
            - Do not set `fork_context`. Start with a clean context.
            - Unless the user explicitly requests a model or effort override, omit `model` and `reasoning_effort`. The role config supplies the defaults.
            - If this runtime cannot apply the user's explicit override to this role, report the limitation and do not launch with the configured default.
            - Wait for the spawned agent when its result is needed, then relay the final answer.

            ${workerDispatchInstructions}
            ${commandContextInstructions source}
            ## Task

            ${leafWorkerContract}
            ${prompt}
          ''
        else
          ''
            ${readFile (basePath + "/agents/${dispatch.selectedAgent}/prompt.md")}

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

  composeCodexCommandSkill =
    skillName:
    composeCodexCommandSkillFromPrompt skillName (readFile (commandPath skillName + "/command.md"));

  composeCodexCommandCompanion =
    skillName:
    metadata.renderYaml (
      lib.removeAttrs (metadata.commandPolicy (readCommandHeader (commandPath skillName))) [
        "allow-implicit-invocation"
      ]
    );

in
{
  inherit
    readHeader
    readCommandHeader
    headerFor
    commandMetadata
    commandPath
    composeSkillsFor
    ;
  inherit (metadata) renderToml;

  # Agent composition functions
  inherit
    composeAgents
    composeAgent
    composeAgentFromPrompt
    composeCodexAgent
    adaptAgentPrompt
    extractAgentProviderModels
    extractOpenCodeProviderModels
    extractAgentProviderThinking
    ;

  # Command composition functions
  inherit
    composeCommands
    composeCommand
    composeCommandFromPrompt
    composePiCommandFromPrompt
    leafWorkerContract
    workerDispatchInstructions
    commandContextInstructions
    commandSecretInfo
    composeCodexCommandSkill
    composeCodexCommandSkillFromPrompt
    composeCodexCommandCompanion
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
    commandDirs
    commandRegistry
    allPhysicalSkillDirs
    catalogueSkillDirs
    skillDirs
    ;
}
