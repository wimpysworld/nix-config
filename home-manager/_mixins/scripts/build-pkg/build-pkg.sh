#!/usr/bin/env bash

function usage() {
  echo "Usage: ${0} <pkg>"
  exit 1
}

# Validate input argument
if [ -z "${1}" ]; then
  usage
fi

# Get the number of processing units
case "$(uname -s)" in
  Linux)  
    platform="nixos"
    all_cores=$(nproc);;
  Darwin)
    platform="darwin"
    all_cores=$(sysctl -n hw.logicalcpu);;
esac
# Calculate 75% of the number of processing units
build_cores=$(printf "%.0f" "$(echo "${all_cores} * 0.75" | bc)")

echo "Building $1 󰏗 with ${build_cores} cores"
nix build .#"${platform}"Configurations."$(hostname -s)".pkgs."${1}" --cores "${build_cores}" -L
