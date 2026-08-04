---
name: draft-project-description
description: "Use when the user asks to write or rewrite a Linear project description, improve a project's LensAgent quality score, or turn project issues into measurable purpose, motivation, outcomes, boundaries, risks, and dates. Resolves the named project, reads every issue and any coaching issue, confirms the match once, then updates only the authorised project fields."
---

# Draft Project Description

Write or rewrite one Linear project description in the form the LensAgent project-quality coach scores.

## Input and authority

Take the Linear project name, ID, or slug from the user's request. If it is missing, ask for it and wait.

Explicit invocation of this skill with a named project authorises updates to that project's description, summary, labels, priority, and dates. Automatic skill discovery alone grants no write authority. Never change its name, issues, membership, or any GitHub or Slack state.

Rewrite the whole description. Do not merge prose into the current description.

## Process

1. Load and follow `communication-rules`.
2. Resolve the project by fuzzy matching the supplied name, ID, or slug against workspace projects. Read the resolved project and its current description.
3. Show the match and ask the user to confirm it. If several projects match, list them and ask which one. If none match, say so and stop. This is the only approval gate. Ask nothing after confirmation.
4. Read every issue in the project, including sub-issues. Derive the outcomes and boundaries from the complete membership.
5. Find any open LensAgent coaching issue for the project. Address every gap it names across name quality, what is accomplished, quantitative measure, and precise date. For a missing number, find it in the issues or name the issue that will supply it.
6. Load `contribution-voice` and follow it for the prose inside the required headings. Run its cut pass.
7. Compose the replacement description with the template below.
8. Show the change summary, then write the authorised project fields without another approval request.
9. Report the project changed and any manual steps left for the operator.

## Linear write rules

- Read the current description before calling `save_project`. It replaces the whole description. Copy each existing `<issue id="..." href="...">KEY</issue>` mention markup verbatim when retaining that mention. A plain issue key is acceptable for a new mention.
- Set a precise `targetDate`. Leave `targetDateResolution` unset because a resolution snaps the date and cannot be cleared.
- Report adding members and favouriting the project as manual steps. The available project write operation cannot do either.
- Do not rename the project to satisfy the name-quality score. Keep its short descriptive name and use numbered outcomes to answer the underlying gap. State this decision in the report.

## Description format

Use these headings in this order. Omit `Risks` when no real external blocker exists.

```markdown
## Purpose

<One short paragraph stating what is true when the project is done, in the reader's terms.>

## Motivation

<One or two paragraphs. State the confirmed defect or gap, then the neighbouring problems it exposed. Cite an issue key or other evidence for every claim.>

## Outcomes

Each outcome states the number that proves it, measured over the 30 days after the last child lands.

* **Zero** <failure mode>. Baseline: <count> on <date>, confirmed by <issue key or case>.
* **<Number>** <measurable end state>. Baseline: <count> on <date>, confirmed by <issue key or case>. <If measurement needs missing instrumentation, say so and name the issue that supplies it.>

## Boundaries

<What is in scope beyond the obvious home subsystem.>

Out of scope: <area> (<issue key or project that owns it>), <area> (<owner>).

## Risks

* <External blocker only, such as a missing licence on borrowed code or another team forking a shared source of truth.>
```

## Output

Return this report after the write:

```markdown
## Changes

* `<heading or field>` - <what changed, in one line>

## Decisions

* <decision> - <reason>. Evidence: <issue key, permalink, or URL>

## Manual

* <step the operator must do, such as adding members or favouriting the project. Omit when none.>

## Still open

* <item> - blocked on <missing input>. Omit when nothing is open.
```

## Constraints

- Use the required description headings exactly. Add no synonyms or extra headings.
- Never ship an outcome without a number and baseline.
- Never stub an omitted section with "N/A" or "None".
- Keep `Boundaries` consistent with the project's issue membership.
- Change only the description, summary, labels, priority, and dates.
- Ask nothing after the project is confirmed.
