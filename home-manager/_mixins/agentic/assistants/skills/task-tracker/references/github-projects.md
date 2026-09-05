# GitHub Projects

Tracker mechanics for tasks held as GitHub issues on a GitHub Project (ProjectV2). Use the `gh` CLI, and load the `gh` skill first. Everything below uses dedicated `gh` subcommands, never raw `gh api`. The `gh` token needs the `project` scope for item writes. Fence permits `gh issue create`, `gh issue edit`, `gh issue comment`, `gh issue develop`, `gh project item-add`, and `gh project item-edit`.

The examples name the Noughty Linux Kanban, `github.com/orgs/noughtylinux/projects/2`, which ships with GitHub's Kanban template and default fields. Read every id at run time. Never hard-code one.

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

A task is a repository issue, written `owner/repo#N` or as a `github.com/<owner>/<repo>/issues/<n>` URL. Read it with:

```sh
gh issue view <n> --repo <owner>/<repo> --json number,title,body,state,stateReason,labels,assignees,issueType,parent,subIssues,subIssuesSummary,projectItems,url
```

`projectItems` lists the projects the issue sits on, with each item's `status` and the project title, but not the project number or id. Resolve those with `gh project list --owner <owner> --format json` and match on `title`, which gives `number` and `id`. Then read the item id with the `item-list` filter below. When the issue is on more than one project, use the one whose URL or title the caller named, or the only one owned by the repository's owner.

For `create-task`, the target is a project URL, `github.com/orgs/<org>/projects/<n>` or `github.com/users/<user>/projects/<n>`. Resolve it and its fields:

```sh
gh project view <n> --owner <owner> --format json
gh project field-list <n> --owner <owner> --format json
```

`project view` returns the project `id`, needed by `item-edit`. `field-list` returns each field's `id`, `type`, and, for single-select fields, `options[]` with `name` and `id`.

An issue also needs a repository. Take it from the current checkout with `gh repo view --json nameWithOwner` when that repository belongs to the project owner. Otherwise list the owner's repositories with `gh repo list <owner> --json name`, pick the one the task's subject fits, and name it in the one-line match statement or the confirmation question that `create-task` makes. Ask about the repository only when no repository is a clear fit.

Adding an issue to the project, when the built-in auto-add workflow has not already done it:

```sh
gh project item-add <n> --owner <owner> --url <issue-url> --format json
```

The response carries the item `id`. Re-read the item id at any time with `gh project item-list <n> --owner <owner> --format json --limit 200 --jq '.items[] | select(.content.url == "<issue-url>") | .id'`.

## Status roles

Status is one single-select field per project. The options are names with no type, so the mapping below supplies the role. Read the option ids from `field-list` and set them with `item-edit`:

```sh
gh project item-edit --project-id <project-id> --id <item-id> --field-id <status-field-id> --single-select-option-id <option-id>
```

One field per call.

| Role | Kanban template Status | Notes |
| ---- | ---------------------- | ----- |
| new | `Backlog` | Where `create-task` lands an issue. The template has no Triage column and none is added |
| ready | `Ready` | `update-task` moves a `Backlog` item here |
| started | `In progress` | |
| in review | `In review` | Move forward only. Leave the item where it is when it is already `In review` or `Done`, or when the issue is closed |
| done | `Done` | The built-in workflow moves a closed issue or merged pull request here on its own. Set it only when the issue is closed and the item still shows another Status. When the issue is still open after the merge, because the pull request carried no `Closes` line, report `Status: skipped: issue open` and change nothing |
| inactive | Issue `state` is `CLOSED` | `stateReason` `COMPLETED` is done, `NOT_PLANNED` is cancelled. Status alone does not decide this. `update-task` reports the state and stops |

A project that does not use the Kanban template names its columns differently. Match on the option names present, in this preference order: new is `Backlog`, then `Todo`, then the first option; ready is `Ready`, then the option after new; started is `In progress`, then `In Progress`; in review is `In review`, then `In Review`; done is `Done`. Where a role has no option, skip the move and say so. Never create an option.

## type and area

Type is the organisation-level issue type, not a label. Read the enabled types with `gh issue list --repo <owner>/<repo> --limit 1 --json issueType` on an existing issue, or accept GitHub's defaults `Task`, `Bug`, and `Feature`. Set it at creation with `gh issue create --type <name>` or later with `gh issue edit <n> --type <name>`.

