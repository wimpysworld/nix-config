## Create Task

File the outcome of this session as a durable task: one tracked issue, several issues wrapped in a parent tracking issue, or a local markdown file. The tracker is Linear or a GitHub Project. Capture all information and research from the session in the task body, so the implementer needs nothing else. This is the write counterpart to `research-task`, which reads.

Input: $ARGUMENTS is a Linear project name, a GitHub project URL, or a filesystem path for a local task file, optionally followed by a status. If $ARGUMENTS is blank, infer the project from this session: the repository, the task's subject, and any project named in the conversation.

### Process

**1. Resolve the target**

Load the `task-tracker` skill, resolve the tracker from $ARGUMENTS, and read that tracker's reference. Its `Identity and lookup` section says how to resolve the project and, for GitHub, the repository the issue is created in.

When $ARGUMENTS names a project and exactly one project matches it, use that project without asking. State the match in one line and carry on. Ask only when the name matches several projects plausibly, or none: list the candidates and ask which one.

When $ARGUMENTS is blank, find the best match from the session and ask the user to confirm it before writing anything. Offer the runner-up where one is close. If no project fits, fall back to a local file and ask for the target directory.

For a local target, show the resolved directory and ask the user to confirm it before writing.

That question, where one is asked, is the only approval gate. Once the target is resolved, create immediately. There is no draft-and-approve step.

**2. Choose the structure**

Decide single task versus cohort:

- One task when the work is a single deliverable.
- One task per unit of work plus a parent tracking task when the work is a group of related tasks to be iterated on.

State the decision and the reason in one line before creating anything.

**3. Query the taxonomy**

Never assume type, label, status, or estimate names. Each project has its own taxonomy. Query it at run time as the tracker reference describes:

- Which types and labels exist.
- Which statuses exist.
- Whether estimates are enabled, and on what scale.

Pick from what exists. Never invent or create a type, a label, or an option. For a local target, query the workspace's taxonomy when one exists; otherwise reuse the vocabulary already present in sibling task files.

**4. Classify**

Status:

- Default to the tracker's `new` role when the caller names none. The reference says how the role is recognised, and it gates on the role, never on a status name.
- A caller may name a different status. Resolve it against the tracker's statuses from step 3. This is how a caller with an already-researched task files straight to the `ready` role.
- If the tracker has no status for the role, or none by the name the caller gave, use the reference's fallback and say so in the report. An unattended caller cannot answer a question.
- Local task files carry no status.

Type and area:

- Apply exactly one type: bug when shipped behaviour is wrong, feature when a user-visible capability is new, otherwise the improvement equivalent. The reference says whether type is a label or a tracker field.
- Apply every area or component label the work touches. Multiple is normal.
- If no area label fits, the type alone is enough.
- If the taxonomy has no type, apply the best-fitting labels available.

Priority, mapped onto the tracker's scale by the reference:

- 1 Urgent - shipped behaviour blocks work already in flight, or the cohort cannot proceed.
- 2 High - a correctness bug, or the critical path of an active cohort.
- 3 Medium - the default for planned work.
- 4 Low - deferred or optional work, gated behind evidence that does not yet exist.
- Never set 0 No priority deliberately.
- A parent takes the highest priority among its children.

Estimate. Load the `sizing` skill and follow it; it holds the scale and what the work at each size looks like. Map to the scale in use, do not assume one.

Leave parent tracking tasks unestimated; the children carry the size. A single task that estimates at the largest size with unresolved design is the signal to split it into a parent plus children.

**5. Order the cohort**

- Express the order in the parent's `Child issues` numbered list, with `Depends on <n>` on each entry.
- Restate each edge in the child's `Dependencies` section: what it depends on, what it blocks, and one sentence on why.
- Say which steps ship inert and which flip behaviour on.
- Do not create tracker blocking or dependency relations. The parent body is the single source of order.

**6. Ground the body**

Read `contribution-voice` first unless its complete, current instructions are in this context. Apply it for the prose. A task body publishes under the user's name. The templates in Output Format fix the headings, so the skill's rule against scaffolding does not apply to them; it governs everything written inside them. Run its cut pass on every section before creating the task.

Before writing any body:

- Search the codebase for the utilities, helpers, and patterns that already cover part of the work. Name exact file paths and function names in `Context`.
- For each bullet in `Scope`, say whether existing code is reused, extended, or written new. Justify every new.
- Give every material claim its source: a permalink pinned to a commit SHA, a spec URL, or a repo path with what the implementer will find there. Cut a claim that carries none.
- Record findings, not the search log. Where the session weighed options, state the chosen approach and the rejected alternatives in one line each.
- Record a blocker only when the session's research and the existing code do not resolve it. Speculation is not a blocker.
- Write success criteria that a reader can check by observation or by running a command. Subjective criteria do not ship.

