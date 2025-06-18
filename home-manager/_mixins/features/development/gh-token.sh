#!/usr/bin/env bash
set -euo pipefail
VERSION="0.1.0"

if [[ "${BASH_VERSINFO[0]}" -lt 4 || ( "${BASH_VERSINFO[0]}" -eq 4 && "${BASH_VERSINFO[1]}" -lt 4 ) ]]; then
    echo "✘ ERROR! This script requires Bash version 4.4 or higher." >&2
    exit 1
fi

_require_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "✘ ERROR! Required command '$1' not found in PATH." >&2
        exit 1
    fi
}

_update_gh_token() {
    _require_command "gh"

    if [[ "$(gh config get git_protocol)" != "https" ]]; then
        # gh stores config in ~/.config/gh/config.yml on Linux/macOS
        local gh_config_file="${HOME}/.config/gh/config.yml"

        # Check if the config file exists and is writable
        if [[ -f "$gh_config_file" && -w "$gh_config_file" ]]; then
            echo "🖬 Configuring gh git_protocol to use https..."
            gh config set git_protocol https
        else
            echo "⬢ WARNING! gh git_protocol is not 'https', but config is not writable." >&2
        fi
    fi

    # Capture status output and exit code
    local auth_status
    auth_status=$(gh auth status 2>&1)
    local status_code=$?

    if [[ $status_code -eq 0 ]]; then
        echo "⚉ GitHub is authenticated"
    elif [[ "$auth_status" == *"SAML"* ]]; then
        echo "♺ GitHub SAML session may have expired. Attempting to refresh..."
        # Refresh for github.com hostname specifically
        if ! gh auth refresh --hostname github.com; then
            echo "✘ ERROR! Failed to refresh GitHub token." >&2
            # Unset variables to ensure a clean state
            unset GH_TOKEN GITHUB_TOKEN GHORG_GITHUB_TOKEN
            return 1
        fi
        echo "✔ GitHub token refreshed."
    else
        echo "✘ ERROR! GitHub not authenticated. Please run 'gh auth login -p https'." >&2
        unset GH_TOKEN GITHUB_TOKEN GHORG_GITHUB_TOKEN
        return 1
    fi

    # If we get here, authentication is successful (or was just refreshed).
    # Export the token for the current shell and any child processes.
    local token
    token=$(gh auth token)
    if [[ -n "$token" ]]; then
        export GH_TOKEN="$token"
        export GITHUB_TOKEN="$token"
        export GHORG_GITHUB_TOKEN="$token"
    else
        echo "✘ ERROR! Failed to retrieve GitHub token after authentication." >&2
        unset GH_TOKEN GITHUB_TOKEN GHORG_GITHUB_TOKEN
        return 1
    fi
}

# --- Execution-Specific Functions ---

usage() {
    cat <<EOF
$(basename "${0}") v${VERSION}
Manages and refreshes the GitHub CLI token.

This script can be executed directly to perform specific actions,
or sourced (e.g., in .bashrc) to check and export the GitHub token.

USAGE (when executed):
    $(basename "${0}") [COMMAND]

COMMANDS:
    --login     Initiates the GitHub authentication process using HTTPS.
    --logout    Logs out from the github.com account.
    --refresh   Checks authentication and refreshes the token if needed.
    --status    Shows the current GitHub authentication status.
    --test      Tests the SSH connection to GitHub.
    --unset     Outputs the command to unset the token variables.
    --help      Show this help message.
    --version   Show version and exit.

USAGE (when sourced):
    source $(basename "${0}")
    (Checks and exports GITHUB_TOKEN into the current shell)
EOF
}

main() {
    # No arguments are expected in sourced mode, so we only parse when executed.
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --login)
                _require_command "gh"
                echo "⮊ Logging in to github.com..."
                gh auth login -p https
                shift;;
            --logout)
                _require_command "gh"
                echo "⮈ Logging out from github.com..."
                gh auth logout --hostname github.com
                shift;;
            --refresh)
                _update_gh_token
                shift;;
            --status)
                _require_command "gh"
                echo "🛈 Checking GitHub authentication status..."
                gh auth status
                shift;;
            --test)
                _require_command "ssh"
                echo "⮀ Testing SSH connection to github.com..."
                # ssh -T may exit with 1 on success, so we can't check the exit code.
                ssh -T github.com || true
                shift;;
            --unset)
                # Detect the parent shell name to provide the correct command
                local ppid
                ppid=$(ps -o ppid= -p $$)
                local parent_shell
                parent_shell=$(basename "$(ps -p "$ppid" -o comm=)")
                echo "🖹 Copy and paste the command for your $parent_shell to unset the tokens"
                echo
                case "$parent_shell" in
                    bash|zsh) echo "unset GH_TOKEN GITHUB_TOKEN GHORG_GITHUB_TOKEN";;
                    fish) echo "set -e GH_TOKEN; set -e GITHUB_TOKEN; set -e GHORG_GITHUB_TOKEN";;
                    *) echo "⬢ WARNING! $parent_shell is unsupported. Please manually unset the variables.";;
                esac
                shift;;
            --help)
                usage
                exit 0;;
            --version)
                echo "${VERSION}"
                exit 0;;
            *)
                echo "✘ ERROR! Unknown command: $1" >&2
                usage
                exit 1;;
        esac
    done
}

# Sourcing vs. Execution

# If BASH_SOURCE[0] is the same as $0, the script is being executed.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # --- EXECUTION PATH ---
    if [[ $# -eq 0 ]]; then
        # Default action when executed with no args is to show help.
        usage
        exit 1
    fi
    main "$@"
else
    # --- SOURCING PATH ---
    _update_gh_token
    # Clean up the functions from the shell environment after sourcing.
    unset -f _require_command _update_gh_token main usage
fi
