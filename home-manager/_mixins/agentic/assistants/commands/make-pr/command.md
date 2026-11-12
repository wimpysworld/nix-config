## Make PR

Draft the pull request title and body with the inline contract below. Then create a pull request for the current branch. On a work repository, open the body with a bold why line and append a reviewer orientation block, both before creation. A work pull request also carries a review request for the work review team and the `ai-review` label. A personal pull request carries a review request for `sith-skrye`, `sith-traya`, and `sith-zannah`.

Run the pull request creation flow in the current context. Do not launch a sub-agent or a Task for any creation step. The current context holds the change intent, validation results, and non-goals that the pull request message needs. Complete the babysitting handoff before the final response. That separate workflow retains the caller and its existing delegation authority.

Load the `gh` skill before any GitHub access and follow its GitHub policy. This command mutates remote Git and GitHub state by pushing only when needed, running `gh pr create`, and repairing missing review metadata with `gh pr edit`, and it moves any linked tracked issue, Linear or GitHub Project, to its in-review status. Treat explicit human invocation of this command as consent for those actions.

Invocation also authorises the bounded `babysit-pr` workflow through **Completion and babysitting** on recognised owned, managed, or Chainguard projects. Respect an explicit opt-out or later stop. Reading either command for maintenance does not invoke it or authorise remote actions.

### Pull request draft

Before drafting, ensure that this context contains the complete, current `communication-rules` and `contribution-voice` instructions. Read either skill whose instructions are missing, then apply both. If the platform cannot load a skill, apply this contract directly.

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

When **Pull request template** below finds a template, fill it instead of the prose body in this paragraph. When no template exists, write a focused pull request body as prose, with one paragraph for what changes and why, followed by one validation sentence when validation was run. State only checks that this session verified. Omit validation when none ran. Use headings only when several independent concerns or a long commit series need navigation. Do not restate a single commit title, use bullet scaffolding, or hard-wrap body paragraphs.

Put each supported issue reference or `Refs:` footer on its own line at the end, or in the template's linked-issue section, in the form the **Tracker transition** section below resolves. For a GitHub Project task, the last body lines are one `Closes #<n>` line per linked issue, so the merge closes it. Include a breaking-change footer when the branch contains a breaking change. Do not invent or infer a reference that the branch does not support.

Produce the title, a blank line, the body, and any footers inside one fenced Markdown code block. The fenced block is the draft artefact. Preserve its content verbatim for the creation steps below, with no preamble or trailing commentary.

### Pull request template

Load `contribution-templates` and apply it to `<base>` before drafting. It resolves the base repository, reads its pull request templates, selects one, and owns the fill rules. When it finds a template, that template replaces the prose body above. Prose inside each section still follows `communication-rules` and `contribution-voice`. When it reports a trap or an open question, stop before creation and return the question to the user or the parent.

On a community or unknown repository, load `how-to-contribute` and apply it to `<base>` before drafting. When `how-to-contribute` reports a pre-approval gate, required discussion, AI-contribution ban, or trap, report the policy and stop before pushing.

### Working tree handling

Use the branch's committed diff only. Do not stage, commit, or include unstaged files in the pull request title or body.

Treat unstaged overview, proposal, plan, alignment, validation, research, decision, handover, phase/task note, and files marked `working document, not for commit` as non-durable working documents. Leave them untouched and out of the pull request.

A pull request carries the branch's committed diff, so uncommitted work is out of scope. Report it as excluded rather than treating it as a blocker.

### Process

Run each command separately. Do not chain commands with `&&`, `;`, or `|`.

