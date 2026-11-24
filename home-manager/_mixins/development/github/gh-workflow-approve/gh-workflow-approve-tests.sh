#!/usr/bin/env bash

# gh-workflow-approve-tests: runnable policy and execution test suite for
# gh-workflow-approve.

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
helper_script="${script_dir}/gh-workflow-approve.sh"
target="${1:-${helper_script}}"

if [[ ! -r ${target} ]]; then
	printf 'gh-workflow-approve-tests: cannot read %s\n' "${target}" >&2
	exit 1
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT

log_file="${tmpdir}/gh.log"
fake_gh="${tmpdir}/fake-gh"
cat >"${fake_gh}" <<EOF
#!${BASH}
EOF
cat >>"${fake_gh}" <<'EOF'
set -euo pipefail
printf '%s\n' "$*" >>"${FAKE_GH_LOG}"
if [[ $1 == "api" && $2 == "--method" && $3 == "GET" ]]; then
	printf '%s\n' "${FAKE_GH_RUN_JSON}"
	exit 0
fi
if [[ $1 == "api" && $2 == "--method" && $3 == "POST" ]]; then
	exit 0
fi
printf 'unexpected fake-gh invocation: %s\n' "$*" >&2
exit 99
EOF
chmod +x "${fake_gh}"

run_helper() {
	local out_var="$1"
	local err_var="$2"
	local rc_var="$3"
	shift 3
	local out_file="${tmpdir}/stdout"
	local err_file="${tmpdir}/stderr"
	local exit_code=0
	set +e
	FAKE_GH_LOG="${log_file}" \
		FAKE_GH_RUN_JSON="${FAKE_GH_RUN_JSON:-}" \
		GH_WORKFLOW_APPROVE_GH_BIN="${fake_gh}" \
		"${BASH}" "${target}" "$@" >"${out_file}" 2>"${err_file}"
	exit_code=$?
	set -e
	printf -v "${out_var}" '%s' "$(cat "${out_file}")"
	printf -v "${err_var}" '%s' "$(cat "${err_file}")"
	printf -v "${rc_var}" '%s' "${exit_code}"
}

fail() {
	printf 'FAIL: %s\n' "$*" >&2
	exit 1
}

stdout=""
stderr=""
rc=0

# 1. --help succeeds without calling gh.
run_helper stdout stderr rc --help
[[ ${rc} -eq 0 ]] || fail "--help exited ${rc}"
[[ ${stdout} == *"gh-workflow-approve <owner>/<repo> <run-id>"* ]] || fail "--help missing usage"
[[ ! -s ${log_file} ]] || fail "--help unexpectedly invoked gh"

# 2. Policy rejections exit 64 without calling gh.
for bad_case in \
	"" \
	"wimpysworld/deb-get" \
	"evilorg/deb-get 12345" \
	"wimpysworld/deb-get 0" \
	"wimpysworld/deb-get abc" \
	"wimpysworld/../deb-get 12345" \
	"--repo wimpysworld/deb-get"; do
	# shellcheck disable=SC2086
	run_helper stdout stderr rc ${bad_case}
	[[ ${rc} -eq 64 ]] || fail "case '${bad_case}' exited ${rc}, expected 64 (stderr: ${stderr})"
	[[ ! -s ${log_file} ]] || fail "case '${bad_case}' unexpectedly invoked gh"
done

# 3. Non-pull_request event is refused after GET without POST.
: >"${log_file}"
FAKE_GH_RUN_JSON='{"id":12345,"event":"push","status":"action_required","conclusion":null}' \
	run_helper stdout stderr rc wimpysworld/deb-get 12345
[[ ${rc} -eq 64 ]] || fail "non-PR event exited ${rc}, expected 64"
grep -qx 'api --method GET repos/wimpysworld/deb-get/actions/runs/12345' "${log_file}" || fail "missing GET call"
if grep -q 'POST' "${log_file}"; then
	fail "non-PR event unexpectedly called POST"
fi

# 4. Non-action_required status/conclusion is refused after GET without POST.
: >"${log_file}"
FAKE_GH_RUN_JSON='{"id":12345,"event":"pull_request","status":"completed","conclusion":"success"}' \
	run_helper stdout stderr rc wimpysworld/deb-get 12345
[[ ${rc} -eq 64 ]] || fail "completed run exited ${rc}, expected 64"
if grep -q 'POST' "${log_file}"; then
	fail "completed run unexpectedly called POST"
fi

# 5. Valid action_required pull_request run approves cleanly via POST.
: >"${log_file}"
FAKE_GH_RUN_JSON='{"id":987654,"event":"pull_request","status":"action_required","conclusion":"action_required"}' \
	run_helper stdout stderr rc wimpysworld/deb-get 987654
[[ ${rc} -eq 0 ]] || fail "valid approval exited ${rc} (stderr: ${stderr})"
[[ ${stdout} == "gh-workflow-approve: approved workflow run 987654 in wimpysworld/deb-get." ]] || fail "unexpected stdout: ${stdout}"
grep -qx 'api --method GET repos/wimpysworld/deb-get/actions/runs/987654' "${log_file}" || fail "missing GET call for valid run"
grep -qx 'api --method POST repos/wimpysworld/deb-get/actions/runs/987654/approve' "${log_file}" || fail "missing POST approve call"

printf 'gh-workflow-approve-tests: all checks passed.\n'
