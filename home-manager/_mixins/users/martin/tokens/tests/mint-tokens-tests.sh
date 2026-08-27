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

run_success bash "$script" --force >"$tmp/force-output"
assert_log 'gcloud auth login --update-adc --force'
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
    run_success bash "$script" "${args[@]}" >/dev/null
    assert_log 'gcloud auth login --update-adc --force --no-launch-browser'
    assert_log 'chainctl auth login --headless --audience=prod --audience=mcp-prod'
    assert_log 'auth login --headless --audience=stage --audience=mcp-stage'
done

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
