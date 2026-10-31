#!/usr/bin/env bash

# gh-review-inline-tests: runnable policy and execution test suite for
# gh-review-inline.

set -uo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
target_bin="${1:-}"
helper_script="${script_dir}/gh-review-inline.sh"

if [[ -z ${target_bin} && ! -r ${helper_script} ]]; then
	printf 'gh-review-inline-tests: cannot read %s\n' "${helper_script}" >&2
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

if [[ $# -eq 4 && $1 == "api" && $2 == repos/*/*/"pulls/"* && $3 == "--jq" ]]; then
	if [[ -r "${GH_STUB_STATE}/head-exit" ]]; then
		exit "$(cat "${GH_STUB_STATE}/head-exit")"
	fi
	printf '%s\n' "${GH_STUB_HEAD_SHA:-f38afe1c3262f023814aa4411678363480db2492}"
	exit 0
fi

if [[ $# -eq 6 && $1 == "api" && $2 == "--method" && $3 == "POST" && $4 == repos/*/*/"pulls/"*"/reviews" && $5 == "--input" && $6 == "-" ]]; then
	cat >"${GH_STUB_STATE}/stdin-${call_num}"
	if [[ -r "${GH_STUB_STATE}/post-exit" ]]; then
		exit "$(cat "${GH_STUB_STATE}/post-exit")"
	fi
	printf '{"id":999,"state":"COMMENTED"}\n'
	exit 0
fi

printf 'unexpected gh stub invocation: %s\n' "$*" >&2
exit 99
STUB
chmod +x "${stub_dir}/gh"

export PATH="${stub_dir}:${PATH}"
export GH_REVIEW_INLINE_GH_BIN="${stub_dir}/gh"
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

assert_rejected() {
	local label="$1"
	local needle="$2"
	shift 2
	reset_stub
	run_helper "$@"
	if [[ ${status} -ne 64 ]]; then
		fail "${label}" "expected exit 64, got ${status} (stderr: ${stderr})"
	elif [[ ${stderr} != *"${needle}"* ]]; then
		fail "${label}" "stderr '${stderr}' did not contain '${needle}'"
	elif [[ $(call_count) -ne 0 ]]; then
		fail "${label}" "gh was called $(call_count) time(s) on a policy rejection"
	else
		pass "${label}"
	fi
}

readonly PR_URL="https://github.com/wimpysworld/nix-config/pull/1136"
readonly HEAD_SHA="f38afe1c3262f023814aa4411678363480db2492"

finding1="${work}/finding-1.md"
finding2="${work}/finding-2.md"
summary_file="${work}/summary.md"
empty_file="${work}/empty.md"
# shellcheck disable=SC2016
printf '%s\n' 'In `cauldron.js:133`, read top-level `name` and `version` fields.' >"${finding1}"
# shellcheck disable=SC2016
printf '%s\n' 'In `cauldron.css:326`, define `--card-color` on each `.card-*` class.' >"${finding2}"
printf '%s\n' '@flexiondotorg Inline findings attached.' >"${summary_file}"
: >"${empty_file}"

# 1. --help
reset_stub
run_helper --help
if [[ ${status} -eq 0 && ${stdout} == *"USAGE"* ]]; then
	pass "--help exits 0 and prints usage"
else
	fail "--help exits 0 and prints usage" "status=${status}"
fi

# 2. Argument validation rejections
assert_rejected "reject no arguments" "expected <pr-url>"
assert_rejected "reject glued --commit=" "glued flag" \
	"${PR_URL}" "--commit=${HEAD_SHA}" --comment "a.nix:1" --comment-file "${finding1}"
assert_rejected "reject glued --comment-file=" "glued flag" \
	"${PR_URL}" --commit "${HEAD_SHA}" --comment "a.nix:1" "--comment-file=${finding1}"
assert_rejected "reject non-PR URL" "must match https://github.com/" \
	"https://github.com/wimpysworld/nix-config/issues/1136" --commit "${HEAD_SHA}" --comment "a.nix:1" --comment-file "${finding1}"
assert_rejected "reject missing --commit" "--commit <40-hex-sha> is required" \
	"${PR_URL}" --comment "a.nix:1" --comment-file "${finding1}"
assert_rejected "reject short --commit SHA" "40-character hexadecimal" \
	"${PR_URL}" --commit "f38afe1c" --comment "a.nix:1" --comment-file "${finding1}"
assert_rejected "reject REQUEST_CHANGES event" "REQUEST_CHANGES" \
	"${PR_URL}" --commit "${HEAD_SHA}" --event REQUEST_CHANGES --comment "a.nix:1" --comment-file "${finding1}"
assert_rejected "reject missing --comment pairs" "at least one --comment" \
	"${PR_URL}" --commit "${HEAD_SHA}"
assert_rejected "reject --comment without --comment-file" "missing --comment-file" \
	"${PR_URL}" --commit "${HEAD_SHA}" --comment "a.nix:1"
assert_rejected "reject orphan --comment-file" "must immediately follow" \
	"${PR_URL}" --commit "${HEAD_SHA}" --comment-file "${finding1}"
assert_rejected "reject absolute path in --comment" "clean relative repository path" \
	"${PR_URL}" --commit "${HEAD_SHA}" --comment "/etc/passwd:1" --comment-file "${finding1}"
assert_rejected "reject parent traversal in --comment" "path segments" \
	"${PR_URL}" --commit "${HEAD_SHA}" --comment "a/../b.nix:1" --comment-file "${finding1}"
assert_rejected "reject zero line number in --comment" "must match <repo-path>:<line>" \
	"${PR_URL}" --commit "${HEAD_SHA}" --comment "a.nix:0" --comment-file "${finding1}"
assert_rejected "reject inverted range in --comment" "start-line < end-line" \
	"${PR_URL}" --commit "${HEAD_SHA}" --comment "a.nix:20-10" --comment-file "${finding1}"
assert_rejected "reject empty --comment-file" "must not be empty" \
	"${PR_URL}" --commit "${HEAD_SHA}" --comment "a.nix:10" --comment-file "${empty_file}"
assert_rejected "reject stdin '-' as --comment-file" "flag-like argument '-'" \
	"${PR_URL}" --commit "${HEAD_SHA}" --comment "a.nix:10" --comment-file -

# 3. Head SHA mismatch rejection
reset_stub
GH_STUB_HEAD_SHA="0000000000000000000000000000000000000000" run_helper \
	"${PR_URL}" --commit "${HEAD_SHA}" --comment "a.nix:10" --comment-file "${finding1}"
if [[ ${status} -eq 64 && ${stderr} == *"head SHA moved"* && $(call_count) -eq 1 ]]; then
	pass "reject when pull request head SHA moved before posting"
else
	fail "reject when pull request head SHA moved before posting" "status=${status} calls=$(call_count) stderr=${stderr}"
fi

# 4. Successful multi-comment submission with single-line and range specs
reset_stub
run_helper "${PR_URL}" \
	--commit "${HEAD_SHA}" \
	--event COMMENT \
	--body-file "${summary_file}" \
	--comment "nixos/_mixins/server/private-matrix/cauldron.js:133" \
	--comment-file "${finding1}" \
	--comment "nixos/_mixins/server/private-matrix/cauldron.css:315-326" \
	--comment-file "${finding2}"

if [[ ${status} -ne 0 ]]; then
	fail "submit multi-comment inline review" "status=${status} stderr=${stderr}"
elif [[ $(call_count) -ne 2 ]]; then
	fail "submit multi-comment inline review call count" "calls=$(call_count)"
else
	posted="${state_dir}/stdin-2"
	if jq -e \
		--arg sha "${HEAD_SHA}" \
		'.commit_id == $sha
		and .event == "COMMENT"
		and (.body | startswith("@flexiondotorg"))
		and (.comments | length) == 2
		and .comments[0].path == "nixos/_mixins/server/private-matrix/cauldron.js"
		and .comments[0].line == 133
		and .comments[0].side == "RIGHT"
		and (.comments[0] | has("start_line") | not)
		and .comments[1].path == "nixos/_mixins/server/private-matrix/cauldron.css"
		and .comments[1].start_line == 315
		and .comments[1].start_side == "RIGHT"
		and .comments[1].line == 326
		and .comments[1].side == "RIGHT"' "${posted}" >/dev/null; then
		pass "submit multi-comment inline review encodes single-line and range comments"
	else
		fail "submit multi-comment inline review payload" "$(cat "${posted}")"
	fi
fi

if [[ ${failures} -gt 0 ]]; then
	printf 'FAIL: %s passed, %s failed\n' "${passes}" "${failures}" >&2
	exit 1
fi
printf 'PASS: %s passed, 0 failed\n' "${passes}"
