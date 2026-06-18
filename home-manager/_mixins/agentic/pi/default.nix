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
  fenceWaylandBridge = import ../fence/wayland-bridge.nix { inherit pkgs; };
  fenceLogging = import ../fence/logging.nix { inherit pkgs; };
  piMcpAdapterVersion = "2.6.1";
  # When bumping pi-subagents, verify the surface still matches the provider-router and prelude assumptions: the MCP tool name remains `subagent`; the parameter set still includes `agent`, `task`, `context`, `model`, and `thinking`; and `context` still accepts `"fresh"` and `"fork"` with `"fresh"` as the safer non-forking default. If any of these change, update `extensions/provider-router/index.ts` and the agent-launch prelude in `assistants/default.nix` before merging.
  piSubagentsVersion = "0.25.0";
  piLensVersion = "3.8.44";
  piFooterVersion = "0.3.0";
  piSubCoreVersion = "1.5.0";
  piLogoVersion = "1.0.0";
  rpivBtwVersion = "1.10.2";
  rpivTodoVersion = "1.10.2";
  piMcpAdapterSource = "npm:pi-mcp-adapter@${piMcpAdapterVersion}";
  piSubagentsSource = "npm:pi-subagents@${piSubagentsVersion}";
  piLensSource = "npm:pi-lens@${piLensVersion}";
  piFooterSource = "npm:pi-footer@${piFooterVersion}";
  piSubCoreSource = "npm:@marckrenn/pi-sub-core@${piSubCoreVersion}";
  piLogoSource = "npm:pi-logo@${piLogoVersion}";
  rpivBtwSource = "npm:@juicesharp/rpiv-btw@${rpivBtwVersion}";
  rpivTodoSource = "npm:@juicesharp/rpiv-todo@${rpivTodoVersion}";
  piAssistant = config.agentic.assistants.pi;
  communicationRules = config.agentic.communicationRules;
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
        inherit (catppuccinPalette) accent;
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
      pkgs.jq
    ];
    text = ''
      # Reinforce telemetry-off at runtime; the env var overrides the setting.
      export PI_TELEMETRY=0

      anthropic_api_key_path="${config.sops.secrets.ANTHROPIC_API_KEY.path}"
      if [ ! -r "$anthropic_api_key_path" ]; then
        echo "pi: Anthropic API key secret is missing or unreadable: $anthropic_api_key_path" >&2
        exit 1
      fi

      ANTHROPIC_API_KEY="$(cat "$anthropic_api_key_path")"
      export ANTHROPIC_API_KEY

      # pi-sub-core reads Anthropic quota data from the OAuth usage endpoint.
      # Reuse Claude Code's login token when available; API keys cannot query
      # the plan quota windows.
      claude_config_dir="''${CLAUDE_CONFIG_DIR:-${config.home.homeDirectory}/.claude}"
      claude_credentials_path="$claude_config_dir/.credentials.json"
      if [ -z "''${ANTHROPIC_OAUTH_TOKEN:-}" ] && [ -r "$claude_credentials_path" ]; then
        anthropic_oauth_token="$(
          jq --raw-output '
            (.claudeAiOauth.scopes // []) as $scopes
            | .claudeAiOauth.accessToken? as $token
            | if (($scopes | index("user:profile")) and ($token | type == "string") and ($token | length > 0))
              then $token
              else empty
              end
          ' "$claude_credentials_path" 2>/dev/null || true
        )"
        if [ -n "$anthropic_oauth_token" ]; then
          ANTHROPIC_OAUTH_TOKEN="$anthropic_oauth_token"
          export ANTHROPIC_OAUTH_TOKEN
        fi
      fi

      gemini_api_key_path="${config.sops.secrets.GEMINI_API_KEY.path}"
      if [ -r "$gemini_api_key_path" ]; then
        GEMINI_API_KEY="$(cat "$gemini_api_key_path")"
        export GEMINI_API_KEY
        GOOGLE_GENERATIVE_AI_API_KEY="$GEMINI_API_KEY"
        export GOOGLE_GENERATIVE_AI_API_KEY
      fi

      if [ "''${NOUGHTY_AGENT_LAUNCH_COMMAND:-pi}" = "pi-fenced" ]; then
        export NOUGHTY_AGENT_ISOLATION="Fenced"
      else
        export NOUGHTY_AGENT_ISOLATION="Unfenced"
      fi

      # Resume the most recent session by default. Skipped for management
      # subcommands (install, update, ...), headless `-p` runs, and when the
      # caller already selects a session, so those paths are untouched.
      pi_resume=(--continue)
      case "''${1:-}" in
        install | remove | uninstall | update | list | config | -h | --help | -v | --version)
          pi_resume=()
          ;;
        *)
          for arg in "$@"; do
            case "$arg" in
              -c | --continue | -r | --resume | --session | --session-id | --fork | --no-session | -p | --print)
                pi_resume=()
                break
                ;;
            esac
          done
          ;;
      esac

      # Pi enables built-in tools (read, bash, edit, write, grep, find, ls)
      # and discovered extension tools by default. Do not inject `--tools`
      # here: that flag is a strict allowlist that applies to built-in,
      # extension, and custom tools, so injecting only the built-in names
      # would hide every extension tool (subtask, lens, footer widgets,
      # MCP/adapter tools, etc.). Per-agent allowlists are expressed in the
      # agent's Pi-native frontmatter (`tools:` in `header.pi.yaml`).
      exec "${lib.getExe piPackage}" "''${pi_resume[@]}" "$@"
    '';
  };

  piFencedPackage = pkgs.writeShellApplication {
    name = "pi-fenced";
    runtimeInputs = [
      fencePackage
    ]
    ++ fenceWaylandBridge.runtimeInputs
    ++ fenceLogging.runtimeInputs;
    text = ''
      ${fenceWaylandBridge.setupShell}

      fence_log_agent="pi"
      ${fenceLogging.setupShell}

      export NOUGHTY_AGENT_LAUNCH_COMMAND="pi-fenced"
      fence "''${fence_args[@]}" -- "''${fence_env[@]}" ${lib.getExe' piWrapperPackage "pi"} "$@"
    '';
  };

  piSettings = {
    defaultProvider = "openai-codex";
    defaultModel = "gpt-5.5";
    defaultThinkingLevel = "medium";
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
      "openai-codex/gpt-5.5"
      "openai-codex/gpt-5.3-codex-spark"
      "openai-codex/gpt-5.4-mini"
    ];

    theme = piThemeName;
    quietStartup = true;
    collapseChangelog = true;
    enableInstallTelemetry = false;
    enableAnalytics = false;
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
      piFooterSource
      piSubCoreSource
      {
        source = piLogoSource;
        extensions = [ ];
      }
      rpivBtwSource
      rpivTodoSource
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
    # The adapter shallow-merges files by server name, so Pi-specific
    # `directTools` preferences must include full server entries rather than
    # partial overrides.
    mcpServers = mcpServerDefs.piServers;
  };

  piKeybindings = {
    # Unify quit across agents on Ctrl+D: works natively in Claude Code,
    # Codex, OpenCode, and Pi, so a single keybind covers every TUI.
    # `app.interrupt` stays on Escape, `app.clear` keeps Ctrl+C as the
    # editor-clear shortcut (non-exit semantics).
    "app.exit" = [ "ctrl+d" ];
    # Default is ["escape", "ctrl+c"]; drop Ctrl+C from list-cancel so the
    # key is reserved for editor-clear only.
    "tui.select.cancel" = [ "escape" ];
  };

  piFooterWidget = id: type: options: {
    inherit id type;
    enabled = true;
    inherit options;
  };

  piFooterColors = {
    # Match the Catppuccin roles used by ccstatusline:
    # model yellow, thinking mauve, cwd green, quota red, context peach,
    # isolation purple.
    model = "pi:warning";
    thinking = "pi:thinkingHigh";
    cwd = "pi:success";
    quota = "pi:error";
    context = "pi:bashMode";
    isolation = "pi:thinkingHigh";
  };

  # pi-footer owns the full footer layout while quota-status publishes compact
  # provider quota text through `ctx.ui.setStatus("noughty-quota:usage", ...)`.
  # Prefix separators live in widget icons so optional thinking/quota fields
  # disappear without leaving stray separators.
  piFooterConfig = {
    version = 1;
    enabled = true;
    preset = "pi-footer";
    separator = "none";
    separatorFg = "default";
    separatorBg = "default";
    iconMode = "text";
    minimalist = false;
    terminal = {
      widthMode = "full";
      colorLevel = "ansi256";
    };
    extensionStatusRow = {
      hiddenKeys = [
        "noughty-quota:usage"
        "noughty-isolation:status"
      ];
      knownKeys = [
        "noughty-quota:usage"
        "noughty-isolation:status"
      ];
    };
    lines = [
      [
        (piFooterWidget "model-provider" "model-provider" {
          raw = true;
          fg = piFooterColors.model;
        })
        (piFooterWidget "thinking" "thinking-level" {
          icon = " · ";
          fg = piFooterColors.thinking;
          hideWhenEmpty = true;
        })
        (piFooterWidget "cwd" "cwd" {
          icon = " · ";
          fg = piFooterColors.cwd;
          cwdDisplayStyle = "full-home";
          segments = 3;
        })
        (piFooterWidget "quota" "external-status" {
          icon = " · ";
          fg = piFooterColors.quota;
          externalStatusKey = "noughty-quota:usage";
          hideWhenEmpty = true;
          trimValue = 0;
          preserveTrimStyles = true;
        })
        (piFooterWidget "context-window" "context-window" {
          icon = " · ";
          fg = piFooterColors.context;
          tokenFormatStyle = "compact";
          contextConditionalColors = true;
          warningFg = "pi:warning";
          dangerFg = "pi:error";
        })
        (piFooterWidget "context-window-label" "custom-text" {
          raw = true;
          fg = piFooterColors.context;
          text = " window";
        })
        (piFooterWidget "context-used" "context" {
          icon = " · Context ";
          fg = piFooterColors.context;
          tokenFormatStyle = "compact";
          contextConditionalColors = true;
          warningFg = "pi:warning";
          dangerFg = "pi:error";
        })
        (piFooterWidget "context-used-label" "custom-text" {
          raw = true;
          fg = piFooterColors.context;
          text = " used";
        })
        (piFooterWidget "isolation" "external-status" {
          icon = " · ";
          fg = piFooterColors.isolation;
          externalStatusKey = "noughty-isolation:status";
          hideWhenEmpty = true;
          trimValue = 0;
          preserveTrimStyles = true;
        })
      ]
    ];
  };

  piIsolationStatusExtension = ''
    import type { ExtensionAPI, ExtensionContext } from "@mariozechner/pi-coding-agent";

    declare const process: {
      env: Record<string, string | undefined>;
    };

    const STATUS_KEY = "noughty-isolation:status";

    function isolationStatus(): string {
      return process.env.NOUGHTY_AGENT_ISOLATION === "Fenced" ? "Fenced" : "Unfenced";
    }

    export default function registerIsolationStatus(pi: ExtensionAPI): void {
      let ctx: ExtensionContext | undefined;

      function publish(): void {
        ctx?.ui.setStatus(STATUS_KEY, isolationStatus());
      }

      pi.on("session_start", (_event, context) => {
        ctx = context;
        publish();
      });

      pi.on("session_shutdown", () => {
        ctx?.ui.setStatus(STATUS_KEY, undefined);
        ctx = undefined;
      });
    }
  '';

  piCommunicationRulesCorrectionPrompt = pkgs.writeTextFile {
    name = "pi-communication-rules-correction-prompt.md";
    text = communicationRules.correctionPrompt;
  };

  # The Pi extension is an in-process TS plugin, so it shells out to the Python
  # core directly: mkPluginAdapter renders the shim and the shim spawns
  # `core pi <event>`. The shim reads its paths from config.json at runtime, so
  # the helper copies the shim verbatim (no token substitution).
  piCommunicationRulesPlugin =
    if communicationRules.mkPluginAdapter == null then
      null
    else
      communicationRules.mkPluginAdapter {
        agent = "pi";
        shim = ./extensions/communication-rules/index.ts;
        correctionPrompt = piCommunicationRulesCorrectionPrompt;
      };

  # The shim spawns this executable as `<adapterPath> pi <event>`; the scanner
  # wrapper bakes --policy-json and --rules, so the shim passes only the agent
  # and event. rulesPath and correctionPromptPath feed the Tier A live-object
  # writes (base-rules injection and the correction re-issue).
  piCommunicationRulesConfig = {
    adapterPath = communicationRules.executable;
    inherit (communicationRules) rulesPath;
    correctionPromptPath = piCommunicationRulesCorrectionPrompt;
  };

  piCommunicationRulesFiles = lib.optionalAttrs communicationRules.enable {
    ".pi/agent/extensions/communication-rules/config.json".text =
      builtins.toJSON piCommunicationRulesConfig;
    ".pi/agent/extensions/communication-rules/index.ts".text = piCommunicationRulesPlugin.pluginText;
  };

  # Herdr's Pi extension reports session identity and state to the multiplexer
  # over its control socket. Pi auto-discovers bare `.ts` files under
  # `extensions/`. The extension is a no-op unless herdr injects HERDR_ENV and
  # HERDR_SOCKET_PATH, so it is harmless outside a herdr pane. Kept verbatim
  # from the upstream herdr integration asset (version marker preserved) so
  # `herdr integration status` recognises it. Linux-only, matching where the
  # fenced Pi wrapper and the herdr socket policy hole exist.
  piHerdrFiles = lib.optionalAttrs host.is.linux {
    ".pi/agent/extensions/herdr-agent-state.ts".source = ./extensions/herdr-agent-state.ts;
  };

  # sub-core does not fetch quota data on session start; it first renders cached
  # state, then waits for its refresh timer. Keep that timer short enough that
  # the footer fills in promptly, and refresh again when work starts.
  piSubCoreConfig = {
    version = 3;
    behavior = {
      refreshInterval = 5;
      minRefreshInterval = 5;
      refreshOnTurnStart = true;
      refreshOnToolResult = false;
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

  sops.secrets.GEMINI_API_KEY = {
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
      ".pi/agent/extensions/pi-footer.json".text = builtins.toJSON piFooterConfig;
      ".pi/agent/pi-sub-core-settings.json".text = builtins.toJSON piSubCoreConfig;
      ".pi/agent/extensions/subagent/config.json".text = builtins.toJSON piSubagentsConfig;
      # Provider-router deploys its static extension files beside the generated
      # provider map consumed at runtime.
      ".pi/agent/extensions/provider-router/agents.json".text =
        builtins.toJSON piAssistant.providerRouterMap;
      ".pi/agent/extensions/provider-router/thinking.json".text =
        builtins.toJSON piAssistant.providerRouterThinkingMap;
      ".pi/agent/extensions/provider-router/index.ts".source = ./extensions/provider-router/index.ts;
      ".pi/agent/extensions/provider-router/LICENSE".source = ./extensions/provider-router/LICENSE;
      ".pi/agent/extensions/provider-router/README.md".source = ./extensions/provider-router/README.md;
      ".pi/agent/extensions/isolation-status/index.ts".text = piIsolationStatusExtension;
      ".pi/agent/extensions/pi-logo-filter/index.ts".source = ./extensions/pi-logo-filter/index.ts;
      ".pi/agent/extensions/quota-status/index.ts".source = ./extensions/quota-status/index.ts;
      ".pi/agent/themes/${piThemeName}.json".text = builtins.toJSON piCatppuccinTheme;
    }
    // piCommunicationRulesFiles
    // piHerdrFiles
    // piAssistant.homeFiles;

  };

  programs = lib.mkIf host.is.linux {
    bash.shellAliases.pi-fenced = lib.getExe piFencedPackage;
    fish.shellAliases.pi-fenced = lib.getExe piFencedPackage;
    zsh.shellAliases.pi-fenced = lib.getExe piFencedPackage;
  };
}