1. Inspect branch state with `git status --short --branch`, `git rev-parse --abbrev-ref HEAD`, `git log main..HEAD --oneline`, `git log main..HEAD --format=full`, `git log -20 main --oneline`, and `git diff main..HEAD --stat`.
2. Stop if the current branch is `main`, or if there are no commits in `main..HEAD`.
3. If staged files or unstaged files exist, leave them unchanged. Note that they are excluded because only committed branch changes are used.
4. Resolve `<base>`, `<default branch>`, and `<head>` with **Base and head** below. Classify the repository with **Repository classification** below. Reuse those values for the contribution gate, orientation, review metadata, Linear guard, and pull request lookup and creation. Resolve linked issues and their tracker with **Tracker transition** below for the draft footers. Apply **Pull request template** above.
5. Apply **Pull request draft** above. Preserve its fenced pull request message verbatim as the pull request source.
6. Strip only the Markdown fence lines. Use the first remaining line as the pull request title. Write the remaining body text unchanged to a temporary file.
7. On a work repository, insert the bold why line and append the orientation block with **Reviewer orientation** below. When a template applies, place both inside its summary or description section, as `contribution-templates` describes. Both belong in the initial pull request, so never add either later by editing the pull request.
8. Push with an explicit refspec: `git push origin <branch>`. A bare `git push` depends on tracking configuration that may be absent, and pushes nothing when it is. Never pass `-u`: a sandbox mounts `.git/config` read-only, so the upstream write fails after the push has already landed. Stop if the push requires force, deletion, tags, or a non-fast-forward update.
9. Verify the push landed. Run `git fetch origin <branch>`, then compare `git rev-parse HEAD` against `git rev-parse FETCH_HEAD`. Report a mismatch and stop rather than creating the pull request. Never trust the exit status alone: a push that matches nothing reports success while doing nothing.
10. Look for an existing pull request with `<base>` and `<head>`, following **Pull request lookup and verification** below.
11. On a work repository, resolve the owner with `gh repo view <base> --json owner` and build the team handle. Do this before creating the pull request or repairing existing work metadata.
12. If no pull request exists, create one with `gh pr create --repo <base> --base <default branch> --head <head> --title <title> --body-file <temp-file>`. On a work repository, add `--reviewer <owner>/fulfillment-automation-team-write` and `--label ai-review`. On a personal repository, add `--reviewer sith-skrye,sith-traya,sith-zannah`.
13. Verify the pull request URL and title on every repository. On a work or personal repository, verify and repair the review metadata with **Review metadata** below. Never report success from `gh pr create` alone.
14. Move each linked issue to the `in review` role, following **Tracker transition** below. A tracker failure never stops this command.
15. Prepare the **Output** report. Retain metadata and tracker failures as report entries, not early exits.
16. Apply **Completion and babysitting**, including any ownership question, before the final response. Follow the authorised babysitting workflow and wait for its result or stated stopping condition.
17. Return the prepared report and the babysitting outcome, skipped reason, or pending ownership decision.

### Base and head

Resolve these values once at Step 4, and reuse them for classification, the contribution gate, lookup, and creation:

- Run `gh repo view --json nameWithOwner,isFork,parent,owner` on the origin.
- `<base>` is `nameWithOwner`. When `isFork` is true, `<base>` is `<parent.owner.login>/<parent.name>`, the repository that receives the pull request.
- `<default branch>` comes from `gh repo view <base> --json defaultBranchRef`. Never assume `main`.
- `<head>` is `<owner.login>:<branch>`, so that a fork branch resolves against the base repository.

### Repository classification

This section is the shared policy for `make-pr` and `babysit-pr`. Classify the verified receiving repository, not the fork or local checkout. Match exact GitHub owner logins case-insensitively:

- `personal`: `wimpysworld`, `Oval-Tutu`, `noughtylinux`, `quickemu-project`, or `linuxmatters`.
- `work`: `chainguard-dev`.
- `community`: the user or trusted project instructions explicitly identify this destination as a third-party contribution.
- `unknown`: none of the above, or the evidence conflicts.

An explicit user classification for this destination takes precedence. A confirmed owned or managed project is `personal`, and confirmed Chainguard work is `work`. Record the evidence and its scope. Do not extend one repository's answer to its whole organisation or change this allowlist during execution.

Email, checkout location, fork ownership, write access, organisation membership, and a similar owner name do not establish ownership. An unlisted owner is unknown, not automatically third-party.

Reuse the classification for the contribution gate, orientation, review metadata, Linear workspace guard, and babysitting decision. Until resolved, handle `unknown` like `community` for templates, contribution checks, lookup, and review metadata. Skip Linear writes when the workspace classification is unknown. Do not infer automatic babysitting eligibility from that conservative handling.

### Reviewer orientation

Work pull requests only, as decided in **Repository classification** above. A personal or community pull request gets no block and no mention of one.

Insert the why line as the first line of the body file, followed by a blank line, so the benefit reads before anything else:

```markdown
**Why this change exists and why a reviewer should care, one line.**
```

Append this block to the end of the body file:

```markdown
<details>
<summary>Reviewer orientation</summary>

- **Out of scope** - what it deliberately leaves alone, and links to the follow-on issues where they exist.
- **Verified** - what was run and what passed.
- **Tracking** - [<ISSUE-KEY>](<issue link>)

</details>
```

Filling it in:

