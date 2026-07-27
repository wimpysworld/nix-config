#!/usr/bin/env bash

# gh-review-reply: Fence-friendly helper for replying inside a GitHub pull
# request review comment thread.
#
# `gh` has no subcommand for the reply endpoint, the raw `gh api` escape hatch
# is denied under Fence, and `gh-api-safe` refuses every POST by design. This
# helper closes that gap for exactly one endpoint:
#
#   POST repos/{owner}/{repo}/pulls/{pr}/comments/{comment_id}/replies
#
# Policy summary:
#   * The argument list is fixed: OWNER REPO PR_NUMBER COMMENT_ID
#     --body-file PATH. Any other argument count is rejected.
#   * Every token that begins with `-` is rejected except the single
#     `--body-file` flag in its expected position. That is what refuses
#     -X/--method, -f/--field, -F/--raw-field, and --input, and it also
#     refuses a body path of `-`, so stdin cannot be smuggled in. The glued
#     `--body-file=PATH` form is rejected as well.
#   * OWNER and REPO must match ^[A-Za-z0-9._-]+$ and may not be `.` or `..`,
#     so a slash-bearing endpoint path can never pass as an owner. PR_NUMBER
#     and COMMENT_ID must be digits only.
#   * The endpoint path is built here from the validated components and is
#     never taken from argv, so a request can never reach another endpoint.
#   * The body is encoded with `jq -Rs`, which reads the whole file as one raw
#     string. Quotes, backticks, and newlines survive verbatim, and a body of
#     `true` or `42` stays a JSON string rather than a bool or a number.
#   * On a policy violation the helper exits 64 with a single-line reason on
#     stderr. A failed request exits with the GitHub CLI's own status instead,
#     because a 404 on a missing comment id is not a policy violation.
#
# Standalone test, from this directory:
#
#   bash gh-review-reply-tests.sh

readonly EX_POLICY=64

die() {
	printf 'gh-review-reply: %s\n' "$*" >&2
	exit "${EX_POLICY}"
}

usage() {
	cat <<'EOF'
gh-review-reply: reply inside a GitHub pull request review comment thread.

USAGE
    gh-review-reply OWNER REPO PR_NUMBER COMMENT_ID --body-file PATH
    gh-review-reply --help

POLICY
    The argument list is fixed and every argument is validated. OWNER and
    REPO must match ^[A-Za-z0-9._-]+$ and may not be `.` or `..`.
    PR_NUMBER and COMMENT_ID must be digits only. The body file must be an
    existing, readable, regular file.

    Every token beginning with `-` is rejected except `--body-file` in its
    expected position, which refuses -X/--method, -f/--field, -F/--raw-field,
    and --input. The glued `--body-file=PATH` form is rejected; pass the path
    as a separate argument.

    The request path is built from the validated arguments as
    repos/OWNER/REPO/pulls/PR_NUMBER/comments/COMMENT_ID/replies and is never
    taken from argv, so no other endpoint is reachable.

    The body is sent as a JSON string produced by `jq -Rs`, so quotes,
    backticks, and newlines in the file survive verbatim.

    On a policy violation gh-review-reply exits 64 with a single-line reason
    on stderr. A failed request exits with the GitHub CLI's own status.
EOF
}

# Surface --help/-h before any other parsing so users can discover the
# policy without tripping the argument count requirement.
for arg in "$@"; do
	case "${arg}" in
	-h | --help)
		usage
		exit 0
		;;
	esac
done

# Reject the glued flag form before the argument count check, so the reason
# reported is the real one rather than a miscount.
for arg in "$@"; do
	case "${arg}" in
	--body-file=*)
		die "--body-file=PATH is not accepted; pass the path as a separate argument"
		;;
	esac
done

if [[ $# -ne 6 ]]; then
	die "expected exactly 6 arguments: OWNER REPO PR_NUMBER COMMENT_ID --body-file PATH (try: gh-review-reply --help)"
fi

# Walk the argv once. Position 5 must be the literal --body-file flag; every
# other token must not look like a flag. This is what refuses -X, --method,
# -f, -F, --field, --raw-field, --input, and a body path of `-`.
args=("$@")
i=0
while [[ ${i} -lt ${#args[@]} ]]; do
	tok="${args[${i}]}"
	if [[ ${i} -eq 4 ]]; then
		if [[ ${tok} != "--body-file" ]]; then
			die "expected --body-file as the fifth argument, got '${tok}'"
		fi
	elif [[ ${tok} == -* ]]; then
		die "flag-like argument '${tok}' is not permitted (--body-file is the only accepted flag)"
	fi
	i=$((i + 1))
done

owner="$1"
repo="$2"
pr_number="$3"
comment_id="$4"
body_file="$6"

if [[ ${owner} == "." || ${owner} == ".." ]]; then
	die "owner '${owner}' is not a valid GitHub account name"
fi

if [[ ${repo} == "." || ${repo} == ".." ]]; then
	die "repository '${repo}' is not a valid GitHub repository name"
fi

if [[ ! ${owner} =~ ^[A-Za-z0-9._-]+$ ]]; then
	die "owner '${owner}' must match ^[A-Za-z0-9._-]+\$"
fi

if [[ ! ${repo} =~ ^[A-Za-z0-9._-]+$ ]]; then
	die "repository '${repo}' must match ^[A-Za-z0-9._-]+\$"
fi

if [[ ! ${pr_number} =~ ^[0-9]+$ ]]; then
	die "pull request number '${pr_number}' must be digits only"
fi

if [[ ! ${comment_id} =~ ^[0-9]+$ ]]; then
	die "review comment id '${comment_id}' must be digits only"
fi

if [[ ! -e ${body_file} ]]; then
	die "body file '${body_file}' does not exist"
fi

if [[ ! -f ${body_file} ]]; then
	die "body file '${body_file}' is not a regular file"
fi

if [[ ! -r ${body_file} ]]; then
	die "body file '${body_file}' is not readable"
fi

# The path is assembled from the validated components above. Nothing from
# argv reaches it unchecked.
path="repos/${owner}/${repo}/pulls/${pr_number}/comments/${comment_id}/replies"

: "${GH_REVIEW_REPLY_GH:=gh}"
export GH_TELEMETRY="${GH_TELEMETRY:-false}"

# Run the pipeline with errexit off so a failed request is reported by this
# helper rather than terminating the shell, and read both stages out of
# PIPESTATUS before any other command overwrites it.
set +e
jq -Rs '{body: .}' <"${body_file}" | "${GH_REVIEW_REPLY_GH}" api --method POST "${path}" --input -
statuses=("${PIPESTATUS[@]}")
set -e

gh_status="${statuses[1]}"
jq_status="${statuses[0]}"

if [[ ${gh_status} -ne 0 ]]; then
	printf 'gh-review-reply: gh exited %s for review comment %s at %s\n' "${gh_status}" "${comment_id}" "${path}" >&2
	printf 'gh-review-reply: review comment %s may not exist on pull request %s, or the API rejected the reply.\n' "${comment_id}" "${pr_number}" >&2
	exit "${gh_status}"
fi

if [[ ${jq_status} -ne 0 ]]; then
	printf 'gh-review-reply: jq exited %s while encoding %s, so the reply body may be incomplete.\n' "${jq_status}" "${body_file}" >&2
	exit "${jq_status}"
fi
