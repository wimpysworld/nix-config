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
  collisionCheck = compose.assertNoCommandCollisions {
    context = "Catalogue command and skill names";
    sources =
      compose.commandSources
      ++ lib.mapAttrsToList (name: _: {
        inherit name;
        source = "skill: ${name}";
      }) (compose.skillDirs // compose.secretSkillDirs);
  };
  markdown = builtins.deepSeq commands (
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
    )
  );
in
{
  inherit commands agents markdown;
}