- The why line is bold, carries no label, and says why the change exists, not what it does. The diff says what. Write what breaks or stays broken without it, so a reviewer knows why it is worth their time.
- Write orientation, not instructions. Never write a direction aimed at a reviewer or their tooling, such as what to look at or what to skip. Facts let a reviewer decide; instructions invite them to stop thinking.
- Summarise, never paste. A task written by `create-task` carries a `Non-goals` heading that maps onto `Out of scope`. Restate it in the reviewer's terms, one line. Never copy the issue body across.
- `Out of scope` names follow-on work only where a tracked issue exists. Link it the same way as `Tracking`. Say nothing where no follow-on is tracked.
- Control leaks. These pull requests land on repositories that may be public. Drop anything naming an internal system, a customer, a colleague, a roadmap item, or a dated plan. Omit any line that cannot be written without one of those. An omitted line is a clean outcome; a leaked one is not.
- Every issue is a link, and its text is the bare key. For Linear, write `[FUL-1](https://linear.app/<workspace>/issue/FUL-1)`: that URL resolves, while the slugged URL Linear hands you ends in the issue title and publishes it on a repository that may be public. Never paste a slugged Linear URL. For a GitHub issue in this repository write `#123`, and `owner/repo#123` for one elsewhere; GitHub links both itself, so neither takes a URL.
- Derive `Verified` from the branch's committed diff and what this session ran, not from the issue. Never claim a check that was not run.
- Omit an empty bullet. Never stub one with "N/A" or "None".
- Omit the why line when it would only restate the pull request title. Skip the details block when no bullet adds anything; noise trains reviewers to collapse it unread. Say in the report what was skipped, and why.

### Pull request lookup and verification

These rules apply to work, personal, and community repositories.

Before any mutation of a discovered pull request, fetch `author,headRepository,headRepositoryOwner,headRefName,baseRefName,state,isDraft,url` with `gh pr view`. Verify the authenticated user through `gh-api-safe user --jq .login`. Match the author to that user, the head repository and branch to the intended origin and branch, and the URL's base repository to `<base>`. Require an open pull request. An existing non-default base branch is valid when it matches the intended target. Report a mismatch and stop without changing that pull request. Record draft status without changing it. A valid existing draft can complete creation reporting but cannot enter babysitting.

- Before creation, run `gh pr view <head> --repo <base> --json url,title,reviewRequests,reviews`. If it returns a pull request, do not run `gh pr create`. Use that pull request and continue with **Review metadata** on a work or personal repository.
- Create a pull request only when the lookup unambiguously says that none exists. If authentication, network access, or another lookup failure makes the outcome unclear, report the failure and stop before creation.
- If `gh pr create` fails, run `gh pr view <head> --repo <base> --json url,title` first. If the pull request exists, never create it again. If none exists, stop on a community repository. On a work or personal repository, apply the retry in **Review metadata** only when a reviewer or label failed.
- After creation, discovery, and any metadata repair, fetch the final pull request by URL. Run `gh pr view <url> --json url,title` on a community repository. Run `gh pr view <url> --json url,title,reviewRequests,reviews` on a personal repository, and `gh pr view <url> --json url,title,labels,reviewRequests` on a work repository.
- Verify that the returned URL matches the created or discovered URL and that the title is present. For a newly created pull request, also verify that the returned title exactly matches the draft title. For an existing pull request, report its verified title unchanged, even when it differs from the new draft.
- If the URL or title cannot be verified, report the mismatch or lookup failure and do not report a successful pull request.

### Review metadata

Work and personal pull requests only, as decided in **Repository classification** above. On a community repository, run `gh pr create` with the base arguments alone when creation is needed. Name no reviewer and no label, look neither one up, and report neither one. Skip the rest of this section.

The review request and the label are repository metadata. Never write either into the pull request body. The why line and the reviewer orientation block on a work pull request stand on their own and do not change.

Resolving the work team handle:

- On a work repository, run `gh repo view <base> --json owner` before creating the pull request, then build the handle `<owner>/fulfillment-automation-team-write`. Never hard-code an organisation, because a work repository can sit under more than one.
- Where the owner is a user account rather than an organisation, or the lookup fails, create the pull request without `--reviewer` and report the missing prerequisite. The label still applies.

Creating and checking review metadata:

