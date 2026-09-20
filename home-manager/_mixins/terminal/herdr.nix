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
  # Agents the plugin's configure and sidebar collectors enable. Claude is
  # excluded because its observation rides the Claude Code StatusLine, which
  # stays under Home Manager management here.
  herdrAgentQuotaAgents = [
    "codex"
    "opencode"
    "pi"
  ];
  # The plugin tags its icon token values with zero-width Unicode markers so
  # the conditional `rules` on the icon cell can recolour them per state. The
  # tags are invisible in the configuration file, so they are built from their
  # codepoints through a JSON escape (Nix string literals have no `\u` form).
  iconDoneTag = builtins.fromJSON "\"\\u2060\"";
  iconWorkingTag = builtins.fromJSON "\"\\u2061\"";
  # Brand-icon colour lives on `$quota_icon` via these conditions: teal when
  # done, yellow while working, ink-white otherwise, matching the plugin's
  # own `rules` on the gauges identity row.
  iconDoneColor = "#94e2d5";
  iconWorkingColor = "#f9e2af";
  iconIdleColor = "#e9e9f0";
  quotaSafeColor = "#98b17d";
  quotaWarningColor = "#dec27f";
  quotaDangerColor = "#df919b";
  quotaAlertColor = "#e4b957";

  # Per-pane identity row from the retired usage plugin's vocabulary
  # (`$title`, `$provider`, `$limit`, `$context`), written to ALL agents'
  # panes and preserved verbatim inside each agent's quota-specific rows.
  herdrIdentityRows = [
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
  # The plugin's gauges row template, exactly as herdr-agent-quota installs
  # it for the selected agents. The plugin detects its own managed rows with
  # a comment marker that Home Manager's TOML generator cannot emit, so the
  # rows are properties of this file: the plugin's repair action sees user
  # entries and leaves them alone, and activation reclaims ownership.
  herdrAgentQuotaRows = [
    [
      {
        token = "$quota_group";
        bold = true;
        dim = false;
      }
    ]
  ]
  ++ herdrIdentityRows
  ++ [
    [
      {
        token = "$quota_icon";
        fg = iconIdleColor;
        bold = false;
        dim = false;
        rules = [
          {
            contains = iconDoneTag;
            fg = iconDoneColor;
          }
          {
            contains = iconWorkingTag;
            fg = iconWorkingColor;
          }
        ];
      }
      {
        token = "$quota_provider_model";
        fg = iconIdleColor;
        bold = true;
        dim = false;
      }
    ]
    [
      {
        token = "$quota_share_5h_normal";
        fg = quotaSafeColor;
        bold = false;
        dim = false;
      }
      {
        token = "$quota_share_5h_warning";
        fg = quotaWarningColor;
        bold = false;
        dim = false;
      }
      {
        token = "$quota_share_5h_danger";
        fg = quotaDangerColor;
        bold = false;
        dim = false;
      }
      {
        token = "$quota_share_5h_unknown";
        bold = false;
        dim = false;
      }
    ]
    [
      {
        token = "$quota_share_week_inline_normal";
        fg = quotaSafeColor;
        bold = false;
        dim = false;
      }
      {
        token = "$quota_share_week_inline_warning";
        fg = quotaWarningColor;
        bold = false;
        dim = false;
      }
      {
        token = "$quota_share_week_inline_danger";
        fg = quotaDangerColor;
        bold = false;
        dim = false;
      }
      {
        token = "$quota_share_week_inline_unknown";
        bold = false;
        dim = false;
      }
      {
        token = "$quota_share_week_normal";
        fg = quotaSafeColor;
        bold = false;
        dim = false;
      }
      {
        token = "$quota_share_week_warning";
        fg = quotaWarningColor;
        bold = false;
        dim = false;
      }
      {
        token = "$quota_share_week_danger";
        fg = quotaDangerColor;
        bold = false;
        dim = false;
      }
      {
        token = "$quota_share_week_unknown";
        bold = false;
        dim = false;
      }
    ]
    [
      {
        token = "$quota_share_month_normal";
        fg = quotaSafeColor;
        bold = false;
        dim = false;
      }
      {
        token = "$quota_share_month_warning";
        fg = quotaWarningColor;
        bold = false;
        dim = false;
      }
      {
        token = "$quota_share_month_danger";
        fg = quotaDangerColor;
        bold = false;
        dim = false;
      }
      {
        token = "$quota_share_month_unknown";
        bold = false;
        dim = false;
      }
    ]
    [
      {
        token = "$quota_model";
        fg = iconIdleColor;
        bold = false;
        dim = false;
      }
    ]
    [
      {
        token = "$quota_topic";
        bold = false;
        dim = false;
      }
    ]
    [
      {
        token = "$quota_error";
        fg = quotaAlertColor;
        bold = false;
        dim = false;
      }
    ]
    [
      {
        token = "$quota_context_normal";
        fg = quotaSafeColor;
        bold = false;
        dim = false;
      }
      {
        token = "$quota_context_warning";
        fg = quotaWarningColor;
        bold = false;
        dim = false;
      }
      {
        token = "$quota_context_danger";
        fg = quotaDangerColor;
        bold = false;
        dim = false;
      }
    ]
    [
      {
        token = "$quota_5h_normal";
        fg = quotaSafeColor;
        bold = false;
        dim = false;
      }
      {
        token = "$quota_5h_warning";
        fg = quotaWarningColor;
        bold = false;
        dim = false;
      }
      {
        token = "$quota_5h_danger";
        fg = quotaDangerColor;
        bold = false;
        dim = false;
      }
      {
        token = "$quota_5h_unknown";
        bold = false;
        dim = false;
      }
    ]
    [
      {
        token = "$quota_week_inline_normal";
        fg = quotaSafeColor;
        bold = false;
        dim = false;
      }
      {
        token = "$quota_week_inline_warning";
        fg = quotaWarningColor;
        bold = false;
        dim = false;
      }
      {
        token = "$quota_week_inline_danger";
        fg = quotaDangerColor;
        bold = false;
        dim = false;
      }
      {
        token = "$quota_week_inline_unknown";
        bold = false;
        dim = false;
      }
      {
        token = "$quota_week_normal";
        fg = quotaSafeColor;
        bold = false;
        dim = false;
      }
      {
        token = "$quota_week_warning";
        fg = quotaWarningColor;
        bold = false;
        dim = false;
      }
      {
        token = "$quota_week_danger";
        fg = quotaDangerColor;
        bold = false;
        dim = false;
      }
      {
        token = "$quota_week_unknown";
        bold = false;
        dim = false;
      }
    ]
    [
      {
        token = "$quota_month_normal";
        fg = quotaSafeColor;
        bold = false;
        dim = false;
      }
      {
        token = "$quota_month_warning";
        fg = quotaWarningColor;
        bold = false;
        dim = false;
      }
      {
        token = "$quota_month_danger";
        fg = quotaDangerColor;
        bold = false;
        dim = false;
      }
      {
        token = "$quota_month_unknown";
        bold = false;
        dim = false;
      }
    ]
    [
      {
        token = "$quota_nest_gap";
        bold = false;
        dim = false;
      }
    ]
  ];
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
      rows = herdrIdentityRows;
      # Per-agent row overrides for the plugin's chosen agents. The plugin
      # only rewrites `rows_by_agent.<provider>` entries it installed itself
      # (marked with a comment Home Manager cannot emit), so user entries
      # here stay HM-owned and the plugin's repair action leaves them alone.
      rows_by_agent = {
        "codex" = herdrAgentQuotaRows;
        "opencode" = herdrAgentQuotaRows;
        "pi" = herdrAgentQuotaRows;
      };
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
    # The plugin's refresh and settings keys. Written before the first run so
    # the plugin's own installer recognises them as already present and
    # leaves `keys.command` untouched during activation.
    keys.command = [
      {
        key = "prefix+shift+r";
        type = "plugin_action";
        command = "herdr-agent-quota.refresh";
        description = "refresh all agent quotas";
      }
      {
        key = "prefix+shift+q";
        type = "plugin_action";
        command = "herdr-agent-quota.open-settings";
        description = "open agent quota settings";
      }
    ];

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
in
{
  config = lib.mkIf (!host.is.iso) {
    # `pkgs.herdr` comes from the `modifiedPackages` overlay, which exposes the
    # llm-agents flake build with a stable-release override.
    home.packages = [
      herdrWorktree
      pkgs.herdr
      herdrLayout
      pkgs.herdr-agent-quota
    ];

    # Unlink layout plugin variants that a previous host configuration may
    # have left linked, so exactly one `workspace.created` handler remains.
    # Also unlink the retired usage plugins so no stale plugin state remains.
    home.activation.herdrLayoutPrune = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      for herdr_layout_id in ${
        lib.escapeShellArgs (
          [
            "usagebar"
            "space-usage"
          ]
          ++ (if noughtyLib.hostHasTag "cg" then [ "local.home-layout" ] else [ "local.work-layout" ])
        )
      }; do
        ${pkgs.herdr}/bin/herdr plugin unlink "$herdr_layout_id" || true
      done
    '';

    home.activation.herdrLayoutPlugin = lib.hm.dag.entryAfter [ "herdrLayoutPrune" ] ''
      ${pkgs.herdr}/bin/herdr plugin link \
        ${herdrLayout}/share/herdr/plugins/${herdrLayout.passthru.pluginDir} --enabled
    '';

    # Claude Code quota rides its StatusLine, which Home Manager owns here
    # without the plugin's managed wrapper, so Claude stays out of this
    # selection until that integration is decided. The `only` prefix keeps the
    # persisted subset from being read as "everything later".
    home.activation.herdrAgentQuotaPlugin = lib.hm.dag.entryAfter [ "herdrLayoutPlugin" ] ''
      ${pkgs.herdr}/bin/herdr plugin link \
        ${pkgs.herdr-agent-quota}/share/herdr/plugins/${pkgs.herdr-agent-quota.passthru.pluginDir} --enabled
    '';

    # The plugin's `--apply` rewrites three user-owned text files: Herdr's
    # config.toml and the Ghostty/kitty configs, all Home Manager store
    # symlinks here, plus the plugin's own state. Herdr's own config path is
    # redirected into a writable copy, and the terminal configs are hidden
    # behind a scratch XDG config root whose targets do not exist, so the
    # plugin's terminal step finds nothing to write. The sidebar rows and the
    # terminal maps are provisioned declaratively above.
    home.activation.herdrAgentQuotaConfigure = lib.hm.dag.entryAfter [ "herdrAgentQuotaPlugin" ] ''
      herdr_agent_quota_config_dir="$(${pkgs.herdr}/bin/herdr plugin config-dir herdr-agent-quota)" \
        || exit 2
      mkdir -p "$herdr_agent_quota_config_dir"
      printf 'only,%s\n' ${lib.escapeShellArg (lib.concatStringsSep "," herdrAgentQuotaAgents)} > "$herdr_agent_quota_config_dir/agents"

      herdr_agent_quota_state_dir="${config.home.homeDirectory}/.local/state/herdr/plugins/herdr-agent-quota"
      mkdir -p "$herdr_agent_quota_state_dir"

      herdr_agent_quota_scratch="$(mktemp -d)" || exit 2
      trap 'rm -rf "$herdr_agent_quota_scratch"' INT TERM EXIT

      # The copy feeds the plugin's Herdr config rewrite; the last generation
      # is already linked, so the copy matches the current declarative file.
      cp "${config.home.homeDirectory}/.config/herdr/config.toml" "$herdr_agent_quota_scratch/herdr-config.toml"

      PATH="${
        lib.makeBinPath [
          pkgs.herdr
          pkgs.coreutils
        ]
      }:$PATH" \
        HERDR_PLUGIN_CONFIG_DIR="$herdr_agent_quota_config_dir" \
        HERDR_PLUGIN_STATE_DIR="$herdr_agent_quota_state_dir" \
        HERDR_CONFIG_FILE="$herdr_agent_quota_scratch/herdr-config.toml" \
        XDG_CONFIG_HOME="$herdr_agent_quota_scratch" \
        ${pkgs.herdr-agent-quota}/bin/herdr-agent-quota configure --apply --agent-order default --agent ${lib.escapeShellArg (lib.concatStringsSep "," herdrAgentQuotaAgents)}
    '';

    home.activation.herdrReloadConfig = lib.hm.dag.entryAfter [ "herdrAgentQuotaConfigure" ] ''
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

    xdg.configFile."herdr/config.toml".source = lib.mkDefault (
      tomlFormat.generate "herdr-config.toml" settings
    );
  };
}
