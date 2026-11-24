#!/usr/bin/env bash

# gh-security-release-tag-tests: runnable policy and execution test suite for
# gh-security-release-tag.

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
helper_script="${script_dir}/gh-security-release-tag.sh"
target="${1:-${helper_script}}"

if [[ ! -r ${target} ]]; then
	printf 'gh-security-release-tag-tests: cannot read %s\n' "${target}" >&2
	exit 1
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT

log_file="${tmpdir}/gh.log"
hab_file="${tmpdir}/haberdasher.json"
gql_file="${tmpdir}/graphql.json"
fake_gh="${tmpdir}/fake-gh"

cat >"${fake_gh}" <<EOF
#!${BASH}
EOF
cat >>"${fake_gh}" <<'EOF'
set -euo pipefail
if [[ ${1:-} == "api" && ${2:-} == "graphql" ]]; then
	printf 'api graphql\n' >>"${FAKE_GH_LOG}"
	cat "${FAKE_GH_GQL_FILE}"
	exit 0
fi
printf '%s\n' "$*" >>"${FAKE_GH_LOG}"
if [[ ${1:-} == "api" && ${2:-} == "--method" && ${3:-} == "GET" && ${4:-} == "repos/wimpysworld/Haberdasher/contents/haberdasher.yaml" ]]; then
	cat "${FAKE_GH_HAB_FILE}"
	exit 0
fi
if [[ ${1:-} == "api" && ${2:-} == "--method" && ${3:-} == "POST" ]]; then
	printf '{"ref":"refs/tags/created"}\n'
	exit 0
fi
printf 'unexpected fake-gh invocation: %s\n' "$*" >&2
exit 99
EOF
chmod +x "${fake_gh}"

fail() {
	printf 'FAIL: %s\n' "$*" >&2
	exit 1
}

write_haberdasher_yaml() {
	local yaml_content="$1"
	python3 - "${yaml_content}" "${hab_file}" <<'PY'
import base64
import json
import sys

yaml_text, out_path = sys.argv[1], sys.argv[2]
encoded = base64.b64encode(yaml_text.encode("utf-8")).decode("ascii")
wrapped = "\n".join(encoded[i : i + 60] for i in range(0, len(encoded), 60)) + "\n"
with open(out_path, "w", encoding="utf-8") as fh:
    json.dump({"encoding": "base64", "content": wrapped}, fh)
PY
}

readonly HEAD_SHA="1111111111111111111111111111111111111111"
readonly PREV_SHA="0000000000000000000000000000000000000000"
readonly OTHER_SHA="2222222222222222222222222222222222222222"
# 2026-04-01T12:00:00Z = 1775044800
# 2026-04-01T14:30:00Z = 1775053800 (9000s after merge, >= 7200s default cooldown)
# 2026-04-01T13:00:00Z = 1775048400 (3600s after merge, < 7200s default cooldown)
readonly NOW_AFTER_COOLDOWN="1775053800"
readonly NOW_BEFORE_COOLDOWN="1775048400"

write_graphql_fixture() {
	python3 - "${gql_file}" "$@" <<'PY'
import json
import sys

out_path = sys.argv[1]
overrides = json.loads(sys.argv[2]) if len(sys.argv) > 2 else {}

repo = {
    "isArchived": False,
    "defaultBranchRef": {
        "name": "main",
        "target": {
            "oid": "1111111111111111111111111111111111111111",
            "statusCheckRollup": {"state": "SUCCESS"},
            "history": {
                "nodes": [
                    {
                        "oid": "1111111111111111111111111111111111111111",
                        "messageHeadline": "fix(deps): patch CVE-2026-1234 in http client",
                        "committedDate": "2026-04-01T12:00:00Z",
                    },
                    {
                        "oid": "0000000000000000000000000000000000000000",
                        "messageHeadline": "chore: release v0.6.6",
                        "committedDate": "2026-03-15T10:00:00Z",
                    },
                ]
            },
        },
    },
    "latestRelease": {
        "tagName": "v0.6.6",
        "publishedAt": "2026-03-15T10:05:00Z",
        "isDraft": False,
        "isPrerelease": False,
        "tagCommit": {"oid": "0000000000000000000000000000000000000000"},
    },
    "ref": None,
    "openPrs": {
        "nodes": [
            {
                "number": 50,
                "title": "docs: update README examples",
                "headRefName": "docs/readme",
                "author": {"__typename": "User", "login": "contributor"},
                "labels": {"nodes": [{"name": "documentation"}]},
            }
        ]
    },
    "mergedPrs": {
        "nodes": [
            {
                "number": 49,
                "title": "Bump golang.org/x/net (CVE-2026-1234)",
                "mergedAt": "2026-04-01T12:00:00Z",
                "headRefName": "dependabot/go_modules/golang.org/x/net-0.38.0",
                "author": {"__typename": "Bot", "login": "dependabot"},
                "labels": {"nodes": [{"name": "dependencies"}, {"name": "security"}]},
            }
        ]
    },
}


def deep_merge(dst, src):
    for key, val in src.items():
        if isinstance(val, dict) and isinstance(dst.get(key), dict):
            deep_merge(dst[key], val)
        else:
            dst[key] = val


deep_merge(repo, overrides)
with open(out_path, "w", encoding="utf-8") as fh:
    json.dump({"data": {"repository": repo}}, fh)
PY
}

