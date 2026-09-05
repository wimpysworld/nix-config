---
name: task-tracker
description: "Use when a command reads or writes a tracked task and must know which tracker holds it: Linear, a GitHub Project, or a local Markdown file. Resolves the tracker from an issue key, an issue URL, `owner/repo#N`, a project URL, or a path, then names the tracker-specific mechanics for status, type, labels, priority, estimate, parent and child order, assignee, comments, long research, and branch links. Use whenever `create-task`, `review-task`, `update-task`, `implement-task`, `make-pr`, or `pr-done` touches a task, even when the caller names only Linear or only GitHub."
---

# Task tracker

One task workflow, three trackers. The commands speak in roles. This skill maps each role onto Linear, GitHub Projects, or a local file, so a command never names a tracker mechanic itself.

## Resolve the tracker from the input

Decide from `$ARGUMENTS`. Never decide from the repository, the Git remote, or the current directory.

| Input form | Tracker | Reference |
| ---------- | ------- | --------- |
| Issue key such as `FUL-123` or `WW-7`, or a `linear.app` URL | Linear | `references/linear.md` |
| Linear project name (for `create-task`) | Linear | `references/linear.md` |
| `owner/repo#N`, a `github.com/<owner>/<repo>/issues/<n>` URL | GitHub Projects | `references/github-projects.md` |
| `github.com/orgs/<org>/projects/<n>` or `github.com/users/<user>/projects/<n>` URL (for `create-task`) | GitHub Projects | `references/github-projects.md` |
| Filesystem path | Local file | Body template only, no tracker |

`make-pr` and `pr-done` take no task argument. They resolve each linked issue from the Git evidence instead, by the same shape rules: a `Refs: <ISSUE-KEY>` trailer is Linear, a `Refs: <owner>/<repo>#<n>` trailer is GitHub, an issue-key token in the branch name at non-alphanumeric boundaries is Linear when its prefix matches a team key visible in the connected workspace, and a pull request's `closingIssuesReferences` entry is GitHub. One branch may link issues in both trackers.

Read the matching reference before the first tracker call. Read only the ones the input needs. A command that handles a cohort resolves the tracker once from the parent and applies it to every child.

When the input does not match any form, ask which tracker before doing anything else.

## Roles every command uses

| Role | Meaning |
| ---- | ------- |
| new | Filed, not yet groomed. `create-task` lands here by default |
| ready | Groomed and ready to pick up. `update-task` promotes to here |
| started | Claimed. `implement-task` moves here |
| in review | A pull request is open. `make-pr` moves here |
| done | Merged. `pr-done` moves here |
| inactive | Completed or cancelled. `update-task` refuses to touch it |
| type | Bug, feature, or improvement |
| area | Component or subsystem labels |
| priority | 1 Urgent, 2 High, 3 Medium, 4 Low |
| estimate | The `sizing` skill's scale |
| parent and order | A tracking task with children, ordered by its `Child issues` list |
| assignee | The authenticated user |
| durable record | The comment a command posts when work lands |
| long research | Where research over roughly 6,000 characters lives |
| branch link | How a branch and pull request attach to the task |

Each reference has one section per role, in this order, plus an `Identity and lookup` section first and a `Limits` section last.

## Shared rules

- Gate on the role, never on a status name. The reference says how the role is recognised.
- Resolve the user at run time. Never hard-code an identifier or a login.
- Draw type, area, priority, and estimate from the tracker's live taxonomy. Never invent a label, a type, or an option.
- The body template, `contribution-voice`, `sizing`, and the `Child issues` ordering are tracker-neutral. They do not move into a reference.
- Dependency order lives in the parent body's `Child issues` list, never in tracker relations.
- A tracker failure after the code has landed is reported in one line and never blocks the Git work.

## Commands that stay Linear-only

`triage-tasks`, `work-order-create`, `work-order-plan`, `work-order-next`, `work-order-update`, and `weekly-update` depend on cycles, documents, status updates, or the Triage queue. GitHub Projects has no equivalent, so they accept Linear input only and say so.
