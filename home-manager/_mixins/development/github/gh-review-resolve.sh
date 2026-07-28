#!/usr/bin/env bash

# gh-review-resolve: Fence-friendly helper for marking a GitHub pull request
# review thread as resolved.
#
# Resolving a thread is a GraphQL mutation only. GitHub has no REST endpoint
# for it, `gh` has no subcommand for it, the raw `gh api` escape hatch is
# denied under Fence, and `gh-api-safe` refuses every write by design. This
# helper closes that gap for exactly one mutation:
#
#   resolveReviewThread(input: {threadId: ...})
#
# Policy summary:
#   * The argument list is fixed: <review-comment-url>. Any other argument
#     count is rejected. The URL is the only accepted way to name the thread;
#     owner, repository, pull request number, and comment id are all parsed
#     out of it, never taken from a separate argument, an API lookup, or the
#     git remote.
#   * The URL must begin with https://github.com/ and its path must be
#     <owner>/<repo>/pull/<number>, optionally followed by further segments
#     such as /files. Its fragment must be #discussion_r<digits> from the
#     conversation tab or #r<digits> from the files tab. An
#     #issuecomment-<digits> fragment names a top-level comment rather than a
#     review comment, so it is rejected with that reason.
#   * Every token that begins with `-` is rejected apart from `--help` and
#     `-h`. There is no flag to smuggle a query, a mutation, an endpoint, or a
#     field through.
#   * The owner and repository parsed from the URL must match
#     ^[A-Za-z0-9._-]+$ and may not be `.` or `..`, so a slash-bearing
#     endpoint path can never pass as an owner. The pull request number and
#     the comment id must be digits only.
#   * The query and the mutation are fixed strings in this file. Every value
#     reaches GitHub as a typed GraphQL variable, so nothing from argv is ever
#     interpolated into the query text.
#   * The thread id sent to the mutation is the one found by the lookup, so a
#     caller cannot name an arbitrary node.
#   * The lookup pages through both the review threads and the comments of
#     each thread, and it matches every comment in a thread rather than the
#     first, because the URL may name any comment in the thread.
#   * A thread that is already resolved is reported and exits 0, so the helper
#     is safe to re-run.
#   * On a policy violation the helper exits 64 with a single-line reason on
#     stderr. A failed request exits with the GitHub CLI's own status instead,
#     because a 404 on a missing comment id is not a policy violation.
#
# Standalone test, from this directory:
#
#   bash gh-review-resolve-tests.sh

readonly EX_POLICY=64

die() {
	printf 'gh-review-resolve: %s\n' "$*" >&2
	exit "${EX_POLICY}"
}

