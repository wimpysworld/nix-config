#!/usr/bin/env bash

# gh-review-resolve-tests: runnable policy test for gh-review-resolve.sh.
#
# The repository has no shell test harness and no flake check wires one, so
# this file is deliberately self-contained and run by hand:
#
#   bash home-manager/_mixins/development/github/gh-review-resolve-tests.sh
#
# It puts a stub `gh` on PATH that records its argv, replies with canned
# GraphQL JSON chosen by the call number, and exits with a status the test
# controls, then runs gh-review-resolve.sh under `bash -euo pipefail` so the
# shell options match how writeShellApplication runs it. `jq` is the real one
# from PATH.
#
# Exits 0 when every case passes, 1 otherwise.

set -uo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
helper="${script_dir}/gh-review-resolve.sh"

if [[ ! -r ${helper} ]]; then
	printf 'gh-review-resolve-tests: cannot read %s\n' "${helper}" >&2
	exit 1
fi

work="$(mktemp -d)"
trap 'rm -rf "${work}"' EXIT

# The stub numbers each invocation, records its argv in argv-<n>, prints
# response-<n> when the test wrote one, and honours GH_STUB_EXIT so the real
# `gh` failure path can run. Arguments are recorded with `printf %q` so a
# multi-line GraphQL document stays on a single line of the record.
stub_dir="${work}/bin"
mkdir -p "${stub_dir}"
cat >"${stub_dir}/gh" <<'STUB'
#!/usr/bin/env bash
set -uo pipefail
stub_call=$(($(wc -l <"${GH_STUB_DIR}/calls") + 1))
printf 'call\n' >>"${GH_STUB_DIR}/calls"
: >"${GH_STUB_DIR}/argv-${stub_call}"
for stub_arg in "$@"; do
	printf '%q\n' "${stub_arg}" >>"${GH_STUB_DIR}/argv-${stub_call}"
done
if [[ -r "${GH_STUB_DIR}/response-${stub_call}" ]]; then
	cat "${GH_STUB_DIR}/response-${stub_call}"
fi
exit "${GH_STUB_EXIT:-0}"
STUB
chmod +x "${stub_dir}/gh"

export PATH="${stub_dir}:${PATH}"
export GH_STUB_DIR="${work}/stub"
mkdir -p "${GH_STUB_DIR}"

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

# Clears every recorded call and every canned reply. Response-driven tests
# call this first, then write the replies they need.
reset_stub() {
	rm -f "${GH_STUB_DIR}"/argv-* "${GH_STUB_DIR}"/response-*
	: >"${GH_STUB_DIR}/calls"
}

# Runs the helper. Sets the globals status, stdout, and stderr for the
# assertions that follow.
run_helper() {
	stdout="$(bash -euo pipefail "${helper}" "$@" 2>"${work}/stderr")"
	status=$?
	stderr="$(cat "${work}/stderr")"
}

gh_call_count() {
	wc -l <"${GH_STUB_DIR}/calls" | tr -d ' '
}

# One review thread, with the comment ids it holds.
thread_node() {
	local id="$1" resolved="$2" has_next="$3" end_cursor="$4"
	shift 4
	local nodes="" sep=""
	local comment_id
	for comment_id in "$@"; do
		nodes+="${sep}{\"databaseId\":${comment_id}}"
		sep=","
	done
	printf '{"id":"%s","isResolved":%s,"comments":{"pageInfo":{"hasNextPage":%s,"endCursor":"%s"},"nodes":[%s]}}' \
		"${id}" "${resolved}" "${has_next}" "${end_cursor}" "${nodes}"
}

# One page of the review threads query.
threads_page() {
	local has_next="$1" end_cursor="$2"
	shift 2
	local nodes="" sep="" node
	for node in "$@"; do
		nodes+="${sep}${node}"
		sep=","
	done
	printf '{"data":{"repository":{"pullRequest":{"reviewThreads":{"pageInfo":{"hasNextPage":%s,"endCursor":"%s"},"nodes":[%s]}}}}}\n' \
		"${has_next}" "${end_cursor}" "${nodes}"
}