- On a work repository, create with `gh pr create --repo <base> --base <default branch> --head <head> --title <title> --body-file <temp-file> --reviewer <owner>/fulfillment-automation-team-write --label ai-review`.
- On a personal repository, create with `gh pr create --repo <base> --base <default branch> --head <head> --title <title> --body-file <temp-file> --reviewer sith-skrye,sith-traya,sith-zannah`. Never pass `--label ai-review` on a personal repository.
- When `gh pr create` fails on `--reviewer` or `--label`, check `gh pr view <head> --repo <base> --json url,title` first. Never retry while the outcome is unclear.
- On a work repository, when no pull request exists, retry `gh pr create` once without the failing argument. Report the dropped argument and the reason. When the pull request exists, repair the missing field once with the repair rules below.
- On a personal repository, when no pull request exists after a `--reviewer` failure, retry `gh pr create` once without `--reviewer`. Then repair each missing reviewer individually with `gh pr edit <url> --add-reviewer <login>` for `sith-skrye`, `sith-traya`, and `sith-zannah`. One failing account does not block the other two.
- Verify the review metadata with the universal final lookup in **Pull request lookup and verification**. Never report success from `gh pr create` alone.
- On a work repository, the label matches when `ai-review` appears in `labels`. The team review request matches when a `Team` entry in `reviewRequests` carries the `slug` `fulfillment-automation-team-write`. A team carries `name` and `slug` and never a `login`, so a match on `login` finds nothing and reports a false failure.
- On a personal repository, a user review request matches when a `User` entry in `reviewRequests` or an `author` in `reviews` has `login` equal to `sith-skrye`, `sith-traya`, or `sith-zannah`.
- Use dedicated `gh` subcommands only. Never call `gh api`.

Repairing missing metadata:

- Where the pull request exists and metadata is missing, discover the existing pull request with `gh pr view <head> --repo <base> --json url,title,reviewRequests,reviews`. Never run `gh pr create` again. A duplicate pull request is never created after an ambiguous partial success.
- On a work repository, run one repair for the missing field: `gh pr edit <url> --add-reviewer <owner>/fulfillment-automation-team-write` or `gh pr edit <url> --add-label ai-review`.
- On a personal repository, run one `gh pr edit <url> --add-reviewer <login>` command for each missing reviewer among `sith-skrye`, `sith-traya`, and `sith-zannah` that did not already review the pull request.
- Fetch the final object by URL with the fields in **Pull request lookup and verification**, then record the exact reviewer or label that is still missing. End repairs after that one pass, then continue to completion.
- A reviewer or label failure never rewrites the branch, force-pushes, closes the pull request, or rolls a Linear issue back. The pull request is the deliverable and it stays open.
- Never create the label, the team, a repository permission, or an organisation membership. Report the missing prerequisite and who must supply it.

Named failures, and what each one means:

- The `ai-review` label does not exist on the repository. Creation fails on `--label`. Retry without it, then report that an administrator must create the label.
- The team handle needs organisation qualification. A bare `fulfillment-automation-team-write` does not resolve, which is why the handle always carries the `<owner>/` prefix.
- The team is not visible to the authenticated account. The handle does not resolve. Report that the account needs to see the team, and never guess another handle.
- The team has no access to the repository. The request is refused. Report that an administrator must grant the team access to the repository.
- A personal reviewer account lacks access to the repository. When `gh pr edit <url> --add-reviewer <login>` fails for one account, report that account and the reason. Keep the other requested reviewers.
- The token cannot request reviewers or apply labels. Creation fails on the argument, or the field comes back empty. Report the missing permission and the argument it blocked.
- The author is also in the requested team. GitHub may drop the author from the request, so `reviewRequests` can come back without the team after a call that succeeded. Report the request as made, name the author's membership as the reason, and never retry in a loop.
- The branch already has an open pull request. Creation fails. Discover that pull request, repair any missing metadata once, and report its URL. When an agent already reviewed an existing personal pull request, GitHub removes that login from `reviewRequests` and keeps it in `reviews`. Report the remaining `reviewRequests` entries and any repair failure without retrying in a loop.
- Creation succeeds but the metadata fails. Record the pull request as created and name the failed field. Continue to completion and babysitting.
- `gh pr view` returns a different representation for the team. Where `reviewRequests` carries neither a matching `slug` nor a recognisable `Team` entry, report the field as unverified rather than failed, and print what came back.

### Tracker transition

Load the `task-tracker` skill. Two things link an issue, and nothing else does: an issue-key token in the branch name, and a `Refs:` trailer on any commit in `main..HEAD`. Resolve each hit's tracker by the shape rules in the skill, then read that tracker's reference. Its `branch link` section says which tokens count and what the trailer and the pull request body must carry. Never take a key from the pull request body or a commit subject. A key mentioned in prose is not a link.

