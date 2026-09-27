{ lib, pkgs }:

{
  # The Wayland bridge replaces XDG_RUNTIME_DIR, and systemd-run finds the
  # user manager through it, so keep the host value. Run before the bridge.
  captureShell = ''
    fence_host_runtime_dir="''${XDG_RUNTIME_DIR:-}"
  '';

  # Cap the whole fenced session, because systemd-run cannot reach the user
  # manager from inside the sandbox. The probe uses the same properties, so a
  # failure falls back to an uncapped launch before the agent starts. Prefix
  # the fence command with the fence_launch array.
  setupShell = ''
    fence_launch=()
    ${lib.optionalString pkgs.stdenv.hostPlatform.isLinux ''
      fence_memory_cap=(-p MemoryMax=75% -p MemorySwapMax=0)
      if XDG_RUNTIME_DIR="$fence_host_runtime_dir" systemd-run --user --scope -q "''${fence_memory_cap[@]}" true >/dev/null 2>&1; then
        fence_launch=(env "XDG_RUNTIME_DIR=$fence_host_runtime_dir" systemd-run --user --scope -q "''${fence_memory_cap[@]}" env "XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR")
      else
        echo "''${0##*/}: warning: systemd-run cannot reach the user manager, so the session runs without a memory cap" >&2
      fi
    ''}
  '';
}
