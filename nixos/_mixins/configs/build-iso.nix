{ pkgs }:

pkgs.writeScriptBin "build-iso" ''
#!${pkgs.stdenv.shell}
if [ -z $1 ]; then
  ${pkgs.coreutils-full}/bin/echo "Usage: build-iso <console|gnome|mate|pantheon>"
  exit 1
fi

if [ -e $HOME/Zero/nix-config ]; then
  all_cores=$(${pkgs.coreutils-full}/bin/nproc)
  build_cores=$(printf "%.0f" $(echo "$all_cores * 0.75" | ${pkgs.bc}/bin/bc))
  pushd $HOME/Zero/nix-config 2>&1 > /dev/null
  echo "Building ISO ($1) with $build_cores cores"
  ${pkgs.nix-output-monitor}/bin/nom build .#nixosConfigurations.iso-$1.config.system.build.isoImage --cores $build_cores
  ISO=$(${pkgs.coreutils-full}/bin/head -n1 result/nix-support/hydra-build-products | ${pkgs.coreutils-full}/bin/cut -d'/' -f6)
  ${pkgs.coreutils-full}/bin/mkdir -p $HOME/Quickemu/nixos-$1 2>/dev/null
  ${pkgs.coreutils-full}/bin/cp result/iso/$ISO $HOME/Quickemu/nixos-$1/nixos.iso
  ${pkgs.coreutils-full}/bin/chown $USER: $HOME/Quickemu/nixos-$1/nixos.iso
  ${pkgs.coreutils-full}/bin/chmod 644 $HOME/Quickemu/nixos-$1/nixos.iso
  popd 2>&1 > /dev/null
else
  ${pkgs.coreutils-full}/bin/echo "ERROR! No nix-config found in $HOME/Zero/nix-config"
fi
''