usage() {
	cat <<'EOF'
gh-review-resolve: mark a GitHub pull request review thread as resolved.

USAGE
    gh-review-resolve <review-comment-url>
    gh-review-resolve --help

EXAMPLE
    gh-review-resolve https://github.com/wimpysworld/nyala/pull/49#discussion_r3653766431

POLICY
    The argument list is fixed and the single argument is validated. The URL
    must begin with https://github.com/ and its path must be
    <owner>/<repo>/pull/<number>, optionally followed by further segments
    such as /files. Its fragment must be #discussion_r<id> from the
    conversation tab or #r<id> from the files tab. An #issuecomment-<id>
    fragment names a top-level comment, not a review comment, so no thread
    can be found for it.

    The owner and repository parsed from the URL must match
    ^[A-Za-z0-9._-]+$ and may not be `.` or `..`. The pull request number and
    the comment id must be digits only.

    Every token beginning with `-` is rejected apart from `--help` and `-h`,
    so no query, mutation, endpoint, method, or field can be passed in.

    The GraphQL query and the resolveReviewThread mutation are fixed strings
    inside gh-review-resolve, and every value is sent as a typed GraphQL
    variable. The thread id given to the mutation is the one holding the
    comment named by the URL, so no other node is reachable.

    A thread that is already resolved is reported and exits 0, so running
    gh-review-resolve twice is not an error.

    On a policy violation gh-review-resolve exits 64 with a single-line
    reason on stderr. A failed request exits with the GitHub CLI's own
    status.
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

if [[ $# -ne 1 ]]; then
	die "expected exactly 1 argument: <review-comment-url> (try: gh-review-resolve --help)"
fi

# The URL begins with `h`, so the only tokens this refuses are the ones
# trying to pass a flag. There is no accepted flag other than --help and -h,
# both of which have already exited above.
if [[ $1 == -* ]]; then
	die "flag-like argument '$1' is not permitted (gh-review-resolve takes a review comment URL and nothing else)"
fi

url="$1"

readonly URL_PREFIX="https://github.com/"

# Everything below comes out of the URL. No API call and no git remote is
# consulted, so the caller cannot be redirected to another repository.
if [[ ${url} != "${URL_PREFIX}"* ]]; then
	die "review comment URL must begin with ${URL_PREFIX}, got '${url}'"
fi

rest="${url#"${URL_PREFIX}"}"

if [[ ${rest} != *"#"* ]]; then
	die "review comment URL '${url}' has no fragment; expected '#discussion_r<id>' or '#r<id>' naming the review comment"
fi

url_path="${rest%%#*}"
fragment="${rest#*#}"

if [[ ${fragment} =~ ^issuecomment-[0-9]+$ ]]; then
	die "fragment '#${fragment}' names a top-level comment, not a review comment; top-level comments have no review thread to resolve"
fi

# The conversation tab anchors review comments as #discussion_r<id> and the
# files tab as #r<id>. Both name the same comment, so both are accepted.
if [[ ${fragment} =~ ^(discussion_r|r)([0-9]+)$ ]]; then
	comment_id="${BASH_REMATCH[2]}"
else
	die "fragment '#${fragment}' is not a review comment anchor; expected '#discussion_r<id>' or '#r<id>'"
fi

if [[ ${url_path} =~ ^[^/]+/[^/]+/issues(/|$) ]]; then
	die "review comment URL '${url}' names an issue, not a pull request; expected '<owner>/<repo>/pull/<number>' in the path"
fi

# Trailing segments such as /files are allowed, because GitHub serves the same
# anchor from the conversation and files tabs.
if [[ ${url_path} =~ ^([^/]+)/([^/]+)/pull/([^/]+)(/.*)?$ ]]; then
	owner="${BASH_REMATCH[1]}"
	repo="${BASH_REMATCH[2]}"
	pr_number="${BASH_REMATCH[3]}"
else
	die "review comment URL path '${url_path}' does not match '<owner>/<repo>/pull/<number>'"
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

if [[ ! ${pr_number} =~ ^[0-9]+$ ]]; then
	die "pull request number '${pr_number}' must be digits only"
fi

if [[ ! ${comment_id} =~ ^[0-9]+$ ]]; then
	die "review comment id '${comment_id}' must be digits only"
fi

# The query, the mutation, and the jq filters are fixed here. Values travel as
# typed GraphQL variables, so no part of argv reaches the query text.
# shellcheck disable=SC2016 # The `$` names GraphQL variables, not shell ones.
readonly THREADS_QUERY='query($owner: String!, $name: String!, $pr: Int!, $cursor: String) {
  repository(owner: $owner, name: $name) {
    pullRequest(number: $pr) {
      reviewThreads(first: 100, after: $cursor) {
        pageInfo { hasNextPage endCursor }
        nodes {
          id
          isResolved
          comments(first: 100) {
            pageInfo { hasNextPage endCursor }
            nodes { databaseId }
          }
        }
      }
    }
  }
}'

# shellcheck disable=SC2016 # The `$` names GraphQL variables, not shell ones.
readonly THREAD_COMMENTS_QUERY='query($threadId: ID!, $cursor: String) {
  node(id: $threadId) {
    ... on PullRequestReviewThread {
      id
      isResolved
      comments(first: 100, after: $cursor) {
        pageInfo { hasNextPage endCursor }
        nodes { databaseId }
      }
    }
  }
}'

# shellcheck disable=SC2016 # The `$` names GraphQL variables, not shell ones.
readonly RESOLVE_MUTATION='mutation($threadId: ID!) {
  resolveReviewThread(input: {threadId: $threadId}) {
    thread { id isResolved }
  }
}'

