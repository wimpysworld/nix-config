#!/usr/bin/env bash

# gh-bot-merge-tests: runnable policy and execution test suite for gh-bot-merge.
#
# Can be run standalone:
#   bash home-manager/_mixins/development/github/gh-bot-merge/gh-bot-merge-tests.sh
# or from Nix checkPhase with the built executable passed as $1.

set -uo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
target_bin="${1:-}"
helper_script="${script_dir}/gh-bot-merge.sh"

if [[ -z ${target_bin} && ! -r ${helper_script} ]]; then
	printf 'gh-bot-merge-tests: cannot read %s\n' "${helper_script}" >&2
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

if [[ $# -ge 2 && $1 == "pr" && $2 == "view" ]]; then
	if [[ -r "${GH_STUB_STATE}/view-exit" ]]; then
		exit "$(cat "${GH_STUB_STATE}/view-exit")"
	fi
	cat "${GH_STUB_STATE}/pr.json"
	exit 0
fi

if [[ $# -ge 2 && $1 == "api" && $2 == "user" ]]; then
	printf '%s\n' "${GH_STUB_VIEWER:-flexiondotorg}"
	exit 0
fi

if [[ $# -ge 2 && $1 == "pr" && $2 == "review" ]]; then
	printf '%s\n' "$*" >>"${GH_STUB_STATE}/reviews"
	exit "${GH_STUB_REVIEW_EXIT:-0}"
fi

if [[ $# -ge 2 && $1 == "pr" && $2 == "merge" ]]; then
	printf '%s\n' "$*" >>"${GH_STUB_STATE}/merges"
	if [[ " $* " == *" --admin "* ]]; then
		exit "${GH_STUB_ADMIN_MERGE_EXIT:-0}"
	fi
	exit "${GH_STUB_STD_MERGE_EXIT:-0}"
fi

printf 'unexpected gh stub invocation: %s\n' "$*" >&2
exit 99
STUB
chmod +x "${stub_dir}/gh"

export PATH="${stub_dir}:${PATH}"
export GH_BOT_MERGE_GH_BIN="${stub_dir}/gh"
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
	: >"${state_dir}/reviews"
	: >"${state_dir}/merges"
}

write_pr_json() {
	local owner="${1:-wimpysworld}"
	local author="${2:-app/dependabot}"
	local head_ref="${3:-dependabot/nix/nixpkgs-3ec6363}"
	local extra_jq="${4:-.}"

	jq -n \
		--arg owner "${owner}" \
		--arg author "${author}" \
		--arg head_ref "${head_ref}" \
		'{
			number: 42,
			state: "OPEN",
			isDraft: false,
			mergeable: "MERGEABLE",
			mergeStateStatus: "BLOCKED",
			author: { login: $author },
			headRefName: $head_ref,
			headRepositoryOwner: { login: $owner },
			isCrossRepository: false,
			labels: [
				{ name: "dependencies" },
				{ name: "automated" }
			],
			files: [
				{ path: "flake.lock" }
			],
			statusCheckRollup: [
				{
					__typename: "CheckRun",
					name: "Build",
					status: "COMPLETED",
					conclusion: "SUCCESS"
				},
				{
					__typename: "CheckRun",
					name: "Release",
					status: "COMPLETED",
					conclusion: "SKIPPED"
				},
				{
					__typename: "CheckRun",
					name: "Advisory",
					status: "COMPLETED",
					conclusion: "NEUTRAL"
				},
				{
					__typename: "StatusContext",
					context: "ci/status",
					state: "SUCCESS"
				}
			],
			reviewDecision: "REVIEW_REQUIRED"
		} | '"${extra_jq}" >"${state_dir}/pr.json"
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

review_count() {
	wc -l <"${state_dir}/reviews" | tr -d ' '
}

merge_count() {
	wc -l <"${state_dir}/merges" | tr -d ' '
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

assert_pr_rejected() {
	local label="$1"
	local url="$2"
	local expected_substr="${3:-}"
	run_helper "${url}"
	if [[ ${status} -ne 64 ]]; then
		fail "${label}" "expected exit 64, got ${status}: ${stderr}"
	elif [[ $(review_count) -ne 0 || $(merge_count) -ne 0 ]]; then
		fail "${label}" "mutating gh subcommand was called on rejected PR"
	elif [[ -n ${expected_substr} && ${stderr} != *"${expected_substr}"* ]]; then
		fail "${label}" "expected '${expected_substr}' in stderr, got: ${stderr}"
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

assert_cli_rejected 'no arguments'
assert_cli_rejected 'too many arguments' --dry-run https://github.com/wimpysworld/nix-config/pull/42 extra
assert_cli_rejected 'reordered --dry-run after URL' https://github.com/wimpysworld/nix-config/pull/42 --dry-run
assert_cli_rejected 'unknown flag' --admin https://github.com/wimpysworld/nix-config/pull/42
assert_cli_rejected 'flag as URL' --dry-run
assert_cli_rejected 'unknown organization' https://github.com/nixos/nixpkgs/pull/42
assert_cli_rejected 'http scheme' http://github.com/wimpysworld/nix-config/pull/42
assert_cli_rejected 'issues URL instead of pull' https://github.com/wimpysworld/nix-config/issues/42
assert_cli_rejected 'zero PR number' https://github.com/wimpysworld/nix-config/pull/0
assert_cli_rejected 'dot repository' https://github.com/wimpysworld/./pull/42
assert_cli_rejected 'dot-dot repository' https://github.com/wimpysworld/../pull/42
assert_cli_rejected 'extra path segment' https://github.com/wimpysworld/nix-config/pull/42/files

# 2. Metadata state, draft, fork, mergeable, and CI check rejections
url_ww='https://github.com/wimpysworld/nix-config/pull/42'

reset_stub
write_pr_json wimpysworld 'app/dependabot' 'dependabot/nix/nixpkgs-3ec6363' '.state = "CLOSED"'
assert_pr_rejected 'reject closed PR' "${url_ww}" 'not OPEN'

reset_stub
write_pr_json wimpysworld 'app/dependabot' 'dependabot/nix/nixpkgs-3ec6363' '.isDraft = true'
assert_pr_rejected 'reject draft PR' "${url_ww}" 'draft'

reset_stub
write_pr_json wimpysworld 'app/dependabot' 'dependabot/nix/nixpkgs-3ec6363' '.isCrossRepository = true'
assert_pr_rejected 'reject fork PR (isCrossRepository=true)' "${url_ww}" 'fork'

reset_stub
write_pr_json wimpysworld 'app/dependabot' 'dependabot/nix/nixpkgs-3ec6363' '.headRepositoryOwner.login = "attacker-fork"'
assert_pr_rejected 'reject fork PR (mismatched headRepositoryOwner)' "${url_ww}" 'fork'

reset_stub
write_pr_json wimpysworld 'app/dependabot' 'dependabot/nix/nixpkgs-3ec6363' '.mergeable = "CONFLICTING"'
assert_pr_rejected 'reject conflicting PR' "${url_ww}" 'not mergeable'

reset_stub
write_pr_json wimpysworld 'app/dependabot' 'dependabot/nix/nixpkgs-3ec6363' \
	'.statusCheckRollup += [{__typename: "CheckRun", name: "Nix ❄️", status: "COMPLETED", conclusion: "FAILURE"}]'
assert_pr_rejected 'reject failing CheckRun and name check' "${url_ww}" 'Nix ❄️'

reset_stub
write_pr_json wimpysworld 'app/dependabot' 'dependabot/nix/nixpkgs-3ec6363' \
	'.statusCheckRollup += [{__typename: "CheckRun", name: "Test Suite", status: "IN_PROGRESS", conclusion: null}]'
assert_pr_rejected 'reject in_progress CheckRun and name check' "${url_ww}" 'Test Suite'

reset_stub
write_pr_json wimpysworld 'app/dependabot' 'dependabot/nix/nixpkgs-3ec6363' \
	'.statusCheckRollup += [{__typename: "StatusContext", context: "external/gate", state: "PENDING"}]'
assert_pr_rejected 'reject pending StatusContext and name check' "${url_ww}" 'external/gate'

# 3. Author & branch policy rejections
reset_stub
write_pr_json wimpysworld 'mallory' 'dependabot/nix/nixpkgs-3ec6363'
assert_pr_rejected 'reject untrusted author on dependabot branch' "${url_ww}" 'does not match'

reset_stub
write_pr_json wimpysworld 'dependabot[bot]' 'feature/not-dependabot'
assert_pr_rejected 'reject dependabot author on non-dependabot branch' "${url_ww}" 'does not match'

reset_stub
write_pr_json wimpysworld 'github-actions[bot]' 'feature/arbitrary-branch'
assert_pr_rejected 'reject github-actions author on arbitrary branch' "${url_ww}" 'does not match'

# 4. Freshener policy rejections (including automerge: false packages!)
for blocked_pkg in roamgate herdr-ctx-bar herdr-disp-model; do
	reset_stub
	write_pr_json wimpysworld 'flexiondotorg' "${blocked_pkg}-0.2.0" \
		'.files = [{path: ("pkgs/" + "'"${blocked_pkg}"'" + "/default.nix")}]'
	assert_pr_rejected "reject automerge: false package ${blocked_pkg}" "${url_ww}" 'does not match'
done

reset_stub
write_pr_json wimpysworld 'flexiondotorg' 'chainctl-0.2.391' \
	'.files = [{path: "pkgs/chainctl/default.nix"}]'
assert_pr_rejected 'reject freshener PR outside wimpysworld/nix-config' \
	'https://github.com/wimpysworld/nyala/pull/42' 'does not match'

reset_stub
write_pr_json wimpysworld 'flexiondotorg' 'chainctl-0.2.391' \
	'.labels = [{name: "dependencies"}] | .files = [{path: "pkgs/chainctl/default.nix"}]'
assert_pr_rejected 'reject freshener PR missing automated label' "${url_ww}" 'does not match'

reset_stub
write_pr_json wimpysworld 'flexiondotorg' 'chainctl-0.2.391' \
	'.files = [{path: "pkgs/chainctl/default.nix"}, {path: ".github/workflows/freshener.yml"}]'
assert_pr_rejected 'reject freshener PR touching workflow file' "${url_ww}" 'does not match'

# 5. Valid Dependabot PRs (--dry-run and full merge across allowed owners)
for owner in wimpysworld linuxmatters quickemu-project flexiondotorg; do
	reset_stub
	write_pr_json "${owner}" 'dependabot[bot]' 'dependabot/github_actions/actions/checkout-7'
	run_helper --dry-run "https://github.com/${owner}/repo/pull/42/"
	if [[ ${status} -ne 0 ]]; then
		fail "dry-run dependabot on ${owner}" "status ${status}: ${stderr}"
	elif [[ ${stdout} != *"class=dependabot"* || ${stdout} != *"--approve=yes"* ]]; then
		fail "dry-run dependabot output on ${owner}" "stdout: ${stdout}"
	elif [[ $(review_count) -ne 0 || $(merge_count) -ne 0 ]]; then
		fail "dry-run dependabot did not mutate on ${owner}" "reviews=$(review_count) merges=$(merge_count)"
	else
		pass "dry-run accepts dependabot[bot] on ${owner} without mutating"
	fi
done

reset_stub
write_pr_json linuxmatters 'app/dependabot' 'dependabot/nix/nixpkgs-3ec6363'
run_helper 'https://github.com/linuxmatters/jive-vocals/pull/42'
if [[ ${status} -ne 0 ]]; then
	fail 'merge app/dependabot PR' "status ${status}: ${stderr}"
elif [[ $(review_count) -ne 1 || $(merge_count) -ne 1 ]]; then
	fail 'merge app/dependabot PR calls review once and merge once' "reviews=$(review_count) merges=$(merge_count)"
elif grep -q -- '--admin' "${state_dir}/merges"; then
	fail 'merge app/dependabot PR tries non-admin squash merge first' "$(cat "${state_dir}/merges")"
else
	pass 'merge app/dependabot PR approves and squash-merges without --admin when allowed'
fi

# 6. Fallback to --admin when ruleset rejects non-admin merge after approval
reset_stub
write_pr_json wimpysworld 'app/dependabot' 'dependabot/nix/nixpkgs-3ec6363'
GH_STUB_STD_MERGE_EXIT=1 run_helper "${url_ww}"
if [[ ${status} -ne 0 ]]; then
	fail 'fallback to --admin merge' "status ${status}: ${stderr}"
elif [[ $(review_count) -ne 1 || $(merge_count) -ne 2 ]]; then
	fail 'fallback to --admin merge tries standard then --admin' "reviews=$(review_count) merges=$(merge_count)"
elif ! tail -n 1 "${state_dir}/merges" | grep -q -- '--admin --squash --delete-branch'; then
	fail 'fallback second merge call uses --admin' "$(cat "${state_dir}/merges")"
else
	pass 'fallback to --admin succeeds when repository ruleset blocks standard merge'
fi

# 7. Valid GitHub Actions automated update branches
for ga_branch in update_flake_lock_action ci/update-electron-toolchain tailor-alter freshen/packages; do
	reset_stub
	write_pr_json wimpysworld 'github-actions[bot]' "${ga_branch}" '.reviewDecision = "APPROVED"'
	run_helper "${url_ww}"
	if [[ ${status} -ne 0 ]]; then
		fail "github-actions branch ${ga_branch}" "status ${status}: ${stderr}"
	elif [[ $(review_count) -ne 0 || $(merge_count) -ne 1 ]]; then
		fail "github-actions branch ${ga_branch} skips approve when already APPROVED" \
			"reviews=$(review_count) merges=$(merge_count)"
	else
		pass "github-actions[bot] on '${ga_branch}' merges cleanly"
	fi
done

# 8. Valid wimpysworld/nix-config Freshener PRs (self-authored by flexiondotorg)
for pkg in chainctl claude-themes-catppuccin defold handy lan-mouse manuscript moltis openusage weave wolfictl yam; do
	reset_stub
	write_pr_json wimpysworld 'flexiondotorg' "${pkg}-1.2.3" \
		'.files = [{path: ("pkgs/" + "'"${pkg}"'" + "/default.nix")}, {path: "flake.lock"}]'
	run_helper --dry-run "${url_ww}"
	if [[ ${status} -ne 0 ]]; then
		fail "freshener dry-run ${pkg}" "status ${status}: ${stderr}"
	elif [[ ${stdout} != *"class=freshener"* || ${stdout} != *"--approve=no"* || ${stdout} != *"--admin=yes"* ]]; then
		fail "freshener dry-run output ${pkg}" "stdout: ${stdout}"
	else
		pass "freshener dry-run accepts ${pkg} with --approve=no --admin=yes"
	fi
done

reset_stub
write_pr_json wimpysworld 'flexiondotorg' 'chainctl-0.2.391' \
	'.files = [{path: "pkgs/chainctl/default.nix"}]'
run_helper "${url_ww}"
if [[ ${status} -ne 0 ]]; then
	fail 'freshener merge execution' "status ${status}: ${stderr}"
elif [[ $(review_count) -ne 0 || $(merge_count) -ne 1 ]]; then
	fail 'freshener merge skips self-approval and runs admin merge once' \
		"reviews=$(review_count) merges=$(merge_count)"
elif ! grep -q -- '--admin --squash --delete-branch' "${state_dir}/merges"; then
	fail 'freshener merge uses --admin --squash --delete-branch' "$(cat "${state_dir}/merges")"
else
	pass 'freshener PR by viewer skips self-approval and merges with --admin'
fi

printf '%s: %s passed, %s failed\n' \
	"$([[ ${failures} -eq 0 ]] && printf PASS || printf FAIL)" \
	"${passes}" "${failures}"
[[ ${failures} -eq 0 ]]
