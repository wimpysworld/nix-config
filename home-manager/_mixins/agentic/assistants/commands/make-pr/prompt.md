## Make PR

Draft the pull request title and body with the inline contract below. Then create a pull request for the current branch. On a work repository, append a reviewer orientation block before creation. A work pull request also carries a review request for the work review team and the `ai-review` label.

Run the pull request creation flow in the current context. Do not launch a sub-agent or a Task for any step. The current context holds the change intent, validation results, and non-goals that the pull request message needs. The watch handover after successful creation is separate and may invoke `pr-watch` when the user selects it.

Load the `gh` skill before any GitHub access and follow its GitHub policy. This command mutates remote Git and GitHub state by pushing only when needed, running `gh pr create`, and repairing missing review metadata with `gh pr edit`, and it moves any linked Linear issue to In Review. Treat explicit human invocation of this command as consent for those actions.

### Pull request draft

Before drafting, load and follow the `communication-rules` and `contribution-voice` skills. If the platform cannot load a skill, apply this contract directly.

Draft from the committed changes already inspected in `main..HEAD` and the bounded history of `main`. Select one Conventional Commit type from the dominant change intent across the branch:

- `feat` for new user-facing behaviour.
- `fix` for correcting wrong behaviour, but not for behaviour-neutral cleanup.
- `refactor` for a code change with no behaviour change, including code comments.
- `perf` for a change whose purpose is performance.
- `docs` for documentation only, `test` for tests only, `ci` for CI configuration, `build` for dependencies or build tooling, and `style` for formatting only.
- `revert` for reverting an earlier commit. Use `chore` only when no more specific type applies.

Ask the user before drafting when the type is ambiguous between `fix` and `refactor`, when the bounded base history has no established scope convention, or when the scope of a breaking change is unclear. Proceed without asking for minor wording choices, footer formatting, issue reference formatting, or a cross-cutting change whose scope must be omitted.

Derive the scope from the repository's existing commit convention and the affected component. Use a directory or feature area that the project already uses. Omit the scope only when the change is cross-cutting.

Write the title as `<type>(<scope>): <imperative description>`, or `<type>: <imperative description>` when the scope is omitted. Use imperative mood, keep the title to 72 characters or fewer, and describe the branch's main effect.

Write a focused pull request body as prose, with one paragraph for what changes and why, followed by one validation sentence when validation was run. State only checks that this session verified. Omit validation when none ran. Use headings only when several independent concerns or a long commit series need navigation. Do not restate a single commit title, use bullet scaffolding, or hard-wrap body paragraphs.

Put each supported issue reference or `Refs: <ISSUE-KEY>` footer on its own line at the end. Include a breaking-change footer when the branch contains a breaking change. Do not invent or infer a reference that the branch does not support.

Produce the title, a blank line, the body, and any footers inside one fenced Markdown code block. The fenced block is the draft artefact. Preserve its content verbatim for the creation steps below, with no preamble or trailing commentary.

### Working tree handling

Use the branch's committed diff only. Do not stage, commit, or include unstaged files in the pull request title or body.

Treat unstaged overview, proposal, plan, alignment, validation, research, decision, handover, phase/task note, and files marked `working document, not for commit` as non-durable working documents. Leave them untouched and out of the pull request.

A pull request carries the branch's committed diff, so uncommitted work is out of scope. Report it as excluded rather than treating it as a blocker.

### Process

Run each command separately. Do not chain commands with `&&`, `;`, or `|`.

