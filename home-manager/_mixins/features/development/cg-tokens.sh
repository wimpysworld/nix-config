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
# Global variables to store TTLs, populated by get_current_ttls
CURRENT_TOKEN_TTL_SEC=0
CURRENT_REFRESH_TTL_SEC=0
# Global variable to track date command type and label, populated by detect_date_type
DATE_TYPE=""
DATE_LABEL=""
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

# Detect date command type and set global DATE_TYPE variable
detect_date_type() {
    if [ -z "$DATE_TYPE" ]; then
        if date --help 2>&1 | grep -q "BusyBox v"; then
            DATE_LABEL="BusyBox"
            DATE_TYPE="busybox"
        elif date --help 2>&1 | grep -q "coreutils"; then
            DATE_LABEL="GNU Core Utilities"
            DATE_TYPE="coreutils"
        elif [[ "$(uname)" == "Darwin" ]]; then
            DATE_LABEL="BSDCoreUtils (macOS)"
            DATE_TYPE="bsd"
        else
            DATE_LABEL="Unknown"
            DATE_TYPE="unknown"
        fi
    fi
}

# Helper function to try date parsing
try_date_parse() {
    local cmd_args=("$@")
    local ts=""

    ts=$(LC_ALL=C "${cmd_args[@]}" 2>/dev/null)
    if [[ "$ts" =~ ^[0-9]+$ ]]; then
        echo "$ts"
    else
        echo ""
    fi
}

# Convert a date string to a Unix timestamp
# Input date string format e.g., "2025-06-30 12:30:05 -0700 PDT"
tounix() {
    local date_str="$1"
    local ts=""
    detect_date_type

    # Strip timezone abbreviation (e.g., BST, PDT) as it can sometimes confuse date parsers
    local cleaned_date_str="${date_str% [A-Z][A-Z][A-Z]}"

    # Treat unknown date type like coreutils. Works for uutils.
    if [[ "$DATE_TYPE" == "coreutils" ]] || [[ "$DATE_TYPE" == "unknown" ]]; then
        ts=$(try_date_parse date --date="$cleaned_date_str" "+%s")
        if [[ -z "$ts" ]]; then
            # If stripping failed, try with the original string.
            ts=$(try_date_parse date --date="$date_str" "+%s")
        fi
    elif [[ "$DATE_TYPE" == "busybox" ]]; then
        ts=$(try_date_parse date -d "$cleaned_date_str" "+%s")
        if [[ -z "$ts" ]]; then
            # If stripping failed, try with the original string.
            ts=$(try_date_parse date -d "$date_str" "+%s")
        fi
    elif [[ "$DATE_TYPE" == "bsd" ]]; then
        # BSD date (macOS specific): requires -j and -f for parsing arbitrary date strings.
        # Try original string, with full format, BSD needs exact format match
        ts=$(try_date_parse date -jf "%Y-%m-%d %H:%M:%S %z %Z" "$date_str" "+%s")
        if [[ -z "$ts" ]]; then
            # Try cleaned string with simpler format (fallback for missing timezone)
            ts=$(try_date_parse date -jf "%Y-%m-%d %H:%M:%S %z" "$cleaned_date_str" "+%s")
        fi
    fi

    # If 'ts' is empty, catch and report an error.
    if [[ -z "$ts" ]]; then
        echo "✗ ERROR! Failed to parse date string '$date_str' to Unix timestamp." >&2
        echo "⚑ DEBUG! Date parsing failed using: ${DATE_LABEL}" >&2
        return 1
    fi
    echo "$ts"
}

# Get the token TTL and populate CURRENT_TOKEN_TTL_SEC
get_token_ttl() {
    local audience="$1"
    CURRENT_TOKEN_TTL_SEC=0
    local now_ts
    now_ts=$(date "+%s")

    local status_json
    # Get token expiry from chainctl auth status. If the token has expired, this
    # will trigger a re-authentication so the output can not be suppressed.
    status_json=$(chainctl auth status --output=json --audience="$audience" || echo "{}")

    local expiry_date_str
    expiry_date_str=$(echo "$status_json" | jq -r .expiry 2>/dev/null)

    if [[ -n "$expiry_date_str" && "$expiry_date_str" != "null" ]]; then
        local expiry_ts
        expiry_ts=$(tounix "$expiry_date_str")
        if [[ $? -eq 0 && -n "$expiry_ts" ]]; then
            CURRENT_TOKEN_TTL_SEC=$((expiry_ts - now_ts))
            # Ensure TTL is not negative
            if [[ $CURRENT_TOKEN_TTL_SEC -lt 0 ]]; then CURRENT_TOKEN_TTL_SEC=0; fi
        fi
    fi
}

