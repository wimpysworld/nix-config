#!/usr/bin/env bash

# gh-review-reply-tests: runnable policy test for gh-review-reply.sh.
#
# The repository has no shell test harness and no flake check wires one, so
# this file is deliberately self-contained and run by hand:
#
#   bash home-manager/_mixins/development/github/gh-review-reply-tests.sh
#
# It puts a stub `gh` on PATH that records its argv and its stdin and exits
# with a status the test controls, then runs gh-review-reply.sh under
# `bash -euo pipefail` so the shell options match how writeShellApplication
# runs it. `jq` is the real one from PATH.
#
# Exits 0 when every case passes, 1 otherwise.

set -uo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
helper="${script_dir}/gh-review-reply.sh"

if [[ ! -r ${helper} ]]; then
	printf 'gh-review-reply-tests: cannot read %s\n' "${helper}" >&2
	exit 1
fi

work="$(mktemp -d)"
trap 'rm -rf "${work}"' EXIT

# The stub records every argument on its own line, saves stdin verbatim,
# appends one line per invocation to a call log, and honours GH_STUB_EXIT so
# a test can make the real `gh` failure path run.
stub_dir="${work}/bin"
mkdir -p "${stub_dir}"
cat >"${stub_dir}/gh" <<'STUB'
#!/usr/bin/env bash
set -uo pipefail
: >"${GH_STUB_ARGV}"
for stub_arg in "$@"; do
	printf '%s\n' "${stub_arg}" >>"${GH_STUB_ARGV}"
done
cat >"${GH_STUB_STDIN}"
printf 'call\n' >>"${GH_STUB_CALLS}"
exit "${GH_STUB_EXIT:-0}"
STUB
chmod +x "${stub_dir}/gh"

export PATH="${stub_dir}:${PATH}"
export GH_STUB_ARGV="${work}/gh-argv"
export GH_STUB_STDIN="${work}/gh-stdin"
export GH_STUB_CALLS="${work}/gh-calls"

# A body that would break naive quoting: a double quote, a backtick, a
# newline, and a leading-dash line. Written with no trailing newline so the
# round-trip comparison is exact.
body_file="${work}/body.md"
# shellcheck disable=SC2016 # The backtick is test data, not a substitution.
printf 'He said "hi" and ran `date`.\nSecond line.\n-- not a flag' >"${body_file}"

status=0
stdout=""
stderr=""
passes=0
failures=0

fail() {
	failures=$((failures + 1))
	printf 'FAIL: %s\n' "$1" >&2
	if [[ -n ${2:-} ]]; then
		printf '      %s\n' "$2" >&2
	fi
}

pass() {
	passes=$((passes + 1))
	printf 'ok: %s\n' "$1"
}

# Runs the helper with a clean stub state. Sets the globals status, stdout,
# and stderr for the assertions that follow.
run_helper() {
	: >"${GH_STUB_ARGV}"
	: >"${GH_STUB_STDIN}"
	: >"${GH_STUB_CALLS}"
	stdout="$(bash -euo pipefail "${helper}" "$@" 2>"${work}/stderr")"
	status=$?
	stderr="$(cat "${work}/stderr")"
}

gh_call_count() {
	grep -c . "${GH_STUB_CALLS}"
}

# Asserts that a policy violation exits 64 and never reaches the stub `gh`.
assert_policy() {
	local label="$1"
	shift
	run_helper "$@"
	if [[ ${status} -ne 64 ]]; then
		fail "${label}" "expected exit 64, got ${status}"
		return
	fi
	if [[ "$(gh_call_count)" -ne 0 ]]; then
		fail "${label}" "gh was called despite the policy rejection"
		return
	fi
	pass "${label}"
}

assert_policy 'endpoint path as OWNER' \
	'repos/o/r/pulls/1/comments' repo 1 2 --body-file "${body_file}"
assert_policy 'traversal owner' \
	'..' repo 1 2 --body-file "${body_file}"
assert_policy 'endpoint path as REPO' \
	owner 'r/pulls/1/comments' 1 2 --body-file "${body_file}"
assert_policy '--method POST in a validated position' \
	owner repo --method POST --body-file "${body_file}"
# A flag-like token in the OWNER or REPO position still matches the name
# pattern ^[A-Za-z0-9._-]+$, so only the flag rejection stops these.
assert_policy '--method as OWNER' \
	--method POST 1 2 --body-file "${body_file}"
assert_policy '-X as OWNER' \
	-X POST 1 2 --body-file "${body_file}"
assert_policy '-F as REPO' \
	owner -F 1 2 --body-file "${body_file}"
assert_policy '--field as REPO' \
	owner --field 1 2 --body-file "${body_file}"
