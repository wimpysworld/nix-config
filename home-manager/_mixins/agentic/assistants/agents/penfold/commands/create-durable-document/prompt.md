## Create Durable Document

Write one durable record from the working documents of a finished build: what was built, and the decisions made, with their rationale. This is the closing step of a build, the counterpart to create-overview. The result is the single source of truth for a completed unit of work, for example a project stage, so the working docs can be deleted afterwards.

### Inputs

Working documents as paths or text: an overview, a proposal, a plan, a validation, and the implementation diff. Any subset is fine. $ARGUMENTS

If no input is given, ask for the working docs and the output path, then wait.

### Output

One durable document at a caller-named path, for example `docs/STAGE-N.md`. If the path is not supplied, confirm it before writing.

### Source of truth

- Draw the built result and the decisions from the inputs and from the actual code.
- Where the inputs and the code disagree, the code as built wins. Flag the divergence.
- Preserve any durable item that lives only in a working doc, for example the bar to promote a deferred option.
- Drop working-doc scaffolding: step lists, gate vocabulary, dependency order, "working document, not for commit" banners, ticket and phase numbers.

### Sections

Required sections are always present. Optional sections appear only when the build has that content.

| Section | Required | Focus |
|---------|----------|-------|
| Intro paragraph | yes | One paragraph: what was built, why, the make-or-break point, and "this is the durable record of the completed work" |
| Status summary | yes | Code-complete state, where it landed, that acceptance criteria are met, what remains for later work |
| Objective and scope | yes | The objective in one line; in scope (delivered) and out of scope (deferred, with the bar to promote each) |
| Work as built | yes | Technical sections describing the work as it exists in the code, one heading per area; the body of the record |
| Work completed | optional | Commit-by-commit log of how the build landed, each with its rationale; include only when the commit history adds detail the sections do not |
| Decisions recorded with rationale | yes | Each decision with its short reasoning; the choice and why, drawn from inputs and code |
| Acceptance criteria and how each was met | yes | Each criterion and the evidence it was met, naming the test or check |
| Risks identified and how they were resolved or carried forward | yes | Each risk, then resolved or carried forward as accepted, with the reason |

### Constraints

- Skip optional sections that do not apply.
- State the work as built, not the plan to build it.
- After writing, leave no reference to a now-deletable working doc. Point only at peer durable records and the architecture overview.
- Findings over process: what was built and decided, not how the build proceeded.
- No hedging language ("perhaps", "might", "could possibly").
- No repetition across sections; state each fact once.
