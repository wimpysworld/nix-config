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

  # Herdr Web runs on skrye and zannah only. The token key names a value in
  # `secrets/herdr.yaml`. All hosts share `HERDR_WEB_TAILSCALE_OWNER`, the
  # Tailscale login that gets in through Tailscale Serve without pairing.
  herdrWebUiHosts = {
    skrye.tokenKey = "HERDR_WEB_TOKEN_SKRYE";
    zannah.tokenKey = "HERDR_WEB_TOKEN_ZANNAH";
  };
  herdrWebUiEnabled = noughtyLib.isHost (builtins.attrNames herdrWebUiHosts);
  herdrWebUiHost = herdrWebUiHosts.${host.name} or { };
  # Herdr Web keeps devices, push keys, and bridge tokens here, and the bridge
  # path is fixed to `~/.config/herdr-web-ui/bridges`. Fence denies reads and
  # writes of the whole directory.
  herdrWebUiDir = "${config.xdg.configHome}/herdr-web-ui";
  herdrWebUiEnv = "${herdrWebUiDir}/service.env";
  herdrWebUiPasteDir = "${herdrWebUiDir}/paste";

  # The token is not a sops-nix secret, because Fence keeps
  # `~/.config/sops-nix` readable. This decrypts the token and the owner login
  # with the user's age key and writes them to an env file with mode 0600.
  # The decrypted values stay in shell variables, so they are never in argv,
  # the environment, the Nix store, or a log. On any failure the old file
  # stays.
  herdrWebUiEnvWriter = pkgs.writeShellApplication {
    name = "herdr-web-ui-env";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.sops
    ];
    text = ''
      state_dir="$1"
      paste_dir="$2"
      env_file="$3"
      sops_file="$4"
      age_key_file="$5"
      token_key="$6"
      owner_key="$7"

      # On Linux, Fence masks a denyRead path only when the path exists as
      # the sandbox starts, so the directories exist before the service runs.
      install -d -m 700 "$state_dir" "$paste_dir"

      # sops errors are discarded so that nothing it prints reaches the log.
      decrypt() {
        [[ -r "$age_key_file" ]] \
          && SOPS_AGE_KEY_FILE="$age_key_file" sops -d --extract "[\"$1\"]" "$sops_file" 2>/dev/null
      }

      token="$(decrypt "$token_key")" || token=""
      owner="$(decrypt "$owner_key")" || owner=""
      if [[ -z "$token" || -z "$owner" ]]; then
        echo "herdr-web-ui: could not decrypt $token_key or $owner_key, leaving $env_file unchanged" >&2
        exit 0
      fi
      # systemd reads the file without a shell, so only plain values pass.
      safe='^[A-Za-z0-9._~+/=:@-]+$'
      if [[ ! "$token" =~ $safe || ! "$owner" =~ $safe ]]; then
        echo "herdr-web-ui: the decrypted values are not valid, leaving $env_file unchanged" >&2
        exit 0
      fi

      tmp="$(mktemp "$env_file.XXXXXX")"
      printf 'HERDR_WEB_TOKEN=%s\nHERDR_WEB_TAILSCALE_OWNER=%s\n' "$token" "$owner" >"$tmp"
      chmod 600 "$tmp"
      mv -f "$tmp" "$env_file"
    '';
  };

  # Agent CLIs live in the user profile, which a user service does not put on
  # PATH by default.
  herdrWebUiPath = lib.concatStringsSep ":" [
    "${config.home.homeDirectory}/.nix-profile/bin"
    "${config.home.homeDirectory}/.local/state/nix/profile/bin"
    "/etc/profiles/per-user/${config.home.username}/bin"
    "/run/current-system/sw/bin"
    "/run/wrappers/bin"
  ];

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
    # Values merged into `options.json`, not `config.json`. The daemon ignores
    # a value of the wrong type, so every option except a bool is a string.
    # An icon must be in Telegram's free topic-icon pack, or the daemon uses
    # the default icon.
    options = {
      "privacy.redact" = true;
      "topics.delete_after_days" = "1";
      "icons.working" = "🧠";
      "icons.idle" = "☕️";
      "icons.blocked" = "‼️";
      "icons.done" = "⭐️";
      "icons.unknown" = "❓";
      "icons.exited" = "🏴‍☠️";
    };
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

      # Set the declared options again on every activation, so that a change
      # from the Telegram options panel does not persist.
      # shellcheck disable=SC2016 # jq variables, not shell expansions.
      merge_json "$config_dir/options.json" '
        .version = (.version // 1)
        | .values = ((.values // {}) + $settings.options)
      ' --argjson settings "$settings"
    '';
  };

  # Herdr runs the plugin startup hook only when the server starts, so a switch
  # does not start or restart the daemon. Herdr runs an invoked action in the
  # background, so this waits for the action's log entry and returns its
  # output and exit code.
  herdrTgAgent = pkgs.writeShellApplication {
    name = "herdr-tg-agent";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.herdr
      pkgs.jq
    ];
    text = ''
      case "''${1:-}" in
        start | stop | restart | status) action="$1" ;;
        *)
          echo "Usage: herdr-tg-agent start|stop|restart|status" >&2
          exit 2
          ;;
      esac

      plugin=${lib.escapeShellArg pluginId}
      invoked="$(herdr plugin action invoke "$action" --plugin "$plugin")"
      log_id="$(jq -r '.result.log.log_id // empty' <<<"$invoked")"
      if [[ -z "$log_id" ]]; then
        echo "herdr-tg-agent: the invoke response has no log ID" >&2
        exit 1
      fi

      # Poll every half second for up to 15 seconds.
      for _ in {1..30}; do
        entry="$(herdr plugin log list --plugin "$plugin" --limit 20 \
          | jq -c --arg id "$log_id" '.result.logs[] | select(.log_id == $id)')"
        if [[ -n "$entry" ]] && [[ "$(jq -r '.status' <<<"$entry")" != running ]]; then
          jq -j '.stdout // ""' <<<"$entry"
          jq -j '(.stderr // "") + (if .error then .error + "\n" else "" end)' <<<"$entry" >&2
          exit "$(jq -r '.exit_code // 1' <<<"$entry")"
        fi
        sleep 0.5
      done

      echo "herdr-tg-agent: the $action action did not finish within 15 seconds (log $log_id)" >&2
      exit 1
    '';
  };

  # The service runs the profile copy of Herdr, not a store path, so a Herdr
  # update does not change the unit or the plist and does not restart the
  # server.
  herdrProfileBin = "${config.home.profileDirectory}/bin/herdr";
  herdrSocket = "${config.xdg.configHome}/herdr/herdr.sock";
  # NixOS runs `ssh-agent.service` in the user manager. Lima and WSL hosts are
  # Home Manager only, so they have no such unit.
  hostHasSshAgentUnit =
    host.is.linux && !(noughtyLib.hostHasTag "lima" || noughtyLib.hostHasTag "wsl");
  # Panes of a server that starts at boot have no display. These are the
  # variables the compositor imports into the user manager, with a generic
  # fallback for a desktop outside the compositor contract.
  compositor = lib.attrByPath [
    host.desktop
  ] null (import ../../../lib/wayland-compositors.nix).compositors;
  paneDisplayVariables =
    if compositor != null then
      compositor.ephemeralEnvironment
    else
      [
        "DISPLAY"
        "WAYLAND_DISPLAY"
        "XDG_SESSION_TYPE"
        "XDG_CURRENT_DESKTOP"
      ];

