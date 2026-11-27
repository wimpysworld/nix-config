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
	path="$4"
	if [[ ${path} == "--paginate" ]]; then
		path="$5"
	fi
	case "${path}" in
		*/actions/runs\?head_sha=*) printf '%s\n' "${FAKE_GH_RUNS_JSON}" ;;
		*/actions/runs/*) printf '%s\n' "${FAKE_GH_RUN_JSON}" ;;
		*/pulls/*/commits\?*) printf '%s\n' "${FAKE_GH_COMMITS_JSON}" ;;
		*/pulls/*) printf '%s\n' "${FAKE_GH_PR_JSON}" ;;
		*/commits/*) printf '%s\n' "${FAKE_GH_COMMIT_JSON}" ;;
		*)
			printf 'unexpected fake-gh path: %s\n' "${path}" >&2
			exit 99
			;;
	esac
	exit 0
fi
if [[ $1 == "api" && $2 == "--method" && $3 == "POST" ]]; then
	exit "${FAKE_GH_POST_RC:-0}"
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

# 6. --dependabot-vendor-hash mode.
readonly HEAD_SHA="cccccccccccccccccccccccccccccccccccccccc"
readonly DEP_SHA="bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
readonly OLD_HASH="sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
readonly NEW_HASH="sha256-BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB="
readonly PR_URL="https://github.com/wimpysworld/tailor/pull/180"

base_pr="$(jq -cn --arg sha "${HEAD_SHA}" '{
	state: "open", draft: false, user: {login: "dependabot[bot]"},
	head: {ref: "dependabot/go_modules/gomod-abc", sha: $sha, repo: {full_name: "wimpysworld/tailor", owner: {login: "wimpysworld"}}},
	base: {repo: {full_name: "wimpysworld/tailor", owner: {login: "wimpysworld"}}}
}')"
base_commits="$(jq -cn --arg head "${HEAD_SHA}" --arg dep "${DEP_SHA}" '[
	{sha: $dep, author: {login: "dependabot[bot]"}, commit: {verification: {verified: true}}, parents: [{sha: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}]},
	{sha: $head, author: {login: "github-actions[bot]"}, commit: {verification: {verified: false}}, parents: [{sha: $dep}]}
]')"
base_commit="$(jq -cn --arg sha "${HEAD_SHA}" --arg old "${OLD_HASH}" --arg new "${NEW_HASH}" '{
	sha: $sha,
	files: [{filename: "nix/package.nix", status: "modified", additions: 1, deletions: 1,
		patch: "@@ -10,7 +10,7 @@\n   pname = \"tailor\";\n-  vendorHash = \"\($old)\";\n+  vendorHash = \"\($new)\";\n }"}]
}')"
base_runs="$(jq -cn --arg sha "${HEAD_SHA}" '{workflow_runs: [
	{id: 111, event: "pull_request", status: "completed", conclusion: "action_required", head_sha: $sha, actor: {login: "github-actions[bot]"}},
	{id: 222, event: "pull_request", status: "completed", conclusion: "action_required", head_sha: $sha, actor: {login: "github-actions[bot]"}},
	{id: 333, event: "push", status: "completed", conclusion: "success", head_sha: $sha, actor: {login: "github-actions[bot]"}}
]}')"
no_held_runs="$(jq -c '.workflow_runs |= map(select(.id == 333))' <<<"${base_runs}")"

export FAKE_GH_PR_JSON="${base_pr}"
export FAKE_GH_COMMITS_JSON="${base_commits}"
export FAKE_GH_COMMIT_JSON="${base_commit}"
export FAKE_GH_RUNS_JSON="${base_runs}"

# 6a. Success approves every held pull_request run of the head commit.
: >"${log_file}"
run_helper stdout stderr rc --dependabot-vendor-hash "${PR_URL}"
[[ ${rc} -eq 0 ]] || fail "vendorHash success exited ${rc} (stderr: ${stderr})"
grep -qx 'api --method GET repos/wimpysworld/tailor/pulls/180' "${log_file}" || fail "missing pull request GET"
grep -qx 'api --method GET --paginate repos/wimpysworld/tailor/pulls/180/commits?per_page=100' "${log_file}" || fail "missing commits GET"
grep -qx "api --method GET repos/wimpysworld/tailor/commits/${HEAD_SHA}" "${log_file}" || fail "missing head commit GET"
grep -qx "api --method GET --paginate repos/wimpysworld/tailor/actions/runs?head_sha=${HEAD_SHA}&per_page=100" "${log_file}" || fail "missing runs GET"
grep -qx 'api --method POST repos/wimpysworld/tailor/actions/runs/111/approve' "${log_file}" || fail "missing POST for run 111"
grep -qx 'api --method POST repos/wimpysworld/tailor/actions/runs/222/approve' "${log_file}" || fail "missing POST for run 222"
[[ $(grep -c 'POST' "${log_file}") -eq 2 ]] || fail "vendorHash success sent other POST calls"

# 6b. No held run exits 0 without POST.
: >"${log_file}"
FAKE_GH_RUNS_JSON="${no_held_runs}" run_helper stdout stderr rc --dependabot-vendor-hash "${PR_URL}"
[[ ${rc} -eq 0 ]] || fail "no held runs exited ${rc} (stderr: ${stderr})"
[[ ${stdout} == *"no held pull_request workflow runs"* ]] || fail "no held runs message missing: ${stdout}"
if grep -q 'POST' "${log_file}"; then
	fail "no held runs unexpectedly called POST"
fi

# 6c. Approve endpoint failure exits non-zero and asks for a manual approval.
: >"${log_file}"
FAKE_GH_POST_RC=1 run_helper stdout stderr rc --dependabot-vendor-hash "${PR_URL}"
[[ ${rc} -ne 0 ]] || fail "approve failure exited 0"
[[ ${stderr} == *'"Approve workflows to run"'* ]] || fail "approve failure message missing: ${stderr}"
[[ $(grep -c 'POST' "${log_file}") -eq 1 ]] || fail "approve failure continued after the first POST"

# 6d. URL policy rejections exit 64 without calling gh.
for bad_url in \
	"https://github.com/evilorg/tailor/pull/180" \
	"https://github.com/wimpysworld/tailor/issues/180" \
	"https://github.com/wimpysworld/../pull/180" \
	"--dry-run"; do
	: >"${log_file}"
	run_helper stdout stderr rc --dependabot-vendor-hash "${bad_url}"
	[[ ${rc} -eq 64 ]] || fail "URL '${bad_url}' exited ${rc}, expected 64"
	[[ ! -s ${log_file} ]] || fail "URL '${bad_url}' unexpectedly invoked gh"
done

# 6e. Each rejecting condition exits 64 without POST.
expect_rejected() {
	local name="$1"
	local var="$2"
	local base="$3"
	local filter="$4"
	local mutated
	mutated="$(jq -c --arg sha "${HEAD_SHA}" "${filter}" <<<"${base}")"
	: >"${log_file}"
	env "${var}=${mutated}" FAKE_GH_LOG="${log_file}" GH_WORKFLOW_APPROVE_GH_BIN="${fake_gh}" \
		"${BASH}" "${target}" --dependabot-vendor-hash "${PR_URL}" >"${tmpdir}/stdout" 2>"${tmpdir}/stderr" && rc=0 || rc=$?
	[[ ${rc} -eq 64 ]] || fail "${name} exited ${rc}, expected 64 (stderr: $(cat "${tmpdir}/stderr"))"
	[[ $(wc -l <"${tmpdir}/stderr") -eq 1 ]] || fail "${name} reason is not one line"
	if grep -q 'POST' "${log_file}"; then
		fail "${name} unexpectedly called POST"
	fi
}

expect_rejected "closed pull request" FAKE_GH_PR_JSON "${base_pr}" '.state = "closed"'
expect_rejected "draft pull request" FAKE_GH_PR_JSON "${base_pr}" '.draft = true'
expect_rejected "cross-repository pull request" FAKE_GH_PR_JSON "${base_pr}" '.head.repo = {full_name: "evil/tailor", owner: {login: "evil"}}'
expect_rejected "non-Dependabot author" FAKE_GH_PR_JSON "${base_pr}" '.user.login = "sith-skrye"'
expect_rejected "non-Go branch" FAKE_GH_PR_JSON "${base_pr}" '.head.ref = "dependabot/npm_and_yarn/foo"'
expect_rejected "head commit only" FAKE_GH_COMMITS_JSON "${base_commits}" '[last]'
expect_rejected "unverified Dependabot commit" FAKE_GH_COMMITS_JSON "${base_commits}" '.[0].commit.verification.verified = false'
expect_rejected "non-Dependabot earlier commit" FAKE_GH_COMMITS_JSON "${base_commits}" '.[0].author.login = "sith-skrye"'
expect_rejected "merge head commit" FAKE_GH_COMMITS_JSON "${base_commits}" '.[1].parents += [{sha: "dddddddddddddddddddddddddddddddddddddddd"}]'
expect_rejected "head commit by another author" FAKE_GH_COMMITS_JSON "${base_commits}" '.[1].author.login = "sith-skrye"'
expect_rejected "two changed files" FAKE_GH_COMMIT_JSON "${base_commit}" '.files += [.files[0] | .filename = "go.sum"]'
expect_rejected "other changed file" FAKE_GH_COMMIT_JSON "${base_commit}" '.files[0].filename = "flake.nix"'
expect_rejected "added file" FAKE_GH_COMMIT_JSON "${base_commit}" '.files[0].status = "added"'
expect_rejected "two additions" FAKE_GH_COMMIT_JSON "${base_commit}" '.files[0].additions = 2'
expect_rejected "non-vendorHash line" FAKE_GH_COMMIT_JSON "${base_commit}" '.files[0].patch |= sub("\\+  vendorHash = \"[^\"]*\";"; "+  version = \"1.2.3\";")'
expect_rejected "short hash" FAKE_GH_COMMIT_JSON "${base_commit}" '.files[0].patch |= sub("BBBB="; "B=")'
expect_rejected "held run by another actor" FAKE_GH_RUNS_JSON "${base_runs}" '.workflow_runs[1].actor.login = "flexiondotorg"'
expect_rejected "held run on another commit" FAKE_GH_RUNS_JSON "${base_runs}" '.workflow_runs[0].head_sha = "dddddddddddddddddddddddddddddddddddddddd"'

printf 'gh-workflow-approve-tests: all checks passed.\n'
