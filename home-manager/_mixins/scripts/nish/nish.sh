#!/usr/bin/env bash

# Exit on error, undefined variable, and error in pipes
set -euo pipefail

# Check if any arguments were provided
if [ $# -eq 0 ]; then
  echo "Usage: $(basename "${0}") package1 package2 ..." >&2
  exit 1
fi

case "$(uname -s)" in
  Linux) platform="nixos";;
  Darwin) platform="darwin";;
esac

# Build the command string starting with 'nom shell'
cmd="nix shell"

# Loop through all arguments and prefix
for pkg in "$@"; do
  cmd+=" .#${platform}Configurations.$(hostname -s).pkgs.${pkg}"
done

# Execute the command
echo "Executing: ${cmd}" >&2
exec ${cmd} -L
