## Review Task

Judge whether a task is ready to implement, and say what must change first.

Input: $ARGUMENTS is a Linear issue key or URL, a GitHub issue URL or `owner/repo#N`, or a path to a local markdown task file. If $ARGUMENTS is blank, stop and ask which task to review before doing anything else.

### Process

1. Read the whole task before judging. Load the `task-tracker` skill, resolve the tracker from $ARGUMENTS, and read the task as its reference describes. Read local files from disk.
2. For a parent tracking issue, also read every child named in `Child issues`.
3. Check material claims against the codebase, the sources under `Evidence`, and current docs where needed.
4. Judge each area below.
5. Decide whether an implementer can start without further research and without new product or architecture decisions.

A standalone or child task body uses these headings, in order: `Outcome`, `Why`, `Problem`, `Context`, `Scope` with `In scope` and `Out of scope`, `Requirements`, `Success Criteria`, `Validation`, `Dependencies`, `Evidence`. A parent uses `Outcome`, `Why`, `Problem`, `Context`, `Scope` with `In scope` and `Out of scope`, `Shared decisions`, `Child issues`, `Success Criteria`, and `Evidence`. `Outcome`, `Why`, `Scope`, and `Success Criteria` are mandatory. The rest appear only when there is real content, so a missing optional section is a finding only when its absence leaves the implementer guessing.

| Area | Question |
| ---- | -------- |
| Outcome | Is it a single, testable statement of the end state, not a list of activities? |
| Why | Does it state the broader user, business, reliability, or delivery impact without repeating the Problem? |
| Problem | Does it state the technical failure, mechanism, or gap? |
| Context | Does it state the existing behaviour and constraints that the work must preserve or build on? |
| Scope | Do `In scope` and `Out of scope` bound the work, with no hidden work that the Outcome implies but the Scope omits? |
| Requirements | Where present, are the rules numbered, testable, and free of overlap with Scope? |
| Success Criteria | Are they observable and independently checkable, rather than restatements of the Scope? |
| Validation | Where commands are needed, do they exist and run in this repository? |
| Dependencies | For a cohort member, are the stated edges consistent with the parent's order? |
| Evidence | Can an implementer start from it without doing fresh research? |
| Child issues | For a parent, is the dependency order complete and acyclic, and does every child exist? |
| Metadata | Are type, labels, priority, and estimate consistent with the work described, and drawn from the tracker's live taxonomy as the reference maps them? Load the `sizing` skill and judge the estimate against it. |
| Gaps | What is missing that would block or misdirect an implementer? |

### Output Format

```markdown
## Verdict

Ready / Ready with fixes / Not ready - one sentence explaining why.

## Fixes

| Priority | Area | Finding | Evidence | Fix |
| -------- | ---- | ------- | -------- | --- |
| P0/P1/P2 | Heading or area from the table above | The specific gap | Task text, code path, linked source, or research citation | One concrete change |

## Readiness

State what an implementer can start now, what must change first, and what questions remain.
```

Omit empty table rows. If there are no findings, state "No blocking gaps found" under Fixes.

### Constraints

- Read and report only. Never edit the task, post a comment, or change any external state.
- Review task quality, not implementation mechanics. Do not design the solution.
- Do not compare an implementation diff against the task.
- Do not invent findings. Every finding must cite task text, repository evidence, a linked source, or current research.
- P0 blocks an implementer. P1 misdirects one. P2 is worth fixing but neither.
- British spelling. No hedging language.
