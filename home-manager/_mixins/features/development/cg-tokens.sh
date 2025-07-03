#!/usr/bin/env bash
set -euo pipefail

if [[ "${BASH_VERSINFO[0]}" -lt 4 || ( "${BASH_VERSINFO[0]}" -eq 4 && "${BASH_VERSINFO[1]}" -lt 4 ) ]]; then
    echo "✘ ERROR! This script requires Bash version 4.4 or higher." >&2
    exit 1
fi

# Check for required commands
for cmd in chainctl jq date base64; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "✘ ERROR! Required command '$cmd' not found in PATH." >&2
        exit 1
    fi
done

AUDIENCES=(
    "https://console-api.enforce.dev"
    "apk.cgr.dev"
    "cgr.dev"
)
# Intelligently set default AUTH_MODE based on display server availability
AUTH_MODE=headless
if [[ "$(uname)" == "Darwin" ]] || [[ -n "${WAYLAND_DISPLAY:-}" || -n "${DISPLAY:-}" ]]; then
    AUTH_MODE=browser
fi
# Default operation mode
OPERATION=refresh
OPERATION_TITLE="⊚ Ensuring tokens are fresh..."
# Default refresh threshold; 30 mins
TTL_THRESHOLD_SEC=$((30 * 60))
VERSION="0.1.4"

usage() {
    cat <<EOF
$(basename "${0}") v${VERSION}
Refreshes Chainguard tokens if they are close to expiring.

USAGE:
    $(basename "${0}") [OPTIONS]

OPTIONS:
    --headless                Use headless authentication.
    --browser                 Use browser-based authentication.
    --ttl-threshold <minutes> Set token refresh threshold in minutes (default: 30, min: 5, max: 60).
    --logout                  Log out from all configured audiences.
    --help                    Show this help message and exit.
    --version                 Show version and exit.

NOTES:
    If no authentication mode is specified, the script automatically detects whether
    a display server (X11 or Wayland) is available or if running on macOS, and defaults
    to --browser mode if found, otherwise uses --headless mode.
EOF
}

# Get the OS-specific base directory for the Chainguard cache.
_get_cache_base_dir() {
    if [[ "$(uname)" == "Darwin" ]]; then
        echo "${HOME}/Library/Caches/chainguard"
    else
        echo "${HOME}/.cache/chainguard"
    fi
}

# Get TTL from a token file.
_get_ttl_from_file() {
    local audience="$1"
    local token_filename="$2"
    local ttl=0

    local cache_base_dir
    cache_base_dir=$(_get_cache_base_dir)

    # Sanitize the audience to create a safe directory name, just as 'chainctl' does.
    local safe_audience="${audience//\//-}"
    local token_file="${cache_base_dir}/${safe_audience}/${token_filename}"

    if [[ -f "$token_file" ]]; then
        local token_data
        token_data=$(cat "$token_file")
        local expiry_ts_str=""

        # Decode the JWT payload and extract the 'exp' (expiration time) claim.
        expiry_ts_str=$(echo "$token_data" | cut -d'.' -f2 | base64 -d 2>/dev/null | jq -r .exp 2>/dev/null)

        if [[ -n "$expiry_ts_str" && "$expiry_ts_str" != "null" && "$expiry_ts_str" =~ ^[0-9]+$ ]]; then
            ttl=$((expiry_ts_str - $(date "+%s")))
            # Ensure TTL is not negative
            if [[ $ttl -lt 0 ]]; then ttl=0; fi
        fi
    fi
    echo "$ttl"
}

# Get the token and refresh TTLs for a given audience.
# Outputs two space-separated values: <token_ttl> <refresh_ttl>
get_current_ttls() {
    local audience="$1"
    local token_ttl
    token_ttl=$(_get_ttl_from_file "$audience" "oidc-token")
    local refresh_ttl
    refresh_ttl=$(_get_ttl_from_file "$audience" "refresh-token")
    echo "$token_ttl $refresh_ttl"
}

logout_audience() {
    local audience="$1"
    if chainctl auth logout --audience="$audience" --output=none >/dev/null 2>&1; then
        echo "✔ Logged out: $audience"
    else
        echo "⚑ NOTE! $audience failed to log out. This is not critical."
    fi
}