run_helper() {
	local out_var="$1"
	local err_var="$2"
	local rc_var="$3"
	shift 3
	local out_file="${tmpdir}/stdout"
	local err_file="${tmpdir}/stderr"
	local exit_code=0
	set +e
	FAKE_GH_LOG="${log_file}" \
		FAKE_GH_HAB_FILE="${hab_file}" \
		FAKE_GH_GQL_FILE="${gql_file}" \
		GH_SECURITY_RELEASE_TAG_GH_BIN="${fake_gh}" \
		GH_SECURITY_RELEASE_TAG_COOLDOWN_SECS="${TEST_COOLDOWN_SECS:-7200}" \
		GH_SECURITY_RELEASE_TAG_NOW_EPOCH="${TEST_NOW_EPOCH:-${NOW_AFTER_COOLDOWN}}" \
		"${BASH}" "${target}" "$@" >"${out_file}" 2>"${err_file}"
	exit_code=$?
	set -e
	printf -v "${out_var}" '%s' "$(cat "${out_file}")"
	printf -v "${err_var}" '%s' "$(cat "${err_file}")"
	printf -v "${rc_var}" '%s' "${exit_code}"
}

assert_no_post() {
	local context="$1"
	if grep -q -- '--method POST' "${log_file}"; then
		fail "${context}: unexpectedly called POST (log: $(cat "${log_file}"))"
	fi
}

stdout=""
stderr=""
rc=0

# 1. --help succeeds without calling gh.
: >"${log_file}"
run_helper stdout stderr rc --help
[[ ${rc} -eq 0 ]] || fail "--help exited ${rc}"
[[ ${stdout} == *"gh-security-release-tag [--dry-run] <owner>/<repo> <tag> <commit-sha>"* ]] || fail "--help missing usage"
[[ ! -s ${log_file} ]] || fail "--help unexpectedly invoked gh"

# 2. Bad args, flags, owner, tag, and SHA exit 64 without calling gh.
bad_cases=(
	""
	"wimpysworld/deb-get"
	"wimpysworld/deb-get v0.6.7"
	"wimpysworld/deb-get v0.6.7 ${HEAD_SHA} extra"
	"--force wimpysworld/deb-get v0.6.7 ${HEAD_SHA}"
	"--dry-run --dry-run wimpysworld/deb-get v0.6.7 ${HEAD_SHA}"
	"wimpysworld/deb-get --dry-run v0.6.7 ${HEAD_SHA}"
	"evilorg/deb-get v0.6.7 ${HEAD_SHA}"
	"wimpysworld/../deb-get v0.6.7 ${HEAD_SHA}"
	"./deb-get v0.6.7 ${HEAD_SHA}"
	"wimpysworld/deb-get 0.6.7 ${HEAD_SHA}"
	"wimpysworld/deb-get v0.6.7-rc.1 ${HEAD_SHA}"
	"wimpysworld/deb-get v0.6 ${HEAD_SHA}"
	"wimpysworld/deb-get latest ${HEAD_SHA}"
	"wimpysworld/deb-get v0.6.7 deadbeef"
	"wimpysworld/deb-get v0.6.7 AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
	"wimpysworld/deb-get v0.6.7 gggggggggggggggggggggggggggggggggggggggg"
)
for bad_case in "${bad_cases[@]}"; do
	: >"${log_file}"
	# shellcheck disable=SC2086
	run_helper stdout stderr rc ${bad_case}
	[[ ${rc} -eq 64 ]] || fail "case '${bad_case}' exited ${rc}, expected 64 (stderr: ${stderr})"
	[[ ! -s ${log_file} ]] || fail "case '${bad_case}' unexpectedly invoked gh"