# The comment id is compared as a string, so a large databaseId cannot lose
# precision on its way through jq.
# shellcheck disable=SC2016 # `$cid` is a jq variable, not a shell one.
readonly MATCH_THREAD_FILTER='[ (.data.repository.pullRequest.reviewThreads.nodes // [])[]
  | select(any((.comments.nodes // [])[]; (.databaseId | tostring) == $cid))
  | "\(.id) \(.isResolved)" ] | first // ""'

readonly THREAD_PAGE_FILTER='(.data.repository.pullRequest.reviewThreads.pageInfo // {})
  | "\(.hasNextPage == true) \(.endCursor // "")"'

readonly DEFERRED_THREADS_FILTER='(.data.repository.pullRequest.reviewThreads.nodes // [])[]
  | select(.comments.pageInfo.hasNextPage == true)
  | "\(.id) \(.comments.pageInfo.endCursor)"'

# shellcheck disable=SC2016 # `$cid` is a jq variable, not a shell one.
readonly MATCH_NODE_FILTER='if any((.data.node.comments.nodes // [])[]; (.databaseId | tostring) == $cid)
  then "\(.data.node.id) \(.data.node.isResolved)" else "" end'

readonly NODE_PAGE_FILTER='(.data.node.comments.pageInfo // {})
  | "\(.hasNextPage == true) \(.endCursor // "")"'

: "${GH_REVIEW_RESOLVE_GH:=gh}"
export GH_TELEMETRY="${GH_TELEMETRY:-false}"

response=""
thread_id=""
thread_resolved=""

# Runs one GraphQL request and leaves the reply in `response`. A failed
# request exits with the GitHub CLI's own status rather than the policy
# status, because a 404 on a missing comment id is not a policy violation.
gh_graphql() {
	local what="$1"
	shift
	local status
	set +e
	response="$("${GH_REVIEW_RESOLVE_GH}" api graphql "$@" </dev/null)"
	status=$?
	set -e
	if [[ ${status} -ne 0 ]]; then
		printf 'gh-review-resolve: gh exited %s while %s.\n' "${status}" "${what}" >&2
		exit "${status}"
	fi
}

# Reads one filter over the last reply. A jq failure means the reply was not
# the shape this helper expects, which is not a policy violation either.
jq_read() {
	local out status
	set +e
	out="$(jq -r --arg cid "${comment_id}" "$1" <<<"${response}")"
	status=$?
	set -e
	if [[ ${status} -ne 0 ]]; then
		printf 'gh-review-resolve: jq exited %s reading the GraphQL reply.\n' "${status}" >&2
		exit "${status}"
	fi
	printf '%s\n' "${out}"
}

# Walks the remaining comment pages of one thread and sets thread_id when the
# comment id turns up, because the URL may name any comment in the thread.
scan_thread_comments() {
	local id="$1" cursor="$2" match page
	while :; do
		gh_graphql "reading the comments of review thread ${id}" \
			-f "query=${THREAD_COMMENTS_QUERY}" \
			-f "threadId=${id}" \
			-f "cursor=${cursor}"
		match="$(jq_read "${MATCH_NODE_FILTER}")"
		if [[ -n ${match} ]]; then
			thread_id="${match%% *}"
			thread_resolved="${match##* }"
			return
		fi
		page="$(jq_read "${NODE_PAGE_FILTER}")"
		if [[ ${page%% *} != true ]]; then
			return
		fi
		cursor="${page#* }"
	done
}

# A pull request can hold more review threads than one page returns, so the
# lookup follows the thread cursor until the comment id turns up.
cursor=""
while :; do
	threads_args=(
		-f "query=${THREADS_QUERY}"
		-f "owner=${owner}"
		-f "name=${repo}"
		-F "pr=${pr_number}"
	)
	if [[ -n ${cursor} ]]; then
		threads_args+=(-f "cursor=${cursor}")
	fi
	gh_graphql "reading the review threads on pull request ${pr_number}" "${threads_args[@]}"

	match="$(jq_read "${MATCH_THREAD_FILTER}")"
	if [[ -n ${match} ]]; then
		thread_id="${match%% *}"
		thread_resolved="${match##* }"
		break
	fi

	# A thread can also hold more comments than one page returns, so follow
	# every comment cursor on this page before moving on.
	deferred_text="$(jq_read "${DEFERRED_THREADS_FILTER}")"
	mapfile -t deferred <<<"${deferred_text}"
	for line in "${deferred[@]}"; do
		if [[ -z ${line} ]]; then
			continue
		fi
		scan_thread_comments "${line%% *}" "${line##* }"
		if [[ -n ${thread_id} ]]; then
			break
		fi
	done

	if [[ -n ${thread_id} ]]; then
		break
	fi

	page="$(jq_read "${THREAD_PAGE_FILTER}")"
	if [[ ${page%% *} != true ]]; then
		break
	fi
	cursor="${page#* }"
done

if [[ -z ${thread_id} ]]; then
	die "review comment ${comment_id} was not found in any review thread on ${owner}/${repo} pull request ${pr_number}"
fi

# Resolving twice is not an error, so report the state and stop here.
if [[ ${thread_resolved} == true ]]; then
	printf 'gh-review-resolve: review thread %s holding review comment %s on pull request %s is already resolved.\n' \
		"${thread_id}" "${comment_id}" "${pr_number}"
	exit 0
fi

# The mutation takes the thread id found above and nothing from argv.
gh_graphql "resolving review thread ${thread_id}" \
	-f "query=${RESOLVE_MUTATION}" \
	-f "threadId=${thread_id}"

printf 'gh-review-resolve: resolved review thread %s holding review comment %s on pull request %s.\n' \
	"${thread_id}" "${comment_id}" "${pr_number}"
