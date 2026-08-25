{ pkgs }:

{
  runtimeInputs = [ pkgs.coreutils ];
  captureShell = ''
    capture_fence_agent_share_runtime_dir() {
      local current_uid
      local owner_uid

      fence_agent_share_host_runtime_dir="''${XDG_RUNTIME_DIR:-}"
      if [[ -z "$fence_agent_share_host_runtime_dir" ]]; then
        echo "fence agent share: XDG_RUNTIME_DIR is not set" >&2
        return 1
      fi
      if [[ "$fence_agent_share_host_runtime_dir" != /* ]]; then
        echo "fence agent share: XDG_RUNTIME_DIR must be an absolute path" >&2
        return 1
      fi
      if [[ -L "$fence_agent_share_host_runtime_dir" || ! -d "$fence_agent_share_host_runtime_dir" ]]; then
        echo "fence agent share: XDG_RUNTIME_DIR must be a real directory" >&2
        return 1
      fi

      current_uid="$(id -u)"
      owner_uid="$(stat -c %u -- "$fence_agent_share_host_runtime_dir")"
      if [[ "$owner_uid" != "$current_uid" ]]; then
        echo "fence agent share: XDG_RUNTIME_DIR is not owned by the current user" >&2
        return 1
      fi

      fence_agent_share_host_runtime_dir="$(realpath -e -- "$fence_agent_share_host_runtime_dir")"
    }

    capture_fence_agent_share_runtime_dir
  '';
  setupShell = ''
    setup_fence_agent_share() {
      local share_path
      local resolved_share_path
      local current_uid
      local owner_uid

      share_path="$fence_agent_share_host_runtime_dir/fence-share"

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
