#!/usr/bin/env bash

# gh-bot-merge: Fence-friendly helper for approving and merging verified
# automated pull requests across wimpysworld, linuxmatters, quickemu-project,
# noughtylinux, oval-tutu, and flexiondotorg.

readonly EX_POLICY=64

die() {
	printf 'gh-bot-merge: %s\n' "$*" >&2
	exit "${EX_POLICY}"
}

usage() {
	cat <<'EOF'
gh-bot-merge: approve and squash-merge a verified automated pull request.

USAGE
    gh-bot-merge [--dry-run] <pr-url>
    gh-bot-merge --help

EXAMPLES
    gh-bot-merge --dry-run https://github.com/wimpysworld/nix-packages/pull/34
    gh-bot-merge https://github.com/linuxmatters/jive-vocals/pull/185

POLICY
    The URL must match:
      ^https://github\.com/(wimpysworld|linuxmatters|quickemu-project|noughtylinux|oval-tutu|Oval-Tutu|flexiondotorg)/([A-Za-z0-9._-]+)/pull/([1-9][0-9]*)/?$
    Any other owner, URL format, or extra flag is rejected with exit 64.

    Before any mutation, gh-bot-merge reads the pull request metadata and
    verifies that:
      * state is OPEN and isDraft is false
      * isCrossRepository is false and headRepositoryOwner.login matches the
        base repository owner (fork pull requests are never merged)
      * mergeable is MERGEABLE
      * every statusCheckRollup entry is either a COMPLETED CheckRun with
        conclusion in [SUCCESS, SKIPPED, NEUTRAL] or a StatusContext with
        state SUCCESS
      * the author, branch, labels, and changed files match one of the four
        permitted pull request classes:
          - dependabot
          - github-actions
          - freshener (wimpysworld/nix-config only; excludes automerge=false
            packages herdr-ctx-bar, herdr-disp-model, and roamgate)
          - trusted-peer (authored by flexiondotorg, sith-skrye, sith-traya,
            or sith-zannah; requires zero unresolved review threads, zero
            reviews requesting changes, a trusted-peer approval or peer viewer,
            and flexiondotorg as author or approver when touching sensitive
            packages)

    With --dry-run, gh-bot-merge prints the verified classification and
    whether the pull request requires --approve or --admin, then exits 0
    without mutating.
EOF
}

