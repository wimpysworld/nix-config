#!/usr/bin/env bash

# gh-workflow-approve: Fence-friendly helper for approving one fork pull-request
# GitHub Actions workflow run that is waiting in action_required state.

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
    gh-workflow-approve --help

EXAMPLES
    gh-workflow-approve wimpysworld/deb-get 1234567890

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
EOF
}

if [[ $# -eq 1 && ($1 == "--help" || $1 == "-h") ]]; then
	usage
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

: "${GH_WORKFLOW_APPROVE_GH_BIN:=gh}"
readonly GH_WORKFLOW_APPROVE_GH_BIN
export GH_PROMPT_DISABLED=true
export GH_TELEMETRY=false

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
