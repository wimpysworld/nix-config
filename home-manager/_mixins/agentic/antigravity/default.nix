{
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
  cfg = config.agentic.antigravity;
  isDeveloper = noughtyLib.userHasTag "developer";
  fencedEnabled = !host.is.server;
  supportedSystems = [
    "x86_64-linux"
    "aarch64-linux"
    "aarch64-darwin"
  ];
  aiSopsFile = ../../../../secrets/ai.yaml;

  antigravityUpstreamPackage = inputs.llm-agents.packages.${system}.antigravity-cli;
  mcpServerDefs = import ../mcp/servers.nix {
    inherit config pkgs;
  };

  fencePackage = import ../fence/package.nix { inherit inputs pkgs; };
  fenceAgentShare = import ../fence/agent-share.nix { inherit config pkgs; };
  fenceGit = import ../fence/git.nix { inherit config pkgs; };
  fenceWaylandBridge = import ../fence/wayland-bridge.nix { inherit pkgs; };
  fenceMemoryCap = import ../fence/memory-cap.nix { inherit lib pkgs; };
  fenceChromium =
    if !(host.is.linux && fencedEnabled) then
      {
        runtimeInputs = [ ];
        setupShell = "";
      }
    else
      import ../fence/chromium.nix { inherit pkgs; };
  fenceLogging = import ../fence/logging.nix { inherit pkgs; };
  communicationRules = config.agentic.communicationRules;
  antigravityTripwireAdapter =
    if communicationRules.mkAntigravityHookAdapter == null then
      null
    else
      communicationRules.mkAntigravityHookAdapter { };
  antigravityCommunicationRulesHook = lib.optionalAttrs (antigravityTripwireAdapter != null) {
    PreInvocation = [
      (antigravityTripwireAdapter.mkHook "PreInvocation")
    ];
    PreToolUse = [
      {
        matcher = "run_command|shell_exec|call_mcp_tool|mcp_.*";
        hooks = [
          (antigravityTripwireAdapter.mkHook "PreToolUse")
        ];
      }
    ];
  };

  geminiKeyPath = if cfg.enable then config.sops.secrets.GEMINI_API_KEY.path else "";

  agyWrapperPackage =
    (pkgs.writeShellApplication {
      name = "agy";
      runtimeInputs = [
        pkgs.coreutils
      ];
      text = ''
        gemini_api_key_path=${lib.escapeShellArg geminiKeyPath}
        if [[ -n "$gemini_api_key_path" && -r "$gemini_api_key_path" ]]; then
          GEMINI_API_KEY="$(cat "$gemini_api_key_path")"
          export GEMINI_API_KEY
        fi

        export AGY_CLI_DISABLE_AUTO_UPDATE=true
        export PAGER=cat

        if [[ -r /etc/ssl/certs/ca-certificates.crt ]]; then
          export SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
        elif [[ -r /etc/ssl/cert.pem ]]; then
          export SSL_CERT_FILE=/etc/ssl/cert.pem
        else
          export SSL_CERT_FILE=${lib.escapeShellArg "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"}
        fi

        non_session=0
        has_skip_permissions=0
        agy_resume=(-c)

        case "''${1:-}" in
          acp | agent | agents | changelog | help | install | mcp | mic-serve | models | plugin | plugins | remote-control | update | -h | --help | -v | --version)
            non_session=1
            agy_resume=()
            ;;
        esac

        for arg in "$@"; do
          case "$arg" in
            --dangerously-skip-permissions)
              has_skip_permissions=1
              ;;
            -h | --help | -v | --version)
              non_session=1
              agy_resume=()
              ;;
            -p | --print | --print=* | --prompt | --prompt=* | -i | --prompt-interactive | --prompt-interactive=* | -c | --continue | --continue=* | --conversation | --conversation=* | --new-project)
              agy_resume=()
              ;;
          esac
        done

        agy_permission_args=()
        if [[ "''${FENCE_SANDBOX:-}" == "1" && "''${NOUGHTY_AGY_BYPASS:-}" == "1" && "$non_session" == "0" && "$has_skip_permissions" == "0" ]]; then
          agy_permission_args=(--dangerously-skip-permissions)
        fi

        exec ${lib.escapeShellArg (lib.getExe antigravityUpstreamPackage)} "''${agy_permission_args[@]}" "''${agy_resume[@]}" "$@"
      '';
    }).overrideAttrs
      {
        inherit (antigravityUpstreamPackage) meta;
        passthru.unwrapped = antigravityUpstreamPackage;
      };

  agyFencedPackage = pkgs.writeShellApplication {
    name = "agy-fenced";
    runtimeInputs = [
      fencePackage
    ]
    ++ fenceAgentShare.runtimeInputs
    ++ fenceWaylandBridge.runtimeInputs
    ++ fenceChromium.runtimeInputs
    ++ fenceLogging.runtimeInputs;
    text = ''
      if [[ "''${FENCE_SANDBOX:-0}" == 1 ]]; then
        export HERDR_AGENT=agy
        export NOUGHTY_AGY_BYPASS=1
        exec ${lib.getExe cfg.package} "$@"
      fi

      ${fenceAgentShare.captureShell}
      ${fenceMemoryCap.captureShell}
      ${fenceWaylandBridge.setupShell}
      ${fenceAgentShare.setupShell}
      ${fenceGit.setupShell}
      ${fenceChromium.setupShell}

      fence_log_agent="agy"
      ${fenceLogging.setupShell}

      # herdr identifies a pane's agent from the foreground process group
      # environ. Export the hint host-side so fence and the whole wrapper chain
      # inherit it; an inline post-`--` token would land only inside the sandbox
      # PID namespace, which herdr does not read.
      export HERDR_AGENT=agy

      # Pass the bypass through as an env token so the launcher sees the real
      # first user argument and resumes the most recent session by default.
      ${fenceMemoryCap.setupShell}
      cd -- "$fence_empty_cwd"
      "''${fence_launch[@]}" fence "''${fence_args[@]}" -- "''${fence_env[@]}" "''${fence_direnv[@]}" "NOUGHTY_AGY_BYPASS=1" ${lib.getExe cfg.package} "$@"
    '';
  };

  declarativeSettings = {
    model = "Gemini 4 Neon (High)";
    modelProvider = "gemini";
    colorScheme = "terminal";
    enableTerminalSandbox = false;
    notifications = false;
    showTips = false;
    showFeedbackSurvey = false;
    useTerminalCursor = true;
    permissions = {
      deny = [
        "read_url(*)"
        "execute_url(*)"
      ];
    };
  };

  trustedWorkspaces = [
    "${config.home.homeDirectory}/Chainguard"
    "${config.home.homeDirectory}/Chainguard/_worktrees"
    "${config.home.homeDirectory}/Chainguard/mono"
    "${config.home.homeDirectory}/Chainguard/stereo"
    "${config.home.homeDirectory}/Chainguard/cg-github"
    "${config.home.homeDirectory}/Chainguard/infra"
    "${config.home.homeDirectory}/Development"
    "${config.home.homeDirectory}/Development/_worktrees"
    "${config.home.homeDirectory}/Volatile"
    "${config.home.homeDirectory}/Zero"
    "${config.home.homeDirectory}/Zero/nix-config"
  ];

  antigravitySettingsActivationScript = ''
    antigravity_dir=${lib.escapeShellArg "${config.home.homeDirectory}/.gemini/antigravity-cli"}
    gemini_config_dir=${lib.escapeShellArg "${config.home.homeDirectory}/.gemini/config"}
    settings_file="$antigravity_dir/settings.json"
    jq=${lib.getExe pkgs.jq}

    ${pkgs.coreutils}/bin/mkdir -p "$antigravity_dir" "$gemini_config_dir"

    if [[ -L "$settings_file" ]]; then
      ${pkgs.coreutils}/bin/rm -f -- "$settings_file"
    fi

    existing_json='{}'
    if [[ -f "$settings_file" ]] && "$jq" -e 'type == "object"' "$settings_file" >/dev/null 2>&1; then
      existing_json="$(${pkgs.coreutils}/bin/cat "$settings_file")"
    fi

    tmp="$(${pkgs.coreutils}/bin/mktemp "$settings_file.XXXXXX")"
    if printf '%s\n' "$existing_json" | "$jq" \
      --argjson desired ${lib.escapeShellArg (builtins.toJSON declarativeSettings)} \
      --argjson roots ${lib.escapeShellArg (builtins.toJSON trustedWorkspaces)} \
      '
        . as $existing
        | $desired
        | if ($existing | has("gcp")) and ($existing.gcp != null) then .gcp = $existing.gcp else . end
        | .trustedWorkspaces = (
            (
              if ($existing.trustedWorkspaces | type) == "array" then
                [ $existing.trustedWorkspaces[] | select(type == "string") ]
              else
                []
              end
            ) + $roots
            | unique
          )
      ' > "$tmp"; then
      ${pkgs.coreutils}/bin/chmod 600 "$tmp"
      ${pkgs.coreutils}/bin/mv -f "$tmp" "$settings_file"
    else
      ${pkgs.coreutils}/bin/rm -f "$tmp"
    fi

    hooks_file="$gemini_config_dir/hooks.json"
    if [[ -L "$hooks_file" ]]; then
      ${pkgs.coreutils}/bin/rm -f -- "$hooks_file"
    fi

    ${
      if communicationRules.enable then
        ''
          existing_hooks='{}'
          if [[ -f "$hooks_file" ]] && "$jq" -e 'type == "object"' "$hooks_file" >/dev/null 2>&1; then
            existing_hooks="$(${pkgs.coreutils}/bin/cat "$hooks_file")"
          fi

          hooks_tmp="$(${pkgs.coreutils}/bin/mktemp "$hooks_file.XXXXXX")"
          if printf '%s\n' "$existing_hooks" | "$jq" \
            --argjson comm_rules ${lib.escapeShellArg (builtins.toJSON antigravityCommunicationRulesHook)} \
            '."communication-rules" = $comm_rules' > "$hooks_tmp"; then
            ${pkgs.coreutils}/bin/chmod 600 "$hooks_tmp"
            ${pkgs.coreutils}/bin/mv -f "$hooks_tmp" "$hooks_file"
          else
            ${pkgs.coreutils}/bin/rm -f "$hooks_tmp"
          fi
        ''
      else
        ''
          if [[ -f "$hooks_file" ]] && "$jq" -e 'type == "object" and has("communication-rules")' "$hooks_file" >/dev/null 2>&1; then
            hooks_tmp="$(${pkgs.coreutils}/bin/mktemp "$hooks_file.XXXXXX")"
            if "$jq" 'del(."communication-rules")' "$hooks_file" > "$hooks_tmp"; then
              ${pkgs.coreutils}/bin/chmod 600 "$hooks_tmp"
              ${pkgs.coreutils}/bin/mv -f "$hooks_tmp" "$hooks_file"
            else
              ${pkgs.coreutils}/bin/rm -f "$hooks_tmp"
            fi
          fi
        ''
    }
  '';

  shellAliases = {
    antigravity = lib.getExe cfg.package;
  }
  // lib.optionalAttrs fencedEnabled {
    agy-fenced = lib.getExe agyFencedPackage;
    antigravity-fenced = lib.getExe agyFencedPackage;
  };
