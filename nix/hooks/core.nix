# Managed by Tailor: nix/hooks/core.nix
{ pkgs, ... }:
pkgs.lib.optionalString pkgs.stdenv.hostPlatform.isLinux ''
  if tailor_nixos_drivers; then
    if [ -d /run/opengl-driver/lib ]; then
      tailor_prepend_path LD_LIBRARY_PATH /run/opengl-driver/lib
    fi
    if [ "''${VK_DRIVER_FILES+x}" != x ] && [ -d /run/opengl-driver/share/vulkan/icd.d ]; then
      tailor_icds=""
      while IFS= read -r tailor_icd; do
        if [ -r "$tailor_icd" ]; then
          tailor_icds="''${tailor_icds:+$tailor_icds:}$tailor_icd"
        fi
      done < <(find -L /run/opengl-driver/share/vulkan/icd.d -type f -name '*.json' 2>/dev/null | LC_ALL=C sort)
      if [ -n "$tailor_icds" ]; then export VK_DRIVER_FILES="$tailor_icds"; fi
      unset tailor_icds tailor_icd
    fi
  fi
''
