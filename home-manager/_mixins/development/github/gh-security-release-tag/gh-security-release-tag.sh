#!/usr/bin/env bash

# gh-security-release-tag: Fence-friendly helper for creating one verified
# semver release tag on a Haberdasher-published repository after a security
# pull request has merged and its cooldown has elapsed.

set -euo pipefail

readonly EX_POLICY=64

die() {
	printf 'gh-security-release-tag: %s\n' "$*" >&2
	exit "${EX_POLICY}"
}

usage() {
	cat <<'EOF'
gh-security-release-tag: create one verified security release tag via git/refs.

USAGE
    gh-security-release-tag [--dry-run] <owner>/<repo> <tag> <commit-sha>
    gh-security-release-tag --help

EXAMPLES
    gh-security-release-tag --dry-run wimpysworld/deb-get v0.6.7 0123456789abcdef0123456789abcdef01234567
    gh-security-release-tag wimpysworld/deb-get v0.6.7 0123456789abcdef0123456789abcdef01234567

ENVIRONMENT
    GH_SECURITY_RELEASE_TAG_COOLDOWN_SECS
        Minimum seconds since the most recent merged security PR (default: 7200).
    GH_SECURITY_RELEASE_TAG_NOW_EPOCH
        Optional UTC epoch seconds override for deterministic cooldown checks.

POLICY
    - Optional leading --dry-run only; any other flag is rejected with exit 64.
    - <owner>/<repo> must match ^[A-Za-z0-9][A-Za-z0-9._-]*/[A-Za-z0-9][A-Za-z0-9._-]*$
      with no dot segments, and <owner> must be one of:
      wimpysworld, linuxmatters, quickemu-project, noughtylinux, oval-tutu, flexiondotorg.
    - <tag> must match strict stable semver ^v[0-9]+\.[0-9]+\.[0-9]+$.
    - <commit-sha> must match ^[0-9a-f]{40}$.
    - Before creating any tag, gh-security-release-tag verifies live via GitHub:
        1. <owner>/<repo> appears in wimpysworld/Haberdasher haberdasher.yaml sources.
        2. The repository is not archived.
        3. defaultBranchRef.target.oid equals <commit-sha> with statusCheckRollup.state == SUCCESS.
        4. refs/tags/<tag> does not already exist.
        5. latestRelease is a stable non-draft, non-prerelease semver release at a different commit.
        6. Zero open security PRs exist.
        7. At least one security PR merged after latestRelease.publishedAt and cooldown elapsed.
        8. Commits since latestRelease contain no breaking changes, and <tag> matches the exact
           expected minor (if any feat: commit) or patch bump.
    - On success without --dry-run, gh-security-release-tag calls:
        POST repos/<owner>/<repo>/git/refs -f ref=refs/tags/<tag> -f sha=<commit-sha>
EOF
}

