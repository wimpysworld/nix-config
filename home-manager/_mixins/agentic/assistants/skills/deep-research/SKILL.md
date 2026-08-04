---
name: deep-research
description: "Use when the user asks to research a topic in depth, compare options, or investigate an open question, and says things like 'deep research', 'research this', 'look into X', or 'what are the options for X'. Runs multi-round web research and synthesises a cited report; use it for an open question with no tracked task yet, and `research-task` when an existing task anchors the work."
user-invocable: true
argument-hint: "<topic>"
---

# Deep Research

Conduct multi-round research on a topic, synthesising findings into a cited report. Every claim must trace to a source.

Topic argument: $ARGUMENTS. If blank, ask for the research topic before planning.

### Depth

| Level | Rounds | Sources | Use when |
|-------|--------|---------|----------|
| Quick | 1-2 | 3-5 | Fact-checking, simple lookups |
| Standard | 3-4 | 5-10 | Feature evaluation, comparison |
| Thorough | 5+ | 10-20 | Architecture decisions, major investments |

Default to **Standard**. Escalate to Thorough if early findings reveal significant complexity. State the chosen depth and rationale before beginning.

### Plan Location

Write the plan to:

```
${TMPDIR:-/tmp}/agent-research/<slug>/research-plan.md
```

- `<slug>` is a short kebab-case slug from the research topic. Strip dates, status words, and filler.
- Create the directory if it does not exist.

The plan is disposable. It lasts for one research run only. Never commit it and never write it inside the repo.

Report the plan path in your output so the user can find it.

### Process

**1. Prepare**

Load and follow the `communication-rules` skill before writing anything.

**2. Plan**

Before any search, create a research plan as a numbered checklist. Each item: one specific question to answer. Write the plan to the derived path above. Update item status as research progresses.

| Status | Meaning |
|--------|---------|
| `[ ]` | Pending |
| `[~]` | In progress |
| `[x]` | Complete |
| `[-]` | Cancelled with reason |

**3. Search**

For Standard and Thorough depth: Delegate to a wide fan-out of sub-agents, in parallel where possible. Split by plan item, source family, or research angle so each task stays small and well bounded. For Quick depth, use one worker unless fan-out clearly saves time.

For each plan item:
1. Mark it `[~]` in the plan file before starting
2. Search using `mcp__exa__web_search_exa` - prefer specific queries over broad ones
3. Use `mcp__exa__web_search_advanced_exa` for date ranges, domain filters, categories, highlights, summaries, or subpage crawling
4. Evaluate results before reading - prioritise by source quality:
   - Official documentation and specifications
   - Primary sources (author blogs, release notes, changelogs)
   - Reputable technical publications
   - Community content (forums, Stack Overflow)
5. Read selected URLs using `mcp__exa__web_fetch_exa`, batching URLs when reading several pages

**Query refinement:** If a search returns fewer than 3 relevant results, reformulate with different keywords, synonyms, or narrower/broader scope before proceeding.

**4. Track**

Maintain a visited URL set. Never read the same URL twice. When extracting facts, record the source number immediately.

**5. Iterate**

After completing each plan item, assess:
- Are there follow-up questions raised by the findings?
- Do any claims contradict across sources?
- Are there gaps that need a new plan item?

Add new items to the plan as discovered. Continue until all items are complete or depth limit is reached.

**6. Synthesise**

Compile findings into the output format below. Every factual claim must have an inline citation.

### Output Format

```markdown
# [Report Title]

## Summary
[What was researched, key conclusion - one paragraph]

## Findings

### [Theme 1]
[Synthesised findings with inline citations [1], [2]]

### [Theme 2]
[Synthesised findings with inline citations]

## Interesting Findings
[Surprising, counterintuitive, or noteworthy details - omit if none]

## Open Questions
[Unresolved items that could not be answered through research - omit if none]

## Sources
[1] [Title](URL) - one-line relevance note
[2] [Title](URL) - one-line relevance note
```

### Markers

📌 KEY (critical finding), ⚠️ CAVEAT (limitation/uncertainty), ✗ CONFLICT (sources disagree)

### Constraints

- Every factual claim must have an inline citation; no uncited assertions
- Never present information from training data as research findings
- Search before assuming; verify before asserting
- If sources conflict, present both positions with citations and flag with ✗ CONFLICT
- No hedging language ("perhaps", "might", "could potentially")
- No filler sections - omit any section with no findings
- Mark an item `[~]` in the plan file before starting it; mark it `[x]` before starting the next - never advance without updating the file first
