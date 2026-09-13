#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'EOF'
Usage: mint-tokens [--force] [--headless]

Refresh Google Cloud, Workspace, Chainguard, MCP, and Docker credentials.

  --force     Log in again even when existing credentials are valid.
  --headless  Use non-browser login where supported.
  -h, --help  Show this help and exit without checking credentials.

Workspace needs a manually configured client_secret.json and interactive login.
Gmail is read-only. Calendar, Docs, Sheets, and Slides are read-write.
Drive uses drive.file, limited to files created or authorised through the app.
MINT_GWS_ACCOUNT selects the Workspace account (default: active gcloud account).
With --headless, Workspace repair fails without starting a browser login.
EOF
}

force=0
headless=0
while (($#)); do
    case "$1" in
    --force) force=1 ;;
    --headless) headless=1 ;;
    -h | --help)
        usage
        exit 0
        ;;
    *)
        echo "✘ ERROR! Unsupported argument: $1" >&2
        usage >&2
        exit 2
        ;;
    esac
    shift
done

: "${MINT_PROD_AUDIENCES:?}"
: "${MINT_STAGE_AUDIENCES:?}"
: "${MINT_MCP_TOKENS:?}"
: "${MINT_STAGE_ENV:?}"

probe_pid=
stop_probe() {
    if [[ -n "$probe_pid" ]]; then
        kill -TERM -- "-$probe_pid" 2>/dev/null || true
        sleep 0.1
        kill -KILL -- "-$probe_pid" 2>/dev/null || true
        wait "$probe_pid" 2>/dev/null || true
        probe_pid=
    fi
}
handle_signal() {
    local status="$1"
    trap - INT TERM
    stop_probe
    exit "$status"
}
trap 'handle_signal 130' INT
trap 'handle_signal 143' TERM

read -r -a prod_audiences <<<"$MINT_PROD_AUDIENCES"
read -r -a stage_audiences <<<"$MINT_STAGE_AUDIENCES"

gcloud_login_flags=(--update-adc)
chainctl_login_flags=()
if ((force)); then
    gcloud_login_flags+=(--force)
fi
if ((headless)); then
    gcloud_login_flags+=(--no-launch-browser)
    chainctl_login_flags+=(--headless)
fi

adc_valid=0
if gcloud auth application-default print-access-token >/dev/null 2>&1; then
    adc_valid=1
    echo "✔ gcloud Application Default Credentials are valid."
else
    echo "◍ gcloud Application Default Credentials expired or missing."
fi
user_valid=0
if gcloud auth print-access-token >/dev/null 2>&1; then
    user_valid=1
    account=$(gcloud auth list --filter=status:ACTIVE --format='value(account)' 2>/dev/null || true)
    echo "✔ gcloud account active: ${account}"
else
    echo "◍ gcloud user credentials expired or missing."
fi
if ((force || adc_valid == 0 || user_valid == 0)); then
    echo "◍ Repairing gcloud user credentials and Application Default Credentials with one login..."
    gcloud auth login "${gcloud_login_flags[@]}"
    echo "✔ gcloud user credentials and Application Default Credentials renewed."
fi

gws_scopes='https://www.googleapis.com/auth/gmail.readonly,https://www.googleapis.com/auth/calendar,https://www.googleapis.com/auth/drive.file,https://www.googleapis.com/auth/documents,https://www.googleapis.com/auth/spreadsheets,https://www.googleapis.com/auth/presentations'
export GOOGLE_WORKSPACE_CLI_CONFIG_DIR="${GOOGLE_WORKSPACE_CLI_CONFIG_DIR:-${XDG_CONFIG_HOME:-${HOME}/.config}/gws}"
for override in GOOGLE_WORKSPACE_CLI_TOKEN GOOGLE_WORKSPACE_CLI_CREDENTIALS_FILE GOOGLE_WORKSPACE_CLI_CLIENT_ID GOOGLE_WORKSPACE_CLI_CLIENT_SECRET; do
    if [[ -v "$override" ]]; then
        echo "✘ ERROR! Unset ${override} before mint-tokens. Workspace requires its own encrypted desktop login." >&2
        exit 1
    fi
done
gws_account=${MINT_GWS_ACCOUNT:-$(gcloud auth list --filter=status:ACTIVE --format='value(account)' 2>/dev/null || true)}
if [[ -z "$gws_account" || "$gws_account" == *$'\n'* ]]; then
    echo '✘ ERROR! Select one active gcloud account or set MINT_GWS_ACCOUNT before Workspace login.' >&2
    exit 1
fi
workspace_credentials_usable() {
    local status
    status=$(timeout --signal=TERM --kill-after=1s 30s gws auth status </dev/null 2>/dev/null) || return 1
    jq -e --arg account "$gws_account" --arg scopes "$gws_scopes" '
        ($scopes | split(",")) as $required |
        ["openid", "https://www.googleapis.com/auth/userinfo.email",
         "https://www.googleapis.com/auth/userinfo.profile"] as $identity |
        .auth_method == "oauth2" and .storage == "encrypted" and
        .encryption_valid == true and .has_refresh_token == true and
        .token_valid == true and .user == $account and
        (.scopes | type) == "array" and
        (($required - .scopes) | length) == 0 and
        ((.scopes - ($required + $identity)) | length) == 0
    ' <<<"$status" >/dev/null 2>&1
}