**7. Create**

Where the research exceeds roughly 6,000 characters, or will outlive the work, store it where the reference's `long research` section says, link it from the parent, and say so in one line in the parent body. For a local target, write the durable record as a sibling file and link it by relative path.

To a tracker: create children as sub-issues of the parent, in dependency order, so identifiers ascend with the sequence. Assign every issue, parent and children, to the user creating them. Resolve that user at run time from the authenticated identity; never hard-code an identifier.

To a local file: write one file per task in the confirmed directory. For a cohort, write the parent as `00-<slug>.md` and each child as `NN-<slug>.md`, numbered in dependency order, so the filenames carry the sequence. Start every local task file with the frontmatter block below, then the matching body template unchanged:

```yaml
---
title: <task title>
labels: [<label>, <label>]
priority: <1-4>
estimate: <points on the scale in use>
---
```

### Output Format

Standalone or child issue body:

```markdown
## Outcome

<One sentence, present tense, from the reader's point of view. What is true when this is done.>

## Why

<In one short paragraph, state the broader user, business, reliability, or delivery impact. Keep the technical problem in Problem.>

## Problem

<The technical problem. For a bug: the observed failure, where it was confirmed, and the mechanism. For a feature: the technical gap. Omit only when the Outcome is self-evident.>

## Context

<Existing behaviour and constraints that the implementer must not break or must build on: current behaviour, file paths, measured numbers, standing decisions. Omit when there is no prior art.>

## Scope

### In scope

* <Bounded statement of what changes.>
* <One bullet per boundary or subsystem touched.>

### Out of scope

* Do not <thing a reasonable implementer would otherwise do>.

## Requirements

<Numbered, testable rules. Use only when Scope needs more than six bullets or splits into named groups. Otherwise omit and let Scope carry it.>

## Success Criteria

* <Observable end state, not a task.>
* <Each bullet is independently checkable.>
* <Include the test obligation: what new tests must prove.>

## Validation

<fenced sh block with the exact commands to run>

<Include only when commands or measurements are required. State what to record before and after for performance work.>

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

## Why

<In one short paragraph, state the broader user, business, reliability, or delivery impact of the cohort. Keep the technical problem in Problem.>

## Problem

<The shared technical problem all children solve. Two or three paragraphs maximum.>

## Context

<Existing behaviour and constraints that every child must honour, including file paths, measured numbers, and standing decisions. Omit when there is no prior art.>

## Scope

### In scope

* <area>

### Out of scope

* <area that the cohort will not change>

## Shared decisions

* <Standing decision every child must honour, with its reason.>

## Child issues

Implement in this order:

1. **<Child title>** - <one line of what it does>. Depends on: none.
2. **<Child title>** - <one line>. Depends on 1.
3. **<Child title>** - <one line>. Depends on 1, 2. Flips the behaviour on.
4. **<Child title>** - <one line>. Depends on 2. Can run in parallel with 3.

<Mark which steps ship inert and which change user-visible behaviour.>

## Success Criteria

* Every child issue has a ship, reject, or defer decision.
* <Cross-cutting gate that no single child owns.>
* <Documentation that must exist at the end.>

## Evidence

* <Link to the durable record holding the full research, if one was created.>
* <Permalinks and file paths shared by the cohort.>
```

### Constraints

- `Outcome`, `Why`, `Scope`, and `Success Criteria` are mandatory. Every other section appears only when there is real content.
- `Scope` always contains both `In scope` and `Out of scope`.
- Never stub a section with "N/A" or "None". Omit it.
- Use exactly these heading names. No synonyms.
- Never put tool, agent, or workflow instructions into an issue body.
- Keep `Why` to one short paragraph. `Problem` and `Context` can use one or two short paragraphs; use bullets elsewhere.
- The parent holds cohort scope, shared decisions, dependency order, and cohort success. Children hold delivery scope, success criteria, priority, estimate, and labels.
- Every issue gets a type, labels, priority, and an estimate, drawn from the live taxonomy. Local files carry the same values in frontmatter.
- Every tracked issue is assigned to the user creating it. Local task files carry no assignee.
- The body templates are identical for every tracker and for local files. Only the frontmatter differs.
- Tracker mechanics live in `task-tracker`. Never name a status, type, or field here.
- British spelling. No hedging language.
- Ask nothing after the target is resolved. Create the task.
