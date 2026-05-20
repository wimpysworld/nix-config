{
  catppuccinPalette,
  config,
  inputs,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  inherit (pkgs.stdenv.hostPlatform) system;
  aiSopsFile = ../../../../secrets/ai.yaml;
  piPackage = inputs.llm-agents.packages.${system}.pi;
  fencePackage = import ../fence/package.nix { inherit inputs pkgs; };
  piMcpAdapterVersion = "2.6.1";
  piSubagentsVersion = "0.24.3";
  piLensVersion = "3.8.44";
  piBarVersion = "0.3.38";
  rpivBtwVersion = "1.10.2";
  rpivTodoVersion = "1.10.2";
  piMcpAdapterSource = "npm:pi-mcp-adapter@${piMcpAdapterVersion}";
  piSubagentsSource = "npm:pi-subagents@${piSubagentsVersion}";
  piLensSource = "npm:pi-lens@${piLensVersion}";
  piBarSource = "npm:pi-bar@${piBarVersion}";
  rpivBtwSource = "npm:@juicesharp/rpiv-btw@${rpivBtwVersion}";
  rpivTodoSource = "npm:@juicesharp/rpiv-todo@${rpivTodoVersion}";
  piAssistant = config.agentic.assistants.pi;
  mcpServerDefs = import ../mcp/servers.nix { inherit config pkgs; };
  piThemeName = "catppuccin-${catppuccinPalette.flavor}";
  piCatppuccinTheme =
    let
      getColor = colorName: catppuccinPalette.getColor colorName;
    in
    {
      "$schema" =
        "https://raw.githubusercontent.com/badlogic/pi-mono/main/packages/coding-agent/src/modes/interactive/theme/theme-schema.json";
      name = piThemeName;
      vars = lib.genAttrs [
        "rosewater"
        "flamingo"
        "pink"
        "mauve"
        "red"
        "maroon"
        "peach"
        "yellow"
        "green"
        "teal"
        "sky"
        "sapphire"
        "blue"
        "lavender"
        "text"
        "subtext1"
        "subtext0"
        "overlay2"
        "overlay1"
        "overlay0"
        "surface2"
        "surface1"
        "surface0"
        "base"
        "mantle"
        "crust"
      ] getColor;
      colors = {
        accent = catppuccinPalette.accent;
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
        userMessageText = "text";
        customMessageBg = "surface0";
        customMessageText = "text";
        customMessageLabel = "mauve";
        toolPendingBg = "mantle";
        toolSuccessBg = "surface0";
        toolErrorBg = "surface0";
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

  # Pi's npm package installer uses global npm operations. Nix's default npm
  # global prefix is the read-only store, so give Pi a user-owned prefix while
  # keeping the npm binary itself from Nixpkgs. Keep routine npm advisory
  # chatter quiet while preserving npm errors and exit status.
  piNpmPackage = pkgs.writeShellApplication {
    name = "pi-npm";
    runtimeInputs = [ pkgs.nodejs ];
    text = ''
      export NPM_CONFIG_PREFIX="${config.home.homeDirectory}/.pi/agent/npm-global"
      export NPM_CONFIG_AUDIT=false
      export NPM_CONFIG_FUND=false
      export NPM_CONFIG_LOGLEVEL=error

      exec npm --loglevel=error --no-audit --no-fund "$@"
    '';
  };

  piWrapperPackage = pkgs.writeShellApplication {
    name = "pi";
    runtimeInputs = [
      piPackage
      pkgs.coreutils
    ];
    text = ''
      anthropic_api_key_path="${config.sops.secrets.ANTHROPIC_API_KEY.path}"
      if [ ! -r "$anthropic_api_key_path" ]; then
        echo "pi: Anthropic API key secret is missing or unreadable: $anthropic_api_key_path" >&2
        exit 1
      fi

      ANTHROPIC_API_KEY="$(cat "$anthropic_api_key_path")"
      export ANTHROPIC_API_KEY

      exec "${lib.getExe piPackage}" "$@"
    '';
  };

  piFencedPackage = pkgs.writeShellApplication {
    name = "pi-fenced";
    runtimeInputs = [ fencePackage ];
    text = ''
      exec fence -- ${lib.getExe' piWrapperPackage "pi"} "$@"
    '';
  };

  piSettings = {
    defaultProvider = "anthropic";
    defaultModel = "claude-opus-4-7";
    defaultThinkingLevel = "high";
    thinkingBudgets = {
      minimal = 1024;
      low = 4096;
      medium = 10240;
      high = 32768;
      xhigh = 64000;
    };
    hideThinkingBlock = true;
    enabledModels = [
      "anthropic/claude-opus-4-7"
      "anthropic/claude-sonnet-4-6"
      "anthropic/claude-haiku-4-5"
    ];

    theme = piThemeName;
    quietStartup = true;
    collapseChangelog = true;
    enableInstallTelemetry = false;
    doubleEscapeAction = "tree";
    treeFilterMode = "default";
    autocompleteMaxVisible = 8;

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
    warnings.anthropicExtraUsage = true;

    # Versioned Pi package specs are pinned and skipped by `pi update`.
    packages = [
      piMcpAdapterSource
      piSubagentsSource
      piLensSource
      piBarSource
      rpivBtwSource
      rpivTodoSource
    ];

    # pi-bar reads `bar.progressModel` from Pi settings to pick the model used
    # for one-line "what is pi doing right now" updates in the footer. Use a
    # fast Anthropic model already enabled above so pi-bar does not have to
    # auto-discover a provider at launch.
    bar.progressModel = "anthropic/claude-haiku-4-5";
    extensions = [ ];
    skills = [
      "skills"
    ];
    prompts = [
      "prompts/*.md"
    ];
    themes = [
      "themes/*.json"
    ];
    enableSkillCommands = true;
    npmCommand = [ "${piNpmPackage}/bin/pi-npm" ];

    subagents = {
      disableBuiltins = false;
      agentOverrides = {
        # This builtin requires pi-web-access, which is not installed in this
        # pass. Keep it visible in /agents but disabled by default.
        researcher.disabled = true;
      };
    };
  };

  piMcpConfig = {
    settings = {
      # Keep Pi's MCP surface to the adapter proxy tool. Project-level
      # `.pi/mcp.json` can override these settings when a project needs a
      # deliberately wider tool surface.
      directTools = false;
      disableProxyTool = false;
      autoAuth = false;
      sampling = false;
      samplingAutoApprove = false;
    };
    # The adapter shallow-merges files by server name, so Pi-specific
    # `directTools` preferences must include full server entries rather than
    # partial overrides.
    mcpServers = mcpServerDefs.piServers;
  };

  piKeybindings = {
    # Bind Ctrl+Q to quit alongside the default Ctrl+D (when editor is empty).
    "app.exit" = [
      "ctrl+d"
      "ctrl+q"
    ];
  };

  # pi-bar persists footer segment choices and extension-status filters in
  # ~/.pi/agent/pi-bar.json. Declare the full segment set so pi-bar's footer
  # mirrors Codex's verbose `tui.status_line` as closely as the extension
  # supports (model+thinking ~ Codex `model-with-reasoning`,
  # context ~ Codex `context-window-size`/`context-used`, progress ~ Codex
  # `run-state`, extensions ~ Codex `permissions`). pi-bar has no analogue
  # for Codex `fast-mode`, `current-dir`, `five-hour-limit`, `weekly-limit`,
  # or `codex-version`. `statusFilter.mode = "all"` keeps every extension
  # status badge visible by default.
  piBarConfig = {
    segments = [
      "model"
      "thinking"
      "context"
      "extensions"
      "progress"
    ];
    statusFilter = {
      mode = "all";
      hidden = [ ];
    };
  };

  piSubagentsConfig = {
    asyncByDefault = false;
    forceTopLevelAsync = false;
    parallel = {
      maxTasks = 4;
      concurrency = 2;
    };
    defaultSessionDir = "~/.pi/agent/sessions/subagent";
    maxSubagentDepth = 1;
    intercomBridge.mode = "off";
  };
in
lib.mkIf (noughtyLib.userHasTag "developer") {
  sops.secrets.ANTHROPIC_API_KEY = {
    sopsFile = aiSopsFile;
    mode = "0400";
  };

  sops.templates."pi-mcp-config" = {
    content = builtins.toJSON piMcpConfig;
    path = "${config.home.homeDirectory}/.pi/agent/mcp.json";
    mode = "0600";
  };

  home = {
    # Pi Lens creates its state directory at startup. Fence cannot allow
    # creation of this leaf directory without also allowing writes to $HOME, so
    # create it during Home Manager activation before fenced Pi sessions start.
    activation.piLensStateDirectory = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      mkdir -p "${config.home.homeDirectory}/.pi-lens"
      chmod 700 "${config.home.homeDirectory}/.pi-lens"
    '';

    packages = [
      piWrapperPackage
      piNpmPackage
    ]
    ++ lib.optional host.is.linux piFencedPackage;
    file = {
      ".pi/agent/settings.json".text = builtins.toJSON piSettings;
      ".pi/agent/keybindings.json".text = builtins.toJSON piKeybindings;
      ".pi/agent/pi-bar.json".text = builtins.toJSON piBarConfig;
      ".pi/agent/extensions/subagent/config.json".text = builtins.toJSON piSubagentsConfig;
      # Provider-router deploys its static extension files beside the generated
      # provider map consumed at runtime.
      ".pi/agent/extensions/provider-router/agents.json".text =
        builtins.toJSON piAssistant.providerRouterMap;
      ".pi/agent/extensions/provider-router/index.ts".source = ./extensions/provider-router/index.ts;
      ".pi/agent/extensions/provider-router/LICENSE".source = ./extensions/provider-router/LICENSE;
      ".pi/agent/extensions/provider-router/README.md".source = ./extensions/provider-router/README.md;
      ".pi/agent/themes/${piThemeName}.json".text = builtins.toJSON piCatppuccinTheme;
    }
    // piAssistant.homeFiles;

  };

  programs = lib.mkIf host.is.linux {
    bash.shellAliases.pi-fenced = lib.getExe piFencedPackage;
    fish.shellAliases.pi-fenced = lib.getExe piFencedPackage;
    zsh.shellAliases.pi-fenced = lib.getExe piFencedPackage;
  };
}
