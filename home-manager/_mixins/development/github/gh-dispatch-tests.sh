#!/usr/bin/env bash

# gh-dispatch-tests: local policy tests for gh-dispatch.sh.
#
# Run this file directly from any directory:
#
#   bash home-manager/_mixins/development/github/gh-dispatch-tests.sh
#
# Both backends are local stubs. The tests do not open a network connection.

set -uo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
helper="${script_dir}/gh-dispatch.sh"

if [[ ! -r ${helper} ]]; then
	printf 'gh-dispatch-tests: cannot read %s\n' "${helper}" >&2
	exit 1
fi

work="$(mktemp -d)"
trap 'rm -rf "${work}"' EXIT
mkdir -p "${work}/bin"

# The quoted text is the generated stub, so its variables expand at runtime.
# shellcheck disable=SC2016
for backend in gh-backend api-safe; do
	apply_path="${work}/bin/${backend}"
	printf '%s\n' \
		'#!/usr/bin/env bash' \
		'set -uo pipefail' \
		'printf "%s\\n" "${0##*/}" >"${GH_STUB_KIND}"' \
		': >"${GH_STUB_ARGV}"' \
		'for arg in "$@"; do printf "%s\\n" "${arg}" >>"${GH_STUB_ARGV}"; done' \
		'printf "%s\\n" "${GH_TELEMETRY:-}" >"${GH_STUB_TELEMETRY}"' \
		'printf "call\\n" >>"${GH_STUB_CALLS}"' \
		'exit "${GH_STUB_EXIT:-0}"' >"${apply_path}"
	chmod +x "${apply_path}"
done

export GH_DISPATCH_GH="${work}/bin/gh-backend"
export GH_DISPATCH_API_SAFE="${work}/bin/api-safe"
export GH_STUB_ARGV="${work}/backend-argv"
export GH_STUB_CALLS="${work}/backend-calls"
export GH_STUB_KIND="${work}/backend-kind"
export GH_STUB_TELEMETRY="${work}/backend-telemetry"

status=0
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
	: >"${GH_STUB_KIND}"
	: >"${GH_STUB_TELEMETRY}"
	bash -euo pipefail "${helper}" "$@" >/dev/null 2>"${work}/stderr"
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

assert_blocked() {
	local label="$1"
	shift
	export FENCE_SANDBOX=1
	run_helper "$@"
	if [[ ${status} -ne 64 ]]; then
		fail "${label}" "expected exit 64, got ${status}: ${stderr}"
		return
	fi
	if [[ "$(backend_call_count)" -ne 0 ]]; then
		fail "${label}" 'a backend ran for a blocked command'
		return
	fi
	pass "${label}"
}

assert_backend() {
	local label="$1" fence="$2" expected_kind="$3"
	shift 3
	local expected_argv="${work}/expected-argv"
	export FENCE_SANDBOX="${fence}"
	run_helper "$@"
	if [[ ${status} -ne 0 ]]; then
		fail "${label}" "expected exit 0, got ${status}: ${stderr}"
		return
	fi
	if [[ "$(backend_call_count)" -ne 1 ]]; then
		fail "${label}" "expected one backend call, got $(backend_call_count)"
		return
	fi
	if [[ "$(<"${GH_STUB_KIND}")" != "${expected_kind}" ]]; then
		fail "${label}" "unexpected backend: $(<"${GH_STUB_KIND}")"
		return
	fi
	if [[ "$(<"${GH_STUB_TELEMETRY}")" != false ]]; then
		fail "${label}" 'the dispatcher did not disable telemetry'
		return
	fi
	if [[ ${expected_kind} == api-safe ]]; then
		shift
	fi
	printf '%s\n' "$@" >"${expected_argv}"
	if ! cmp -s "${expected_argv}" "${GH_STUB_ARGV}"; then
		fail "${label}" 'backend argv did not match'
		return
	fi
	pass "${label}"
}

# Unfenced calls always use the private gh backend.
assert_backend 'unfenced read' 0 gh-backend pr view 42
assert_backend 'unfenced destructive command' 0 gh-backend pr merge 42
assert_backend 'unset Fence marker' '' gh-backend workflow run build.yml

