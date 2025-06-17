#!/usr/bin/env bash
# Inspired by: https://gist.github.com/smoser/568f03b41efe80f57cea4605beec71ac
set -euo pipefail

# --- Configuration ---
VERSION="0.1.0"
AUDIENCES=(
    "https://console-api.enforce.dev"
    "apk.cgr.dev"
    "cgr.dev"
)

# --- Helper Functions ---
usage() {
    cat <<EOF
$(basename "${0}") version ${VERSION}
Refreshes Chainguard tokens if they are close to expiring.

USAGE:
    $(basename "${0}") [OPTIONS]

OPTIONS:
    --headless              Enable headless operation (default).
    --no-headless           Disable headless operation (interactive).
    --logout                Log out from all configured audiences.
    --ttl-minutes <minutes> Set desired token TTL in minutes (default: 30).
    --help                  Show this help message and exit.
    --version               Show script version and exit.
EOF
}

_IS_COREUTILS_DATE_CHECKED=""
_IS_COREUTILS_DATE_RESULT=""

# Checks if 'date' command is from GNU coreutils
is_coreutils_date() {
    if [ -z "$_IS_COREUTILS_DATE_CHECKED" ]; then
        #TODO: Add support for uutils
        if date --help 2>&1 | grep -q "coreutils"; then
            _IS_COREUTILS_DATE_RESULT="true"
        else
            _IS_COREUTILS_DATE_RESULT="false"
        fi
        _IS_COREUTILS_DATE_CHECKED="true"
    fi
    [ "$_IS_COREUTILS_DATE_RESULT" = "true" ]
}

# Convert a date string to a Unix timestamp
# Input date string format e.g., "2025-06-30 12:30:05 -0700 PDT"
tounix() {
    local date_str="$1"
    local ts=""

    if is_coreutils_date; then
        # GNU date:
        # Attempt 1: Strip timezone abbreviation (e.g., BST, PDT) as it can sometimes confuse GNU date.
        local cleaned_date_str_gnu="${date_str% [A-Z][A-Z][A-Z]}"
        ts=$(LC_ALL=C date --date="$cleaned_date_str_gnu" "+%s" 2>/dev/null)

        # Attempt 2: If stripping failed, try with the original string. GNU date is often flexible.
        if ! [[ "$ts" =~ ^[0-9]+$ ]]; then
            ts=$(LC_ALL=C date --date="$date_str" "+%s" 2>/dev/null)
        fi
    elif [[ "$(uname)" == "Darwin" ]]; then
        # BSD date (macOS specific): requires -j and -f for parsing arbitrary date strings.
        # Attempt 1: With timezone abbreviation
        ts=$(LC_ALL=C date -jf "%Y-%m-%d %H:%M:%S %z %Z" "$date_str" "+%s" 2>/dev/null)

        if ! [[ "$ts" =~ ^[0-9]+$ ]]; then
            # Attempt 2: Without timezone abbreviation, if the first failed
            local cleaned_date_str_bsd="${date_str% [A-Z][A-Z][A-Z]}"
            ts=$(LC_ALL=C date -jf "%Y-%m-%d %H:%M:%S %z" "$cleaned_date_str_bsd" "+%s" 2>/dev/null)
        fi
    # If not coreutils and not Darwin, 'ts' will likely remain empty.
    # The check below will catch this and report an error.
    fi

    if ! [[ "$ts" =~ ^[0-9]+$ ]]; then
        echo "Error: Failed to parse date string '$date_str' to Unix timestamp." >&2
        local date_type_for_msg
        # _IS_COREUTILS_DATE_RESULT is set by the is_coreutils_date call above
        if [[ "$_IS_COREUTILS_DATE_RESULT" == "true" ]]; then
            date_type_for_msg="GNU coreutils"
        elif [[ "$(uname)" == "Darwin" ]]; then
            date_type_for_msg="macOS (BSD)"
        else
            date_type_for_msg="non-GNU/non-macOS (unknown type)"
        fi
        echo "Debug: Date parsing failed. Detected/Attempted date type: $date_type_for_msg. Input: '$date_str'" >&2
        return 1
    fi
    echo "$ts"
}

# Global variables to store TTLs, populated by get_current_ttls
_CURRENT_TOKEN_TTL_SEC=0
_CURRENT_REFRESH_TTL_SEC=0

# Get current token TTL and refresh token TTL for a given audience
# Populates _CURRENT_TOKEN_TTL_SEC and _CURRENT_REFRESH_TTL_SEC
get_current_ttls() {
    local audience="$1"
    _CURRENT_TOKEN_TTL_SEC=0
    _CURRENT_REFRESH_TTL_SEC=0
    local now_ts
    now_ts=$(date "+%s")

    # Get token expiry from chainctl auth status
    local status_json
    # Suppress stderr for chainctl if token doesn't exist, jq will handle empty/error json
    status_json=$(chainctl auth status --output=json --audience="$audience" 2>/dev/null || echo "{}")

    local expiry_date_str
    expiry_date_str=$(echo "$status_json" | jq -r .expiry 2>/dev/null)

    if [[ -n "$expiry_date_str" && "$expiry_date_str" != "null" ]]; then
        local expiry_ts
        expiry_ts=$(tounix "$expiry_date_str")
        if [[ $? -eq 0 && -n "$expiry_ts" ]]; then
            _CURRENT_TOKEN_TTL_SEC=$((expiry_ts - now_ts))
            # Ensure TTL is not negative
            if [[ $_CURRENT_TOKEN_TTL_SEC -lt 0 ]]; then _CURRENT_TOKEN_TTL_SEC=0; fi
        fi
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
            _CURRENT_REFRESH_TTL_SEC=$((refresh_exp_ts_str - now_ts))
            # Ensure TTL is not negative
            if [[ $_CURRENT_REFRESH_TTL_SEC -lt 0 ]]; then _CURRENT_REFRESH_TTL_SEC=0; fi
        fi
    fi
}

