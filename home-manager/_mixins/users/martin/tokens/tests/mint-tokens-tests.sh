#!/usr/bin/env bash
set -euo pipefail

script=${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/mint-tokens.sh}
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/home/.docker"
log="$tmp/log"

cat >"$tmp/bin/gcloud" <<'EOF'
#!/usr/bin/env bash
printf 'gcloud %s\n' "$*" >>"$TEST_LOG"
case "$*" in
'auth application-default print-access-token') exit "${ADC_EXIT:-0}" ;;
'auth print-access-token') exit "${USER_EXIT:-0}" ;;
'auth list '*) printf '%s\n' 'user@example.com' ;;
'auth login '*) exit "${GCLOUD_LOGIN_EXIT:-0}" ;;
esac
EOF
cat >"$tmp/bin/gws" <<'EOF'
#!/usr/bin/env bash
printf 'gws %s\n' "$*" >>"$TEST_LOG"
case "$*" in
'auth status')
    printf '%s\n' SECRET_STATUS_ERROR >&2
    if [[ "${GWS_REPAIR:-0}" == 1 ]] && grep -Fq 'gws auth login ' "$TEST_LOG"; then
        GWS_STATE=valid
    fi
    [[ "${GWS_STATE:-valid}" != timeout ]] || exit 124
    if [[ "${GWS_STATE:-valid}" == malformed ]]; then
        printf '%s\n' 'not json'
        exit 0
    fi
    if [[ "${GWS_STATE:-valid}" == missing ]]; then
        printf '%s\n' '{"storage":"none"}'
        exit 0
    fi
    jq -n --arg state "${GWS_STATE:-valid}" '
      {auth_method:"oauth2", storage:"encrypted", encryption_valid:true,
       has_refresh_token:true, token_valid:true, user:"user@example.com",
       scopes:(["gmail.readonly","calendar","drive.file","documents","spreadsheets","presentations","userinfo.email","userinfo.profile"] |
         map("https://www.googleapis.com/auth/" + .)) + ["openid"]} |
      if $state == "revoked" then .token_valid = false
      elif $state == "metadata" then del(.token_valid,.user,.scopes)
      elif $state == "wrong-account" then .user = "other@example.com"
      elif $state == "scopes" then .scopes = []
      elif $state == "broad" then .scopes += ["https://www.googleapis.com/auth/gmail.send"]
      elif $state == "full-drive" then .scopes += ["https://www.googleapis.com/auth/drive"]
      elif $state == "plaintext" then .storage = "plaintext"
      elif $state == "corrupt" then .encryption_valid = false
      else . end'
    ;;
