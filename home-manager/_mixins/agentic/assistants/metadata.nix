{ lib }:
let
  providers = [
    "claude"
    "opencode"
    "codex"
    "pi"
  ];
  companionKeys = [
    "interface"
    "policy"
    "dependencies"
  ];
  modelKeys = [
    "model"
    "effort"
    "model_reasoning_effort"
    "reasoningEffort"
    "thinking"
  ];
  fail = path: message: throw "${toString path}/header.toml: ${message}";
  nonEmptyString = value: builtins.isString value && lib.trim value != "";
  noNull =
    value:
    if builtins.isAttrs value then
      lib.all noNull (builtins.attrValues value)
    else if builtins.isList value then
      lib.all noNull value
    else
      value != null;
  readHeader =
    path:
    let
      header = builtins.fromTOML (builtins.readFile (path + "/header.toml"));
      unknown = lib.subtractLists (
        [
          "common"
          "compose"
          "routing"
        ]
        ++ providers
      ) (builtins.attrNames header);
      nativeModels =
        lib.concatMap
          (
            native:
            lib.filter (
              key: lib.elem key modelKeys || lib.hasPrefix "model-" key || lib.hasPrefix "thinking-" key
            ) (builtins.attrNames native)
          )
          (
            map (provider: header.${provider} or { }) ([ "common" ] ++ providers)
            ++ [ (header.opencode.options or { }) ]
          );
      routing = header.routing or { };
      unsupportedSkill =
        builtins.pathExists (path + "/SKILL.md")
        && lib.any (provider: (routing.${provider} or { }) != { }) [
          "codex"
          "opencode"
        ];
      routeValid =
        provider: route:
        let
          allowed =
            if provider == "claude" then
              [
                "model"
                "effort"
              ]
            else if provider == "codex" then
              [
                "model"
                "model_reasoning_effort"
              ]
            else if provider == "opencode" then
              [
                "model"
                "reasoningEffort"
              ]
            else
              [
                "model"
                "thinking"
              ];
        in
        builtins.isAttrs route
        && lib.all (key: lib.elem key allowed) (builtins.attrNames route)
        && lib.all nonEmptyString (builtins.attrValues route)
        && (
          !(route ? thinking)
          || lib.elem route.thinking [
            "off"
            "minimal"
            "low"
            "medium"
            "high"
            "xhigh"
            "max"
          ]
        );
      routesValid = lib.all (
        provider:
        lib.elem provider providers
        && (
          if provider == "pi" then
            builtins.isAttrs routing.pi && lib.all (routeValid "pi") (builtins.attrValues routing.pi)
          else
            routeValid provider routing.${provider}
        )
      ) (builtins.attrNames routing);
      controls = header.compose or { };
      controlValid =
        lib.all (
          key:
          lib.elem key [
            "agent"
            "claude"
            "codex"
          ]
        ) (builtins.attrNames controls)
        &&
          lib.all
            (
              provider:
              builtins.isAttrs (controls.${provider} or { })
              && lib.all (
                key:
                lib.elem key (if provider == "claude" then [ "use-task" ] else [ "spawn-agent" ])
                && builtins.isBool controls.${provider}.${key}
              ) (builtins.attrNames (controls.${provider} or { }))
            )
            [
              "claude"
              "codex"
            ];
    in
    if unknown != [ ] then
      fail path "Unknown tables: ${lib.concatStringsSep ", " unknown}."
    else if !noNull header then
      fail path "Null metadata is not supported."
    else if nativeModels != [ ] then
      fail path "Model settings belong exclusively in routing tables."
    else if unsupportedSkill then
      fail path "Codex and OpenCode skill routing has no supported native execution boundary."
    else if !routesValid then
      fail path "Invalid routing provider, field, or value."
    else if !controlValid then
      fail path "Composition switches must be booleans."
    else if controls ? agent && !nonEmptyString controls.agent then
      fail path "compose.agent must be a non-empty string."
    else
      header;

  project =
    kind: platform: name: header:
    let
      common = header.common or { };
      allowed =
        if kind == "skill" then
          [
            "name"
            "description"
            "license"
            "compatibility"
            "metadata"
            "allowed-tools"
          ]
        else if kind == "command" then
          [ "description" ] ++ lib.optional (platform != "codex") "argument-hint"
        else if kind == "agent" then
          [ "description" ]
        else
          [ ];
      defaults = lib.optionalAttrs (kind == "agent" && platform == "pi") {
        systemPromptMode = "append";
        inheritProjectContext = false;
        inheritSkills = true;
      };
      native =
        if kind == "skill" && platform == "codex" then
          lib.removeAttrs (header.codex or { }) companionKeys
        else
          header.${platform} or { };
      route = (header.routing or { }).${platform} or { };
      unsupported =
        (
          kind == "skill"
          && lib.elem platform [
            "codex"
            "opencode"
          ]
          && route != { }
        )
        || (kind == "instructions" && route != { })
        || (platform == "opencode" && kind == "command" && route ? reasoningEffort);
      projectedRoute = if platform == "pi" then { } else route;
      identity = lib.optionalAttrs (
        kind == "agent"
        && lib.elem platform [
          "claude"
          "pi"
          "codex"
        ]
      ) { inherit name; };
      result = lib.foldl' lib.recursiveUpdate { } [
        defaults
        (lib.getAttrs (lib.intersectLists allowed (builtins.attrNames common)) common)
        native
        projectedRoute
        identity
      ];
      validSkill =
        kind != "skill"
        || (
          (common.name or "") == name
          && builtins.stringLength name <= 64
          && builtins.match "[a-z0-9]+(-[a-z0-9]+)*" name != null
          && nonEmptyString (common.description or "")
        );
    in
    if unsupported then
      throw "Unsupported ${platform} routing for ${kind} ${name}."
    else if !validSkill then
      throw "Invalid skill identity or description for ${name}."
    else if native ? name && native.name != name then
      throw "Provider name must match ${name}."
    else
      result;

  renderYaml =
    value:
    lib.concatStringsSep "\n" (
      lib.mapAttrsToList (
        key: item:
        "${
          if builtins.match "[A-Za-z0-9_-]+" key != null then key else builtins.toJSON key
        }: ${builtins.toJSON item}"
      ) value
    );
  renderToml =
    value:
    let
      scalar =
        item:
        if builtins.isAttrs item then
          "{ ${
            lib.concatStringsSep ", " (lib.mapAttrsToList (key: v: "${builtins.toJSON key} = ${scalar v}") item)
          } }"
        else if builtins.isList item then
          "[${lib.concatMapStringsSep ", " scalar item}]"
        else
          builtins.toJSON item;
    in
    lib.concatStringsSep "\n" (
      lib.mapAttrsToList (key: item: "${builtins.toJSON key} = ${scalar item}") value
    );

  commandDispatch =
    knownAgents: cmdName: agentName: header:
    let
      selectedAgent = header.compose.agent or agentName;
      spawn = header.compose.codex.spawn-agent or true;
      route = header.routing.codex or { };
    in
    if selectedAgent != null && !(knownAgents ? ${selectedAgent}) then
      throw "Unknown Codex agent ${selectedAgent} for ${cmdName}."
    else if route != { } && (selectedAgent == null || !spawn) then
      throw "Codex command ${cmdName} routes inline work. Select an agent with spawn-agent = true, or remove routing.codex."
    else
      {
        inherit selectedAgent spawn route;
        role = if route == { } then selectedAgent else "command-${cmdName}";
      };

  commandPolicy =
    header:
    let
      value =
        header.codex.policy.allow_implicit_invocation or (header.codex.allow-implicit-invocation or false);
    in
    if value != false then
      throw "Codex commands require policy.allow_implicit_invocation = false."
    else
      lib.recursiveUpdate (header.codex or { }) { policy.allow_implicit_invocation = false; };

  skillCompanion =
    path:
    let
      native = (readHeader path).codex or { };
      companion = lib.getAttrs (lib.intersectLists companionKeys (builtins.attrNames native)) native;
      policy = companion.policy or { };
    in
    if companion != { } && builtins.pathExists (path + "/agents/openai.yaml") then
      fail path "Codex companion metadata conflicts with agents/openai.yaml. Keep one metadata source."
    else if
      companion != { }
      && builtins.pathExists (path + "/agents")
      && (builtins.readDir path).agents != "directory"
    then
      fail path "Codex companion metadata requires agents to be a directory."
    else if policy ? allow_implicit_invocation && !builtins.isBool policy.allow_implicit_invocation then
      fail path "codex.policy.allow_implicit_invocation must be a boolean."
    else
      companion;
in
{
  inherit
    readHeader
    project
    renderYaml
    renderToml
    commandDispatch
    commandPolicy
    skillCompanion
    ;
}