# Raw API calls use gh-api-safe only inside Fence.
assert_backend 'fenced REST API read' 1 api-safe api repos/example/project
assert_backend 'fenced GraphQL read' 1 api-safe api graphql -f 'query={ viewer { login } }'
assert_backend 'unfenced raw API call' 0 gh-backend api repos/example/project -X DELETE
assert_blocked 'flags before api are rejected' --repo example/project api repos/example/project

# Approved dedicated reads and writes reach the private backend.
assert_backend 'pull request comment' 1 gh-backend pr comment 42 --body-file reply.md
assert_backend 'issue creation' 1 gh-backend issue create --title Bug
assert_backend 'workflow rerun' 1 gh-backend run rerun 99
assert_backend 'workflow cancellation' 1 gh-backend run cancel 99
assert_backend 'workflow run list' 1 gh-backend run list
assert_backend 'workflow cache list' 1 gh-backend cache list
assert_backend 'pull request update' 1 gh-backend pr update-branch 42
assert_backend 'pull request approval' 1 gh-backend pr review 42 --approve
assert_backend 'release read' 1 gh-backend release view v1.0.0
assert_backend 'project item list' 1 gh-backend project item-list 2 --owner example
assert_backend 'project item add' 1 gh-backend project item-add 2 --owner example --url https://github.com/example/project/issues/1
assert_backend 'project item edit' 1 gh-backend project item-edit --id ITEM --project-id PROJECT --field-id FIELD --single-select-option-id OPTION
assert_backend 'deploy key list' 1 gh-backend repo deploy-key list
assert_backend 'alias list' 1 gh-backend alias list
assert_backend 'agent task list' 1 gh-backend agent-task list
assert_backend 'agent task view' 1 gh-backend agent-task view 42
assert_backend 'skill list' 1 gh-backend skill list
assert_backend 'skill preview' 1 gh-backend skill preview owner/skill
assert_backend 'skill search' 1 gh-backend skill search query
assert_backend 'discussion command' 1 gh-backend discussion list
assert_backend 'gh-dash extension' 1 gh-backend dash --help
assert_backend 'gh-enhance extension' 1 gh-backend enhance --help
assert_backend 'gh-markdown-preview extension' 1 gh-backend markdown-preview --help
assert_backend 'gh-notify extension' 1 gh-backend notify --help

# Representative exact and family-wide denies stop before either backend.
assert_blocked 'pull request merge' pr merge 42
assert_blocked 'workflow dispatch' workflow run build.yml
assert_blocked 'release creation' release create v1.0.0
assert_blocked 'project creation' project create --owner example --title Board
assert_blocked 'project field creation' project field-create 2 --owner example --name Size --data-type TEXT
assert_blocked 'project item deletion' project item-delete 2 --owner example --id ITEM
assert_blocked 'repository edit' repo edit --description changed
assert_blocked 'configuration read' config get oauth_token
assert_blocked 'secret read' secret get TOKEN
assert_blocked 'codespace logs' codespace logs
assert_blocked 'extension execution' extension exec dash
assert_blocked 'token injection' auth login --with-token
assert_blocked 'token injection with equals' auth login --with-token=token.txt
assert_blocked 'configured alias name' fenced-shell-alias
assert_blocked 'unmanaged extension name' unapproved-extension --help
assert_blocked 'agent task creation' agent-task create
assert_blocked 'skill installation' skill install owner/skill
assert_blocked 'skill publication' skill publish
assert_blocked 'skill update' skill update
assert_blocked 'Copilot agent' copilot
assert_blocked 'agent alias' agent
assert_blocked 'agents alias' agents
assert_blocked 'skills alias' skills

# Persistent flags cannot hide a blocked command.
assert_blocked 'root repository flag before merge' -R example/project pr merge 42
assert_blocked 'family repository flag before merge' pr --repo example/project merge 42
assert_blocked 'hostname flag before auth mutation' auth --hostname github.com setup-git
assert_backend 'root repository flag before read' 1 gh-backend -R example/project pr view 42

