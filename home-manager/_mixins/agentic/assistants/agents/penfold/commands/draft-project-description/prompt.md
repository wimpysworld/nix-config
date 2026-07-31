## Draft Project Description

Write or rewrite a Linear project description so it earns a high score from the LensAgent project-quality coach on the first pass. The coach files a coaching issue rating the project on four dimensions: name quality, what is accomplished, quantitative measure, and precise date. This is a full rewrite of the description field, not a merge.

Input: $ARGUMENTS is a Linear project name, ID, or slug. If $ARGUMENTS is blank, stop and ask for the project before doing anything else.

Authority: human invocation is consent to write the one named project's description, summary, labels, priority, and dates. Not its issues, not its membership, not GitHub, not Slack.

### Process

**1. Resolve the project**

Fuzzy match $ARGUMENTS against the workspace's projects and read the resolved project, including its current description. Show the match and ask the user to confirm. If several match plausibly, list them and ask which one. If none match, say so and stop.

This confirmation is the only approval gate. Ask nothing after it.

**2. Read every issue**

Read every issue in the project, including sub-issues. The outcomes come from the issues, and `Boundaries` must match the membership. A boundary that excludes an area the project owns is the defect this section carries most often.

**3. Satisfy the coach**

Look for an open LensAgent coaching issue on the project. Read it and address every gap it names. Where a gap is a missing number, find the number in the issues or name the issue that will supply it.

**4. Compose**

Load the `contribution-voice` skill and follow it for every sentence. A project description publishes under the user's name. The template below fixes the headings, so the skill's rule against scaffolding does not apply to them; it governs the prose inside. Run its cut pass before writing.

**5. Write**

Show the change summary, then write. Do not ask for approval. Report after, naming the project and the manual steps left for the operator.

### Writing to Linear

- `save_project` has no patch operation, unlike `save_issue`. Every write replaces the whole description. Read the current description first and copy each existing `<issue id="..." href="...">KEY</issue>` mention markup verbatim. A plain issue key is acceptable for a new mention.
- Set a precise `targetDate` and leave `targetDateResolution` unset. `month` snaps the date to the month end, and the resolution cannot be cleared once set; the enum offers only `halfYear`, `month`, `quarter`, and `year`.
- This MCP has no favourites or star tool, and `save_project` has no members field. Report both as manual steps for the operator rather than claiming them done.
- Do not rename the project to satisfy the coach's name-quality dimension. LensAgent proposes marketing-style names such as "Achieve 100% FIPS Variant Planning Accuracy and Eliminate FIPS-Related Build Halts". A short descriptive name plus numbered outcomes answers the underlying ask. Say so in the report.

### Description Template

```markdown
## Purpose

<One short paragraph. What is true when the project is done, in the reader's terms.>

## Motivation

<One or two paragraphs. The confirmed defect or gap that started this, then the neighbouring problems that fixing it exposed. Every claim names its issue key or its evidence.>

## Outcomes

Each outcome states the number that proves it, measured over the 30 days after the last child lands.

* **Zero** <failure mode>. Baseline: <count> on <date>, confirmed by <issue key or case>.
* **<Number>** <measurable end state>. Baseline: <count> on <date>, confirmed by <issue key or case>. <Where the measurement needs instrumentation that does not exist yet, say so and name the issue that supplies it.>

## Boundaries

<What is in scope beyond the obvious home subsystem.>

Out of scope: <area> (<issue key or project that owns it>), <area> (<owner>).

## Risks

* <External blocker only: a missing licence on borrowed code, another team forking a shared source of truth. Omit the whole section when there are none.>
```

### Output Format

```markdown
## Changes

* `<heading>` - <what changes, in one line>

## Decisions

* <decision> - <reason>. Evidence: <issue key, permalink, or URL>

## Manual

* <step the operator must do: add members, favourite the project. Omit when none.>

## Still open

* <item> - blocked on <missing input>. Omit when nothing is open.
```

### Constraints

- Use exactly these heading names, in this order. No synonyms, no new headings.
- An outcome with no number and no baseline does not ship.
- `Risks` appears only for real external blockers. Never stub a section with "N/A" or "None". Omit it.
- `Boundaries` must not contradict the project's issue membership.
- Write the description, summary, labels, priority, and dates only. Never touch the project's issues or membership.
- British spelling, short sentences, active voice, conclusion first. No hedging. The session's Communication Rules govern the rest.
- Ask nothing after the project resolves. Write the description.
