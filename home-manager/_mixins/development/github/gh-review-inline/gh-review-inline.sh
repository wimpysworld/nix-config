#!/usr/bin/env bash

# gh-review-inline: Fence-friendly helper for submitting a GitHub pull request
# review with line-anchored inline comments.
#
# `gh pr review` has no flags for inline `comments[]`, and raw `gh api` is
# denied under Fence. This helper closes that gap for one endpoint:
#
#   POST repos/{owner}/{repo}/pulls/{pr}/reviews

readonly EX_POLICY=64

die() {
	printf 'gh-review-inline: %s\n' "$*" >&2
	exit "${EX_POLICY}"
}

usage() {
	cat <<'EOF'
gh-review-inline: submit a GitHub pull request review with inline comments.

USAGE
    gh-review-inline <pr-url> --commit <40-hex-sha> [--event <COMMENT|APPROVE>]
        [--body-file <path>]
        --comment <repo-path>:<line> --comment-file <path>
        [--comment <repo-path>:<start-line>-<end-line> --comment-file <path> ...]
    gh-review-inline --help

EXAMPLE
    gh-review-inline https://github.com/wimpysworld/nix-config/pull/1136 \
        --commit f38afe1c3262f023814aa4411678363480db2492 \
        --event COMMENT \
        --comment nixos/_mixins/server/private-matrix/cauldron.js:133 \
        --comment-file finding-1.md

POLICY
    The first argument must be a pull request URL matching:
      ^https://github\.com/([A-Za-z0-9._-]+)/([A-Za-z0-9._-]+)/pull/([1-9][0-9]*)/?$

    --commit <40-hex-sha> is required. Before posting, gh-review-inline reads
    the pull request head SHA from GitHub and refuses to post if the head SHA
    has moved since the review ran.

    --event accepts only COMMENT (default) or APPROVE. REQUEST_CHANGES is
    rejected with exit 64.

    At least one --comment <spec> --comment-file <path> pair is required.
    <spec> is <repo-path>:<line> or <repo-path>:<start-line>-<end-line> on the
    RIGHT side of the diff. Every --comment-file (and optional --body-file)
    must be an existing, readable, non-empty regular file.
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
	--commit=* | --event=* | --body-file=* | --comment=* | --comment-file=*)
		die "glued flag '${arg}' is not accepted; pass the flag and value as separate arguments"
		;;
	esac
done