in
{
  config = lib.mkIf (!host.is.iso) {
    # `pkgs.herdr` comes from the `modifiedPackages` overlay, which exposes the
    # llm-agents flake build with a stable-release override.
    home.packages = [
      herdrWorktree
      pkgs.herdr
      herdrLayout
    ]
    ++ lib.optional herdrTelegramAgentsEnabled herdrTgAgent;

    # Unlink layout plugin variants that a previous host configuration may
    # have left linked, so exactly one `workspace.created` handler remains.
    # Also unlink the retired usage, quota, and mobile relay plugins so no
    # stale plugin state remains on hosts that missed an earlier activation.
    home.activation.herdrLayoutPrune = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      for herdr_layout_id in ${
        lib.escapeShellArgs (
          [
            "usagebar"
            "ez-corp.space-usage"
            "herdr-agent-quota"
            "herdr-mobile-relay.events"
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

    # The env file must exist before sd-switch starts the service.
    home.activation.herdrWebUiEnv = lib.mkIf herdrWebUiEnabled (
      lib.hm.dag.entryBetween [ "reloadSystemd" ] [ "writeBoundary" ] ''
        run ${lib.getExe herdrWebUiEnvWriter} \
          ${lib.escapeShellArg herdrWebUiDir} \
          ${lib.escapeShellArg herdrWebUiPasteDir} \
          ${lib.escapeShellArg herdrWebUiEnv} \
          ${../../../secrets/herdr.yaml} \
          ${lib.escapeShellArg config.sops.age.keyFile} \
          ${lib.escapeShellArg herdrWebUiHost.tokenKey} \
          HERDR_WEB_TAILSCALE_OWNER
      ''
    );

    home.activation.herdrTelegramAgentsPlugin = lib.mkIf herdrTelegramAgentsEnabled (
      lib.hm.dag.entryAfter [ "herdrLayoutPlugin" ] ''
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
          "herdrLayoutPlugin"
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

    # The Herdr server starts with the user manager, which linger starts at
    # boot on NixOS. `keep-old` stops a switch from restarting a running
    # server and its panes. A server started by hand owns the socket, so the
    # condition skips the start instead of failing in a restart loop.
    systemd.user.services.herdr = lib.mkIf host.is.linux {
      Unit = {
        Description = "Herdr server";
        X-SwitchMethod = "keep-old";
        After = lib.optional hostHasSshAgentUnit "ssh-agent.service";
        Wants = lib.optional hostHasSshAgentUnit "ssh-agent.service";
      };
      Service = {
        Type = "simple";
        ExecCondition = "${pkgs.bash}/bin/bash -c '! ${lib.getExe pkgs.socat} -u OPEN:/dev/null UNIX-CONNECT:${herdrSocket} 2>/dev/null'";
        ExecStart = "${herdrProfileBin} server";
        Environment = lib.optional hostHasSshAgentUnit "SSH_AUTH_SOCK=%t/ssh-agent";
        Restart = "on-failure";
        RestartSec = 30;
        # Herdr saves the session as it stops.
        TimeoutStopSec = 60;
      };
      Install.WantedBy = [ "default.target" ];
    };

    # launchd starts the agent at login. The shell exits 0 when a server
    # started by hand owns the socket, and `KeepAlive` restarts only after a
    # failure, so neither case loops. The plist text holds no store path.
    launchd.agents.herdr = lib.mkIf host.is.darwin {
      enable = true;
      config = {
        ProgramArguments = [
          "/bin/sh"
          "-c"
          "/usr/bin/nc -U -z '${herdrSocket}' 2>/dev/null && exit 0; exec '${herdrProfileBin}' server"
        ];
        RunAtLoad = true;
        KeepAlive.SuccessfulExit = false;
        ThrottleInterval = 30;
        StandardOutPath = "${config.home.homeDirectory}/Library/Logs/herdr.log";
        StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/herdr.log";
      };
    };

    # A pane of a server that started before the graphical login has no
    # display variables. This copies them from the user manager into a new
    # pane shell, once, and only when the pane has no Wayland or X11 display.
    programs.fish.interactiveShellInit = lib.mkIf (host.is.workstation && host.is.linux) ''
      if test "$HERDR_ENV" = 1; and not set -q WAYLAND_DISPLAY; and not set -q DISPLAY; and command -q systemctl
          for __herdr_line in (systemctl --user show-environment 2>/dev/null)
              set -l __herdr_kv (string split -m 1 = -- $__herdr_line)
              if contains -- $__herdr_kv[1] ${lib.escapeShellArgs paneDisplayVariables}; and not set -q $__herdr_kv[1]
                  set -gx $__herdr_kv[1] $__herdr_kv[2]
              end
          end
          set -e __herdr_line
      end
    '';

    # Herdr Web runs as a user service, not as a Herdr plugin, so systemd
    # restarts it and Herdr does not start a second copy. It runs without the
    # upstream supervisor, so the self-updater is off. It starts after the
    # Herdr server and retries the Herdr socket, so a socket that appears
    # late does no harm. `Wants`, not `BindsTo`, keeps it up across a
    # deliberate `herdr server stop`. The env file holds `HERDR_WEB_TOKEN`
    # and `HERDR_WEB_TAILSCALE_OWNER`. Without it the unit fails, so the
    # server never runs without a token.
    systemd.user.services.herdr-web-ui = lib.mkIf (herdrWebUiEnabled && host.is.linux) {
      Unit = {
        Description = "Herdr Web";
        After = [ "herdr.service" ];
        Wants = [ "herdr.service" ];
      };
      Service = {
        Type = "simple";
        ExecStart = lib.getExe pkgs.herdr-web-ui;
        EnvironmentFile = herdrWebUiEnv;
        Environment = [
          # Keep `HOST` and `PORT` in sync with the Tailscale Serve target in
          # nixos/_mixins/server/herdr-web-ui/default.nix.
          "HOST=127.0.0.1"
          "PORT=7317"
          "HERDR_WEB_TELEMETRY=0"
          "HERDR_WEB_APP_NAME=${host.name}"
          "HERDR_WEB_HERDR_BIN=${lib.getExe pkgs.herdr}"
          "HERDR_WEB_STATE_DIR=${herdrWebUiDir}"
          "HERDR_WEB_PASTE_DIR=${herdrWebUiPasteDir}"
          "PATH=${herdrWebUiPath}"
        ];
        Restart = "on-failure";
        RestartSec = 10;
      };
      Install.WantedBy = [ "default.target" ];
    };

    xdg.configFile."herdr/config.toml".source = lib.mkDefault (
      tomlFormat.generate "herdr-config.toml" settings
    );
  };
}