done

# Bad cooldown/now env vars exit 64 without calling gh.
: >"${log_file}"
TEST_COOLDOWN_SECS="abc" run_helper stdout stderr rc wimpysworld/deb-get v0.6.7 "${HEAD_SHA}"
[[ ${rc} -eq 64 ]] || fail "invalid cooldown exited ${rc}, expected 64"
[[ ! -s ${log_file} ]] || fail "invalid cooldown unexpectedly invoked gh"

: >"${log_file}"
TEST_NOW_EPOCH="-5" run_helper stdout stderr rc wimpysworld/deb-get v0.6.7 "${HEAD_SHA}"
[[ ${rc} -eq 64 ]] || fail "invalid now_epoch exited ${rc}, expected 64"
[[ ! -s ${log_file} ]] || fail "invalid now_epoch unexpectedly invoked gh"

# Prepare default multiline block haberdasher.yaml with comments.
write_haberdasher_yaml "$(
	cat <<'YAML'
# Haberdasher source repositories
sources:
  # Core tools
  - wimpysworld/deb-get # package helper
  - "WimpysWorld/Tailor"
  - 'linuxmatters/jive-vocals'
YAML
)"
write_graphql_fixture '{}'

# 3. Non-Haberdasher repo rejected after GET without GraphQL or POST.
: >"${log_file}"
run_helper stdout stderr rc wimpysworld/unlisted-repo v0.6.7 "${HEAD_SHA}"
[[ ${rc} -eq 64 ]] || fail "non-Haberdasher repo exited ${rc}, expected 64 (stderr: ${stderr})"
grep -qx 'api --method GET repos/wimpysworld/Haberdasher/contents/haberdasher.yaml' "${log_file}" || fail "missing Haberdasher GET"
if grep -q 'api graphql' "${log_file}"; then
	fail "non-Haberdasher repo unexpectedly called GraphQL"
fi
assert_no_post "non-Haberdasher repo"

# 4. Archived repo rejected.
: >"${log_file}"
write_graphql_fixture '{"isArchived": true}'
run_helper stdout stderr rc wimpysworld/deb-get v0.6.7 "${HEAD_SHA}"
[[ ${rc} -eq 64 ]] || fail "archived repo exited ${rc}, expected 64"
assert_no_post "archived repo"

# 5. Non-HEAD SHA rejected.
: >"${log_file}"
write_graphql_fixture '{}'
run_helper stdout stderr rc wimpysworld/deb-get v0.6.7 "${OTHER_SHA}"
[[ ${rc} -eq 64 ]] || fail "non-HEAD SHA exited ${rc}, expected 64"
assert_no_post "non-HEAD SHA"

# 6. Non-SUCCESS CI rejected (PENDING and null).
: >"${log_file}"
write_graphql_fixture '{"defaultBranchRef": {"target": {"statusCheckRollup": {"state": "PENDING"}}}}'
run_helper stdout stderr rc wimpysworld/deb-get v0.6.7 "${HEAD_SHA}"
[[ ${rc} -eq 64 ]] || fail "PENDING CI exited ${rc}, expected 64"
assert_no_post "PENDING CI"

: >"${log_file}"
write_graphql_fixture '{"defaultBranchRef": {"target": {"statusCheckRollup": null}}}'
run_helper stdout stderr rc wimpysworld/deb-get v0.6.7 "${HEAD_SHA}"
[[ ${rc} -eq 64 ]] || fail "null statusCheckRollup exited ${rc}, expected 64"
assert_no_post "null statusCheckRollup"

# 7. Existing tag rejected.
: >"${log_file}"
write_graphql_fixture '{"ref": {"name": "v0.6.7"}}'
run_helper stdout stderr rc wimpysworld/deb-get v0.6.7 "${HEAD_SHA}"
[[ ${rc} -eq 64 ]] || fail "existing tag exited ${rc}, expected 64"
assert_no_post "existing tag"

