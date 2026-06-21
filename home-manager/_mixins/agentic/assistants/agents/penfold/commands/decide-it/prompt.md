## Decide It

Resolve unresolved questions and decisions in a working document, then update that document in place.

Input: `$ARGUMENTS`.

If `$ARGUMENTS` is blank, ask for a working document path or document text and wait for it. If it is a readable path, read that file and edit it. If it is document text, ask for the target file path before researching, because this command must write the resolved document in place.

Side effects: this workflow edits the target document, reads project source, may inspect upstream app source code, may use web research, and delegates research through `delegate-task`.

### Process

1. Read the full document before judging.
2. Identify explicit and implicit unresolved items: `Open Questions`, `Decisions`, `TBD`, `TODO`, `FIXME`, `TBC`, option tables without a selected option, question marks that ask for a choice, ambiguous review findings, and assumptions that block implementation.
3. Treat project objectives as the explicit document goal, user constraints, nearby project instructions, existing repo patterns, and maintainability of the resulting work.
4. Group related items only when the same evidence answers them. Keep each group small enough for one bounded research task.
5. Delegate a wide fan-out of sub-agent tasks in parallel where possible. Use `delegate-task` routing and the current available agents. Do not name a static agent set.
6. Research enough to make a clear decision. Sources may include source code analysis in this project, upstream app source code, current documentation, web research, and project objectives.
7. Compare the returned evidence. When evidence conflicts, choose the conservative decision that best serves the project objectives, existing patterns, testability, and reversibility.
8. Edit the target document in place. Replace unresolved text with the chosen answer, decision, rationale, and evidence. Do not only append a report.
9. Leave an item unresolved only when research cannot answer it and outside input is required. Mark it as blocked with the missing input and the evidence already checked.

### Delegation Packet

For each delegated item or small group, use this packet shape:

```markdown
Task: Answer or decide <specific item> for <document path>.
Context: <document excerpt, known constraints, project objective, prior decisions>
Scope: <repo paths, upstream sources, web topics, in/out of scope>
Validation: <evidence required, commands or checks to run, citation or file-path expectations>
Output: Start with `Answer:`. Include `Recommendation:`, `Evidence:`, `Files:`, `Confidence: high/medium/low`, and `Blockers:` only if blocked.
Discipline: No preamble. Do not restate the task. Return decision-useful findings only. Omit raw command output.
```

### Document Update Rules

- Answer direct questions where they appear.
- Convert open option lists into a selected decision with a short rationale and rejected alternatives when useful.
- Replace `TODO`, `TBD`, `TBC`, and similar markers with the decided action.
- Preserve useful evidence, source links, and file paths near the decision.
- Keep wording concise. Remove repeated uncertainty once resolved.
- Preserve unrelated content and the document's existing structure.

### Output

At completion, report:

```markdown
Answer: <pass/fail/blocker in one sentence>
Changes:
- `<document path>` - <concise detail>
Decisions:
- <decision and rationale>
Tests:
- Pass/Fail/Not run - <command or reason>
Blockers:
- <only if blocked>
```
