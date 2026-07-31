## Create Task

File the outcome of this session as a durable task: one Linear issue, several issues wrapped in a parent tracking issue, or a local markdown file. Capture all information and research from the session in the task body, so the implementer needs nothing else. This is the write counterpart to `research-task`, which reads.

Input: $ARGUMENTS is a Linear project name, or a filesystem path for a local task file, optionally followed by a status. If $ARGUMENTS is blank, stop and ask for the target before doing anything else.

### Process

**1. Resolve the target**

If $ARGUMENTS is a filesystem path, the target is local. Otherwise list Linear projects and fuzzy match $ARGUMENTS. Show the matched project and ask the user to confirm before writing anything. If several projects match plausibly, list them and ask which one. If the resolved workspace has no Linear project, fall back to a local file and ask for the target directory.

For a local target, show the resolved directory and ask the user to confirm it before writing.

This confirmation is the only approval gate. Once the target is confirmed, create immediately. There is no draft-and-approve step.

**2. Choose the structure**

Decide single task versus cohort:

- One task when the work is a single deliverable.
- One task per unit of work plus a parent tracking task when the work is a group of related tasks to be iterated on.

State the decision and the reason in one line before creating anything.

**3. Query the taxonomy**

Never assume label, status, or estimate names. Each project has its own taxonomy. For the resolved project's team, query at run time:

- Which labels exist.
- Which workflow statuses exist.
- Whether estimates are enabled, and on what scale.

Pick from what exists. Never invent or create a label. For a local target, query the workspace's team taxonomy when one exists; otherwise reuse the vocabulary already present in sibling task files.

**4. Classify**

Status:

- Default to the team's `triage`-type status when the caller names none. Gate on the status type, never the status name.
- A caller may name a different status. Resolve it against the team's workflow statuses from step 3. This is how a caller with an already-researched task files straight to Backlog.
- If the team has no `triage`-type status, or no status by the name the caller gave, use the team's default entry status and say so in the report. Linear's Triage is a per-team feature that can be switched off, and an unattended caller cannot answer a question.
- Local task files carry no status.

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

Estimate. Load the `sizing` skill and follow it; it holds the scale and what the work at each size looks like. Map to the scale in use, do not assume one.

Leave parent tracking tasks unestimated; the children carry the size. A single task that estimates at the largest size with unresolved design is the signal to split it into a parent plus children.

**5. Order the cohort**

- Express the order in the parent's `Child issues` numbered list, with `Depends on <n>` on each entry.
- Restate each edge in the child's `Dependencies` section: what it depends on, what it blocks, and one sentence on why.
- Say which steps ship inert and which flip behaviour on.
- Do not create Linear blocking relations. This workspace does not use them.

**6. Ground the body**

Load the `contribution-voice` skill and follow it for the prose. A task body publishes under the user's name. The templates in Output Format fix the headings, so the skill's rule against scaffolding does not apply to them; it governs everything written inside them. Run its cut pass on every section before creating the task.

Before writing any body:

- Search the codebase for the utilities, helpers, and patterns that already cover part of the work. Name exact file paths and function names in `Context`.
- For each bullet in `Scope`, say whether existing code is reused, extended, or written new. Justify every new.
- Give every material claim its source: a permalink pinned to a commit SHA, a spec URL, or a repo path with what the implementer will find there. Cut a claim that carries none.
- Record findings, not the search log. Where the session weighed options, state the chosen approach and the rejected alternatives in one line each.
- Record a blocker only when the session's research and the existing code do not resolve it. Speculation is not a blocker.
- Write acceptance criteria a reader can check by observation or by running a command. Subjective criteria do not ship.

**7. Create**

Where the research exceeds roughly 6,000 characters, or will outlive the work, create a Linear document holding the durable record, link it from the parent, and say so in one line in the parent body. For a local target, write the durable record as a sibling file and link it by relative path.

To Linear: create children as sub-issues of the parent, in dependency order, so identifiers ascend with the sequence. Assign every issue, parent and children, to the user creating them. Resolve that user at run time from the authenticated Linear identity; never hard-code an identifier.

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

## Problem

<Why this exists. For a bug: the observed failure, where it was confirmed, and the mechanism. For a feature: the gap. Omit only when the Outcome is self-evident.>

## Context

<What exists today that the implementer must not break or must build on: current behaviour, file paths, measured numbers, standing decisions. Omit when there is no prior art.>

## Scope

* <Bounded statement of what changes.>
* <One bullet per boundary or subsystem touched.>

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
- Every issue gets labels, priority, and an estimate, drawn from the live taxonomy. Local files carry the same four values in frontmatter.
- Every Linear issue is assigned to the user creating it. Local task files carry no assignee.
- The body templates are identical for Linear and for local files. Only the frontmatter differs.
- British spelling. No hedging language.
- Ask nothing after the target is confirmed. Create the task.