echo '◍ Checking Workspace credentials, account, and scopes...'
if ((force)) || ! workspace_credentials_usable; then
    if ((headless)); then
        echo '✘ ERROR! Workspace requires interactive login. Run mint-tokens without --headless on a browser-capable host.' >&2
        exit 1
    fi
    if [[ ! -r "$GOOGLE_WORKSPACE_CLI_CONFIG_DIR/client_secret.json" ]]; then
        echo "✘ ERROR! Save the Desktop OAuth client JSON as ${GOOGLE_WORKSPACE_CLI_CONFIG_DIR}/client_secret.json, then run mint-tokens again." >&2
        exit 1
    fi
    echo '◍ Workspace login requires the selected account and all requested scopes (five-minute limit).'
    timeout --signal=TERM --kill-after=1s 300s gws auth login --scopes "$gws_scopes"
    # gws 0.22.5 login keeps tokens cached for the previous account and scopes.
    if [[ -e "$GOOGLE_WORKSPACE_CLI_CONFIG_DIR/token_cache.json" ]]; then
        cache_backup=$(mktemp -d "$GOOGLE_WORKSPACE_CLI_CONFIG_DIR/token-cache-backup.XXXXXXXX")
        mv -- "$GOOGLE_WORKSPACE_CLI_CONFIG_DIR/token_cache.json" "$cache_backup/token_cache.json"
    fi
    if ! workspace_credentials_usable; then
        echo '✘ ERROR! Workspace verification failed. Check the account, scopes, consent, and network before retrying.' >&2
        echo 'Remove any older, broader app grant in your Google Account before retrying with these scopes.' >&2
        exit 1
    fi
fi
echo '✔ Workspace credentials match the selected account and scopes.'

audience_flags() {
    local audience
    for audience in "$@"; do
        printf '%s\n' "--audience=${audience}"
    done
}

environment_tokens_usable() {
    local config="$1" audience
    shift
    local command=(chainctl)
    if [[ -n "$config" ]]; then
        command+=(--config "$config")
    fi

    for audience in "$@"; do
        CHAINGUARD_DEFAULT_SKIP_AUTO_LOGIN=true \
            timeout --signal=TERM --kill-after="${MINT_CHAINCTL_PROBE_KILL_AFTER:-1s}" \
            "${MINT_CHAINCTL_PROBE_TIMEOUT:-10s}" \
            "${command[@]}" auth token --audience="$audience" </dev/null >/dev/null 2>&1 &
        probe_pid=$!
        if ! wait "$probe_pid" 2>/dev/null; then
            probe_pid=
            return 1
        fi
        probe_pid=
    done
}

mapfile -t prod_flags < <(audience_flags "${prod_audiences[@]}")
echo "◍ Checking Chainguard production credentials..."
prod_usable=0
if environment_tokens_usable "" "${prod_audiences[@]}"; then
    prod_usable=1
fi
if ((force || !prod_usable)); then
    if ((!headless)); then
        chainctl config unset auth.mode >/dev/null
    fi
    chainctl auth login "${chainctl_login_flags[@]}" "${prod_flags[@]}"
fi

config_dir="${XDG_CONFIG_HOME:-${HOME}/.config}/chainctl"
stage_config="${config_dir}/stage-${MINT_STAGE_ENV}.yaml"
install -d -m700 "$config_dir"
umask 077
cat >"$stage_config" <<EOF
default:
    social-login: google-oauth2
    use-refresh-token: true
platform:
    api: https://console-api.${MINT_STAGE_ENV}
    audience: https://console-api.${MINT_STAGE_ENV}
    console: https://console.${MINT_STAGE_ENV}
    issuer: https://issuer.${MINT_STAGE_ENV}
EOF
mapfile -t stage_flags < <(audience_flags "${stage_audiences[@]}")
echo "◍ Checking Chainguard staging credentials..."
stage_usable=0
if environment_tokens_usable "$stage_config" "${stage_audiences[@]}"; then
    stage_usable=1
fi
if ((force || !stage_usable)); then
    chainctl --config "$stage_config" auth login "${chainctl_login_flags[@]}" "${stage_flags[@]}"
fi

chmod 600 "$stage_config"
echo "◍ Chainguard development authentication is disabled pending issuer callback repair."

"$MINT_MCP_TOKENS"

docker_config="${DOCKER_CONFIG:-${HOME}/.docker}/config.json"
ensure_docker_helper() {
    local registry="$1" helper="$2" out
    shift 2
    if ! grep -q "\"${registry}\"" "$docker_config" 2>/dev/null; then
        "$@" || {
            echo "✘ ERROR! Could not configure the Docker credential helper for ${registry}." >&2
            return 1
        }
    fi
    if ! out=$(printf '%s' "$registry" | "$helper" get 2>&1); then
        echo "✘ ERROR! ${helper} cannot get credentials for ${registry}:" >&2
        echo "$out" >&2
        return 1
    fi
    echo "✔ Docker credentials working for ${registry}."
}

ensure_docker_helper gcr.io docker-credential-gcloud gcloud auth configure-docker gcr.io --quiet
ensure_docker_helper cgr.dev docker-credential-cgr chainctl auth configure-docker
