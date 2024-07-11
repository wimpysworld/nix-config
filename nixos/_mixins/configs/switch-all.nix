{ pkgs }:

pkgs.writeScriptBin "switch-all" ''
  #!${pkgs.stdenv.shell}

  if [ -e $HOME/Zero/nix-config ]; then
    all_cores=$(${pkgs.coreutils-full}/bin/nproc)
    build_cores=$(printf "%.0f" $(echo "$all_cores * 0.75" | ${pkgs.bc}/bin/bc))
    echo "Switching NixOS with $build_cores cores"
    ${pkgs.nh}/bin/nh os switch ~/Zero/nix-config/ -- --cores $build_cores
    echo "Switching Home Manager with $build_cores cores"
    ${pkgs.nh}/bin/nh home switch --backup-extension ~/Zero/nix-config/ -- --cores $build_cores
  else
    ${pkgs.coreutils-full}/bin/echo "ERROR! No nix-config found in $HOME/Zero/nix-config"
  fi
''
