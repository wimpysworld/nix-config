---
name: review-report-path
description: "Use when a review, audit, or analysis command must decide where to write its report, or must find a report written earlier. Defines durable per-user report storage and the slug and run rules that preserve parallel and past reviews of pull requests, issues, branches, commits, and worktrees. Use even when the caller only says 'write the report', 'read the review report', or names a report file."
---

# Review Report Path

Every review, audit, and analysis report goes to durable per-user state storage:

```
${XDG_STATE_HOME:-${HOME}/.local/state}/agent-reviews/<project>/<target>/<run-id>/<report-name>
```

The calling command supplies `<report-name>`. This skill supplies `<project>`, `<target>`, and `<run-id>`.

Do not use `/tmp` or `$TMPDIR`. A fenced process can have private temporary storage that disappears after that process exits.

## Project

`<project>` is the repository directory name, kebab-case. In a git worktree, take the name of the main repository, not the worktree directory, so every review of one repository lands under one directory.

## Target

`<target>` names what is under review. It keeps concurrent reviews apart, so two reviews running at once never write to the same file.

Take the first rule that matches:

| Target | Slug | Example |
| --- | --- | --- |
| Pull request, by URL, number, or `owner/repo#123` | `pr-<number>` | `pr-123` |
| Branch or worktree whose branch has an open pull request, found with `gh pr view --json number` | `pr-<number>` | `pr-123` |
| Linear issue, by key or URL | `issue-<key>` | `issue-eng-123` |
| GitHub issue, by URL or `owner/repo#123` | `issue-<number>` | `issue-456` |
| Single commit | `commit-<short-sha>` | `commit-a1b2c3d` |
| Branch with no pull request | `branch-<name>` | `branch-feat-fix-auth` |
| Local file, such as a plan or pasted feedback | `file-<basename>` | `file-plan` |
| Anything else, including a detached checkout | `worktree-<dirname>` | `worktree-nix-config-pr-123` |

A command that takes no argument reviews the checkout it runs in, so it starts at the branch rules.

Normalise every slug: lowercase it, replace each character outside `a-z0-9` with a hyphen, collapse repeated hyphens, trim leading and trailing hyphens, and cut it to 60 characters.

## Run

Create a new run directory for every invocation, after deriving `<project>` and `<target>`:

```sh
report_root="${XDG_STATE_HOME:-${HOME}/.local/state}/agent-reviews/<project>/<target>"
mkdir -p "$report_root"
run_dir="$(mktemp -d "$report_root/run-$(date -u +%Y%m%dT%H%M%SZ)-XXXXXX")"
```

`mktemp -d` creates the run directory exclusively. Keep the generated directory name as `<run-id>`. Use the same `run_dir` for the final report and all fallback findings from that invocation.

## Find a Report

Derive the target directory from durable state, then search every run:

```sh
target_dir="${XDG_STATE_HOME:-${HOME}/.local/state}/agent-reviews/<project>/<target>"
if [ -d "$target_dir" ]; then
  for run_dir in "$target_dir"/run-*; do
    [ -d "$run_dir" ] || continue
    report_path="$run_dir/<report-name>"
    [ -f "$report_path" ] && printf '%s\n' "$report_path"
  done | sort
fi
```

When the caller does not name a report, exclude worker fallback files:

```sh
if [ -d "$target_dir" ]; then
  for run_dir in "$target_dir"/run-*; do
    [ -d "$run_dir" ] || continue
    for report_path in "$run_dir"/*; do
      [ -f "$report_path" ] || continue
      case "${report_path##*/}" in
        findings-*.md) continue ;;
      esac
      printf '%s\n' "$report_path"
    done
  done | sort
fi
```

The run directory stays in each result, so the caller can select an exact past run.

## Rules

- Create the state and target directories if they do not exist.
- Create a new run directory before any worker writes a fallback findings file.
- Never delete a run directory or a report. Never reuse a run directory for a later invocation.
- Never overwrite an existing report or findings file. If an expected new path exists before fan-out, create another run directory.
- Keep reports outside the repository and never commit them.
- Report the written path in your output so the user can find it.
- To find a report, derive the same project and target directory in per-user state storage. Search all `run-*` directories under that target.
- When the caller names a report file, list each matching `<run-id>/<report-name>`. Use the sole match, or ask which run to use when several match.
- When the caller does not name a report file, list the reports with their run IDs. Use the sole report, or ask which one to use when several exist.
- Never select the newest report when several reports match. Ask the caller to select an exact run.
- When the target directory is missing or empty, list target directories under `${XDG_STATE_HOME:-${HOME}/.local/state}/agent-reviews/<project>/` instead of guessing.