# A real gh shell alias runs outside Fence, which proves that the isolated
# configuration is valid. The dispatcher blocks the same alias inside Fence.
real_gh="$(command -v gh)"
alias_config_dir="${work}/gh-config"
alias_marker="${work}/shell-alias-ran"
mkdir -p "${alias_config_dir}"
# The marker variable must expand when the configured shell alias runs.
# shellcheck disable=SC2016
GH_CONFIG_DIR="${alias_config_dir}" "${real_gh}" alias set fenced-shell-alias \
	'!printf ran >"${GH_ALIAS_MARKER}"'

saved_backend="${GH_DISPATCH_GH}"
export GH_DISPATCH_GH="${real_gh}"
export GH_CONFIG_DIR="${alias_config_dir}"
export GH_ALIAS_MARKER="${alias_marker}"
export FENCE_SANDBOX=0
bash -euo pipefail "${helper}" fenced-shell-alias
if [[ ! -f ${alias_marker} ]]; then
	fail 'isolated shell alias precondition' 'the real gh alias did not run'
else
	pass 'isolated shell alias precondition'
fi

rm -f "${alias_marker}"
export FENCE_SANDBOX=1
bash -euo pipefail "${helper}" fenced-shell-alias >/dev/null 2>"${work}/stderr"
status=$?
if [[ ${status} -ne 64 || -e ${alias_marker} ]]; then
	fail 'isolated shell alias block' "expected exit 64 without the marker, got ${status}"
else
	pass 'isolated shell alias block'
fi
export GH_DISPATCH_GH="${saved_backend}"
unset GH_CONFIG_DIR GH_ALIAS_MARKER

# gh-dash inherits the dispatcher through PATH. A child gh call selects the
# fenced or unfenced backend from the same wrapper.
# The quoted text is the generated wrapper, so its variables expand at runtime.
# shellcheck disable=SC2016
printf '%s\n' \
	'#!/usr/bin/env bash' \
	'exec bash -euo pipefail "${GH_DISPATCH_HELPER}" "$@"' >"${work}/bin/gh"
chmod +x "${work}/bin/gh"
export GH_DISPATCH_HELPER="${helper}"
cat >"${work}/bin/gh-dash-stub" <<'STUB'
#!/usr/bin/env bash
exec gh pr merge 42
STUB
chmod +x "${work}/bin/gh-dash-stub"

export PATH="${work}/bin:${PATH}"
export FENCE_SANDBOX=1
: >"${GH_STUB_CALLS}"
"${work}/bin/gh-dash-stub" >/dev/null 2>"${work}/stderr"
status=$?
if [[ ${status} -ne 64 || "$(backend_call_count)" -ne 0 ]]; then
	fail 'fenced gh-dash backend selection' "expected a local block, got ${status}"
else
	pass 'fenced gh-dash backend selection'
fi

export FENCE_SANDBOX=0
: >"${GH_STUB_CALLS}"
"${work}/bin/gh-dash-stub" >/dev/null 2>"${work}/stderr"
status=$?
if [[ ${status} -ne 0 || "$(backend_call_count)" -ne 1 ]]; then
	fail 'unfenced gh-dash backend selection' "expected one gh call, got ${status}"
else
	pass 'unfenced gh-dash backend selection'
fi

printf '%d passed, %d failed\n' "${passes}" "${failures}"
if [[ ${failures} -ne 0 ]]; then
	exit 1
fi

if [[ -n ${GH_DISPATCH_PACKAGE:-} ]]; then
	for asset in \
		share/bash-completion/completions/gh.bash \
		share/fish/vendor_completions.d/gh.fish \
		share/man/man1/gh.1.gz \
		share/zsh/site-functions/_gh; do
		if [[ ! -e ${GH_DISPATCH_PACKAGE}/${asset} ]]; then
			printf 'FAIL: package asset is missing: %s\n' "${asset}" >&2
			exit 1
		fi
	done
	printf 'ok: completion and man page assets\n'
fi
