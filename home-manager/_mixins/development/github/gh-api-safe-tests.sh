#!/usr/bin/env bash

# gh-api-safe-tests: local policy tests for gh-api-safe.sh.
#
# Run this file directly from any directory:
#
#   bash home-manager/_mixins/development/github/gh-api-safe-tests.sh
#
# The test sets GH_API_SAFE_GH to a local stub. The stub records each call and
# never runs gh or opens a network connection.

set -uo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
helper="${script_dir}/gh-api-safe.sh"

if [[ ! -r ${helper} ]]; then
	printf 'gh-api-safe-tests: cannot read %s\n' "${helper}" >&2
	exit 1
fi

work="$(mktemp -d)"
trap 'rm -rf "${work}"' EXIT

stub_dir="${work}/bin"
mkdir -p "${stub_dir}"
cat >"${stub_dir}/gh-api-backend" <<'STUB'
#!/usr/bin/env bash
set -uo pipefail
printf 'call\n' >>"${GH_STUB_CALLS}"
: >"${GH_STUB_ARGV}"
for stub_arg in "$@"; do
	printf '%s\n' "${stub_arg}" >>"${GH_STUB_ARGV}"
done
exit "${GH_STUB_EXIT:-0}"
STUB
chmod +x "${stub_dir}/gh-api-backend"

export GH_API_SAFE_GH="${stub_dir}/gh-api-backend"
export GH_STUB_ARGV="${work}/backend-argv"
export GH_STUB_CALLS="${work}/backend-calls"

status=0
stdout=""
stderr=""
passes=0
failures=0

fail() {
	failures=$((failures + 1))
	printf 'FAIL: %s\n' "$1" >&2
	if [[ -n ${2:-} ]]; then
		printf '      %s\n' "$2" >&2
	fi
}

pass() {
	passes=$((passes + 1))
	printf 'ok: %s\n' "$1"
}

run_helper() {
	: >"${GH_STUB_ARGV}"
	: >"${GH_STUB_CALLS}"
	stdout="$(bash -euo pipefail "${helper}" "$@" 2>"${work}/stderr")"
	status=$?
	stderr="$(<"${work}/stderr")"
}

backend_call_count() {
	local count=0
	while IFS= read -r _; do
		count=$((count + 1))
	done <"${GH_STUB_CALLS}"
	printf '%d\n' "${count}"
}

assert_policy() {
	local label="$1"
	shift
	run_helper "$@"
	if [[ ${status} -ne 64 ]]; then
		fail "${label}" "expected exit 64, got ${status}: ${stderr}"
		return
	fi
	if [[ "$(backend_call_count)" -ne 0 ]]; then
		fail "${label}" 'backend was called despite the policy rejection'
		return
	fi
	pass "${label}"
}

assert_allowed() {
	local label="$1"
	local expected_argv="${work}/expected-argv"
	shift
	run_helper "$@"
	if [[ ${status} -ne 0 ]]; then
		fail "${label}" "expected exit 0, got ${status}: ${stderr}"
		return
	fi
	if [[ "$(backend_call_count)" -ne 1 ]]; then
		fail "${label}" "expected one backend call, got $(backend_call_count)"
		return
	fi
	printf '%s\n' api "$@" >"${expected_argv}"
	if ! cmp -s "${expected_argv}" "${GH_STUB_ARGV}"; then
		fail "${label}" 'backend argv did not match the accepted request'
		return
	fi
	pass "${label}"
}

# Help is local and must not call the backend.
run_helper --help
if [[ ${status} -ne 0 ]]; then
	fail '--help exits 0' "got ${status}"
elif [[ ${stdout} != *USAGE* || ${stdout} != *POLICY* ]]; then
	fail '--help exits 0' 'usage or policy text is missing'
elif [[ "$(backend_call_count)" -ne 0 ]]; then
	fail '--help exits 0' 'backend was called for help'
else
	pass '--help exits 0 without a backend call'
fi

# Representative allow-list paths and ordinary output flags reach only the
# local backend. These cases cover each REST allow-list family.
assert_allowed 'rate limit path' rate_limit
assert_allowed 'meta path' meta
assert_allowed 'octocat path' octocat
assert_allowed 'current user path' user
assert_allowed 'user child path' user/repos
assert_allowed 'named user path' users/octocat
assert_allowed 'organisation path' orgs/example
assert_allowed 'repository path with output flag' repos/example/project/issues --jq '.[].title'
assert_allowed 'search path' 'search/issues?q=repo:example/project'
assert_allowed 'notifications path' notifications --paginate
assert_allowed 'gist path' gists/1
assert_allowed 'licence path' licenses/mit
assert_allowed 'gitignore path' gitignore/templates
assert_allowed 'emoji path' emojis
assert_allowed 'feeds path' feeds
assert_allowed 'markdown path without a body' markdown

