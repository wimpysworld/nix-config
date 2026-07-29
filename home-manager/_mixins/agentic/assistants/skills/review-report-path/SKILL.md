---
name: review-report-path
description: "Use when a review, audit, or analysis command must decide where to write its report, or must find a report written earlier. Defines the `${TMPDIR:-/tmp}/agent-reviews/<project>/<target>/` path and the slug rules that keep parallel reviews of pull requests, issues, branches, commits, and worktrees from overwriting each other. Use even when the caller only says 'write the report', 'read the review report', or names a report file."
---

# Review Report Path

Every review, audit, and analysis report goes to one path:

```
${TMPDIR:-/tmp}/agent-reviews/<project>/<target>/<report-name>
```

The calling command supplies `<report-name>`. This skill supplies `<project>` and `<target>`.

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

## Rules

- Create the directory if it does not exist.
- The report is disposable. It lasts for one review only. Never commit it and never write it inside the repo.
- Report the written path in your output so the user can find it.
- To read a report back, derive the same path from the same target. When that directory holds several reports, ask which one to use. When it is missing, list the target directories under `${TMPDIR:-/tmp}/agent-reviews/<project>/` instead of guessing.
