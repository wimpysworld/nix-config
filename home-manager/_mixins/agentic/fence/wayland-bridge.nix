{ pkgs }:

{
  runtimeInputs = [
    pkgs.coreutils
  ];

  setupShell = ''
    fence_args=()
    fence_env=()
    fence_wayland_runtime_dir=""

    cleanup_fence_wayland_bridge() {
      if [[ -n "$fence_wayland_runtime_dir" ]]; then
        rm -rf -- "$fence_wayland_runtime_dir"
      fi
    }

    setup_fence_wayland_bridge() {
      local host_runtime_dir
      local host_wayland_socket
      local wayland_bridge_socket
      local wayland_display
      local wayland_display_name

      wayland_display="''${WAYLAND_DISPLAY:-}"
      host_runtime_dir="''${XDG_RUNTIME_DIR:-}"
      if [[ -z "$wayland_display" || -z "$host_runtime_dir" ]]; then
        return 0
      fi

      case "$wayland_display" in
        /*)
          host_wayland_socket="$wayland_display"
          wayland_display_name="$(basename "$wayland_display")"
          ;;
        */*)
          return 0
          ;;
        *)
          host_wayland_socket="$host_runtime_dir/$wayland_display"
          wayland_display_name="$wayland_display"
          if [[ ! -S "$host_wayland_socket" && -S "/run/user/$(id -u)/$wayland_display" ]]; then
            host_wayland_socket="/run/user/$(id -u)/$wayland_display"
          fi
          ;;
      esac

      if [[ -z "$wayland_display_name" || ! -S "$host_wayland_socket" ]]; then
        return 0
      fi

      fence_wayland_runtime_dir="$(mktemp -d "''${TMPDIR:-/tmp}/fence-wayland-runtime.XXXXXX")"
      chmod 700 "$fence_wayland_runtime_dir"
      wayland_bridge_socket="$fence_wayland_runtime_dir/$wayland_display_name"

      ln -s "$host_wayland_socket" "$wayland_bridge_socket"
      if [[ ! -L "$wayland_bridge_socket" ]]; then
        cleanup_fence_wayland_bridge
        fence_wayland_runtime_dir=""
        return 0
      fi

      export XDG_RUNTIME_DIR="$fence_wayland_runtime_dir"
      export WAYLAND_DISPLAY="$wayland_display_name"
      fence_args+=(--expose-host-path-rw "$fence_wayland_runtime_dir")
      fence_args+=(--expose-host-path-rw "$host_wayland_socket")
      fence_env+=(
        "XDG_RUNTIME_DIR=$fence_wayland_runtime_dir"
        "WAYLAND_DISPLAY=$wayland_display_name"
      )
      trap cleanup_fence_wayland_bridge EXIT
    }

    setup_fence_wayland_bridge
  '';
}