1. Inspect branch state with `git status --short --branch`, `git rev-parse --abbrev-ref HEAD`, `git log main..HEAD --oneline`, `git log main..HEAD --format=full`, `git log -20 main --oneline`, and `git diff main..HEAD --stat`.
2. Stop if the current branch is `main`, or if there are no commits in `main..HEAD`.
3. If staged files or unstaged files exist, leave them unchanged. Note that they are excluded because only committed branch changes are used.
4. Classify the repository once, following **Work repository classification** below. Reuse that one result for the reviewer orientation, the review metadata, and the Linear workspace guard.
5. Apply **Pull request draft** above. Preserve its fenced pull request message verbatim as the pull request source.
6. Strip only the Markdown fence lines. Use the first remaining line as the pull request title. Write the remaining body text unchanged to a temporary file.
7. Append the reviewer orientation block to that temporary file, following **Reviewer orientation** below. The block is part of the pull request from the moment it exists, so never add it later by editing the pull request.
8. Push with an explicit refspec: `git push origin <branch>`. A bare `git push` depends on tracking configuration that may be absent, and pushes nothing when it is. Never pass `-u`: a sandbox mounts `.git/config` read-only, so the upstream write fails after the push has already landed. Stop if the push requires force, deletion, tags, or a non-fast-forward update.
9. Verify the push landed. Run `git fetch origin <branch>`, then compare `git rev-parse HEAD` against `git rev-parse FETCH_HEAD`. Report a mismatch and stop rather than creating the pull request. Never trust the exit status alone: a push that matches nothing reports success while doing nothing.
10. Look for an existing pull request, following **Pull request lookup and verification** below.
11. On a work repository, resolve the owner with `gh repo view --json owner` and build the team handle, following **Work review metadata** below. Do this before the pull request is created or existing work metadata is repaired.
12. If no pull request exists, create one with the dedicated GitHub CLI command: `gh pr create --base main --head <branch> --title <title> --body-file <temp-file>`. On a work repository, add `--reviewer <owner>/fulfillment-automation-team-write` and `--label ai-review`.
13. Verify the pull request URL and title on every repository. On a work repository, also verify and repair the review metadata, following **Work review metadata** below. Never report success from `gh pr create` alone.
14. Move each linked Linear issue to In Review, following **Linear transition** below. A Linear failure never stops this command.
15. Report the verified pull request URL, title, whether the orientation block was included, the review metadata outcome on a work repository, each Linear outcome, and any uncommitted files left out.

### Work repository classification

Run `git config user.email`. An address on the `chainguard.dev` domain means work. Anything else means personal or community, including an empty address and a malformed one.

Classify once, at the step after branch inspection, and reuse that one result. The reviewer orientation, the review metadata, and the Linear workspace guard all read the same answer.

### Reviewer orientation

Work pull requests only, as decided in **Work repository classification** above. A personal or community pull request gets no block and no mention of one.

Append this block to the end of the body file:

```markdown
<details>
<summary>Reviewer orientation</summary>

**Why this change exists and why a reviewer should care, one line.**

- **Out of scope** - what it deliberately leaves alone, and links to the follow-on issues where they exist.
- **Verified** - what was run and what passed.
- **Tracking** - [<ISSUE-KEY>](<issue link>)

</details>
```

Filling it in:

- The first line is bold, carries no label, and says why the change exists, not what it does. The diff says what. Write what breaks or stays broken without it, so a reviewer knows why it is worth their time.
- Write orientation, not instructions. Never write a direction aimed at a reviewer or their tooling, such as what to look at or what to skip. Facts let a reviewer decide; instructions invite them to stop thinking.
- Summarise, never paste. A task written by `create-task` carries a `Non-goals` heading that maps onto `Out of scope`. Restate it in the reviewer's terms, one line. Never copy the issue body across.
- `Out of scope` names follow-on work only where a tracked issue exists. Link it the same way as `Tracking`. Say nothing where no follow-on is tracked.
- Control leaks. These pull requests land on repositories that may be public. Drop anything naming an internal system, a customer, a colleague, a roadmap item, or a dated plan. Omit any line that cannot be written without one of those. An omitted line is a clean outcome; a leaked one is not.
- Every issue is a link, and its text is the bare key. For Linear, write `[FUL-1](https://linear.app/<workspace>/issue/FUL-1)`: that URL resolves, while the slugged URL Linear hands you ends in the issue title and publishes it on a repository that may be public. Never paste a slugged Linear URL. For a GitHub issue in this repository write `#123`, and `owner/repo#123` for one elsewhere; GitHub links both itself, so neither takes a URL.
- Derive `Verified` from the branch's committed diff and what this session ran, not from the issue. Never claim a check that was not run.
- Omit an empty bullet. Never stub one with "N/A" or "None".
- Skip the whole block when the first line would restate the pull request title and no bullet adds anything. Noise trains reviewers to collapse it unread. Say in the report that it was skipped, and why.

