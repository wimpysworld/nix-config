#!/usr/bin/env bash

# gh-review-withdraw-approval: Fence-friendly helper for dismissing the
# authenticated caller's own APPROVED reviews on a GitHub pull request.
#
# Dismissing a pull request review is a GraphQL mutation (`dismissPullRequestReview`)
# or a REST write, `gh pr review` has no subcommand flag to dismiss an earlier
# approval, the raw `gh api` escape hatch is denied under Fence, and
# `gh-api-safe` is read-only by design. This helper closes that gap for one
# mutation, scoped strictly to the authenticated caller's own APPROVED reviews:
#
#   dismissPullRequestReview(input: {pullRequestReviewId: ..., message: ...})

readonly EX_POLICY=64

die() {
	printf 'gh-review-withdraw-approval: %s\n' "$*" >&2
	exit "${EX_POLICY}"
}

usage() {
	cat <<'EOF'
gh-review-withdraw-approval: dismiss the authenticated caller's own APPROVED reviews on a GitHub pull request.

USAGE
    gh-review-withdraw-approval <pr-url|owner/repo#number|number> [--message <msg>]
    gh-review-withdraw-approval --help

EXAMPLE
    gh-review-withdraw-approval https://github.com/wimpysworld/nix-config/pull/1187

POLICY
    The target pull request may be passed as:
      - https://github.com/<owner>/<repo>/pull/<number> (with optional trailing
        segments or fragments)
      - <owner>/<repo>#<number>
      - <number> (resolved against the current repository via gh repo view)

    An optional `--message <msg>` flag sets the dismissal reason; otherwise
    "Withdrawing prior approval after confirming or raising a review finding."
    is used. Every other flag (including glued `--message=...`) is rejected.

    The helper queries the authenticated user's login (`viewer { login }`) and
    pages through the pull request's `APPROVED` reviews (`reviews(first: 100,
    states: [APPROVED])`). It filters strictly to reviews where
    `author.login == viewer.login` so another user's review can never be
    dismissed. When the authenticated user has zero `APPROVED` reviews on the
    pull request, the helper reports that and exits 0 idempotently.

    On a policy violation gh-review-withdraw-approval exits 64 with a
    single-line reason on stderr. A failed request exits with the GitHub CLI's
    own status.
EOF
}

for arg in "$@"; do
	case "${arg}" in
	-h | --help)
		usage
		exit 0
		;;
	esac
done

for arg in "$@"; do
	case "${arg}" in
	--message=*)
		die "--message=MSG is not accepted; pass --message and the message as separate arguments"
		;;
	esac
done

readonly DEFAULT_MESSAGE="Withdrawing prior approval after confirming or raising a review finding."

target=""
message="${DEFAULT_MESSAGE}"
message_set=false

while [[ $# -gt 0 ]]; do
	tok="$1"
	case "${tok}" in
	--message)
		if [[ ${message_set} == true ]]; then
			die "--message may only be specified once"
		fi
		if [[ $# -lt 2 ]]; then
			die "missing value after --message"
		fi
		message="$2"
		if [[ -z ${message} || -z ${message//[[:space:]]/} ]]; then
			die "--message must not be empty"
		fi
		message_set=true
		shift 2
		;;
	-*)
		die "flag-like argument '${tok}' is not permitted (try: gh-review-withdraw-approval --help)"
		;;
	*)
		if [[ -n ${target} ]]; then
			die "unexpected positional argument '${tok}' (expected one pull request target and optional --message <msg>)"
		fi
		target="${tok}"
		shift
		;;
	esac
done

if [[ -z ${target} ]]; then
	die "expected a pull request target: <pr-url|owner/repo#number|number> (try: gh-review-withdraw-approval --help)"
fi

: "${GH_REVIEW_WITHDRAW_APPROVAL_GH:=gh}"
export GH_TELEMETRY="${GH_TELEMETRY:-false}"

readonly URL_PREFIX="https://github.com/"
owner=""
repo=""
pr_number=""

if [[ ${target} == "${URL_PREFIX}"* ]]; then
	rest="${target#"${URL_PREFIX}"}"
	url_path="${rest%%#*}"
	url_path="${url_path%%\?*}"
	if [[ ${url_path} =~ ^[^/]+/[^/]+/issues(/|$) ]]; then
		die "pull request URL '${target}' names an issue, not a pull request; expected '<owner>/<repo>/pull/<number>' in the path"
	fi
	if [[ ${url_path} =~ ^([^/]+)/([^/]+)/pull/([^/]+)(/.*)?$ ]]; then
		owner="${BASH_REMATCH[1]}"
		repo="${BASH_REMATCH[2]}"
		pr_number="${BASH_REMATCH[3]}"
	else
		die "pull request URL path '${url_path}' does not match '<owner>/<repo>/pull/<number>'"
	fi
elif [[ ${target} =~ ^([^/#]+)/([^/#]+)#([0-9]+)$ ]]; then
	owner="${BASH_REMATCH[1]}"
	repo="${BASH_REMATCH[2]}"
	pr_number="${BASH_REMATCH[3]}"
elif [[ ${target} =~ ^[0-9]+$ ]]; then
	pr_number="${target}"
	set +e
	name_with_owner="$("${GH_REVIEW_WITHDRAW_APPROVAL_GH}" repo view --json nameWithOwner --jq .nameWithOwner </dev/null)"
	repo_status=$?
	set -e
	if [[ ${repo_status} -ne 0 ]]; then
		printf 'gh-review-withdraw-approval: gh exited %s while resolving current repository for pull request #%s.\n' "${repo_status}" "${pr_number}" >&2
		exit "${repo_status}"
	fi
	if [[ ${name_with_owner} =~ ^([^/]+)/([^/]+)$ ]]; then
		owner="${BASH_REMATCH[1]}"
		repo="${BASH_REMATCH[2]}"
	else
		die "could not resolve '<owner>/<repo>' from current repository (got '${name_with_owner}')"
	fi
else
	die "pull request target '${target}' must be https://github.com/<owner>/<repo>/pull/<number>, <owner>/<repo>#<number>, or <number>"
fi

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

if [[ ! ${pr_number} =~ ^[1-9][0-9]*$ ]]; then
	die "pull request number '${pr_number}' must be a positive integer"
fi

# shellcheck disable=SC2016 # The `$` names GraphQL variables, not shell ones.
readonly REVIEWS_QUERY='query($owner: String!, $name: String!, $pr: Int!, $cursor: String) {
  viewer {
    login
  }
  repository(owner: $owner, name: $name) {
    pullRequest(number: $pr) {
      reviews(first: 100, after: $cursor, states: [APPROVED]) {
        pageInfo {
          hasNextPage
          endCursor
        }
        nodes {
          id
          databaseId
          author {
            login
          }
          state
        }
      }
    }
  }
}'

# shellcheck disable=SC2016 # The `$` names GraphQL variables, not shell ones.
readonly DISMISS_MUTATION='mutation($reviewId: ID!, $message: String!) {
  dismissPullRequestReview(input: {pullRequestReviewId: $reviewId, message: $message}) {
    pullRequestReview {
      id
      state
    }
  }
}'

readonly VIEWER_FILTER='.data.viewer.login // ""'
readonly PR_EXISTS_FILTER='(.data.repository.pullRequest != null) | tostring'
readonly REVIEWS_PAGE_FILTER='(.data.repository.pullRequest.reviews.pageInfo // {})
  | "\(.hasNextPage == true) \(.endCursor // "")"'
# shellcheck disable=SC2016 # `$viewer` is a jq variable, not a shell one.
readonly OWN_APPROVED_FILTER='(.data.repository.pullRequest.reviews.nodes // [])[]
  | select(.state == "APPROVED" and (.author.login // "") == $viewer and ((.id // "") != ""))
  | .id'

response=""

gh_graphql() {
	local what="$1"
	shift
	local status
	set +e
	response="$("${GH_REVIEW_WITHDRAW_APPROVAL_GH}" api graphql "$@" </dev/null)"
	status=$?
	set -e
	if [[ ${status} -ne 0 ]]; then
		printf 'gh-review-withdraw-approval: gh exited %s while %s.\n' "${status}" "${what}" >&2
		exit "${status}"
	fi
}

jq_read() {
	local filter="$1"
	shift
	local out status
	set +e
	out="$(jq -r "$@" "${filter}" <<<"${response}")"
	status=$?
	set -e
	if [[ ${status} -ne 0 ]]; then
		printf 'gh-review-withdraw-approval: jq exited %s reading the GraphQL reply.\n' "${status}" >&2
		exit "${status}"
	fi
	printf '%s\n' "${out}"
}

declare -a review_ids=()
viewer_login=""
cursor=""

while :; do
	query_args=(
		-f "query=${REVIEWS_QUERY}"
		-f "owner=${owner}"
		-f "name=${repo}"
		-F "pr=${pr_number}"
	)
	if [[ -n ${cursor} ]]; then
		query_args+=(-f "cursor=${cursor}")
	fi
	gh_graphql "reading APPROVED reviews on ${owner}/${repo} pull request ${pr_number}" "${query_args[@]}"

	if [[ -z ${viewer_login} ]]; then
		viewer_login="$(jq_read "${VIEWER_FILTER}")"
		if [[ -z ${viewer_login} ]]; then
			die "authenticated viewer login is empty"
		fi
	fi

	pr_exists="$(jq_read "${PR_EXISTS_FILTER}")"
	if [[ ${pr_exists} != "true" ]]; then
		die "pull request ${pr_number} was not found on ${owner}/${repo}"
	fi

	page="$(jq_read "${REVIEWS_PAGE_FILTER}")"
	matched_text="$(jq_read "${OWN_APPROVED_FILTER}" --arg viewer "${viewer_login}")"
	mapfile -t page_ids <<<"${matched_text}"
	for id in "${page_ids[@]}"; do
		if [[ -n ${id} ]]; then
			review_ids+=("${id}")
		fi
	done

	if [[ ${page%% *} != true ]]; then
		break
	fi
	cursor="${page#* }"
done

if [[ ${#review_ids[@]} -eq 0 ]]; then
	printf 'gh-review-withdraw-approval: %s has no APPROVED reviews on %s/%s pull request %s.\n' \
		"${viewer_login}" "${owner}" "${repo}" "${pr_number}"
	exit 0
fi

for review_id in "${review_ids[@]}"; do
	gh_graphql "dismissing APPROVED review ${review_id} on ${owner}/${repo} pull request ${pr_number}" \
		-f "query=${DISMISS_MUTATION}" \
		-f "reviewId=${review_id}" \
		-f "message=${message}"
	printf 'gh-review-withdraw-approval: dismissed APPROVED review %s by %s on %s/%s pull request %s.\n' \
		"${review_id}" "${viewer_login}" "${owner}" "${repo}" "${pr_number}"
done
