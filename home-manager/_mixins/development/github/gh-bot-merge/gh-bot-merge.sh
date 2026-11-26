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
      * the pull request does not carry the team:do-not-merge label
        (case-insensitive; blocks automated merge for every author class)
      * isCrossRepository is false and headRepositoryOwner.login matches the
        base repository owner (fork pull requests are never merged)
      * mergeable is MERGEABLE
      * every statusCheckRollup entry is either a COMPLETED CheckRun with
        conclusion in [SUCCESS, SKIPPED, NEUTRAL] or a StatusContext with
        state SUCCESS (empty statusCheckRollup is permitted outside freshener,
        and completed failing checks on automated PRs are permitted when a
        trusted peer has approved headRefOid)
      * for dependabot, no pull_request workflow run on headRefOid is held
        (action_required), queued, or in progress, and an empty
        statusCheckRollup is rejected when such runs exist
      * zero unresolved review threads remain on the pull request
      * the author, branch, labels, and changed files match one of the four
        permitted pull request classes:
          - dependabot
          - github-actions
          - freshener (wimpysworld/nix-config only)
          - trusted-peer (authored by flexiondotorg, sith-skrye, sith-traya,
            or sith-zannah; requires zero unresolved review threads, zero
            reviews requesting changes, and a trusted-peer approval or peer
            viewer)

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

readonly PR_VIEW_FIELDS='number,state,isDraft,mergeable,mergeStateStatus,author,headRefName,headRefOid,headRepositoryOwner,isCrossRepository,labels,additions,deletions,changedFiles,files,statusCheckRollup,reviewDecision'

set +e
pr_json="$("${GH_BOT_MERGE_GH_BIN}" pr view "${pr_url}" --json "${PR_VIEW_FIELDS}" </dev/null)"
gh_status=$?
set -e
if [[ ${gh_status} -ne 0 ]]; then
	printf 'gh-bot-merge: gh exited %s while reading pull request %s.\n' "${gh_status}" "${pr_url}" >&2
	exit "${gh_status}"
fi