if [[ $# -eq 1 && ($1 == "--help" || $1 == "-h") ]]; then
	usage
	exit 0
fi

dry_run=false
raw_url=""

if [[ $# -eq 1 ]]; then
	raw_url="$1"
elif [[ $# -eq 2 && $1 == "--dry-run" ]]; then
	dry_run=true
	raw_url="$2"
else
	die "expected usage: gh-bot-merge [--dry-run] <pr-url> (try: gh-bot-merge --help)"
fi

if [[ ${raw_url} == -* ]]; then
	die "flag-like argument '${raw_url}' is not permitted in <pr-url> position"
fi

readonly URL_PATTERN='^https://github\.com/(wimpysworld|linuxmatters|quickemu-project|noughtylinux|oval-tutu|Oval-Tutu|flexiondotorg)/([A-Za-z0-9._-]+)/pull/([1-9][0-9]*)/?$'
if [[ ! ${raw_url} =~ ${URL_PATTERN} ]]; then
	die "URL '${raw_url}' must match https://github.com/(wimpysworld|linuxmatters|quickemu-project|noughtylinux|oval-tutu|Oval-Tutu|flexiondotorg)/<repo>/pull/<number>"
fi

owner="${BASH_REMATCH[1]}"
repo="${BASH_REMATCH[2]}"
pr_number="${BASH_REMATCH[3]}"

if [[ ${repo} == "." || ${repo} == ".." ]]; then
	die "repository '${repo}' is not a valid GitHub repository name"
fi

pr_url="https://github.com/${owner}/${repo}/pull/${pr_number}"

: "${GH_BOT_MERGE_GH_BIN:=gh}"
readonly GH_BOT_MERGE_GH_BIN
export GH_PROMPT_DISABLED=true
export GH_TELEMETRY=false

readonly PR_VIEW_FIELDS='number,state,isDraft,mergeable,mergeStateStatus,author,headRefName,headRepositoryOwner,isCrossRepository,labels,changedFiles,files,statusCheckRollup,reviewDecision'

set +e
pr_json="$("${GH_BOT_MERGE_GH_BIN}" pr view "${pr_url}" --json "${PR_VIEW_FIELDS}" </dev/null)"
gh_status=$?
set -e
if [[ ${gh_status} -ne 0 ]]; then
	printf 'gh-bot-merge: gh exited %s while reading pull request %s.\n' "${gh_status}" "${pr_url}" >&2
	exit "${gh_status}"
fi

if jq -e 'type == "object" and ((.changedFiles // 0) > ((.files // []) | length))' <<<"${pr_json}" >/dev/null 2>&1; then
	# shellcheck disable=SC2016
	readonly JQ_REST_FILE_ENTRY='.[] | {path: (.filename // ""), previousPath: (.previous_filename // ""), changeType: ((.status // "") | ascii_upcase)}'
	set +e
	paginated_files_jsonl="$("${GH_BOT_MERGE_GH_BIN}" api --paginate "repos/${owner}/${repo}/pulls/${pr_number}/files?per_page=100" --jq "${JQ_REST_FILE_ENTRY}" </dev/null)"
	files_status=$?
	set -e
	if [[ ${files_status} -ne 0 ]]; then
		printf 'gh-bot-merge: gh exited %s while reading pull request files for %s.\n' "${files_status}" "${pr_url}" >&2
		exit "${files_status}"
	fi

	set +e
	pr_json="$(
		printf '%s\n%s\n' "${pr_json}" "${paginated_files_jsonl}" | jq -s '
			.[0] as $pr
			| (.[1:]) as $paginated
			| if ($paginated | length) == ($pr.changedFiles // 0) then
				$pr | .files = $paginated
			  else
				$pr
			  end
		'
	)"
	merge_files_status=$?
	set -e
	if [[ ${merge_files_status} -ne 0 ]]; then
		printf 'gh-bot-merge: jq exited %s while merging paginated pull request files for %s.\n' "${merge_files_status}" "${pr_url}" >&2
		exit "${merge_files_status}"
	fi
fi

# shellcheck disable=SC2016 # $owner, $repo, and $pr_number are jq variables.
readonly JQ_VERIFY='
def check_ok:
  if .__typename == "CheckRun" then
    .status == "COMPLETED" and (.conclusion == "SUCCESS" or .conclusion == "SKIPPED" or .conclusion == "NEUTRAL")
  elif .__typename == "StatusContext" then
    .state == "SUCCESS"
  elif has("status") or has("conclusion") then
    .status == "COMPLETED" and (.conclusion == "SUCCESS" or .conclusion == "SKIPPED" or .conclusion == "NEUTRAL")
  elif has("state") then
    .state == "SUCCESS"
  else
    false
  end;

def check_label:
  if (.__typename == "StatusContext") or ((has("state")) and (has("status") | not)) then
    "\(.context // .name // "unknown") (\(.state // "UNKNOWN"))"
  else
    "\(.name // .context // "unknown") (\(.status // "UNKNOWN")/\(.conclusion // "PENDING"))"
  end;

def is_dependabot:
  (.author.login == "app/dependabot" or .author.login == "dependabot[bot]")
  and ((.headRefName // "") | startswith("dependabot/"));

def is_github_actions:
  (.author.login == "app/github-actions" or .author.login == "github-actions[bot]")
  and (
    .headRefName == "update_flake_lock_action"
    or .headRefName == "ci/update-electron-toolchain"
    or .headRefName == "tailor-alter"
    or ((.headRefName // "") | startswith("freshen/"))
  );

def touches_sensitive_package($owner; $repo):
  (($owner | ascii_downcase) == "wimpysworld" and ($repo | ascii_downcase) == "nix-config")
  and any(
    (.files // [])[];
    .changeType == "RENAMED"
    or ((.path // "") | test("^pkgs/(herdr-ctx-bar|herdr-disp-model|roamgate)/"))
  );

def has_freshener_labels:
  ((.labels // []) | map(.name)) | (any(. == "automated") and any(. == "dependencies"));

def is_freshener_branch:
  ((.headRefName // "") | test("^freshen/|^(chainctl|claude-themes-catppuccin|defold|handy|herdr-ctx-bar|herdr-disp-model|lan-mouse|manuscript|moltis|openusage|roamgate|weave|wolfictl|yam)-[0-9A-Za-z._-]+$"));

def is_trusted_peer($owner; $repo):
  (
    .author.login == "flexiondotorg"
    or .author.login == "sith-skrye"
    or .author.login == "sith-traya"
    or .author.login == "sith-zannah"
  )
  and (
    (
      ($owner | ascii_downcase) == "wimpysworld"
      and ($repo | ascii_downcase) == "nix-config"
      and .author.login == "flexiondotorg"
      and (has_freshener_labels or is_freshener_branch)
    )
    | not
  );

def is_freshener($owner; $repo):
  (($owner | ascii_downcase) == "wimpysworld" and ($repo | ascii_downcase) == "nix-config")
  and (.author.login == "flexiondotorg")
  and has_freshener_labels
  and ((.headRefName // "") | test("^(chainctl|claude-themes-catppuccin|defold|handy|lan-mouse|manuscript|moltis|openusage|weave|wolfictl|yam)-[0-9A-Za-z._-]+$"))
  and (touches_sensitive_package($owner; $repo) | not)
  and (((.files // []) | length) > 0)
  and all(
    (.files // [])[];
    ((.path // "") | test("^(pkgs/[A-Za-z0-9._-]+/default\\.nix|flake\\.nix|flake\\.lock)$"))
    and (.path != "pkgs/./default.nix")
    and (.path != "pkgs/../default.nix")
  );

if type != "object" or ((.number | tostring) != $pr_number) then
  "ERR\u001fresponse did not identify pull request #" + $pr_number
elif .state != "OPEN" then
  "ERR\u001fpull request #" + $pr_number + " is not OPEN (state=" + (.state // "UNKNOWN") + ")"
elif .isDraft != false then
  "ERR\u001fpull request #" + $pr_number + " is a draft"
elif (.isCrossRepository != false) or (((.headRepositoryOwner.login // "") | ascii_downcase) != ($owner | ascii_downcase)) then
  "ERR\u001fpull request #" + $pr_number + " is a fork or cross-repository pull request (isCrossRepository=" + (.isCrossRepository | tostring) + ", headRepositoryOwner=" + (.headRepositoryOwner.login // "UNKNOWN") + ")"
elif .mergeable != "MERGEABLE" then
  "ERR\u001fpull request #" + $pr_number + " is not mergeable (mergeable=" + (.mergeable // "UNKNOWN") + ")"
elif ((.changedFiles // ((.files // []) | length)) > ((.files // []) | length)) then
  "ERR\u001fpull request #" + $pr_number + " changed file list is incomplete (changedFiles=" + (.changedFiles | tostring) + ", files=" + (((.files // []) | length) | tostring) + ")"
elif ((.statusCheckRollup // []) | length) == 0 then
  "ERR\u001fpull request #" + $pr_number + " has no statusCheckRollup entries (CI checks are missing or have not registered yet)"
else
  ([(.statusCheckRollup // [])[] | select(check_ok | not) | check_label]) as $bad_checks
  | if ($bad_checks | length) > 0 then
      "ERR\u001fpull request #" + $pr_number + " has failing or pending status checks: " + ($bad_checks | join(", "))
    elif is_dependabot then
      ["OK", "dependabot", (.author.login // ""), (.reviewDecision // ""), (.mergeStateStatus // ""), (touches_sensitive_package($owner; $repo) | tostring)] | join("\u001f")
    elif is_github_actions then
      ["OK", "github-actions", (.author.login // ""), (.reviewDecision // ""), (.mergeStateStatus // ""), (touches_sensitive_package($owner; $repo) | tostring)] | join("\u001f")
    elif is_freshener($owner; $repo) then
      ["OK", "freshener", (.author.login // ""), (.reviewDecision // ""), (.mergeStateStatus // ""), (touches_sensitive_package($owner; $repo) | tostring)] | join("\u001f")
    elif is_trusted_peer($owner; $repo) then
      ["OK", "trusted-peer", (.author.login // ""), (.reviewDecision // ""), (.mergeStateStatus // ""), (touches_sensitive_package($owner; $repo) | tostring)] | join("\u001f")
    else
      "ERR\u001fpull request #" + $pr_number + " (author=" + (.author.login // "UNKNOWN") + ", headRefName=" + (.headRefName // "UNKNOWN") + ") does not match any permitted PR policy"
    end
end
'

set +e
verify_out="$(jq -r \
	--arg owner "${owner}" \
	--arg repo "${repo}" \
	--arg pr_number "${pr_number}" \
	"${JQ_VERIFY}" <<<"${pr_json}")"
jq_status=$?
set -e
if [[ ${jq_status} -ne 0 ]]; then
	printf 'gh-bot-merge: jq exited %s while verifying pull request %s.\n' "${jq_status}" "${pr_url}" >&2
	exit "${jq_status}"
fi

IFS=$'\x1f' read -r verdict field1 field2 field3 field4 field5 <<<"${verify_out}"
if [[ ${verdict} != "OK" ]]; then
	die "${field1:-verification failed}"
fi

pr_class="${field1}"
author_login="${field2}"
review_decision="${field3}"
merge_state_status="${field4}"
touches_sensitive="${field5:-false}"

set +e
viewer="$("${GH_BOT_MERGE_GH_BIN}" api user --jq .login </dev/null)"
viewer_status=$?
set -e
if [[ ${viewer_status} -ne 0 ]]; then
	printf 'gh-bot-merge: gh exited %s while reading authenticated viewer.\n' "${viewer_status}" >&2
	exit "${viewer_status}"
fi
if [[ -z ${viewer} ]]; then
	die "authenticated viewer login is empty"
fi

peer_approved="false"
if [[ ${pr_class} == "trusted-peer" ]]; then
	case "${viewer}" in
	flexiondotorg | sith-skrye | sith-traya | sith-zannah) ;;
	*) die "authenticated viewer '${viewer}' is not authorised to merge trusted-peer pull requests" ;;
	esac

	# shellcheck disable=SC2016 # $owner, $repo, and $pr are GraphQL variables.
	readonly TRUSTED_PEER_GRAPHQL_QUERY='query($owner: String!, $repo: String!, $pr: Int!) {
  repository(owner: $owner, name: $repo) {
    pullRequest(number: $pr) {
      reviewThreads(first: 100) {
        pageInfo {
          hasNextPage
        }
        nodes {
          isResolved
        }
      }
      latestOpinionatedReviews(first: 50) {
        pageInfo {
          hasNextPage
        }
        nodes {
          author {
            login
          }
          state
        }
      }
    }
  }
}'

	# shellcheck disable=SC2016 # jq variables, not shell expansion.
	readonly JQ_VERIFY_TRUSTED_PEER='
def is_trusted_peer_login($login):
  $login == "flexiondotorg"
  or $login == "sith-skrye"
  or $login == "sith-traya"
  or $login == "sith-zannah";

(.data.repository.pullRequest // null) as $pr
| if ($pr | type) != "object" then
    "ERR\u001fGraphQL response did not identify pull request #" + $pr_number
  elif ($pr.reviewThreads.pageInfo.hasNextPage == true) or ($pr.latestOpinionatedReviews.pageInfo.hasNextPage == true) then
    "ERR\u001fpull request #" + $pr_number + " has more than 100 review threads or 50 opinionated reviews; refusing automated merge"
  else
    ([($pr.reviewThreads.nodes // [])[] | select(.isResolved != true)] | length) as $unresolved
    | ($pr.latestOpinionatedReviews.nodes // []) as $reviews
    | any($reviews[]; .state == "CHANGES_REQUESTED") as $changes_requested
    | any(
        $reviews[];
        .state == "APPROVED"
        and (.author.login // "") != $author_login
        and is_trusted_peer_login(.author.login // "")
      ) as $has_peer_approval
    | any(
        $reviews[];
        .state == "APPROVED"
        and (.author.login // "") == "flexiondotorg"
      ) as $has_flexion_approval
    | if $unresolved > 0 then
        "ERR\u001fpull request #" + $pr_number + " has " + ($unresolved | tostring) + " unresolved review thread(s)"
      elif ($review_decision == "CHANGES_REQUESTED") or $changes_requested then
        "ERR\u001fpull request #" + $pr_number + " has a review requesting changes"
      elif ($touches_sensitive == "true") and ($author_login != "flexiondotorg") and ($has_flexion_approval | not) then
        "ERR\u001fpull request #" + $pr_number + " touches a sensitive package and requires flexiondotorg as author or approver"
      elif ($viewer == $author_login) and ($has_peer_approval | not) then
        "ERR\u001fpull request #" + $pr_number + " authored by " + $viewer + " requires an APPROVED review from another trusted peer before merging"
      else
        ["OK", ($has_peer_approval | tostring)] | join("\u001f")
      end
  end
'

	set +e
	graphql_json="$("${GH_BOT_MERGE_GH_BIN}" api graphql \
		-f "query=${TRUSTED_PEER_GRAPHQL_QUERY}" \
		-f "owner=${owner}" \
		-f "repo=${repo}" \
		-F "pr=${pr_number}" </dev/null)"
	graphql_status=$?
	set -e
	if [[ ${graphql_status} -ne 0 ]]; then
		printf 'gh-bot-merge: gh exited %s while reading review threads and reviews for %s.\n' "${graphql_status}" "${pr_url}" >&2
		exit "${graphql_status}"
	fi

	set +e
	peer_verify_out="$(jq -r \
		--arg pr_number "${pr_number}" \
		--arg author_login "${author_login}" \
		--arg viewer "${viewer}" \
		--arg review_decision "${review_decision}" \
		--arg touches_sensitive "${touches_sensitive}" \
		"${JQ_VERIFY_TRUSTED_PEER}" <<<"${graphql_json}")"
	peer_jq_status=$?
	set -e
	if [[ ${peer_jq_status} -ne 0 ]]; then
		printf 'gh-bot-merge: jq exited %s while verifying trusted-peer reviews for %s.\n' "${peer_jq_status}" "${pr_url}" >&2
		exit "${peer_jq_status}"
	fi

	IFS=$'\x1f' read -r peer_verdict peer_field1 <<<"${peer_verify_out}"
	if [[ ${peer_verdict} != "OK" ]]; then
		die "${peer_field1:-trusted-peer verification failed}"
	fi
	peer_approved="${peer_field1}"
fi

needs_approve=false
if [[ ${pr_class} == "trusted-peer" ]]; then
	if [[ ${author_login} != "${viewer}" && ${peer_approved} != "true" ]]; then
		needs_approve=true
	fi
elif [[ ${author_login} != "${viewer}" && ${review_decision} != "APPROVED" ]]; then
	needs_approve=true
fi

needs_admin=false
if [[ ${author_login} == "${viewer}" && ${peer_approved} != "true" && (${review_decision} == "REVIEW_REQUIRED" || ${merge_state_status} == "BLOCKED") ]]; then
	needs_admin=true
fi

if [[ ${dry_run} == true ]]; then
	approve_mode="no"
	if [[ ${needs_approve} == true ]]; then
		approve_mode="yes"
	fi
	admin_mode="fallback"
	if [[ ${needs_admin} == true ]]; then
		admin_mode="yes"
	fi
	printf 'gh-bot-merge: dry-run: class=%s --approve=%s --admin=%s url=%s\n' \
		"${pr_class}" "${approve_mode}" "${admin_mode}" "${pr_url}"
	exit 0
fi

if [[ ${needs_approve} == true ]]; then
	set +e
	"${GH_BOT_MERGE_GH_BIN}" pr review "${pr_url}" --approve </dev/null
	review_status=$?
	set -e
	if [[ ${review_status} -ne 0 ]]; then
		printf 'gh-bot-merge: gh exited %s while approving %s.\n' "${review_status}" "${pr_url}" >&2
		exit "${review_status}"
	fi
fi

if [[ ${author_login} == "${viewer}" && ${peer_approved} != "true" && ${review_decision} == "REVIEW_REQUIRED" ]]; then
	set +e
	"${GH_BOT_MERGE_GH_BIN}" pr merge "${pr_url}" --admin --squash --delete-branch </dev/null
	merge_status=$?
	set -e
	if [[ ${merge_status} -ne 0 ]]; then
		printf 'gh-bot-merge: gh exited %s while admin-merging %s.\n' "${merge_status}" "${pr_url}" >&2
		exit "${merge_status}"
	fi
else
	set +e
	"${GH_BOT_MERGE_GH_BIN}" pr merge "${pr_url}" --squash --delete-branch </dev/null
	merge_status=$?
	set -e
	if [[ ${merge_status} -ne 0 ]]; then
		set +e
		"${GH_BOT_MERGE_GH_BIN}" pr merge "${pr_url}" --admin --squash --delete-branch </dev/null
		admin_status=$?
		set -e
		if [[ ${admin_status} -ne 0 ]]; then
			printf 'gh-bot-merge: gh exited %s while merging %s (including --admin fallback).\n' "${admin_status}" "${pr_url}" >&2
			exit "${admin_status}"
		fi
	fi
fi

printf 'gh-bot-merge: merged %s (%s).\n' "${pr_url}" "${pr_class}"
