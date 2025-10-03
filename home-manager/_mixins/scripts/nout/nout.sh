#!/usr/bin/env bash

# Exit on error, undefined variable, and error in pipes
set -euo pipefail

# Show help message
show_help() {
    cat << 'EOF'
Usage: nout [--unstable] <package> [args...]

Run a single package from Nixpkgs in an isolated environment.

By default, uses the current stable Nixpkgs channel. Use --unstable
to force the use of nixos-unstable channel.

Examples:
  nout hello                    # Run hello from stable channel
  nout --unstable hello         # Run hello from unstable channel
  nout git --version            # Run git with --version argument
  nout firefox --safe-mode      # Run firefox in safe mode

Options:
  --unstable         Use nixos-unstable channel instead of stable
  -h, --help         Show this help message

The script automatically detects the main executable name from the package
and falls back to heuristics if needed.
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
            echo "Usage: $(basename "${0}") [--unstable] package [args...]" >&2
            exit 1
            ;;
        *)
            break
            ;;
    esac
done

# Function to get the main program name from a Nixpkg
get_main_program() {
    local pkg="$1"
    local nixpkgs_channel="$2"

    echo "Determining main program for '$pkg' from '$nixpkgs_channel'..." >&2
    main_program=$(nix eval --impure github:nixos/nixpkgs/"$nixpkgs_channel"#"$pkg".meta.mainProgram --raw 2>/dev/null || echo "")

    if [ -n "$main_program" ] && [ "$main_program" != "null" ]; then
        echo "$main_program"
        return 0
    fi

    # Fallback 1: Try with lib.getExe
    exe_name=$(nix eval --impure --expr "
        let pkgs = (builtins.getFlake \"github:nixos/nixpkgs/$nixpkgs_channel\").legacyPackages.\${builtins.currentSystem};
        in builtins.baseNameOf (pkgs.lib.getExe pkgs.\"$pkg\")" --raw 2>/dev/null || echo "")

    if [ -n "$exe_name" ]; then
        echo "$exe_name"
        return 0
    fi

    # Fallback 2: Use package name as heuristic
    echo "$pkg"
}

# Check if any arguments were provided
if [ $# -eq 0 ]; then
    echo "Usage: $(basename "${0}") [--unstable] package [args...]" >&2
    exit 1
fi

# Determine which nixpkgs channel to use
if [ "$USE_UNSTABLE" = true ]; then
    NIXPKGS_CHANNEL="nixos-unstable"
else
    # Get current stable nixpkgs channel using shared norm command
    NIXPKGS_CHANNEL=$(norm 2>/dev/null || echo "nixos-unstable")
fi

# Get the actual executable name from the package
PACKAGE_NAME="${1}"
shift
NOUT_COMMAND=$(get_main_program "${PACKAGE_NAME}" "${NIXPKGS_CHANNEL}")

# Build the command string starting with 'nom shell'
cmd="nom shell --impure github:nixos/nixpkgs/${NIXPKGS_CHANNEL}#${PACKAGE_NAME} --command ${NOUT_COMMAND}"

# Add remaining arguments if any
if [ $# -gt 0 ]; then
    cmd="${cmd} $*"
fi

export NIXPKGS_ALLOW_UNFREE=1
exec ${cmd}
