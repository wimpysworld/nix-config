## Build It

Turn an agreed overview into implemented, validated work.

Input: `$ARGUMENTS`.

If `$ARGUMENTS` is blank, ask for an overview path or overview text and wait for it. Once the overview is present, proceed to completion without deferring to the user.

Side effects: this workflow writes proposal and plan files, edits implementation files, updates documentation where required, runs local validation commands, stages intended code and documentation changes for commit-message drafting, and may use web research. It never creates commits.

Command invocation: use the current provider's command prefix when invoking each command. Codex uses `$command`; slash-command runtimes use `/command`. The workflow below lists command names without a fixed prefix.

### Process

1. Resolve the overview. If `$ARGUMENTS` is a readable path, read it. Otherwise treat `$ARGUMENTS` as overview text.
2. Derive a short kebab-case slug from the overview title, overview path stem, or task name. Prefer clear nouns. Strip dates, status words, and filler.
3. Choose artefact paths in the current workspace: `proposal-<slug>.md` and `plan-<slug>.md`, unless nearby project patterns imply a better directory or filename. Avoid overwriting existing files.
4. Run the `create-proposal <proposal>` workflow using the overview as source context.
5. Run `review-proposal <proposal>`. Apply clear fixes to the proposal. If the proposal or review leaves open questions or unresolved decisions, run `decide-it <proposal>` using the provider-prefix rule above before planning.
6. Run the `create-plan <plan>` workflow using the overview and proposal as source context.
7. Run `review-alignment <plan> <proposal>`. Apply clear fixes to the proposal or plan. If either artefact or the alignment review leaves open questions, unresolved decisions, or ambiguous findings, run `decide-it <document>` on the relevant artefact and rerun alignment when the decision changes either document.
8. Before implementation, confirm the plan has no unresolved questions or decisions. If it does, run `decide-it <plan>` and continue from the updated plan.
9. Run `implement-plan <plan>`.
10. Run `validate-plan <plan> <proposal>` with the changed files or implementation diff. Fix required gaps and rerun validation until it passes or a real blocker remains.
11. After validation passes, run `update-docs <changed files or implementation diff>` using the provider-prefix rule above. This delegates documentation checks and required updates to Velma. Update documentation only where the implemented change requires it.
12. If prompt, command, skill, assistant, or project instruction artefacts changed, delegate their documentation checks and required updates to Rosey. Run the relevant Rosey workflow, such as `update-command`, `update-skill`, `update-assistant`, or `update-agents-md`, using the provider-prefix rule above.
13. Review the working tree. Stage only code and documentation intended for commit. Do not stage working documents or planning artefacts, including overview, proposal, plan, alignment, validation, research, decision documents, or other build artefacts. Use explicit path-limited staging.
14. Run `draft-commit-message` using the provider-prefix rule above. Preserve its fenced commit message unchanged for the final output.

If the platform cannot expand a command from inside this command, perform the same workflow directly. Use the current command catalogue and project instructions as the source of truth.

### Decisions

- Treat the overview as the source of intent.
- Do not ask the user for more input after the overview is present.
- Treat documentation checks, required documentation updates, staging, and commit-message drafting as part of completion.
- For every open question, unresolved decision, or ambiguous review finding, use the `decide-it <document>` workflow against the artefact that contains it. Let `decide-it` handle bounded delegation, research, and in-place document updates.
- Use the current provider's command prefix for `decide-it` and `draft-commit-message`; this prompt names commands without a fixed prefix.
- When evidence still conflicts after `decide-it`, choose the conservative path that best fits existing patterns, and record the decision in the relevant artefact.

### Output

At completion, report:

```markdown
Answer: <pass/fail/blocker in one sentence>
Changes:
- `<path>` - <concise detail>
Tests:
- Pass/Fail/Not run - <command or reason>
Commit message:
<verbatim fenced commit message from `draft-commit-message`>
Blockers:
- <only if blocked>
```
