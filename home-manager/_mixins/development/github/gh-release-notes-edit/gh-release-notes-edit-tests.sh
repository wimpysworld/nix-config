#!/usr/bin/env bash

# gh-release-notes-edit-tests: runnable policy and execution test suite for
# gh-release-notes-edit.

set -uo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
target_bin="${1:-}"
helper_script="${2:-${script_dir}/gh-release-notes-edit.sh}"

if [[ ! -r ${helper_script} ]]; then
	printf 'gh-release-notes-edit-tests: cannot read %s\n' "${helper_script}" >&2
	exit 1
fi

work="$(mktemp -d)"
trap 'chmod u+r "${work}/unreadable.md" 2>/dev/null || true; rm -rf "${work}"' EXIT

stub_dir="${work}/bin"
state_dir="${work}/state"
mkdir -p "${stub_dir}" "${state_dir}"

cat >"${stub_dir}/gh" <<EOF
#!${BASH}
EOF
cat >>"${stub_dir}/gh" <<'STUB'
set -uo pipefail

call_num=$(($(wc -l <"${GH_STUB_STATE}/calls") + 1))
printf '%s\n' "$*" >>"${GH_STUB_STATE}/calls"
: >"${GH_STUB_STATE}/argv-${call_num}"
for arg in "$@"; do
	printf '%s\n' "${arg}" >>"${GH_STUB_STATE}/argv-${call_num}"
done

