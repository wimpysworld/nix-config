## Find Next Work

Identify the implementation work that the user can do next from their current Linear cycle work order.

This command serves work only: the `FUL` team. It is read-only. It changes nothing in Linear and posts nowhere.

Resolve the user at run time from the authenticated Linear identity. Load the `work-order-format` skill and use its wave and dependency semantics.

### Process

**1. Locate the work order.** Resolve the current `FUL` cycle and construct the exact title `<user first name>'s Cycle <n> work order`. Call `list_documents` with the team and that exact title as the search query. Follow each `nextPageCursor` with `cursor` until no cursor remains, and accept only an exact title match. When no current cycle exists, stop and report that fact. When the document does not exist, stop and tell the user to run `work-order-create <cycle number>`.

**2. Read the implementation state.** Read the full document. Extract every issue from its wave sections, each wave's prerequisite waves, the `Sequencing` constraints, and the `Deferred` entries. Deferred issues are never candidates.

Fetch every issue from the wave sections. Read its status type, assignee, cycle, full description, and recorded relations. Exclude an issue from the candidate set when its assignee is not the resolved user or its cycle is not the current cycle, and report the mismatch as a work order problem.

Classify each recorded relation by direction. An incoming prerequisite is an issue that blocks the candidate. An outgoing relation names an issue that the candidate blocks. In each `Dependencies` section, distinguish prerequisites of the candidate from issues that the candidate blocks. Resolve and read every incoming prerequisite. Never treat an outgoing issue as a blocker.

**3. Find the ready waves.** A prerequisite wave is complete only when every issue in that wave has status type `completed`. A wave with no prerequisite is ready immediately. A later wave is ready only when all its named prerequisite waves are complete. Respect explicit parallel-wave declarations. Never infer an order between parallel waves.

**4. Find the ready issues.** An issue needs implementation only when its status type is `backlog`, `unstarted`, or `started`. It is ready only when all incoming prerequisites from recorded relations and its `Dependencies` section have status type `completed`.

Select next work in this order:

1. Ready issues with status type `started`, across all ready waves.
2. Ready `backlog` or `unstarted` issues, across all ready waves.

Use the first non-empty group. Do not recommend new work while ready started work exists. Keep issues in the same wave or explicitly parallel waves as parallel choices. Use the document's wave order only where it declares a dependency. Never invent priority between parallel choices.

**5. Report blockers and inconsistencies.** For each unfinished candidate in a ready wave that is not ready, name every unfinished incoming prerequisite. List unfinished candidates in later waves with their prerequisite waves. Report a cancelled prerequisite, a `triage`-type issue in a wave, a missing issue, an assignee or cycle mismatch, or a dependency conflict as a work order problem. Tell the user to run `work-order-update` when the document needs correction.

**6. Report** per the output template. Omit empty sections.

### Output

```markdown
Document: <url>

Next:

* Continue: <issue key> <issue title> - Wave <n>. <Why it is ready.>
* Start: <issue key> <issue title> - Wave <n>. <Why it is ready.>

Blocked now:

* <issue key> - blocked by <issue key and status, or external dependency>.

Later:

* <issue key> <issue title> - Wave <n> needs Wave <n>.

Work order problems:

* <problem and the action that fixes it>.
```

When all wave issues have status type `completed` or `cancelled`, report `The current cycle work order has no implementation work left.` When unfinished issues exist but none are ready, state that under `Next` and list the blockers.

### Constraints

- Read-only. Never create, patch, comment, or change external state.
- Use status types, never status names, for every state decision.
- Treat only `completed` blockers and prerequisite-wave issues as complete.
- Never select a deferred, `triage`, `completed`, or `cancelled` issue.
- Never reorder parallel work.
- British spelling. No hedging language.
