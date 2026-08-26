# Shared launch directory for fenced agents.
#
# The directory is exposed read-write into the sandbox and used as `TMPDIR`
# there, so an agent and the host can hand files to each other.
#
# It lives under `~/.cache`, not `$XDG_RUNTIME_DIR`. Fence rebuilds any mount
# boundary it has to cross: naming a path on a different device places a tmpfs
# at the first boundary and then rebinds only the named paths. `/run` is its own
# tmpfs on NixOS, so a single entry under it blanks the whole tree, taking
# `/run/current-system/sw/bin` and `/run/user/$UID/secrets.d` with it. `~/.cache`
# is on the same device as `/`, so nothing is rebuilt.
{ config, pkgs }:

let
  shareParentDir = config.xdg.cacheHome;
in
{
  runtimeInputs = [ pkgs.coreutils ];
  captureShell = ''
    capture_fence_agent_share_base_dir() {
      local current_uid
      local owner_uid

      fence_agent_share_host_base_dir=${pkgs.lib.escapeShellArg shareParentDir}

      install -d -m 0700 -- "$fence_agent_share_host_base_dir"

      if [[ -L "$fence_agent_share_host_base_dir" || ! -d "$fence_agent_share_host_base_dir" ]]; then
        echo "fence agent share: $fence_agent_share_host_base_dir must be a real directory" >&2
        return 1
      fi

      current_uid="$(id -u)"
      owner_uid="$(stat -c %u -- "$fence_agent_share_host_base_dir")"
      if [[ "$owner_uid" != "$current_uid" ]]; then
        echo "fence agent share: $fence_agent_share_host_base_dir is not owned by the current user" >&2
        return 1
      fi

      fence_agent_share_host_base_dir="$(realpath -e -- "$fence_agent_share_host_base_dir")"
    }

    capture_fence_agent_share_base_dir
  '';
  setupShell = ''
    setup_fence_agent_share() {
      local share_path
      local resolved_share_path
      local current_uid
      local owner_uid

      share_path="$fence_agent_share_host_base_dir/fence-share"

      if [[ -L "$share_path" ]]; then
        echo "fence agent share: $share_path must not be a symlink" >&2
        return 1
      fi
      if [[ -e "$share_path" && ! -d "$share_path" ]]; then
        echo "fence agent share: $share_path must be a directory" >&2
        return 1
      fi
      if [[ ! -e "$share_path" ]]; then
        install -d -m 0700 -- "$share_path"
      fi

      current_uid="$(id -u)"
      owner_uid="$(stat -c %u -- "$share_path")"
      if [[ "$owner_uid" != "$current_uid" ]]; then
        echo "fence agent share: $share_path is not owned by the current user" >&2
        return 1
      fi

      chmod 0700 -- "$share_path"
      resolved_share_path="$(realpath -e -- "$share_path")"
      if [[ "$resolved_share_path" != "$share_path" ]]; then
        echo "fence agent share: $share_path did not resolve to the expected path" >&2
        return 1
      fi

      fence_args+=(--expose-host-path-rw "$resolved_share_path")
      fence_env+=("TMPDIR=$resolved_share_path")
    }

    setup_fence_agent_share
  '';
}
