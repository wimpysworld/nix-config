{ pkgs }:

pkgs.writeScriptBin "build-iso-console" ''
#!${pkgs.stdenv.shell}

if [ -e $HOME/Zero/nix-config ]; then
  pushd $HOME/Zero/nix-config
  ${pkgs.unstable.nix}/bin/nix build .#nixosConfigurations.iso-console.config.system.build.isoImage
  ISO=$(head -n1 result/nix-support/hydra-build-products | cut -d'/' -f6)
  ${pkgs.coreutils-full}/bin/cp result/iso/$ISO $HOME/Quickemu/nixos-console/nixos.iso
  ${pkgs.coreutils-full}/bin/chown $USER: $HOME/Quickemu/nixos-console/nixos.iso
  ${pkgs.coreutils-full}/bin/chmod 644 $HOME/Quickemu/nixos-console/nixos.iso
  popd
else
  ${pkgs.coreutils-full}/bin/echo "ERROR! No nix-config found in $HOME/Zero/nix-config"
fi
''
