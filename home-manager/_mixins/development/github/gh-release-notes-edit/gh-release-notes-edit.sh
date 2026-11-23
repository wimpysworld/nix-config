#!/usr/bin/env bash

# gh-release-notes-edit: Fence-friendly helper for updating the release notes
# body on one existing GitHub release (published or draft).
#
# `gh release` mutations and raw `gh api` are denied under Fence. This helper
# exposes one fixed write endpoint:
#
#   PATCH repos/{owner}/{repo}/releases/{id}  with payload {"body": ...}

readonly EX_POLICY=64

die() {
	printf 'gh-release-notes-edit: %s\n' "$*" >&2
	exit "${EX_POLICY}"
}

usage() {
	cat <<'EOF'
gh-release-notes-edit: update the notes body of one existing GitHub release.

USAGE
    gh-release-notes-edit <owner/repo> <tag> --notes-file <file>
    gh-release-notes-edit -h | --help

EXAMPLE
    gh-release-notes-edit wimpysworld/nix-config v1.2.3 --notes-file notes.md

POLICY
    Exactly four ordered arguments are required. Any other flag, glued flag,
    or extra argument is rejected with exit 64.

    <owner/repo> must match ^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$ and neither
    segment may equal "." or "..".

    <tag> must be non-empty, contain no whitespace or control characters, and
    contain no "." or ".." path segments.

    <file> must be a readable regular UTF-8 file containing at least one
    non-whitespace character.

    The helper resolves an existing release via GET on
    repos/<owner>/<repo>/releases/tags/<uri-encoded-tag>. When that returns
    HTTP 404 (for example, a draft release), it queries
    repos/<owner>/<repo>/releases?per_page=100 with --paginate and matches
    .tag_name == <tag>. Zero matches or multiple matching drafts fail without
    sending a PATCH.

    The PATCH sends only {"body": ...} to repos/<owner>/<repo>/releases/<id>,
    preserving all other release fields and assets. It never creates or deletes
    a release.
EOF
}