# Get the refresh TTL and populate CURRENT_REFRESH_TTL_SEC
get_refresh_ttl() {
    local audience="$1"
    CURRENT_REFRESH_TTL_SEC=0
    local now_ts
    now_ts=$(date "+%s")

    # Cache directory for chainctl refresh tokens
    local CHAINCTL_CACHE_DIR="${HOME}/.cache/chainguard"
    if [[ "$(uname)" == "Darwin" ]]; then
        CHAINCTL_CACHE_DIR="${HOME}/Library/Caches/chainguard"
    fi
    # Get refresh token expiry from cache file
    # Sanitize audience for use in file path (replace / with -)
    local audsafe="${audience//\//-}"
    local refresh_token_file="${CHAINCTL_CACHE_DIR}/${audsafe}/refresh-token"
    if [[ -f "$refresh_token_file" ]]; then
        local refresh_data_b64
        refresh_data_b64=$(cat "$refresh_token_file")
        local refresh_exp_ts_str
        # Suppress stderr from base64/jq if file is malformed
        refresh_exp_ts_str=$(echo "$refresh_data_b64" | base64 -d 2>/dev/null | jq -r .exp 2>/dev/null)

        if [[ -n "$refresh_exp_ts_str" && "$refresh_exp_ts_str" != "null" && "$refresh_exp_ts_str" =~ ^[0-9]+$ ]]; then
            # The .exp field in refresh token is already a Unix timestamp
            CURRENT_REFRESH_TTL_SEC=$((refresh_exp_ts_str - now_ts))
            # Ensure TTL is not negative
            if [[ $CURRENT_REFRESH_TTL_SEC -lt 0 ]]; then CURRENT_REFRESH_TTL_SEC=0; fi
        fi
    fi
}

get_current_ttls() {
    local audience="$1"
    get_token_ttl "$audience"
    get_refresh_ttl "$audience"
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
    get_current_ttls "$audience"
    # Determine if any token refresh is needed
    if [[ $CURRENT_TOKEN_TTL_SEC -lt $TTL_THRESHOLD_SEC || $CURRENT_REFRESH_TTL_SEC -lt $TTL_THRESHOLD_SEC ]]; then
        # If the refresh token's remaining life is less than the refresh threshold,
        # logout first and login to obtain a new, potentially longer-lived refresh token.
        if [[ $CURRENT_REFRESH_TTL_SEC -lt $TTL_THRESHOLD_SEC ]]; then
            echo "◍ $audience: Refresh token TTL ($((CURRENT_REFRESH_TTL_SEC / 60)) mins) is less than desired new token TTL ($((TTL_THRESHOLD_SEC / 60)) mins)."
            echo "↻ Logging out and logging in to refresh tokens."
            # Suppress error if logout fails, as it's not critical.
            chainctl auth logout --audience="$audience" >/dev/null 2>&1 || true
            if chainctl auth login --audience="$audience" >/dev/null 2>&1; then
                echo "✔ Authenticated."
            else
                echo "✗ ERROR! Failed to reauthenticate."
            fi
        else
            echo -n "♽ Refreshing token "
            if chainctl auth login --audience="$audience" >/dev/null 2>&1; then
                echo -n "✔ "
            else
                echo "✗ ERROR! Failed to refresh token."
            fi
        fi
        get_current_ttls "$audience"
        echo "TTL is $((CURRENT_TOKEN_TTL_SEC / 60)) mins with a refresh TTL of $((CURRENT_REFRESH_TTL_SEC / 60)) mins: $audience"
    else
        echo "✔ TTL is $((CURRENT_TOKEN_TTL_SEC / 60)) mins. Refresh threshold is $((TTL_THRESHOLD_SEC / 60)) mins: $audience"
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
    local note_prefix="⚑ NOTE! TTL threshold of ${ttl_minutes}m is"
    [[ $ttl_minutes -lt 5 ]] && echo "${note_prefix} too low, capping to 5 mins." >&2 && ttl_minutes=5
    [[ $ttl_minutes -gt 60 ]] && echo "${note_prefix} too high, capping to 60 mins." >&2 && ttl_minutes=60
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
            case "${2,,}" in
                yes|no) HEADLESS="${2,,}"; shift 2;;
                *) option_error "--headless requires an argument: 'yes' or 'no'.";;
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

case "${HEADLESS}" in
    no) chainctl config unset auth.mode >/dev/null 2>&1;;
    *)  chainctl config set auth.mode headless >/dev/null 2>&1
esac

process_audiences