if jq -e 'type == "object" and (((.changedFiles // 0) > ((.files // []) | length)) or any((.files // [])[]; ((.changeType // "") | ascii_upcase) == "RENAMED" and ((.previousPath // "") == "")))' <<<"${pr_json}" >/dev/null 2>&1; then
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
			| if (($paginated | length) == ($pr.changedFiles // 0)) and ((($paginated | map(.path) | unique) | length) == ($pr.changedFiles // 0)) then
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

def check_pending:
  if .__typename == "CheckRun" then
    .status != "COMPLETED"
  elif .__typename == "StatusContext" then
    .state == "PENDING" or .state == "EXPECTED"
  elif has("status") or has("conclusion") then
    .status != "COMPLETED"
  elif has("state") then
    .state == "PENDING" or .state == "EXPECTED"
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
    or ((.headRefName // "") | test("^ci/nix-hash-[0-9A-Za-z._-]+$"))
  );

def has_freshener_labels:
  ((.labels // []) | map(.name)) | (any(. == "automated") and any(. == "dependencies"));

def is_freshener_branch:
  ((.headRefName // "") | test("^freshen/|^(brave|chainctl|claude-themes-catppuccin|defold|handy|herdr-ctx-bar|herdr-disp-model|lan-mouse|manuscript|moltis|openusage|roamgate|silo-server|weave|wolfictl|yam)-[0-9A-Za-z._-]+$"));

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
  and ((.headRefName // "") | test("^(brave|chainctl|claude-themes-catppuccin|defold|handy|herdr-ctx-bar|herdr-disp-model|lan-mouse|manuscript|moltis|openusage|roamgate|silo-server|weave|wolfictl|yam)-[0-9A-Za-z._-]+$"))
  and (((.files // []) | length) > 0)
  and all(
    (.files // [])[];
    ((.path // "") | test("^(pkgs/[A-Za-z0-9._-]+/default\\.nix|pkgs/brave/release\\.nix|flake\\.nix|flake\\.lock)$"))
    and (.path != "pkgs/./default.nix")
    and (.path != "pkgs/../default.nix")
  );

def is_sensitive_community_path:
  (. // "")
  | gsub("\\\\"; "/")
  | sub("^/+"; "")
  | sub("^(\\./)+"; "")
  | ascii_downcase as $pl
  | if ($pl | length) == 0 then
      false
    elif ($pl == ".github/workflows")
      or ($pl == ".github/actions")
      or ($pl | startswith(".github/workflows/"))
      or ($pl | startswith(".github/actions/"))
      or ($pl | endswith("npins/sources.json"))
      or ($pl | endswith("niv/sources.json"))
    then
      true
    else
      ($pl | split("/") | last) as $base
      | ($base == "flake.nix"
        or $base == "flake.lock"
        or $base == "cargo.toml"
        or $base == "cargo.lock"
        or $base == "go.mod"
        or $base == "go.sum"
        or $base == "go.work"
        or $base == "go.work.sum"
        or $base == "package.json"
        or $base == "package-lock.json"
        or $base == "npm-shrinkwrap.json"
        or $base == "pnpm-lock.yaml"
        or $base == "pnpm-workspace.yaml"
        or $base == "yarn.lock"
        or $base == "bun.lock"
        or $base == "bun.lockb"
        or $base == "deno.json"
        or $base == "deno.jsonc"
        or $base == "deno.lock"
        or $base == "pyproject.toml"
        or $base == "poetry.lock"
        or $base == "uv.lock"
        or $base == "pipfile"
        or $base == "pipfile.lock"
        or $base == "pdm.lock"
        or $base == "setup.py"
        or $base == "setup.cfg"
        or $base == "composer.json"
        or $base == "composer.lock"
        or $base == "pom.xml"
        or $base == "build.gradle"
        or $base == "build.gradle.kts"
        or $base == "gradle.lockfile"
        or $base == "settings.gradle"
        or $base == "settings.gradle.kts"
        or $base == "libs.versions.toml"
        or $base == "mix.exs"
        or $base == "mix.lock"
        or $base == "pubspec.yaml"
        or $base == "pubspec.lock"
        or $base == "packages.lock.json"
        or $base == "package.resolved"
        or $base == "dependabot.yml"
        or $base == "dependabot.yaml"
        or $base == "renovate.json"
        or $base == "renovate.json5"
        or $base == ".renovaterc"
        or $base == ".renovaterc.json"
        or $base == ".goreleaser.yml"
        or $base == ".goreleaser.yaml"
        or $base == ".envrc"
        or $base == "codeowners"
        or $base == "security.md"
        or ($base | test("^requirements.*\\.txt$"))
        or ($base | test("^constraints.*\\.txt$"))
        or ($base | test("^gemfile"))
        or ($base | test("\\.gemspec$")))
    end;

def has_do_not_merge_label:
  any((.labels // [])[]; ((.name // "") | ascii_downcase) == "team:do-not-merge");

def is_community_small($owner; $repo):
  (is_dependabot | not)
  and (is_github_actions | not)
  and (is_freshener($owner; $repo) | not)
  and (is_trusted_peer($owner; $repo) | not)
  and ((($owner | ascii_downcase) == "wimpysworld" and ($repo | ascii_downcase) == "nix-config") | not)
  and (((.additions // 0) + (.deletions // 0)) <= 150)
  and (((.changedFiles // ((.files // []) | length)) <= 5) and (((.files // []) | length) > 0))
  and (all(
    (.files // [])[];
    ((((.changeType // "") | ascii_upcase) == "RENAMED" and ((.previousPath // "") == "")) | not)
    and (((.path // "") | is_sensitive_community_path) | not)
    and (((.previousPath // "") | is_sensitive_community_path) | not)
  ));

def is_community_labeled($owner; $repo):
  (is_dependabot | not)
  and (is_github_actions | not)
  and (is_freshener($owner; $repo) | not)
  and (is_trusted_peer($owner; $repo) | not)
  and any((.labels // [])[]; .name == "team:merge");

def is_community($owner; $repo):
  is_community_small($owner; $repo) or is_community_labeled($owner; $repo);

if type != "object" or ((.number | tostring) != $pr_number) then
  "ERR\u001fresponse did not identify pull request #" + $pr_number
elif .state != "OPEN" then
  "ERR\u001fpull request #" + $pr_number + " is not OPEN (state=" + (.state // "UNKNOWN") + ")"
elif .isDraft != false then
  "ERR\u001fpull request #" + $pr_number + " is a draft"
elif .mergeable != "MERGEABLE" then
  "ERR\u001fpull request #" + $pr_number + " is not mergeable (mergeable=" + (.mergeable // "UNKNOWN") + ")"
elif ((.headRefOid | type) != "string") or ((.headRefOid | length) == 0) then
  "ERR\u001fpull request #" + $pr_number + " has no headRefOid"
elif ((.changedFiles // ((.files // []) | length)) > ((.files // []) | length)) then
  "ERR\u001fpull request #" + $pr_number + " changed file list is incomplete (changedFiles=" + (.changedFiles | tostring) + ", files=" + (((.files // []) | length) | tostring) + ")"
elif has_do_not_merge_label then
  "ERR\u001fpull request #" + $pr_number + " carries the team:do-not-merge label"
else
  (
    if is_dependabot then "dependabot"
    elif is_github_actions then "github-actions"
    elif is_freshener($owner; $repo) then "freshener"
    elif is_trusted_peer($owner; $repo) then "trusted-peer"
    elif is_community($owner; $repo) then "community"
    else ""
    end
  ) as $pr_class
  | ([(.statusCheckRollup // [])[] | select(check_ok | not) | check_label]) as $bad_checks
  | ([(.statusCheckRollup // [])[] | select(check_pending) | check_label]) as $pending_checks
  | if $pr_class == "" then
      "ERR\u001fpull request #" + $pr_number + " (author=" + (.author.login // "UNKNOWN") + ", headRefName=" + (.headRefName // "UNKNOWN") + ") does not match any permitted PR policy"
    elif ($pr_class != "community") and ((.isCrossRepository != false) or (((.headRepositoryOwner.login // "") | ascii_downcase) != ($owner | ascii_downcase))) then
      "ERR\u001fpull request #" + $pr_number + " is a fork or cross-repository pull request (isCrossRepository=" + (.isCrossRepository | tostring) + ", headRepositoryOwner=" + (.headRepositoryOwner.login // "UNKNOWN") + ")"
    elif (((.statusCheckRollup // []) | length) == 0) and ($pr_class == "freshener") then
      "ERR\u001fpull request #" + $pr_number + " has no statusCheckRollup entries (CI checks are missing or have not registered yet)"
    elif (($pending_checks | length) > 0) or ((($bad_checks | length) > 0) and (($pr_class == "trusted-peer") or ($pr_class == "community"))) then
      "ERR\u001fpull request #" + $pr_number + " has failing or pending status checks: " + ($bad_checks | join(", "))
    else
      ["OK", $pr_class, (.author.login // ""), (.reviewDecision // ""), (.mergeStateStatus // ""), .headRefOid, ($bad_checks | join(", ")), (if $pr_class == "community" and (is_community_small($owner; $repo) | not) then "true" else "false" end), ((.statusCheckRollup // []) | length | tostring)] | join("\u001f")
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

IFS=$'\x1f' read -r verdict field1 field2 field3 field4 field5 field6 field7 field8 <<<"${verify_out}"
if [[ ${verdict} != "OK" ]]; then
	die "${field1:-verification failed}"
fi

pr_class="${field1}"
author_login="${field2}"
review_decision="${field3}"
merge_state_status="${field4}"
head_ref_oid="${field5:-}"
failed_checks="${field6:-}"
community_via_label="${field7:-false}"
rollup_count="${field8:-0}"
if [[ -z ${head_ref_oid} ]]; then
	die "pull request #${pr_number} has no headRefOid"
fi

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
if [[ ${pr_class} == "trusted-peer" || ${pr_class} == "community" ]]; then
	case "${viewer}" in
	flexiondotorg | sith-skrye | sith-traya | sith-zannah) ;;
	*) die "authenticated viewer '${viewer}' is not authorised to merge ${pr_class} pull requests" ;;
	esac
fi

if [[ ${pr_class} == "community" && ${community_via_label} == "true" ]]; then
	set +e
	timeline_json="$("${GH_BOT_MERGE_GH_BIN}" api --paginate "repos/${owner}/${repo}/issues/${pr_number}/timeline?per_page=100" </dev/null)"
	timeline_status=$?
	set -e
	if [[ ${timeline_status} -ne 0 ]]; then
		printf 'gh-bot-merge: gh exited %s while reading issue timeline for %s.\n' "${timeline_status}" "${pr_url}" >&2
		exit "${timeline_status}"
	fi

	# shellcheck disable=SC2016
	readonly JQ_VERIFY_TEAM_MERGE='
	def is_trusted_labeler($login):
	  ($login | ascii_downcase) as $l
	  | $l == "flexiondotorg" or $l == "sith-skrye" or $l == "sith-traya" or $l == "sith-zannah";

	[ .[] | select(type == "array") | .[] ] as $all
	| ([ range(0; $all | length) as $i
	    | $all[$i]
	    | select((.event == "labeled" or .event == "unlabeled") and ((.label.name // "") | ascii_downcase) == "team:merge")
	    | { idx: $i, item: . }
	  ]) as $label_evs
	| if ($label_evs | length) == 0 then
	    "ERR\u001fpull request #" + $pr_number + " has no team:merge label event"
	  else
	    ($label_evs | last) as $last
	    | if $last.item.event != "labeled" then
	        "ERR\u001fpull request #" + $pr_number + " team:merge label is no longer active"
	      elif (is_trusted_labeler($last.item.actor.login // "") | not) then
	        "ERR\u001fpull request #" + $pr_number + " team:merge label was applied by untrusted actor " + ($last.item.actor.login // "UNKNOWN")
	      else
	        ($all[($last.idx + 1):] | map(select(.event == "committed" or .event == "head_ref_force_pushed"))) as $post_pushes
	        | ($all[0:$last.idx] | map(select(.event == "committed" or .event == "head_ref_force_pushed"))) as $pre_pushes
	        | if ($post_pushes | length) > 0 then
	            "ERR\u001fpull request #" + $pr_number + " received commits or force-pushes after team:merge was applied"
	          elif ($pre_pushes | length) == 0 then
	            "ERR\u001fpull request #" + $pr_number + " cannot prove head commit preceded team:merge in timeline"
	          else
	            (($pre_pushes | last) | (.sha // .commit_id // "")) as $last_pre_sha
	            | if $last_pre_sha != $head_ref_oid then
	                "ERR\u001fpull request #" + $pr_number + " head commit " + $head_ref_oid + " does not match last commit before team:merge (" + $last_pre_sha + ")"
	              else
	                "OK"
	              end
	          end
	      end
	  end
	'
	set +e
	label_verdict="$(jq -s -r --arg pr_number "${pr_number}" --arg head_ref_oid "${head_ref_oid}" "${JQ_VERIFY_TEAM_MERGE}" <<<"${timeline_json}")"
	label_jq_status=$?
	set -e
	if [[ ${label_jq_status} -ne 0 ]]; then
		printf 'gh-bot-merge: jq exited %s while verifying team:merge timeline for %s.\n' "${label_jq_status}" "${pr_url}" >&2
		exit "${label_jq_status}"
	fi
	if [[ ${label_verdict} != "OK" ]]; then
		die "${label_verdict#ERR$'\x1f'}"
	fi
fi

if [[ ${pr_class} == "community" || ${pr_class} == "dependabot" ]]; then
	set +e
	runs_json="$("${GH_BOT_MERGE_GH_BIN}" api --paginate "repos/${owner}/${repo}/actions/runs?head_sha=${head_ref_oid}&per_page=100" </dev/null)"
	runs_status=$?
	set -e
	if [[ ${runs_status} -ne 0 ]]; then
		printf 'gh-bot-merge: gh exited %s while reading workflow runs for %s.\n' "${runs_status}" "${pr_url}" >&2
		exit "${runs_status}"
	fi

	# Held runs never appear in statusCheckRollup, so Dependabot pull requests
	# must also wait for every pull_request run on headRefOid to finish.
	# shellcheck disable=SC2016
	readonly JQ_VERIFY_RUNS='
	def run_label: "\(.name // "workflow") (\(.status // "unknown")/\(.conclusion // "pending"))";

	[ .[] | (.workflow_runs // [])[] ] as $runs
	| [ $runs[] | select((.event // "") == "pull_request") ] as $pr_runs
	| if $pr_class == "community" then
	    [ $runs[] | select(
	        (.status // "") != "completed"
	        or (.conclusion // "") == "action_required"
	        or ((.conclusion // "") != "success" and (.conclusion // "") != "skipped" and (.conclusion // "") != "neutral")
	      ) | run_label ] as $bad
	    | if ($bad | length) > 0 then
	        "ERR\u001fpull request #" + $pr_number + " has incomplete, action_required, or failing workflow runs: " + ($bad | join(", "))
	      else
	        "OK"
	      end
	  else
	    [ $pr_runs[] | select((.status // "") != "completed" or (.conclusion // "") == "action_required") | run_label ] as $unfinished
	    | if ($unfinished | length) > 0 then
	        "ERR\u001fpull request #" + $pr_number + " has held (action_required), queued, or in-progress pull_request workflow runs on " + $head_ref_oid + ": " + ($unfinished | join(", ")) + "; wait for them to finish, then retry"
	      elif ($rollup_count == 0) and (($pr_runs | length) > 0) then
	        "ERR\u001fpull request #" + $pr_number + " has no statusCheckRollup entries but has pull_request workflow runs on " + $head_ref_oid + ": " + ($pr_runs | map(run_label) | join(", ")) + "; wait for CI to report, then retry"
	      else
	        "OK"
	      end
	  end
	'
	set +e
	runs_verdict="$(jq -s -r \
		--arg pr_class "${pr_class}" \
		--arg pr_number "${pr_number}" \
		--arg head_ref_oid "${head_ref_oid}" \
		--argjson rollup_count "${rollup_count}" \
		"${JQ_VERIFY_RUNS}" <<<"${runs_json}")"
	runs_jq_status=$?
	set -e
	if [[ ${runs_jq_status} -ne 0 ]]; then
		printf 'gh-bot-merge: jq exited %s while verifying workflow runs for %s.\n' "${runs_jq_status}" "${pr_url}" >&2
		exit "${runs_jq_status}"
	fi
	if [[ ${runs_verdict} != "OK" ]]; then
		die "${runs_verdict#ERR$'\x1f'}"
	fi
fi

# shellcheck disable=SC2016 # $owner, $repo, and $pr are GraphQL variables.
readonly PR_GRAPHQL_QUERY='query($owner: String!, $repo: String!, $pr: Int!) {
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
          commit {
            oid
          }
        }
      }
    }
  }
}'

# shellcheck disable=SC2016 # jq variables, not shell expansion.
readonly JQ_VERIFY_GRAPHQL='
def is_trusted_peer_login($login):
  $login == "flexiondotorg"
  or $login == "sith-skrye"
  or $login == "sith-traya"
  or $login == "sith-zannah";

(.data.repository.pullRequest // null) as $pr
| if ($pr | type) != "object" then
    "ERR\u001fGraphQL response did not identify pull request #" + $pr_number
  elif ($pr.reviewThreads.pageInfo.hasNextPage == true) or ((($pr_class == "trusted-peer") or ($failed_checks != "")) and ($pr.latestOpinionatedReviews.pageInfo.hasNextPage == true)) then
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
        and (.commit.oid // "") == $head_ref_oid
      ) as $has_peer_approval
    | ([
        $reviews[]
        | select(
            .state == "APPROVED"
            and (.author.login // "") != $author_login
            and is_trusted_peer_login(.author.login // "")
            and (.commit.oid // "") != $head_ref_oid
          )
        | (.commit.oid // "UNKNOWN")
      ]) as $stale_peer_oids
    | if $unresolved > 0 then
        "ERR\u001fpull request #" + $pr_number + " has " + ($unresolved | tostring) + " unresolved review thread(s)"
      elif ($review_decision == "CHANGES_REQUESTED") or $changes_requested then
        "ERR\u001fpull request #" + $pr_number + " has a review requesting changes"
      elif $pr_class != "trusted-peer" then
        if ($failed_checks != "") and ($has_peer_approval | not) then
          "ERR\u001fpull request #" + $pr_number + " has failing or pending status checks: " + $failed_checks
        else
          ["OK", ($has_peer_approval | tostring)] | join("\u001f")
        end
      elif ($viewer == $author_login) and ($has_peer_approval | not) then
        if ($stale_peer_oids | length) > 0 then
          "ERR\u001fpull request #" + $pr_number + " authored by " + $viewer + " has a stale peer approval on commit " + $stale_peer_oids[0] + " (expected headRefOid " + $head_ref_oid + ") and requires an APPROVED review on the head commit from another trusted peer before merging"
        else
          "ERR\u001fpull request #" + $pr_number + " authored by " + $viewer + " requires an APPROVED review from another trusted peer before merging"
        end
      else
        ["OK", ($has_peer_approval | tostring)] | join("\u001f")
      end
  end
'

set +e
graphql_json="$("${GH_BOT_MERGE_GH_BIN}" api graphql \
	-f "query=${PR_GRAPHQL_QUERY}" \
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
	--arg pr_class "${pr_class}" \
	--arg pr_number "${pr_number}" \
	--arg author_login "${author_login}" \
	--arg viewer "${viewer}" \
	--arg review_decision "${review_decision}" \
	--arg head_ref_oid "${head_ref_oid}" \
	--arg failed_checks "${failed_checks}" \
	"${JQ_VERIFY_GRAPHQL}" <<<"${graphql_json}")"
peer_jq_status=$?
set -e
if [[ ${peer_jq_status} -ne 0 ]]; then
	printf 'gh-bot-merge: jq exited %s while verifying review threads and reviews for %s.\n' "${peer_jq_status}" "${pr_url}" >&2
	exit "${peer_jq_status}"
fi

IFS=$'\x1f' read -r peer_verdict peer_field1 <<<"${peer_verify_out}"
if [[ ${peer_verdict} != "OK" ]]; then
	die "${peer_field1:-review thread or trusted-peer verification failed}"
fi
peer_approved="${peer_field1}"

needs_approve=false
if [[ ${pr_class} == "trusted-peer" ]]; then
	if [[ ${author_login} != "${viewer}" && ${peer_approved} != "true" ]]; then
		needs_approve=true
	fi
elif [[ ${author_login} != "${viewer}" && ${review_decision} != "APPROVED" && ${peer_approved} != "true" ]]; then
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
	"${GH_BOT_MERGE_GH_BIN}" pr merge "${pr_url}" --admin --squash --delete-branch --match-head-commit "${head_ref_oid}" </dev/null
	merge_status=$?
	set -e
	if [[ ${merge_status} -ne 0 ]]; then
		printf 'gh-bot-merge: gh exited %s while admin-merging %s.\n' "${merge_status}" "${pr_url}" >&2
		exit "${merge_status}"
	fi
else
	set +e
	"${GH_BOT_MERGE_GH_BIN}" pr merge "${pr_url}" --squash --delete-branch --match-head-commit "${head_ref_oid}" </dev/null
	merge_status=$?
	set -e
	if [[ ${merge_status} -ne 0 ]]; then
		set +e
		"${GH_BOT_MERGE_GH_BIN}" pr merge "${pr_url}" --admin --squash --delete-branch --match-head-commit "${head_ref_oid}" </dev/null
		admin_status=$?
		set -e
		if [[ ${admin_status} -ne 0 ]]; then
			printf 'gh-bot-merge: gh exited %s while merging %s (including --admin fallback).\n' "${admin_status}" "${pr_url}" >&2
			exit "${admin_status}"
		fi
	fi
fi

printf 'gh-bot-merge: merged %s (%s).\n' "${pr_url}" "${pr_class}"
