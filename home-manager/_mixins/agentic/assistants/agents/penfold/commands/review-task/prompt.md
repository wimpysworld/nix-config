## Review Task

Judge whether a task is ready to implement, and say what must change first.

Input: $ARGUMENTS is a Linear issue key or URL, or a path to a local markdown task file. If $ARGUMENTS is blank, stop and ask which task to review before doing anything else.

### Process

1. Read the whole task before judging. Read Linear issues with the Linear MCP; read local files from disk.
2. For a parent tracking issue, also read every child named in `Child issues`.
3. Check material claims against the codebase, the sources under `Evidence`, and current docs where needed.
4. Judge each area below.
5. Decide whether an implementer can start without further research and without new product or architecture decisions.

A task body uses these headings, in order: `Outcome`, `Problem`, `Context`, `Scope`, `Requirements`, `Acceptance criteria`, `Validation`, `Non-goals`, `Dependencies`, `Evidence`. `Outcome`, `Scope`, and `Acceptance criteria` are mandatory. The rest appear only when there is real content, so a missing optional section is a finding only when its absence leaves the implementer guessing.

| Area | Question |
| ---- | -------- |
| Outcome | Is it a single, testable statement of the end state, not a list of activities? |
| Problem and Context | Is it clear why the work exists and what must not break? |
| Scope | Is it bounded, with no hidden work that the Outcome implies but the Scope omits? |
| Requirements | Where present, are the rules numbered, testable, and free of overlap with Scope? |
| Acceptance criteria | Are they observable and independently checkable, rather than restatements of the Scope? |
| Validation | Where commands are needed, do they exist and run in this repository? |
| Non-goals | Do they fence off the work a reasonable implementer would otherwise do? |
| Dependencies | For a cohort member, are the stated edges consistent with the parent's order? |
| Evidence | Can an implementer start from it without doing fresh research? |
| Child issues | For a parent, is the dependency order complete and acyclic, and does every child exist? |
| Metadata | Are labels, priority, and estimate consistent with the work described? Load the `sizing` skill and judge the estimate against it. |
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
