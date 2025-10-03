#!/usr/bin/env bash

# Shared stable channel detection for nout.sh, nosh.sh and nh search
# Returns the current NixOS stable channel (e.g., nixos-25.05)

# Exit on error, undefined variable, and error in pipes
set -euo pipefail

# Cache file for stable channel information
CACHE_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/noughty-linux-stable-channel"
CACHE_EXPIRY=604800  # 1 week in seconds (NixOS releases every 6 months)

# Function to get the current stable NixOS channel using git ls-remote
# Queries the nixpkgs repository to find the latest stable branch
# Caches result for 1 week to avoid repeated network calls
get_stable_nixpkgs() {
    local current_time
    local cache_time

    current_time=$(date +%s)

    # Check if cache exists and is still valid
    if [ -f "$CACHE_FILE" ]; then
        cache_time=$(stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0)
        if [ $((current_time - cache_time)) -lt $CACHE_EXPIRY ]; then
            cat "$CACHE_FILE"
            return 0
        fi
    fi

    # Query nixpkgs repository for release branches
    local stable_branches
    local latest_stable

    stable_branches=$(git ls-remote --heads https://github.com/NixOS/nixpkgs.git 2>/dev/null |
        grep -o 'refs/heads/nixos-[0-9][0-9]\.[0-9][0-9]$' |
        sed 's|refs/heads/||' |
        sort -V |
        tail -1 || echo "")

    if [ -n "$stable_branches" ]; then
        latest_stable="$stable_branches"
        # Create cache directory if it doesn't exist
        mkdir -p "$(dirname "$CACHE_FILE")"
        echo "$latest_stable" > "$CACHE_FILE"
        echo "$latest_stable"
        return 0
    fi

    # Fallback to unstable channel if git query fails
    # Note: Don't cache the fallback - we want to retry detection next time
    echo "nixos-unstable"
}

# If called directly, output the stable channel
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    get_stable_nixpkgs
fi
