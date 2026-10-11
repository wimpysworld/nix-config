{
  catppuccinPalette,
  config,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  # Herdr reads its configuration from `~/.config/herdr/config.toml`.
  tomlFormat = pkgs.formats.toml { };
  # Herdr uses a single worktree root for every repository and appends
  # `<repo-name>/<branch>` to it. Work hosts use `~/Chainguard`, and other hosts
  # use `~/Development`. The absolute path avoids reliance on tilde expansion.
  worktreeRoot =
    if noughtyLib.hostHasTag "cg" then
      "${config.home.homeDirectory}/Chainguard/_worktrees"
    else
      "${config.home.homeDirectory}/Development/_worktrees";
  # Work hosts get the Chainguard pane set and Claude and Codex autostart;
  # home hosts get the OpenCode pane set for personal development.
  herdrLayout = if noughtyLib.hostHasTag "cg" then pkgs.herdr-work-layout else pkgs.herdr-home-layout;
  settings = {
    # Herdr shows the onboarding screen until it writes `onboarding = false`
    # back to the configuration file. Nix renders that file as a read-only
    # symlink into the store, so herdr can never record completion itself. The
    # flag is pre-set here to skip onboarding on every start.
    onboarding = false;
    theme = {
      name = "catppuccin";
      custom = {
        accent = catppuccinPalette.getColor "blue";
        sidebar_bg = catppuccinPalette.getColor "crust";
        active_row_bg = catppuccinPalette.getColor "surface0";
        selection_bg = catppuccinPalette.getColor "surface1";
        surface_dim = catppuccinPalette.getColor "surface2";
      };
    };
    # After a server restart, herdr resumes supported agent panes into their
    # previous conversation sessions. The restarted agents cost more attention
    # than they save, so panes come back as plain shells instead.
    session.resume_agents_on_restore = false;
    ui.agent_panel_sort = "spaces";
    ui.sidebar.agents = {
      row_gap = 0;
      rows = [
        [
          "state_icon"
          {
            token = "$title";
            fg = catppuccinPalette.getColor "text";
            bold = true;
            dim = false;
          }
        ]
        [
          {
            token = "$provider";
            dim = false;
          }
          {
            token = "$limit";
            dim = false;
          }
        ]
        [
          {
            token = "$context";
            dim = false;
          }
        ]
      ];
    };
    ui.sidebar.spaces.rows = [
      [
        "state_icon"
        "workspace"
      ]
      [
        "branch"
        "git_status"
      ]
    ];
    ui.status_indicators = "symbols";
    ui.show_agent_labels_on_pane_borders = true;
    ui.sound.enabled = false;
    ui.toast.delivery = "system";
    terminal.kitty_graphics = true;
    worktrees.directory = worktreeRoot;
  };
  herdrWorktree = pkgs.writeShellApplication {
    name = "herdr-worktree";
    runtimeInputs = with pkgs; [
      coreutils
      git
      herdr
    ];
    text = ''
      die() {
        printf 'herdr-worktree: %s\n' "$1" >&2
        exit 2
      }

      contains_path() {
        local child="$1"
        local parent="$2"

        [[ "$child" == "$parent" || "$child" == "$parent"/* ]]
      }

      expand_user_path() {
        local path="$1"

        case "$path" in
          \~)
            printf '%s\n' "$home_dir"
            ;;
          \~/*)
            printf '%s/%s\n' "$home_dir" "''${path#"~/"}"
            ;;
          \~*)
            die "only ~/ tilde paths are supported"
            ;;
          /*)
            printf '%s\n' "$path"
            ;;
          *)
            printf '%s/%s\n' "$cwd" "$path"
            ;;
        esac
      }

      branch_to_path_slug() {
        local branch="$1"
        local slug=""
        local last_was_dash=false
        local char
        local index

        for ((index = 0; index < ''${#branch}; index++)); do
          char="''${branch:index:1}"
          case "$char" in
            [a-z])
              slug+="''${char}"
              last_was_dash=false
              ;;
            [A-Z])
              slug+="''${char,,}"
              last_was_dash=false
              ;;
            [0-9])
              slug+="''${char}"
              last_was_dash=false
              ;;
            *)
              if [[ "$last_was_dash" == false ]]; then
                slug+="-"
                last_was_dash=true
              fi
              ;;
          esac
        done

        while [[ "$slug" == -* ]]; do
          slug="''${slug#-}"
        done
        while [[ "$slug" == *- ]]; do
          slug="''${slug%-}"
        done

        if [[ -z "$slug" ]]; then
          printf 'worktree\n'
        else
          printf '%s\n' "$slug"
        fi
      }

      export LC_ALL=C

      [[ -n "''${HOME:-}" ]] || die "HOME is not set"
      [[ "$HOME" == /* ]] || die "HOME must be absolute"
      home_dir="$(realpath -- "$HOME")" || die "failed to resolve HOME"
      cwd="$(pwd -P)" || die "failed to resolve current directory"

      selected_root=""
      for root in "$home_dir/Chainguard" "$home_dir/Zero/nix-config" "$home_dir/Development"; do
        [[ -d "$root" ]] || continue
        root="$(realpath -- "$root")" || continue
        if contains_path "$cwd" "$root"; then
          selected_root="$root"
          break
        fi
      done

      [[ -n "$selected_root" ]] || die "current directory is outside the allowed workspace roots"

      # The terminal interface uses one fixed worktree root for every
      # repository, so the wrapper uses the same root instead of deriving one
      # from the selected workspace root.
      worktree_root="$(realpath -m -- ${lib.escapeShellArg worktreeRoot})" \
        || die "failed to resolve the worktree root"
      [[ "$worktree_root" == /* ]] || die "worktree root must be absolute"

      repo_root_raw="$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null)" \
        || die "current directory is not inside a Git repository"
      case "$repo_root_raw" in
        /*) ;;
        *) repo_root_raw="$cwd/$repo_root_raw" ;;
      esac
      repo_root="$(realpath -- "$repo_root_raw")" || die "failed to resolve Git repository root"
      contains_path "$repo_root" "$selected_root" \
        || die "Git repository root is outside the selected workspace root"

      repo_name="$(basename -- "$repo_root")"
      [[ -n "$repo_name" ]] || die "failed to determine repository name"

      repo_worktree_root="$(realpath -m -- "$worktree_root/$repo_name")"
      [[ "$repo_worktree_root" != "$worktree_root" ]] \
        || die "repository worktree root must be below the worktree root"
      contains_path "$repo_worktree_root" "$worktree_root" \
        || die "repository worktree root resolves outside the allowed worktree root"

      args=()
      branch=""
      checkout_path_arg=""
      has_branch=false
      has_path=false

      while (($# > 0)); do
        case "$1" in
          --branch)
            (($# >= 2)) || die "missing value for --branch"
            "$has_branch" && die "duplicate --branch"
            branch="$2"
            has_branch=true
            args+=("$1" "$2")
            shift 2
            ;;
          --path)
            (($# >= 2)) || die "missing value for --path"
            "$has_path" && die "duplicate --path"
            checkout_path_arg="$2"
            has_path=true
            shift 2
            ;;
          --cwd | --workspace)
            die "do not pass $1; herdr-worktree selects the source repository from the current directory"
            ;;
          --branch=* | --path=* | --cwd=* | --workspace=*)
            die "$1 uses unsupported = syntax"
            ;;
          *)
            args+=("$1")
            shift
            ;;
        esac
      done

      if "$has_path"; then
        checkout_path="$(expand_user_path "$checkout_path_arg")"
      else
        if ! "$has_branch"; then
          branch="worktree/$(date +%Y%m%d-%H%M%S-%N)-$$"
          args+=("--branch" "$branch")
        fi
        branch_slug="$(branch_to_path_slug "$branch")"
        checkout_path="$repo_worktree_root/$branch_slug"
      fi

      checkout_path="$(realpath -m -- "$checkout_path")"
      [[ "$checkout_path" != "$worktree_root" ]] || die "checkout path must be below the worktree root"
      contains_path "$checkout_path" "$worktree_root" \
        || die "checkout path resolves outside the allowed worktree root"

      exec herdr worktree create --cwd "$repo_root" --path "$checkout_path" "''${args[@]}"
    '';
  };

  # The relay key lives outside `~/.config/herdr`, and Fence denies reads of
  # this directory. The relay keeps its device
  # store, push keys, and pid file beside `relay.env`.
  herdrMobileRelay = pkgs.herdr-mobile-relay;
  herdrMobileRelayRoot = herdrMobileRelay.passthru.pluginRoot;
  herdrMobileRelayDir = "${config.xdg.configHome}/herdr-mobile-relay";
  herdrMobileRelayEnv = "${herdrMobileRelayDir}/relay.env";
  herdrMobileApp = import ../../../lib/herdr-mobile-app.nix {
    inherit (config.noughty.network) tailNet;
  };
  # Agent CLIs live in the user profile, which a user service does not put on
  # PATH by default.
  herdrMobileRelayPath = lib.concatStringsSep ":" [
    "${config.home.homeDirectory}/.nix-profile/bin"
    "${config.home.homeDirectory}/.local/state/nix/profile/bin"
    "/etc/profiles/per-user/${config.home.username}/bin"
    "/run/current-system/sw/bin"
    "/run/wrappers/bin"
    "/nix/var/nix/profiles/default/bin"
    "/usr/bin"
    "/bin"
  ];
  herdrMobileRelayService = pkgs.writeShellApplication {
    name = "herdr-mobile-relay-service";
    runtimeInputs = with pkgs; [
      coreutils
      gnugrep
      openssl
    ];
    text = ''
      export HERDR_RELAY_ENV=${lib.escapeShellArg herdrMobileRelayEnv}
      install -d -m 700 ${lib.escapeShellArg herdrMobileRelayDir}

      # shellcheck source=/dev/null
      . ${herdrMobileRelayRoot}/relay/common.sh

      # Upstream creates the relay key and instance ID only when they are
      # missing. The gateway list must be in the file, because setup links
      # read it from there.
      ensure_relay_env "$HERDR_RELAY_ENV"
      set_env_value_atomic "$HERDR_RELAY_ENV" HERDR_GATEWAY_URL \
        "wss://gw1.herdr-mobile.dev,wss://gw2.herdr-mobile.dev"
      set_env_value_atomic "$HERDR_RELAY_ENV" HERDR_REACHABILITY_PORT_MAPPING 0
      # A phone app URL in the file would override the one that
      # herdr-mobile-relay-link passes for each run. App Deployment stays off.
      remove_env_value_atomic "$HERDR_RELAY_ENV" HERDR_PHONE_APP_URL
      remove_env_value_atomic "$HERDR_RELAY_ENV" HERDR_APP_DEPLOY_ORIGIN
      record_phone_app_origin ${lib.escapeShellArg herdrMobileApp.defaultAppUrl} "$HERDR_RELAY_ENV"
      load_relay_env "$HERDR_RELAY_ENV"

      export HERDR_BIN=${pkgs.herdr}/bin/herdr
      export HERDR_WEB_ROOT=${herdrMobileRelay.passthru.webRoot}
      export PATH=${lib.escapeShellArg herdrMobileRelayPath}:"$PATH"
      exec ${herdrMobileRelayRoot}/herdr-mobile-relay serve
    '';
  };

  # Telegram Agents needs one bot per host, because a second poller on the same
  # token makes the daemon exit. The token and chat ID keys name values in
  # `secrets/herdr.yaml`; all hosts share `TELEGRAM_OPERATOR_IDS`.
  herdrTelegramAgentsHosts = {
    skrye = {
      tokenKey = "TELEGRAM_BOT_SKRYE";
      chatIdKey = "TELEGRAM_CHAT_ID_SKRYE";
      botUsername = "SkryeSithbot";
    };
    zannah = {
      tokenKey = "TELEGRAM_BOT_ZANNAH";
      chatIdKey = "TELEGRAM_CHAT_ID_ZANNAH";
      botUsername = "ZannahSithbot";
    };
  };
  herdrTelegramAgentsEnabled = noughtyLib.isHost (builtins.attrNames herdrTelegramAgentsHosts);
  herdrTelegramAgentsHost = herdrTelegramAgentsHosts.${host.name} or { };
  herdrTelegramAgents = pkgs.herdr-telegram-agents;
  inherit (herdrTelegramAgents.passthru) pluginId;
  # Herdr passes these as HERDR_PLUGIN_CONFIG_DIR and HERDR_PLUGIN_STATE_DIR.
  herdrTelegramAgentsConfigDir = "${config.xdg.configHome}/herdr/plugins/config/${pluginId}";
  herdrTelegramAgentsStateDir = "${config.xdg.stateHome}/herdr/plugins/${pluginId}";

  # Non-secret `config.json` fields. The daemon refuses a file whose `version`
  # differs from its schema version, 1. `chat_title` and `configured_at` are
  # display values only. Observers are declared here, so a `/observers`
  # change lasts only until the next activation.
  herdrTelegramAgentsSettings = {
    version = 1;
    bot_username = herdrTelegramAgentsHost.botUsername or "";
    chat_title = host.name;
    observer_ids = [ ];
    log_level = "info";
    configured_at = "1970-01-01T00:00:00Z";
  };

  # The plugin reads its bot token only from `config.json`, and the daemon
  # rewrites that file, so a sops template cannot own it. This decrypts the
  # host's token, chat ID, and operator IDs from `secrets/herdr.yaml` with the
  # user's age key and writes the whole file from them and the Nix settings,
  # so the plugin needs no setup wizard. sops-nix does not render the values,
  # because Fence keeps `~/.config/sops-nix` readable. The decrypted values
  # stay in shell variables and reach jq through process substitution, so
  # they are never in argv, the environment, the Nix store, or a log.
  herdrTelegramAgentsConfig = pkgs.writeShellApplication {
    name = "herdr-telegram-agents-config";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.jq
      pkgs.sops
    ];
    text = ''
      config_dir="$1"
      state_dir="$2"
      sops_file="$3"
      age_key_file="$4"
      settings="$5"
      token_key="$6"
      chat_id_key="$7"
      operator_ids_key="$8"

      # On Linux, Fence masks a denyRead path only when the path exists as
      # the sandbox starts, so both directories exist before the daemon runs.
      install -d -m 700 "$config_dir" "$state_dir"

      # sops errors are discarded so that nothing it prints reaches the log.
      decrypt() {
        [[ -r "$age_key_file" ]] \
          && SOPS_AGE_KEY_FILE="$age_key_file" sops -d --extract "[\"$1\"]" "$sops_file" 2>/dev/null
      }

      write_config() {
        local target="$config_dir/config.json" token chat_id operator_ids tmp
        token="$(decrypt "$token_key")" || token=""
        chat_id="$(decrypt "$chat_id_key")" || chat_id=""
        operator_ids="$(decrypt "$operator_ids_key")" || operator_ids=""
        if [[ -z "$token" || -z "$chat_id" || -z "$operator_ids" ]]; then
          echo "herdr-telegram-agents: could not decrypt $token_key, $chat_id_key, or $operator_ids_key, leaving config.json unchanged" >&2
          return 0
        fi

        # The daemon decodes `chat_id` and `operator_ids` as 64-bit integers
        # and needs a negative supergroup ID and at least one operator. Up to
        # 15 digits stay exact in jq. jq errors are discarded, because they
        # can quote a decrypted value.
        tmp="$(mktemp "$target.XXXXXX")"
        # shellcheck disable=SC2016 # jq variables, not shell expansions.
        if ! jq -n \
          --argjson settings "$settings" \
          --rawfile token <(printf '%s' "$token") \
          --rawfile chat_id <(printf '%s' "$chat_id") \
          --rawfile operator_ids <(printf '%s' "$operator_ids") '
            def trim: gsub("^\\s+|\\s+$"; "");
            ($token | trim) as $token
            | ($chat_id | trim) as $chat_id
            | ($operator_ids | split(",") | map(trim) | map(select(. != ""))) as $ops
            | if $token == "" then error("token")
              elif ($chat_id | test("^-[0-9]{1,15}$") | not) then error("chat_id")
              elif ($ops | length) == 0 or any($ops[]; test("^[0-9]{1,15}$") | not) then error("operator_ids")
              else . end
            | {
                version: $settings.version,
                bot_token: $token,
                bot_username: $settings.bot_username,
                chat_id: ($chat_id | tonumber),
                chat_title: $settings.chat_title,
                operator_ids: ($ops | map(tonumber)),
                observer_ids: $settings.observer_ids,
                log_level: $settings.log_level,
                configured_at: $settings.configured_at
              }
          ' >"$tmp" 2>/dev/null; then
          rm -f "$tmp"
          echo "herdr-telegram-agents: the decrypted values are not valid, leaving config.json unchanged" >&2
          return 0
        fi
        chmod 600 "$tmp"
        mv -f "$tmp" "$target"
      }

      merge_json() {
        local target="$1" filter="$2" tmp
        shift 2
        if [[ -e "$target" ]] && ! jq -e 'type == "object"' "$target" >/dev/null 2>&1; then
          echo "herdr-telegram-agents: $target is not a JSON object, leaving it unchanged" >&2
          return 0
        fi
        tmp="$(mktemp "$target.XXXXXX")"
        if [[ -e "$target" ]]; then
          jq "$@" "$filter" "$target" >"$tmp" || { rm -f "$tmp"; return 1; }
        else
          jq -n "$@" "{} | $filter" >"$tmp" || { rm -f "$tmp"; return 1; }
        fi
        chmod 600 "$tmp"
        mv -f "$tmp" "$target"
      }

      write_config

      # Secret redaction is on by default. Set it again on every activation,
      # so that a change from the Telegram options panel does not persist.
      merge_json "$config_dir/options.json" '
        .version = (.version // 1)
        | .values = ((.values // {}) + { "privacy.redact": true })
      '
    '';
  };

  # Prints a setup link and QR for one phone app, then restores the default app
  # that the Herdr `setup-link` action uses.
  herdrMobileRelayLink = pkgs.writeShellApplication {
    name = "herdr-mobile-relay-link";
    runtimeInputs = with pkgs; [ coreutils ] ++ lib.optionals host.is.linux [ pkgs.hostname ];
    text = ''
      app="''${1:-${herdrMobileApp.defaultApp}}"
      case "$app" in
      ${lib.concatStrings (
        lib.mapAttrsToList (name: url: ''
          ${name}) app_url=${lib.escapeShellArg url} ;;
        '') herdrMobileApp.appUrls
      )}
        *)
          printf 'Usage: herdr-mobile-relay-link [%s]\n' ${lib.escapeShellArg (lib.concatStringsSep "|" (lib.attrNames herdrMobileApp.appUrls))} >&2
          exit 2
          ;;
      esac

      export HERDR_RELAY_ENV=${lib.escapeShellArg herdrMobileRelayEnv}
      status=0
      HERDR_PHONE_APP_URL="$app_url" ${herdrMobileRelayRoot}/relay/setup-link.sh || status=$?

      if [[ -d ${lib.escapeShellArg herdrMobileRelayDir} ]]; then
        # shellcheck source=/dev/null
        . ${herdrMobileRelayRoot}/relay/common.sh
        record_phone_app_origin ${lib.escapeShellArg herdrMobileApp.defaultAppUrl} "$HERDR_RELAY_ENV"
      fi
      exit "$status"
    '';
  };
in
{
  config = lib.mkIf (!host.is.iso) {
    # `pkgs.herdr` comes from the `modifiedPackages` overlay, which exposes the
    # llm-agents flake build with a stable-release override.
    home.packages = [
      herdrWorktree
      pkgs.herdr
      herdrLayout
      herdrMobileRelay
      herdrMobileRelayLink
    ];

    # Herdr panes inherit the server environment, so plugin actions use the
    # relay environment of the service and the default phone app.
    home.sessionVariables = {
      HERDR_RELAY_ENV = herdrMobileRelayEnv;
      HERDR_PHONE_APP_URL = herdrMobileApp.defaultAppUrl;
    };

    # Unlink layout plugin variants that a previous host configuration may
    # have left linked, so exactly one `workspace.created` handler remains.
    # Also unlink the retired usage and quota plugins so no stale plugin state
    # remains on hosts that missed an earlier activation.
    home.activation.herdrLayoutPrune = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      for herdr_layout_id in ${
        lib.escapeShellArgs (
          [
            "usagebar"
            "space-usage"
            "herdr-agent-quota"
          ]
          ++ (if noughtyLib.hostHasTag "cg" then [ "local.home-layout" ] else [ "local.work-layout" ])
          ++ lib.optional (!herdrTelegramAgentsEnabled) pluginId
        )
      }; do
        ${pkgs.herdr}/bin/herdr plugin unlink "$herdr_layout_id" || true
      done
    '';

    home.activation.herdrLayoutPlugin = lib.hm.dag.entryAfter [ "herdrLayoutPrune" ] ''
      ${pkgs.herdr}/bin/herdr plugin link \
        ${herdrLayout}/share/herdr/plugins/${herdrLayout.passthru.pluginDir} --enabled
    '';

    home.activation.herdrMobileRelayPlugin = lib.hm.dag.entryAfter [ "herdrLayoutPlugin" ] ''
      ${pkgs.herdr}/bin/herdr plugin link ${herdrMobileRelayRoot} --enabled
    '';

    # On Linux, Fence masks a denyRead path only when the path exists as the
    # sandbox starts. The private directory and an empty `relay.env` exist
    # before the relay first runs, so an agent never sees the relay key. The
    # relay accepts an empty file and adds its key on first start.
    home.activation.herdrMobileRelayEnv =
      lib.hm.dag.entryBetween [ "reloadSystemd" "setupLaunchAgents" ] [ "writeBoundary" ]
        ''
          run install -d -m 700 ${lib.escapeShellArg herdrMobileRelayDir}
          if [[ ! -e ${lib.escapeShellArg herdrMobileRelayEnv} ]]; then
            run install -m 600 /dev/null ${lib.escapeShellArg herdrMobileRelayEnv}
          fi
        '';

    home.activation.herdrTelegramAgentsPlugin = lib.mkIf herdrTelegramAgentsEnabled (
      lib.hm.dag.entryAfter [ "herdrMobileRelayPlugin" ] ''
        ${pkgs.herdr}/bin/herdr plugin link ${herdrTelegramAgents.passthru.pluginRoot} --enabled
      ''
    );

    # The age key is a user file that activation does not create, so the step
    # needs only `writeBoundary`.
    home.activation.herdrTelegramAgentsConfig = lib.mkIf herdrTelegramAgentsEnabled (
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        run ${lib.getExe herdrTelegramAgentsConfig} \
          ${lib.escapeShellArg herdrTelegramAgentsConfigDir} \
          ${lib.escapeShellArg herdrTelegramAgentsStateDir} \
          ${../../../secrets/herdr.yaml} \
          ${lib.escapeShellArg config.sops.age.keyFile} \
          ${lib.escapeShellArg (builtins.toJSON herdrTelegramAgentsSettings)} \
          ${lib.escapeShellArg herdrTelegramAgentsHost.tokenKey} \
          ${lib.escapeShellArg herdrTelegramAgentsHost.chatIdKey} \
          TELEGRAM_OPERATOR_IDS
      ''
    );

    home.activation.herdrReloadConfig =
      lib.hm.dag.entryAfter
        [
          "herdrMobileRelayPlugin"
          "herdrTelegramAgentsPlugin"
        ]
        ''
          herdr_reload_status=0
          herdr_reload_output="$(${pkgs.herdr}/bin/herdr server reload-config 2>&1)" \
            || herdr_reload_status=$?

          if ((herdr_reload_status != 0)) \
            && ! printf '%s\n' "$herdr_reload_output" \
              | ${pkgs.jq}/bin/jq -e '.error.code == "server_not_running"' >/dev/null 2>&1; then
            printf '%s\n' "$herdr_reload_output" >&2
            exit "$herdr_reload_status"
          fi
        '';

    # The unit name and the launchd label are the ones that the upstream
    # scripts read to find `HERDR_RELAY_ENV` and to restart the relay. No unit
    # starts the Herdr server, so the relay polls for its socket instead of
    # ordering after it.
    systemd.user.services.herdr-mobile-relay = lib.mkIf host.is.linux {
      Unit.Description = "Herdr Mobile Relay";
      Service = {
        Type = "simple";
        ExecStart = lib.getExe herdrMobileRelayService;
        Environment = [ "HERDR_RELAY_ENV=${herdrMobileRelayEnv}" ];
        Restart = "on-failure";
        RestartSec = 10;
      };
      Install.WantedBy = [ "default.target" ];
    };

    launchd.agents.herdr-mobile-relay = lib.mkIf host.is.darwin {
      enable = true;
      config = {
        Label = "com.herdr-mobile-relay.service";
        ProgramArguments = [ (lib.getExe herdrMobileRelayService) ];
        EnvironmentVariables.HERDR_RELAY_ENV = herdrMobileRelayEnv;
        RunAtLoad = true;
        KeepAlive = true;
        StandardOutPath = "${config.home.homeDirectory}/Library/Logs/herdr-mobile-relay.log";
        StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/herdr-mobile-relay.log";
      };
    };

    xdg.configFile."herdr/config.toml".source = lib.mkDefault (
      tomlFormat.generate "herdr-config.toml" settings
    );
  };
}
