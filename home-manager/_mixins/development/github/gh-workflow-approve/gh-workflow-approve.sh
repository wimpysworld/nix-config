#!/usr/bin/env bash

# gh-workflow-approve: Fence-friendly helper for approving one fork pull-request
# GitHub Actions workflow run that is waiting in action_required state, or the
# held runs of a verified Dependabot vendorHash fix commit.

readonly EX_POLICY=64

die() {
	printf 'gh-workflow-approve: %s\n' "$*" >&2
	exit "${EX_POLICY}"
}

usage() {
	cat <<'EOF'
gh-workflow-approve: approve one action_required fork pull-request workflow run.

USAGE
    gh-workflow-approve <owner>/<repo> <run-id>
    gh-workflow-approve --dependabot-vendor-hash <pr-url>
    gh-workflow-approve --help

EXAMPLES
    gh-workflow-approve wimpysworld/deb-get 1234567890
    gh-workflow-approve --dependabot-vendor-hash https://github.com/wimpysworld/tailor/pull/180

POLICY
    - <owner>/<repo> must match ^[A-Za-z0-9][A-Za-z0-9._-]*/[A-Za-z0-9][A-Za-z0-9._-]*$
      with no dot segments, and <owner> must be one of:
      wimpysworld, linuxmatters, quickemu-project, noughtylinux, oval-tutu, flexiondotorg.
    - <run-id> must match ^[1-9][0-9]*$.
    - Before approving, gh-workflow-approve reads:
        GET repos/<owner>/<repo>/actions/runs/<run-id>
      and verifies that .event == "pull_request" and
      (.status == "action_required" or .conclusion == "action_required").
    - On success, gh-workflow-approve calls:
        POST repos/<owner>/<repo>/actions/runs/<run-id>/approve

DEPENDABOT VENDORHASH MODE
    - <pr-url> must match:
      ^https://github\.com/(wimpysworld|linuxmatters|quickemu-project|noughtylinux|oval-tutu|Oval-Tutu|flexiondotorg)/([A-Za-z0-9._-]+)/pull/([1-9][0-9]*)/?$
    - gh-workflow-approve reads:
        GET repos/<owner>/<repo>/pulls/<number>
        GET repos/<owner>/<repo>/pulls/<number>/commits?per_page=100 (paginated)
        GET repos/<owner>/<repo>/commits/<head-sha>
        GET repos/<owner>/<repo>/actions/runs?head_sha=<head-sha>&per_page=100 (paginated)
      and verifies that:
        * the pull request is open, not a draft, and not cross-repository
        * the author is app/dependabot or dependabot[bot] and the head
          branch starts with dependabot/go_modules/
        * every commit except the head is authored by dependabot[bot] with
          a verified signature
        * the head commit has one parent and is authored by
          github-actions[bot]
        * the head commit changes only nix/package.nix (modified, one
          addition, one deletion) and both changed lines match
          ^\s*vendorHash\s*=\s*"sha256-[A-Za-z0-9+/]{43}=";\s*$
        * every held (action_required) pull_request run has head_sha equal
          to the head commit and actor.login github-actions[bot]
    - It then calls, once for each held run:
        POST repos/<owner>/<repo>/actions/runs/<run-id>/approve
    - With no held run, it exits 0 without a write.
EOF
}

