#!/usr/bin/env bash
set -euo pipefail
script=${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/gws.sh}
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/home"
export HOME="$tmp/home" XDG_CONFIG_HOME="$tmp/home/.config"
export TEST_LOG="$tmp/log" TEST_COUNT="$tmp/count" TEST_ARGS="$tmp/args"
cat >"$tmp/bin/cloud-absolute" <<'EOF'
#!/usr/bin/env bash
[[ "$*" == 'auth print-access-token' ]] || exit 99
printf 'token request\n' >>"$TEST_LOG"
printf 'SECRET_ERROR\n' >&2
case "${TOKEN_STATE:-valid}" in
failure) exit 1 ;;
empty) exit 0 ;;
timeout) exit 124 ;;
esac
count=0
[[ ! -f "$TEST_COUNT" ]] || read -r count <"$TEST_COUNT"
printf '%s\n' "$((count + 1))" >"$TEST_COUNT"
printf 'SECRET_TOKEN_%s\n' "$((count + 1))"
EOF
cat >"$tmp/bin/workspace-absolute" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$GOOGLE_WORKSPACE_CLI_TOKEN" >>"$TEST_LOG"
printf '%s\0' "$@" >"$TEST_ARGS"
exit "${RAW_EXIT:-0}"
EOF
cat >"$tmp/bin/timeout" <<'EOF'
#!/usr/bin/env bash
[[ "$1 $2 $3" == '--signal=TERM --kill-after=1s 30s' ]] || exit 98
shift 3
exec "$@"
EOF
for name in gws gcloud; do
    printf '#!/usr/bin/env bash\nexit 97\n' >"$tmp/bin/$name"
done
chmod +x "$tmp/bin/"*
export PATH="$tmp/bin:$PATH"
sed -e "s|@gcloud@|$tmp/bin/cloud-absolute|g" -e "s|@gws@|$tmp/bin/workspace-absolute|g" "$script" >"$tmp/wrapper"
fail() {
    echo "FAIL: $*" >&2
    exit 1
}
: >"$TEST_LOG"
for _ in 1 2; do
    GOOGLE_WORKSPACE_CLI_TOKEN=SECRET_STALE bash "$tmp/wrapper" docs documents get --params '{"documentId":"a b"}' '' '*' >"$tmp/output" 2>&1
done
[[ $(grep -c '^token request$' "$TEST_LOG") == 2 ]] || fail 'token was not requested each time'
grep -Fxq SECRET_TOKEN_1 "$TEST_LOG" || fail 'first token is missing'
grep -Fxq SECRET_TOKEN_2 "$TEST_LOG" || fail 'second token is missing'
! grep -Fq SECRET_STALE "$TEST_LOG" || fail 'stale token was retained'
printf '%s\0' docs documents get --params '{"documentId":"a b"}' '' '*' >"$tmp/expected"
cmp "$tmp/expected" "$TEST_ARGS" || fail 'arguments changed'
for state in failure empty timeout; do
    : >"$TEST_LOG"
    if TOKEN_STATE="$state" bash "$tmp/wrapper" >"$tmp/output" 2>&1; then
        fail "$state returned success"
    fi
    ! grep -Fq SECRET_TOKEN "$TEST_LOG" || fail 'raw gws ran without a token'
    ! grep -Fq SECRET "$tmp/output" || fail 'token failure leaked output'
    grep -Fq 'Could not obtain a nonempty gcloud token' "$tmp/output" || fail 'token error is missing'
done
set +e
RAW_EXIT=42 bash "$tmp/wrapper" >/dev/null 2>&1
status=$?
set -e
[[ "$status" == 42 ]] || fail 'raw gws exit status changed'
echo 'gws wrapper tests passed'