Workspace guard, Linear only: take the repository classification from **Repository classification** above and apply the guard in the Linear reference's `Identity and lookup` section. `work` requires the work Linear workspace, and `personal` or `community` requires the personal Linear workspace. If the classification and the visible instance disagree, skip the transition and report one line saying that the profile does not match the repository.

Handle each linked issue on its own, and report each one. A branch may carry more than one `Refs:` trailer, and a cohort may span more than one tracker.

- Move the issue to the `in review` role as the reference describes. Never invent a status and never create one.
- Move forward only. The reference says which states are already at or past `in review`. Leave the issue where it is in those states.

Never fatal. The pull request is the deliverable. If the tracker is unreachable, a key does not resolve, the role has no status, or the write fails, record one line. Continue to completion and babysitting. Never block, retry in a loop, undo, or amend anything because of a tracker failure.

### Output

Prepare this report, then return it after **Completion and babysitting**:

````markdown
Pull request: <url>
Title: <title>
Template: <base repository and template file name, or none>
Reviewer orientation: <why line and block included, or what was skipped and the reason>
Review requested: <fulfillment-automation-team-write on work, or sith-skrye, sith-traya, sith-zannah on personal, applied or failed with reason>
Label: ai-review, applied or failed with reason
Tracker:
- <issue key or reference and its new status, the reason it was skipped, or none>
Excluded:
- <uncommitted file left out, or none>
````

Match the review metadata lines to the repository classification:

- On `work`, include `Review requested: fulfillment-automation-team-write, applied or failed with reason` and `Label: ai-review, applied or failed with reason`.
- On `personal`, include `Review requested: sith-skrye, sith-traya, sith-zannah, applied or failed with reason` and omit `Label`.
- On `community` or `unknown`, omit both `Review requested` and `Label`.

### Completion and babysitting

If no pull request URL is verified, report the failure without a babysitting question or next action.

For a verified URL, apply these decisions in order:

1. Honour an explicit opt-out, decline, cancellation, or stop. Report that babysitting was skipped.
2. On `community`, finish with the pull request report. Do not offer babysitting or print a babysitting next action.
3. On `personal` or `work`, continue automatically. Do not ask another permission question.
4. On `unknown`, ask the ownership question below before completing the response. Do not silently classify it as third-party.

Use an available structured question tool, including Pi's questionnaire when available. Ask one single-select question:

- Header: `PR ownership`
- Question: `Is <base> your own or managed project, Chainguard work, or a third-party contribution?`
- `Own or managed` - Classify this repository as personal and start babysitting this pull request.
- `Chainguard work` - Classify this repository as work and start babysitting this pull request.
- `Third-party` - Report the pull request without babysitting.

Replace `<base>` with the verified receiving repository. Do not add an `Other` choice. Honour a free-text stop or opt-out. If no structured tool is available, ask the exact question directly, with the same choices and effects. Await the answer before dependent work. Silence, a timeout, an unavailable interaction channel, or an ambiguous answer supplies neither classification nor consent. In a non-interactive run, report the verified pull request and `Babysitting pending: ownership of <base> is unknown`. Require that classification when resuming.

For an authorised handoff, resolve and read the complete `babysit-pr` workflow from the configured command or skill roots, or repository command source. Codex uses its command-derived `SKILL.md`, Claude Code and OpenCode their command Markdown, and Pi its prompt template. Follow the body in this caller's context, without generated launch wrappers. A printed `$babysit-pr` or `/babysit-pr` token does not execute the workflow.

Pass the exact PR URL, verified base and head identities, classification and evidence, user preferences, and this invocation's authority. That authority covers only the actions listed in `babysit-pr`'s **Authority**, subject to its preconditions and prohibitions. Do not merge, close, approve, release, force-push, dispatch workflows, or mutate another author's pull request. A worker retains its role and returns any required coordination to its parent.

Recheck the babysitting preconditions before mutations. A dirty tree, draft, identity mismatch, signing failure, or other precondition failure skips babysitting with a reason. Preserve the successful creation result and excluded files. Never clean, stash, commit excluded work, or mark a draft ready to enable the handoff.

Wait for the workflow's result, bounded stopping condition, or user stop. Return the creation report with its outcome and any required resume action. If the body cannot be loaded, report that blocker, not a completed handoff. Use `$babysit-pr <url>` on Codex and `/babysit-pr <url>` on slash-command runtimes only for user-facing resume instructions.