# 8. Open security PR rejected (security/* branch AND Dependabot security PR).
: >"${log_file}"
write_graphql_fixture '{"openPrs": {"nodes": [{"number": 51, "title": "Fix vuln", "headRefName": "security/fix-tls", "author": {"__typename": "User", "login": "maintainer"}, "labels": {"nodes": []}}]}}'
run_helper stdout stderr rc wimpysworld/deb-get v0.6.7 "${HEAD_SHA}"
[[ ${rc} -eq 64 ]] || fail "open security/* PR exited ${rc}, expected 64"
assert_no_post "open security/* PR"

: >"${log_file}"
write_graphql_fixture '{"openPrs": {"nodes": [{"number": 52, "title": "Bump foo to address GHSA-abcd-1234", "headRefName": "dependabot/gomod/foo", "author": {"__typename": "Bot", "login": "dependabot"}, "labels": {"nodes": [{"name": "dependencies"}]}}]}}'
run_helper stdout stderr rc wimpysworld/deb-get v0.6.7 "${HEAD_SHA}"
[[ ${rc} -eq 64 ]] || fail "open Dependabot GHSA PR exited ${rc}, expected 64"
assert_no_post "open Dependabot GHSA PR"

# 9. No merged security PR after latestRelease rejected.
: >"${log_file}"
write_graphql_fixture '{"mergedPrs": {"nodes": [{"number": 48, "title": "Bump foo (CVE-2026-0001)", "mergedAt": "2026-03-10T12:00:00Z", "headRefName": "security/old-fix", "author": {"__typename": "User", "login": "maintainer"}, "labels": {"nodes": []}}]}}'
run_helper stdout stderr rc wimpysworld/deb-get v0.6.7 "${HEAD_SHA}"
[[ ${rc} -eq 64 ]] || fail "old merged security PR exited ${rc}, expected 64"
assert_no_post "old merged security PR"

# 10. Cooldown not elapsed rejected.
: >"${log_file}"
write_graphql_fixture '{}'
TEST_NOW_EPOCH="${NOW_BEFORE_COOLDOWN}" run_helper stdout stderr rc wimpysworld/deb-get v0.6.7 "${HEAD_SHA}"
[[ ${rc} -eq 64 ]] || fail "cooldown not elapsed exited ${rc}, expected 64"
assert_no_post "cooldown not elapsed"

# 11. Breaking commits rejected (!: syntax and BREAKING CHANGE).
: >"${log_file}"
write_graphql_fixture '{"defaultBranchRef": {"target": {"history": {"nodes": [{"oid": "'"${HEAD_SHA}"'", "messageHeadline": "feat(api)!: change config schema", "committedDate": "2026-04-01T12:00:00Z"}, {"oid": "'"${PREV_SHA}"'", "messageHeadline": "chore: release v0.6.6", "committedDate": "2026-03-15T10:00:00Z"}]}}}}'
run_helper stdout stderr rc wimpysworld/deb-get v0.7.0 "${HEAD_SHA}"
[[ ${rc} -eq 64 ]] || fail "breaking !: commit exited ${rc}, expected 64"
assert_no_post "breaking !: commit"

: >"${log_file}"
write_graphql_fixture '{"defaultBranchRef": {"target": {"history": {"nodes": [{"oid": "'"${HEAD_SHA}"'", "messageHeadline": "fix: drop legacy flag (BREAKING CHANGE)", "committedDate": "2026-04-01T12:00:00Z"}, {"oid": "'"${PREV_SHA}"'", "messageHeadline": "chore: release v0.6.6", "committedDate": "2026-03-15T10:00:00Z"}]}}}}'
run_helper stdout stderr rc wimpysworld/deb-get v0.6.7 "${HEAD_SHA}"
[[ ${rc} -eq 64 ]] || fail "BREAKING CHANGE commit exited ${rc}, expected 64"
assert_no_post "BREAKING CHANGE commit"

# 12. feat: commit rejects patch tag v0.6.7 and accepts minor tag v0.7.0.
write_graphql_fixture '{"defaultBranchRef": {"target": {"history": {"nodes": [{"oid": "'"${HEAD_SHA}"'", "messageHeadline": "fix(deps): patch CVE-2026-1234", "committedDate": "2026-04-01T12:00:00Z"}, {"oid": "'"${OTHER_SHA}"'", "messageHeadline": "feat(cli): add json output flag", "committedDate": "2026-03-25T12:00:00Z"}, {"oid": "'"${PREV_SHA}"'", "messageHeadline": "chore: release v0.6.6", "committedDate": "2026-03-15T10:00:00Z"}]}}}}'

