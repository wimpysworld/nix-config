{ pkgs }:

pkgs.writeScriptBin "switch-all" ''
#!${pkgs.stdenv.shell}

if [ -e $HOME/Zero/nix-config ]; then
  sudo ${pkgs.coreutils-full}/bin/true
  pushd $HOME/Zero/nix-config
  sudo nixos-rebuild switch --flake .#
  ${pkgs.home-manager}/bin/home-manager switch -b backup --flake $HOME/Zero/nix-config
  popd
else
  ${pkgs.coreutils-full}/bin/echo "ERROR! No nix-config found in $HOME/Zero/nix-config"
fi
''
