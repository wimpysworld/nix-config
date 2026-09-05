# Linear

Tracker mechanics for tasks held in Linear. Use the Linear MCP for every read and write. The wording below is the behaviour the task commands carried before this skill existed, so the Linear path is unchanged.

## Contents

1. Identity and lookup
2. Status roles
3. type and area
4. priority
5. estimate
6. parent and order
7. assignee
8. durable record
9. long research
10. branch link
11. Limits

## Identity and lookup

A task is an issue key such as `FUL-123` or a `linear.app` issue URL. Read the issue and its sub-issues with the Linear MCP. For `create-task`, the target is a project name: list Linear projects and fuzzy match. `create-task` decides whether the match needs confirming.

Workspace guard, for commands that also read Git: classify `git config user.email`. An address on the `chainguard.dev` domain means work, anything else means personal. The connected Linear instance is personal when the `WW` team, Wimpy's World, is visible, and work when `FUL`, Fulfillment Automation, is visible. If the classification and the visible instance disagree, skip the Linear write and report one line saying the profile does not match the repository. Never touch a work issue from the personal workspace or the reverse.

## Status roles

Gate on the workflow status type, never on the status name. Linear's types are `triage`, `backlog`, `unstarted`, `started`, `completed`, and `cancelled`. Query the team's live workflow statuses at run time and never create a status.

| Role | Linear |
| ---- | ------ |
| new | The team's `triage`-type status. If the team has no `triage`-type status, use the team's default entry status and say so in the report. Linear's Triage is a per-team feature that can be switched off |
| ready | The team's `backlog`-type status. `update-task` promotes a `triage`-type issue here as part of its update |
| started | The `started`-type status. Both In Progress and In Review are `started`, so pick the one whose position is first, or the one named In Progress |
| in review | The `started`-type status named In Review. If the team has no `started`-type status named In Review, skip the move and say so. Move forward only: leave the issue where it is when it is already In Review, when its type is `completed` or `cancelled`, or when its `started`-type status sits after In Review in the team's own order. Write only from `triage`, `backlog`, `unstarted`, or an earlier `started` status |
| done | The `completed`-type status named Done. Use `save_issue` with only `id` and `state`. If the status type is already `completed`, `canceled`, or `duplicate`, preserve it |
| inactive | Type `completed` (Done) or `cancelled` (Cancelled, Duplicate). `update-task` reports the status and stops, changing nothing at all |

A caller of `create-task` may name a different status. Resolve it against the team's workflow statuses. This is how a caller with an already-researched task files straight to Backlog.

## type and area

Query the team's labels at run time. Never invent or create a label.

- If the taxonomy has type-like labels, apply exactly one: bug when shipped behaviour is wrong, feature when a user-visible capability is new, otherwise the improvement equivalent.
- Apply every area or component label the work touches. Multiple is normal.
- If no area label fits, the type label alone is enough.
- If the taxonomy has no type-like labels, apply the best-fitting labels available.

## priority

Linear priority maps one to one: 1 Urgent, 2 High, 3 Medium, 4 Low. Never set 0 No priority deliberately. A parent takes the highest priority among its children.

## estimate

Query whether estimates are enabled for the team and on what scale. Load the `sizing` skill and map its size to the scale in use. Leave parent tracking tasks unestimated.

## parent and order

Create children as sub-issues of the parent, in dependency order, so identifiers ascend with the sequence. Express the order in the parent's `Child issues` numbered list, with `Depends on <n>` on each entry, and restate each edge in the child's `Dependencies` section. Do not create Linear blocking relations. This workspace does not use them.

## assignee

Assign every issue, parent and children, to the user creating or claiming it. Resolve that user at run time from the authenticated Linear identity. Never hard-code an identifier.

## durable record

Post the record as a Linear comment on the issue with `save_comment`. Send real newlines in the body, never literal backslash-n. `finish-pr` appends `<!-- pr-done-workflow:<full-head-sha> -->` to its comment and skips the post when that exact marker is already present.

## long research

Where the research exceeds roughly 6,000 characters, or will outlive the work, create a Linear document holding the durable record, link it from the parent, and say so in one line in the parent body.

## branch link

Two things link an issue, and nothing else does: the branch name, when it contains the issue key (a branch named `ful-123` links FUL-123), and a `Refs: <ISSUE-KEY>` trailer on any commit in `main..HEAD`. Never take a key from the pull request body or a commit subject. A key mentioned in prose is not a link.

`implement-task` names the branch with the bare lowercased issue key, such as `ful-123`, or the parent's key for a cohort. Linear links and auto-closes the issue when the branch name contains its key, so add nothing to the key. Each commit carries a `Refs: <ISSUE-KEY>` footer.

`make-pr` and `finish-pr` collect keys only from complete issue-key tokens in the head branch, at non-alphanumeric boundaries, and exact `Refs:` trailers parsed from the commits in `main..HEAD` or the resolved PR. A branch token counts only when its prefix matches a team key visible in the connected workspace, so a GitHub branch such as `42-fix-the-thing` or `development-42` never becomes a Linear lookup. Deduplicate case-insensitively. Do not scan other prose or metadata for keys.

In a pull request body, write `[FUL-1](https://linear.app/<workspace>/issue/FUL-1)`: that URL resolves, while the slugged URL Linear hands you ends in the issue title and publishes it on a repository that may be public. Never paste a slugged Linear URL.

## Limits

Never run an unfiltered workspace-wide issue query. In a large workspace it exceeds the tool's output limit. Narrow `fields` to what the report needs. `list_issues` has no created-by filter, so filter the returned issues on `createdById`.