refresh_audience() {
    local audience="$1"
    local token_ttl_sec refresh_ttl_sec
    read -r token_ttl_sec refresh_ttl_sec < <(get_current_ttls "$audience")

    # Determine if any token refresh is needed.
    if [[ $token_ttl_sec -lt $TTL_THRESHOLD_SEC || $refresh_ttl_sec -lt $TTL_THRESHOLD_SEC ]]; then
        # If the refresh token's TTL is below the threshold, we need a full re-authentication.
        if [[ $refresh_ttl_sec -lt $TTL_THRESHOLD_SEC ]]; then
            if [[ $refresh_ttl_sec -eq 0 ]]; then
                echo "◍ $audience not logged in or refresh token expired."
            else
                echo "◍ $audience refresh token TTL ($((refresh_ttl_sec / 60)) mins) is low."
            fi
            # Logout first to ensure a clean state. Suppress error as it's not critical.
            chainctl auth logout --audience="$audience" >/dev/null 2>&1 || true
            echo "↻ $audience performing full re-authentication..."

            # In browser mode, redirect output to hide messages.
	        local cmd="chainctl auth login --audience=${audience}"
            if [[ "${AUTH_MODE}" == "browser" ]]; then
                if ! $cmd >/dev/null 2>&1; then
                    command_error "Failed to reauthenticate $audience" "${cmd}"
                fi
            else
                if ! $cmd; then
                    command_error "Failed to reauthenticate $audience" "${cmd}"
                fi
            fi
        else
            # The access token needs a simple, non-interactive refresh.
            echo "♽ $audience refreshing token... "
	        local cmd="chainctl auth login --audience=$audience"
            if ! $cmd >/dev/null 2>&1; then
                command_error "Failed to refresh token for $audience." "${cmd}"
            fi
        fi
        # Re-fetch TTLs to report the new values.
        read -r token_ttl_sec refresh_ttl_sec < <(get_current_ttls "$audience")
        echo "✔ $audience refreshed. New TTL is $((token_ttl_sec / 60)) mins. Refresh TTL is $((refresh_ttl_sec / 60)) mins"
    else
        # Tokens are fine, no action needed.
        echo "✔ TTL is $((token_ttl_sec / 60)) mins. Refresh TTL is $((refresh_ttl_sec / 60)) mins: $audience"
    fi
}

# Process audiences based on the operation type
process_audiences() {
    echo "${OPERATION_TITLE}"
    for audience in "${AUDIENCES[@]}"; do
        case "${OPERATION}" in
            logout) logout_audience "$audience";;
            refresh) refresh_audience "$audience";;
            *) echo "✘ ERROR! Unknown operation type: ${OPERATION}" >&2;;
        esac
    done
}

# Helper function for option parsing errors
option_error() {
    echo "✗ ERROR! $1" >&2
    usage
    exit 1
}

# Helper function for errors on command exeuction.
# Arguments:
# 1: The error message
# 2: The command that failed
command_error() {
    echo "✘ ERROR! $1" >&2
    echo "  Please try running '$2' manually." >&2
    exit 1
}

# Validate and normalize TTL threshold value
validate_ttl_threshold() {
    local ttl_minutes="$1"
    if [[ $ttl_minutes -lt 5 ]]; then
        echo "⚑ NOTE! TTL threshold of ${ttl_minutes}m is too low, capping to 5 mins." >&2
        ttl_minutes=5
    elif [[ $ttl_minutes -gt 60 ]]; then
        echo "⚑ NOTE! TTL threshold of ${ttl_minutes}m is too high, capping to 60 mins." >&2
        ttl_minutes=60
    fi
    echo $((ttl_minutes * 60))
}

# Ensure Docker/Podman are configured with the Chainguard credential helper.
update_docker_config() {
    local docker_config="${HOME}/.docker/config.json"

    # First, check if the configuration is already correct.
    if [[ -f "$docker_config" ]] && [[ "$(jq -r '.credHelpers."cgr.dev" // "null"' < "$docker_config")" == "cgr" ]]; then
        echo "✪ Chainguard credential helper for Docker is configured"
        return 0
    fi

    # The 'chainctl' command is idempotent and will only make changes if needed.
    # This configures authentication for any tool that reads ~/.docker/config.json,
    # including both Docker and Podman.
    local cmd="chainctl auth configure-docker"
    echo "⚑ Chainguard credential helper not configured. Attempting to configure now..." >&2
    if ! $cmd >/dev/null 2>&1; then
        command_error "Failed to automatically configure Chainguard credential helper." "${cmd}"
    else
        echo "✪ Chainguard credential helper for Docker is configured"
    fi
}

# Configure chainctl for use at Chainguard
configure_chainctl() {
    chainctl config set default.autoclose true >/dev/null 2>&1
    chainctl config set default.autoclose-timeout 2 >/dev/null 2>&1
    chainctl config set default.use-refresh-token true >/dev/null 2>&1
    chainctl config set default.social-login google-oauth2 >/dev/null 2>&1
}

# Option parsing
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help)
            usage
            exit 0;;
        --version)
            echo "${VERSION}"
            exit 0;;
        --headless)
            AUTH_MODE="headless"
            shift;;
        --browser)
            AUTH_MODE="browser"
            shift;;
        --ttl-threshold)
            [[ -n "$2" && "$2" =~ ^[0-9]+$ ]] || option_error "--ttl-threshold requires a numeric argument."
            TTL_THRESHOLD_SEC=$(validate_ttl_threshold "$2")
            shift 2;;
        --logout)
            OPERATION="logout"
            OPERATION_TITLE="↩ Logging out..."
            shift;;
        *) option_error "Unknown option or unexpected argument: $1";;
    esac
done

# Set auth mode via an environment variable to avoid changing global config.
export CHAINGUARD_AUTH_MODE="${AUTH_MODE}"

configure_chainctl
update_docker_config
process_audiences
