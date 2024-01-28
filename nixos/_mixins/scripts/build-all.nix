{ pkgs }:

pkgs.writeScriptBin "build-all" ''
#!${pkgs.stdenv.shell}

if [ -e $HOME/Zero/nix-config ]; then
  pushd $HOME/Zero/nix-config
  ${pkgs.home-manager}/bin/home-manager build --flake $HOME/Zero/nix-config
  ${pkgs.unstable.nixos-rebuild}/bin/nixos-rebuild build --flake $HOME/Zero/nix-config
  popd
else
  ${pkgs.coreutils-full}/bin/echo "ERROR! No nix-config found in $HOME/Zero/nix-config"
fi
''