# --- Sanity Checks for required commands ---
for cmd in chainctl jq date base64; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "Error: Required command '$cmd' not found in PATH." >&2
        exit 1
    fi
done

# Option parsing
HEADLESS_OPT="--headless"
WANTED_TTL_SECONDS=$((30 * 60)) # Default TTL: 60 minutes
LOGOUT_MODE=false

if [[ $# -gt 0 ]]; then
    # Loop through all arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --help)
                usage
                exit 0
                ;;
            --version)
                echo "${VERSION}"
                exit 0
                ;;
            --headless)
                HEADLESS_OPT="--headless"
                shift
                ;;
            --no-headless)
                HEADLESS_OPT=""
                shift
                ;;
            --ttl-minutes)
                if [[ -n "$2" && "$2" =~ ^[0-9]+$ ]]; then
                    WANTED_TTL_SECONDS=$(($2 * 60))
                    shift 2
                else
                    echo "Error: --ttl-minutes requires a numeric argument." >&2
                    usage
                    exit 1
                fi
                ;;
            --logout)
                LOGOUT_MODE=true
                shift
                ;;
            *)
                echo "Error: Unknown option or unexpected argument: $1" >&2
                usage
                exit 1
                ;;
        esac
    done
fi

# Cache directory for chainguard refresh tokens
CHAINCTL_CACHE_DIR="${HOME}/.cache/chainguard"
if [[ "$(uname)" == "Darwin" ]]; then
    CHAINCTL_CACHE_DIR="${HOME}/Library/Caches/chainguard"
fi

if [[ "${LOGOUT_MODE}" == "true" ]]; then
    echo "󰍃 Logging out from configured audiences..."
    for audience in "${AUDIENCES[@]}"; do
        if chainctl auth logout --audience="$audience" --output="none" >/dev/null 2>&1; then
            echo "󰌊 $audience logged out"
        else
            echo " $audience failed to log out or no active session."
        fi
    done
    exit 0
fi

# --- Main Logic ---
echo " Ensuring tokens for selected audiences have at least $((WANTED_TTL_SECONDS / 60)) minutes TTL."
for audience in "${AUDIENCES[@]}"; do
    get_current_ttls "$audience"

    current_token_ttl_min=$((_CURRENT_TOKEN_TTL_SEC / 60))
    current_refresh_ttl_min=$((_CURRENT_REFRESH_TTL_SEC / 60))
    wanted_ttl_min=$((WANTED_TTL_SECONDS / 60))
    echo "󱌒 $audience has TTL of ${current_token_ttl_min}m, wanted ${wanted_ttl_min}m."

    # Determine if action (login/refresh) is needed
    if [[ $_CURRENT_TOKEN_TTL_SEC -lt $WANTED_TTL_SECONDS || $_CURRENT_REFRESH_TTL_SEC -lt $WANTED_TTL_SECONDS ]]; then
        echo "󰒓 $audience: action required"
        # If the current refresh token's remaining life is less than our desired token lifetime,
        # it's better to logout first. This ensures that the subsequent login can establish
        # a new, potentially longer-lived refresh token.
        if [[ $_CURRENT_REFRESH_TTL_SEC -lt $WANTED_TTL_SECONDS ]]; then
            echo " $audience: refresh token TTL (${current_refresh_ttl_min}m) is less than desired new token TTL (${wanted_ttl_min}m). Logging out first."
            # Suppress error if logout fails (e.g., no active session), as it's not critical.
            chainctl auth logout --audience="$audience" --output="none" 2>/dev/null || echo "Note: Logout for $audience failed or no existing session (this is often normal)."
        fi

        echo "󰍂 $audience: attempting login/refresh"
        # chainctl auth login handles refreshing if possible, or prompts for new login.
        # Minimal output is desired, so we redirect stdout/stderr.
        if [[ -n "$HEADLESS_OPT" ]]; then
            chainctl auth login --audience="$audience" "$HEADLESS_OPT"
        else
            chainctl auth login --audience="$audience" >/dev/null 2>&1
        fi

        # Get updated TTLs and report final status
        get_current_ttls "$audience"
        current_token_ttl_min=$((_CURRENT_TOKEN_TTL_SEC / 60))
        current_refresh_ttl_min=$((_CURRENT_REFRESH_TTL_SEC / 60))
        echo "󰌉 $audience: TTL is ${current_token_ttl_min}m with a refresh TTL of ${current_refresh_ttl_min}m."
    else
        echo "󱞩 TTLs are sufficient."
    fi
done
