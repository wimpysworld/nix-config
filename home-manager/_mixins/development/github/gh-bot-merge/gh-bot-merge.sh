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
      ^https://github\.com/(wimpysworld|linuxmatters|quickemu-project|noughtylinux|oval-tutu|flexiondotorg)/([A-Za-z0-9._-]+)/pull/([1-9][0-9]*)/?$
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
      * the author, branch, labels, and changed files match one of the three
        permitted automated pull request classes:
          - dependabot
          - github-actions
          - freshener (wimpysworld/nix-config only; excludes automerge=false
            packages herdr-ctx-bar, herdr-disp-model, and roamgate)

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

readonly URL_PATTERN='^https://github\.com/(wimpysworld|linuxmatters|quickemu-project|noughtylinux|oval-tutu|flexiondotorg)/([A-Za-z0-9._-]+)/pull/([1-9][0-9]*)/?$'
if [[ ! ${raw_url} =~ ${URL_PATTERN} ]]; then
	die "URL '${raw_url}' must match https://github.com/(wimpysworld|linuxmatters|quickemu-project|noughtylinux|oval-tutu|flexiondotorg)/<repo>/pull/<number>"
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

readonly PR_VIEW_FIELDS='number,state,isDraft,mergeable,mergeStateStatus,author,headRefName,headRepositoryOwner,isCrossRepository,labels,files,statusCheckRollup,reviewDecision'

set +e
pr_json="$("${GH_BOT_MERGE_GH_BIN}" pr view "${pr_url}" --json "${PR_VIEW_FIELDS}" </dev/null)"
gh_status=$?
set -e
if [[ ${gh_status} -ne 0 ]]; then
	printf 'gh-bot-merge: gh exited %s while reading pull request %s.\n' "${gh_status}" "${pr_url}" >&2
	exit "${gh_status}"
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

def is_freshener($owner; $repo):
  ($owner == "wimpysworld" and $repo == "nix-config")
  and (.author.login == "flexiondotorg")
  and (((.labels // []) | map(.name)) | (contains(["automated"]) and contains(["dependencies"])))
  and ((.headRefName // "") | test("^(chainctl|claude-themes-catppuccin|defold|handy|lan-mouse|manuscript|moltis|openusage|weave|wolfictl|yam)-[0-9A-Za-z._-]+$"))
  and (((.files // []) | length) > 0)
  and all(
    (.files // [])[];
    ((.path // "") | test("^(pkgs/[A-Za-z0-9._-]+/default\\.nix|flake\\.nix|flake\\.lock)$"))
    and (.path != "pkgs/./default.nix")
    and (.path != "pkgs/../default.nix")
  );

if type != "object" or ((.number | tostring) != $pr_number) then
  "ERR\tresponse did not identify pull request #" + $pr_number
elif .state != "OPEN" then
  "ERR\tpull request #" + $pr_number + " is not OPEN (state=" + (.state // "UNKNOWN") + ")"
elif .isDraft != false then
  "ERR\tpull request #" + $pr_number + " is a draft"
elif (.isCrossRepository != false) or ((.headRepositoryOwner.login // "") != $owner) then
  "ERR\tpull request #" + $pr_number + " is a fork or cross-repository pull request (isCrossRepository=" + (.isCrossRepository | tostring) + ", headRepositoryOwner=" + (.headRepositoryOwner.login // "UNKNOWN") + ")"
elif .mergeable != "MERGEABLE" then
  "ERR\tpull request #" + $pr_number + " is not mergeable (mergeable=" + (.mergeable // "UNKNOWN") + ")"
else
  ([(.statusCheckRollup // [])[] | select(check_ok | not) | check_label]) as $bad_checks
  | if ($bad_checks | length) > 0 then
      "ERR\tpull request #" + $pr_number + " has failing or pending status checks: " + ($bad_checks | join(", "))
    elif is_dependabot then
      ["OK", "dependabot", (.author.login // ""), (.reviewDecision // ""), (.mergeStateStatus // "")] | @tsv
    elif is_github_actions then
      ["OK", "github-actions", (.author.login // ""), (.reviewDecision // ""), (.mergeStateStatus // "")] | @tsv
    elif is_freshener($owner; $repo) then
      ["OK", "freshener", (.author.login // ""), (.reviewDecision // ""), (.mergeStateStatus // "")] | @tsv
    else
      "ERR\tpull request #" + $pr_number + " (author=" + (.author.login // "UNKNOWN") + ", headRefName=" + (.headRefName // "UNKNOWN") + ") does not match any permitted automated PR policy"
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

IFS=$'\t' read -r verdict field1 field2 field3 field4 <<<"${verify_out}"
if [[ ${verdict} != "OK" ]]; then
	die "${field1:-verification failed}"
fi

pr_class="${field1}"
author_login="${field2}"
review_decision="${field3}"
merge_state_status="${field4}"

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

needs_approve=false
if [[ ${author_login} != "${viewer}" && ${review_decision} != "APPROVED" ]]; then
	needs_approve=true
fi

needs_admin=false
if [[ ${author_login} == "${viewer}" && (${review_decision} == "REVIEW_REQUIRED" || ${merge_state_status} == "BLOCKED") ]]; then
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

if [[ ${author_login} == "${viewer}" && ${review_decision} == "REVIEW_REQUIRED" ]]; then
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
