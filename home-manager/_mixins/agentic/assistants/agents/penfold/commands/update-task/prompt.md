## Update Task

Fold the decisions from this session into an existing task, so the task stays the single source of truth. This is a merge into what is already there, not a rewrite.

Input: $ARGUMENTS is a Linear issue key or URL, a GitHub issue URL or `owner/repo#N`, or a path to a local task file. If $ARGUMENTS is blank, stop and ask for the target before doing anything else.

### Process

**1. Read the target first**

Load the `task-tracker` skill, resolve the tracker from $ARGUMENTS, and read the whole task as its reference describes before judging anything. Never write blind. If the key, URL, or path does not resolve, say so and stop.

**2. Check the task is active**

Gate on the tracker role, never on a status name. The `inactive` role means the task is not active: report the status and stop, changing nothing at all - no body, no labels, no comment. This refusal is the one stop permitted after the target resolves. The `new` role is active: promote it to the `ready` role as part of this update. A local task file has no status, so neither rule applies to one.

**3. Collect what the session changed**

From this session only, list:

- Decisions made, each with its reason.
- Scope added or cut.
- New evidence: permalinks pinned to a commit SHA, spec URLs, repo paths with what the implementer will find there.
- Questions the session answered.
- Dependencies that changed.

Ignore session talk that changes nothing in the task.

**4. Resolve what the task still leaves open**

Find the unresolved items in the task: `Open questions`, `TBD`, `TODO`, `TBC`, `FIXME`, option lists with no choice made, and assumptions that block implementation. For each item the session has not already settled:

- Research only as far as the decision needs. Source order: this repo's code and patterns, upstream source, current documentation, then the web.
- Align each decision with the task's stated outcome, the evidence already in the task, and the existing code patterns. Deviate only when the task gives no good guidance and authoritative sources settle it. Flag every deviation, with the reason it departs from the task and the sources that support it.
- When evidence still conflicts after research, take the conservative option: the one that best serves the outcome, existing patterns, testability, and reversibility. Say in one line which evidence conflicted and why the chosen option won.
- Leave an item open only when outside input is required. Mark it blocked, naming the missing input and the evidence already checked.

Answer each question where it appears, replace the open marker with the decided action, and keep the evidence next to the decision it supports. Retitle a heading once its items are resolved, keeping the original heading level. Never leave `Open questions` standing above answered questions.

**5. Re-check the classification**

Query the live taxonomy for types, labels, statuses, and the estimate scale, as the tracker reference describes. Load the `sizing` skill and check the estimate against it. Never invent a type, a label, or an option. Change type, labels, priority, or estimate only when the session changed what the work involves, and state what changed and why. For a local task file the same values live in the frontmatter: `title`, `labels`, `priority`, `estimate`.

**6. Merge**

Read `contribution-voice` first unless its complete, current instructions are in this context. Apply it for every sentence you add or rewrite. A task body publishes under the user's name. The heading set is fixed, so the skill's rule against scaffolding does not apply to it; it governs the prose inside. Run its cut pass on the new text only, and leave untouched sections alone.

Keep the heading set and order from `create-task`'s templates. Standalone and child tasks use `Outcome`, `Why`, `Problem`, `Context`, `Scope` with `In scope` and `Out of scope`, `Requirements`, `Success Criteria`, `Validation`, `Dependencies`, and `Evidence`. Parent tasks use `Outcome`, `Why`, `Problem`, `Context`, `Scope` with `In scope` and `Out of scope`, `Shared decisions`, `Child issues`, `Success Criteria`, and `Evidence`. Add a heading only when the session produced real content for it. Never stub one. Preserve every existing section, sentence, and link the session did not touch.

For a task in a cohort, update the parent's `Child issues` list when dependency order or parallelism changed, and restate each changed edge in the affected child's `Dependencies` section.

**7. Write**

Show the change summary, then write. Do not ask for approval. Report after, naming the issue key, the issue reference, or the file path written.

### Output Format

```markdown
## Changes

* `<heading>` - <what changes, in one line>

## Decisions

* <decision> - <reason>. Evidence: <permalink, path, or URL>

## Classification

* <label, priority, estimate, or status change> - <why>. Omit when nothing changed.

## Still open

* <item> - blocked on <missing input>. Evidence checked: <source>. Omit when nothing is open.
```

### Constraints

- Merge, never replace. Content the session did not touch stays as it is.
- Use the heading names from `create-task`. No synonyms, no new headings.
- Never stub a section with "N/A" or "None". Omit it.
- Never put tool, agent, or workflow instructions into a task body.
- Every decision carries a reason and its evidence.
- Research only as far as the decision needs. Stop once the answer is clear.
- Draw type, labels, priority, and estimate from the live taxonomy. The `sizing` skill holds the rubric the estimate must match.
- Write to the task's own tracker or to a local file only. Never write to Slack, and never write to GitHub for a Linear task.
- Never touch a task in the `inactive` role. Report why and stop.
- Tracker mechanics live in `task-tracker`. Never name a status, type, or field here.
- British spelling. No hedging language.
- Ask nothing after the target resolves. Update the task, unless step 2 refuses it.