if [[ $# -lt 1 ]]; then
	die "expected <pr-url> as the first argument (try: gh-review-inline --help)"
fi

raw_url="$1"
if [[ ${raw_url} == -* ]]; then
	die "flag-like argument '${raw_url}' is not permitted in <pr-url> position"
fi

readonly URL_PATTERN='^https://github\.com/([A-Za-z0-9._-]+)/([A-Za-z0-9._-]+)/pull/([1-9][0-9]*)/?$'
if [[ ! ${raw_url} =~ ${URL_PATTERN} ]]; then
	die "pull request URL '${raw_url}' must match https://github.com/<owner>/<repo>/pull/<number>"
fi

owner="${BASH_REMATCH[1]}"
repo="${BASH_REMATCH[2]}"
pr_number="${BASH_REMATCH[3]}"

if [[ ${owner} == "." || ${owner} == ".." ]]; then
	die "owner '${owner}' is not a valid GitHub account name"
fi
if [[ ${repo} == "." || ${repo} == ".." ]]; then
	die "repository '${repo}' is not a valid GitHub repository name"
fi

shift
commit_sha=""
event="COMMENT"
body_file=""
declare -a comment_specs=()
declare -a comment_files=()
expecting_comment_file=false

while [[ $# -gt 0 ]]; do
	tok="$1"
	if [[ ${expecting_comment_file} == true ]]; then
		if [[ ${tok} != "--comment-file" ]]; then
			die "expected --comment-file immediately after --comment, got '${tok}'"
		fi
		if [[ $# -lt 2 ]]; then
			die "missing path after --comment-file"
		fi
		val="$2"
		if [[ ${val} == -* ]]; then
			die "flag-like argument '${val}' is not permitted as --comment-file path"
		fi
		comment_files+=("${val}")
		expecting_comment_file=false
		shift 2
		continue
	fi

	case "${tok}" in
	--commit)
		if [[ -n ${commit_sha} ]]; then
			die "--commit may only be specified once"
		fi
		if [[ $# -lt 2 ]]; then
			die "missing SHA after --commit"
		fi
		commit_sha="$2"
		shift 2
		;;
	--event)
		if [[ $# -lt 2 ]]; then
			die "missing value after --event"
		fi
		event="$2"
		shift 2
		;;
	--body-file)
		if [[ -n ${body_file} ]]; then
			die "--body-file may only be specified once"
		fi
		if [[ $# -lt 2 ]]; then
			die "missing path after --body-file"
		fi
		body_file="$2"
		if [[ ${body_file} == -* ]]; then
			die "flag-like argument '${body_file}' is not permitted as --body-file path"
		fi
		shift 2
		;;
	--comment)
		if [[ $# -lt 2 ]]; then
			die "missing <repo-path>:<line> after --comment"
		fi
		spec="$2"
		if [[ ${spec} == -* ]]; then
			die "flag-like argument '${spec}' is not permitted as --comment spec"
		fi
		comment_specs+=("${spec}")
		expecting_comment_file=true
		shift 2
		;;
	--comment-file)
		die "--comment-file must immediately follow a --comment <repo-path>:<line> argument"
		;;
	-*)
		die "flag '${tok}' is not permitted"
		;;
	*)
		die "unexpected positional argument '${tok}'"
		;;
	esac
done

if [[ ${expecting_comment_file} == true ]]; then
	die "missing --comment-file after the final --comment argument"
fi

if [[ -z ${commit_sha} ]]; then
	die "--commit <40-hex-sha> is required"
fi
if [[ ! ${commit_sha} =~ ^[0-9A-Fa-f]{40}$ ]]; then
	die "--commit '${commit_sha}' must be a 40-character hexadecimal commit SHA"
fi

case "${event}" in
COMMENT | APPROVE) ;;
REQUEST_CHANGES)
	die "event 'REQUEST_CHANGES' is not permitted; use COMMENT or APPROVE"
	;;
*)
	die "event '${event}' is not permitted; expected COMMENT or APPROVE"
	;;
esac

if [[ ${#comment_specs[@]} -eq 0 ]]; then
	die "at least one --comment <repo-path>:<line> --comment-file <path> pair is required"
fi

validate_regular_file() {
	local label="$1"
	local fpath="$2"
	if [[ ! -e ${fpath} ]]; then
		die "${label} '${fpath}' does not exist"
	fi
	if [[ ! -f ${fpath} ]]; then
		die "${label} '${fpath}' is not a regular file"
	fi
	if [[ ! -r ${fpath} ]]; then
		die "${label} '${fpath}' is not readable"
	fi
	if [[ ! -s ${fpath} ]]; then
		die "${label} '${fpath}' must not be empty"
	fi
}

if [[ -n ${body_file} ]]; then
	validate_regular_file "body file" "${body_file}"
fi

declare -a parsed_paths=()
declare -a parsed_start_lines=()
declare -a parsed_end_lines=()

readonly SPEC_SINGLE='^(.+):([1-9][0-9]*)$'
readonly SPEC_RANGE='^(.+):([1-9][0-9]*)-([1-9][0-9]*)$'

idx=0
while [[ ${idx} -lt ${#comment_specs[@]} ]]; do
	spec="${comment_specs[${idx}]}"
	cfile="${comment_files[${idx}]}"
	validate_regular_file "comment file" "${cfile}"

	cpath=""
	start_line=""
	end_line=""
	if [[ ${spec} =~ ${SPEC_RANGE} ]]; then
		cpath="${BASH_REMATCH[1]}"
		start_line="${BASH_REMATCH[2]}"
		end_line="${BASH_REMATCH[3]}"
		if ((10#${start_line} >= 10#${end_line})); then
			die "comment range '${spec}' must have start-line < end-line"
		fi
	elif [[ ${spec} =~ ${SPEC_SINGLE} ]]; then
		cpath="${BASH_REMATCH[1]}"
		start_line=""
		end_line="${BASH_REMATCH[2]}"
	else
		die "comment spec '${spec}' must match <repo-path>:<line> or <repo-path>:<start-line>-<end-line>"
	fi

	if [[ -z ${cpath} || ${cpath} == /* || ${cpath} == ./* || ${cpath} == ../* || ${cpath} == "." || ${cpath} == ".." ]]; then
		die "comment path '${cpath}' must be a clean relative repository path"
	fi
	if [[ ${cpath} == *"//"* || ${cpath} == *"/./"* || ${cpath} == *"/../"* || ${cpath} == *"/." || ${cpath} == *"/.." ]]; then
		die "comment path '${cpath}' must not contain empty, '.', or '..' path segments"
	fi
	if [[ ${cpath} == *$'\n'* || ${cpath} == *$'\r'* ]]; then
		die "comment path '${cpath}' must not contain control characters"
	fi

	parsed_paths+=("${cpath}")
	parsed_start_lines+=("${start_line}")
	parsed_end_lines+=("${end_line}")
	idx=$((idx + 1))
done

if [[ -z ${GH_REVIEW_INLINE_GH_BIN:-} ]]; then
	readonly GH_REVIEW_INLINE_GH_BIN="gh"
fi
export GH_PROMPT_DISABLED=true
export GH_TELEMETRY=false

pr_meta_path="repos/${owner}/${repo}/pulls/${pr_number}"
set +e
head_sha="$("${GH_REVIEW_INLINE_GH_BIN}" api "${pr_meta_path}" --jq '.head.sha // empty' </dev/null)"
head_status=$?
set -e
if [[ ${head_status} -ne 0 ]]; then
	printf 'gh-review-inline: gh exited %s while reading pull request %s at %s.\n' "${head_status}" "${pr_number}" "${pr_meta_path}" >&2
	exit "${head_status}"
fi
if [[ -z ${head_sha} ]]; then
	die "could not determine current head SHA for pull request #${pr_number}"
fi
if [[ "${head_sha,,}" != "${commit_sha,,}" ]]; then
	die "pull request #${pr_number} head SHA moved (expected ${commit_sha}, found ${head_sha}); re-verify against the new head before posting"
fi

comments_json="[]"
idx=0
while [[ ${idx} -lt ${#comment_specs[@]} ]]; do
	cpath="${parsed_paths[${idx}]}"
	sline="${parsed_start_lines[${idx}]}"
	eline="${parsed_end_lines[${idx}]}"
	cfile="${comment_files[${idx}]}"

	set +e
	if [[ -n ${sline} ]]; then
		entry_json="$(jq -Rs \
			--arg path "${cpath}" \
			--argjson start_line "${sline}" \
			--argjson line "${eline}" \
			'{path: $path, start_line: $start_line, start_side: "RIGHT", line: $line, side: "RIGHT", body: .}' <"${cfile}")"
	else
		entry_json="$(jq -Rs \
			--arg path "${cpath}" \
			--argjson line "${eline}" \
			'{path: $path, line: $line, side: "RIGHT", body: .}' <"${cfile}")"
	fi
	entry_status=$?
	set -e
	if [[ ${entry_status} -ne 0 ]]; then
		printf 'gh-review-inline: jq exited %s while encoding %s.\n' "${entry_status}" "${cfile}" >&2
		exit "${entry_status}"
	fi

	comments_json="$(jq -c --argjson item "${entry_json}" '. + [$item]' <<<"${comments_json}")"
	idx=$((idx + 1))
done

review_body=""
if [[ -n ${body_file} ]]; then
	set +e
	review_body_json="$(jq -Rs '.' <"${body_file}")"
	body_status=$?
	set -e
	if [[ ${body_status} -ne 0 ]]; then
		printf 'gh-review-inline: jq exited %s while encoding %s.\n' "${body_status}" "${body_file}" >&2
		exit "${body_status}"
	fi
	review_body="$(jq -r '.' <<<"${review_body_json}")"
fi

payload_json="$(jq -c -n \
	--arg commit_id "${head_sha}" \
	--arg event "${event}" \
	--arg body "${review_body}" \
	--argjson comments "${comments_json}" \
	'{commit_id: $commit_id, event: $event, body: $body, comments: $comments}')"

reviews_path="repos/${owner}/${repo}/pulls/${pr_number}/reviews"
set +e
"${GH_REVIEW_INLINE_GH_BIN}" api --method POST "${reviews_path}" --input - <<<"${payload_json}"
post_status=$?
set -e
if [[ ${post_status} -ne 0 ]]; then
	printf 'gh-review-inline: gh exited %s while posting inline review for pull request #%s at %s.\n' "${post_status}" "${pr_number}" "${reviews_path}" >&2
	exit "${post_status}"
fi
