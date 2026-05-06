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
  inherit (pkgs.stdenv.hostPlatform) system;
  aiSopsFile = ../../../../secrets/ai.yaml;
  piPackage = inputs.llm-agents.packages.${system}.pi;
  piMcpAdapterVersion = "2.5.4";
  piSubagentsVersion = "0.24.0";
  piMcpAdapterSource = "npm:pi-mcp-adapter@${piMcpAdapterVersion}";
  piSubagentsSource = "npm:pi-subagents@${piSubagentsVersion}";
  piAssistant = config.agentic.assistants.pi;
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
  # keeping the npm binary itself from Nixpkgs.
  piNpmPackage = pkgs.writeShellApplication {
    name = "pi-npm";
    runtimeInputs = [ pkgs.nodejs ];
    text = ''
      export NPM_CONFIG_PREFIX="${config.home.homeDirectory}/.pi/agent/npm-global"
      exec npm "$@"
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
    ];
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
    # The adapter reads the shared server definitions from
    # `~/.config/mcp/mcp.json`; this Home Manager-owned file only carries
    # Pi-specific adapter settings.
    mcpServers = { };
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

  home = {
    packages = [
      piWrapperPackage
      piNpmPackage
    ];
    file = {
      ".pi/agent/settings.json".text = builtins.toJSON piSettings;
      ".pi/agent/mcp.json".text = builtins.toJSON piMcpConfig;
      ".pi/agent/extensions/subagent/config.json".text = builtins.toJSON piSubagentsConfig;
      ".pi/agent/themes/${piThemeName}.json".text = builtins.toJSON piCatppuccinTheme;
    }
    // piAssistant.homeFiles;

    activation.piTrayaAgent = lib.hm.dag.entryAfter [ "writeBoundary" "sops-nix" ] ''
      ${piAssistant.trayaActivation}
    '';
  };
}