| Command role | Issue type |
| ------------ | ---------- |
| bug, shipped behaviour is wrong | `Bug` |
| feature, a user-visible capability is new | `Feature` |
| improvement, everything else | `Task` |

A user-owned project has no organisation and no issue types. Fall back to type-like labels as the Linear reference describes.

Area labels are repository labels. Read them with `gh label list --repo <owner>/<repo> --json name,description`. Apply every area label the work touches with `--label` on create or `--add-label` on edit. Never create a label.

## priority

`Priority` is a project single-select field. The Kanban template ships `P0`, `P1`, and `P2`, and that set stays as it is.

| Command priority | Option |
| ---------------- | ------ |
| 1 Urgent | `P0` |
| 2 High | `P1` |
| 3 Medium | `P2` |
| 4 Low | `P2` |

Set it with `item-edit` and the `Priority` field id. When the project has no `Priority` field, record the priority in the body's `Why` section in one clause and say so in the report.

## estimate

`Size` is a project single-select field with `XS`, `S`, `M`, `L`, and `XL`, which is the `sizing` skill's scale one to one. Set it with `item-edit` and the `Size` field id. Leave the numeric `Estimate` field unused. Leave parent tracking tasks unsized. When the project has no `Size` field, omit the estimate and say so in the report.

## parent and order

Children are native sub-issues. Create the parent first, then each child in dependency order with `--parent`:

```sh
gh issue create --repo <owner>/<repo> --title <title> --body-file <file> --type <type> --assignee @me --project <project-title> --parent <parent-number>
```

`--project` takes the project title and adds the issue to the project at creation, so a separate `item-add` is not needed. Attach an existing issue with `gh issue edit <parent> --add-sub-issue <n>`.

Order still lives in the parent body's `Child issues` numbered list with `Depends on <n>`, restated in each child's `Dependencies` section. Do not use GitHub's `--blocked-by` dependency relations, so the parent body stays the single source of order across both trackers. The project's `Parent issue` and `Sub-issues progress` fields fill in on their own.

Read children with `gh issue view <parent> --json subIssues`. Each entry carries `number`, `title`, `state`, and `url`.

## assignee

`@me` is the authenticated user. Use `--assignee @me` on create and `--add-assignee @me` on edit. Never hard-code a login.

## durable record

Post the record as an issue comment:

```sh
gh issue comment <n> --repo <owner>/<repo> --body-file <file>
```

`finish-pr` appends `<!-- pr-done-workflow:<full-head-sha> -->` to its comment and skips the post when `gh issue view <n> --json comments --jq '.comments[].body'` already contains that exact marker.

## long research

GitHub Projects has no document. Where the research exceeds roughly 6,000 characters, or will outlive the work, write it as a Markdown file in the repository under `docs/` on the task's branch, commit it with the first task commit, and link it from the parent body by repository path. Do not use a draft project item or a Gist.

## branch link

A branch name does not link an issue on GitHub. Create the branch through the issue so GitHub records the link:

```sh
gh issue develop <n> --repo <owner>/<repo> --checkout
```

Keep GitHub's default branch name, `<n>-<slugified-title>`, for example `42-fix-the-thing`. It starts with the number, so it never has the shape of a Linear issue key. For a cohort, create the branch from the parent. The CLI cannot link a branch that already exists, so when `implement-task` reuses a checked-out branch, the `Refs:` trailer and the `Closes` line carry the link, and the report says in one line that no linked branch was created. List links with `gh issue develop <n> --list`.

Each commit carries a `Refs: <owner>/<repo>#<n>` footer. `make-pr` writes `Closes #<n>` for a single task, or one `Closes` line per child for a cohort, as the last lines of the pull request body, so the merge closes the issue and the built-in workflow moves it to `Done`. In prose, write `#123` for an issue in the same repository and `owner/repo#123` elsewhere. GitHub links both, so neither takes a URL.

`finish-pr` collects issue numbers from the pull request's `closingIssuesReferences` (`gh pr view <n> --json closingIssuesReferences`) and from exact `Refs:` trailers on the resolved PR commits. Never scan prose for numbers.

## Limits

`gh project item-list` returns 30 items by default. Pass `--limit` and, where the project is large, `--query` with the project filter syntax, for example `--query 'status:"In progress" assignee:@me'`. A project holds up to 50,000 items. `item-edit` sets exactly one field per call and returns the item id. `field-create` can make only `TEXT`, `SINGLE_SELECT`, `DATE`, and `NUMBER` fields, and it is denied under Fence anyway, so a missing field is reported for the project owner to add.
