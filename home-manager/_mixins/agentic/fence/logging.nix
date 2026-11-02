# Shared per-launch logging and working-directory helper for the fenced agent
# wrappers.
#
# Sourced after `wayland-bridge.nix` so `fence_args` is already declared as a
# bash array. The helper sets up a private log directory under
# `${XDG_STATE_HOME:-$HOME/.local/state}/fence`, picks a per-launch filename
# of the form `<agent>-<timestamp>-<pid>.log`, refreshes a
# `<agent>-current.log` symlink, and appends `-m --fence-log-file <file>` to
# `fence_args`. It also prepares an empty launch working directory at
# `${XDG_STATE_HOME:-$HOME/.local/state}/fence/empty-cwd` so Fence's mandatory
# workspace-scoped dangerous-file and directory denies (`.git/hooks`,
# `.git/config`, `.mcp.json`, `.vscode`, `.idea`) apply only to that empty
# directory, then restores the caller's original working directory inside
# `fence-direnv-exec` before running `direnv exec`. The agent name is taken
# from the wrapper-local variable `fence_log_agent`; only literal
# `claude|codex|moltis|opencode|pi` should be set.
#
# Permissions: the directory is created 0700; Fence opens the file 0600 via
# the flag path, so the helper deliberately does not pre-create the file.
{ pkgs }:

let
  fenceDirenvBashEnv = pkgs.writeText "fence-direnv-bash-env" ''
    eval "$(BASH_ENV= ${pkgs.lib.getExe pkgs.direnv} export bash)"
  '';

  # Load the project devShell inside Fence. Two separate faults break a bare
  # `direnv exec` in the sandbox, and both must be fixed or the devShell is
  # lost entirely.
  #
  # First, Fence masks /run/current-system/sw/bin, so nix-direnv's `has
  # sha1sum` test fails. With no hash program it computes an empty cache
  # suffix and looks for `.direnv/flake-profile` rather than the real
  # `.direnv/flake-profile-<sha1>`. It finds nothing, declares the cache
  # invalid, and falls back to `nix`, which Fence masks too, so `direnv exec`
  # exits 125. Putting coreutils on PATH restores the hash program and the
  # cached shell loads.
  #
  # Second, the host DIRENV_* variables leak into the sandbox. direnv then
  # treats the environment as already applied and exports nothing, while the
  # sandbox PATH never had the devShell entries. Clearing them forces a real
  # load.
  fenceDirenvLauncher = pkgs.writeShellApplication {
    name = "fence-direnv-exec";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.direnv
    ];
    text = ''
      if [[ -n "''${FENCE_LAUNCH_PWD:-}" ]]; then
        cd -- "$FENCE_LAUNCH_PWD"
        unset FENCE_LAUNCH_PWD
      fi
      unset DIRENV_DIFF DIRENV_DIR DIRENV_FILE DIRENV_IN_ENVRC DIRENV_WATCHES
      exec direnv exec "$PWD" env "BASH_ENV=${fenceDirenvBashEnv}" "$@"
    '';
  };
in
{
  runtimeInputs = [
    pkgs.coreutils
    pkgs.direnv
    pkgs.findutils
  ];

  setupShell = ''
    setup_fence_logging() {
      local fence_log_dir
      local fence_log_stamp
      local fence_log_file
      local agent

      agent="''${fence_log_agent:-agent}"
      case "$agent" in
        claude | codex | moltis | opencode | pi | agent) ;;
        *)
          agent="agent"
          ;;
      esac

      fence_log_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/fence"
      mkdir -p -- "$fence_log_dir"
      chmod 700 -- "$fence_log_dir"

      fence_log_stamp="$(date -u +%Y%m%dT%H%M%SZ)"
      fence_log_file="$fence_log_dir/$agent-$fence_log_stamp-$$.log"

      ln -sfn -- "$fence_log_file" "$fence_log_dir/$agent-current.log"

      fence_args+=(-m --fence-log-file "$fence_log_file")
    }

    setup_fence_empty_cwd() {
      local state_base_dir
      local fence_state_dir
      local current_uid
      local owner_uid

      fence_launch_pwd="$(pwd -P)"

      state_base_dir="''${XDG_STATE_HOME:-$HOME/.local/state}"
      install -d -m 0700 -- "$state_base_dir"
      if [[ -L "$state_base_dir" || ! -d "$state_base_dir" ]]; then
        echo "fence empty cwd: $state_base_dir must be a real directory" >&2
        return 1
      fi
      state_base_dir="$(realpath -e -- "$state_base_dir")"

      fence_state_dir="$state_base_dir/fence"
      if [[ -L "$fence_state_dir" ]]; then
        echo "fence empty cwd: $fence_state_dir must not be a symlink" >&2
        return 1
      fi
      install -d -m 0700 -- "$fence_state_dir"

      fence_empty_cwd="$fence_state_dir/empty-cwd"
      if [[ -L "$fence_empty_cwd" ]]; then
        echo "fence empty cwd: $fence_empty_cwd must not be a symlink" >&2
        return 1
      fi
      if [[ -e "$fence_empty_cwd" && ! -d "$fence_empty_cwd" ]]; then
        echo "fence empty cwd: $fence_empty_cwd must be a directory" >&2
        return 1
      fi
      install -d -m 0700 -- "$fence_empty_cwd"

      current_uid="$(id -u)"
      owner_uid="$(stat -c %u -- "$fence_empty_cwd" 2>/dev/null || stat -f %u -- "$fence_empty_cwd")"
      if [[ "$owner_uid" != "$current_uid" ]]; then
        echo "fence empty cwd: $fence_empty_cwd is not owned by the current user" >&2
        return 1
      fi

      chmod 0700 -- "$fence_empty_cwd"
      find "$fence_empty_cwd" -mindepth 1 -delete

      fence_env+=("FENCE_LAUNCH_PWD=$fence_launch_pwd")
    }

    setup_fence_logging
    setup_fence_empty_cwd

    fence_direnv=(
      ${pkgs.lib.getExe fenceDirenvLauncher}
    )
  '';
}
