## Make PR

Draft the pull request title and body with `draft-pr-message`, then create a pull request for the current branch. On a work repository, append a reviewer orientation block to the body before the pull request is created.

This command mutates remote Git and GitHub state by pushing only when needed and running `gh pr create`, and it moves any linked Linear issue to In Review. Treat explicit human invocation of this command as consent for those actions. Never use raw `gh api`.

Command invocation: use the current provider's command prefix when invoking `draft-pr-message`. Codex uses `$draft-pr-message`; slash-command runtimes use `/draft-pr-message`. If the platform cannot expand another command, follow the existing `draft-pr-message` prompt directly for the draft phase only. After its fenced message is produced, this command resumes and creates the pull request.

### Working tree handling

Use the branch's committed diff only. Do not stage, commit, or include unstaged files in the pull request title or body.

Treat unstaged overview, proposal, plan, alignment, validation, research, decision, handover, phase/task note, and files marked `working document, not for commit` as non-durable working documents. Leave them untouched and out of the pull request.

A pull request carries the branch's committed diff, so uncommitted work is out of scope. Report it as excluded rather than treating it as a blocker.

### Process

Run each command separately. Do not chain commands with `&&`, `;`, or `|`.

1. Inspect branch state with `git status --short --branch`, `git rev-parse --abbrev-ref HEAD`, `git log main..HEAD --oneline`, and `git diff main..HEAD --stat`.
2. Stop if the current branch is `main`, or if there are no commits in `main..HEAD`.
3. If staged files or unstaged files exist, leave them unchanged. Note that they are excluded because only committed branch changes are used.
4. Invoke or follow `draft-pr-message`. Preserve its fenced pull request message verbatim as the pull request source.
5. Strip only the Markdown fence lines. Use the first remaining line as the pull request title. Write the remaining body text unchanged to a temporary file.
6. Append the reviewer orientation block to that temporary file, following **Reviewer orientation** below. The block is part of the pull request from the moment it exists, so never add it later by editing the pull request.
7. Push with an explicit refspec: `git push -u origin <branch>`. A bare `git push` depends on tracking configuration that may be absent or unwritable, and pushes nothing when it is. Stop if the push requires force, deletion, tags, or a non-fast-forward update.
8. Verify the push landed. Run `git fetch origin <branch>`, then compare `git rev-parse HEAD` against `git rev-parse FETCH_HEAD`. Report a mismatch and stop rather than creating the pull request. Never trust the exit status alone: a failed `.git/config` write leaves a push reporting success while doing nothing.
9. Create the pull request with the dedicated GitHub CLI command: `gh pr create --base main --head <branch> --title <title> --body-file <temp-file>`. Never use raw `gh api`.
10. Move each linked Linear issue to In Review, following **Linear transition** below. A Linear failure never stops this command.
11. Report the pull request URL, title, whether the orientation block was included, each Linear outcome, and any uncommitted files left out.
12. Offer the watch handover, following **Watch handover** below. Print it after the report, as the last thing you say.

### Watch handover

This command runs in a sub-task on every platform, so it cannot put a question to the user itself. Never call an interactive question tool, and never invoke `pr-watch`. End with the offer and let the caller act on the answer.

Offer only when the pull request exists. Say nothing when this command stopped early or `gh pr create` failed: no offer, no empty section, no "nothing to watch here".

Fill in the URL so the command copies and runs as it stands, never leave a placeholder. Put it after the report, on its own, as the last thing in the response:

```markdown
**Watch this pull request?**

- **Yes** - run `pr-watch <url>`. It watches the checks, fixes the failures this pull request caused, triages flakes, and answers reviews.
- **No** - the pull request is open and nothing else happens.
```

The caller relays that offer and waits. On Yes it invokes `pr-watch <url>` with its own provider's command prefix. Anything else is a No. Never treat silence as consent.

### Reviewer orientation

Work pull requests only. Classify the repository from `git config user.email`, as in **Linear transition** below: an address on the `chainguard.dev` domain means work; anything else means personal or community. A personal or community pull request gets no block and no mention of one.

Append this block to the end of the body file:

```markdown
<details>
<summary>Reviewer orientation</summary>

**Outcome** - what this change achieves, one line.

**Scope** - what it touches.

**Out of scope** - what it deliberately leaves alone, and why.

**Worth attention** - the two or three places a defect would hurt most.

**Verified** - what was run and what passed.

**Tracking** - <ISSUE-KEY>

</details>
```

Filling it in:

- Write orientation, not instructions. State what the change does and where a defect would hurt. Never write a direction aimed at a reviewer or their tooling, such as what to look at or what to skip. Facts let a reviewer decide; instructions invite them to stop thinking.
- Summarise, never paste. A task written by `create-task` carries `Outcome`, `Scope`, and `Non-goals` headings that map onto the first three fields. Restate each one in the reviewer's terms, one line each. Never copy the issue body across.
- Control leaks. These pull requests land on repositories that may be public. Drop anything naming an internal system, a customer, a colleague, a roadmap item, or a dated plan. Omit any field that cannot be written without one of those. An omitted field is a clean outcome; a leaked one is not.
- `Tracking` is the bare issue key, never a URL. A Linear URL carries a title slug, so on a public repository the link publishes the issue title. The key alone is enough for a colleague to find it.
- Derive `Worth attention` and `Verified` from the branch's committed diff and what this session ran, not from the issue. Never claim a check that was not run.
- Omit an empty field. Never stub one with "N/A" or "None".
- Skip the whole block when every field would restate the title. Noise trains reviewers to collapse it unread. Say in the report that it was skipped, and why.

### Linear transition

Two things link an issue, and nothing else does: the branch name, when the branch came from Linear's `gitBranchName`, and a `Refs: <ISSUE-KEY>` trailer on any commit in `main..HEAD`. Never take a key from the pull request body or a commit subject. A key mentioned in prose is not a link.

Workspace guard: classify the repository from `git config user.email`. An address on the `chainguard.dev` domain means work; anything else means personal. The connected Linear instance is personal when the `WW` team, Wimpy's World, is visible, and work when `FUL` is visible. If the classification and the visible instance disagree, skip the transition and report one line saying the profile does not match the repository. Never touch a work issue from the personal workspace or the reverse.

Handle each linked issue on its own, and report each one. A branch may carry more than one `Refs:` trailer.

- Match the status by name. List the team's workflow statuses and take the `started`-type status named In Review. Linear's types are `triage`, `backlog`, `unstarted`, `started`, `completed`, and `cancelled`, and both In Progress and In Review are `started`, so the type alone cannot tell them apart. If the team has no `started`-type status named In Review, skip the issue and say so. Never invent a status and never create one.
- Move forward only. Leave the issue where it is when it is already In Review, when its type is `completed` or `cancelled`, or when its `started`-type status sits after In Review in the team's own order. Write only from `triage`, `backlog`, `unstarted`, or an earlier `started` status.

Never fatal. The pull request is the deliverable. If Linear is unreachable, a key does not resolve, the team has no In Review status, or the write fails, report it in one line and finish successfully. Never block, never retry in a loop, and never undo or amend anything because of a Linear failure.

### Output

The report, then the offer after it:

````markdown
Pull request: <url>
Title: <title>
Reviewer orientation: <included, or skipped and the reason>
Linear:
- <issue key and its new status, the reason it was skipped, or none>
Excluded:
- <uncommitted file left out, or none>

**Watch this pull request?**

- **Yes** - run `pr-watch <url>`. It watches the checks, fixes the failures this pull request caused, triages flakes, and answers reviews.
- **No** - the pull request is open and nothing else happens.
````