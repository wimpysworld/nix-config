#!/usr/bin/env bash

# slack-post-tests: runnable policy test for slack-post.sh.
#
# The repository has no shell test harness and no flake check wires one, so
# this file is deliberately self-contained and run by hand:
#
#   bash home-manager/_mixins/development/slack/slack-post-tests.sh
#
# It puts a stub `curl` on PATH that records its argv and returns a canned
# Slack response, then runs slack-post.sh under `bash -euo pipefail` so the
# shell options match how writeShellApplication runs it. `jq` is the real one
# from PATH. No request ever leaves the machine.
#
# Exits 0 when every case passes, 1 otherwise.

set -uo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
helper="${script_dir}/slack-post.sh"

if [[ ! -r ${helper} ]]; then
	printf 'slack-post-tests: cannot read %s\n' "${helper}" >&2
	exit 1
fi

work="$(mktemp -d)"
trap 'rm -rf "${work}"' EXIT

# The stub records every argument on its own line, saves the request body, and
# answers with a canned response chosen by the endpoint it was given. The
# conversations.open reply hands back a DM channel so the DM path can run.
stub_dir="${work}/bin"
mkdir -p "${stub_dir}"
cat >"${stub_dir}/curl" <<'STUB'
#!/usr/bin/env bash
set -uo pipefail
: >"${CURL_STUB_ARGV}"
for stub_arg in "$@"; do
	printf '%s\n' "${stub_arg}" >>"${CURL_STUB_ARGV}"
done
cat >"${CURL_STUB_STDIN}"
printf 'call\n' >>"${CURL_STUB_CALLS}"
if printf '%s\n' "$@" | grep -q 'conversations.open'; then
	printf '{"ok":true,"channel":{"id":"D0STUBDM01"}}'
else
	printf '{"ok":true,"channel":"C0STUBCHAN","ts":"1785267943.715149"}'
fi
STUB
chmod +x "${stub_dir}/curl"

export PATH="${stub_dir}:${PATH}"
export CURL_STUB_ARGV="${work}/curl-argv"
export CURL_STUB_STDIN="${work}/curl-stdin"
export CURL_STUB_CALLS="${work}/curl-calls"

token_file="${work}/token"
printf 'xoxp-0-stub-token\n' >"${token_file}"

body_file="${work}/body.md"
printf ':wtb2: hello\n\n\n' >"${body_file}"

empty_file="${work}/empty.md"
: >"${empty_file}"

failures=0

# Run the helper with the shell options writeShellApplication uses. The token
# path is injected the same way the Nix wrapper injects it.
run_helper() {
	: >"${CURL_STUB_CALLS}"
	{
		printf 'set -o errexit -o nounset -o pipefail\n'
		printf 'readonly SLACK_POST_TOKEN_FILE=%q\n' "${1}"
		cat "${helper}"
	} >"${work}/run.sh"
	shift
	bash "${work}/run.sh" "$@" 2>&1
}

# Assert the helper exits with the expected status and its output contains the
# expected fragment.
expect() {
	local label="$1" want_status="$2" want_text="$3"
	shift 3
	local output status
	output="$(run_helper "${token_file}" "$@")"
	status=$?
	if [[ ${status} -ne ${want_status} ]]; then
		printf 'FAIL %s: expected exit %d, got %d\n' "${label}" "${want_status}" "${status}"
		printf '     output: %s\n' "${output}"
		failures=$((failures + 1))
		return
	fi
	if [[ ${output} != *"${want_text}"* ]]; then
		printf 'FAIL %s: expected output to contain %q\n' "${label}" "${want_text}"
		printf '     output: %s\n' "${output}"
		failures=$((failures + 1))
		return
	fi
	printf 'ok   %s\n' "${label}"
}

# Assert the last request body matches a jq test.
expect_payload() {
	local label="$1" filter="$2"
	if [[ $(jq -r "${filter}" <"${work}/last-payload") == "true" ]]; then
		printf 'ok   %s\n' "${label}"
	else
		printf 'FAIL %s: payload did not satisfy %s\n' "${label}" "${filter}"
		printf '     payload: %s\n' "$(cat "${work}/last-payload")"
		failures=$((failures + 1))
	fi
}

# Pull the --data argument out of the recorded argv.
capture_payload() {
	awk '/^--data$/ { getline; print; exit }' "${CURL_STUB_ARGV}" >"${work}/last-payload"
}