if [[ $# -eq 1 && ($1 == "-h" || $1 == "--help") ]]; then
	usage
	exit 0
fi

if [[ $# -ne 4 ]]; then
	die "expected exactly 4 arguments: <owner/repo> <tag> --notes-file <file> (try: gh-release-notes-edit --help)"
fi

owner_repo="$1"
tag="$2"
flag="$3"
notes_file="$4"

if [[ ${flag} == --notes-file=* ]]; then
	die "glued flag '${flag}' is not accepted; pass --notes-file and <file> as separate arguments"
fi

if [[ ${flag} != "--notes-file" ]]; then
	die "third argument must be --notes-file, got '${flag}'"
fi

if [[ ${owner_repo} == -* ]]; then
	die "flag-like argument '${owner_repo}' is not permitted in <owner/repo> position"
fi

readonly REPO_PATTERN='^([A-Za-z0-9._-]+)/([A-Za-z0-9._-]+)$'
if [[ ! ${owner_repo} =~ ${REPO_PATTERN} ]]; then
	die "repository '${owner_repo}' must match <owner>/<repo>"
fi

owner="${BASH_REMATCH[1]}"
repo="${BASH_REMATCH[2]}"

if [[ ${owner} == "." || ${owner} == ".." ]]; then
	die "owner '${owner}' must not be . or .."
fi

if [[ ${repo} == "." || ${repo} == ".." ]]; then
	die "repository '${repo}' must not be . or .."
fi

if [[ -z ${tag} ]]; then
	die "tag must not be empty"
fi

if [[ ${tag} == -* ]]; then
	die "flag-like argument '${tag}' is not permitted in <tag> position"
fi

if [[ ${tag} =~ [[:space:][:cntrl:]] ]]; then
	die "tag must not contain whitespace or control characters"
fi

if [[ ${tag} == "." || ${tag} == ".." || ${tag} == "./"* || ${tag} == "../"* || ${tag} == *"/." || ${tag} == *"/.." || ${tag} == *"/./"* || ${tag} == *"/../"* ]]; then
	die "tag '${tag}' must not contain '.' or '..' path segments"
fi

if [[ -z ${notes_file} ]]; then
	die "notes file path must not be empty"
fi

if [[ ${notes_file} == -* ]]; then
	die "flag-like argument '${notes_file}' is not permitted as --notes-file path"
fi

if [[ ! -e ${notes_file} ]]; then
	die "notes file '${notes_file}' does not exist"
fi

if [[ ! -f ${notes_file} ]]; then
	die "notes file '${notes_file}' is not a regular file"
fi

if [[ ! -r ${notes_file} ]]; then
	die "notes file '${notes_file}' is not readable"
fi

work_dir="$(mktemp -d)"
chmod 700 "${work_dir}"
cleanup() {
	rm -rf "${work_dir}"
}
trap cleanup EXIT

notes_snapshot="${work_dir}/notes.md"
payload_file="${work_dir}/payload.json"
tag_stdout="${work_dir}/tag.stdout"
tag_stderr="${work_dir}/tag.stderr"
list_stdout="${work_dir}/list.stdout"
list_stderr="${work_dir}/list.stderr"
patch_stdout="${work_dir}/patch.stdout"
patch_stderr="${work_dir}/patch.stderr"

if ! cat -- "${notes_file}" >"${notes_snapshot}"; then
	die "notes file '${notes_file}' could not be read"
fi

if ! iconv -f UTF-8 -t UTF-8 <"${notes_snapshot}" >/dev/null 2>&1; then
	die "notes file '${notes_file}' is not valid UTF-8"
fi

set +e
notes_has_text="$(jq -r -Rs 'test("\\S")' <"${notes_snapshot}" 2>/dev/null)"
jq_status=$?
set -e
if [[ ${jq_status} -ne 0 ]]; then
	printf 'gh-release-notes-edit: jq exited %s while checking the notes file.\n' "${jq_status}" >&2
	exit "${jq_status}"
fi

if [[ ${notes_has_text} != "true" ]]; then
	die "notes file '${notes_file}' must contain a non-whitespace character"
fi

set +e
jq -Rs '{body: .}' <"${notes_snapshot}" >"${payload_file}"
jq_status=$?
set -e
if [[ ${jq_status} -ne 0 ]]; then
	printf 'gh-release-notes-edit: jq exited %s while encoding the notes file.\n' "${jq_status}" >&2
	exit "${jq_status}"
fi

if [[ -z ${GH_RELEASE_NOTES_EDIT_GH_BIN:-} ]]; then
	readonly GH_RELEASE_NOTES_EDIT_GH_BIN="gh"
fi
unset GH_DEBUG DEBUG GH_HOST
export GH_PROMPT_DISABLED=true
export GH_TELEMETRY=false

set +e
encoded_tag="$(jq -rn --arg tag "${tag}" '$tag | @uri')"
jq_status=$?
set -e
if [[ ${jq_status} -ne 0 || -z ${encoded_tag} ]]; then
	printf 'gh-release-notes-edit: failed to URI-encode tag %s.\n' "${tag}" >&2
	exit 1
fi

tag_endpoint="repos/${owner}/${repo}/releases/tags/${encoded_tag}"
release_id=""

set +e
"${GH_RELEASE_NOTES_EDIT_GH_BIN}" api --hostname github.com --method GET "${tag_endpoint}" \
	</dev/null >"${tag_stdout}" 2>"${tag_stderr}"
tag_status=$?
set -e

if [[ ${tag_status} -eq 0 ]]; then
	set +e
	release_id="$(jq -r 'if type == "object" and (.id | type) == "number" then (.id | tostring) else empty end' <"${tag_stdout}" 2>/dev/null)"
	set -e
else
	is_not_found=false
	if grep -q 'HTTP 404' "${tag_stderr}" 2>/dev/null; then
		is_not_found=true
	elif jq -e 'type == "object" and (.status == "404" or .status == 404 or .message == "Not Found")' <"${tag_stdout}" >/dev/null 2>&1; then
		is_not_found=true
	fi

	if [[ ${is_not_found} != true ]]; then
		printf 'gh-release-notes-edit: gh exited %s while reading release %s on %s/%s.\n' \
			"${tag_status}" "${tag}" "${owner}" "${repo}" >&2
		if [[ -s ${tag_stderr} ]]; then
			cat "${tag_stderr}" >&2
		fi
		exit "${tag_status}"
	fi

	list_endpoint="repos/${owner}/${repo}/releases?per_page=100"
	set +e
	"${GH_RELEASE_NOTES_EDIT_GH_BIN}" api --hostname github.com --method GET --paginate "${list_endpoint}" \
		</dev/null >"${list_stdout}" 2>"${list_stderr}"
	list_status=$?
	set -e
	if [[ ${list_status} -ne 0 ]]; then
		printf 'gh-release-notes-edit: gh exited %s while listing releases on %s/%s.\n' \
			"${list_status}" "${owner}" "${repo}" >&2
		if [[ -s ${list_stderr} ]]; then
			cat "${list_stderr}" >&2
		fi
		exit "${list_status}"
	fi

	set +e
	matches_json="$(jq -s -c --arg tag "${tag}" \
		'map(if type == "array" then . else [.] end) | add // [] | map(select(type == "object" and .tag_name == $tag))' \
		<"${list_stdout}" 2>/dev/null)"
	jq_status=$?
	set -e
	if [[ ${jq_status} -ne 0 ]]; then
		printf 'gh-release-notes-edit: failed to parse releases list for %s/%s.\n' "${owner}" "${repo}" >&2
		exit 1
	fi

	match_count="$(jq -r 'length' <<<"${matches_json}")"
	if [[ ${match_count} -eq 0 ]]; then
		printf 'gh-release-notes-edit: no release found for tag %s on %s/%s.\n' \
			"${tag}" "${owner}" "${repo}" >&2
		exit 1
	fi
	if [[ ${match_count} -gt 1 ]]; then
		printf 'gh-release-notes-edit: found %s releases matching tag %s on %s/%s; refusing ambiguous update.\n' \
			"${match_count}" "${tag}" "${owner}" "${repo}" >&2
		exit 1
	fi

	release_id="$(jq -r 'if (.[0].id | type) == "number" then (.[0].id | tostring) else empty end' <<<"${matches_json}")"
fi

if [[ ! ${release_id} =~ ^[0-9]+$ ]]; then
	printf 'gh-release-notes-edit: release lookup for tag %s on %s/%s returned invalid release id.\n' \
		"${tag}" "${owner}" "${repo}" >&2
	exit 1
fi

patch_endpoint="repos/${owner}/${repo}/releases/${release_id}"
set +e
"${GH_RELEASE_NOTES_EDIT_GH_BIN}" api --hostname github.com --method PATCH "${patch_endpoint}" --input - \
	<"${payload_file}" >"${patch_stdout}" 2>"${patch_stderr}"
patch_status=$?
set -e
if [[ ${patch_status} -ne 0 ]]; then
	printf 'gh-release-notes-edit: gh exited %s while updating release %s (%s) on %s/%s.\n' \
		"${patch_status}" "${tag}" "${release_id}" "${owner}" "${repo}" >&2
	if [[ -s ${patch_stderr} ]]; then
		cat "${patch_stderr}" >&2
	fi
	exit "${patch_status}"
fi

html_url="$(jq -r 'if type == "object" and (.html_url | type) == "string" then .html_url else empty end' <"${patch_stdout}" 2>/dev/null || true)"
if [[ -n ${html_url} ]]; then
	printf '%s\n' "${html_url}"
else
	printf 'gh-release-notes-edit: updated release %s (%s) on %s/%s.\n' \
		"${tag}" "${release_id}" "${owner}" "${repo}"
fi
