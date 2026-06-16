{
  catppuccinPalette,
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  inherit (pkgs.stdenv.hostPlatform) system;
  # claude-code package selection (Linux llm-agents vs unstable) lives in
  # overlays/default.nix.
  claudePackage = pkgs.claude-code;
  fencePackage = import ../fence/package.nix { inherit inputs pkgs; };
  fenceWaylandBridge = import ../fence/wayland-bridge.nix { inherit pkgs; };
  fenceLogging = import ../fence/logging.nix { inherit pkgs; };
  ccColor = colorName: "hex:${builtins.substring 1 (-1) (catppuccinPalette.getColor colorName)}";

  # ACP adapter that lets Zed drive Claude Code over the Agent Client
  # Protocol. The binary is `claude-agent-acp`, sourced from the same
  # llm-agents flake input so the version is pinned alongside claude-code.
  claudeAgentAcpPackage = inputs.llm-agents.packages.${system}.claude-agent-acp;
  ccstatuslinePackage = inputs.llm-agents.packages.${system}.ccstatusline;
  usageRemainingPackage = pkgs.writeTextFile {
    name = "ccstatusline-usage-remaining";
    destination = "/bin/ccstatusline-usage-remaining";
    executable = true;
    text = ''
      #!${lib.getExe pkgs.nodejs}
      const fs = require("fs");
      const https = require("https");
      const os = require("os");
      const path = require("path");

      const bucketName = process.argv[2];
      if (!["five_hour", "seven_day"].includes(bucketName)) {
        process.exit(0);
      }

      const cacheMaxAgeMs = 180 * 1000;
      const home = process.env.HOME || os.homedir();
      const configDir = process.env.CLAUDE_CONFIG_DIR || path.join(home, ".claude");
      const cacheDir = process.env.XDG_CACHE_HOME
        ? path.join(process.env.XDG_CACHE_HOME, "ccstatusline")
        : path.join(home, ".cache", "ccstatusline");
      const cacheFile = path.join(cacheDir, "usage-api.json");

      function printRemaining(data) {
        const bucket = data && Object.prototype.hasOwnProperty.call(data, bucketName)
          ? data[bucketName]
          : undefined;
        const used = bucket === null ? 0 : bucket && bucket.utilization;
        if (typeof used !== "number" || !Number.isFinite(used)) {
          return false;
        }
        const remaining = Math.max(0, Math.min(100, 100 - used));
        process.stdout.write(Math.round(remaining).toString() + "%\n");
        return true;
      }

      function readJson(file) {
        try {
          return JSON.parse(fs.readFileSync(file, "utf8"));
        } catch {
          return null;
        }
      }

      function tryFreshCache() {
        try {
          const stat = fs.statSync(cacheFile);
          if (Date.now() - stat.mtimeMs > cacheMaxAgeMs) {
            return false;
          }
          return printRemaining(readJson(cacheFile));
        } catch {
          return false;
        }
      }

      function tryStaleCache() {
        return printRemaining(readJson(cacheFile));
      }

      function readToken() {
        const credentials = readJson(path.join(configDir, ".credentials.json"));
        return credentials && credentials.claudeAiOauth && credentials.claudeAiOauth.accessToken;
      }

      function fetchUsage(token) {
        const request = https.request({
          hostname: "api.anthropic.com",
          path: "/api/oauth/usage",
          method: "GET",
          timeout: 5000,
          headers: {
            Authorization: "Bearer " + token,
            "anthropic-beta": "oauth-2025-04-20",
          },
        }, (response) => {
          let body = "";
          response.setEncoding("utf8");
          response.on("data", (chunk) => {
            body += chunk;
          });
          response.on("end", () => {
            if (response.statusCode !== 200 || body.length === 0) {
              tryStaleCache();
              return;
            }
            const data = JSON.parse(body);
            fs.mkdirSync(cacheDir, { recursive: true });
            fs.writeFileSync(cacheFile, JSON.stringify(data));
            printRemaining(data);
          });
        });

        request.on("error", tryStaleCache);
        request.on("timeout", () => {
          request.destroy();
          tryStaleCache();
        });
        request.end();
      }

      if (!tryFreshCache()) {
        const token = readToken();
        if (typeof token === "string" && token.length > 0) {
          fetchUsage(token);
        } else {
          tryStaleCache();
        }
      }
    '';
  };
  contextUsedPackage = pkgs.writeTextFile {
    name = "ccstatusline-context-used";
    destination = "/bin/ccstatusline-context-used";
    executable = true;
    text = ''
      #!${lib.getExe pkgs.nodejs}
      const fs = require("fs");

      function toNumber(value) {
        if (typeof value === "number" && Number.isFinite(value)) {
          return value;
        }
        if (typeof value === "string" && value.trim().length > 0) {
          const parsed = Number(value);
          return Number.isFinite(parsed) ? parsed : null;
        }
        return null;
      }

      function usageTokens(usage) {
        const direct = toNumber(usage);
        if (direct !== null) {
          return direct;
        }
        if (!usage || typeof usage !== "object") {
          return null;
        }
        return [
          usage.input_tokens,
          usage.output_tokens,
          usage.cache_creation_input_tokens,
          usage.cache_read_input_tokens,
        ].reduce((total, value) => total + (toNumber(value) || 0), 0);
      }

      function contextUsedPercentage(data) {
        const contextWindow = data && data.context_window;
        if (!contextWindow || typeof contextWindow !== "object") {
          return 0;
        }

        const explicitUsed = toNumber(contextWindow.used_percentage);
        if (explicitUsed !== null) {
          return explicitUsed;
        }

        const windowSize = toNumber(contextWindow.context_window_size);
        if (!windowSize || windowSize <= 0) {
          return 0;
        }

        const currentUsage = usageTokens(contextWindow.current_usage);
        if (currentUsage !== null) {
          return currentUsage / windowSize * 100;
        }

        const totalInput = toNumber(contextWindow.total_input_tokens) || 0;
        const totalOutput = toNumber(contextWindow.total_output_tokens) || 0;
        return (totalInput + totalOutput) / windowSize * 100;
      }

      try {
        const data = JSON.parse(fs.readFileSync(0, "utf8"));
        const used = Math.max(0, Math.min(100, contextUsedPercentage(data)));
        process.stdout.write(Math.round(used).toString() + "%\n");
      } catch {
        process.stdout.write("0%\n");
      }
    '';
  };
  sharedMcpConfigPath = "${config.xdg.configHome}/mcp/mcp.json";
  renderedMcpConfigPath = "${config.xdg.configHome}/sops-nix/secrets/rendered/mcp-config.json";
  claudeEnvironment = {
    CLAUDE_CODE_HIDE_CWD = "1";
    ENABLE_CLAUDEAI_MCP_SERVERS = "false";
    # Enable the experimental agent-teams feature, which exposes the
    # SendMessage tool for resuming subagents and messaging teammates.
    CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1";
    # Disable first-party telemetry, analytics, and error reporting. The
    # umbrella flag covers most non-essential traffic; the individual flags
    # are set too so opt-out stays robust across versions.
    CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = "1";
    DISABLE_TELEMETRY = "1";
    DISABLE_ERROR_REPORTING = "1";
    DISABLE_FEEDBACK_COMMAND = "1";
    CLAUDE_CODE_DISABLE_FEEDBACK_SURVEY = "1";
    # Hide the account/email banner for recordings without suppressing the
    # workspace-trust dialog. `IS_DEMO=1` also silently skipped the trust
    # prompt without granting trust, leaving newly-opened projects stuck at
    # `hasTrustDialogAccepted: false`, which disables the statusline, the
    # `fileSuggestion` finder, and `@` mentions. See upstream #37780.
    CLAUDE_CODE_HIDE_ACCOUNT_INFO = "1";
  };
  claudeEnvironmentExports = lib.concatLines (
    lib.mapAttrsToList (name: value: "export ${name}=${lib.escapeShellArg value}") claudeEnvironment
  );
  claudeEnvironmentArgs = lib.concatStringsSep " " (
    lib.mapAttrsToList (name: value: lib.escapeShellArg "${name}=${value}") claudeEnvironment
  );
  # Replacement for Claude Code's built-in `@` file picker. Pipes `fd` into
  # `fzf --filter` so queries get real fuzzy scoring and untracked files,
  # gitignored files, and symlinked trees all participate. Wired into
  # `settings.fileSuggestion` below.
  fileSuggestionCommand = pkgs.callPackage ./file-suggestion { };
  communicationRules = config.agentic.communicationRules or { enable = false; };
  claudeCodeTripwireCorrectionPrompt = pkgs.writeTextFile {
    name = "claude-code-tripwire-correction-prompt.md";
    text = communicationRules.correctionPrompt or "";
  };
  # Build the command-style hook through the shared helper. The helper exports
  # the environment the core reads (TRIPWIRE_SCANNER, TRIPWIRE_POLICY_JSON,
  # TRIPWIRE_CORRECTION_PROMPT) and runs `scanner.py claude-code <event>`, so
  # detection, the strike machine, and Tier A re-issue all live in the core.
  claudeCodeTripwireAdapter = communicationRules.mkCommandHookAdapter {
    agent = "claude-code";
    correctionPrompt = claudeCodeTripwireCorrectionPrompt;
  };
  claudeCodeTripwireHook = event: claudeCodeTripwireAdapter.mkHook event;
  claudeCodeTripwireHooks = {
    SessionStart = lib.mkAfter [
      {
        hooks = [ (claudeCodeTripwireHook "SessionStart") ];
      }
    ];
    # UserPromptSubmit consumes a pending Tier A re-issue flag set by a Stop or
    # SubagentStop breach. It injects the rules back to the model on the next
    # turn without re-rolling the reply the user already saw. Without this, the
    # flag is set but never read, so the silent re-issue never fires.
    UserPromptSubmit = lib.mkAfter [
      {
        hooks = [ (claudeCodeTripwireHook "UserPromptSubmit") ];
      }
    ];
    PreToolUse = lib.mkAfter [
      {
        matcher = "Edit|MultiEdit|Write|Bash|mcp__.*__(comment|create|edit|post|publish|reply|review|send|submit|update|write).*";
        hooks = [ (claudeCodeTripwireHook "PreToolUse") ];
      }
    ];
    Stop = lib.mkAfter [
      {
        hooks = [ (claudeCodeTripwireHook "Stop") ];
      }
    ];
    # SubagentStop scans a subagent's final output and mirrors the Stop path:
    # same block/correction, 3-strike yield cap, and systemMessage notice. No
    # matcher, so it applies to every subagent type.
    SubagentStop = lib.mkAfter [
      {
        hooks = [ (claudeCodeTripwireHook "SubagentStop") ];
      }
    ];
  };

  inherit (config.claude-code) lspServers;

  # Wrap Claude Code with LSP plugin support when language modules contribute
  # LSP server configurations. Sets ENABLE_LSP_TOOL=1 and passes --plugin-dir
  # pointing to the generated .lsp.json location. When no LSP servers are
  # configured, the unwrapped package is used unchanged.
  claudePackageWithLsp =
    if lspServers != { } then
      pkgs.symlinkJoin {
        name = "claude-code-with-lsp";
        paths = [ claudePackage ];
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          wrapProgram $out/bin/claude \
            --set ENABLE_LSP_TOOL 1 \
            --add-flags "--plugin-dir ${config.home.homeDirectory}/.claude/plugins/nix-lsp"
        '';
      }
    else
      claudePackage;

  # Launch defaults shared by the plain and fenced `claude` wrappers. Builds a
  # `claude_defaults` bash array holding the Opus model, high effort, and a
  # resume of the most recent session. The defaults are dropped for subcommands
  # (e.g. `claude mcp list`) and headless `-p` runs, where `--continue` would
  # break the command or resume an unrelated conversation. `--continue` is also
  # dropped when the caller already names a session to resume, so the flags
  # never clash. The array sits before the user's own arguments, so a passed
  # `--model`/`--effort` wins on last-flag precedence.
  claudeLaunchDefaults = ''
    claude_defaults=(--model opus --effort high --continue)
    case "''${1:-}" in
      -p | --print | agents | auth | config | doctor | install | mcp | migrate-installer | plugin | setup-token | update)
        claude_defaults=()
        ;;
      *)
        for arg in "$@"; do
          case "$arg" in
            -c | --continue | -r | --resume)
              claude_defaults=(--model opus --effort high)
              break
              ;;
          esac
        done
        ;;
    esac
  '';

  # Home Manager's native `mcpServers` wrapper emits `--mcp-config <path>`
  # before user arguments. Claude Code treats that option as variadic
  # (`<configs...>`), so commands like `claude mcp list` are swallowed as
  # extra config paths. Own the wrapper here with `--mcp-config=<path>`,
  # which keeps argument parsing intact and reads the sops-rendered file.
  claudePackageWithMcp =
    pkgs.runCommand "claude-code-with-mcp"
      {
        inherit (claudePackageWithLsp) meta;
      }
      ''
        mkdir -p "$out/bin"
        cat > "$out/bin/claude" <<'EOF'
        #!${lib.getExe pkgs.bash}
        mcp_configs=(
          ${lib.escapeShellArg sharedMcpConfigPath}
          ${lib.escapeShellArg renderedMcpConfigPath}
        )
        claude=${lib.escapeShellArg (lib.getExe' claudePackageWithLsp "claude")}

        ${claudeEnvironmentExports}

        ${claudeLaunchDefaults}

        for mcp_config in "''${mcp_configs[@]}"; do
          if [[ -f "$mcp_config" ]]; then
            exec "$claude" "--mcp-config=$mcp_config" "''${claude_defaults[@]}" "$@"
          fi
        done

        exec "$claude" "''${claude_defaults[@]}" "$@"
        EOF
        chmod +x "$out/bin/claude"
      '';

  claudeFencedPackage = pkgs.writeShellApplication {
    name = "claude-fenced";
    runtimeInputs = [
      fencePackage
      pkgs.ncurses
    ]
    ++ fenceWaylandBridge.runtimeInputs
    ++ fenceLogging.runtimeInputs;
    text = ''
      ${fenceWaylandBridge.setupShell}

      fence_log_agent="claude"
      ${fenceLogging.setupShell}

      mcp_configs=(
        ${lib.escapeShellArg sharedMcpConfigPath}
        ${lib.escapeShellArg renderedMcpConfigPath}
      )
      mcp_config=""
      tmp_mcp_config=""

      for candidate in "''${mcp_configs[@]}"; do
        if [[ -f "$candidate" ]]; then
          mcp_config="$candidate"
          break
        fi
      done

      if [[ -n "$mcp_config" ]]; then
        tmp_dir="''${XDG_RUNTIME_DIR:-/tmp}"
        tmp_mcp_config="$(mktemp "$tmp_dir/claude-mcp-config.XXXXXX.json")"
        chmod 600 "$tmp_mcp_config"
        cp "$mcp_config" "$tmp_mcp_config"
        fence_args+=(--expose-host-path "$tmp_mcp_config")
        trap 'rm -f "$tmp_mcp_config"; cleanup_fence_wayland_bridge' EXIT
      fi

      ${claudeLaunchDefaults}

      width="$(tput cols 2>/dev/null || true)"
      case "$width" in
        "" | *[!0-9]*)
          if [[ -n "$tmp_mcp_config" ]]; then
            fence "''${fence_args[@]}" -- "''${fence_env[@]}" "NOUGHTY_AGENT_ISOLATION=Fenced" ${claudeEnvironmentArgs} ${lib.getExe' claudePackageWithLsp "claude"} "--mcp-config=$tmp_mcp_config" --dangerously-skip-permissions "''${claude_defaults[@]}" "$@"
          else
            fence "''${fence_args[@]}" -- "''${fence_env[@]}" "NOUGHTY_AGENT_ISOLATION=Fenced" ${claudeEnvironmentArgs} ${lib.getExe' claudePackageWithLsp "claude"} --dangerously-skip-permissions "''${claude_defaults[@]}" "$@"
          fi
          ;;
        *)
          if [[ -n "$tmp_mcp_config" ]]; then
            fence "''${fence_args[@]}" -- "''${fence_env[@]}" "CCSTATUSLINE_WIDTH=$width" "NOUGHTY_AGENT_ISOLATION=Fenced" ${claudeEnvironmentArgs} ${lib.getExe' claudePackageWithLsp "claude"} "--mcp-config=$tmp_mcp_config" --dangerously-skip-permissions "''${claude_defaults[@]}" "$@"
          else
            fence "''${fence_args[@]}" -- "''${fence_env[@]}" "CCSTATUSLINE_WIDTH=$width" "NOUGHTY_AGENT_ISOLATION=Fenced" ${claudeEnvironmentArgs} ${lib.getExe' claudePackageWithLsp "claude"} --dangerously-skip-permissions "''${claude_defaults[@]}" "$@"
          fi
          ;;
      esac
    '';
  };
in
{
  options.claude-code.lspServers = lib.mkOption {
    type = lib.types.attrsOf (lib.types.attrsOf lib.types.anything);
    default = { };
    description = "LSP server configurations contributed by language modules, merged into .lsp.json";
  };

  config = {
    home = {
      file = lib.mkIf (lspServers != { }) {
        ".claude/plugins/nix-lsp/.lsp.json".text = builtins.toJSON lspServers;
      };
      packages = [
        ccstatuslinePackage
        claudeAgentAcpPackage
        usageRemainingPackage
        contextUsedPackage
      ]
      ++ lib.optional host.is.linux claudeFencedPackage;
      # Skip Claude Code's bundled ripgrep in favour of the system binary on
      # PATH. The bundled `rg` crashes on 16 KB-page kernels (Apple Silicon,
      # some Linux configs), silently emptying the file picker. Using the Nix
      # ripgrep is harmless on every other host and avoids the failure mode
      # entirely. See CLAUDE-FUZZY-FINDER-IS-DOGSHIT.md and upstream #11307.
      sessionVariables = {
        USE_BUILTIN_RIPGREP = "0";
      };
    };

    # Disable Claude Code's LSP plugin install prompt. All required LSP servers
    # are provided by Nix, so the recommendation to install them is noise. The
    # kill switch is the undocumented `lspRecommendationDisabled` key (verified
    # from the decompiled source); it must live in the mutable runtime file
    # `~/.claude.json`, not in settings.json (which would reject it on schema
    # validation). Claude Code rewrites `~/.claude.json` at runtime (OAuth,
    # caches, per-project state), so the key is merged in idempotently rather
    # than declared as a read-only symlink.
    home.activation.claudeCodeDisableLspPrompt = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      claude_config=${lib.escapeShellArg "${config.home.homeDirectory}/.claude.json"}
      jq=${lib.getExe pkgs.jq}

      # Start from an empty object when the file does not exist yet.
      if [[ ! -f "$claude_config" ]]; then
        ${pkgs.coreutils}/bin/install -m 600 /dev/null "$claude_config"
        echo '{}' > "$claude_config"
      fi

      # Skip silently if the file is unreadable as JSON (corrupt or empty).
      if ! "$jq" -e . "$claude_config" >/dev/null 2>&1; then
        exit 0
      fi

      tmp="$(${pkgs.coreutils}/bin/mktemp "$claude_config.XXXXXX")"
      if "$jq" '.lspRecommendationDisabled = true' "$claude_config" > "$tmp"; then
        ${pkgs.coreutils}/bin/mv "$tmp" "$claude_config"
      else
        ${pkgs.coreutils}/bin/rm -f "$tmp"
      fi
    '';

    # Declarative configuration for ccstatusline.
    # Settings are written to ~/.config/ccstatusline/settings.json, which is the
    # default path the tool reads on startup. The status line command is injected
    # into Claude Code's settings.json by the claude-code Home Manager module.
    xdg.configFile."ccstatusline/settings.json".text = builtins.toJSON {
      version = 3;
      # Plain values required: builtins.toJSON serialises lib.mkDefault wrappers
      # verbatim as attribute sets, which fails ccstatusline's Zod schema validation.
      flexMode = "full";
      compactThreshold = 60;
      colorLevel = 2;
      defaultPadding = "";
      defaultSeparator = " ${builtins.fromJSON "\"\\u00B7\""} ";
      inheritSeparatorColors = false;
      globalBold = false;
      powerline = {
        enabled = false;
        separators = [ "\uE0B0" ];
        separatorInvertBackground = [ false ];
        startCaps = [ ];
        endCaps = [ ];
        autoAlign = false;
      };
      lines = [
        [
          # Single-line layout mirroring the Codex status line ordering as
          # closely as ccstatusline permits. Claude has no native equivalents
          # for Codex run-state, fast-mode, or permissions segments.
          {
            id = "1";
            type = "model";
            color = ccColor "yellow";
            rawValue = true;
          }
          {
            id = "2";
            type = "thinking-effort";
            color = ccColor "mauve";
            rawValue = true;
          }
          {
            id = "3";
            type = "current-working-dir";
            color = ccColor "green";
            rawValue = true;
            metadata = {
              abbreviateHome = "true";
            };
          }
          {
            id = "4";
            type = "custom-text";
            color = ccColor "red";
            customText = "5h ";
            merge = "no-padding";
          }
          {
            id = "5";
            type = "custom-command";
            color = ccColor "red";
            commandPath = "${lib.getExe usageRemainingPackage} five_hour";
            timeout = 1000;
          }
          {
            id = "6";
            type = "custom-text";
            color = ccColor "red";
            customText = "weekly ";
            merge = "no-padding";
          }
          {
            id = "7";
            type = "custom-command";
            color = ccColor "red";
            commandPath = "${lib.getExe usageRemainingPackage} seven_day";
            timeout = 1000;
          }
          {
            id = "8";
            type = "context-window";
            color = ccColor "peach";
            rawValue = true;
            merge = "no-padding";
          }
          {
            id = "9";
            type = "custom-text";
            color = ccColor "peach";
            customText = " window";
          }
          {
            id = "10";
            type = "custom-text";
            color = ccColor "peach";
            customText = "Context ";
            merge = "no-padding";
          }
          {
            id = "11";
            type = "custom-command";
            color = ccColor "peach";
            commandPath = lib.getExe contextUsedPackage;
            timeout = 1000;
            merge = "no-padding";
          }
          {
            id = "12";
            type = "custom-text";
            color = ccColor "peach";
            customText = " used";
          }
          {
            id = "13";
            type = "custom-command";
            color = ccColor "mauve";
            commandPath = "${lib.getExe pkgs.bash} -c 'printf \"%s\\n\" \"\${NOUGHTY_AGENT_ISOLATION:-Unfenced}\"'";
            timeout = 1000;
          }
        ]
      ];
    };

    programs = {
      bash.shellAliases = lib.mkIf host.is.linux {
        claude-fenced = lib.getExe claudeFencedPackage;
      };
      claude-code = {
        enable = true;
        package = claudePackageWithMcp;
        settings = lib.mkMerge [
          {
            # MCP servers are selected by the shared MCP mixin. Project
            # MCP servers remain opt-in instead of being silently trusted.
            enableAllProjectMcpServers = false;

            # Never surface the in-product feedback survey.
            feedbackSurveyRate = 0;

            # Disable the rotating tips shown on the spinner line.
            spinnerTipsEnabled = false;

            # Keep Claude Code out of Git commit and pull request attribution.
            attribution = {
              commit = "";
              pr = "";
            };

            # Wire ccstatusline into Claude Code's status bar. The module writes
            # this value to ~/.claude/settings.json under the "statusLine" key,
            # which Claude Code reads on startup to invoke the formatter.
            statusLine = {
              type = "command";
              command = lib.getExe ccstatuslinePackage;
              padding = 0;
            };

            # Replace the built-in `@` file picker with `fd | fzf --filter`.
            # The built-in matcher is a bespoke subsequence scorer capped at 15
            # results and gated on `git ls-files`, so untracked or word-fragment
            # queries fail. Claude Code invokes this command per keystroke with
            # JSON `{"query": "..."}` on stdin. See ./file-suggestion for the
            # script body and CLAUDE-FUZZY-FINDER-IS-DOGSHIT.md for context.
            fileSuggestion = {
              type = "command";
              command = lib.getExe fileSuggestionCommand;
            };
          }
          (lib.mkIf communicationRules.enable {
            hooks = claudeCodeTripwireHooks;
          })
          (lib.optionalAttrs host.is.linux {
            skipDangerousModePermissionPrompt = true;
          })
        ];
      };
      fish.shellAliases = lib.mkIf host.is.linux {
        claude-fenced = lib.getExe claudeFencedPackage;
      };
      zsh.shellAliases = lib.mkIf host.is.linux {
        claude-fenced = lib.getExe claudeFencedPackage;
      };
    };
  };
}
