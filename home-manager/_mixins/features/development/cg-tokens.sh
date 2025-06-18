#!/usr/bin/env bash
# Inspired by: https://gist.github.com/smoser/568f03b41efe80f57cea4605beec71ac
set -euo pipefail

if [[ "${BASH_VERSINFO[0]}" -lt 4 || ( "${BASH_VERSINFO[0]}" -eq 4 && "${BASH_VERSINFO[1]}" -lt 4 ) ]]; then
    echo "✗ ERROR! This script requires Bash version 4.4 or higher." >&2
    exit 1
fi

# Check for required commands
for cmd in chainctl jq date base64; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "✗ ERROR! Required command '$cmd' not found in PATH." >&2
        exit 1
    fi
done

AUDIENCES=(
    "https://console-api.enforce.dev"
    "apk.cgr.dev"
    "cgr.dev"
)
# Default headless mode
HEADLESS=yes
# Default operation mode
OPERATION=refresh
OPERATION_TITLE="◉ Ensuring tokens are fresh..."
# Default refresh threshold; 30 mins
TTL_THRESHOLD_SEC=$((30 * 60))
VERSION="0.1.2"

usage() {
    cat <<EOF
$(basename "${0}") v${VERSION}
Refreshes Chainguard tokens if they are close to expiring.

USAGE:
    $(basename "${0}") [OPTIONS]

OPTIONS:
    --headless <yes|no>       Enable or disable headless operation (default: yes).
    --ttl-threshold <minutes> Set token refresh threshold in minutes (default: 30, min: 5, max: 60).
    --logout                  Log out from all configured audiences.
    --help                    Show this help message and exit.
    --version                 Show version and exit.
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

            # Build the login command. In interactive mode, redirect output to hide browser messages.
            local login_cmd="chainctl auth login --audience=\"$audience\""
            if [[ "${HEADLESS}" != "yes" ]]; then
                login_cmd+=" >/dev/null 2>&1"
            fi
            if ! eval "$login_cmd"; then
                echo "✗ ERROR! Failed to reauthenticate $audience" >&2
                return 1
            fi
        else
            # The access token needs a simple, non-interactive refresh.
            echo "♽ $audience refreshing token... "
            if ! chainctl auth login --audience="$audience" >/dev/null 2>&1; then
                echo "✗ ERROR! Failed to refresh token for $audience."
                return 1
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
            *) echo "✗ ERROR! Unknown operation type: ${OPERATION}" >&2;;
        esac
    done
}

# Helper function for option parsing errors
option_error() {
    echo "✗ ERROR! $1" >&2
    usage
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
            [[ -z "$2" ]] && option_error "--headless requires an argument: 'yes' or 'no'."
            case "${2,,}" in
                yes|no) HEADLESS="${2,,}"; shift 2;;
                *) option_error "Invalid argument for --headless: '$2'. Use 'yes' or 'no'.";;
            esac;;
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
if [[ "${HEADLESS}" == "yes" ]]; then
    export CHAINGUARD_AUTH_MODE=headless
fi

process_audiences