printf '== argument policy ==\n'
expect 'help exits 0' 0 'slack-post: post one message' --help
expect 'wrong argument count' 64 'expected 3 or 5 arguments' C0ABEN38TRB
expect 'target may not be a flag' 64 "target may not begin with '-'" -x --body-file "${body_file}"
expect 'second argument must be --body-file' 64 'must be --body-file' C0ABEN38TRB --body "${body_file}"
expect 'glued body flag' 64 'expected 3 or 5 arguments' C0ABEN38TRB "--body-file=${body_file}"
expect 'body file may not be stdin' 64 "body file may not begin with '-'" C0ABEN38TRB --body-file -
expect 'body file must exist' 64 'not a regular file' C0ABEN38TRB --body-file "${work}/missing.md"
expect 'body file must not be empty' 64 'body file is empty' C0ABEN38TRB --body-file "${empty_file}"
expect 'fourth argument must be --thread-ts' 64 'must be --thread-ts' \
	C0ABEN38TRB --body-file "${body_file}" --thread 1785267943.715149
expect 'thread timestamp is validated' 64 'must look like' \
	C0ABEN38TRB --body-file "${body_file}" --thread-ts not-a-ts

printf '== target policy ==\n'
expect 'rejects a bad target' 64 'target must be a channel ID' 'Bad Chan!' --body-file "${body_file}"
expect 'rejects a non-Slack URL' 64 'not a Slack message URL' \
	https://example.com/archives/C0ABEN38TRB/p1785267943715149 --body-file "${body_file}"
expect 'rejects a Slack URL without a message' 64 'not a Slack message URL' \
	https://acme.slack.com/archives/C0ABEN38TRB --body-file "${body_file}"
expect 'rejects --thread-ts with a URL' 64 'not accepted with a URL' \
	https://acme.slack.com/archives/C0ABEN38TRB/p1785267943715149 \
	--body-file "${body_file}" --thread-ts 1785267943.715149

printf '== token policy ==\n'
for pair in \
	'xoxe.xoxp-1-Mi123:app configuration token' \
	'xoxe-1-abc:refresh token' \
	'xoxb-123:bot token' \
	'garbage:not a user OAuth token'; do
	printf '%s\n' "${pair%%:*}" >"${work}/other-token"
	output="$(run_helper "${work}/other-token" C0ABEN38TRB --body-file "${body_file}")"
	if [[ ${output} == *"${pair#*:}"* ]]; then
		printf 'ok   rejects %s\n' "${pair%%:*}"
	else
		printf 'FAIL rejects %s: got %s\n' "${pair%%:*}" "${output}"
		failures=$((failures + 1))
	fi
done

printf '== payload ==\n'
expect 'posts to a channel ID' 0 'ts: 1785267943.715149' C0ABEN38TRB --body-file "${body_file}"
capture_payload
expect_payload 'channel is passed through' '.channel == "C0ABEN38TRB"'
expect_payload 'trailing newlines are trimmed' '.text == ":wtb2: hello"'
expect_payload 'mrkdwn is on so emotes resolve' '.mrkdwn == true'
expect_payload 'no thread_ts on a top-level post' '(.thread_ts // null) == null'

expect 'posts to a channel name' 0 'ts:' '#eng-fulfillment-automation' --body-file "${body_file}"
capture_payload
expect_payload 'channel name is passed through' '.channel == "#eng-fulfillment-automation"'

expect 'replies with an explicit thread' 0 'thread_ts: 1785267943.715149' \
	C0ABEN38TRB --body-file "${body_file}" --thread-ts 1785267943.715149
capture_payload
expect_payload 'explicit thread_ts reaches Slack' '.thread_ts == "1785267943.715149"'

printf '== URL parsing ==\n'
expect 'derives the thread from the path' 0 'thread_ts: 1785267943.715149' \
	https://acme.slack.com/archives/C0ABEN38TRB/p1785267943715149 --body-file "${body_file}"
capture_payload
expect_payload 'channel comes from the path' '.channel == "C0ABEN38TRB"'
expect_payload 'thread comes from the path' '.thread_ts == "1785267943.715149"'

expect 'prefers thread_ts from the query' 0 'thread_ts: 1785200000.111222' \
	'https://acme.slack.com/archives/C0ABEN38TRB/p1785267943715149?thread_ts=1785200000.111222&cid=C0ABEN38TRB' \
	--body-file "${body_file}"
capture_payload
expect_payload 'query thread wins over the path' '.thread_ts == "1785200000.111222"'

printf '== DM path ==\n'
expect 'opens a DM for a user ID' 0 'ts:' U08V6EV65TQ --body-file "${body_file}"
capture_payload
expect_payload 'posts to the opened DM channel' '.channel == "D0STUBDM01"'
if [[ $(wc -l <"${CURL_STUB_CALLS}") -eq 2 ]]; then
	printf 'ok   DM path makes two calls\n'
else
	printf 'FAIL DM path made %s calls, expected 2\n' "$(wc -l <"${CURL_STUB_CALLS}")"
	failures=$((failures + 1))
fi

printf '\n'
if [[ ${failures} -eq 0 ]]; then
	printf 'slack-post-tests: all cases passed\n'
	exit 0
fi
printf 'slack-post-tests: %d case(s) failed\n' "${failures}"
exit 1