# Unknown paths and every sensitive deny-list family stop before the backend.
assert_policy 'unknown REST path' authorizations
assert_policy 'admin path' admin/keys
assert_policy 'enterprise path' enterprises/example
assert_policy 'SCIM path' scim/v2/organizations/example/Users
assert_policy 'application path' applications/client-id/token
assert_policy 'marketplace path' marketplace_listing/plans
assert_policy 'user SSH keys path' user/keys
assert_policy 'user GPG keys path' user/gpg_keys
assert_policy 'user signing keys path' user/ssh_signing_keys
assert_policy 'user email path' user/emails
assert_policy 'repository secrets path' repos/example/project/actions/secrets
assert_policy 'deploy keys path' repos/example/project/deploy-keys
assert_policy 'runner registration token path' repos/example/project/actions/runners/registration-token
assert_policy 'runner remove token path' orgs/example/actions/runners/remove-token

# Method flags are blocked in separate, long-equals, and glued short forms.
assert_policy 'separate -X method' repos/example/project -X DELETE
assert_policy 'separate --method' repos/example/project --method DELETE
assert_policy 'equals --method' repos/example/project --method=DELETE
assert_policy 'glued -X method' repos/example/project -XDELETE
assert_policy 'glued -X equals method' repos/example/project -X=DELETE
assert_policy 'grouped -iX method' repos/example/project -iX DELETE
assert_policy 'grouped -iX glued method' repos/example/project -iXDELETE

# REST fields and input can create a request body, so all forms are blocked.
assert_policy 'separate raw field' repos/example/project -f key=value
assert_policy 'glued raw field' repos/example/project -fkey=value
assert_policy 'grouped -if raw field' repos/example/project -if key=value
assert_policy 'grouped -if glued raw field' repos/example/project -ifkey=value
assert_policy 'separate typed field' repos/example/project -F key=value
assert_policy 'glued typed field' repos/example/project -Fkey=value
assert_policy 'grouped -iF typed field' repos/example/project -iF key=value
assert_policy 'grouped -iF glued typed field' repos/example/project -iFkey=value
assert_policy 'separate long field' repos/example/project --field key=value
assert_policy 'equals long field' repos/example/project --field=key=value
assert_policy 'separate long raw field' repos/example/project --raw-field key=value
assert_policy 'equals long raw field' repos/example/project --raw-field=key=value
assert_policy 'separate input' repos/example/project --input payload.json
assert_policy 'equals input' repos/example/project --input=payload.json

# GraphQL query fields pass when the query is read-only. Mutation words in
# comments and strings are removed before the heuristic checks the query.
assert_allowed 'GraphQL read through -f' graphql -f 'query={ viewer { login } }'
assert_allowed 'GraphQL read through -F' graphql -F 'query=query Viewer { viewer { login } }'
assert_allowed 'GraphQL read through --field' graphql --field 'query={ viewer { login } }'
assert_allowed 'GraphQL read through --raw-field=' graphql '--raw-field=query={ viewer { login } }'
assert_allowed 'GraphQL mutation word in a comment' graphql -f $'query={ viewer { login } } # mutation ignored\n'
assert_allowed 'GraphQL mutation word in a string' graphql -f 'query={ repository(name: "mutation") { id } }'
assert_allowed 'GraphQL mutation word in a block string' graphql -f 'query={ search(query: """mutation""") { issueCount } }'

# Write operations, subscriptions, extra fields, and indirect query files
# stop before the backend.
assert_policy 'GraphQL mutation' graphql -f 'query=mutation { addStar(input: {starrableId: "X"}) { clientMutationId } }'
assert_policy 'GraphQL named mutation' graphql -F 'query=mutation AddStar { addStar(input: {starrableId: "X"}) { clientMutationId } }'
assert_policy 'GraphQL subscription' graphql --field 'query=subscription { viewer { login } }'
assert_policy 'GraphQL missing query' graphql
assert_policy 'GraphQL non-query field' graphql -f owner=example
assert_policy 'GraphQL second non-query field' graphql -f 'query={ viewer { login } }' -f owner=example
assert_policy 'GraphQL @file through -f' graphql -f query=@query.graphql
assert_policy 'GraphQL @file through -F' graphql -F query=@query.graphql
assert_policy 'GraphQL @file through --field=' graphql --field=query=@query.graphql
assert_policy 'GraphQL input file' graphql -f 'query={ viewer { login } }' --input variables.json

printf '%d passed, %d failed\n' "${passes}" "${failures}"
if [[ ${failures} -ne 0 ]]; then
	exit 1
fi
