#!/usr/bin/env bash
if [ -z "${1}" ]; then
    echo "Usage: build-iso <console|gnome|mate|pantheon>"
    exit 1
fi

if [ -e "${HOME}/Zero/nix-config" ]; then
    all_cores=$(nproc)
    build_cores=$(printf "%.0f" "$(echo "$all_cores * 0.75" | bc)")
    { pushd "${HOME}/Zero/nix-config" > /dev/null; } 2>&1 || exit 1
    echo "Building ISO (${1}) with ${build_cores} cores"
    nom build .#nixosConfigurations.iso-"${1}".config.system.build.isoImage --cores "${build_cores}"
    ISO=$(head -n1 result/nix-support/hydra-build-products | cut -d'/' -f6)
    mkdir -p "${HOME}/Quickemu/nixos-${1}" 2>/dev/null
    cp "result/iso/${ISO}" "${HOME}/Quickemu/nixos-${1}/nixos.iso"
    chown "${USER}": "${HOME}/Quickemu/nixos-${1}/nixos.iso"
    chmod 644 "${HOME}/Quickemu/nixos-${1}/nixos.iso"
    { popd > /dev/null; } 2>&1 || exit 1
else
    echo "ERROR! No nix-config found in ${HOME}/Zero/nix-config"
fi
