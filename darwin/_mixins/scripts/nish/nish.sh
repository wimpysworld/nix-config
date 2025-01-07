#!/usr/bin/env bash

# Exit on error, undefined variable, and error in pipes
set -euo pipefail

# Check if any arguments were provided
if [ $# -eq 0 ]; then
    echo "Usage: $(basename "${0}") package1 package2 ..." >&2
    exit 1
fi

# Build the command string starting with 'nix shell'
cmd="nix shell"

# Loop through all arguments and prefix with nixpkgs#
for pkg in "$@"; do
    cmd+=" nixpkgs#${pkg}"
done

# Execute the command
echo "Executing: ${cmd}" >&2
exec ${cmd}