: >"${log_file}"
run_helper stdout stderr rc wimpysworld/deb-get v0.6.7 "${HEAD_SHA}"
[[ ${rc} -eq 64 ]] || fail "feat: commit with patch tag exited ${rc}, expected 64"
assert_no_post "feat: commit with patch tag"

: >"${log_file}"
run_helper stdout stderr rc --dry-run wimpysworld/deb-get v0.7.0 "${HEAD_SHA}"
[[ ${rc} -eq 0 ]] || fail "feat: commit with minor tag exited ${rc} (stderr: ${stderr})"
[[ ${stdout} == "gh-security-release-tag: dry-run passed for wimpysworld/deb-get v0.7.0 (${HEAD_SHA})" ]] || fail "unexpected minor dry-run stdout: ${stdout}"
assert_no_post "feat: commit dry-run"

# 13. Patch-only commits reject minor tag v0.7.0, accept v0.6.7 on dry-run and real run.
write_graphql_fixture '{}'

: >"${log_file}"
run_helper stdout stderr rc wimpysworld/deb-get v0.7.0 "${HEAD_SHA}"
[[ ${rc} -eq 64 ]] || fail "patch-only commits with minor tag exited ${rc}, expected 64"
assert_no_post "patch-only commits with minor tag"

# Inline YAML sources form + case-insensitive match + --dry-run makes no POST.
write_haberdasher_yaml 'sources: [WimpysWorld/Deb-Get, linuxmatters/jive-vocals] # inline sources'
: >"${log_file}"
run_helper stdout stderr rc --dry-run wimpysworld/deb-get v0.6.7 "${HEAD_SHA}"
[[ ${rc} -eq 0 ]] || fail "dry-run patch tag exited ${rc} (stderr: ${stderr})"
[[ ${stdout} == "gh-security-release-tag: dry-run passed for wimpysworld/deb-get v0.6.7 (${HEAD_SHA})" ]] || fail "unexpected dry-run stdout: ${stdout}"
assert_no_post "patch dry-run"

# 14. publishedAt fallback when latestRelease.tagCommit.oid is not in history.
write_graphql_fixture '{"latestRelease": {"tagCommit": {"oid": "9999999999999999999999999999999999999999"}}}'
: >"${log_file}"
run_helper stdout stderr rc --dry-run wimpysworld/deb-get v0.6.7 "${HEAD_SHA}"
[[ ${rc} -eq 0 ]] || fail "publishedAt fallback exited ${rc} (stderr: ${stderr})"
assert_no_post "publishedAt fallback dry-run"

# 15. latestRelease pointing to HEAD_SHA is rejected.
write_graphql_fixture '{"latestRelease": {"tagCommit": {"oid": "'"${HEAD_SHA}"'"}}}'
: >"${log_file}"
run_helper stdout stderr rc wimpysworld/deb-get v0.6.7 "${HEAD_SHA}"
[[ ${rc} -eq 64 ]] || fail "latestRelease already at HEAD exited ${rc}, expected 64"
assert_no_post "latestRelease already at HEAD"

# 16. Real run sends exactly one POST to repos/<owner>/<repo>/git/refs with ref and sha.
write_graphql_fixture '{}'
: >"${log_file}"
run_helper stdout stderr rc wimpysworld/deb-get v0.6.7 "${HEAD_SHA}"
[[ ${rc} -eq 0 ]] || fail "real run exited ${rc} (stderr: ${stderr})"
[[ ${stdout} == "gh-security-release-tag: created tag v0.6.7 in wimpysworld/deb-get at ${HEAD_SHA}." ]] || fail "unexpected real run stdout: ${stdout}"
grep -qx 'api --method GET repos/wimpysworld/Haberdasher/contents/haberdasher.yaml' "${log_file}" || fail "missing Haberdasher GET in real run"
grep -qx 'api graphql' "${log_file}" || fail "missing GraphQL call in real run"
post_count="$(grep -c -- '--method POST' "${log_file}")"
[[ ${post_count} -eq 1 ]] || fail "expected exactly 1 POST call, got ${post_count}"
grep -qx "api --method POST repos/wimpysworld/deb-get/git/refs -f ref=refs/tags/v0.6.7 -f sha=${HEAD_SHA}" "${log_file}" || fail "unexpected POST call: $(cat "${log_file}")"

printf 'gh-security-release-tag-tests: all checks passed.\n'
