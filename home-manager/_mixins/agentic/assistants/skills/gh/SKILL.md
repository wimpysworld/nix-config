---
name: gh
description: "Load when executing GitHub tasks via the gh CLI: creating or reviewing pull requests, managing issues, checking CI runs, creating releases, searching GitHub, or making raw GitHub API calls."
user-invocable: true
---

# GitHub CLI (gh) Reference

## Pull Requests

```bash
# List
gh pr list
gh pr list --state merged --limit 10
gh pr list --json number,title,headRefName,statusCheckRollup

# View
gh pr view 123
gh pr view 123 --comments
gh pr view 123 --json state,mergeable,mergeStateStatus | jq

# Create
gh pr create --fill                                             # title/body from commits
gh pr create --title "feat: add X" --body "..." --draft
gh pr create --base main --reviewer alice,bob --label "needs-review"

# Merge
gh pr merge 123 --squash --delete-branch
gh pr merge 123 --auto --squash                                 # merge once CI passes

# Review & comment
# Note: --approve is denied under Fence (no self-approval). Use
# --comment or --request-changes for review feedback.
gh pr review 123 --comment --body "LGTM"
gh pr review 123 --request-changes --body "Please fix X"
gh pr comment 123 --body "LGTM"
gh pr comment 123 --edit-last --body "Updated: LGTM"

# CI status
gh pr checks 123
gh pr checks 123 --watch                                        # stream until complete

# Edit
gh pr edit 123 --add-label "bug" --add-reviewer charlie
gh pr edit 123 --base develop --title "Updated title"

# Other
gh pr checkout 123
gh pr diff 123
gh pr revert 123 --title "revert: undo X"
gh pr ready 123                                                 # mark draft as ready
```

## Issues

```bash
# List
gh issue list
gh issue list --assignee @me --state open
gh issue list --label "bug" --json number,title,state

# View
gh issue view 456
gh issue view 456 --comments

# Create
gh issue create --title "Bug: X fails" --body "Steps..." --label "bug" --assignee @me

# Manage
gh issue edit 456 --add-label "priority" --milestone "v2.0"
gh issue close 456
gh issue reopen 456
gh issue comment 456 --body "Fixed in #123"
gh issue develop 456 --name "fix/issue-456"                    # create linked branch
```

## CI / Actions

```bash
# List runs
gh run list
gh run list --branch main --status failure --limit 5
gh run list --workflow build.yml --json name,status,conclusion,headBranch

# View a run
gh run view 12345678
gh run view 12345678 --verbose                                  # all job steps
gh run view 12345678 --log-failed                               # logs for failed steps only
gh run view 12345678 --log                                      # full log
gh run view 12345678 --exit-status                             # non-zero exit if failed (scripts)

# Get job IDs (required for --job flag)
gh run view 12345678 --json jobs --jq '.jobs[] | {name, databaseId}'
gh run view 12345678 --job 98765432

# Watch live
gh run watch 12345678

# Rerun
gh run rerun 12345678
gh run rerun 12345678 --failed                                  # only failed jobs
gh run rerun 12345678 --debug                                   # with debug logging

# Trigger workflow_dispatch
gh workflow run deploy.yml --ref main
gh workflow run deploy.yml -f env=staging -f version=1.2.3

# List workflows
gh workflow list
gh workflow view build.yml
```

## Releases

```bash
# Create
gh release create v1.2.3 --generate-notes
gh release create v1.2.3 --title "v1.2.3" --notes "Fixes #123" dist/*.tar.gz
gh release create v1.2.3 --draft --prerelease
gh release create v1.2.3 --notes-from-tag                      # use annotated tag message

# List / view
gh release list
gh release view v1.2.3

# Upload asset to existing release
gh release upload v1.2.3 dist/binary.tar.gz
```

## Repository

```bash
# View
gh repo view
gh repo view owner/repo --json name,description,defaultBranchRef,isPrivate

# Clone / fork
gh repo clone owner/repo
gh repo fork owner/repo --clone

# Create
gh repo create my-project --private --clone
gh repo create my-project --public --source=. --push

# Edit settings
gh repo edit --default-branch main --enable-auto-merge
gh repo edit --description "New description" --homepage "https://example.com"

# Cross-repo flag (works on most commands)
gh pr list -R owner/other-repo
```

## Search

```bash
# Repositories
gh search repos "nix config" --language nix --stars ">100" --sort stars

# Issues and PRs across GitHub
gh search issues "memory leak" --repo owner/repo --state open
gh search prs "fix authentication" --author alice --merged
gh search prs --repo owner/repo --checks failure --state open   # failing CI

# Code (legacy engine; for regex use `gh-api-safe 'search/code?q=...'`)
gh search code "sops.placeholder" --repo owner/repo --language nix
```