assert_policy '--input as OWNER' \
	--input - 1 2 --body-file "${body_file}"
assert_policy '--method POST appended' \
	owner repo 1 2 --body-file "${body_file}" --method POST
assert_policy '-X POST in a validated position' \
	owner repo -X POST --body-file "${body_file}"
assert_policy '-F body=@x' \
	owner repo -F 'body=@x' --body-file "${body_file}"
assert_policy '--field body=@x' \
	owner repo --field 'body=@x' --body-file "${body_file}"
assert_policy '--input -' \
	owner repo --input - --body-file "${body_file}"
assert_policy 'body path of -' \
	owner repo 1 2 --body-file -
assert_policy 'glued --body-file=PATH' \
	owner repo 1 2 "--body-file=${body_file}" extra
assert_policy 'non-numeric pull number' \
	owner repo abc 2 --body-file "${body_file}"
assert_policy 'non-numeric comment id' \
	owner repo 1 12a --body-file "${body_file}"
assert_policy 'missing body file' \
	owner repo 1 2 --body-file "${work}/does-not-exist"
assert_policy 'body file is a directory' \
	owner repo 1 2 --body-file "${work}"
assert_policy 'too few arguments' \
	owner repo 1 2 --body-file
assert_policy 'too many arguments' \
	owner repo 1 2 --body-file "${body_file}" 7
assert_policy 'flag missing from the fifth position' \
	owner repo 1 2 "${body_file}" extra

# --help exits 0 and prints the usage text.
run_helper --help
if [[ ${status} -ne 0 ]]; then
	fail '--help exits 0' "got ${status}"
elif [[ ${stdout} != *"USAGE"* || ${stdout} != *"gh-review-reply OWNER REPO PR_NUMBER COMMENT_ID --body-file PATH"* ]]; then
	fail '--help exits 0' 'usage text missing from stdout'
else
	pass '--help exits 0 and prints usage'
fi

# Happy path: one gh call, exact argv, and a body that round-trips.
run_helper owner repo 42 987654 --body-file "${body_file}"
if [[ ${status} -ne 0 ]]; then
	fail 'happy path exits 0' "got ${status}: ${stderr}"
else
	pass 'happy path exits 0'
fi

if [[ "$(gh_call_count)" -ne 1 ]]; then
	fail 'happy path calls gh exactly once' "call count $(gh_call_count)"
else
	pass 'happy path calls gh exactly once'
fi

expected_argv="${work}/expected-argv"
printf '%s\n' \
	api \
	--method \
	POST \
	'repos/owner/repo/pulls/42/comments/987654/replies' \
	--input \
	- >"${expected_argv}"
if ! cmp -s "${expected_argv}" "${GH_STUB_ARGV}"; then
	fail 'happy path gh argv' "got: $(tr '\n' ' ' <"${GH_STUB_ARGV}")"
else
	pass 'happy path gh argv is api --method POST <path> --input -'
fi

# The payload must be an object whose only key is `body`.
payload_keys="$(jq -c 'keys' <"${GH_STUB_STDIN}" 2>/dev/null)"
if [[ ${payload_keys} != '["body"]' ]]; then
	fail 'payload is {"body": ...}' "keys: ${payload_keys:-<invalid JSON>}"
else
	pass 'payload is a JSON object with only a body key'
fi

# The body value must be a JSON string that round-trips byte for byte.
payload_type="$(jq -r '.body | type' <"${GH_STUB_STDIN}" 2>/dev/null)"
if [[ ${payload_type} != string ]]; then
	fail 'body is a JSON string' "type: ${payload_type:-<invalid JSON>}"
else
	pass 'body is a JSON string'
fi

jq -j '.body' <"${GH_STUB_STDIN}" >"${work}/round-trip" 2>/dev/null
if ! cmp -s "${body_file}" "${work}/round-trip"; then
	fail 'body round-trips byte for byte' "$(cmp "${body_file}" "${work}/round-trip" 2>&1)"
else
	pass 'body with a quote, a backtick, and a newline round-trips byte for byte'
fi

# A failed request exits with gh's own status, not the policy status.
GH_STUB_EXIT=22 run_helper owner repo 42 987654 --body-file "${body_file}"
if [[ ${status} -ne 22 ]]; then
	fail 'gh failure exits with gh status' "expected 22, got ${status}"
elif [[ ${stderr} != *987654* ]]; then
	fail 'gh failure names the comment id' "stderr: ${stderr}"
else
	pass 'gh exiting 22 makes the helper exit 22 and name the comment id'
fi

printf '%s: %s passed, %s failed\n' \
	"$([[ ${failures} -eq 0 ]] && printf PASS || printf FAIL)" \
	"${passes}" "${failures}"
[[ ${failures} -eq 0 ]]
