## Build It

Turn an agreed overview into implemented, validated work.

Input: `$ARGUMENTS`.

If `$ARGUMENTS` is blank, ask for an overview path or overview text and wait for it. Once the overview is present, proceed to completion without deferring to the user.

Side effects: this workflow writes proposal and plan files, edits implementation files, runs local validation commands, and may use web research.

Command invocation: use the current provider's command prefix when invoking each command. Codex uses `$command`; slash-command runtimes use `/command`. The workflow below lists command names without a fixed prefix.

### Process

1. Resolve the overview. If `$ARGUMENTS` is a readable path, read it. Otherwise treat `$ARGUMENTS` as overview text.
2. Derive a short kebab-case slug from the overview title, overview path stem, or task name. Prefer clear nouns. Strip dates, status words, and filler.
3. Choose artefact paths in the current workspace: `proposal-<slug>.md` and `plan-<slug>.md`, unless nearby project patterns imply a better directory or filename. Avoid overwriting existing files.
4. Run the `create-proposal <proposal>` workflow using the overview as source context.
5. Run `review-proposal <proposal>`. Apply clear fixes to the proposal.
6. Run the `create-plan <plan>` workflow using the overview and proposal as source context.
7. Run `review-alignment <plan> <proposal>`. Apply clear fixes to the proposal or plan.
8. Run `implement-plan <plan>`.
9. Run `validate-plan <plan> <proposal>` with the changed files or implementation diff. Fix required gaps and rerun validation until it passes or a real blocker remains.

If the platform cannot expand a command from inside this command, perform the same workflow directly. Use the current command catalogue and project instructions as the source of truth.

### Decisions

- Treat the overview as the source of intent.
- Do not ask the user for more input after the overview is present.
- For every open question, unresolved decision, or ambiguous review finding, use `delegate-task`.
- Delegate a wide fan-out of small, bounded sub-agent tasks in parallel where possible.
- Each sub-agent task must inspect relevant code and existing patterns, analyse project goals, use web research when needed, and return a concrete decision or evidence.
- Use `delegate-task` routing and the current available agents. Do not hard-code agent names or a static fallback list.
- When evidence conflicts, choose the conservative path that best fits existing patterns, and record the decision in the relevant artefact.

### Output

At completion, report:

```markdown
Answer: <pass/fail/blocker in one sentence>
Changes:
- `<path>` - <concise detail>
Tests:
- Pass/Fail/Not run - <command or reason>
Blockers:
- <only if blocked>
```