## Raw API

Default to a dedicated `gh` subcommand. Use `gh-api-safe` only when no
subcommand fits. Reserve raw `gh api` for mutations or `@file` field
input, gated on explicit operator consent.

| Situation | Use |
|---|---|
| Read-only REST fetch | `gh-api-safe <path>` |
| GraphQL read (queries only) | `gh-api-safe graphql -f query='…'` |
| Dedicated subcommand exists | that subcommand (`gh pr edit`, `gh label create`, ...) |
| Mutation (POST/PATCH/PUT/DELETE) | `gh api -X ...` in unfenced shell |
| Field input from file (`-F x=@file`) | raw `gh api` |

`gh-api-safe` wraps `gh api`, enforces a read-shaped allow-list with a
defence-in-depth deny-list on the REST path, blocks
`-X`/`--method`/`-f`/`-F`/`--field`/`--raw-field`/`--input` (except `query=` value under `graphql`, where `@file` is still rejected), and runs a
best-effort GraphQL heuristic that rejects any query whose body contains
a surviving `mutation` or `subscription` keyword after comments and
string literals have been stripped. The heuristic is not a real GraphQL
parser; aliased mutations are out of scope and `@file` queries are
rejected outright. Policy rejections exit 64 with a single-line reason
on stderr; on rejection, switch to the matching dedicated subcommand or
escalate to an unfenced shell rather than retrying the same call. Run
`gh-api-safe --help` for the full policy summary.

Placeholders `{owner}`, `{repo}`, `{branch}` are replaced from current
git context. Default method is GET.

```bash
# GET with jq
gh-api-safe repos/{owner}/{repo}/actions/runs \
  --jq '.workflow_runs[:5] | .[] | {name, conclusion, html_url}'

# Paginate all results
gh-api-safe repos/{owner}/{repo}/issues --paginate --jq '.[].title'

# GraphQL (heuristic-screened; mutations and subscriptions are rejected)
gh-api-safe graphql -f query='{ viewer { login } }'

# Rejected: surviving `mutation` keyword (exit 64 on stderr)
gh-api-safe graphql -f query='mutation { addStar(input: {starrableId: "X"}) { starrable { id } } }'

# Out of scope: `@file` query bodies are rejected outright (exit 64)
gh-api-safe graphql -f query=@query.graphql

# Notifications (read only; PUT mark-as-read is blocked by the wrapper)
gh-api-safe notifications --jq '.[] | {reason, subject: .subject.title}'
```

See `home-manager/_mixins/agentic/fence/README.md` for the read-only
fence policy and `home-manager/_mixins/development/github/gh-api-safe.sh`
for the wrapper source.

### Unsafe: requires unfenced shell

> ⚠️ The commands below mutate GitHub state. They use `gh api` directly
> with `-X` / `-F` / `--input` and are rejected by `gh-api-safe`. They must
> only be run in an unfenced shell with explicit operator consent. Prefer
> the dedicated `gh` subcommands (`gh issue edit`, `gh label create`, etc.)
> wherever they exist.

```bash
# PATCH / POST
gh api repos/{owner}/{repo}/issues/456 -X PATCH -F state=closed
gh api repos/{owner}/{repo}/labels -F name="triage" -F color="e4e669"

# Typed fields (-F): true/false/null/integers become JSON types; @file reads file
gh api repos/{owner}/{repo}/issues -F title="Bug" -F body=@issue.md
```

## JSON Output Pattern

Most commands accept `--json fields` with optional `--jq expression`:

```bash
# Named fields only
gh pr list --json number,title,state,headRefName
gh run list --json name,status,conclusion,headBranch,createdAt

# Filter inline
gh pr list --json number,title,statusCheckRollup \
  --jq '.[] | select(.statusCheckRollup | any(.state == "FAILURE")) | .number'

# Check mergeability
gh pr view 123 --json mergeable,mergeStateStatus

# Combine with jq outside gh for complex transforms
gh issue list --json number,title,labels | jq '.[] | select(.labels | any(.name == "bug"))'
```

## Status & Auth

```bash
gh status                  # cross-repo overview: assigned PRs, review requests, mentions
gh auth status             # active account, token scopes, expiry
# `gh auth token` is denied under Fence. If a tool needs the token,
# read it from ~/.config/gh/hosts.yml directly (filesystem-allowed).
```
