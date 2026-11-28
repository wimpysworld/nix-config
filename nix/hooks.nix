# Managed by Tailor: nix/hooks.nix
{ pkgs, ... }:
''
  tailor_nixos_drivers() {
    [ "''${TAILOR_NIXOS_DRIVERS-}" != 0 ] || return 1
    [ -r /etc/os-release ] || return 1
    local line
    while IFS= read -r line; do
      case "$line" in
        ID=nixos|ID=\"nixos\"|ID=\'nixos\') return 0 ;;
      esac
    done < /etc/os-release
    return 1
  }
  tailor_prepend_path() {
    local name="$1" rest="$2:''${!1-}" part result=""
    while [ -n "$rest" ]; do
      part="''${rest%%:*}"
      if [ "$rest" = "$part" ]; then rest=""; else rest="''${rest#*:}"; fi
      [ -n "$part" ] || continue
      case ":$result:" in *":$part:"*) continue ;; esac
      result="''${result:+$result:}$part"
    done
    printf -v "$name" '%s' "$result"
    export "$name"
  }
''
+ builtins.concatStringsSep "\n" [
  (if builtins.pathExists ./hooks/go.nix then import ./hooks/go.nix { inherit pkgs; } else "")
  (
    if builtins.pathExists ./hooks/go-ffmpeg-statigo.nix then
      import ./hooks/go-ffmpeg-statigo.nix { inherit pkgs; }
    else
      ""
  )
  (
    if builtins.pathExists ./hooks/go-ebitengine.nix then
      import ./hooks/go-ebitengine.nix { inherit pkgs; }
    else
      ""
  )
  (if builtins.pathExists ./hooks/core.nix then import ./hooks/core.nix { inherit pkgs; } else "")
]