# One page of the follow-up comments query for a single thread.
comments_page() {
	local id="$1" resolved="$2" has_next="$3" end_cursor="$4"
	shift 4
	local nodes="" sep="" comment_id
	for comment_id in "$@"; do
		nodes+="${sep}{\"databaseId\":${comment_id}}"
		sep=","
	done
	printf '{"data":{"node":{"id":"%s","isResolved":%s,"comments":{"pageInfo":{"hasNextPage":%s,"endCursor":"%s"},"nodes":[%s]}}}}\n' \
		"${id}" "${resolved}" "${has_next}" "${end_cursor}" "${nodes}"
}

# The reply to the resolveReviewThread mutation.
resolve_reply() {
	printf '{"data":{"resolveReviewThread":{"thread":{"id":"%s","isResolved":true}}}}\n' "$1"
}

# Asserts that a policy violation exits 64 and never reaches the stub `gh`.
assert_policy() {
	local label="$1"
	shift
	reset_stub
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

url='https://github.com/owner/repo/pull/42#discussion_r987654'

# Argument policy. The URL is the only accepted argument, so every flag-like
# token is refused and there is no second argument to carry one.
assert_policy 'no arguments'
assert_policy '--method as the URL' --method
assert_policy '-X as the URL' -X
assert_policy '-F as the URL' -F
assert_policy '-f as the URL' -f
assert_policy '--field as the URL' --field
assert_policy '--input as the URL' --input
assert_policy '--jq as the URL' --jq
assert_policy '--method POST appended' "${url}" --method POST
assert_policy '-X POST appended' "${url}" -X POST
assert_policy '-f query= appended' "${url}" -f 'query=mutation{x}'
assert_policy 'a second URL appended' "${url}" "${url}"

# URL parsing. Scheme and host are fixed, and every component comes out of
# the URL, so nothing else can name the thread.
assert_policy 'http scheme' \
	'http://github.com/owner/repo/pull/42#discussion_r987654'
assert_policy 'non-GitHub host' \
	'https://gitlab.com/owner/repo/pull/42#discussion_r987654'
assert_policy 'GitHub Enterprise host' \
	'https://github.example.com/owner/repo/pull/42#discussion_r987654'
assert_policy 'API host' \
	'https://api.github.com/repos/owner/repo/pulls/42#discussion_r987654'
assert_policy 'issuecomment fragment' \
	'https://github.com/owner/repo/pull/42#issuecomment-2109876543'
assert_policy 'missing fragment' \
	'https://github.com/owner/repo/pull/42'
assert_policy 'unrecognised fragment' \
	'https://github.com/owner/repo/pull/42#diff-0a1b2c3d'
assert_policy 'empty fragment' \
	'https://github.com/owner/repo/pull/42#'
assert_policy 'non-numeric comment id in the fragment' \
	'https://github.com/owner/repo/pull/42#discussion_r12a'
assert_policy 'issues URL rather than pull' \
	'https://github.com/owner/repo/issues/42#discussion_r987654'
assert_policy 'repository root URL' \
	'https://github.com/owner/repo#discussion_r987654'
assert_policy 'non-numeric pull number' \
	'https://github.com/owner/repo/pull/abc#discussion_r987654'
assert_policy 'dot owner' \
	'https://github.com/./repo/pull/42#discussion_r987654'
assert_policy 'dot repository' \
	'https://github.com/owner/./pull/42#discussion_r987654'
assert_policy 'traversal owner' \
	'https://github.com/../repo/pull/42#discussion_r987654'
assert_policy 'traversal repository' \
	'https://github.com/owner/../pull/42#discussion_r987654'
assert_policy 'percent-encoded slash in the owner' \
	'https://github.com/o%2Fw/repo/pull/42#discussion_r987654'

# --help exits 0 and prints the usage text.
reset_stub
run_helper --help
if [[ ${status} -ne 0 ]]; then
	fail '--help exits 0' "got ${status}"
elif [[ ${stdout} != *"USAGE"* || ${stdout} != *"gh-review-resolve <review-comment-url>"* ]]; then
	fail '--help exits 0' 'usage text missing from stdout'
else
	pass '--help exits 0 and prints usage'
fi

# Happy path. The URL names the second comment of the thread, so the lookup
# must match every comment rather than the first.
reset_stub
threads_page false '' \
	"$(thread_node PRRT_other false false '' 111 222)" \
	"$(thread_node PRRT_kw1 false false '' 333 987654)" >"${GH_STUB_DIR}/response-1"
resolve_reply PRRT_kw1 >"${GH_STUB_DIR}/response-2"
run_helper "${url}"
if [[ ${status} -ne 0 ]]; then
	fail 'happy path exits 0' "got ${status}: ${stderr}"
elif [[ "$(gh_call_count)" -ne 2 ]]; then
	fail 'happy path makes one query and one mutation' "call count $(gh_call_count)"
elif [[ ${stdout} != *"resolved review thread PRRT_kw1"* ]]; then
	fail 'happy path reports the thread it resolved' "stdout: ${stdout}"
else
	pass 'happy path matches a later comment in the thread and exits 0'
fi

# The lookup sends the owner, the repository, and the pull request number as
# GraphQL variables, never as query text.
if ! grep -qx 'api' "${GH_STUB_DIR}/argv-1" || ! grep -qx 'graphql' "${GH_STUB_DIR}/argv-1"; then
	fail 'lookup calls gh api graphql' "got: $(tr '\n' ' ' <"${GH_STUB_DIR}/argv-1")"
elif ! grep -qx 'owner=owner' "${GH_STUB_DIR}/argv-1" ||
	! grep -qx 'name=repo' "${GH_STUB_DIR}/argv-1" ||
	! grep -qx 'pr=42' "${GH_STUB_DIR}/argv-1"; then
	fail 'lookup passes typed variables' "got: $(tr '\n' ' ' <"${GH_STUB_DIR}/argv-1")"
elif grep 'query=' "${GH_STUB_DIR}/argv-1" | grep -q '987654'; then
	fail 'lookup keeps the comment id out of the query text' 'comment id found in the query'
else
	pass 'lookup passes owner, repository, and pull request number as variables'
fi

# The mutation names the thread found by the lookup and takes nothing else.
if ! grep -q 'resolveReviewThread' "${GH_STUB_DIR}/argv-2"; then
	fail 'mutation calls resolveReviewThread' "got: $(tr '\n' ' ' <"${GH_STUB_DIR}/argv-2")"
elif ! grep -qx 'threadId=PRRT_kw1' "${GH_STUB_DIR}/argv-2"; then
	fail 'mutation passes the thread id as a variable' "got: $(tr '\n' ' ' <"${GH_STUB_DIR}/argv-2")"
elif grep 'query=' "${GH_STUB_DIR}/argv-2" | grep -q 'PRRT_kw1'; then
	fail 'mutation keeps the thread id out of the query text' 'thread id found in the mutation text'
else
	pass 'mutation sends the thread id as a typed variable'
fi

# The files tab anchor names the same comment as the conversation tab anchor.
reset_stub
threads_page false '' \
	"$(thread_node PRRT_kw1 false false '' 987654)" >"${GH_STUB_DIR}/response-1"
resolve_reply PRRT_kw1 >"${GH_STUB_DIR}/response-2"
run_helper 'https://github.com/owner/repo/pull/42/files#r987654'
if [[ ${status} -ne 0 ]]; then
	fail 'files tab anchor is accepted' "got ${status}: ${stderr}"
else
	pass 'files tab anchor resolves the same thread'
fi

# An already resolved thread is reported and exits 0, so the helper is safe
# to re-run. The mutation must not be sent.
reset_stub
threads_page false '' \
	"$(thread_node PRRT_kw1 true false '' 987654)" >"${GH_STUB_DIR}/response-1"
run_helper "${url}"
if [[ ${status} -ne 0 ]]; then
	fail 'already resolved exits 0' "got ${status}: ${stderr}"
elif [[ "$(gh_call_count)" -ne 1 ]]; then
	fail 'already resolved sends no mutation' "call count $(gh_call_count)"
elif [[ ${stdout} != *"already resolved"* ]]; then
	fail 'already resolved says so' "stdout: ${stdout}"
else
	pass 'already resolved thread exits 0 without sending the mutation'
fi

# A comment id that is on no thread is a policy violation, not a request
# failure, so it exits 64 after the lookup.
reset_stub
threads_page false '' \
	"$(thread_node PRRT_other false false '' 111)" >"${GH_STUB_DIR}/response-1"
run_helper "${url}"
if [[ ${status} -ne 64 ]]; then
	fail 'unknown comment id exits 64' "got ${status}: ${stderr}"
elif [[ ${stderr} != *987654* ]]; then
	fail 'unknown comment id names the comment' "stderr: ${stderr}"
elif [[ "$(gh_call_count)" -ne 1 ]]; then
	fail 'unknown comment id sends no mutation' "call count $(gh_call_count)"
else
	pass 'comment id on no thread exits 64 without sending the mutation'
fi

# A pull request can hold more review threads than one page returns, so the
# lookup must follow the thread cursor.
reset_stub
threads_page true 'T1' \
	"$(thread_node PRRT_other false false '' 111)" >"${GH_STUB_DIR}/response-1"
threads_page false '' \
	"$(thread_node PRRT_kw2 false false '' 987654)" >"${GH_STUB_DIR}/response-2"
resolve_reply PRRT_kw2 >"${GH_STUB_DIR}/response-3"
run_helper "${url}"
if [[ ${status} -ne 0 ]]; then
	fail 'second thread page is read' "got ${status}: ${stderr}"
elif ! grep -qx 'cursor=T1' "${GH_STUB_DIR}/argv-2"; then
	fail 'second thread page uses the thread cursor' "got: $(tr '\n' ' ' <"${GH_STUB_DIR}/argv-2")"
elif ! grep -qx 'threadId=PRRT_kw2' "${GH_STUB_DIR}/argv-3"; then
	fail 'second thread page resolves the matched thread' "got: $(tr '\n' ' ' <"${GH_STUB_DIR}/argv-3")"
else
	pass 'a comment on the second thread page is found and resolved'
fi

# A thread can hold more comments than one page returns, so the lookup must
# follow the comment cursor of every thread that has one.
reset_stub
threads_page false '' \
	"$(thread_node PRRT_kw3 false true 'C1' 111)" >"${GH_STUB_DIR}/response-1"
comments_page PRRT_kw3 false false '' 987654 >"${GH_STUB_DIR}/response-2"
resolve_reply PRRT_kw3 >"${GH_STUB_DIR}/response-3"
run_helper "${url}"
if [[ ${status} -ne 0 ]]; then
	fail 'second comment page is read' "got ${status}: ${stderr}"
elif ! grep -qx 'threadId=PRRT_kw3' "${GH_STUB_DIR}/argv-2" ||
	! grep -qx 'cursor=C1' "${GH_STUB_DIR}/argv-2"; then
	fail 'second comment page uses the comment cursor' "got: $(tr '\n' ' ' <"${GH_STUB_DIR}/argv-2")"
elif ! grep -qx 'threadId=PRRT_kw3' "${GH_STUB_DIR}/argv-3"; then
	fail 'second comment page resolves the matched thread' "got: $(tr '\n' ' ' <"${GH_STUB_DIR}/argv-3")"
else
	pass 'a comment on the second comment page is found and resolved'
fi

# A failed request exits with gh's own status, not the policy status.
reset_stub
GH_STUB_EXIT=22 run_helper "${url}"
if [[ ${status} -ne 22 ]]; then
	fail 'gh failure exits with gh status' "expected 22, got ${status}"
elif [[ ${stderr} != *"gh exited 22"* ]]; then
	fail 'gh failure reports the status' "stderr: ${stderr}"
else
	pass 'gh exiting 22 makes the helper exit 22'
fi

printf '%s: %s passed, %s failed\n' \
	"$([[ ${failures} -eq 0 ]] && printf PASS || printf FAIL)" \
	"${passes}" "${failures}"
[[ ${failures} -eq 0 ]]
