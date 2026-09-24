{
  lib,
  pkgs,
  revision ? "runtime-required",
}:
let
  assistantsPath = ../../home-manager/_mixins/agentic/assistants;
  compose = import (assistantsPath + "/compose.nix") {
    inherit lib pkgs;
    basePath = assistantsPath;
    gwsEnabled = false;
  };
  mcp = import ../../home-manager/_mixins/agentic/mcp/servers.nix {
    inherit pkgs;
    config = {
      noughty.host.tags = [ ];
      sops.placeholder = { };
    };
  };

  clients = [
    "claude"
    "opencode"
    "codex"
    "pi"
  ];

  publicAgents = [
    "batfink"
    "brain"
    "casper"
    "dibble"
    "donatello"
    "garfield"
    "gonzales"
    "penfold"
    "penry"
    "rosey"
    "velma"
  ];

  publicCommands = [
    "ack"
    "add-agentic-repo-capability"
    "address-code-review"
    "ahem"
    "align-documentation"
    "ask"
    "audit-code-security"
    "audit-infra-security"
    "call"
    "clarify-plan"
    "collaborate"
    "create-agents-md"
    "create-assistant"
    "create-command"
    "create-plan"
    "create-project"
    "create-skill"
    "create-task"
    "draft-blog-post"
    "draft-code-review"
    "draft-commit-message"
    "draft-pr-message"
    "draft-readme"
    "draft-video-script"
    "finish-pr"
    "gist"
    "handover-fork"
    "handover-fresh"
    "implement-plan"
    "implement-task"
    "make-commit"
    "oi"
    "orientate"
    "post-code-review"
    "post-issue"
    "project-code-review"
    "project-documentation-review"
    "project-peer-review"
    "project-performance-review"
    "project-polish-comments"
    "project-smells-review"
    "project-tests-review"
    "ready"
    "review-code-again"
    "review-code-colleague"
    "review-code-community"
    "review-code-mine"
    "review-task"
    "triage-tasks"
    "update-agents-md"
    "update-assistant"
    "update-command"
    "update-skill"
    "update-task"
    "work-order-create"
    "work-order-next"
    "work-order-plan"
    "work-order-update"
  ];

  publicSkills = [
    "agentic-repo-capability"
    "audio-metrics"
    "communication-rules"
    "contribution-voice"
    "deep-research"
    "delegate-task"
    "diagram-design"
    "draft-comment"
    "draft-issue"
    "draft-project-description"
    "gh"
    "how-to-contribute"
    "nix"
    "research-task"
    "review-code"
    "review-code-follow-up"
    "review-report-path"
    "semgrep"
    "sizing"
    "task-tracker"
    "work-order-format"
    "write-agents-md"
    "write-assistant"
    "write-command"
    "write-skill"
    "writing-well"
  ];

  roots = {
    claude = "claude/.claude";
    opencode = "opencode/.config/opencode";
    codex = "codex/.codex";
    pi = "pi/.pi/agent";
  };

  mkFile =
    {
      path,
      content,
      mode ? "0644",
      dependencies ? [ ],
    }:
    {
      inherit
        path
        content
        mode
        dependencies
        ;
    };

  executableMode =
    name: if lib.hasSuffix ".py" name || lib.hasSuffix ".sh" name then "0755" else "0644";

  diagramAssetFamilies = [
    "example-architecture"
    "example-bar"
    "example-beeswarm"
    "example-bubble"
    "example-bump"
    "example-data-flow"
    "example-datalake"
    "example-db-schema"
    "example-dependency"
    "example-deployment"
    "example-dp-integration"
    "example-dp-security-matrix"
    "example-er"
    "example-fishbone"
    "example-flowchart"
    "example-gantt"
    "example-high-level"
    "example-high-level-vertical"
    "example-it-state"
    "example-journey"
    "example-kanban"
    "example-layers"
    "example-line"
    "example-loop"
    "example-medallion"
    "example-nested"
    "example-org-chart"
    "example-polar"
    "example-process"
    "example-pyramid"
    "example-quadrant"
    "example-radar"
    "example-ridgeline"
    "example-sankey"
    "example-scatter"
    "example-sequence"
    "example-sequence-oauth"
    "example-slopegraph"
    "example-state"
    "example-story-map"
    "example-swimlane"
    "example-timeline"
    "example-tree"
    "example-tree-block-decomposition"
    "example-treemap"
    "example-uml-class"
    "example-venn"
    "example-wardley"
    "example-waterfall"
    "template"
  ];

  diagramAssets =
    lib.concatMap (
      name:
      map (suffix: "assets/${name}${suffix}.html") [
        ""
        "-dark"
        "-full"
      ]
    ) diagramAssetFamilies
    ++ map (name: "assets/${name}") [
      "example-import-drawio.html"
      "example-import-excalidraw.html"
      "example-import-mermaid.html"
      "example-loop-terminal.html"
      "example-paved-road-animated.html"
      "example-policy-trace-animated.html"
      "example-quadrant-consultant.html"
      "example-queue-animated.html"
      "icons.html"
      "index.html"
      "template-motion.html"
      "template-terminal.html"
    ];

  diagramReferences = map (name: "references/${name}.md") [
    "animation"
    "doctor"
    "export"
    "export-registry"
    "import-drawio"
    "import-excalidraw"
    "import-mermaid"
    "onboarding"
    "output-spec"
    "primitive-annotation"
    "primitive-icons"
    "primitive-sketchy"
    "primitive-terminal"
    "profiles"
    "semantic-patterns"
    "style-guide"
    "type-architecture"
    "type-bar"
    "type-data-flow"
    "type-db-schema"
    "type-dependency"
    "type-deployment"
    "type-dp-integration"
    "type-dp-security-matrix"
    "type-er"
    "type-fishbone"
    "type-flowchart"
    "type-gantt"
    "type-high-level"
    "type-it-state"
    "type-journey"
    "type-kanban"
    "type-layers"
    "type-line"
    "type-loop"
    "type-medallion"
    "type-nested"
    "type-org-chart"
    "type-polar"
    "type-process"
    "type-pyramid"
    "type-quadrant"
    "type-radar"
    "type-sankey"
    "type-scatter"
    "type-sequence"
    "type-state"
    "type-story-map"
    "type-swimlane"
    "type-timeline"
    "type-tree"
    "type-treemap"
    "type-uml-class"
    "type-venn"
    "type-wardley"
    "type-waterfall"
  ];

  reviewedSupportingFiles = [
    "hooks/communication-rules/core/__init__.py"
    "hooks/communication-rules/core/config.py"
    "hooks/communication-rules/core/detection.py"
    "hooks/communication-rules/core/dispatch.py"
    "hooks/communication-rules/core/extractors/__init__.py"
    "hooks/communication-rules/core/extractors/claude_code.py"
    "hooks/communication-rules/core/extractors/codex.py"
    "hooks/communication-rules/core/extractors/opencode.py"
    "hooks/communication-rules/core/extractors/pi.py"
    "hooks/communication-rules/core/responses.py"
    "hooks/communication-rules/core/state.py"
    "hooks/communication-rules/core/types.py"
    "pi/extensions/hardware-cursor/index.ts"
    "pi/extensions/prompt-template-display/index.test.ts"
    "pi/extensions/prompt-template-display/index.ts"
    "pi/extensions/prompt-template-display/test-loader.mjs"
    "pi/extensions/prompt-template-display/types.d.ts"
    "skills/agentic-repo-capability/references/command.md"
    "skills/agentic-repo-capability/references/mcp.md"
    "skills/agentic-repo-capability/references/skill.md"
    "skills/diagram-design/LICENSE"
    "skills/diagram-design/THIRD_PARTY_LICENSES.md"
    "skills/diagram-design/scripts/drawio_extract.py"
    "skills/diagram-design/scripts/excalidraw_extract.py"
    "skills/diagram-design/scripts/mermaid_extract.py"
    "skills/diagram-design/scripts/resolve_profile.py"
    "skills/diagram-design/scripts/self_check.py"
    "skills/semgrep/metadata.json"
    "skills/semgrep/references/quick-reference.md"
    "skills/semgrep/references/workflow.md"
    "skills/task-tracker/references/github-projects.md"
    "skills/task-tracker/references/linear.md"
    "skills/write-agents-md/references/migration.md"
    "skills/write-agents-md/references/platforms.md"
    "skills/write-agents-md/references/sections.md"
    "skills/write-assistant/references/structure.md"
    "skills/write-assistant/references/triggers.md"
    "skills/write-assistant/references/voice.md"
    "skills/write-command/references/portability.md"
    "skills/write-command/references/repo-conventions.md"
    "skills/write-command/references/templates.md"
    "skills/write-skill/references/evaluations.md"
    "skills/write-skill/references/portability.md"
    "skills/writing-well/reference.md"
  ]
  ++ map (path: "skills/diagram-design/${path}") (diagramAssets ++ diagramReferences);

  reviewedExcludedFiles = [
    "hooks/communication-rules/core/__pycache__/__init__.cpython-313.pyc"
    "hooks/communication-rules/core/__pycache__/__init__.cpython-314.pyc"
    "hooks/communication-rules/core/__pycache__/config.cpython-313.pyc"
    "hooks/communication-rules/core/__pycache__/config.cpython-314.pyc"
    "hooks/communication-rules/core/__pycache__/detection.cpython-313.pyc"
    "hooks/communication-rules/core/__pycache__/detection.cpython-314.pyc"
    "hooks/communication-rules/core/__pycache__/dispatch.cpython-313.pyc"
    "hooks/communication-rules/core/__pycache__/dispatch.cpython-314.pyc"
    "hooks/communication-rules/core/__pycache__/responses.cpython-313.pyc"
    "hooks/communication-rules/core/__pycache__/responses.cpython-314.pyc"
    "hooks/communication-rules/core/__pycache__/state.cpython-313.pyc"
    "hooks/communication-rules/core/__pycache__/state.cpython-314.pyc"
    "hooks/communication-rules/core/__pycache__/types.cpython-313.pyc"
    "hooks/communication-rules/core/__pycache__/types.cpython-314.pyc"
    "hooks/communication-rules/core/extractors/__pycache__/__init__.cpython-313.pyc"
    "hooks/communication-rules/core/extractors/__pycache__/__init__.cpython-314.pyc"
    "hooks/communication-rules/core/extractors/__pycache__/claude_code.cpython-313.pyc"
    "hooks/communication-rules/core/extractors/__pycache__/claude_code.cpython-314.pyc"
    "hooks/communication-rules/core/extractors/__pycache__/codex.cpython-313.pyc"
    "hooks/communication-rules/core/extractors/__pycache__/codex.cpython-314.pyc"
    "hooks/communication-rules/core/extractors/__pycache__/opencode.cpython-313.pyc"
    "hooks/communication-rules/core/extractors/__pycache__/opencode.cpython-314.pyc"
    "hooks/communication-rules/core/extractors/__pycache__/pi.cpython-313.pyc"
    "hooks/communication-rules/core/extractors/__pycache__/pi.cpython-314.pyc"
    "skills/diagram-design/scripts/__pycache__/resolve_profile.cpython-313.pyc"
  ];

  discoverSourceFiles =
    source: relative:
    lib.concatLists (
      lib.mapAttrsToList (
        name: type:
        let
          sourcePath = source + "/${name}";
          relativePath = if relative == "" then name else "${relative}/${name}";
        in
        if type == "directory" then
          discoverSourceFiles sourcePath relativePath
        else if type == "regular" then
          [ relativePath ]
        else
          throw "The public export allowlist contains an unsupported source entry: ${toString sourcePath} (${type})."
      ) (builtins.readDir source)
    );

  validateSupportingFiles =
    sourceKey: reviewed: ignored: discovered:
    let
      unknown = lib.subtractLists (reviewed ++ ignored) discovered;
      missing = lib.subtractLists discovered reviewed;
    in
    if unknown != [ ] then
      throw "The public export source ${sourceKey} contains unreviewed supporting files: ${lib.concatStringsSep ", " unknown}."
    else if missing != [ ] then
      throw "The public export source ${sourceKey} is missing reviewed supporting files: ${lib.concatStringsSep ", " missing}."
    else
      reviewed;

  sourceTree =
    {
      destination,
      sourceKey,
      source,
      ignored ? [ ],
    }:
    let
      prefix = "${sourceKey}/";
      reviewed = map (lib.removePrefix prefix) (
        lib.filter (lib.hasPrefix prefix) reviewedSupportingFiles
      );
      reviewedExcluded = map (lib.removePrefix prefix) (
        lib.filter (lib.hasPrefix prefix) reviewedExcludedFiles
      );
      discovered = discoverSourceFiles source "";
      checked = validateSupportingFiles sourceKey reviewed (ignored ++ reviewedExcluded) discovered;
    in
    map (
      relative:
      let
        sourcePath = source + "/${relative}";
        name = baseNameOf relative;
      in
      mkFile {
        path = "${destination}/${relative}";
        content = builtins.readFile sourcePath;
        mode = executableMode name;
      }
    ) checked;

  supportingAllowlistTests =
    let
      topLevel = builtins.tryEval (
        validateSupportingFiles "synthetic" [ "known.txt" ] [ ] [ ".env" "known.txt" ]
      );
      nested = builtins.tryEval (
        validateSupportingFiles "synthetic" [ "known.txt" ] [ ] [ "known.txt" "nested/unknown" ]
      );
    in
    assert !topLevel.success;
    assert !nested.success;
    true;

  agentPath =
    client: name:
    if client == "codex" then
      "${roots.${client}}/agents/${name}.toml"
    else
      "${roots.${client}}/agents/${name}.md";

  agentContent =
    client: name:
    if client == "codex" then
      compose.composeCodexAgent name
    else if client == "pi" then
      let
        prompt = lib.trim (builtins.readFile (assistantsPath + "/agents/${name}/prompt.md"));
      in
      compose.composeAgentFromPrompt "pi" name (compose.adaptAgentPrompt "pi" prompt)
    else
      compose.composeAgent client name;

  agentFiles = lib.concatMap (
    client:
    map (
      name:
      mkFile {
        path = agentPath client name;
        content = agentContent client name;
      }
    ) publicAgents
  ) clients;

  commandFiles = lib.concatMap (
    client:
    lib.concatMap (
      name:
      if client == "codex" then
        [
          (mkFile {
            path = "${roots.codex}/skills/${name}/SKILL.md";
            content = compose.composeCodexCommandSkill name;
          })
          (mkFile {
            path = "${roots.codex}/skills/${name}/agents/openai.yaml";
            content = compose.composeCodexCommandCompanion name + "\n";
          })
        ]
      else
        [
          (mkFile {
            path =
              if client == "pi" then
                "${roots.pi}/prompts/${name}.md"
              else
                "${roots.${client}}/commands/${name}.md";
            content = compose.composeCommand client name;
          })
        ]
    ) publicCommands
  ) clients;

  skillFilesFor =
    client: name:
    let
      root = "${roots.${client}}/skills/${name}";
      rendered = (compose.composeSkillsFor client).${name}.content;
      source = assistantsPath + "/skills/${name}";
    in
    [
      (mkFile {
        path = "${root}/SKILL.md";
        content = rendered;
      })
    ]
    ++ sourceTree {
      destination = root;
      sourceKey = "skills/${name}";
      inherit source;
      ignored = [
        "SKILL.md"
        "header.toml"
      ];
    };

  skillFileGroups = lib.concatMap (client: map (skillFilesFor client) publicSkills) clients;

  publicMcp = lib.getAttrs [
    "context7"
    "exa"
    "linear"
  ] mcp.servers;

  # Keep these package specs equal to the canonical pins in
  # home-manager/_mixins/agentic/pi/default.nix. The package test checks drift.
  piMcpAdapterSource = "npm:pi-mcp-adapter@2.37.0";
  piSubagentsSource = "npm:@tintinweb/pi-subagents@0.19.0";

  piSubagentsConfig = {
    backgroundByDefault = true;
    maxConcurrent = 12;
    maxConcurrentForeground = 12;
    maxSubagentDepth = 1;
    defaultMaxTurns = 50;
    graceTurns = 5;
    defaultJoinMode = "async";
    disableDefaultAgents = true;
    fallbackSubagent = "none";
    strictAgentFiles = true;
    rememberAgents = true;
    outputTranscript = true;
    workflowsEnabled = true;
    agentMentions = "off";
    schedulingEnabled = false;
    worktreeIsolation = false;
  };

  portableInstructions = ''
    # Portable global rules

    ## Scope

    This export is a review bundle. Use a workflow only when its named tools and services are available to the recipient.

    Do not infer access to credentials, private models, sandbox policy, host wrappers, or external write tools from these files.

    ## Delegation

    A coordinator owns planning, dispatch, integration, and explicitly assigned inline work. A worker completes its bounded task and returns to its parent.

    Keep at most twelve workers active. A worker must not launch another worker. If more specialist work is necessary, the worker returns a bounded request to its parent.

    Preserve an artefact verbatim when a later step consumes it unchanged. Keep reports concise and include decisions, evidence, changes, tests, and blockers.

    ## Tools and safety

    Use only tools that the current client exposes. Read current technical documentation before use when an API or package can change.

    Do not change external state without explicit user authority. Do not expose secrets, tokens, or credentials.

    Do not delete or overwrite data, backups, or production state without explicit consent. Preserve unrelated work and use the repository's validation commands.

    ## Communication

    Apply the `communication-rules` skill to user-visible prose. Keep commands, paths, identifiers, quoted text, and numbers exact.
  '';

  composePortableInstructions =
    client:
    lib.replaceStrings
      [ (builtins.readFile (assistantsPath + "/instructions/global.md")) ]
      [ portableInstructions ]
      (compose.composeInstructions client);

  claudeMcp = {
    mcpServers.exa = {
      type = "http";
      inherit (publicMcp.exa) url;
    };
  };

  piMcp = {
    settings = {
      directTools = false;
      disableProxyTool = false;
      autoAuth = false;
      sampling = false;
      samplingAutoApprove = false;
    };
    mcpServers.exa = {
      type = "http";
      inherit (publicMcp.exa) url;
      enabled = true;
      directTools = true;
    };
  };

  palette = (builtins.fromJSON (builtins.readFile ../../lib/catppuccin-palette.json)).mocha.colors;
  piThemeName = "catppuccin-mocha";
  piTheme = {
    "$schema" =
      "https://raw.githubusercontent.com/badlogic/pi-mono/main/packages/coding-agent/src/modes/interactive/theme/theme-schema.json";
    name = piThemeName;
    vars = lib.mapAttrs (_: colour: colour.hex) palette;
    colors = {
      accent = "blue";
      border = "surface2";
      borderAccent = "blue";
      borderMuted = "surface0";
      success = "green";
      error = "red";
      warning = "yellow";
      muted = "subtext0";
      dim = "overlay0";
      text = "text";
      thinkingText = "overlay2";
      selectedBg = "surface0";
      userMessageBg = "mantle";
      userMessageText = "yellow";
      customMessageBg = "surface0";
      customMessageText = "text";
      customMessageLabel = "mauve";
      toolPendingBg = "mantle";
      toolSuccessBg = "#282839";
      toolErrorBg = "#282839";
      toolTitle = "sapphire";
      toolOutput = "subtext1";
      mdHeading = "mauve";
      mdLink = "blue";
      mdLinkUrl = "sapphire";
      mdCode = "teal";
      mdCodeBlock = "text";
      mdCodeBlockBorder = "surface1";
      mdQuote = "subtext0";
      mdQuoteBorder = "surface1";
      mdHr = "surface1";
      mdListBullet = "peach";
      toolDiffAdded = "green";
      toolDiffRemoved = "red";
      toolDiffContext = "overlay1";
      syntaxComment = "overlay1";
      syntaxKeyword = "mauve";
      syntaxFunction = "blue";
      syntaxVariable = "text";
      syntaxString = "green";
      syntaxNumber = "peach";
      syntaxType = "yellow";
      syntaxOperator = "sky";
      syntaxPunctuation = "overlay2";
      thinkingOff = "surface1";
      thinkingMinimal = "overlay0";
      thinkingLow = "sapphire";
      thinkingMedium = "blue";
      thinkingHigh = "mauve";
      thinkingXhigh = "pink";
      bashMode = "peach";
    };
    export = {
      pageBg = "base";
      cardBg = "mantle";
      infoBg = "surface0";
    };
  };

  opencodeRouterPlugin = ''
    import { readFileSync } from "node:fs";
    import createRouter from "./provider-router/index.mjs";

    export default async function ProviderRouter({ client }) {
      const routes = JSON.parse(
        readFileSync(new URL("./provider-router/routes.json", import.meta.url), "utf8"),
      );
      return createRouter(client, routes);
    }
  '';

  portableFiles = [
    (mkFile {
      path = "claude/.mcp.json";
      content = builtins.toJSON claudeMcp + "\n";
    })
    (mkFile {
      path = "${roots.claude}/settings.json";
      content =
        builtins.toJSON {
          autoUpdatesChannel = "stable";
          cleanupPeriodDays = 365;
          env = {
            CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = "1";
            DISABLE_ERROR_REPORTING = "1";
            DISABLE_TELEMETRY = "1";
          };
          outputStyle = "house-style";
        }
        + "\n";
    })
    (mkFile {
      path = "${roots.claude}/rules/instructions.md";
      content = composePortableInstructions "claude";
    })
    (mkFile {
      path = "${roots.claude}/output-styles/house-style.md";
      content = compose.houseStyleOutputStyle + "\n";
    })
    (mkFile {
      path = "${roots.opencode}/opencode.json";
      content =
        builtins.toJSON {
          "$schema" = "https://opencode.ai/config.json";
          autoupdate = false;
          share = "disabled";
          experimental.openTelemetry = false;
          permission = {
            webfetch = "deny";
            websearch = "deny";
          };
          compaction = {
            auto = false;
            prune = true;
          };
          mcp = lib.getAttrs [
            "context7"
            "exa"
            "linear"
          ] mcp.opencodeServers;
          plugin = [ "./plugins/provider-router.ts" ];
        }
        + "\n";
    })
    (mkFile {
      path = "${roots.opencode}/AGENTS.md";
      content = composePortableInstructions "opencode" + "\n" + compose.houseStyleBody + "\n";
    })
    (mkFile {
      path = "${roots.opencode}/plugins/provider-router.ts";
      content = opencodeRouterPlugin;
      dependencies = [ "OpenCode plugin runtime" ];
    })
    (mkFile {
      path = "${roots.opencode}/plugins/provider-router/index.mjs";
      content = builtins.readFile ../../home-manager/_mixins/agentic/opencode/provider-router/index.mjs;
    })
    (mkFile {
      path = "${roots.opencode}/plugins/provider-router/routes.json";
      content =
        builtins.toJSON (
          lib.filterAttrs (_: routes: routes != { }) (
            lib.genAttrs publicAgents compose.extractOpenCodeProviderModels
          )
        )
        + "\n";
    })
    (mkFile {
      path = "${roots.codex}/AGENTS.md";
      content = composePortableInstructions "codex";
    })
    (mkFile {
      path = "${roots.codex}/config.toml";
      content =
        compose.renderToml {
          approval_policy = "on-request";
          sandbox_mode = "workspace-write";
          web_search = "disabled";
          features = {
            collaboration_modes = true;
            skills = true;
          };
          mcp_servers = lib.getAttrs [
            "context7"
            "exa"
            "linear"
          ] mcp.codexServers;
        }
        + "\n";
    })
    (mkFile {
      path = "${roots.pi}/AGENTS.md";
      content = composePortableInstructions "pi" + "\n" + compose.houseStyleBody + "\n";
    })
    (mkFile {
      path = "${roots.pi}/settings.json";
      content =
        builtins.toJSON {
          theme = piThemeName;
          quietStartup = true;
          clearOnStart = true;
          collapseChangelog = true;
          enableInstallTelemetry = false;
          enableAnalytics = false;
          doubleEscapeAction = "tree";
          treeFilterMode = "default";
          autocompleteMaxVisible = 8;
          showHardwareCursor = true;
          compaction = {
            enabled = true;
            reserveTokens = 16384;
            keepRecentTokens = 20000;
          };
          retry = {
            enabled = true;
            maxRetries = 5;
            baseDelayMs = 3000;
            provider = {
              maxRetries = 3;
              maxRetryDelayMs = 120000;
            };
          };
          markdown.codeBlockIndent = " ";
          packages = [
            piMcpAdapterSource
            piSubagentsSource
          ];
          skills = [ "skills" ];
          prompts = [ "prompts/*.md" ];
          themes = [ "themes/*.json" ];
          enableSkillCommands = true;
        }
        + "\n";
    })
    (mkFile {
      path = "${roots.pi}/mcp.json";
      content = builtins.toJSON piMcp + "\n";
    })
    (mkFile {
      path = "${roots.pi}/subagents.json";
      content = builtins.toJSON piSubagentsConfig + "\n";
      dependencies = [ piSubagentsSource ];
    })
    (mkFile {
      path = "${roots.pi}/themes/${piThemeName}.json";
      content = builtins.toJSON piTheme + "\n";
    })
    (mkFile {
      path = "${roots.pi}/extensions/provider-router/index.ts";
      content = builtins.readFile ../../home-manager/_mixins/agentic/pi/extensions/provider-router/index.ts;
    })
    (mkFile {
      path = "${roots.pi}/extensions/provider-router/types.d.ts";
      content = builtins.readFile ../../home-manager/_mixins/agentic/pi/extensions/provider-router/types.d.ts;
    })
    (mkFile {
      path = "${roots.pi}/extensions/provider-router/LICENSE";
      content = builtins.readFile ../../home-manager/_mixins/agentic/pi/extensions/provider-router/LICENSE;
    })
    (mkFile {
      path = "${roots.pi}/extensions/provider-router/README.md";
      content = builtins.readFile ../../home-manager/_mixins/agentic/pi/extensions/provider-router/README.md;
    })
    (mkFile {
      path = "${roots.pi}/extensions/provider-router/agents.json";
      content =
        builtins.toJSON (
          lib.filterAttrs (_: routes: routes != { }) (
            lib.genAttrs publicAgents compose.extractAgentProviderModels
          )
        )
        + "\n";
    })
    (mkFile {
      path = "${roots.pi}/extensions/provider-router/thinking.json";
      content =
        builtins.toJSON (
          lib.filterAttrs (_: routes: routes != { }) (
            lib.genAttrs publicAgents compose.extractAgentProviderThinking
          )
        )
        + "\n";
    })
  ]
  ++ sourceTree {
    destination = "${roots.pi}/extensions/hardware-cursor";
    sourceKey = "pi/extensions/hardware-cursor";
    source = ../../home-manager/_mixins/agentic/pi/extensions/hardware-cursor;
  }
  ++ sourceTree {
    destination = "${roots.pi}/extensions/prompt-template-display";
    sourceKey = "pi/extensions/prompt-template-display";
    source = ../../home-manager/_mixins/agentic/pi/extensions/prompt-template-display;
  };

  scannerFiles = [
    (mkFile {
      path = "integrations/communication-rules/scanner.py";
      content = builtins.readFile ../../home-manager/_mixins/agentic/hooks/communication-rules/scanner.py;
      mode = "0755";
      dependencies = [ "Python 3" ];
    })
  ]
  ++ sourceTree {
    destination = "integrations/communication-rules/core";
    sourceKey = "hooks/communication-rules/core";
    source = ../../home-manager/_mixins/agentic/hooks/communication-rules/core;
  };

  resourceCatalogue = {
    schemaVersion = 1;
    inherit
      publicAgents
      publicCommands
      publicSkills
      ;
    excluded = {
      commands = [
        "babysit-pr"
        "draft-self-review"
        "gather-review-data"
        "make-pr"
        "post-comment"
        "reflect"
        "review-open-source-attestation"
        "weekly-update"
        "wtb"
      ];
      skills = [
        "gws-*"
        "herdr"
        "self-review"
        "slack"
        "zk"
      ];
      integrations = [
        "Fence"
        "host and service wrappers"
        "Herdr socket integration"
        "credential and trust stores"
        "runtime state"
      ];
    };
  };

  docsFiles = [
    (mkFile {
      path = "README.md";
      content = builtins.readFile ./README.md;
    })
    (mkFile {
      path = "docs/install.md";
      content = builtins.readFile ./docs/install.md;
    })
    (mkFile {
      path = "docs/dependencies.md";
      content = builtins.readFile ./docs/dependencies.md;
    })
    (mkFile {
      path = "docs/security.md";
      content = builtins.readFile ./docs/security.md;
    })
    (mkFile {
      path = "catalogues/resources.json";
      content = builtins.toJSON resourceCatalogue + "\n";
    })
    (mkFile {
      path = "LICENSE";
      content = builtins.readFile ../../LICENSE;
    })
    (mkFile {
      path = "CODE_OF_CONDUCT.md";
      content = builtins.readFile ../../CODE_OF_CONDUCT.md;
    })
    (mkFile {
      path = "SUPPORT.md";
      content = builtins.readFile ../../SUPPORT.md;
    })
  ];

  fileGroups = [
    agentFiles
    commandFiles
  ]
  ++ skillFileGroups
  ++ [
    portableFiles
    scannerFiles
    docsFiles
  ];
  files = lib.concatLists fileGroups;
  paths = map (file: file.path) files;
  pathCounts = lib.foldl' (
    counts: path: counts // { ${path} = (counts.${path} or 0) + 1; }
  ) { } paths;
  duplicatePaths = builtins.attrNames (lib.filterAttrs (_: count: count > 1) pathCounts);
  checkedFiles =
    assert supportingAllowlistTests;
    if duplicatePaths != [ ] then
      throw "The public export has duplicate paths: ${lib.concatStringsSep ", " duplicatePaths}."
    else
      files;
in
{
  schemaVersion = 1;
  sourceRevision = revision;
  policy = "explicit-public-allowlist";
  files = checkedFiles;
}
