#!/usr/bin/env bash

# Exit on error, undefined variable, and error in pipes
set -euo pipefail

# Check if any arguments were provided
if [ $# -ne 1 ]; then
    echo "Usage: $(basename "${0}") <executable>" >&2
    echo "Shows the Nix store path for an executable in your PATH" >&2
    exit 1
fi

EXECUTABLE="${1}"

# Find the executable in PATH
EXEC_PATH=$(which "${EXECUTABLE}" 2>/dev/null)
if [ -z "${EXEC_PATH}" ]; then
    echo "Error: '${EXECUTABLE}' not found in PATH" >&2
    exit 1
fi

# Function to extract store path from any path
extract_store_path() {
    local path="$1"
    # Extract the store path (everything up to the first / after /nix/store/hash-name)
    echo "$path" | sed -n 's|^\(/nix/store/[^/]*\).*|\1|p'
}

# Function to resolve through all symlinks and wrappers
resolve_ultimate_store_path() {
    local current_path="$1"
    local seen_paths=()

    while [ -n "$current_path" ]; do
        # Check if we've seen this path before (avoid infinite loops)
        for seen in "${seen_paths[@]}"; do
            if [ "$current_path" = "$seen" ]; then
                break 2
            fi
        done
        seen_paths+=("$current_path")

        # If it's in /nix/store, we found our target
        if [[ "$current_path" =~ ^/nix/store/ ]]; then
            extract_store_path "$current_path"
            return 0
        fi

        # If it's a symlink, follow it
        if [ -L "$current_path" ]; then
            current_path=$(readlink "$current_path")
            # Handle relative symlinks
            if [[ ! "$current_path" =~ ^/ ]]; then
                current_path="$(dirname "${seen_paths[-1]}")/$current_path"
            fi
        # If it's a wrapper script, try to extract the wrapped path
        elif [ -f "$current_path" ] && [ -r "$current_path" ]; then
            # Look for common wrapper patterns
            wrapped_path=$(grep -oE '/nix/store/[^[:space:]"'\'']+' "$current_path" 2>/dev/null | head -1)
            if [ -n "$wrapped_path" ]; then
                current_path="$wrapped_path"
            else
                break
            fi
        else
            break
        fi
    done

    # If we couldn't find a store path, return the original
    echo "Warning: Could not resolve to /nix/store path" >&2
    echo "$1"
    return 1
}

# Resolve the store path
STORE_PATH=$(resolve_ultimate_store_path "$EXEC_PATH")
echo "$STORE_PATH"