if [[ $# -eq 1 && ($1 == "--help" || $1 == "-h") ]]; then
	usage
	exit 0
fi

dry_run=false
if [[ $# -ge 1 && $1 == "--dry-run" ]]; then
	dry_run=true
	shift
fi

if [[ $# -ne 3 ]]; then
	die "expected usage: gh-security-release-tag [--dry-run] <owner>/<repo> <tag> <commit-sha> (try: gh-security-release-tag --help)"
fi

repo="$1"
tag="$2"
commit_sha="$3"

if [[ ${repo} == -* ]]; then
	die "flag-like argument '${repo}' is not permitted in <owner>/<repo> position"
fi
if [[ ${tag} == -* ]]; then
	die "flag-like argument '${tag}' is not permitted in <tag> position"
fi
if [[ ${commit_sha} == -* ]]; then
	die "flag-like argument '${commit_sha}' is not permitted in <commit-sha> position"
fi

readonly REPO_PATTERN='^[A-Za-z0-9][A-Za-z0-9._-]*/[A-Za-z0-9][A-Za-z0-9._-]*$'
if [[ ! ${repo} =~ ${REPO_PATTERN} ]]; then
	die "repository '${repo}' must match <owner>/<repo>"
fi

owner="${repo%%/*}"
name="${repo#*/}"
if [[ ${owner} == "." || ${owner} == ".." || ${name} == "." || ${name} == ".." ]]; then
	die "repository '${repo}' must not contain dot segments"
fi

owner_lower="${owner,,}"
case "${owner_lower}" in
	wimpysworld | linuxmatters | quickemu-project | noughtylinux | oval-tutu | flexiondotorg) ;;
	*)
		die "owner '${owner}' is outside the allowed repository owners"
		;;
esac

readonly TAG_PATTERN='^v[0-9]+\.[0-9]+\.[0-9]+$'
if [[ ! ${tag} =~ ${TAG_PATTERN} ]]; then
	die "tag '${tag}' must match strict stable semver ^v[0-9]+\.[0-9]+\.[0-9]+$"
fi

readonly SHA_PATTERN='^[0-9a-f]{40}$'
if [[ ! ${commit_sha} =~ ${SHA_PATTERN} ]]; then
	die "commit-sha '${commit_sha}' must match ^[0-9a-f]{40}$"
fi

cooldown_secs="${GH_SECURITY_RELEASE_TAG_COOLDOWN_SECS:-7200}"
readonly UINT_PATTERN='^[0-9]+$'
if [[ ! ${cooldown_secs} =~ ${UINT_PATTERN} ]]; then
	die "GH_SECURITY_RELEASE_TAG_COOLDOWN_SECS '${cooldown_secs}' must be a non-negative integer"
fi

now_epoch="${GH_SECURITY_RELEASE_TAG_NOW_EPOCH:-}"
if [[ -n ${now_epoch} && ! ${now_epoch} =~ ${UINT_PATTERN} ]]; then
	die "GH_SECURITY_RELEASE_TAG_NOW_EPOCH '${now_epoch}' must be a non-negative integer"
fi

: "${GH_SECURITY_RELEASE_TAG_GH_BIN:=gh}"
readonly GH_SECURITY_RELEASE_TAG_GH_BIN
export GH_PROMPT_DISABLED=true
export GH_TELEMETRY=false

set +e
python3 - "${GH_SECURITY_RELEASE_TAG_GH_BIN}" "${repo}" "${owner}" "${name}" "${tag}" "${commit_sha}" "${cooldown_secs}" "${now_epoch}" <<'PY'
import base64
from datetime import datetime
import json
import re
import subprocess
import sys
import time

EX_POLICY = 64

GRAPHQL_QUERY = """
query($owner: String!, $name: String!, $tagRef: String!) {
  repository(owner: $owner, name: $name) {
    isArchived
    defaultBranchRef {
      name
      target {
        ... on Commit {
          oid
          statusCheckRollup {
            state
          }
          history(first: 50) {
            nodes {
              oid
              messageHeadline
              committedDate
            }
          }
        }
      }
    }
    latestRelease {
      tagName
      publishedAt
      isDraft
      isPrerelease
      tagCommit {
        oid
      }
    }
    ref(qualifiedName: $tagRef) {
      name
    }
    openPrs: pullRequests(states: OPEN, first: 50) {
      nodes {
        number
        title
        headRefName
        author {
          __typename
          login
        }
        labels(first: 10) {
          nodes {
            name
          }
        }
      }
    }
    mergedPrs: pullRequests(states: MERGED, first: 30, orderBy: { field: UPDATED_AT, direction: DESC }) {
      nodes {
        number
        title
        mergedAt
        headRefName
        author {
          __typename
          login
        }
        labels(first: 10) {
          nodes {
            name
          }
        }
      }
    }
  }
}
"""

SEMVER_RE = re.compile(r"^v([0-9]+)\.([0-9]+)\.([0-9]+)$")
BREAKING_PREFIX_RE = re.compile(r"^[a-z]+(\([^)]+\))?!:", re.IGNORECASE)
BREAKING_CHANGE_RE = re.compile(r"breaking change", re.IGNORECASE)
FEAT_PREFIX_RE = re.compile(r"^feat(\([^)]+\))?:", re.IGNORECASE)
SECURITY_TITLE_RE = re.compile(r"(?:security|cve-|ghsa-)", re.IGNORECASE)


def fail(message: str, code: int = EX_POLICY) -> None:
    sys.stderr.write(f"gh-security-release-tag: {message}\n")
    sys.exit(code)


def run_gh_json(gh_bin: str, args: list[str], description: str) -> dict:
    proc = subprocess.run(
        [gh_bin, *args],
        stdin=subprocess.DEVNULL,
        capture_output=True,
        text=True,
    )
    if proc.returncode != 0:
        detail = proc.stderr.strip()
        if detail:
            sys.stderr.write(f"{detail}\n")
        fail(f"gh exited {proc.returncode} while {description}.", code=proc.returncode)
    try:
        parsed = json.loads(proc.stdout)
    except json.JSONDecodeError as exc:
        fail(f"invalid JSON while {description}: {exc}")
    if not isinstance(parsed, dict):
        fail(f"response was not a JSON object while {description}")
    return parsed


def strip_yaml_comment(line: str) -> str:
    in_single = False
    in_double = False
    escaped = False
    for idx, ch in enumerate(line):
        if in_double:
            if escaped:
                escaped = False
            elif ch == "\\":
                escaped = True
            elif ch == '"':
                in_double = False
        elif in_single:
            if ch == "'":
                in_single = False
        else:
            if ch == '"':
                in_double = True
            elif ch == "'":
                in_single = True
            elif ch == "#" and (idx == 0 or line[idx - 1].isspace()):
                return line[:idx]
    return line


def unquote_yaml_scalar(value: str) -> str:
    text = value.strip()
    if len(text) >= 2 and text[0] == text[-1] and text[0] in ("'", '"'):
        return text[1:-1].strip()
    return text


def parse_haberdasher_sources(yaml_text: str) -> set[str]:
    lines = yaml_text.splitlines()
    sources: list[str] = []
    idx = 0
    while idx < len(lines):
        cleaned = strip_yaml_comment(lines[idx])
        match = re.match(r"^(\s*)sources\s*:(.*)$", cleaned)
        if not match:
            idx += 1
            continue
        key_indent = len(match.group(1))
        rest = match.group(2).strip()
        if rest.startswith("["):
            buf = rest
            while "]" not in buf and idx + 1 < len(lines):
                idx += 1
                buf += " " + strip_yaml_comment(lines[idx]).strip()
            if "]" not in buf:
                fail("malformed inline sources list in haberdasher.yaml")
            inner = buf[1 : buf.index("]")]
            for item in inner.split(","):
                scalar = unquote_yaml_scalar(item)
                if scalar:
                    sources.append(scalar)
            break
        if rest:
            fail("unexpected non-list value for sources in haberdasher.yaml")
        idx += 1
        while idx < len(lines):
            raw_line = strip_yaml_comment(lines[idx])
            if not raw_line.strip():
                idx += 1
                continue
            indent = len(raw_line) - len(raw_line.lstrip(" "))
            stripped = raw_line.strip()
            if indent < key_indent:
                break
            if stripped.startswith("-"):
                if len(stripped) == 1 or stripped[1].isspace():
                    item = unquote_yaml_scalar(stripped[1:])
                    if item:
                        sources.append(item)
                    idx += 1
                    continue
                fail("malformed sources entry in haberdasher.yaml")
            if indent == key_indent:
                break
            break
        break
    return {entry.lower() for entry in sources}


def parse_iso8601_epoch(value: object, label: str) -> int:
    if not isinstance(value, str) or not value.strip():
        fail(f"missing or invalid {label} timestamp")
    raw = value.strip()
    if raw.endswith(("Z", "z")):
        raw = raw[:-1] + "+00:00"
    try:
        dt = datetime.fromisoformat(raw)
    except ValueError:
        fail(f"unparseable {label} timestamp '{value}'")
    if dt.tzinfo is None:
        fail(f"timezone-naive {label} timestamp '{value}'")
    return int(dt.timestamp())


def is_security_pr(pr: object) -> bool:
    if not isinstance(pr, dict):
        return False
    head_ref = str(pr.get("headRefName") or "").strip()
    if head_ref.lower().startswith("security/"):
        return True
    author = pr.get("author")
    is_dependabot = False
    if isinstance(author, dict):
        typename = str(author.get("__typename") or "")
        login = str(author.get("login") or "").strip().lower()
        is_dependabot = (
            login in ("dependabot[bot]", "app/dependabot")
            or (login == "dependabot" and typename == "Bot")
        )
    if not is_dependabot:
        return False
    labels_obj = pr.get("labels")
    label_nodes = labels_obj.get("nodes") if isinstance(labels_obj, dict) else None
    has_security_label = False
    if isinstance(label_nodes, list):
        for node in label_nodes:
            if isinstance(node, dict):
                label_name = str(node.get("name") or "").strip().lower()
                if "security" in label_name:
                    has_security_label = True
                    break
    title = str(pr.get("title") or "")
    has_security_title = bool(SECURITY_TITLE_RE.search(title))
    return has_security_label or has_security_title


def main() -> None:
    gh_bin, repo, owner, name, tag, commit_sha, cooldown_str, now_str = sys.argv[1:9]
    cooldown_secs = int(cooldown_str)
    now_epoch = int(now_str) if now_str else int(time.time())

    # 1. Verify repository is published by Haberdasher.
    hab_doc = run_gh_json(
        gh_bin,
        ["api", "--method", "GET", "repos/wimpysworld/Haberdasher/contents/haberdasher.yaml"],
        "reading wimpysworld/Haberdasher haberdasher.yaml",
    )
    content_b64 = hab_doc.get("content")
    if not isinstance(content_b64, str) or not content_b64.strip():
        fail("haberdasher.yaml response missing base64 content")
    encoding = hab_doc.get("encoding")
    if encoding is not None and encoding != "base64":
        fail(f"haberdasher.yaml has unsupported encoding '{encoding}'")
    try:
        yaml_text = base64.b64decode(content_b64).decode("utf-8")
    except Exception as exc:
        fail(f"failed to decode haberdasher.yaml content: {exc}")
    sources = parse_haberdasher_sources(yaml_text)
    if not sources:
        fail("haberdasher.yaml contains no sources entries")
    if repo.lower() not in sources:
        fail(f"repository '{repo}' is not listed in wimpysworld/Haberdasher haberdasher.yaml sources")

    # 2. Fetch repository release, branch, CI, and PR state via GraphQL.
    gql_doc = run_gh_json(
        gh_bin,
        [
            "api",
            "graphql",
            "-f",
            f"query={GRAPHQL_QUERY}",
            "-f",
            f"owner={owner}",
            "-f",
            f"name={name}",
            "-f",
            f"tagRef=refs/tags/{tag}",
        ],
        f"reading repository state for {repo}",
    )
    errors = gql_doc.get("errors")
    if errors:
        fail(f"GraphQL returned errors for {repo}: {errors}")
    data = gql_doc.get("data")
    repo_data = data.get("repository") if isinstance(data, dict) else None
    if not isinstance(repo_data, dict):
        fail(f"repository '{repo}' not found in GraphQL response")

    # 3a. Repository must not be archived.
    if repo_data.get("isArchived") is not False:
        fail(f"repository '{repo}' is archived or archive state is unknown")

    # 3b. Default branch HEAD must match commit-sha and have SUCCESS CI.
    default_branch = repo_data.get("defaultBranchRef")
    target = default_branch.get("target") if isinstance(default_branch, dict) else None
    if not isinstance(target, dict):
        fail(f"repository '{repo}' missing defaultBranchRef.target")
    head_oid = target.get("oid")
    if head_oid != commit_sha:
        fail(f"commit-sha '{commit_sha}' does not match default branch HEAD '{head_oid}'")

    rollup = target.get("statusCheckRollup")
    ci_state = rollup.get("state") if isinstance(rollup, dict) else None
    if ci_state != "SUCCESS":
        fail(f"default branch HEAD statusCheckRollup state is '{ci_state}', expected 'SUCCESS'")

    # 3c. Target tag must not already exist.
    if "ref" not in repo_data or repo_data["ref"] is not None:
        fail(f"tag '{tag}' already exists in '{repo}' or ref field was omitted")

    # 3d. Latest release must exist, be stable, match semver, and point to a different commit.
    latest_release = repo_data.get("latestRelease")
    if not isinstance(latest_release, dict):
        fail(f"repository '{repo}' has no latestRelease")
    if latest_release.get("isDraft") is not False:
        fail(f"latestRelease in '{repo}' is a draft")
    if latest_release.get("isPrerelease") is not False:
        fail(f"latestRelease in '{repo}' is a prerelease")
    latest_tag = latest_release.get("tagName")
    if not isinstance(latest_tag, str):
        fail(f"latestRelease in '{repo}' has invalid tagName")
    semver_match = SEMVER_RE.fullmatch(latest_tag)
    if not semver_match:
        fail(f"latestRelease tag '{latest_tag}' does not match strict semver ^v[0-9]+\\.[0-9]+\\.[0-9]+$")
    major, minor, patch = (int(semver_match.group(1)), int(semver_match.group(2)), int(semver_match.group(3)))
    latest_published_epoch = parse_iso8601_epoch(latest_release.get("publishedAt"), "latestRelease.publishedAt")
    tag_commit = latest_release.get("tagCommit")
    latest_tag_oid = tag_commit.get("oid") if isinstance(tag_commit, dict) else None
    if latest_tag_oid == commit_sha:
        fail(f"commit-sha '{commit_sha}' is already tagged as latestRelease '{latest_tag}'")

    # 3e. Zero open security PRs.
    open_prs_obj = repo_data.get("openPrs")
    open_nodes = open_prs_obj.get("nodes") if isinstance(open_prs_obj, dict) else None
    if not isinstance(open_nodes, list):
        fail(f"repository '{repo}' GraphQL response missing openPrs.nodes")
    for pr in open_nodes:
        if is_security_pr(pr):
            pr_num = pr.get("number") if isinstance(pr, dict) else "?"
            pr_ref = pr.get("headRefName") if isinstance(pr, dict) else "?"
            fail(f"open security pull request #{pr_num} ({pr_ref}) blocks security release tagging")

    # 3f. At least one merged security PR after latestRelease.publishedAt, and cooldown elapsed.
    merged_prs_obj = repo_data.get("mergedPrs")
    merged_nodes = merged_prs_obj.get("nodes") if isinstance(merged_prs_obj, dict) else None
    if not isinstance(merged_nodes, list):
        fail(f"repository '{repo}' GraphQL response missing mergedPrs.nodes")
    merged_security_epochs: list[int] = []
    for pr in merged_nodes:
        if not is_security_pr(pr):
            continue
        merged_epoch = parse_iso8601_epoch(pr.get("mergedAt"), "mergedPr.mergedAt")
        if merged_epoch > latest_published_epoch:
            merged_security_epochs.append(merged_epoch)
    if not merged_security_epochs:
        fail(f"no security pull request merged in '{repo}' after latestRelease '{latest_tag}'")
    latest_security_merged_epoch = max(merged_security_epochs)
    elapsed_secs = now_epoch - latest_security_merged_epoch
    if elapsed_secs < cooldown_secs:
        fail(
            f"security merge cooldown not elapsed: {elapsed_secs}s elapsed, requires at least {cooldown_secs}s"
        )

    # 3g. Inspect commits since latestRelease for breaking changes and expected semver bump.
    history_obj = target.get("history")
    history_nodes = history_obj.get("nodes") if isinstance(history_obj, dict) else None
    if not isinstance(history_nodes, list) or not history_nodes:
        fail(f"repository '{repo}' defaultBranchRef.target.history.nodes is missing or empty")

    commits_since_release: list[dict] = []
    has_tag_oid_in_history = bool(
        latest_tag_oid
        and any(isinstance(node, dict) and node.get("oid") == latest_tag_oid for node in history_nodes)
    )
    if has_tag_oid_in_history:
        for node in history_nodes:
            if not isinstance(node, dict):
                fail("malformed commit node in default branch history")
            if node.get("oid") == latest_tag_oid:
                break
            commits_since_release.append(node)
    else:
        reached_release_boundary = False
        for node in history_nodes:
            if not isinstance(node, dict):
                fail("malformed commit node in default branch history")
            committed_epoch = parse_iso8601_epoch(node.get("committedDate"), "commit.committedDate")
            if committed_epoch <= latest_published_epoch:
                reached_release_boundary = True
                break
            commits_since_release.append(node)
        if not reached_release_boundary and len(history_nodes) >= 50:
            fail("commit history since latestRelease exceeds 50-commit inspection window")

    if not commits_since_release:
        fail(f"no commits found since latestRelease '{latest_tag}'")

    has_feat = False
    for commit in commits_since_release:
        headline = commit.get("messageHeadline")
        if not isinstance(headline, str):
            fail("commit in history missing messageHeadline")
        if BREAKING_PREFIX_RE.search(headline) or BREAKING_CHANGE_RE.search(headline):
            fail(f"breaking commit prevents automated security release tag: '{headline}'")
        if FEAT_PREFIX_RE.search(headline):
            has_feat = True

    if has_feat:
        expected_tag = f"v{major}.{minor + 1}.0"
    else:
        expected_tag = f"v{major}.{minor}.{patch + 1}"

    if tag != expected_tag:
        fail(
            f"requested tag '{tag}' does not match expected tag '{expected_tag}' "
            f"(from latestRelease '{latest_tag}')"
        )


if __name__ == "__main__":
    main()
PY
verify_status=$?
set -e
if [[ ${verify_status} -ne 0 ]]; then
	exit "${verify_status}"
fi

if [[ ${dry_run} == true ]]; then
	printf 'gh-security-release-tag: dry-run passed for %s %s (%s)\n' "${repo}" "${tag}" "${commit_sha}"
	exit 0
fi

set +e
"${GH_SECURITY_RELEASE_TAG_GH_BIN}" api --method POST "repos/${repo}/git/refs" \
	-f "ref=refs/tags/${tag}" \
	-f "sha=${commit_sha}" \
	</dev/null >/dev/null
post_status=$?
set -e
if [[ ${post_status} -ne 0 ]]; then
	printf 'gh-security-release-tag: gh exited %s while creating tag %s in %s.\n' "${post_status}" "${tag}" "${repo}" >&2
	exit "${post_status}"
fi

printf 'gh-security-release-tag: created tag %s in %s at %s.\n' "${tag}" "${repo}" "${commit_sha}"
