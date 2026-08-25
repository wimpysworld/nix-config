{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  # Herdr reads its configuration from `~/.config/herdr/config.toml`.
  tomlFormat = pkgs.formats.toml { };
  # Herdr uses a single worktree root for every repository and appends
  # `<repo-name>/<branch>` to it. The root sits under `~/Chainguard` because
  # Fence permits writes there, and it keeps work worktrees beside the clones
  # they come from. The path is absolute because herdr's own tilde expansion is
  # not something this module should depend on.
  worktreeRoot = "${config.home.homeDirectory}/Chainguard/_worktrees";
  settings = {
    # Herdr shows the onboarding screen until it writes `onboarding = false`
    # back to the configuration file. Nix renders that file as a read-only
    # symlink into the store, so herdr can never record completion itself. The
    # flag is pre-set here to skip onboarding on every start.
    onboarding = false;
    # Use the host terminal palette for the Herdr interface.
    theme.name = "terminal";
    keys.command = [
      {
        key = "prefix+u";
        type = "plugin_action";
        command = "usagebar.open-limits";
        description = "Agent Usage: open limits pane";
      }
      {
        key = "prefix+m";
        type = "plugin_action";
        command = "usagebar.refresh";
        description = "Agent Usage: refresh sidebar meters";
      }
    ];
    ui.sidebar.agents = {
      row_gap = 0;
      rows = [
        [
          "state_icon"
          "$title"
        ]
        [
          "$provider"
          "$limit"
        ]
        [ "$context" ]
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
      [ "$usage" ]
    ];
    ui.status_indicators = "symbols";
    ui.show_agent_labels_on_pane_borders = true;
    ui.sound.enabled = false;
    ui.toast.delivery = "herdr";
    experimental.kitty_graphics = true;
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
    # llm-agents flake build directly.
    home.packages = [
      herdrWorktree
      pkgs.herdr
      pkgs.herdr-agent-usage
      pkgs.herdr-pc-ram-and-cpu-usage-overlay
      pkgs.herdr-work-layout
    ];

    home.activation.herdrAgentUsagePlugin = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      ${pkgs.herdr}/bin/herdr plugin link \
        ${pkgs.herdr-agent-usage}/share/herdr/plugins/usagebar --enabled
    '';

    home.activation.herdrPcRamAndCpuUsageOverlayPlugin =
      lib.hm.dag.entryAfter [ "herdrAgentUsagePlugin" ]
        ''
          ${pkgs.herdr}/bin/herdr plugin link \
            ${pkgs.herdr-pc-ram-and-cpu-usage-overlay}/share/herdr/plugins/space-usage --enabled
        '';

    home.activation.herdrWorkLayoutPlugin =
      lib.hm.dag.entryAfter [ "herdrPcRamAndCpuUsageOverlayPlugin" ]
        ''
          ${pkgs.herdr}/bin/herdr plugin link \
            ${pkgs.herdr-work-layout}/share/herdr/plugins/work-layout --enabled
        '';

    home.activation.herdrReloadConfig = lib.hm.dag.entryAfter [ "herdrWorkLayoutPlugin" ] ''
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
