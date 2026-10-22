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
  # Every host opens a new space as one Shell pane. In linked worktree
  # spaces, work hosts get the Chainguard pane set and Claude and Codex
  # autostart, and home hosts get the OpenCode pane set.
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
    # Herdr 0.9.3 defaults to 26 columns, and the Agents rows lose 5 columns
    # to the margins. The first Agents row ends with the agent name, and the
    # second row shows the model and effort, such as `claude-opus-5-5 · high`.
    # They need 36 columns. 36 is also
    # the default `ui.sidebar_max_width`, so a wider value needs that too.
    ui.sidebar_width = 36;
    # Herdr's default Agent rows, plus the Context Bar row. The plugin reports
    # exactly one of the three tokens for each supported agent pane, so the
    # bar takes the colour of its band: below 50%, 50% to 79%, and 80% and
    # above. The first row ends with the plain agent name, and the second row
    # holds the Model Display `$model` and `$effort` tokens. Herdr drops
    # `$effort` when the plugin clears it, and drops the row when both are
    # empty.
    ui.sidebar.agents = {
      row_gap = 0;
      rows = [
        [
          "state_icon"
          "machine"
          "workspace"
          # Colour each harness near its brand: peach for Claude's orange,
          # teal for OpenAI's green, and free accents for OpenCode and Pi.
          # Green, yellow and red stay free for the Context Bar bands.
          {
            token = "agent";
            rules = map (rule: rule // { ignore_case = true; }) [
              {
                equals = "claude";
                fg = catppuccinPalette.getColor "peach";
              }
              {
                equals = "codex";
                fg = catppuccinPalette.getColor "teal";
              }
              {
                equals = "opencode";
                fg = catppuccinPalette.getColor "sapphire";
              }
              {
                equals = "pi";
                fg = catppuccinPalette.getColor "mauve";
              }
            ];
          }
        ]
        [
          { token = "$model"; }
          { token = "$effort"; }
        ]
        [
          {
            token = "$ctx_green";
            fg = catppuccinPalette.getColor "green";
          }
          {
            token = "$ctx_yellow";
            fg = catppuccinPalette.getColor "yellow";
          }
          {
            token = "$ctx_red";
            fg = catppuccinPalette.getColor "red";
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

  # The Roamgate secrets are not sops-nix secrets, because Fence
  # keeps `~/.config/sops-nix` readable. This decrypts each sops key with the
  # user's age key and writes `VAR="value"` lines to an env file with mode
  # 0600. Each entry is five arguments: the variable, the sops file, the key,
  # a regular expression that the value must match, and the rule that a
  # warning names when it does not match. The decrypted values stay in shell
  # variables and pipes, so they are never in argv, the environment, the Nix
  # store, or a log. Every failure prints a warning that names the activation
  # step and the reason, never a value, and keeps the old file. It exits 0, so
  # a bad secret does not stop the rest of the activation.
  herdrEnvFileWriter = pkgs.writeShellApplication {
    name = "herdr-env-file";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.iconv
      pkgs.sops
    ];
    text = ''
      step="$1"
      env_file="$2"
      age_key_file="$3"
      shift 3
      # A pattern such as `[0-9]` must match ASCII only, as in the apps.
      export LC_ALL=C

      warn() {
        printf 'WARNING: %s: %s, so %s is unchanged\n' "$step" "$1" "$env_file" >&2
        exit 0
      }
      trap 'warn "an unexpected error stopped the step"' ERR

      [[ -r "$age_key_file" ]] || warn "cannot read the age key $age_key_file"
      (($# > 0 && $# % 5 == 0)) || warn "the entries are not groups of five arguments"

      # One UTF-32 code point per line, in hexadecimal: U+FDD0 to U+FDEF, and
      # U+FFFE and U+FFFF in every plane.
      noncharacter=$'(^|\n)(0000fd[de][0-9a-f]|00[01][0-9a-f]fff[ef])(\n|$)'
      lines=""
      while (($# > 0)); do
        var="$1"
        sops_file="$2"
        key="$3"
        # An empty pattern accepts every value that the checks below accept.
        pattern="$4"
        rule="$5"
        shift 5
        [[ -r "$sops_file" ]] || warn "cannot read $sops_file"
        # sops errors are discarded, because they can quote the file. A NUL
        # becomes the byte 0xff, so the UTF-8 check below refuses it.
        value="$(SOPS_AGE_KEY_FILE="$age_key_file" sops -d --extract "[\"$key\"]" "$sops_file" 2>/dev/null | tr '\0' '\377')" \
          || warn "cannot decrypt $key from $sops_file: the key is missing, or the age key cannot decrypt the file"
        [[ -n "$value" ]] || warn "$key is empty"
        [[ "$value" != *$'\n'* ]] || warn "$key has a line break"
        # systemd ignores the whole file when a value is not valid UTF-8 or
        # has a Unicode noncharacter, so the unit would start without it.
        codepoints="$(printf '%s' "$value" | iconv -f UTF-8 -t UTF-32BE 2>/dev/null | od -An -v -tx1 -w4 | tr -d ' ')" \
          || warn "$key is not valid UTF-8 or has a NUL"
        [[ ! "$codepoints" =~ $noncharacter ]] || warn "$key has a Unicode noncharacter"
        [[ -z "$pattern" || "$value" =~ $pattern ]] || warn "$key is not valid: $rule"
        # In a double-quoted systemd value, a backslash keeps the next `"`,
        # `\`, backtick, or `$` literally, and every other character is
        # literal. systemd expands no variables in an env file.
        value="''${value//\\/\\\\}"
        value="''${value//\"/\\\"}"
        value="''${value//\`/\\\`}"
        value="''${value//\$/\\\$}"
        lines+="$var=\"$value\""$'\n'
      done

      tmp="$(mktemp "$env_file.XXXXXX")" || warn "cannot create a file next to $env_file"
      if ! { printf '%s' "$lines" >"$tmp" && chmod 600 "$tmp" && mv -f "$tmp" "$env_file"; }; then
        rm -f "$tmp"
        warn "cannot write $env_file"
      fi
    '';
  };

  # The activation step creates the state directories, runs the writer, and
  # warns when the unit still has no env file. On Linux, Fence masks a
  # denyRead path only when the path exists as the sandbox starts, so the
  # directories exist before the service runs. Each entry names `var` and
  # `key`, and can set `sopsFile`, `pattern`, and `rule`.
  mkEnvFileStep =
    {
      step,
      unit,
      dirs,
      envFile,
      entries,
    }:
    lib.hm.dag.entryBetween [ "reloadSystemd" ] [ "writeBoundary" ] ''
      run install -d -m 700 ${lib.escapeShellArgs dirs}
      run ${lib.getExe herdrEnvFileWriter} \
        ${
          lib.escapeShellArgs [
            step
            envFile
            config.sops.age.keyFile
          ]
        } \
        ${lib.concatMapStringsSep " " (
          {
            var,
            key,
            sopsFile ? ../../../secrets/herdr.yaml,
            pattern ? "",
            rule ? "",
          }:
          "${lib.escapeShellArg var} ${sopsFile} ${
            lib.escapeShellArgs [
              key
              pattern
              rule
            ]
          }"
        ) entries}
      if [[ ! -v DRY_RUN && ! -s ${lib.escapeShellArg envFile} ]]; then
        warnEcho ${lib.escapeShellArg "${step}: ${envFile} is missing, so ${unit} cannot start"}
      fi
    '';

  # Each start checks for the env file first, so a missing file logs a clear
  # reason. The `-` prefix on `EnvironmentFile` stops systemd from failing
  # earlier with only `Result: resources`.
  mkEnvFileCheck =
    envFile:
    "${pkgs.bash}/bin/bash -c ${lib.escapeShellArg "[[ -s ${lib.escapeShellArg envFile} ]] || { echo \"missing ${envFile}: run just switch-home and check the activation warnings\" >&2; exit 1; }"}";

  # Agent CLIs live in the user profile, which a user service does not put on
  # PATH by default.
  agentPath = lib.concatStringsSep ":" [
    "${config.home.homeDirectory}/.nix-profile/bin"
    "${config.home.homeDirectory}/.local/state/nix/profile/bin"
    "/etc/profiles/per-user/${config.home.username}/bin"
    "/run/current-system/sw/bin"
    "/run/wrappers/bin"
  ];

  # Roamgate runs on hosts with the `roamgate` tag. All of them share the
  # `ROAMGATE_PIN` value in `secrets/herdr.yaml`.
  roamgateEnabled = noughtyLib.hostHasTag "roamgate";
  # Roamgate fixes its data directory to `~/.config/roamgate`, refuses a
  # symlink in that path, and can migrate files from the legacy
  # `~/.config/herdr-gui`. Fence denies reads and writes of both.
  roamgateDir = "${config.xdg.configHome}/roamgate";
  roamgateLegacyDir = "${config.xdg.configHome}/herdr-gui";
  roamgateEnv = "${roamgateDir}/roamgate.env";
  roamgateAssistantDir = "${roamgateDir}/assistant";

  # Ranger, the Roamgate assistant, uses the OpenCode Go subscription through
  # the `opencode-go` provider of its Pi SDK. Pick another model ID from that
  # provider's model list in the Ranger settings.
  roamgateRangerModel = "glm-5.3-flash";

  # Ranger reads its provider and model from `config` in `state.json`, not
  # from the environment or `settings.json`. It counts a provider as
  # configured only when `auth.json` has a key for it, or when `models.json`
  # names the key's environment variable. Roamgate rewrites `state.json` from
  # memory while it runs, so this merge runs before each start. It keeps the
  # conversations and every other key, and drops the thinking effort only
  # when the model changes, because Ranger refuses an effort that the model
  # does not support. A file that is not a JSON object stays unchanged with a
  # warning, and no failure stops the start.
  roamgateRangerConfig = pkgs.writeShellApplication {
    name = "roamgate-ranger-config";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.jq
    ];
    text = ''
      state_dir="$1"
      provider="$2"
      model="$3"
      key_var="$4"
      trap 'echo "WARNING: roamgate-ranger-config: an unexpected error stopped the step" >&2; exit 0' ERR

      # Every file starts from `initial` when it is missing.
      merge_json() {
        local target="$state_dir/$1" initial="$2" filter="$3" tmp
        shift 3
        if [[ -e "$target" ]] && ! jq -e 'type == "object"' "$target" >/dev/null 2>&1; then
          echo "WARNING: roamgate-ranger-config: $target is not a JSON object, so it is unchanged" >&2
          return 0
        fi
        tmp="$(mktemp "$target.XXXXXX")"
        if [[ -e "$target" ]]; then
          jq "$@" "$filter" "$target" >"$tmp" || { rm -f "$tmp"; return 1; }
        else
          jq -n "$@" "$initial | $filter" >"$tmp" || { rm -f "$tmp"; return 1; }
        fi
        chmod 600 "$tmp"
        mv -f "$tmp" "$target"
      }

      install -d -m 700 "$state_dir"
      # shellcheck disable=SC2016 # jq variables, not shell expansions.
      merge_json state.json '{messages: [], entries: [], requests: []}' '
        .config = (.config // {allowed_workspaces: []})
        | if .config.provider != $provider or .config.model != $model
          then .config |= del(.thinking_level) else . end
        | .config += {provider: $provider, model: $model, credential_source: "assistant"}
      ' --arg provider "$provider" --arg model "$model"
      # shellcheck disable=SC2016 # jq variables, not shell expansions.
      merge_json models.json '{}' '
        .providers[$provider].apiKey = ("$" + $key_var)
      ' --arg provider "$provider" --arg key_var "$key_var"
    '';
  };

  # Tailscale Serve publishes each app on the tailnet from a user unit. The
  # user is the Tailscale operator, so `tailscale serve` needs no root. The
  # system CLI matches the running tailscaled. The serve configuration
  # persists in the tailscaled state, and each start sets the same mapping
  # again, so the unit is idempotent. A stop removes the mapping.
  tailscale = "/run/current-system/sw/bin/tailscale";
  mkTailscaleServe =
    {
      description,
      app,
      httpsPort,
      target,
    }:
    let
      serve = pkgs.writeShellApplication {
        name = "${app}-serve";
        runtimeInputs = [ pkgs.jq ];
        # Serve needs the node to be logged in, so wait up to 60 seconds for
        # it. If serve still fails, systemd tries again after `RestartSec`.
        text = ''
          for _ in {1..120}; do
            if ${tailscale} status --peers=false --json \
              | jq -e '.BackendState == "Running"' >/dev/null 2>&1; then
              break
            fi
            sleep 0.5
          done
          exec ${tailscale} serve --bg --yes --https=${httpsPort} ${target}
        '';
      };
    in
    {
      Unit = {
        Description = description;
        After = [ "${app}.service" ];
        Wants = [ "${app}.service" ];
      };
      Service = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = lib.getExe serve;
        ExecStop = "${tailscale} serve --https=${httpsPort} off";
        Restart = "on-failure";
        RestartSec = 30;
      };
      Install.WantedBy = [ "default.target" ];
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
  herdrCtxBar = pkgs.herdr-ctx-bar;
  herdrDispModel = pkgs.herdr-disp-model;
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
  # NixOS runs `ssh-agent.service` in the user manager. WSL hosts are
  # Home Manager only, so they have no such unit.
  hostHasSshAgentUnit = host.is.linux && !(noughtyLib.hostHasTag "wsl");
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

    home.activation.herdrCtxBarPlugin = lib.hm.dag.entryAfter [ "herdrLayoutPlugin" ] ''
      ${pkgs.herdr}/bin/herdr plugin link ${herdrCtxBar.passthru.pluginRoot} --enabled
    '';

    # Model Display has no daemon. The agent modules install its hooks, so its
    # `setup-all` action is not needed.
    home.activation.herdrDispModelPlugin = lib.hm.dag.entryAfter [ "herdrLayoutPlugin" ] ''
      ${pkgs.herdr}/bin/herdr plugin link ${herdrDispModel.passthru.pluginRoot} --enabled
    '';

    # The env file must exist before sd-switch starts the service. Roamgate
    # exits at start when the PIN is not 6 to 12 ASCII digits. Ranger's
    # `opencode-go` provider reads its key from `OPENCODE_API_KEY`. The
    # OpenCode Zen key of the OpenCode Go subscription is that key.
    home.activation.roamgateEnv = lib.mkIf roamgateEnabled (mkEnvFileStep {
      step = "roamgateEnv";
      unit = "roamgate.service";
      dirs = [
        roamgateDir
        roamgateLegacyDir
        roamgateAssistantDir
      ];
      envFile = roamgateEnv;
      entries = [
        {
          var = "ROAMGATE_PIN";
          key = "ROAMGATE_PIN";
          pattern = "^[0-9]{6,12}$";
          rule = "use 6 to 12 ASCII digits";
        }
        {
          var = "OPENCODE_API_KEY";
          key = "OPENCODE_ZEN_API_KEY";
          sopsFile = ../../../secrets/ai.yaml;
        }
      ];
    });

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
          "herdrCtxBarPlugin"
          "herdrDispModelPlugin"
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

    # Herdr runs the Context Bar startup hook only when the server starts, not
    # when a plugin is linked, so a running server would show no bar until a
    # new pane opens and would keep a daemon from an older store path. The
    # `restart` action stops the old daemon and starts one from the linked
    # path. Herdr runs the action in the background, so the step does not
    # wait for it. With no server running, the startup hook starts the daemon
    # later, so the step succeeds quietly. Any other failure prints a warning
    # and does not stop the activation, because the bar is only a display.
    home.activation.herdrCtxBarRestart = lib.hm.dag.entryAfter [ "herdrReloadConfig" ] ''
      herdr_ctx_bar_status=0
      herdr_ctx_bar_output="$(${pkgs.herdr}/bin/herdr plugin action invoke restart \
        --plugin ${lib.escapeShellArg herdrCtxBar.passthru.pluginId} 2>&1)" \
        || herdr_ctx_bar_status=$?

      if ((herdr_ctx_bar_status != 0)) \
        && ! printf '%s\n' "$herdr_ctx_bar_output" \
          | ${pkgs.jq}/bin/jq -e '.error.code == "server_not_running"' >/dev/null 2>&1; then
        warnEcho "herdrCtxBarRestart: the Context Bar restart action failed: $herdr_ctx_bar_output"
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

    # Roamgate runs as a user service from the Nix store, not as its Herdr
    # plugin, which downloads a prebuilt binary. It runs from source on Bun,
    # so the self-updater cannot replace it. The env file holds
    # `ROAMGATE_PIN` and Ranger's `OPENCODE_API_KEY`. Without it the pre-start
    # check fails, so the server never runs without the PIN. With no password set, Roamgate also
    # generates a login token in `~/.config/roamgate`. `NODE_ENV` stays unset,
    # because `development` on a loopback bind turns login off. The package
    # turns worktree hooks off by default for every repository.
    systemd.user.services.roamgate = lib.mkIf (roamgateEnabled && host.is.linux) {
      Unit = {
        Description = "Roamgate";
        After = [ "herdr.service" ];
        Wants = [ "herdr.service" ];
      };
      Service = {
        Type = "simple";
        ExecStart = lib.getExe pkgs.roamgate;
        ExecStartPre = [
          (mkEnvFileCheck roamgateEnv)
          "${lib.getExe roamgateRangerConfig} ${
            lib.escapeShellArgs [
              roamgateAssistantDir
              "opencode-go"
              roamgateRangerModel
              "OPENCODE_API_KEY"
            ]
          }"
        ];
        EnvironmentFile = "-${roamgateEnv}";
        Environment = [
          # Keep `HOST` and `PORT` in sync with the Tailscale Serve target of
          # `roamgate-serve`.
          "HOST=127.0.0.1"
          "PORT=8787"
          # The server answers every update check with no update and makes no
          # network request. The "Automatic update checks" toggle in the
          # settings is a browser `localStorage` value, so it still shows
          # "Enabled" until it is turned off in each browser.
          "ROAMGATE_DISABLE_UPDATE_CHECK=1"
          "PATH=${agentPath}"
        ];
        Restart = "on-failure";
        RestartSec = 10;
      };
      Install.WantedBy = [ "default.target" ];
    };

    # Roamgate needs its own origin, because its web app uses absolute paths,
    # so it gets its own HTTPS port. It trusts no proxy header, so Serve adds
    # no login.
    systemd.user.services.roamgate-serve =
      lib.mkIf (roamgateEnabled && host.is.linux)
        (mkTailscaleServe {
          description = "Publish Roamgate on the tailnet with Tailscale Serve";
          app = "roamgate";
          httpsPort = "10000";
          target = "http://127.0.0.1:8787";
        });

    xdg.configFile."herdr/config.toml".source = lib.mkDefault (
      tomlFormat.generate "herdr-config.toml" settings
    );
  };
}
