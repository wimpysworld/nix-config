#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'EOF'
Usage: mint-tokens [--force] [--headless]

Refresh Google Cloud, Workspace, Chainguard, MCP, and Docker credentials.

  --force     Log in again even when existing credentials are valid.
  --headless  Use non-browser login where supported.
  -h, --help  Show this help and exit without checking credentials.

Workspace uses the active gcloud account with full Drive access for Docs,
Sheets, and Slides. Gmail and Calendar access are not requested.
One gcloud login repairs user credentials, ADC, and missing Drive consent.
With --headless, gcloud login uses --no-launch-browser.
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

gcloud_login_flags=(--update-adc --enable-gdrive-access)
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
drive_error=
workspace_credentials_usable() {
    local token response
    drive_error='Could not obtain a nonempty gcloud token within 30 seconds. Check gcloud credentials and connectivity.'
    token=$(timeout --signal=TERM --kill-after=1s 30s gcloud auth print-access-token </dev/null 2>/dev/null) || return 2
    [[ -n "${token//[[:space:]]/}" ]] || return 2
    drive_error='Google tokeninfo failed. Check network access and Google API availability before retrying.'
    # Google's OAuth2 v2 discovery specifies POST with a query parameter.
    response=$(printf '%s' "$token" | curl --disable --silent --fail \
        --connect-timeout 10 --max-time 30 --max-filesize 1048576 \
        --request POST --get --data-urlencode access_token@- \
        https://www.googleapis.com/oauth2/v2/tokeninfo 2>/dev/null) || return 2
    if ! jq -e '.scope | type == "string"' <<<"$response" >/dev/null 2>&1; then
        drive_error='Google tokeninfo returned no valid scope list. Check Google API availability before retrying.'
        return 2
    fi
    if ! jq -e '.scope | split(" ") | index("https://www.googleapis.com/auth/drive") != null' \
        <<<"$response" >/dev/null 2>&1; then
        drive_error='Full Drive consent is missing. Accept Drive access during gcloud login, or ask your administrator about consent policy.'
        return 1
    fi
    drive_error='Drive API verification failed. Check network access, Drive API availability, and organisation policy before retrying.'
    printf 'Authorization: Bearer %s\n' "$token" | curl --disable --silent --fail \
        --connect-timeout 10 --max-time 30 --max-filesize 1048576 \
        --header @- --output /dev/null \
        'https://www.googleapis.com/drive/v3/about?fields=kind' 2>/dev/null || return 2
}

repair=$force
if ((adc_valid == 0 || user_valid == 0)); then
    repair=1
    if ((!force)); then
        gcloud_login_flags+=(--force)
    fi
elif ((!force)); then
    drive_status=0
    workspace_credentials_usable || drive_status=$?
    case "$drive_status" in
    1)
        repair=1
        gcloud_login_flags+=(--force)
        ;;
    2)
        echo "✘ ERROR! $drive_error" >&2
        exit 1
        ;;
    esac
fi
if ((repair)); then
    echo '◍ Repairing gcloud credentials, ADC, and Drive consent with one login...'
    if ! gcloud auth login "${gcloud_login_flags[@]}"; then
        echo '✘ ERROR! gcloud login failed. Complete login and Drive consent before retrying.' >&2
        exit 1
    fi
    if ! gcloud auth application-default print-access-token >/dev/null 2>&1; then
        echo '✘ ERROR! gcloud Application Default Credentials remain unavailable after login.' >&2
        exit 1
    fi
    if ! workspace_credentials_usable; then
        echo "✘ ERROR! Verification after login failed. $drive_error" >&2
        exit 1
    fi
fi
echo '✔ gcloud credentials include full Drive access for Docs, Sheets, and Slides.'

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
