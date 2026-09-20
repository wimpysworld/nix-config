#!/usr/bin/env bash

# This offline test uses the fixed stub backend that the Nix check supplies.

set -uo pipefail

if [[ $# -ne 3 ]]; then
	printf 'tests.sh: expected the stub helper, encoder-failure helper, and real helper\n' >&2
	exit 1
fi
if [[ ${GH_CODE_SCANNING_DISMISS_NETWORK_ISOLATED:-0} != 1 ]]; then
	printf 'tests.sh: the real-backend test requires an isolated network\n' >&2
	exit 1
fi

helper="$1"
encoder_failure_helper="$2"
real_helper="$3"
work="$(mktemp -d)"
trap 'chmod u+r "${work}/unreadable" 2>/dev/null || true; rm -rf "${work}"' EXIT

export GH_CODE_SCANNING_DISMISS_STUB_DIR="${work}/stub"
export GH_CODE_SCANNING_DISMISS_EXPECTED_TOKEN='offline-environment-token'
export GH_TOKEN="${GH_CODE_SCANNING_DISMISS_EXPECTED_TOKEN}"
unset GITHUB_TOKEN
mkdir -p "${GH_CODE_SCANNING_DISMISS_STUB_DIR}"

passes=0
failures=0
status=0
stdout=""
stderr=""

pass() {
	passes=$((passes + 1))
	printf 'ok: %s\n' "$1"
}

fail() {
	failures=$((failures + 1))
	printf 'FAIL: %s\n' "$1" >&2
	if [[ -n ${2:-} ]]; then
		printf '      %s\n' "$2" >&2
	fi
}

reset_stub() {
	rm -f "${GH_CODE_SCANNING_DISMISS_STUB_DIR}"/*
	: >"${GH_CODE_SCANNING_DISMISS_STUB_DIR}/calls"
	: >"${GH_CODE_SCANNING_DISMISS_STUB_DIR}/auth-calls"
}

call_count() {
	wc -l <"${GH_CODE_SCANNING_DISMISS_STUB_DIR}/calls" | tr -d ' '
}

run_command() {
	local command="$1"
	shift
	stdout="$(${command} "$@" 2>"${work}/stderr")"
	status=$?
	stderr="$(cat "${work}/stderr")"
}

write_get() {
	local state="$1" number="${2:-42}"
	local api_url="${3:-https://api.github.com/repos/owner/repo/code-scanning/alerts/42}"
	local html_url="${4:-https://github.com/owner/repo/security/code-scanning/42}"
	jq -n --arg state "${state}" --argjson number "${number}" \
		--arg url "${api_url}" --arg html_url "${html_url}" \
		'{number: $number, url: $url, html_url: $html_url, state: $state}' \
		>"${GH_CODE_SCANNING_DISMISS_STUB_DIR}/response-1"
}

write_patch() {
	local reason="$1" comment_file="$2" state="${3:-dismissed}" number="${4:-42}"
	local api_url="${5:-https://api.github.com/repos/owner/repo/code-scanning/alerts/42}"
	local html_url="${6:-https://github.com/owner/repo/security/code-scanning/42}"
	jq -n --arg state "${state}" --arg reason "${reason}" --rawfile comment "${comment_file}" \
		--argjson number "${number}" --arg url "${api_url}" --arg html_url "${html_url}" \
		'{number: $number, url: $url, html_url: $html_url, state: $state,
          dismissed_reason: $reason, dismissed_comment: $comment}' \
		>"${GH_CODE_SCANNING_DISMISS_STUB_DIR}/response-2"
}

assert_policy() {
	local label="$1"
	shift
	reset_stub
	run_command "${helper}" "$@"
	if [[ ${status} -ne 64 ]]; then
		fail "${label}" "expected exit 64, got ${status}: ${stderr}"
	elif [[ $(call_count) -ne 0 ]]; then
		fail "${label}" "the backend received $(call_count) calls"
	else
		pass "${label}"
	fi
}

assert_get_rejected() {
	local label="$1" response="$2"
	reset_stub
	printf '%s\n' "${response}" >"${GH_CODE_SCANNING_DISMISS_STUB_DIR}/response-1"
	run_command "${helper}" "${url}" --reason mitigated --comment-file "${comment_file}"
	if [[ ${status} -eq 0 ]]; then
		fail "${label}" "the helper succeeded"
	elif [[ $(call_count) -ne 1 ]]; then
		fail "${label}" "expected one GET and no PATCH, got $(call_count) calls"
	else
		pass "${label}"
	fi
}

url='https://github.com/owner/repo/security/code-scanning/42'
comment_file="${work}/comment.md"
printf 'Café says "quoted".\n第二行\nSENSITIVE-COMMENT' >"${comment_file}"
inherited_config="${work}/inherited-config"
mkdir -p "${inherited_config}"
printf 'http_unix_socket: %s\n' "${work}/malicious.sock" >"${inherited_config}/config.yml"
export GH_CONFIG_DIR="${inherited_config}"

# The help form must stand alone.
reset_stub
run_command "${helper}" --help
if [[ ${status} -ne 0 || ${stdout} != *"USAGE"* || $(call_count) -ne 0 ]]; then
	fail '--help alone' "status ${status}, calls $(call_count)"
else
	pass '--help alone prints usage without a request'
fi
assert_policy '--help with arguments' --help --reason mitigated --comment-file "${comment_file}"

# Argument order and flag forms are fixed.
assert_policy 'no arguments'
assert_policy 'too few arguments' "${url}" --reason mitigated --comment-file
assert_policy 'too many arguments' "${url}" --reason mitigated --comment-file "${comment_file}" extra
assert_policy 'reordered flags' "${url}" --comment-file "${comment_file}" --reason mitigated
assert_policy 'glued reason flag' "${url}" --reason=mitigated x --comment-file "${comment_file}"
assert_policy 'glued comment flag' "${url}" --reason mitigated "--comment-file=${comment_file}" x
assert_policy 'extra method flag' "${url}" --reason mitigated --comment-file "${comment_file}" --method PATCH

# The URL must name one exact github.com code-scanning alert path.
assert_policy 'HTTP URL' 'http://github.com/owner/repo/security/code-scanning/42' --reason mitigated --comment-file "${comment_file}"
assert_policy 'credentials in URL' 'https://user@github.com/owner/repo/security/code-scanning/42' --reason mitigated --comment-file "${comment_file}"
assert_policy 'port in URL' 'https://github.com:443/owner/repo/security/code-scanning/42' --reason mitigated --comment-file "${comment_file}"
assert_policy 'different host' 'https://api.github.com/owner/repo/security/code-scanning/42' --reason mitigated --comment-file "${comment_file}"
assert_policy 'encoded owner' 'https://github.com/o%77ner/repo/security/code-scanning/42' --reason mitigated --comment-file "${comment_file}"
assert_policy 'dot owner' 'https://github.com/./repo/security/code-scanning/42' --reason mitigated --comment-file "${comment_file}"
assert_policy 'traversal owner' 'https://github.com/../repo/security/code-scanning/42' --reason mitigated --comment-file "${comment_file}"
assert_policy 'traversal repository' 'https://github.com/owner/../security/code-scanning/42' --reason mitigated --comment-file "${comment_file}"
assert_policy 'zero alert number' 'https://github.com/owner/repo/security/code-scanning/0' --reason mitigated --comment-file "${comment_file}"
assert_policy 'negative alert number' 'https://github.com/owner/repo/security/code-scanning/-1' --reason mitigated --comment-file "${comment_file}"
assert_policy 'query in URL' 'https://github.com/owner/repo/security/code-scanning/42?x=1' --reason mitigated --comment-file "${comment_file}"
assert_policy 'fragment in URL' 'https://github.com/owner/repo/security/code-scanning/42#x' --reason mitigated --comment-file "${comment_file}"
assert_policy 'trailing slash' 'https://github.com/owner/repo/security/code-scanning/42/' --reason mitigated --comment-file "${comment_file}"
assert_policy 'trailing path' 'https://github.com/owner/repo/security/code-scanning/42/extra' --reason mitigated --comment-file "${comment_file}"

# Only the four API reasons are accepted.
assert_policy 'empty reason' "${url}" --reason '' --comment-file "${comment_file}"
assert_policy 'similar reason' "${url}" --reason false-positive --comment-file "${comment_file}"
assert_policy 'case-changed reason' "${url}" --reason Mitigated --comment-file "${comment_file}"

# Invalid files must fail before the first request.
: >"${work}/empty"
printf ' \t\n' >"${work}/whitespace"
printf '\377' >"${work}/invalid-utf8"
mkdir "${work}/directory"
printf 'unreadable' >"${work}/unreadable"
chmod 000 "${work}/unreadable"
assert_policy 'missing comment file' "${url}" --reason mitigated --comment-file "${work}/missing"
assert_policy 'directory comment file' "${url}" --reason mitigated --comment-file "${work}/directory"
assert_policy 'unreadable comment file' "${url}" --reason mitigated --comment-file "${work}/unreadable"
assert_policy 'invalid UTF-8 comment' "${url}" --reason mitigated --comment-file "${work}/invalid-utf8"
assert_policy 'empty comment' "${url}" --reason mitigated --comment-file "${work}/empty"
assert_policy 'whitespace comment' "${url}" --reason mitigated --comment-file "${work}/whitespace"
chmod u+r "${work}/unreadable"

for ((i = 0; i < 280; i++)); do printf 'é'; done >"${work}/chars-280"
for ((i = 0; i < 281; i++)); do printf 'é'; done >"${work}/chars-281"
assert_policy '281 Unicode characters' "${url}" --reason mitigated --comment-file "${work}/chars-281"

# The happy path sends one GET and one PATCH.
reset_stub
write_get open
write_patch mitigated "${comment_file}"
GH_DEBUG=api DEBUG=1 GH_HOST=example.invalid \
	HTTP_PROXY=http://proxy.invalid HTTPS_PROXY=http://proxy.invalid ALL_PROXY=http://proxy.invalid \
	NO_PROXY=github.com SSL_CERT_FILE="${work}/poison-ca" SSL_CERT_DIR="${work}/poison-ca-dir" \
	CURL_CA_BUNDLE="${work}/poison-ca" REQUESTS_CA_BUNDLE="${work}/poison-ca" \
	GIT_SSL_CAINFO="${work}/poison-ca" NODE_EXTRA_CA_CERTS="${work}/poison-ca" \
	GH_CODE_SCANNING_DISMISS_GH="${work}/not-the-backend" \
	run_command "${helper}" "${url}" --reason mitigated --comment-file "${comment_file}"
if [[ ${status} -ne 0 ]]; then
	fail 'happy path succeeds' "status ${status}: ${stderr}"
elif [[ $(call_count) -ne 2 ]]; then
	fail 'happy path request count' "expected 2, got $(call_count)"
elif grep -q 'SENSITIVE-COMMENT' <<<"${stdout}${stderr}"; then
	fail 'output hides the comment body' 'the comment appeared in output'
else
	pass 'happy path makes one GET and one PATCH without body output'
fi

endpoint='repos/owner/repo/code-scanning/alerts/42'
for call in 1 2; do
	if [[ $(grep -cx -- '--hostname' "${GH_CODE_SCANNING_DISMISS_STUB_DIR}/argv-${call}") -ne 1 ]] ||
		! grep -qx 'github.com' "${GH_CODE_SCANNING_DISMISS_STUB_DIR}/argv-${call}" ||
		! grep -qx "${endpoint}" "${GH_CODE_SCANNING_DISMISS_STUB_DIR}/argv-${call}"; then
		fail 'fixed hostname and endpoint' "call ${call}: $(tr '\n' ' ' <"${GH_CODE_SCANNING_DISMISS_STUB_DIR}/argv-${call}")"
	else
		pass "call ${call} uses the fixed hostname and endpoint"
	fi
	config_dir="$(cat "${GH_CODE_SCANNING_DISMISS_STUB_DIR}/config-dir-${call}")"
	if [[ ${config_dir} == "${inherited_config}" ]]; then
		fail 'request configuration is isolated' "call ${call} retained the inherited directory"
	elif [[ $(cat "${GH_CODE_SCANNING_DISMISS_STUB_DIR}/config-mode-${call}") != 700 ]]; then
		fail 'request configuration is private' "call ${call} did not use mode 700"
	elif [[ $(cat "${GH_CODE_SCANNING_DISMISS_STUB_DIR}/config-files-${call}") != 0 ]]; then
		fail 'request configuration is empty' "call ${call} inherited configuration files"
	else
		pass "call ${call} uses an empty private configuration directory"
	fi
	if grep -q '=set$' "${GH_CODE_SCANNING_DISMISS_STUB_DIR}/environment-${call}"; then
		fail 'transport environment is cleared' "call ${call}: $(tr '\n' ' ' <"${GH_CODE_SCANNING_DISMISS_STUB_DIR}/environment-${call}")"
	else
		ca_file="$(sed -n 's/^SSL_CERT_FILE=//p' "${GH_CODE_SCANNING_DISMISS_STUB_DIR}/environment-${call}")"
		nix_ca_file="$(sed -n 's/^NIX_SSL_CERT_FILE=//p' "${GH_CODE_SCANNING_DISMISS_STUB_DIR}/environment-${call}")"
		if [[ ${ca_file} != "${nix_ca_file}" || ! -r ${ca_file} || ${ca_file} == "${work}/poison-ca" ]]; then
			fail 'controlled CA bundle is retained' "call ${call} used ${ca_file}"
		else
			pass "call ${call} clears transport overrides and uses the Nix CA bundle"
		fi
	fi
done

if [[ $(grep -cx GET "${GH_CODE_SCANNING_DISMISS_STUB_DIR}/argv-1") -ne 1 ]] ||
	[[ $(grep -cx PATCH "${GH_CODE_SCANNING_DISMISS_STUB_DIR}/argv-2") -ne 1 ]]; then
	fail 'fixed methods' 'the request methods did not match GET then PATCH'
else
	pass 'the helper sends GET then PATCH'
fi

# Credential selection follows gh precedence, and stored-token lookup keeps the original config.
reset_stub
write_get open
write_patch mitigated "${comment_file}"
export GH_CODE_SCANNING_DISMISS_EXPECTED_TOKEN='offline-first-token'
GH_TOKEN="${GH_CODE_SCANNING_DISMISS_EXPECTED_TOKEN}" GITHUB_TOKEN='offline-second-token' \
	run_command "${helper}" "${url}" --reason mitigated --comment-file "${comment_file}"
if [[ ${status} -eq 0 && $(wc -l <"${GH_CODE_SCANNING_DISMISS_STUB_DIR}/auth-calls") -eq 0 ]]; then
	pass 'GH_TOKEN takes precedence without stored-token lookup'
else
	fail 'GH_TOKEN takes precedence without stored-token lookup' "status ${status}"
fi

reset_stub
write_get open
write_patch mitigated "${comment_file}"
export GH_CODE_SCANNING_DISMISS_EXPECTED_TOKEN='offline-github-token'
GH_TOKEN='' GITHUB_TOKEN="${GH_CODE_SCANNING_DISMISS_EXPECTED_TOKEN}" \
	run_command "${helper}" "${url}" --reason mitigated --comment-file "${comment_file}"
if [[ ${status} -eq 0 && $(wc -l <"${GH_CODE_SCANNING_DISMISS_STUB_DIR}/auth-calls") -eq 0 ]]; then
	pass 'GITHUB_TOKEN is the environment fallback'
else
	fail 'GITHUB_TOKEN is the environment fallback' "status ${status}"
fi

reset_stub
write_get open
write_patch mitigated "${comment_file}"
export GH_CODE_SCANNING_DISMISS_EXPECTED_TOKEN='offline-stored-token'
export GH_CODE_SCANNING_DISMISS_STUB_AUTH_TOKEN="${GH_CODE_SCANNING_DISMISS_EXPECTED_TOKEN}"
unset GH_TOKEN GITHUB_TOKEN
run_command "${helper}" "${url}" --reason mitigated --comment-file "${comment_file}"
if [[ ${status} -ne 0 ]]; then
	fail 'stored credential lookup succeeds' "status ${status}: ${stderr}"
elif [[ $(wc -l <"${GH_CODE_SCANNING_DISMISS_STUB_DIR}/auth-calls") -ne 1 ]]; then
	fail 'stored credential lookup runs once' 'the auth token call count differed'
elif [[ $(cat "${GH_CODE_SCANNING_DISMISS_STUB_DIR}/auth-config-dir") != "${inherited_config}" ]]; then
	fail 'stored credential lookup uses original config' 'the lookup used the isolated config'
else
	pass 'stored credential lookup runs once under the original config'
fi
export GH_CODE_SCANNING_DISMISS_EXPECTED_TOKEN='offline-environment-token'
export GH_TOKEN="${GH_CODE_SCANNING_DISMISS_EXPECTED_TOKEN}"
unset GH_CODE_SCANNING_DISMISS_STUB_AUTH_TOKEN

payload="${GH_CODE_SCANNING_DISMISS_STUB_DIR}/request-2"
if [[ $(jq -c 'keys' <"${payload}") != '["dismissed_comment","dismissed_reason","state"]' ]]; then
	fail 'payload keys are fixed' "keys: $(jq -c 'keys' <"${payload}")"
elif [[ $(jq -r '.state' <"${payload}") != dismissed || $(jq -r '.dismissed_reason' <"${payload}") != mitigated ]]; then
	fail 'payload values are fixed' "payload: $(jq -c 'del(.dismissed_comment)' <"${payload}")"
else
	jq -j '.dismissed_comment' <"${payload}" >"${work}/roundtrip"
	if cmp -s "${comment_file}" "${work}/roundtrip"; then
		pass 'Unicode, quotes, and newlines round-trip exactly'
	else
		fail 'Unicode, quotes, and newlines round-trip exactly' 'the decoded comment differs'
	fi
fi

# All four reasons and the 280-character boundary are accepted.
for reason in 'false positive' "won't fix" 'used in tests'; do
	reset_stub
	write_get open
	write_patch "${reason}" "${comment_file}"
	run_command "${helper}" "${url}" --reason "${reason}" --comment-file "${comment_file}"
	if [[ ${status} -eq 0 && $(call_count) -eq 2 ]]; then
		pass "reason '${reason}' is accepted"
	else
		fail "reason '${reason}' is accepted" "status ${status}, calls $(call_count)"
	fi
done
reset_stub
write_get open
write_patch mitigated "${work}/chars-280"
run_command "${helper}" "${url}" --reason mitigated --comment-file "${work}/chars-280"
if [[ ${status} -eq 0 && $(call_count) -eq 2 ]]; then
	pass '280 Unicode characters are accepted'
else
	fail '280 Unicode characters are accepted' "status ${status}, calls $(call_count)"
fi

# Encoder failure must happen before the GET.
reset_stub
export GH_CODE_SCANNING_DISMISS_JQ_COUNT="${work}/jq-count"
rm -f "${GH_CODE_SCANNING_DISMISS_JQ_COUNT}"
run_command "${encoder_failure_helper}" "${url}" --reason mitigated --comment-file "${comment_file}"
if [[ ${status} -ne 73 ]]; then
	fail 'encoder failure status' "expected 73, got ${status}"
elif [[ $(call_count) -ne 0 ]]; then
	fail 'encoder failure makes no request' "calls: $(call_count)"
else
	pass 'encoder failure exits 73 before any request'
fi

# Documented response URLs identify the alert without a repository object.
for identity in api html; do
	reset_stub
	case "${identity}" in
	api)
		printf '%s\n' '{"number":42,"url":"https://api.github.com/repos/OWNER/REPO/code-scanning/alerts/42","state":"open"}' \
			>"${GH_CODE_SCANNING_DISMISS_STUB_DIR}/response-1"
		;;
	html)
		printf '%s\n' '{"number":42,"html_url":"https://github.com/OWNER/REPO/security/code-scanning/42","state":"open"}' \
			>"${GH_CODE_SCANNING_DISMISS_STUB_DIR}/response-1"
		;;
	esac
	write_patch mitigated "${comment_file}"
	run_command "${helper}" "${url}" --reason mitigated --comment-file "${comment_file}"
	if [[ ${status} -eq 0 && $(call_count) -eq 2 ]]; then
		pass "${identity} response identity works without repository metadata"
	else
		fail "${identity} response identity works without repository metadata" "status ${status}, calls $(call_count)"
	fi
done

# Invalid GET results prevent the PATCH.
assert_get_rejected 'malformed GET response' 'not-json'
assert_get_rejected 'wrong GET alert number' '{"number":43,"url":"https://api.github.com/repos/owner/repo/code-scanning/alerts/42","state":"open"}'
assert_get_rejected 'missing GET identity URLs' '{"number":42,"state":"open"}'
assert_get_rejected 'wrong GET API host' '{"number":42,"url":"https://evil.example/repos/owner/repo/code-scanning/alerts/42","state":"open"}'
assert_get_rejected 'wrong GET API repository' '{"number":42,"url":"https://api.github.com/repos/owner/other/code-scanning/alerts/42","state":"open"}'
assert_get_rejected 'wrong GET API number path' '{"number":42,"url":"https://api.github.com/repos/owner/repo/code-scanning/alerts/43","state":"open"}'
assert_get_rejected 'GET URL query suffix' '{"number":42,"url":"https://api.github.com/repos/owner/repo/code-scanning/alerts/42?x=1","state":"open"}'
assert_get_rejected 'wrong GET HTML path' '{"number":42,"html_url":"https://github.com/owner/repo/security/code-scanning/43","state":"open"}'
assert_get_rejected 'one wrong GET identity' '{"number":42,"url":"https://api.github.com/repos/owner/repo/code-scanning/alerts/42","html_url":"https://evil.example/owner/repo/security/code-scanning/42","state":"open"}'
assert_get_rejected 'non-open GET state' '{"number":42,"html_url":"https://github.com/owner/repo/security/code-scanning/42","state":"dismissed"}'

reset_stub
printf '22\n' >"${GH_CODE_SCANNING_DISMISS_STUB_DIR}/status-1"
run_command "${helper}" "${url}" --reason mitigated --comment-file "${comment_file}"
if [[ ${status} -ne 22 || $(call_count) -ne 1 ]]; then
	fail 'GET failure stops the helper' "status ${status}, calls $(call_count)"
else
	pass 'GET failure preserves status 22 and prevents PATCH'
fi

# A PATCH failure is not retried.
reset_stub
write_get open
printf '23\n' >"${GH_CODE_SCANNING_DISMISS_STUB_DIR}/status-2"
printf 'SENSITIVE-COMMENT from API\n' >"${GH_CODE_SCANNING_DISMISS_STUB_DIR}/response-2"
run_command "${helper}" "${url}" --reason mitigated --comment-file "${comment_file}"
if [[ ${status} -ne 23 || $(call_count) -ne 2 ]]; then
	fail 'PATCH failure stops without retry' "status ${status}, calls $(call_count)"
elif grep -q 'SENSITIVE-COMMENT' <<<"${stdout}${stderr}"; then
	fail 'PATCH failure hides response bodies' 'the body appeared in output'
else
	pass 'PATCH failure preserves status 23, hides bodies, and does not retry'
fi

# The PATCH response must confirm the target and every requested field.
for mismatch in number api-url html-url state reason comment; do
	reset_stub
	write_get open
	case "${mismatch}" in
	number) write_patch mitigated "${comment_file}" dismissed 43 ;;
	api-url) write_patch mitigated "${comment_file}" dismissed 42 https://api.github.com/repos/owner/other/code-scanning/alerts/42 ;;
	html-url) write_patch mitigated "${comment_file}" dismissed 42 \
		https://api.github.com/repos/owner/repo/code-scanning/alerts/42 \
		https://github.com/owner/other/security/code-scanning/42 ;;
	state) write_patch mitigated "${comment_file}" open ;;
	reason) write_patch "won't fix" "${comment_file}" ;;
	comment)
		printf 'different comment' >"${work}/different"
		write_patch mitigated "${work}/different"
		;;
	esac
	run_command "${helper}" "${url}" --reason mitigated --comment-file "${comment_file}"
	if [[ ${status} -eq 65 && $(call_count) -eq 2 ]]; then
		pass "PATCH ${mismatch} mismatch is rejected"
	else
		fail "PATCH ${mismatch} mismatch is rejected" "status ${status}, calls $(call_count)"
	fi
done

# The real gh backend must ignore an inherited http_unix_socket. The Nix check
# supplies the network sandbox, so a direct request cannot leave the builder.
malicious_dir="${work}/malicious-config"
malicious_socket="${work}/capture.sock"
malicious_hit="${work}/socket-hit"
malicious_ready="${work}/socket-ready"
mkdir -p "${malicious_dir}"
printf 'http_unix_socket: %s\n' "${malicious_socket}" >"${malicious_dir}/config.yml"
python3 - "${malicious_socket}" "${malicious_hit}" "${malicious_ready}" <<'PY' &
import pathlib
import socket
import sys

socket_path, hit_path, ready_path = sys.argv[1:]
server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
server.bind(socket_path)
server.listen(1)
server.settimeout(10)
pathlib.Path(ready_path).touch()
try:
    connection, _ = server.accept()
except TimeoutError:
    pass
else:
    pathlib.Path(hit_path).touch()
    connection.close()
finally:
    server.close()
PY
socket_pid=$!
for ((i = 0; i < 100; i++)); do
	[[ -e ${malicious_ready} ]] && break
	sleep 0.01
done
GH_CONFIG_DIR="${malicious_dir}" GH_TOKEN='offline-real-backend-token' GITHUB_TOKEN='' \
	run_command timeout 8 "${real_helper}" "${url}" --reason mitigated --comment-file "${comment_file}"
kill "${socket_pid}" 2>/dev/null || true
wait "${socket_pid}" 2>/dev/null || true
if [[ -e ${malicious_hit} ]]; then
	fail 'real backend ignores inherited http_unix_socket' 'the malicious socket received a request'
elif [[ ${status} -eq 0 ]]; then
	fail 'real backend remains offline' 'the real request unexpectedly succeeded'
else
	pass 'real backend ignores inherited http_unix_socket in the offline sandbox'
fi

printf '%s: %s passed, %s failed\n' \
	"$([[ ${failures} -eq 0 ]] && printf PASS || printf FAIL)" "${passes}" "${failures}"
[[ ${failures} -eq 0 ]]
