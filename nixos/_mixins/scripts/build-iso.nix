{ pkgs }:

pkgs.writeScriptBin "build-iso" ''
#!${pkgs.stdenv.shell}
if [ -z $1 ]; then
  ${pkgs.coreutils-full}/bin/echo "Usage: build-iso <console|desktop>"
  exit 1
fi

if [ -e $HOME/Zero/nix-config ]; then
  pushd $HOME/Zero/nix-config
  ${pkgs.unstable.nix}/bin/nix build .#nixosConfigurations.iso-$1.config.system.build.isoImage
  ISO=$(${pkgs.coreutils-full}/bin/head -n1 result/nix-support/hydra-build-products | ${pkgs.coreutils-full}/bin/cut -d'/' -f6)
  ${pkgs.coreutils-full}/bin/mkdir -p $HOME/Quickemu/nixos-$1 2>/dev/null
  ${pkgs.coreutils-full}/bin/cp result/iso/$ISO $HOME/Quickemu/nixos-$1/nixos.iso
  ${pkgs.coreutils-full}/bin/chown $USER: $HOME/Quickemu/nixos-$1/nixos.iso
  ${pkgs.coreutils-full}/bin/chmod 644 $HOME/Quickemu/nixos-$1/nixos.iso
  popd
else
  ${pkgs.coreutils-full}/bin/echo "ERROR! No nix-config found in $HOME/Zero/nix-config"
fi
''
