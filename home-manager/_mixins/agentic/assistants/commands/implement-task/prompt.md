## Implement Task

Take an agreed task through to implemented, validated, committed work. This command orchestrates; it never implements.

Input: `$ARGUMENTS` is a Linear issue key or URL, or a path to a local task file. If blank, stop and ask for one, then wait. Once the task is resolved, ask nothing further and run to completion.

Command invocation: use the current provider's command prefix. Codex uses `$command`; slash-command runtimes use `/command`. The steps below name commands without a prefix.

### Process

**1. Resolve the task.** For a Linear key or URL, read the issue, its `gitBranchName`, and its sub-issues. For a path, read the file. Decide whether it is a single task or a parent wrapping children.

**2. Order the work.** For a parent, take the run order from its `Child issues` list. Run children in parallel only where that list says they are independent. A single task is its own order of one.

**3. Open one branch for the whole piece of work.** Use the Linear `gitBranchName`, or the parent's for a cohort. For a local task, derive a kebab-case name from the task title. Linear keys its auto-close on the branch name when the pull request is eventually merged, so the name must match exactly.

For a Linear task, once the branch exists, assign the issue to the user and move it to the team's in-progress status. For a cohort, do this to the parent here; each child is claimed in step 4 as its turn comes. Resolve both values at run time: take the user from the authenticated Linear identity, and take the status from the team's live workflow states by picking the one whose type is started. Never hard-code an identifier or a status name.

**4. Spawn a fresh sub-agent per task.** Before spawning, claim the task: for a Linear issue, assign it to the user and move it to the in-progress status resolved in step 3. Claim each task at its own start, not the whole cohort up front, so the board shows what is running now. Never implement a task in this context. Never hand two tasks to one sub-agent. Fresh context per task and per phase keeps attention high and implementations small. Give each sub-agent its own task body and this instruction set:

1. Run `create-plan ${TMPDIR:-/tmp}/agent-plans/<key>-<slug>/plan.md`, where `<key>` is the Linear issue key or the task file stem, and `<slug>` is a short kebab-case title. The plan is ephemeral, lives outside the repo, and is discarded at the end.
2. Run `implement-plan <plan path>`. It spawns its own fresh sub-agent per phase.
3. Validate the changed files against the task's `Acceptance criteria` and `Scope`. Fix required gaps and revalidate until it passes or a real blocker remains.
4. Resolve any open question or decision the task or plan carries with bounded research, then continue. When evidence still conflicts after research, take the conservative path that best fits existing patterns and record why.
5. After validation passes, run `align-documentation <changed files>` where the change requires documentation. If prompt, command, skill, assistant, or project instruction artefacts changed, run the matching Rosey workflow: `update-command`, `update-skill`, `update-assistant`, or `update-agents-md`.
6. Write the durable record: what was built, each decision with its reason, how each acceptance criterion was met, and any risk carried forward. State the work as built, not the plan to build it. Load the `contribution-voice` skill and follow it before writing; the record publishes under the user's name. Post it as a comment on the Linear issue, or append it to the local task file.
7. Return a short report only: task key or path, pass or fail, changed files, tests, blockers. No phase-level detail.

If the platform cannot expand a command from inside this command, do the same work directly and keep both splits: one fresh sub-agent per task, one per phase.

**5. Commit each task as it lands.** One commit per task, after its validation passes. Stage explicitly with path-limited `git add -- <path>` using the files in that task's report. Never `git add .`, `-A`, or `-u`. Run `draft-commit-message`, then add a `Refs: <ISSUE-KEY>` footer for a Linear task. Commit from this context only, one task at a time in the parent's order, so parallel sub-agents never contend for the index.

**6. Stop after the final commit.** Do not push. Do not open a pull request and do not draft a pull request body; the user runs `make-pr` manually.

### Constraints

- The plan never enters the repo and is never committed. Delete its directory once the task's commit lands.
- Leave every issue at the in-progress status after its commit lands. This command stops before the pull request, so nothing is reviewable or done yet. `make-pr` and the merge carry the status forward.
- Claiming an issue, assignment and status, happens in this context only. Sub-agents never touch issue state.
- The durable record is the permanent artefact; the plan is not.
- Never absorb phase-level detail into this context.

### Output

Per task:

```markdown
Task: <ISSUE-KEY or path> - <pass/fail in one sentence>
Changes:
- `<path>` - <concise detail>
Tests:
- Pass/Fail/Not run - <command or reason>
Commit: <sha>
```

Then once overall:

```markdown
Answer: <pass/fail/blocker in one sentence>
Branch: `<branch name>` - run `make-pr` to open the pull request
Blockers:
- <only if blocked>
```