if [[ $# -eq 6 && $1 == "api" && $2 == "--hostname" && $3 == "github.com" && $4 == "--method" && $5 == "GET" && $6 == repos/*/*/releases/tags/* ]]; then
	if [[ -r "${GH_STUB_STATE}/tag-stderr" ]]; then
		cat "${GH_STUB_STATE}/tag-stderr" >&2
	fi
	if [[ -r "${GH_STUB_STATE}/tag-stdout" ]]; then
		cat "${GH_STUB_STATE}/tag-stdout"
	elif [[ ! -r "${GH_STUB_STATE}/tag-exit" ]]; then
		printf '{"id":12345,"tag_name":"v1.2.3","html_url":"https://github.com/wimpysworld/nix-config/releases/tag/v1.2.3"}\n'
	fi
	if [[ -r "${GH_STUB_STATE}/tag-exit" ]]; then
		exit "$(cat "${GH_STUB_STATE}/tag-exit")"
	fi
	exit 0
fi

if [[ $# -eq 7 && $1 == "api" && $2 == "--hostname" && $3 == "github.com" && $4 == "--method" && $5 == "GET" && $6 == "--paginate" && $7 == repos/*/*/releases\?per_page=100 ]]; then
	if [[ -r "${GH_STUB_STATE}/list-stderr" ]]; then
		cat "${GH_STUB_STATE}/list-stderr" >&2
	fi
	if [[ -r "${GH_STUB_STATE}/list-stdout" ]]; then
		cat "${GH_STUB_STATE}/list-stdout"
	elif [[ ! -r "${GH_STUB_STATE}/list-exit" ]]; then
		printf '[]\n'
	fi
	if [[ -r "${GH_STUB_STATE}/list-exit" ]]; then
		exit "$(cat "${GH_STUB_STATE}/list-exit")"
	fi
	exit 0
fi

if [[ $# -eq 8 && $1 == "api" && $2 == "--hostname" && $3 == "github.com" && $4 == "--method" && $5 == "PATCH" && $6 == repos/*/*/releases/* && $7 == "--input" && $8 == "-" ]]; then
	cat >"${GH_STUB_STATE}/stdin-${call_num}"
	if [[ -r "${GH_STUB_STATE}/patch-stderr" ]]; then
		cat "${GH_STUB_STATE}/patch-stderr" >&2
	fi
	if [[ -r "${GH_STUB_STATE}/patch-stdout" ]]; then
		cat "${GH_STUB_STATE}/patch-stdout"
	else
		printf '{"id":12345,"html_url":"https://github.com/wimpysworld/nix-config/releases/tag/v1.2.3"}\n'
	fi
	if [[ -r "${GH_STUB_STATE}/patch-exit" ]]; then
		exit "$(cat "${GH_STUB_STATE}/patch-exit")"
	fi
	exit 0
fi

printf 'unexpected gh stub invocation: %s\n' "$*" >&2
exit 99
STUB
chmod +x "${stub_dir}/gh"

export PATH="${stub_dir}:${PATH}"
export GH_RELEASE_NOTES_EDIT_GH_BIN="${stub_dir}/gh"
export GH_STUB_STATE="${state_dir}"

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
	rm -f "${state_dir}"/*
	: >"${state_dir}/calls"
}

run_helper() {
	stdout="$(bash -euo pipefail "${helper_script}" "$@" 2>"${work}/stderr")"
	status=$?
	stderr="$(cat "${work}/stderr")"
}

call_count() {
	wc -l <"${state_dir}/calls" | tr -d ' '
}

assert_policy_rejected() {
	local label="$1"
	shift
	reset_stub
	run_helper "$@"
	local line_count
	line_count="$(wc -l <"${work}/stderr" | tr -d ' ')"
	if [[ ${status} -ne 64 ]]; then
		fail "${label}" "expected exit 64, got ${status} (stderr: ${stderr})"
	elif [[ ${line_count} -ne 1 ]]; then
		fail "${label}" "expected single-line stderr, got ${line_count} lines: ${stderr}"
	elif [[ $(call_count) -ne 0 ]]; then
		fail "${label}" "gh was called $(call_count) time(s) on a policy rejection"
	else
		pass "${label}"
	fi
}

notes_file="${work}/notes.md"
# shellcheck disable=SC2016
printf '## Highlights\n\n- Added `gh-release-notes-edit` for "quoted" café notes.\n- 第二行\n' >"${notes_file}"
empty_file="${work}/empty.md"
: >"${empty_file}"
whitespace_file="${work}/whitespace.md"
printf ' \t\n  \r\n' >"${whitespace_file}"
invalid_utf8_file="${work}/invalid-utf8.md"
printf '\377\376' >"${invalid_utf8_file}"
dir_path="${work}/notes-dir"
mkdir -p "${dir_path}"
unreadable_file="${work}/unreadable.md"
printf 'secret\n' >"${unreadable_file}"
chmod 000 "${unreadable_file}"

# 1. --help and -h
reset_stub
run_helper --help
if [[ ${status} -eq 0 && ${stdout} == *"USAGE"* && $(call_count) -eq 0 ]]; then
	pass "--help exits 0 and prints usage without calling gh"
else
	fail "--help exits 0 and prints usage" "status=${status} calls=$(call_count)"
fi

reset_stub
run_helper -h
if [[ ${status} -eq 0 && ${stdout} == *"USAGE"* && $(call_count) -eq 0 ]]; then
	pass "-h exits 0 and prints usage without calling gh"
else
	fail "-h exits 0 and prints usage" "status=${status} calls=$(call_count)"
fi

assert_policy_rejected "--help with extra arguments" --help wimpysworld/nix-config v1.2.3 --notes-file "${notes_file}"

# 2. Bad flags and argument counts
assert_policy_rejected "no arguments"
assert_policy_rejected "too few arguments" wimpysworld/nix-config v1.2.3 --notes-file
assert_policy_rejected "extra positional argument" wimpysworld/nix-config v1.2.3 --notes-file "${notes_file}" extra
assert_policy_rejected "glued --notes-file=PATH (3 args)" wimpysworld/nix-config v1.2.3 "--notes-file=${notes_file}"
assert_policy_rejected "glued --notes-file=PATH (4 args)" wimpysworld/nix-config v1.2.3 "--notes-file=${notes_file}" extra
assert_policy_rejected "method flag -X" -X PATCH --notes-file "${notes_file}"
assert_policy_rejected "extra -X flag" wimpysworld/nix-config v1.2.3 --notes-file "${notes_file}" -X DELETE
assert_policy_rejected "field flag -f" wimpysworld/nix-config v1.2.3 -f body=hi
assert_policy_rejected "raw field flag -F" wimpysworld/nix-config v1.2.3 -F "body=@${notes_file}"
assert_policy_rejected "--input flag" wimpysworld/nix-config v1.2.3 --input "${notes_file}"
assert_policy_rejected "reordered --notes-file" --notes-file "${notes_file}" wimpysworld/nix-config v1.2.3
assert_policy_rejected "stdin dash as --notes-file" wimpysworld/nix-config v1.2.3 --notes-file -

# 3. Invalid <owner/repo>
assert_policy_rejected "missing slash in owner/repo" nix-config v1.2.3 --notes-file "${notes_file}"
assert_policy_rejected "extra slash in owner/repo" wimpysworld/nix-config/extra v1.2.3 --notes-file "${notes_file}"
assert_policy_rejected "URL in owner/repo" https://github.com/wimpysworld/nix-config v1.2.3 --notes-file "${notes_file}"
assert_policy_rejected "dot owner" ./nix-config v1.2.3 --notes-file "${notes_file}"
assert_policy_rejected "dot-dot owner" ../nix-config v1.2.3 --notes-file "${notes_file}"
assert_policy_rejected "dot repo" wimpysworld/. v1.2.3 --notes-file "${notes_file}"
assert_policy_rejected "dot-dot repo" wimpysworld/.. v1.2.3 --notes-file "${notes_file}"
assert_policy_rejected "encoded owner/repo" "wimpysworld/nix%2Fconfig" v1.2.3 --notes-file "${notes_file}"
assert_policy_rejected "space in owner/repo" "wimpysworld/nix config" v1.2.3 --notes-file "${notes_file}"

# 4. Invalid <tag>
assert_policy_rejected "empty tag" wimpysworld/nix-config "" --notes-file "${notes_file}"
assert_policy_rejected "flag-like tag" wimpysworld/nix-config -X --notes-file "${notes_file}"
assert_policy_rejected "whitespace in tag" wimpysworld/nix-config "v1.2.3 beta" --notes-file "${notes_file}"
assert_policy_rejected "newline in tag" wimpysworld/nix-config $'v1.2.3\n' --notes-file "${notes_file}"
assert_policy_rejected "control char in tag" wimpysworld/nix-config $'v1.2.3\x1b' --notes-file "${notes_file}"
assert_policy_rejected "dot tag" wimpysworld/nix-config . --notes-file "${notes_file}"
assert_policy_rejected "dot-dot tag" wimpysworld/nix-config .. --notes-file "${notes_file}"
assert_policy_rejected "leading dot-dot segment in tag" wimpysworld/nix-config ../v1.2.3 --notes-file "${notes_file}"
assert_policy_rejected "middle dot-dot segment in tag" wimpysworld/nix-config pkg/../v1.2.3 --notes-file "${notes_file}"
assert_policy_rejected "trailing dot-dot segment in tag" wimpysworld/nix-config pkg/.. --notes-file "${notes_file}"

# 5. Invalid notes file
assert_policy_rejected "missing notes file" wimpysworld/nix-config v1.2.3 --notes-file "${work}/missing.md"
assert_policy_rejected "directory notes file" wimpysworld/nix-config v1.2.3 --notes-file "${dir_path}"
assert_policy_rejected "empty notes file" wimpysworld/nix-config v1.2.3 --notes-file "${empty_file}"
assert_policy_rejected "whitespace-only notes file" wimpysworld/nix-config v1.2.3 --notes-file "${whitespace_file}"
assert_policy_rejected "invalid UTF-8 notes file" wimpysworld/nix-config v1.2.3 --notes-file "${invalid_utf8_file}"
if [[ ${EUID} -ne 0 ]]; then
	assert_policy_rejected "unreadable notes file" wimpysworld/nix-config v1.2.3 --notes-file "${unreadable_file}"
fi
chmod u+r "${unreadable_file}"

# 6. Valid published release update
reset_stub
run_helper wimpysworld/nix-config v1.2.3 --notes-file "${notes_file}"
if [[ ${status} -ne 0 ]]; then
	fail "published release update succeeds" "status=${status} stderr=${stderr}"
elif [[ $(call_count) -ne 2 ]]; then
	fail "published release update call count" "expected 2, got $(call_count)"
elif [[ $(sed -n '1p' "${state_dir}/calls") != "api --hostname github.com --method GET repos/wimpysworld/nix-config/releases/tags/v1.2.3" ]]; then
	fail "published release GET endpoint" "got: $(sed -n '1p' "${state_dir}/calls")"
elif [[ $(sed -n '2p' "${state_dir}/calls") != "api --hostname github.com --method PATCH repos/wimpysworld/nix-config/releases/12345 --input -" ]]; then
	fail "published release PATCH endpoint" "got: $(sed -n '2p' "${state_dir}/calls")"
elif [[ ${stdout} != "https://github.com/wimpysworld/nix-config/releases/tag/v1.2.3" ]]; then
	fail "published release stdout html_url" "got: ${stdout}"
else
	payload="${state_dir}/stdin-2"
	if [[ $(jq -c 'keys' <"${payload}") != '["body"]' ]]; then
		fail "PATCH payload contains only body key" "keys: $(jq -c 'keys' <"${payload}")"
	else
		jq -j '.body' <"${payload}" >"${work}/roundtrip.md"
		if cmp -s "${notes_file}" "${work}/roundtrip.md"; then
			pass "published release update sends only body and prints html_url"
		else
			fail "published release update body round-trip" "decoded body differs"
		fi
	fi
fi

# 7. Tag URI encoding (slash and plus)
reset_stub
printf '{"id":54321,"tag_name":"pkg/v1.2.3+1","html_url":"https://github.com/wimpysworld/nix-config/releases/tag/pkg%%2Fv1.2.3%%2B1"}\n' >"${state_dir}/tag-stdout"
printf '{"id":54321,"html_url":"https://github.com/wimpysworld/nix-config/releases/tag/pkg%%2Fv1.2.3%%2B1"}\n' >"${state_dir}/patch-stdout"
run_helper wimpysworld/nix-config "pkg/v1.2.3+1" --notes-file "${notes_file}"
if [[ ${status} -eq 0 && $(sed -n '1p' "${state_dir}/calls") == "api --hostname github.com --method GET repos/wimpysworld/nix-config/releases/tags/pkg%2Fv1.2.3%2B1" && $(sed -n '2p' "${state_dir}/calls") == "api --hostname github.com --method PATCH repos/wimpysworld/nix-config/releases/54321 --input -" ]]; then
	pass "URI-encodes special characters in tag for GET lookup"
else
	fail "URI-encodes special characters in tag" "status=${status} calls=$(cat "${state_dir}/calls") stderr=${stderr}"
fi

# 8. Draft release fallback (404 on /tags/, paginated match on /releases)
reset_stub
printf '1\n' >"${state_dir}/tag-exit"
printf 'gh: Not Found (HTTP 404)\n' >"${state_dir}/tag-stderr"
printf '{"message":"Not Found","status":"404"}\n' >"${state_dir}/tag-stdout"
cat >"${state_dir}/list-stdout" <<'JSON'
[{"id":100,"tag_name":"v1.0.0","draft":false}]
[{"id":200,"tag_name":"v2.0.0","draft":true,"html_url":"https://github.com/wimpysworld/nix-config/releases/tag/untagged-abc"}]
JSON
printf '{"id":200,"html_url":"https://github.com/wimpysworld/nix-config/releases/tag/untagged-abc"}\n' >"${state_dir}/patch-stdout"

run_helper wimpysworld/nix-config v2.0.0 --notes-file "${notes_file}"
if [[ ${status} -ne 0 ]]; then
	fail "draft release fallback succeeds" "status=${status} stderr=${stderr}"
elif [[ $(call_count) -ne 3 ]]; then
	fail "draft release fallback call count" "expected 3, got $(call_count)"
elif [[ $(sed -n '2p' "${state_dir}/calls") != "api --hostname github.com --method GET --paginate repos/wimpysworld/nix-config/releases?per_page=100" ]]; then
	fail "draft release fallback list call" "got: $(sed -n '2p' "${state_dir}/calls")"
elif [[ $(sed -n '3p' "${state_dir}/calls") != "api --hostname github.com --method PATCH repos/wimpysworld/nix-config/releases/200 --input -" ]]; then
	fail "draft release fallback PATCH call" "got: $(sed -n '3p' "${state_dir}/calls")"
elif [[ $(jq -c 'keys' <"${state_dir}/stdin-3") != '["body"]' ]]; then
	fail "draft release fallback PATCH payload keys" "got: $(jq -c 'keys' <"${state_dir}/stdin-3")"
elif [[ ${stdout} != "https://github.com/wimpysworld/nix-config/releases/tag/untagged-abc" ]]; then
	fail "draft release fallback stdout html_url" "got: ${stdout}"
else
	pass "draft release fallback resolves paginated draft and patches only body"
fi

# 9. Ambiguous multiple drafts rejection
reset_stub
printf '1\n' >"${state_dir}/tag-exit"
printf 'gh: Not Found (HTTP 404)\n' >"${state_dir}/tag-stderr"
cat >"${state_dir}/list-stdout" <<'JSON'
[{"id":201,"tag_name":"v2.0.0","draft":true},{"id":202,"tag_name":"v2.0.0","draft":true}]
JSON

run_helper wimpysworld/nix-config v2.0.0 --notes-file "${notes_file}"
if [[ ${status} -ne 0 && $(call_count) -eq 2 && ${stderr} == *"ambiguous"* ]]; then
	pass "rejects multiple drafts sharing the same tag without sending PATCH"
else
	fail "rejects multiple drafts sharing the same tag" "status=${status} calls=$(call_count) stderr=${stderr}"
fi

# 10. Missing release 404 failure
reset_stub
printf '1\n' >"${state_dir}/tag-exit"
printf 'gh: Not Found (HTTP 404)\n' >"${state_dir}/tag-stderr"
printf '[{"id":100,"tag_name":"v1.0.0","draft":false}]\n' >"${state_dir}/list-stdout"

run_helper wimpysworld/nix-config v9.9.9 --notes-file "${notes_file}"
if [[ ${status} -ne 0 && $(call_count) -eq 2 && ${stderr} == *"no release found"* ]]; then
	pass "fails clearly when release does not exist without sending PATCH"
else
	fail "fails clearly when release does not exist" "status=${status} calls=$(call_count) stderr=${stderr}"
fi

# 11. Non-404 GET failure stops without fallback
reset_stub
printf '22\n' >"${state_dir}/tag-exit"
printf 'gh: Internal Server Error (HTTP 500)\n' >"${state_dir}/tag-stderr"

run_helper wimpysworld/nix-config v1.2.3 --notes-file "${notes_file}"
if [[ ${status} -eq 22 && $(call_count) -eq 1 ]]; then
	pass "propagates non-404 GET failure without fallback or PATCH"
else
	fail "propagates non-404 GET failure" "status=${status} calls=$(call_count) stderr=${stderr}"
fi

# 12. Invalid non-numeric release id is rejected
reset_stub
printf '{"id":"not-a-number","tag_name":"v1.2.3"}\n' >"${state_dir}/tag-stdout"

run_helper wimpysworld/nix-config v1.2.3 --notes-file "${notes_file}"
if [[ ${status} -ne 0 && $(call_count) -eq 1 && ${stderr} == *"invalid release id"* ]]; then
	pass "rejects non-numeric release id without sending PATCH"
else
	fail "rejects non-numeric release id" "status=${status} calls=$(call_count) stderr=${stderr}"
fi

# 13. Packaged binary checks
if [[ -n ${target_bin} ]]; then
	reset_stub
	target_help="$("${target_bin}" --help 2>"${work}/target-stderr")"
	target_help_status=$?
	if [[ ${target_help_status} -eq 0 && ${target_help} == *"USAGE"* ]]; then
		pass "packaged binary --help exits 0"
	else
		fail "packaged binary --help exits 0" "status=${target_help_status}"
	fi

	reset_stub
	"${target_bin}" wimpysworld/nix-config v1.2.3 -X PATCH >"${work}/target-stdout" 2>"${work}/target-stderr"
	target_bad_status=$?
	if [[ ${target_bad_status} -eq 64 && $(call_count) -eq 0 ]]; then
		pass "packaged binary rejects bad flags with exit 64"
	else
		fail "packaged binary rejects bad flags with exit 64" "status=${target_bad_status} calls=$(call_count)"
	fi

	reset_stub
	GH_TOKEN="" GH_RELEASE_NOTES_EDIT_GH_BIN="${stub_dir}/gh" "${target_bin}" \
		wimpysworld/nix-config v1.2.3 --notes-file "${notes_file}" \
		>"${work}/target-stdout" 2>"${work}/target-stderr"
	target_override_status=$?
	if [[ ${target_override_status} -ne 0 && $(call_count) -eq 0 ]]; then
		pass "packaged binary ignores caller GH_RELEASE_NOTES_EDIT_GH_BIN override"
	else
		fail "packaged binary ignores caller GH_RELEASE_NOTES_EDIT_GH_BIN override" "status=${target_override_status} calls=$(call_count)"
	fi
fi

if [[ ${failures} -gt 0 ]]; then
	printf 'FAIL: %s passed, %s failed\n' "${passes}" "${failures}" >&2
	exit 1
fi
printf 'PASS: %s passed, 0 failed\n' "${passes}"
