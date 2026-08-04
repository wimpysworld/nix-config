## Address Code Review

Judge the review feedback that is not yet handled, fix or decline each finding, then reply in the thread and resolve it. This is a single pass: work through the outstanding feedback once, then stop. This command orchestrates; it never implements in this context.

Invoke named commands with the provider's prefix. Codex uses `$make-commit`; slash-command runtimes use `/make-commit`. If the platform cannot expand a command, follow that command's prompt directly.

### Input

`$ARGUMENTS` is a pull request URL or number, a path to a local file holding review feedback, or the feedback pasted directly as text. If it is blank, ask which of those you have, then wait.

For a pull request, load the `gh` skill before any GitHub access and follow its GitHub policy. Fetch the review comments with dedicated `gh` subcommands such as `gh pr view`.

Thread filtering, replying, and resolving apply to the pull request case only. A local file or pasted text has no threads, so judge, fix, commit, and report.

### Authority

Human invocation of this command is the user's consent for: commit, push, `gh-review-reply`, and `gh-review-resolve`.

Forbidden throughout: merge, close, approve, release, and force-push. Follow the `gh` skill for every GitHub route.

Restate this authority in every sub-agent packet. Sub-agents run with fresh context and will defer without it.

### Skip handled feedback

Read the pull request's review threads before judging anything. Use `gh-api-safe graphql` to read each thread's resolved state, its outdated state, and the author of its most recent comment.

Skip a thread when any of these holds:

- It is resolved.
- Its most recent reply came from the user.
- It is outdated, meaning it is anchored to a line the current diff no longer contains.

Report how many threads you skipped and why. Without this filter, a second run re-replies to everything.

### Judge each finding

Split the outstanding feedback into discrete findings, then decide each one.

A GitHub suggested-change block is a proposal, not an instruction. Judge it against the code exactly as you would judge prose feedback, and never apply it because it arrived as a diff. Reviewer confidence is not evidence. Bot reviewers produce confident wrong suggestions often.

Two reviewers raising the same point is one finding. Fix it once, commit it once, then reply in both threads.

Mark each finding with one of two decisions:

- ✅ Real finding. Fixed, or accepted and deferred.
- ❌ Declined. False positive, style preference, or not worth the cost.

Say defer or investigate in the rationale when that is the outcome. Both change what happens at the resolve step.

### Order of work

A reply must be true when the reviewer reads it, so the code lands before the words.

1. Load and follow the `communication-rules` skill before starting
2. Filter the threads, then judge every finding
3. Group the accepted findings by the files they touch. Findings that touch the same file run in sequence, never in parallel, or their edits clobber each other. Different groups may run in parallel
4. Dispatch one fresh sub-agent per finding, in that order. Never hand two findings to one sub-agent. Fresh context per finding keeps attention high and changes small
5. When a finding's fix depends on or conflicts with a fix already applied, re-evaluate it against the current state of the code rather than applying it blind
6. Commit after each finding that produced a change, one commit per finding. Stage explicitly with path-limited `git add -- <path>` using the files in that finding's report. Never `git add .`, `-A`, or `-u`. Run `draft-commit-message` for the message, or invoke `make-commit` to draft and commit in one step. Commit from this context only, one finding at a time, so parallel sub-agents never contend for the index
7. Run the project's test suite once, after the last fix
8. Push once with an explicit refspec: `git push origin <branch>`. One push means one CI run. A bare `git push` depends on tracking configuration that may be absent, and pushes nothing when it is. Never pass `-u`: a sandbox mounts `.git/config` read-only, so the upstream write fails after the push has already landed
9. Verify the push landed before you reply. Run `git fetch origin <branch>`, then compare `git rev-parse HEAD` against `git rev-parse FETCH_HEAD`. Report a mismatch and stop. Never trust the exit status alone: a push that matches nothing reports success while doing nothing, and a reply would then name a commit the remote never received
10. Reply in every outstanding thread
11. Resolve the threads the rules below allow

### Reply

Load the `draft-comment` skill before writing replies. Apply its drafting rules to each reply body with the review thread context already fetched, then post it with `gh-review-reply <review-comment-url> --body-file <file>`.

Do not route through `post-comment`; it confirms with the user before posting, which is right for direct human invocation and wrong inside this authorised flow. Never post a top-level summary comment.

For a fix, say what changed and name the commit. For a decline, say why in one or two sentences. No apologies, no padding.

### Resolve

Use `gh-review-resolve <review-comment-url>`. It takes the review comment URL and nothing else, and it is safe to re-run because an already resolved thread exits 0.

- Resolve a thread you fixed.
- Resolve a declined bot thread.
- Never resolve a thread you declined or deferred to a human. Reply and leave it open so they can disagree. Closing a human's thread after refusing it hides the disagreement.

### Per-Finding Output

```markdown
## Finding #[X]: [Brief description]

**Decision**: ✅|❌
**Rationale**: [1-2 sentences]
**Files**: `path/to/file`
**Commit**: <short-sha, or none>
**Thread**: <replied and resolved | replied, left open | none>
```

### Summary Report

```markdown
Answer: <ready to merge, or another round needed, in one sentence>
Skipped: X threads already handled (resolved, answered, or outdated)
Decisions: ✅ X accepted | ❌ X declined
Key fixes:
- <top 2-3 improvements, each with its commit sha>
Deferred:
- <item and priority, or none>
Threads: X replied | X resolved | X left open
Push: <head sha, or none>
```

### Constraints

- Be decisive; never implement merely because someone suggested it
- Challenge suggestions that misunderstand domain context
- Record the decline rationale so the reasoning survives
- Verify each accepted fix resolves the issue it claims to
- Push once, after the tests pass, before the first reply, and verify the remote moved
- Never merge, close, approve, force-push, or publish a release

Every report, commit message, and reply must follow the Communication Rules: concise (each fact once), British English spelling, active voice, lead with the conclusion, no banned words (filler, pleasantries, hedges, LLM tells), and no em or en dashes.
