#!/usr/bin/env bash

# Exit on error, undefined variable, and error in pipes
set -euo pipefail

# Show help message
show_help() {
    cat << 'EOF'
Usage: halp <command> [args...]

Displays help output with syntax highlighting using bat.

Tries multiple help discovery methods:
  1. Standard help arguments (--help, -h, -help, help, --usage)
  2. Manual pages with bat formatting
  3. tldr/tlrc summaries as fallback

Examples:
  halp ls
  halp git status
  halp nix-shell
  halp --help        # Show this help

Options:
  -h, --help         Show this help message

Dependencies:
  bat                Required for syntax highlighting
  tldr/tlrc          Optional for command summaries
EOF
}

# Check for help arguments first
if [ $# -eq 0 ] || [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    show_help
    exit 0
fi

# Try different help arguments and return the first successful one
discover_help_arg() {
    local cmd="$1"
    # Try common help arguments in order of prevalence
    local help_args=("--help" "-h" "help" "--usage")

    for arg in "${help_args[@]}"; do
        # Try the help argument, suppress all output to check exit code only
        if "$cmd" "$arg" >/dev/null 2>&1; then
            echo "$arg"
            return 0
        fi
    done

    # No help argument found
    return 1
}

# Show manual page with bat formatting
show_man_page() {
    local cmd="$1"

    echo "'$cmd' does not support standard help arguments" >&2
    echo "Showing manual page instead:" >&2
    echo "" >&2
    man "$cmd" 2>/dev/null | col --no-backspaces --spaces | bat --language=man
}

# Show tldr summary
show_tldr_summary() {
    local cmd="$1"
    local tldr_cmd="$2"

    echo "'$cmd' does not support standard help arguments" >&2
    echo "Showing $tldr_cmd summary instead:" >&2
    echo "" >&2
    "$tldr_cmd" "$cmd" 2>&1
}

# Function to get help output
get_help_output() {
    local cmd="$1"
    shift
    local help_arg

    # Try to discover the help argument
    if help_arg=$(discover_help_arg "$cmd"); then
        # Execute with discovered help argument
        "$cmd" "$help_arg" 2>&1
    else
        # Fallback hierarchy: man -> tldr -> tlrc -> error
        if man "$cmd" >/dev/null 2>&1; then
            show_man_page "$cmd"
        elif command -v tlrc >/dev/null 2>&1; then
            show_tldr_summary "$cmd" "tlrc"
        elif command -v tldr >/dev/null 2>&1; then
            show_tldr_summary "$cmd" "tldr"
        else
            echo "'$cmd' does not support standard help arguments or man pages" >&2
            return 1
        fi
    fi
}

# Get the command and remaining arguments
cmd="$1"
shift

# Get help output and pipe through bat
get_help_output "$cmd" "$@" | bat --language=help
