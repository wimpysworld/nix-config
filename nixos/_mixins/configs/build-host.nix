{ pkgs }:

pkgs.writeScriptBin "build-host" ''
#!${pkgs.stdenv.shell}

if [ -e $HOME/Zero/nix-config ]; then
  pushd $HOME/Zero/nix-config
  nixos-rebuild build --flake .# -L
  popd
else
  ${pkgs.coreutils-full}/bin/echo "ERROR! No nix-config found in $HOME/Zero/nix-config"
fi
''