if [[ $# -eq 1 && ($1 == "--help" || $1 == "-h") ]]; then
	usage
	exit 0
fi

: "${GH_WORKFLOW_APPROVE_GH_BIN:=gh}"
readonly GH_WORKFLOW_APPROVE_GH_BIN
export GH_PROMPT_DISABLED=true
export GH_TELEMETRY=false

gh_read() {
	local what="$1"
	shift
	local out
	local status
	set +e
	out="$("${GH_WORKFLOW_APPROVE_GH_BIN}" api --method GET "$@" </dev/null)"
	status=$?
	set -e
	if [[ ${status} -ne 0 ]]; then
		printf 'gh-workflow-approve: gh exited %s while reading %s.\n' "${status}" "${what}" >&2
		exit "${status}"
	fi
	printf '%s' "${out}"
}

approve_dependabot_vendor_hash() {
	local raw_url="$1"
	if [[ ${raw_url} == -* ]]; then
		die "flag-like argument '${raw_url}' is not permitted in <pr-url> position"
	fi
	local url_pattern='^https://github\.com/(wimpysworld|linuxmatters|quickemu-project|noughtylinux|oval-tutu|Oval-Tutu|flexiondotorg)/([A-Za-z0-9._-]+)/pull/([1-9][0-9]*)/?$'
	if [[ ! ${raw_url} =~ ${url_pattern} ]]; then
		die "URL '${raw_url}' must match https://github.com/(wimpysworld|linuxmatters|quickemu-project|noughtylinux|oval-tutu|Oval-Tutu|flexiondotorg)/<repo>/pull/<number>"
	fi
	local pr_repo="${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
	local pr_number="${BASH_REMATCH[3]}"
	if [[ ${BASH_REMATCH[2]} == "." || ${BASH_REMATCH[2]} == ".." ]]; then
		die "repository '${BASH_REMATCH[2]}' is not a valid GitHub repository name"
	fi
	local pr_url="https://github.com/${pr_repo}/pull/${pr_number}"

	local pr_json commits_json commit_json runs_json verdict head_sha
	pr_json="$(gh_read "pull request ${pr_url}" "repos/${pr_repo}/pulls/${pr_number}")" || exit $?
	# shellcheck disable=SC2016 # jq program, not shell expansion.
	verdict="$(jq -r '
		if type != "object" then "ERR pull request response was not a JSON object"
		elif .state != "open" then "ERR pull request is not open"
		elif .draft != false then "ERR pull request is a draft"
		elif (.head.repo.full_name // "") == "" or .head.repo.full_name != .base.repo.full_name or .head.repo.owner.login != .base.repo.owner.login then "ERR pull request is cross-repository"
		elif (.user.login != "dependabot[bot]" and .user.login != "app/dependabot") then "ERR pull request author \(.user.login // "") is not Dependabot"
		elif ((.head.ref // "") | startswith("dependabot/go_modules/") | not) then "ERR head branch \(.head.ref // "") does not start with dependabot/go_modules/"
		elif ((.head.sha // "") | test("^[0-9a-f]{40}$") | not) then "ERR pull request head sha is not a commit id"
		else "OK \(.head.sha)"
		end' <<<"${pr_json}" 2>/dev/null)" || die "pull request response for ${pr_url} was not valid JSON"
	[[ ${verdict} == OK\ * ]] || die "${pr_url}: ${verdict#ERR }"
	head_sha="${verdict#OK }"

	commits_json="$(gh_read "commits of ${pr_url}" --paginate "repos/${pr_repo}/pulls/${pr_number}/commits?per_page=100")" || exit $?
	# shellcheck disable=SC2016 # jq program, not shell expansion.
	verdict="$(jq -s -r --arg head_sha "${head_sha}" '
		(map(arrays) | add // []) as $c
		| if ($c | length) < 2 then "ERR pull request needs Dependabot commits and one fix commit"
		  elif ($c | last | .sha) != $head_sha then "ERR last commit is not the pull request head"
		  elif any($c[:-1][]; (.author.login // "") != "dependabot[bot]" or (.commit.verification.verified // false) != true) then "ERR a commit before the head is not a verified Dependabot commit"
		  elif (($c | last | .parents // []) | length) != 1 then "ERR head commit does not have exactly one parent"
		  elif ($c | last | .parents[0].sha) != ($c[-2].sha) then "ERR head commit parent is not the previous pull request commit"
		  elif ($c | last | .author.login // "") != "github-actions[bot]" then "ERR head commit author is not github-actions[bot]"
		  else "OK"
		  end' <<<"${commits_json}" 2>/dev/null)" || die "commits response for ${pr_url} was not valid JSON"
	[[ ${verdict} == "OK" ]] || die "${pr_url}: ${verdict#ERR }"

	commit_json="$(gh_read "commit ${head_sha} in ${pr_repo}" "repos/${pr_repo}/commits/${head_sha}")" || exit $?
	# shellcheck disable=SC2016 # jq program, not shell expansion.
	verdict="$(jq -r --arg head_sha "${head_sha}" --arg re '^\s*vendorHash\s*=\s*"sha256-[A-Za-z0-9+/]{43}=";\s*$' '
		(.files // []) as $f
		| ([($f[0].patch // "") | split("\n")[] | select(startswith("+") or startswith("-"))]) as $lines
		| if type != "object" or .sha != $head_sha then "ERR head commit response does not match the pull request head"
		  elif ($f | length) != 1 then "ERR head commit must change exactly one file"
		  elif $f[0].filename != "nix/package.nix" or $f[0].status != "modified" then "ERR head commit must modify only nix/package.nix"
		  elif $f[0].additions != 1 or $f[0].deletions != 1 then "ERR head commit must add one line and delete one line"
		  elif ($lines | length) != 2 or ([$lines[] | .[0:1]] | sort) != ["+", "-"] then "ERR head commit patch must hold one removed and one added line"
		  elif any($lines[]; .[1:] | test($re) | not) then "ERR head commit changes a line other than vendorHash"
		  else "OK"
		  end' <<<"${commit_json}" 2>/dev/null)" || die "head commit response for ${pr_url} was not valid JSON"
	[[ ${verdict} == "OK" ]] || die "${pr_url}: ${verdict#ERR }"

	runs_json="$(gh_read "workflow runs for ${head_sha} in ${pr_repo}" --paginate "repos/${pr_repo}/actions/runs?head_sha=${head_sha}&per_page=100")" || exit $?
	# shellcheck disable=SC2016 # jq program, not shell expansion.
	verdict="$(jq -s -r --arg head_sha "${head_sha}" '
		[ .[] | (.workflow_runs // [])[]
		  | select((.event // "") == "pull_request" and ((.status // "") == "action_required" or (.conclusion // "") == "action_required")) ] as $held
		| if any($held[]; (.head_sha // "") != $head_sha) then "ERR a held run does not belong to the head commit"
		  elif any($held[]; (.actor.login // "") != "github-actions[bot]") then "ERR a held run was not triggered by github-actions[bot]"
		  elif any($held[]; (.id | type) != "number" or .id < 1) then "ERR a held run has no valid id"
		  else "OK " + ([$held[].id | tostring] | unique | join(" "))
		  end' <<<"${runs_json}" 2>/dev/null)" || die "workflow runs response for ${pr_url} was not valid JSON"
	[[ ${verdict} == OK* ]] || die "${pr_url}: ${verdict#ERR }"

	local -a held_ids
	read -r -a held_ids <<<"${verdict#OK}"
	if [[ ${#held_ids[@]} -eq 0 ]]; then
		printf 'gh-workflow-approve: no held pull_request workflow runs on %s for %s.\n' "${head_sha}" "${pr_url}"
		return 0
	fi

	local held_id post_status
	for held_id in "${held_ids[@]}"; do
		set +e
		"${GH_WORKFLOW_APPROVE_GH_BIN}" api --method POST "repos/${pr_repo}/actions/runs/${held_id}/approve" </dev/null
		post_status=$?
		set -e
		if [[ ${post_status} -ne 0 ]]; then
			printf 'gh-workflow-approve: gh exited %s while approving workflow run %s; a person must click "Approve workflows to run" on %s.\n' "${post_status}" "${held_id}" "${pr_url}" >&2
			exit "${post_status}"
		fi
		printf 'gh-workflow-approve: approved workflow run %s in %s.\n' "${held_id}" "${pr_repo}"
	done
}

if [[ $# -eq 2 && $1 == "--dependabot-vendor-hash" ]]; then
	approve_dependabot_vendor_hash "$2"
	exit 0
fi

if [[ $# -ne 2 ]]; then
	die "expected usage: gh-workflow-approve <owner>/<repo> <run-id> (try: gh-workflow-approve --help)"
fi

repo="$1"
run_id="$2"

if [[ ${repo} == -* ]]; then
	die "flag-like argument '${repo}' is not permitted in <owner>/<repo> position"
fi
if [[ ${run_id} == -* ]]; then
	die "flag-like argument '${run_id}' is not permitted in <run-id> position"
fi

readonly REPO_PATTERN='^[A-Za-z0-9][A-Za-z0-9._-]*/[A-Za-z0-9][A-Za-z0-9._-]*$'
if [[ ! ${repo} =~ ${REPO_PATTERN} ]]; then
	die "repository '${repo}' must match <owner>/<repo>"
fi

owner="${repo%%/*}"
name="${repo#*/}"
if [[ ${owner} == "." || ${owner} == ".." || ${name} == "." || ${name} == ".." ]]; then
	die "repository '${repo}' must not contain dot segments"
fi

owner_lower="${owner,,}"
case "${owner_lower}" in
	wimpysworld | linuxmatters | quickemu-project | noughtylinux | oval-tutu | flexiondotorg) ;;
	*)
		die "owner '${owner}' is outside the allowed repository owners"
		;;
esac

readonly RUN_ID_PATTERN='^[1-9][0-9]*$'
if [[ ! ${run_id} =~ ${RUN_ID_PATTERN} ]]; then
	die "run-id '${run_id}' must match ^[1-9][0-9]*$"
fi

set +e
run_json="$("${GH_WORKFLOW_APPROVE_GH_BIN}" api --method GET "repos/${repo}/actions/runs/${run_id}" </dev/null)"
get_status=$?
set -e
if [[ ${get_status} -ne 0 ]]; then
	printf 'gh-workflow-approve: gh exited %s while reading workflow run %s in %s.\n' "${get_status}" "${run_id}" "${repo}" >&2
	exit "${get_status}"
fi

if ! jq -e 'type == "object"' >/dev/null 2>&1 <<<"${run_json}"; then
	die "workflow run ${run_id} response was not a JSON object"
fi

run_event="$(jq -r '.event // ""' <<<"${run_json}")"
run_status="$(jq -r '.status // ""' <<<"${run_json}")"
run_conclusion="$(jq -r '.conclusion // ""' <<<"${run_json}")"

if [[ ${run_event} != "pull_request" ]]; then
	die "workflow run ${run_id} has event '${run_event}', expected 'pull_request'"
fi

if [[ ${run_status} != "action_required" && ${run_conclusion} != "action_required" ]]; then
	die "workflow run ${run_id} is not waiting for approval (status='${run_status}', conclusion='${run_conclusion}')"
fi

set +e
"${GH_WORKFLOW_APPROVE_GH_BIN}" api --method POST "repos/${repo}/actions/runs/${run_id}/approve" </dev/null
post_status=$?
set -e
if [[ ${post_status} -ne 0 ]]; then
	printf 'gh-workflow-approve: gh exited %s while approving workflow run %s in %s.\n' "${post_status}" "${run_id}" "${repo}" >&2
	exit "${post_status}"
fi

printf 'gh-workflow-approve: approved workflow run %s in %s.\n' "${run_id}" "${repo}"
