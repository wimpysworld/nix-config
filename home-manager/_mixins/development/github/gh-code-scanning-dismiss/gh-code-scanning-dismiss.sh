#!/usr/bin/env bash

# This helper dismisses one GitHub code-scanning alert through a fixed REST endpoint.
# The package binds the GitHub CLI backend to a private absolute executable.

readonly EX_POLICY=64
readonly EX_DATAERR=65

policy_error() {
	printf 'gh-code-scanning-dismiss: %s\n' "$1" >&2
	exit "${EX_POLICY}"
}

data_error() {
	printf 'gh-code-scanning-dismiss: %s\n' "$1" >&2
	exit "${EX_DATAERR}"
}

response_identifies_alert() {
	jq -e --arg api_url "${api_url}" --arg html_url "${html_url}" --arg number "${alert_number}" '
    def same_identity($expected):
      type == "string" and (ascii_downcase == ($expected | ascii_downcase));
    type == "object"
    and ((.number | type) == "number")
    and ((.number | tostring) == $number)
    and (has("url") or has("html_url"))
    and ((has("url") | not) or (.url | same_identity($api_url)))
    and ((has("html_url") | not) or (.html_url | same_identity($html_url)))
  ' >/dev/null 2>&1
}

usage() {
	cat <<'EOF'
gh-code-scanning-dismiss: dismiss one GitHub code-scanning alert.

USAGE
    gh-code-scanning-dismiss https://github.com/OWNER/REPO/security/code-scanning/NUMBER \
        --reason REASON --comment-file PATH
    gh-code-scanning-dismiss --help

REASONS
    false positive
    won't fix
    used in tests
    mitigated

POLICY
    The argument order is fixed. The URL must use HTTPS on github.com.
    The path must contain only an owner, a repository, and a positive decimal alert number.
    The owner and repository accept letters, digits, dots, underscores, and hyphens.
    The owner and repository must not equal "." or "..".

    The comment must be a readable regular UTF-8 file.
    The comment must contain a non-whitespace character.
    The limit is 280 Unicode characters, including newline characters.

    The helper first reads the exact alert endpoint.
    The response must name the requested open alert.
    The helper then sends one PATCH with fixed state "dismissed".
    The PATCH contains the selected reason and comment.
    The helper verifies the PATCH response before it reports success.

    The GET and PATCH are separate requests.
    The alert can change between them, and the helper makes no atomic claim.
    A response that does not match the requested dismissal makes the helper fail.

    Policy errors exit 64.
    GitHub CLI request failures preserve the GitHub CLI exit status.
    The helper does not retry, reopen alerts, change assignees, or request approvals.
EOF
}

