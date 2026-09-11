
# Review Report Path

Store private diagnostic reports from reviews, audits, and analysis in durable per-user state storage by default:

```
${XDG_STATE_HOME:-${HOME}/.local/state}/agent-reviews/<project>/<target>/<run-id>/<report-name>
```

The calling command supplies `<report-name>`. This skill supplies `<project>`, `<target>`, and `<run-id>`.

This convention excludes project documents, tracker content, disposable plans, transport payloads, and runtime logs. Keep those outputs under their own workflow contracts.

Honour explicit user destinations unless the calling workflow restricts the input or output boundary. Otherwise, keep reports outside the repository and never commit them. Do not use `/tmp` or `$TMPDIR` for default report storage. A fenced process can have private temporary storage that disappears after that process exits.

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

Only the owner starting a new report-writing workflow allocates a run. Lookup creates no directories or files. Workers use the supplied run and fallback paths, not a new run.

For a new report-writing workflow, derive `<project>` and `<target>`, then allocate one run before any worker writes fallback findings:

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

- Create missing state and target directories only when allocating a new report run.
- Never delete a run directory, report, or fallback findings file. Never reuse a run directory for a later invocation.
- Never overwrite an existing report or findings file. If an expected new path exists, stop writing to it. The workflow owner allocates another run and supplies replacement paths before workers write.
- Report the written path in your output so the user can find it.
- To find a report, derive the same project and target directory in per-user state storage. Search all `run-*` directories under that target.
- When the caller names a report file, list each matching `<run-id>/<report-name>`. Use the sole match, or ask which run to use when several match.
- When the caller does not name a report file, list the reports with their run IDs. Use the sole report, or ask which one to use when several exist.
- Unless the calling workflow explicitly overrides selection, never select the newest report when several reports match. Ask the caller to select an exact run.
- When no matching report exists, list available target directories under `${XDG_STATE_HOME:-${HOME}/.local/state}/agent-reviews/<project>/` and stop instead of guessing. This includes missing, empty, and fallback-only target directories.