'auth login --scopes '*) exit "${GWS_LOGIN_EXIT:-0}" ;;
*) exit 98 ;;
esac
EOF
cat >"$tmp/bin/chainctl" <<'EOF'
#!/usr/bin/env bash
printf 'chainctl %s\n' "$*" >>"$TEST_LOG"
if [[ "$*" == *'auth token --audience='* ]]; then
    audience=
    for argument in "$@"; do
        [[ "$argument" != --audience=* ]] || audience=${argument#--audience=}
    done
    printf 'probe skip-auto-login=%s audience=%s\n' \
        "${CHAINGUARD_DEFAULT_SKIP_AUTO_LOGIN:-unset}" "$audience" >>"$TEST_LOG"
    [[ "${CHAINGUARD_DEFAULT_SKIP_AUTO_LOGIN:-}" == true ]] || exit 88
    [[ $(readlink "/proc/$$/fd/0") == /dev/null ]] || exit 89
    printf '%s\n' 'SECRET_TOKEN'
    printf '%s\n' 'SECRET_TOKEN_ERROR' >&2
    if [[ "${PROBE_SLEEP_AUDIENCE:-}" == "$audience" ]]; then
        printf '%s\n' "$$" >"${PROBE_STARTED:?}"
        trap '' INT TERM
        while true; do sleep 1; done
    fi
    for invalid in ${INVALID_AUDIENCES:-}; do
        [[ "$audience" != "$invalid" ]] || exit 1
    done
fi
if [[ "$*" == 'config unset auth.mode' ]]; then
    printf '%s\n' 'auth.mode was not set'
fi
if [[ -n "${CHAIN_FAIL_MATCH:-}" && "$*" == *"$CHAIN_FAIL_MATCH"* ]]; then
    printf '%s\n' 'mock chainctl error' >&2
    exit 1
fi
EOF
cat >"$tmp/bin/xdg-open" <<'EOF'
#!/usr/bin/env bash
printf 'xdg-open %s\n' "$*" >>"$TEST_LOG"
exit 99
EOF
for helper in docker-credential-gcloud docker-credential-cgr; do
    cat >"$tmp/bin/$helper" <<EOF
#!/usr/bin/env bash
printf '$helper %s\n' "\$*" >>"\$TEST_LOG"
cat >/dev/null
exit "\${DOCKER_EXIT:-0}"
EOF
done
cat >"$tmp/bin/mcp-private" <<'EOF'
#!/usr/bin/env bash
printf 'mcp-private %s\n' "$*" >>"$TEST_LOG"
exit "${MCP_EXIT:-0}"
EOF
chmod +x "$tmp/bin/"*

export PATH="$tmp/bin:$PATH"
export HOME="$tmp/home"
export XDG_CONFIG_HOME="$tmp/home/.config"
export DOCKER_CONFIG="$tmp/home/.docker"
export TEST_LOG="$log"
export MINT_PROD_AUDIENCES='prod mcp-prod'
export MINT_STAGE_AUDIENCES='stage mcp-stage'
export MINT_MCP_TOKENS="$tmp/bin/mcp-private"
export MINT_STAGE_ENV='stage.example'
export GOOGLE_WORKSPACE_CLI_CONFIG_DIR="$XDG_CONFIG_HOME/gws"
unset GOOGLE_WORKSPACE_CLI_TOKEN GOOGLE_WORKSPACE_CLI_CREDENTIALS_FILE
unset GOOGLE_WORKSPACE_CLI_CLIENT_ID GOOGLE_WORKSPACE_CLI_CLIENT_SECRET MINT_GWS_ACCOUNT
mkdir -p "$GOOGLE_WORKSPACE_CLI_CONFIG_DIR"
printf '%s\n' '{}' >"$GOOGLE_WORKSPACE_CLI_CONFIG_DIR/client_secret.json"
unset MINT_DEV_AUDIENCES MINT_DEV_ENV

fail() {
    echo "FAIL: $*" >&2
    exit 1
}
assert_log() {
    grep -Fq -- "$1" "$log" || fail "log does not contain: $1"
}
assert_no_log() {
    if grep -Fq -- "$1" "$log"; then
        fail "log contains: $1"
    fi
}
line_of() {
    grep -n -F -- "$1" "$log" | head -1 | cut -d: -f1
}
dev_config="$XDG_CONFIG_HOME/chainctl/devenv-wimpress.guardenv.dev.yaml"
assert_development_untouched() {
    assert_no_log 'development'
    assert_no_log 'devenv-'
    assert_no_log 'guardenv.dev'
    assert_no_log 'xdg-open '
    [[ $(cat "$dev_config") == 'existing development config' ]] ||
        fail 'development config was created or rewritten'
}
run_success() {
    : >"$log"
    rm -rf "$XDG_CONFIG_HOME/chainctl"
    mkdir -p "${dev_config%/*}"
    printf '%s\n' 'existing development config' >"$dev_config"
    "$@"
    assert_development_untouched
}

: >"$log"
env -u MINT_PROD_AUDIENCES bash "$script" --help >"$tmp/help"
assert_no_log 'gcloud '
grep -Fq 'Usage: mint-tokens' "$tmp/help" || fail 'help is missing usage'

for unsupported in '--bogus' '--force unexpected'; do
    : >"$log"
    read -r -a unsupported_args <<<"$unsupported"
    set +e
    bash "$script" "${unsupported_args[@]}" >"$tmp/unsupported-output" 2>&1
    status=$?
    set -e
    [[ "$status" == 2 ]] || fail "unsupported arguments returned $status instead of 2"
    assert_no_log 'gcloud '
done

for adc in 0 1; do
    for user in 0 1; do
        run_success env ADC_EXIT=$adc USER_EXIT=$user bash "$script" >"$tmp/matrix-output" 2>&1
        if ((adc == 0 && user == 0)); then
            assert_no_log 'gcloud auth login --update-adc'
        else
            assert_log 'gcloud auth login --update-adc'
        fi
        assert_no_log 'chainctl auth login '
        assert_no_log 'gws auth login '
        assert_log 'gws auth status'
        [[ $(grep -c '^probe skip-auto-login=true ' "$log") == 4 ]] ||
            fail 'all production and staging audiences were not probed'
        for audience in prod mcp-prod stage mcp-stage; do
            assert_log "audience=$audience"
        done
        grep -Fq 'development authentication is disabled pending issuer callback repair' "$tmp/matrix-output" ||
            fail 'development disabled notice is missing'
        ! grep -Fq 'SECRET_TOKEN' "$tmp/matrix-output" || fail 'a probe token appeared in output'
        assert_log 'mcp-private '
    done
done

run_success env INVALID_AUDIENCES=prod bash "$script" >"$tmp/prod-invalid-output"
assert_log 'chainctl auth login --audience=prod --audience=mcp-prod'
assert_no_log 'auth login --audience=stage'

run_success env INVALID_AUDIENCES=stage bash "$script" >"$tmp/stage-invalid-output"
assert_no_log 'chainctl auth login --audience=prod'
assert_log 'auth login --audience=stage --audience=mcp-stage'

printf '%s\n' 'OLD_ENCRYPTED_CACHE' >"$GOOGLE_WORKSPACE_CLI_CONFIG_DIR/token_cache.json"
run_success bash "$script" --force >"$tmp/force-output"
[[ ! -e "$GOOGLE_WORKSPACE_CLI_CONFIG_DIR/token_cache.json" ]] || fail 'Workspace kept the old active token cache'
grep -Fq OLD_ENCRYPTED_CACHE "$GOOGLE_WORKSPACE_CLI_CONFIG_DIR"/token-cache-backup.*/token_cache.json ||
    fail 'Workspace did not preserve the old token cache'
assert_log 'gcloud auth login --update-adc --force'
assert_log 'gws auth login --scopes https://www.googleapis.com/auth/gmail.readonly,https://www.googleapis.com/auth/calendar,https://www.googleapis.com/auth/drive.file,https://www.googleapis.com/auth/documents,https://www.googleapis.com/auth/spreadsheets,https://www.googleapis.com/auth/presentations'
[[ $(grep -c '^gcloud auth login ' "$log") == 1 ]] || fail '--force ran more than one gcloud login'
assert_log 'chainctl auth login --audience=prod --audience=mcp-prod'
assert_log 'auth login --audience=stage --audience=mcp-stage'
[[ $(grep -c '^probe skip-auto-login=true ' "$log") == 4 ]] || fail '--force skipped a probe'
if grep -Eq 'auth.mode was not set|SECRET_TOKEN' "$tmp/force-output"; then
    fail 'suppressed command output appeared during forced repair'
fi

: >"$log"
if CHAIN_FAIL_MATCH='config unset auth.mode' bash "$script" --force >"$tmp/unset-output" 2>&1; then
    fail 'production auth.mode unset failure returned success'
fi
grep -Fq 'mock chainctl error' "$tmp/unset-output" || fail 'production auth.mode unset error was hidden'
assert_development_untouched

for flags in '--force --headless' '--headless --force'; do
    read -r -a args <<<"$flags"
    : >"$log"
    if bash "$script" "${args[@]}" >"$tmp/headless-output" 2>&1; then
        fail 'forced headless Workspace repair returned success'
    fi
    assert_log 'gcloud auth login --update-adc --force --no-launch-browser'
    assert_no_log 'gws auth login '
    assert_no_log 'chainctl '
    grep -Fq 'Workspace requires interactive login' "$tmp/headless-output" || fail 'headless error is missing'
done

run_success env INVALID_AUDIENCES='prod stage' bash "$script" --headless >/dev/null
assert_no_log 'gws auth login '
assert_log 'chainctl auth login --headless --audience=prod --audience=mcp-prod'
assert_log 'auth login --headless --audience=stage --audience=mcp-stage'

run_success env GWS_STATE=revoked GWS_REPAIR=1 bash "$script" >"$tmp/gws-repair-output"
assert_log 'gws auth login --scopes '
[[ $(grep -c '^gws auth status' "$log") == 2 ]] || fail 'Workspace repair did not verify the new login'

for state in missing revoked metadata wrong-account scopes broad full-drive plaintext corrupt malformed timeout; do
    for flags in '' '--headless'; do
        : >"$log"
        read -r -a args <<<"$flags"
        if GWS_STATE="$state" bash "$script" "${args[@]}" >"$tmp/gws-output" 2>&1; then
            fail "invalid Workspace state $state returned success"
        fi
        if [[ "$flags" == --headless ]]; then
            assert_no_log 'gws auth login '
        else
            assert_log 'gws auth login --scopes '
            grep -Fq 'Workspace verification failed' "$tmp/gws-output" || fail 'post-login verification is missing'
        fi
        assert_no_log 'chainctl '
        ! grep -Fq 'SECRET_STATUS_ERROR' "$tmp/gws-output" || fail 'Workspace probe stderr leaked'
    done
done

: >"$log"
if GWS_LOGIN_EXIT=1 bash "$script" --force >/dev/null 2>&1; then
    fail 'Workspace login failure returned success'
fi
assert_no_log 'chainctl '

: >"$log"
if GOOGLE_WORKSPACE_CLI_TOKEN=SECRET_TOKEN bash "$script" >"$tmp/override-output" 2>&1; then
    fail 'Workspace token override returned success'
fi
assert_no_log 'gws '
! grep -Fq 'SECRET_TOKEN' "$tmp/override-output" || fail 'Workspace override leaked'

mv "$GOOGLE_WORKSPACE_CLI_CONFIG_DIR/client_secret.json" "$tmp/client.json"
run_success bash "$script" >/dev/null
: >"$log"
if GWS_STATE=missing bash "$script" >"$tmp/client-output" 2>&1; then
    fail 'missing Workspace client returned success'
fi
assert_no_log 'gws auth login '
grep -Fq 'Desktop OAuth client JSON' "$tmp/client-output" || fail 'missing client error is missing'
mv "$tmp/client.json" "$GOOGLE_WORKSPACE_CLI_CONFIG_DIR/client_secret.json"

run_success env INVALID_AUDIENCES='prod stage' bash "$script" >/dev/null
prod_login=$(line_of 'chainctl auth login --audience=prod')
stage_login=$(line_of 'auth login --audience=stage')
mcp_copy=$(line_of 'mcp-private ')
gcloud_docker=$(line_of 'docker-credential-gcloud')
cgr_docker=$(line_of 'docker-credential-cgr')
((prod_login < stage_login && stage_login < mcp_copy && mcp_copy < gcloud_docker && gcloud_docker < cgr_docker)) ||
    fail 'Chainguard, MCP, and Docker ordering is wrong'

: >"$log"
if INVALID_AUDIENCES=stage CHAIN_FAIL_MATCH='auth login --audience=stage' bash "$script" >/dev/null 2>&1; then
    fail 'chainctl repair failure returned success'
fi
assert_no_log 'mcp-private'
assert_no_log 'docker-credential-gcloud'
assert_development_untouched

: >"$log"
if GCLOUD_LOGIN_EXIT=1 ADC_EXIT=1 bash "$script" >/dev/null 2>&1; then
    fail 'gcloud login failure returned success'
fi
assert_no_log 'chainctl '

: >"$log"
if MCP_EXIT=1 bash "$script" >/dev/null 2>&1; then
    fail 'MCP failure returned success'
fi
assert_no_log 'docker-credential-gcloud'
assert_development_untouched

: >"$log"
if DOCKER_EXIT=1 bash "$script" >/dev/null 2>&1; then
    fail 'Docker helper failure returned success'
fi
assert_log 'mcp-private '
assert_development_untouched

: >"$log"
probe_started="$tmp/timeout-probe"
rm -f "$probe_started"
PROBE_SLEEP_AUDIENCE=stage PROBE_STARTED="$probe_started" \
    MINT_CHAINCTL_PROBE_TIMEOUT=0.1s MINT_CHAINCTL_PROBE_KILL_AFTER=0.1s \
    bash "$script" >"$tmp/timeout-output"
assert_log 'auth login --audience=stage --audience=mcp-stage'
timeout_probe_pid=$(cat "$probe_started")
if kill -0 "$timeout_probe_pid" 2>/dev/null; then
    fail 'timed-out chainctl probe is still running'
fi
assert_development_untouched

: >"$log"
probe_started="$tmp/interrupt-probe"
rm -f "$probe_started"
setsid env --default-signal=INT PROBE_SLEEP_AUDIENCE=prod PROBE_STARTED="$probe_started" \
    MINT_CHAINCTL_PROBE_TIMEOUT=30s MINT_CHAINCTL_PROBE_KILL_AFTER=0.1s \
    bash "$script" >"$tmp/interrupt-output" 2>&1 &
interrupt_pid=$!
for _ in {1..100}; do
    [[ -s "$probe_started" ]] && break
    sleep 0.02
done
[[ -s "$probe_started" ]] || fail 'interrupt test did not reach the chainctl probe'
kill -INT -- "-$interrupt_pid"
for _ in {1..100}; do
    ! kill -0 "$interrupt_pid" 2>/dev/null && break
    sleep 0.02
done
if kill -0 "$interrupt_pid" 2>/dev/null; then
    kill -KILL -- "-$interrupt_pid" 2>/dev/null || true
    fail 'mint-tokens did not exit promptly after SIGINT'
fi
set +e
wait "$interrupt_pid"
interrupt_status=$?
set -e
[[ "$interrupt_status" == 130 ]] || fail "SIGINT returned $interrupt_status instead of 130"
interrupt_probe_pid=$(cat "$probe_started")
if kill -0 "$interrupt_probe_pid" 2>/dev/null; then
    fail 'interrupted chainctl probe is still running'
fi
assert_no_log 'chainctl auth login '
assert_no_log 'mcp-private '
assert_development_untouched

echo 'mint-tokens tests passed'
