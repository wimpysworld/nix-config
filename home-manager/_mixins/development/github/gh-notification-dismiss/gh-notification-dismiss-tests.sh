#!/usr/bin/env bash

# gh-notification-dismiss-tests: runnable policy and execution test suite for
# gh-notification-dismiss.
#
# Can be run standalone:
#   bash home-manager/_mixins/development/github/gh-notification-dismiss/gh-notification-dismiss-tests.sh
# or from Nix checkPhase with the built executable passed as $1.

set -uo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
target_bin="${1:-}"
helper_script="${script_dir}/gh-notification-dismiss.sh"

if [[ -z ${target_bin} && ! -r ${helper_script} ]]; then
	printf 'gh-notification-dismiss-tests: cannot read %s\n' "${helper_script}" >&2
	exit 1
fi

work="$(mktemp -d)"
trap 'rm -rf "${work}"' EXIT

stub_dir="${work}/bin"
state_dir="${work}/state"
mkdir -p "${stub_dir}" "${state_dir}"

cat >"${stub_dir}/gh" <<EOF
#!${BASH}
EOF
cat >>"${stub_dir}/gh" <<'STUB'
set -uo pipefail

call_num=$(($(wc -l <"${GH_STUB_STATE}/calls") + 1))
printf '%s\n' "$*" >>"${GH_STUB_STATE}/calls"
: >"${GH_STUB_STATE}/argv-${call_num}"
for arg in "$@"; do
	printf '%s\n' "${arg}" >>"${GH_STUB_STATE}/argv-${call_num}"
done

if [[ $# -eq 4 && $1 == "api" && $2 == "--method" ]]; then
	exit "${GH_STUB_API_EXIT:-0}"
fi

printf 'unexpected gh stub invocation: %s\n' "$*" >&2
exit 99
STUB
chmod +x "${stub_dir}/gh"

export PATH="${stub_dir}:${PATH}"
export GH_NOTIFICATION_DISMISS_GH_BIN="${stub_dir}/gh"
export GH_STUB_STATE="${state_dir}"

passes=0
failures=0
status=0
stdout=""
stderr=""

pass() {
	passes=$((passes + 1))
	printf 'ok: %s\n' "$1"
}

fail() {
	failures=$((failures + 1))
	printf 'FAIL: %s\n' "$1" >&2
	if [[ -n ${2:-} ]]; then
		printf '      %s\n' "$2" >&2
	fi
}

reset_stub() {
	rm -f "${state_dir}"/*
	: >"${state_dir}/calls"
}

run_helper() {
	if [[ -n ${target_bin} ]]; then
		stdout="$("${target_bin}" "$@" 2>"${work}/stderr")"
		status=$?
	else
		stdout="$(bash -euo pipefail "${helper_script}" "$@" 2>"${work}/stderr")"
		status=$?
	fi
	stderr="$(cat "${work}/stderr")"
}

call_count() {
	wc -l <"${state_dir}/calls" | tr -d ' '
}

assert_cli_rejected() {
	local label="$1"
	shift
	reset_stub
	run_helper "$@"
	if [[ ${status} -ne 64 ]]; then
		fail "${label}" "expected exit 64, got ${status}: ${stderr}"
	elif [[ $(call_count) -ne 0 ]]; then
		fail "${label}" "gh was called despite CLI policy rejection"
	else
		pass "${label}"
	fi
}

# 1. --help and CLI argument checks
reset_stub
run_helper --help
if [[ ${status} -ne 0 || ${stdout} != *"USAGE"* || $(call_count) -ne 0 ]]; then
	fail '--help prints usage and exits 0' "status=${status}"
else
	pass '--help prints usage and exits 0'
fi

reset_stub
run_helper -h
if [[ ${status} -ne 0 || ${stdout} != *"USAGE"* || $(call_count) -ne 0 ]]; then
	fail '-h prints usage and exits 0' "status=${status}"
else
	pass '-h prints usage and exits 0'
fi

assert_cli_rejected 'no arguments'
assert_cli_rejected 'too many arguments' --read 12345 extra
assert_cli_rejected 'reordered --read after thread-id' 12345 --read
assert_cli_rejected 'unknown flag' --done 12345
assert_cli_rejected 'flag as thread-id' --read
assert_cli_rejected 'zero thread-id' 0
assert_cli_rejected 'leading-zero thread-id' 012345
assert_cli_rejected 'negative thread-id' -12345
assert_cli_rejected 'alphabetic thread-id' abcdef
assert_cli_rejected 'alphanumeric thread-id' 123a45
assert_cli_rejected 'slash in thread-id' '12345/subscription'
assert_cli_rejected 'dot in thread-id' '123.45'
assert_cli_rejected 'dot-dot traversal' '..'
assert_cli_rejected 'query string in thread-id' '12345?all=true'

# 2. Default mode (mark as done via DELETE)
reset_stub
run_helper 987654321
if [[ ${status} -ne 0 ]]; then
	fail 'default mode marks thread as done' "status=${status} stderr=${stderr}"
elif [[ $(call_count) -ne 1 ]]; then
	fail 'default mode calls gh once' "calls=$(call_count)"
elif [[ "$(cat "${state_dir}/calls")" != "api --method DELETE notifications/threads/987654321" ]]; then
	fail 'default mode calls DELETE notifications/threads/<id>' "got: $(cat "${state_dir}/calls")"
elif [[ ${stdout} != "gh-notification-dismiss: marked thread 987654321 as done." ]]; then
	fail 'default mode prints confirmation' "got: ${stdout}"
else
	pass 'default mode calls DELETE notifications/threads/<id> and confirms done'
fi

# 3. --read mode (mark as read via PATCH)
reset_stub
run_helper --read 987654321
if [[ ${status} -ne 0 ]]; then
	fail '--read mode marks thread as read' "status=${status} stderr=${stderr}"
elif [[ $(call_count) -ne 1 ]]; then
	fail '--read mode calls gh once' "calls=$(call_count)"
elif [[ "$(cat "${state_dir}/calls")" != "api --method PATCH notifications/threads/987654321" ]]; then
	fail '--read mode calls PATCH notifications/threads/<id>' "got: $(cat "${state_dir}/calls")"
elif [[ ${stdout} != "gh-notification-dismiss: marked thread 987654321 as read." ]]; then
	fail '--read mode prints confirmation' "got: ${stdout}"
else
	pass '--read mode calls PATCH notifications/threads/<id> and confirms read'
fi

# 4. Preserve gh failure exit code
reset_stub
GH_STUB_API_EXIT=1 run_helper 987654321
if [[ ${status} -ne 1 ]]; then
	fail 'propagates non-zero gh exit code' "expected 1, got ${status}"
elif [[ ${stderr} != *"gh exited 1 while marking thread 987654321 as done."* ]]; then
	fail 'reports gh failure on stderr' "got: ${stderr}"
else
	pass 'propagates non-zero gh exit status on API failure'
fi

printf '%s: %s passed, %s failed\n' \
	"$([[ ${failures} -eq 0 ]] && printf PASS || printf FAIL)" \
	"${passes}" "${failures}"
[[ ${failures} -eq 0 ]]