in
{
  options.agentic.antigravity = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = isDeveloper && !host.is.server && lib.elem system supportedSystems;
      description = "Whether to enable Google Antigravity CLI integration.";
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = agyWrapperPackage;
      defaultText = lib.literalExpression "agyWrapperPackage";
      description = "Wrapped Google Antigravity CLI package.";
    };
  };

  config = lib.mkIf cfg.enable {
    sops.secrets.GEMINI_API_KEY = {
      sopsFile = aiSopsFile;
      mode = "0400";
    };

    sops.templates."antigravity-mcp-config.json" = {
      content = builtins.toJSON {
        mcpServers = mcpServerDefs.antigravityServers;
      };
      path = "${config.home.homeDirectory}/.gemini/config/mcp_config.json";
      mode = "0600";
    };

    home = {
      packages = [
        cfg.package
      ]
      ++ lib.optional communicationRules.enable antigravityTripwireAdapter.hookPackage
      ++ lib.optional fencedEnabled agyFencedPackage;

      activation.antigravitySettings = lib.hm.dag.entryAfter [
        "writeBoundary"
        "assistantOwnedFiles"
      ] antigravitySettingsActivationScript;
    };

    programs = {
      bash.shellAliases = shellAliases;
      fish.shellAliases = shellAliases;
      zsh.shellAliases = shellAliases;
    };
  };
}
