## Make Linear Issue

File the outcome of this session into Linear as either one issue, or several issues wrapped in a parent tracking issue. Capture all information and research from the session in the issue bodies, so the implementer needs nothing else. This is the write counterpart to `research-linear-issue`, which reads.

Input: $ARGUMENTS is the Linear project name. If $ARGUMENTS is blank, stop and ask for the project name before doing anything else.

### Process

**1. Resolve the project**

List Linear projects and fuzzy match $ARGUMENTS. Show the matched project and ask the user to confirm before writing anything. If several projects match plausibly, list them and ask which one. This confirmation is the only approval gate.

**2. Choose the shape**

Once the project is confirmed, create the issues immediately. There is no draft-and-approve step.

Decide single issue versus cohort:

- One issue when the work is a single deliverable.
- One issue per task plus a parent tracking issue when the work is a group of related tasks to be iterated on.

State the decision and the reason in one line before creating anything.

**3. Query the taxonomy**

Never assume label, status, or estimate names. Each project has its own taxonomy. For the resolved project's team, query at run time:

- Which labels exist.
- Which workflow statuses exist.
- Whether estimates are enabled, and on what scale.

Pick from what exists. Never invent or create a label.

**4. Classify**

Labels:

- If the taxonomy has type-like labels, apply exactly one: bug when shipped behaviour is wrong, feature when a user-visible capability is new, otherwise the improvement equivalent.
- Apply every area or component label the work touches. Multiple is normal.
- If no area label fits, the type label alone is enough.
- If the taxonomy has no type-like labels, apply the best-fitting labels available.

Priority:

- 1 Urgent - shipped behaviour blocks work already in flight, or the cohort cannot proceed.
- 2 High - a correctness bug, or the critical path of an active cohort.
- 3 Medium - the default for planned work.
- 4 Low - deferred or optional work, gated behind evidence that does not yet exist.
- Never set 0 No priority deliberately.
- A parent takes the highest priority among its children.

Estimate. Map to the scale in use, do not assume one. The current workspace uses a T-shirt scale; read this as a shape guide, not a fixed set of values:

| Size | Points | Shape                                                            |
| ---- | ------ | ---------------------------------------------------------------- |
| XS   | 1      | A few lines changed, plus a test                                 |
| S    | 2      | Single-file change, or a bounded investigation                   |
| M    | 3      | Multi-file change inside one subsystem                           |
| L    | 5      | New component, or a cross-cutting seam change with a known design |
| XL   | 8      | Multiple subsystems, or unresolved design risk                   |

Leave parent tracking issues unestimated; the children carry the size. A single issue that estimates at the largest size with unresolved design is the signal to split it into a parent plus children.

**5. Order the cohort**

- Express the order in the parent's `Child issues` numbered list, with `Depends on <n>` on each entry.
- Restate each edge in the child's `Dependencies` section: what it depends on, what it blocks, and one sentence on why.
- Say which steps ship inert and which flip behaviour on.
- Do not create Linear blocking relations. This workspace does not use them.

**6. Create**

Where the research exceeds roughly 6,000 characters, or will outlive the work, create a Linear document holding the durable record, link it from the parent, and say so in one line in the parent body.

Create children as sub-issues of the parent, in dependency order, so identifiers ascend with the sequence.

### Output Format

Standalone or child issue body:

```markdown
## Outcome

<One sentence, present tense, from the reader's point of view. What is true when this is done.>

## Problem

<Why this exists. For a bug: the observed failure, where it was confirmed, and the mechanism. For a feature: the gap. Omit only when the Outcome is self-evident.>

## Context

<What exists today that the implementer must not break or must build on: current behaviour, file paths, measured numbers, standing decisions. Omit when there is no prior art.>

## Scope

* <Bounded statement of what changes.>
* <One bullet per seam or subsystem touched.>

## Requirements

<Numbered, testable rules. Use only when Scope needs more than six bullets or splits into named groups. Otherwise omit and let Scope carry it.>

## Acceptance criteria

* <Observable end state, not a task.>
* <Each bullet is independently checkable.>
* <Include the test obligation: what new tests must prove.>

## Validation

<fenced sh block with the exact commands to run>

<Include only when commands or measurements are required. State what to record before and after for performance work.>

## Non-goals

* Do not <thing a reasonable implementer would otherwise do>.

## Dependencies

<Only for issues in a cohort. State what it depends on and what it blocks, with one sentence on why.>

## Evidence

* <Permalink pinned to a commit SHA, or a spec URL.>
* `path/to/file` - <what the implementer will find there.>
```

Parent tracking issue body:

```markdown
## Outcome

<One sentence describing the state of the whole cohort when every child is closed.>

## Problem

<The shared problem all children serve. Two or three paragraphs maximum.>

## Boundaries

In scope:

* <area>

Out of scope:

* <area>

## Shared decisions

* <Standing decision every child must honour, with its reason.>

## Child issues

Implement in this order:

1. **<Child title>** - <one line of what it does>. Depends on: none.
2. **<Child title>** - <one line>. Depends on 1.
3. **<Child title>** - <one line>. Depends on 1, 2. Flips the behaviour on.
4. **<Child title>** - <one line>. Depends on 2. Can run in parallel with 3.

<Mark which steps ship inert and which change user-visible behaviour.>

## Completion criteria

* Every child issue has a ship, reject, or defer decision.
* <Cross-cutting gate that no single child owns.>
* <Documentation that must exist at the end.>

## Evidence

* <Link to the Linear document holding the full research record, if one was created.>
* <Permalinks and file paths shared by the cohort.>
```

### Constraints

- `Outcome`, `Scope`, and `Acceptance criteria` are mandatory. Every other section appears only when there is real content.
- Never stub a section with "N/A" or "None". Omit it.
- Use exactly these heading names. No synonyms.
- Never put tool, agent, or workflow instructions into an issue body.
- Bullets over paragraphs, except `Problem` and `Context`, where one or two short paragraphs are allowed.
- The parent holds boundaries, shared decisions, dependency order, and cohort completion. Children hold delivery scope, acceptance, priority, estimate, and labels.
- Every issue gets labels, priority, and an estimate, drawn from the live taxonomy.
- British spelling. No hedging language.
- Ask nothing after the project is confirmed. Create the issues.
