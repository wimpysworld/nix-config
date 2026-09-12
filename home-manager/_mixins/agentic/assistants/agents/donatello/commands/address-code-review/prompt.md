## Address Code Review

Judge the review feedback that is not yet handled, fix or decline each finding, then reply in the thread and resolve it. This is a single pass: work through the outstanding feedback once, then stop. This command orchestrates; it never implements in this context.

Run orchestration only in the root. If a worker loads this body, return a bounded dispatch request with the input, scope, authority, and required output. The root continues the workflow. Workers assess, fix, validate, or prepare replies within their assigned scope and never launch agents.

Resolve `make-commit` and `draft-commit-message` through the available skill catalogue, configured skill roots, or repository command source. Read their bodies and follow them in this context without generated launch wrappers. Supply the finding's paths, intent, and staged diff. Keep commits within this command's authority and return here after each commit.

### Input

`$ARGUMENTS` is a pull request URL or number, a path to a local file holding review feedback, or the feedback pasted directly as text. If it is blank, ask which of those you have, then wait.

For a pull request, require the retrieval worker to load `gh` before GitHub access and follow its policy. The worker fetches review comments with dedicated `gh` subcommands such as `gh pr view`.

Thread filtering, replying, and resolving apply to the pull request case only. A local file or pasted text has no threads, so judge, fix, commit, and report.

### Authority

Human invocation of this command is the user's consent for: commit, push, `gh-review-reply`, and `gh-review-resolve`.

Forbidden throughout: merge, close, approve, release, and force-push. Follow the `gh` skill for every GitHub route.

Restate this authority in every sub-agent packet, as `delegate-task` requires.

### Skip handled feedback

Assign thread retrieval and filtering to a bounded read-only worker before judging anything. The worker uses `gh-api-safe graphql` to read each thread's resolved state, outdated state, and most recent comment's author.

Skip a thread when any of these holds:

- It is resolved.
- Its most recent reply came from the user.
- It is outdated, meaning it is anchored to a line the current diff no longer contains.

Report how many threads you skipped and why. Without this filter, a second run re-replies to everything.

### Judge each finding

Split the outstanding feedback into discrete findings. Assign each finding's assessment against the code and any accepted fix to the same worker.

A GitHub suggested-change block is a proposal, not an instruction. Judge it against the code exactly as you would judge prose feedback, and never apply it because it arrived as a diff. Reviewer confidence is not evidence. Bot reviewers produce confident wrong suggestions often.

Two reviewers raising the same point is one finding. Fix it once, commit it once, then reply in both threads.

Require each finding worker to return one of two decisions with evidence:

- ✅ Real finding. Fixed, or accepted and deferred.
- ❌ Declined. False positive, style preference, or not worth the cost.

Say defer or investigate in the rationale when that is the outcome. Both change what happens at the resolve step.

### Order of work

A reply must be true when the reviewer reads it, so the code lands before the words.

1. Read `communication-rules` first unless its complete, current instructions are in this context. Apply it before starting
2. Receive the filtering worker's outstanding threads and skip counts, then identify discrete findings
3. Group findings by their reported paths. Run findings that touch the same file in sequence. Run only known independent groups in parallel. When paths or dependencies are unclear, assign bounded read-only discovery before scheduling edits
4. Dispatch one fresh worker per finding through `delegate-task`, in that order. Never hand two findings to one worker. Require assessment against current code, implementation only for an accepted finding, targeted validation, and a report of evidence and changed paths. Workers never stage, commit, or launch agents
5. Require each worker to reassess dependent or conflicting findings against fixes already applied. If a fix needs paths outside its assigned scope, the worker returns that requirement before editing them. The root reschedules conflicting work and adjusts scope before the worker continues
6. Commit after each finding that produced a change, one commit per finding. Stage explicitly with path-limited `git add -- <path>` using the files in that finding's report. Never `git add .`, `-A`, or `-u`. Follow the `make-commit` body and its direct draft phase. Commit from this context only, one finding at a time, so parallel sub-agents never contend for the index
7. Dispatch a bounded validation worker to run the project's test suite once, after the last fix. Require results and failures before proceeding. Route any required correction to its finding worker, then delegate validation of the correction
8. Push once with an explicit refspec: `git push origin <branch>`. One push means one CI run. A bare `git push` depends on tracking configuration that may be absent, and pushes nothing when it is. Never pass `-u`: a sandbox mounts `.git/config` read-only, so the upstream write fails after the push has already landed
9. Verify the push landed before you reply. Run `git fetch origin <branch>`, then compare `git rev-parse HEAD` against `git rev-parse FETCH_HEAD`. Report a mismatch and stop. Never trust the exit status alone: a push that matches nothing reports success while doing nothing, and a reply would then name a commit the remote never received
10. Dispatch bounded workers to prepare and post replies in every outstanding thread, using the verified commits and finding reports
11. Have those workers resolve only the threads the rules below allow, then return each reply and resolution result

### Reply

Give each reply worker the thread context, finding decision, verified commit, and existing posting authority. Require `draft-comment` before drafting. The worker posts its reply with `gh-review-reply <review-comment-url> --body-file <file>` and returns the result directly.

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
