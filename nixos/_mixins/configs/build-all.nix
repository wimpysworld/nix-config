{ pkgs }:

pkgs.writeScriptBin "build-all" ''
#!${pkgs.stdenv.shell}

if [ -e $HOME/Zero/nix-config ]; then
  pushd $HOME/Zero/nix-config
  nixos-rebuild build --flake .# -L
  ${pkgs.home-manager}/bin/home-manager build --flake $HOME/Zero/nix-config -L
  popd
else
  ${pkgs.coreutils-full}/bin/echo "ERROR! No nix-config found in $HOME/Zero/nix-config"
fi
''
