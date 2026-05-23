# Shared per-launch logging helper for the fenced agent wrappers.
#
# Sourced after `wayland-bridge.nix` so `fence_args` is already declared as a
# bash array. The helper sets up a private log directory under
# `${XDG_STATE_HOME:-$HOME/.local/state}/fence`, picks a per-launch filename
# of the form `<agent>-<timestamp>-<pid>.log`, refreshes a
# `<agent>-current.log` symlink, and appends `-m --fence-log-file <file>` to
# `fence_args`. The agent name is taken from the wrapper-local variable
# `fence_log_agent`; only literal `claude|codex|opencode|pi` should be set.
#
# Permissions: the directory is created 0700; Fence opens the file 0600 via
# the flag path, so the helper deliberately does not pre-create the file.
{ pkgs }:

{
  runtimeInputs = [ pkgs.coreutils ];

  setupShell = ''
    setup_fence_logging() {
      local fence_log_dir
      local fence_log_stamp
      local fence_log_file
      local agent

      agent="''${fence_log_agent:-agent}"
      case "$agent" in
        claude | codex | opencode | pi | agent) ;;
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

    setup_fence_logging
  '';
}
