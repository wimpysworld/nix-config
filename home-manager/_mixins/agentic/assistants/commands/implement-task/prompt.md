## Implement Task

Take an agreed task through to implemented, validated, committed work. This command orchestrates; it never implements.

Input: `$ARGUMENTS` is a Linear issue key or URL, or a path to a local task file. If blank, stop and ask for one, then wait. Once the task is resolved, ask nothing further and run to completion.

This command is the sole dispatcher. Every planner, phase worker, and specialist it launches must do its own assigned work, return directly here, and never launch another agent or invoke a command that does. Use `delegate-task` for routing, fresh context, packets, waiting, and teardown. Wait for every required return before continuing.

Side effects: this command creates and checks out one Git branch; writes implementation and documentation files; writes and removes its task plan directories beneath `${TMPDIR:-/tmp}/agent-plans/`; updates Linear assignment, status, and comments or appends to a local task file; and stages and commits selected paths. It never pushes or opens a pull request.

Command invocation: use the current provider's command prefix. Codex uses `$command`; slash-command runtimes use `/command`. Invoke named commands only from this context, wait for each return, and tell each launched specialist not to delegate.

### Process

**1. Resolve the task.** For a Linear key or URL, read the issue, its `gitBranchName`, and its sub-issues. For a path, read the file. Decide whether it is a single task or a parent wrapping children.

**2. Order the work.** For a parent, take the run order from its `Child issues` list. Run children in parallel only where that list says they are independent. Preserve that order for commits. A single task is its own order of one.

**3. Open one branch for the whole piece of work.** Use the Linear `gitBranchName`, or the parent's for a cohort. For a local task, derive a kebab-case name from the task title. Linear keys its auto-close on the branch name when the pull request is eventually merged, so the name must match exactly.

For a Linear task, once the branch exists, assign the issue to the user and move it to the team's in-progress status. For a cohort, do this to the parent here; each child is claimed as its turn starts. Resolve both values at run time: take the user from the authenticated Linear identity, and take the status from the team's live workflow states by picking the one whose type is started. Never hard-code an identifier or a status name.

**4. Plan each task directly.** Before planning, claim the task: for a Linear issue, assign it to the user and move it to the in-progress status resolved in step 3. Claim each task at its own start, not the whole cohort up front, so the board shows what is running now.

Dispatch one fresh planning worker for one task body. Give it read-only repository authority plus permission to write only `${TMPDIR:-/tmp}/agent-plans/<key>-<slug>/plan.md`, where `<key>` is the lowercased Linear key or task file stem and `<slug>` is a short kebab-case title. Require atomic phases with an assigned agent and reason, dependencies, parallel eligibility, blockers, scope, success criteria, reuse candidates, and flags. The worker writes the disposable plan, returns its path and complete contents directly to this command, and stops. It never implements, changes issue state, invokes `create-plan`, or launches an agent.

**5. Dispatch each phase directly.** Read the returned plan here. Route every phase against the current agent list, re-routing the plan's assignment where current evidence calls for it. Dispatch one fresh worker per phase, in dependency order. Run independent, non-overlapping phases in parallel. Never give one worker two phases, a task, or the whole plan.

Give each worker the task's scope and acceptance criteria plus its phase's dependencies, scope, reuse candidates, flags, and success criteria. It verifies dependencies and reuse, implements only that phase, tests it, and returns changed files, tests, deviations, and blockers directly here. It may edit only its declared scope. It never changes issue state, stages or commits, invokes `implement-plan`, or launches an agent. Stop it after receiving its report.

**6. Validate and align each task here.** Check the combined changed files against the task's `Acceptance criteria` and `Scope`. Resolve open decisions with bounded research. If evidence still conflicts, take the conservative path that fits existing patterns and record why. Dispatch a fresh corrective phase for any implementation gap, then revalidate.

After validation passes, invoke `align-documentation <changed files>` where documentation must change. For changed prompts, commands, skills, assistants, or project instructions, invoke the matching `update-command`, `update-skill`, `update-assistant`, or `update-agents-md` workflow. These are direct specialist dispatches from this command. Wait for each return and revalidate its changes.

Load `contribution-voice`, then write the durable record from this context: 2 to 4 prose sentences saying what now exists and anything a reader must act on. Use no headings, bullets, or file list. Include only a non-obvious decision or carried risk, say the acceptance criteria pass in one clause, and name a criterion only when it does not. Post it as a Linear comment or append it to the local task file.

**7. Commit each task here.** One commit per task, after validation passes, in the parent's order. Stage explicitly with path-limited `git add -- <path>` from that task's reports. Never use `git add .`, `-A`, or `-u`. Invoke `draft-commit-message`, add a `Refs: <ISSUE-KEY>` footer for a Linear task, and commit from this context so workers never contend for the index. Delete that task's plan directory after its commit lands.

**8. Stop after the final commit.** Do not push. Do not open a pull request or draft its body; the user runs `make-pr` manually.

### Constraints

- No per-task coordinator or nested orchestrator exists. Every launched agent reports directly to this command and launches no agent of its own.
- The plan never enters the repo and is never committed.
- Leave every issue at the in-progress status after its commit lands. This command stops before the pull request, so nothing is reviewable or done yet. `make-pr` and the merge carry the status forward.
- Claiming an issue, writing its durable record, staging, and committing happen in this context only.
- The durable record is the permanent artefact; the plan is not.
- Keep worker reports short and retain only details needed for validation, the task report, and the commit.

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