### Pull request lookup and verification

These rules apply to work, personal, and community repositories.

- Before creation, run `gh pr view <branch> --json url,title`. If it returns a pull request, do not run `gh pr create`; use that object and continue with work metadata only on a work repository.
- Create a pull request only when the lookup unambiguously says that none exists. If authentication, network access, or another lookup failure makes the outcome unclear, report the failure and stop before creation.
- If `gh pr create` reports a failure, run `gh pr view <branch> --json url,title` before deciding what happened. If the pull request exists, never create it again. If none exists, stop on a personal or community repository; on a work repository, apply the bounded metadata retry below only when one reviewer or label argument caused the failure.
- After creation, discovery, and any work metadata repair, fetch the final object by URL. Run `gh pr view <url> --json url,title` on a personal or community repository. Add `labels,reviewRequests` to the fields on a work repository.
- Verify that the returned URL matches the created or discovered URL and that the title is present. For a newly created pull request, also verify that the returned title exactly matches the draft title. For an existing pull request, report its verified title unchanged, even when it differs from the new draft.
- If the URL or title cannot be verified, report the mismatch or lookup failure and do not report a successful pull request.

### Work review metadata

Work pull requests only, as decided in **Work repository classification** above. On a personal or community repository, run `gh pr create` with the existing arguments alone when creation is needed. Name no team and no label, look neither one up, and report neither one. Skip the rest of this section.

The review request and the label are repository metadata. Never write either into the pull request body. The reviewer orientation block stands on its own and does not change.

Resolving the team handle:

- Run `gh repo view --json owner` before creating the pull request, then build the handle `<owner>/fulfillment-automation-team-write`. Never hard-code an organisation, because a work repository may sit under more than one.
- Where the owner is a user account rather than an organisation, or the lookup fails, create the pull request without `--reviewer` and report the missing prerequisite. The label still applies.

Creating and checking work metadata:

- Create with `gh pr create --base main --head <branch> --title <title> --body-file <temp-file> --reviewer <owner>/fulfillment-automation-team-write --label ai-review`.
- Where `gh pr create` fails on the reviewer or the label, look for the pull request first with `gh pr view <branch> --json url,title`. Where one exists, the failure came after creation, so repair the field instead, following the repair rules below. Where none exists, retry `gh pr create` once with only the failing argument removed, then report the dropped argument and the reason. Never retry on a failure whose outcome is unclear until that lookup answers it.
- Verify the work metadata with the universal final lookup in **Pull request lookup and verification**. Never report success from `gh pr create` alone.
- The label matches when `ai-review` appears in `labels`. The review request matches when a `Team` entry in `reviewRequests` carries the `slug` `fulfillment-automation-team-write`. A team carries `name` and `slug` and never a `login`, so a match on `login` finds nothing and reports a false failure.
- Use dedicated `gh` subcommands only. Never call `gh api`.

Repairing one missing field:

- Where the pull request exists and a field is missing, discover the existing pull request with `gh pr view <branch> --json url,title`. Never run `gh pr create` again. A duplicate pull request is never created after an ambiguous partial success.
- Make one focused attempt for the missing field only, with `gh pr edit <url> --add-reviewer <owner>/fulfillment-automation-team-write` or `gh pr edit <url> --add-label ai-review`.
- Fetch the final object by URL with the fields in **Pull request lookup and verification**, then report the exact field that is still missing. Stop after that one attempt.
- A reviewer or label failure never rewrites the branch, force-pushes, closes the pull request, or rolls a Linear issue back. The pull request is the deliverable and it stays open.
- Never create the label, the team, a repository permission, or an organisation membership. Report the missing prerequisite and who must supply it.

Named failures, and what each one means:

- The `ai-review` label does not exist on the repository. Creation fails on `--label`. Retry without it, then report that an administrator must create the label.
- The team handle needs organisation qualification. A bare `fulfillment-automation-team-write` does not resolve, which is why the handle always carries the `<owner>/` prefix.
- The team is not visible to the authenticated account. The handle does not resolve. Report that the account needs to see the team, and never guess another handle.
- The team has no access to the repository. The request is refused. Report that an administrator must grant the team access to the repository.
- The token cannot request reviewers or apply labels. Creation fails on the argument, or the field comes back empty. Report the missing permission and the argument it blocked.
- The author is also in the requested team. GitHub may drop the author from the request, so `reviewRequests` can come back without the team after a call that succeeded. Report the request as made, name the author's membership as the reason, and never retry in a loop.
- The branch already has an open pull request. Creation fails. Discover that pull request, repair the missing field once, and report its URL.
- Creation succeeds but the metadata fails. Report the pull request as created, name the field that failed, and finish. The command still succeeded.
- `gh pr view` returns a different representation for the team. Where `reviewRequests` carries neither a matching `slug` nor a recognisable `Team` entry, report the field as unverified rather than failed, and print what came back.

### Linear transition

Two things link an issue, and nothing else does: the branch name, when it contains the issue key (a branch named `ful-123` links FUL-123), and a `Refs: <ISSUE-KEY>` trailer on any commit in `main..HEAD`. Never take a key from the pull request body or a commit subject. A key mentioned in prose is not a link.

Workspace guard: take the repository classification from **Work repository classification** above. The connected Linear instance is personal when the `WW` team, Wimpy's World, is visible, and work when `FUL` is visible. If the classification and the visible instance disagree, skip the transition and report one line saying the profile does not match the repository. Never touch a work issue from the personal workspace or the reverse.

Handle each linked issue on its own, and report each one. A branch may carry more than one `Refs:` trailer.

- Match the status by name. List the team's workflow statuses and take the `started`-type status named In Review. Linear's types are `triage`, `backlog`, `unstarted`, `started`, `completed`, and `cancelled`, and both In Progress and In Review are `started`, so the type alone cannot tell them apart. If the team has no `started`-type status named In Review, skip the issue and say so. Never invent a status and never create one.
- Move forward only. Leave the issue where it is when it is already In Review, when its type is `completed` or `cancelled`, or when its `started`-type status sits after In Review in the team's own order. Write only from `triage`, `backlog`, `unstarted`, or an earlier `started` status.

Never fatal. The pull request is the deliverable. If Linear is unreachable, a key does not resolve, the team has no In Review status, or the write fails, report it in one line and finish successfully. Never block, never retry in a loop, and never undo or amend anything because of a Linear failure.

### Output

Return this report to the user:

````markdown
Pull request: <url>
Title: <title>
Reviewer orientation: <included, or skipped and the reason>
Review requested: fulfillment-automation-team-write, applied or failed with reason
Label: ai-review, applied or failed with reason
Linear:
- <issue key and its new status, the reason it was skipped, or none>
Excluded:
- <uncommitted file left out, or none>
````

The `Review requested` and `Label` lines belong to a work pull request. Omit both lines on a personal or community repository, so that no work name reaches a report that is not a work report.

### Watch choice

If the report does not contain a verified pull request URL, finish after the report. Do not ask a question or offer a next action.

If the report contains a verified pull request URL, define `<watch-command>` with that URL. Codex uses `$pr-watch <url>`. Slash-command runtimes use `/pr-watch <url>`. Replace `<url>` and show only the matching form.

In an interactive session, use the available structured user-question tool to ask one single-select question after the report:

- Header: `Watch PR`
- Question: `Watch this pull request?`
- `Watch (Recommended)` - Run `<watch-command>` to monitor checks and reviews.
- `Stop here` - Finish after the report.

Use the verified URL from the report. Do not add an `Other` choice. The client can add its own free-text choice.

If the user selects `Watch (Recommended)`, invoke the provider-specific command and wait for it to finish. If the user selects `Stop here`, finish without another summary. Treat cancellation, silence, and any other answer as `Stop here`.

If no structured user-question tool is available in an interactive session, print the same question and choices with the provider-specific command, then wait.

In a non-interactive session, print `Next action: $pr-watch <url>` on Codex or `Next action: /pr-watch <url>` on a slash-command runtime, with the verified URL substituted. Then finish.
