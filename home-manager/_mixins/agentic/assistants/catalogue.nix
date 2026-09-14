{
  lib,
  basePath ? ./.,
}:
let
  compose = import ./compose.nix { inherit lib basePath; };
  metadata = import ./metadata.nix { inherit lib; };
  clients = [
    "claude"
    "opencode"
    "codex"
    "pi"
  ];
  escape =
    value:
    lib.replaceStrings [ "\\" "|" "\r" "\n" "<" ">" ] [ "\\\\" "\\|" " " " " "&lt;" "&gt;" ] value;
  cell = value: if value == null || value == "" then "Unset" else escape value;
  row = values: "| " + lib.concatMapStringsSep " | " cell values + " |\n";
  entryText =
    execution:
    let
      agent = if execution.selectedAgent == null then "" else execution.selectedAgent;
    in
    {
      caller-context = "Caller context";
      claude-task = "Task worker: ${agent}";
      claude-agent = "@${agent} prefix";
      pi-agent = "Agent worker: ${agent}";
      codex-agent = "spawn_agent: ${agent}";
      codex-inline = "Inline persona: ${agent}";
      opencode-subtask = "Native subtask: ${execution.native.agent or "client selection"}";
      body =
        if execution.native ? agent then
          "Body, native agent: ${execution.native.agent}"
        else
          "Body without repository dispatch";
    }
    .${execution.mode}
    + lib.optionalString (execution.native ? context) ", native context: ${execution.native.context}"
    + lib.optionalString (
      execution.native ? subtask
    ) ", subtask: ${builtins.toJSON execution.native.subtask}"
    + lib.optionalString (execution.native ? model) ", command model: ${execution.native.model}";
  commands = lib.mapAttrsToList (
    name: entry:
    let
      executions = lib.genAttrs clients (client: metadata.commandExecution client name entry.header);
    in
    {
      inherit name;
      link = "./${name}/command.toml";
      description = entry.header.common.description;
      agent = entry.header.compose.agent or null;
      visibility = if entry.secret then "secret" else "public";
      callerContext = entry.header.compose.caller-context or false;
      clients = lib.mapAttrs (client: execution: {
        invocation = "${if client == "codex" then "$" else "/"}${name}";
        description = execution.native.description or entry.header.common.description;
        argumentHint = execution.native.argument-hint or null;
        behaviour = entryText execution;
        nativeContext = execution.native.context or null;
        nativeSubtask = execution.native.subtask or null;
        model = execution.native.model or null;
      }) executions;
    }
  ) compose.commandRegistry;
  agents = lib.concatLists (
    lib.mapAttrsToList (
      name: _:
      let
        header = compose.readHeader (basePath + "/agents/${name}");
        validated = map (client: metadata.project "agent" client name header) clients;
        routes = header.routing or { };
        routeRow = client: provider: route: {
          agent = name;
          inherit client provider;
          model = route.model or null;
          effort =
            route.effort
              or (route.model_reasoning_effort or (route.reasoningEffort or (route.thinking or null)));
        };
      in
      builtins.deepSeq validated (
        lib.concatMap (
          client:
          let
            route = routes.${client} or { };
          in
          if client == "pi" then
            if route == { } then
              [ (routeRow client null { }) ]
            else
              lib.mapAttrsToList (provider: value: routeRow client provider value) route
          else if client == "opencode" && (route.providers or { }) != { } then
            lib.mapAttrsToList (provider: value: routeRow client provider value) route.providers
          else
            [ (routeRow client null route) ]
        ) clients
      )
    ) compose.agentDirs
  );
  select = names: values: lib.getAttrs (lib.intersectLists names (builtins.attrNames values)) values;
  agentControlKeys = {
    claude = [
      "tools"
      "disallowedTools"
      "permissionMode"
    ];
    opencode = [
      "mode"
      "permission"
    ];
    codex = [ "sandbox_mode" ];
    pi = [
      "tools"
      "prompt_mode"
      "extensions"
      "exclude_extensions"
      "skills"
      "isolated"
    ];
  };
  agentRecords = lib.mapAttrsToList (
    name: _:
    let
      header = compose.readHeader (basePath + "/agents/${name}");
      description = header.common.description or null;
    in
    if !builtins.isString description || lib.trim description == "" then
      throw "Agent ${name} requires a non-empty common.description."
    else
      {
        inherit name description;
        link = "./${name}/header.toml";
        availability = if name == "traya" then "Excluded from codingAgentDirs" else "Enabled client";
        clients = lib.genAttrs clients (
          client:
          let
            projected = metadata.project "agent" client name header;
          in
          {
            description = projected.description or description;
            controls = select agentControlKeys.${client} projected;
          }
        );
      }
  ) compose.agentDirs;
  skillRecords = lib.mapAttrsToList (
    name: kind:
    let
      secret = compose.secretSkillDirs ? ${name};
      generated = kind == "generated";
      path = basePath + "/skills/${name}";
      header = if secret then null else compose.readHeader path;
      companion = if secret then null else metadata.skillCompanion path;
    in
    builtins.deepSeq companion {
      inherit name;
      link = if secret then "./${name}/" else "./${name}/header.toml";
      visibility = if secret then "secret" else "public";
      sourceType = if generated then "generated" else "directory";
      description = if secret then null else header.common.description;
      availability =
        if lib.hasPrefix "gws-" name then
          "Enabled client, developer user and cg host"
        else
          "Enabled client";
      clients = lib.genAttrs clients (
        client:
        if secret then
          {
            description = null;
            controls = null;
            invocationPolicy = null;
          }
        else
          let
            projected = metadata.project "skill" client name header;
          in
          {
            inherit (projected) description;
            controls = select [ "allowed-tools" ] projected;
            invocationPolicy =
              if client == "claude" then
                select [ "user-invocable" "disable-model-invocation" ] projected
              else if client == "codex" then
                select [ "allow_implicit_invocation" ] (companion.policy or { })
              else if client == "pi" then
                select [ "disable-model-invocation" ] projected
              else
                { };
          }
      );
    }
  ) compose.catalogueSkillDirs;
  controlsText =
    controls:
    if controls == null then
      "Unknown (secret metadata)"
    else if controls == { } then
      "No metadata override"
    else
      builtins.toJSON controls;
  generatedNotice = "Generated from validated metadata. Run `just update-assistant-catalogue` to update this file.\n\n";
  catalogueNotice = "These tables describe repository sources and projected client metadata, not installed resources or runtime authority. Client enablement still applies. No metadata override means that this source sets no listed control, not that all tools are allowed.\n\n";
  collisionCheck = compose.assertNoCommandCollisions {
    context = "Catalogue command and skill names";
    sources =
      compose.commandSources
      ++ lib.mapAttrsToList (name: _: {
        inherit name;
        source = "skill: ${name}";
      }) compose.catalogueSkillDirs;
  };
  commandsMarkdown = builtins.deepSeq commands (
    builtins.deepSeq agents (
      builtins.seq collisionCheck (
        "# Assistant commands\n\nGenerated from validated metadata. Run `just update-assistant-catalogue` to update this file.\n\n"
        + "An associated agent does not imply worker execution. Caller-context takes precedence over dispatch controls. Claude, Codex, and Pi commands have no model pins. OpenCode command model routes remain supported, including caller-context commands. The tables describe generated entry behaviour, not observed runtime execution.\n\n"
        + "Claude Code, OpenCode, and Pi use `/name`. Codex uses manual-only `$name` skills. OpenCode `/init` separately reads the create-agents-md body with its Rosey binding.\n\n"
        + row [
          "Command"
          "Description"
          "Associated agent"
          "Visibility"
          "Claude Code"
          "OpenCode"
          "Codex"
          "Pi"
        ]
        + row (lib.replicate 8 "---")
        + lib.concatMapStrings (
          command:
          row (
            [
              "[${command.name}](${command.link})"
              command.description
              command.agent
              command.visibility
            ]
            ++ map (client: command.clients.${client}.behaviour) clients
          )
        ) commands
        + "\n## Client metadata differences\n\nOnly description overrides and nonempty argument hints are shown. When any client has an argument hint, all clients are listed to show absent hints. Same as common means no description override. Unset means that the argument hint is absent.\n\n"
        + row [
          "Command"
          "Client"
          "Description override"
          "Argument hint"
        ]
        + row (lib.replicate 4 "---")
        + lib.concatMapStrings (
          command:
          let
            hasHints = lib.any (
              client:
              let
                hint = command.clients.${client}.argumentHint;
              in
              hint != null && hint != ""
            ) clients;
          in
          lib.concatMapStrings (
            client:
            let
              entry = command.clients.${client};
              overridesDescription = entry.description != command.description;
            in
            lib.optionalString (hasHints || overridesDescription) (row [
              "[${command.name}](${command.link})"
              client
              (if overridesDescription then entry.description else "Same as common")
              entry.argumentHint
            ])
          ) clients
        ) commands
        + "\nSee the [agent catalogue](../agents/README.md) for agent model defaults and projected client controls.\n"
      )
    )
  );
  agentsMarkdown = builtins.deepSeq agentRecords (
    builtins.deepSeq agents (
      "# Assistant agents\n\n"
      + generatedNotice
      + catalogueNotice
      + row [
        "Agent"
        "Description"
        "Availability"
      ]
      + row (lib.replicate 3 "---")
      + lib.concatMapStrings (
        agent:
        row [
          "[${agent.name}](${agent.link})"
          agent.description
          agent.availability
        ]
      ) agentRecords
      + "\n## Projected client controls\n\nPi defaults come from metadata.project. Descriptions show the client projection, including any override. These controls do not grant authority or list observed runtime tools.\n\n"
      + row [
        "Agent"
        "Client"
        "Description"
        "Controls"
      ]
      + row (lib.replicate 4 "---")
      + lib.concatMapStrings (
        agent:
        lib.concatMapStrings (
          client:
          row [
            agent.name
            client
            agent.clients.${client}.description
            (controlsText agent.clients.${client}.controls)
          ]
        ) clients
      ) agentRecords
      + "\n## Agent model defaults\n\nThese are declared agent defaults, not command or caller model assignments. Unset values leave runtime fallback unchanged. Provider routes depend on the active inference provider. OpenCode provider routes apply only to direct-root native task children, not direct slash-command bindings. Explicit supported overrides take precedence. Inline personas do not apply agent model defaults.\n\n"
      + row [
        "Agent"
        "Client"
        "Inference provider"
        "Model"
        "Effort / thinking"
      ]
      + row (lib.replicate 5 "---")
      + lib.concatMapStrings (
        agent:
        row [
          agent.agent
          agent.client
          agent.provider
          agent.model
          agent.effort
        ]
      ) agents
    )
  );
  skillsMarkdown = builtins.deepSeq skillRecords (
    builtins.seq collisionCheck (
      "# Assistant skills\n\n"
      + generatedNotice
      + catalogueNotice
      + "Only top-level skills are listed. Nested reference files are not separate entries. Generated delegate-task uses public metadata without reading its body. Secret bodies include their own metadata, so their descriptions and policies are unknown here. Workspace skills require both a developer user and a cg host, in addition to client enablement.\n\n"
      + row [
        "Skill"
        "Description"
        "Visibility"
        "Source type"
        "Availability"
      ]
      + row (lib.replicate 5 "---")
      + lib.concatMapStrings (
        skill:
        row [
          "[${skill.name}](${skill.link})"
          (if skill.description == null then "Unknown (secret metadata)" else skill.description)
          skill.visibility
          skill.sourceType
          skill.availability
        ]
      ) skillRecords
      + "\n## Native invocation policy and projected controls\n\nClaude Code uses user-invocable and disable-model-invocation. Codex uses companion policy.allow_implicit_invocation. Pi uses disable-model-invocation. OpenCode has no invocation-policy projection here. Absent fields leave client defaults unchanged. Ordinary skills do not inherit the manual-only policy of Codex command-derived skills. Skill loading grants no additional authority.\n\n"
      + row [
        "Skill"
        "Client"
        "Description"
        "Invocation policy"
        "Projected controls"
      ]
      + row (lib.replicate 5 "---")
      + lib.concatMapStrings (
        skill:
        lib.concatMapStrings (
          client:
          let
            entry = skill.clients.${client};
          in
          row [
            skill.name
            client
            (if entry.description == null then "Unknown (secret metadata)" else entry.description)
            (controlsText entry.invocationPolicy)
            (controlsText entry.controls)
          ]
        ) clients
      ) skillRecords
    )
  );
in
{
  inherit
    commands
    agents
    agentRecords
    skillRecords
    commandsMarkdown
    agentsMarkdown
    skillsMarkdown
    ;
  markdown = commandsMarkdown;
}
