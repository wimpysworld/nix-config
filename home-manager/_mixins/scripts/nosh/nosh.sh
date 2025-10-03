#!/usr/bin/env bash

# Exit on error, undefined variable, and error in pipes
set -euo pipefail

# Show help message
show_help() {
    cat << 'EOF'
Usage: nosh [--unstable] <package1> [package2] [package3] ...

Spawn an interactive shell with multiple packages from Nixpkgs available.

By default, uses the current stable Nixpkgs channel. Use --unstable
to force the use of nixos-unstable channel.

Examples:
  nosh git vim                  # Shell with git and vim from stable
  nosh --unstable git neovim    # Shell with packages from unstable
  nosh python3 pip poetry      # Development environment
  nosh nodejs npm yarn         # Node.js development setup

Options:
  --unstable         Use nixos-unstable channel instead of stable
  -h, --help         Show this help message

The shell spawned will be the one specified in the SHELL environment
variable, or your default shell if not set.
EOF
}

# Parse command line arguments
USE_UNSTABLE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --unstable)
            USE_UNSTABLE=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        -*)
            echo "Unknown option $1" >&2
            echo "Usage: $(basename "${0}") [--unstable] package1 package2 ..." >&2
            exit 1
            ;;
        *)
            break
            ;;
    esac
done

# Check if any arguments were provided
if [ $# -eq 0 ]; then
    echo "Usage: $(basename "${0}") [--unstable] package1 package2 ..." >&2
    exit 1
fi

# Determine which nixpkgs channel to use
if [ "$USE_UNSTABLE" = true ]; then
    NIXPKGS_CHANNEL="nixos-unstable"
else
    # Get current stable nixpkgs channel using shared norm command
    NIXPKGS_CHANNEL=$(norm 2>/dev/null || echo "nixos-unstable")
fi

# Build the command string starting with 'nix shell'
cmd="nom shell --impure"

# Loop through all arguments and prefix with nixpkgs#
for pkg in "$@"; do
    cmd+=" github:nixos/nixpkgs/${NIXPKGS_CHANNEL}#${pkg}"
done

export NIXPKGS_ALLOW_UNFREE=1
exec ${cmd}