if [[ $# -eq 1 && $1 == "--help" ]]; then
	usage
	exit 0
fi

if [[ $# -ne 5 ]]; then
	policy_error "expected exactly 5 ordered arguments (try: gh-code-scanning-dismiss --help)"
fi

if [[ $2 != "--reason" ]]; then
	policy_error "the second argument must be --reason"
fi

if [[ $4 != "--comment-file" ]]; then
	policy_error "the fourth argument must be --comment-file"
fi

url="$1"
reason="$3"
comment_file="$5"

case "${reason}" in
"false positive" | "won't fix" | "used in tests" | mitigated) ;;
*) policy_error "reason must be one of: false positive, won't fix, used in tests, mitigated" ;;
esac

readonly URL_PATTERN='^https://github\.com/([A-Za-z0-9._-]+)/([A-Za-z0-9._-]+)/security/code-scanning/([1-9][0-9]*)$'
if [[ ! ${url} =~ ${URL_PATTERN} ]]; then
	policy_error "URL must exactly match https://github.com/OWNER/REPO/security/code-scanning/NUMBER"
fi

owner="${BASH_REMATCH[1]}"
repo="${BASH_REMATCH[2]}"
alert_number="${BASH_REMATCH[3]}"

if [[ ${owner} == "." || ${owner} == ".." ]]; then
	policy_error "owner must not be . or .."
fi

if [[ ${repo} == "." || ${repo} == ".." ]]; then
	policy_error "repository must not be . or .."
fi

if [[ ! -e ${comment_file} ]]; then
	policy_error "comment file does not exist"
fi

if [[ ! -f ${comment_file} ]]; then
	policy_error "comment file is not a regular file"
fi

if [[ ! -r ${comment_file} ]]; then
	policy_error "comment file is not readable"
fi

comment_snapshot="$(mktemp)"
payload_file="$(mktemp)"
runtime_config=""
token=""
cleanup() {
	unset token GH_TOKEN GITHUB_TOKEN
	rm -f "${comment_snapshot}" "${payload_file}"
	if [[ -n ${runtime_config} ]]; then
		rm -rf "${runtime_config}"
	fi
}
trap cleanup EXIT
if ! cat -- "${comment_file}" >"${comment_snapshot}"; then
	policy_error "comment file could not be read"
fi

if ! iconv -f UTF-8 -t UTF-8 <"${comment_snapshot}" >/dev/null 2>&1; then
	policy_error "comment file is not valid UTF-8"
fi

set +e
comment_metadata="$(jq -r -Rs '[length, test("\\S")] | @tsv' <"${comment_snapshot}" 2>/dev/null)"
jq_status=$?
set -e
if [[ ${jq_status} -ne 0 ]]; then
	printf 'gh-code-scanning-dismiss: jq exited %s while checking the comment file.\n' "${jq_status}" >&2
	exit "${jq_status}"
fi

comment_length="${comment_metadata%%$'\t'*}"
comment_has_text="${comment_metadata#*$'\t'}"
if [[ ${comment_has_text} != "true" ]]; then
	policy_error "comment file must contain a non-whitespace character"
fi

if ((comment_length > 280)); then
	policy_error "comment file must not exceed 280 Unicode characters"
fi

set +e
jq -n --arg reason "${reason}" --rawfile comment "${comment_snapshot}" \
	'{state: "dismissed", dismissed_reason: $reason, dismissed_comment: $comment}' \
	>"${payload_file}" 2>/dev/null
jq_status=$?
set -e
if [[ ${jq_status} -ne 0 ]]; then
	printf 'gh-code-scanning-dismiss: jq exited %s while encoding the dismissal request.\n' "${jq_status}" >&2
	exit "${jq_status}"
fi

endpoint="repos/${owner}/${repo}/code-scanning/alerts/${alert_number}"
api_url="https://api.github.com/${endpoint}"
html_url="https://github.com/${owner}/${repo}/security/code-scanning/${alert_number}"

# Debug output can expose the token or comment. Credential lookup uses the
# original configuration, but all HTTP requests use an empty private directory.
unset GH_DEBUG DEBUG
if [[ -n ${GH_TOKEN:-} ]]; then
	token="${GH_TOKEN}"
elif [[ -n ${GITHUB_TOKEN:-} ]]; then
	token="${GITHUB_TOKEN}"
else
	set +e
	token="$("${GH_CODE_SCANNING_DISMISS_GH}" auth token --hostname github.com </dev/null 2>/dev/null)"
	token_status=$?
	set -e
	if [[ ${token_status} -ne 0 ]]; then
		printf 'gh-code-scanning-dismiss: GitHub CLI exited %s while reading credentials for github.com.\n' \
			"${token_status}" >&2
		exit "${token_status}"
	fi
fi
if [[ -z ${token} ]]; then
	data_error "GitHub CLI returned an empty credential for github.com"
fi
unset GH_TOKEN GITHUB_TOKEN GH_HOST GH_ENTERPRISE_TOKEN GITHUB_ENTERPRISE_TOKEN
unset HTTP_PROXY HTTPS_PROXY ALL_PROXY NO_PROXY http_proxy https_proxy all_proxy no_proxy
unset SSL_CERT_FILE SSL_CERT_DIR CURL_CA_BUNDLE REQUESTS_CA_BUNDLE GIT_SSL_CAINFO GIT_SSL_CAPATH NODE_EXTRA_CA_CERTS
runtime_config="$(mktemp -d)"
chmod 700 "${runtime_config}"
export GH_CONFIG_DIR="${runtime_config}"
export GH_PROMPT_DISABLED=true
export GH_TELEMETRY=false
export GH_NO_UPDATE_NOTIFIER=true
export GH_NO_EXTENSION_UPDATE_NOTIFIER=true
export SSL_CERT_FILE="${GH_CODE_SCANNING_DISMISS_CA_BUNDLE}"
export NIX_SSL_CERT_FILE="${GH_CODE_SCANNING_DISMISS_CA_BUNDLE}"

set +e
get_response="$(GH_TOKEN="${token}" "${GH_CODE_SCANNING_DISMISS_GH}" api --hostname github.com --method GET "${endpoint}" </dev/null 2>/dev/null)"
get_status=$?
set -e
if [[ ${get_status} -ne 0 ]]; then
	printf 'gh-code-scanning-dismiss: GitHub CLI exited %s while reading alert %s on %s/%s.\n' \
		"${get_status}" "${alert_number}" "${owner}" "${repo}" >&2
	exit "${get_status}"
fi

if ! response_identifies_alert <<<"${get_response}"; then
	data_error "GET response did not identify the requested alert"
fi

if ! jq -e '.state == "open"' <<<"${get_response}" >/dev/null 2>&1; then
	data_error "requested alert is not open"
fi

set +e
patch_response="$(GH_TOKEN="${token}" "${GH_CODE_SCANNING_DISMISS_GH}" api --hostname github.com --method PATCH "${endpoint}" \
	--input "${payload_file}" </dev/null 2>/dev/null)"
patch_status=$?
set -e
if [[ ${patch_status} -ne 0 ]]; then
	printf 'gh-code-scanning-dismiss: GitHub CLI exited %s while dismissing alert %s on %s/%s.\n' \
		"${patch_status}" "${alert_number}" "${owner}" "${repo}" >&2
	exit "${patch_status}"
fi

unset token
if ! response_identifies_alert <<<"${patch_response}" ||
	! jq -e --slurpfile intended "${payload_file}" '
    type == "object"
    and (.state == $intended[0].state)
    and (.dismissed_reason == $intended[0].dismissed_reason)
    and (.dismissed_comment == $intended[0].dismissed_comment)
  ' <<<"${patch_response}" >/dev/null 2>&1; then
	data_error "PATCH response did not confirm the requested dismissal"
fi

printf 'gh-code-scanning-dismiss: dismissed code-scanning alert %s on %s/%s.\n' \
	"${alert_number}" "${owner}" "${repo}"
