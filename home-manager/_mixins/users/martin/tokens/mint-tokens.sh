#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'EOF'
Usage: mint-tokens [--force] [--headless]

Refresh Google, Chainguard, MCP, and Docker credentials for all configured audiences.

  --force     Log in again even when existing credentials are valid.
  --headless  Use non-browser login where supported.
  -h, --help  Show this help and exit without checking credentials.
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
