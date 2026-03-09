## Deep Research

Conduct multi-round research on a topic, synthesising findings into a cited report. Every claim must trace to a source.

### Depth

| Level | Rounds | Sources | Use when |
|-------|--------|---------|----------|
| Quick | 1-2 | 3-5 | Fact-checking, simple lookups |
| Standard | 3-4 | 5-10 | Feature evaluation, comparison |
| Thorough | 5+ | 10-20 | Architecture decisions, major investments |

Default to **Standard**. Escalate to Thorough if early findings reveal significant complexity. State the chosen depth and rationale before beginning.

### Process

**1. Plan**

Before any search, create a research plan as a numbered checklist. Each item: one specific question to answer. Write the plan to a `RESEARCH-PLAN.md` file in the working directory. Update item status as research progresses.

| Status | Meaning |
|--------|---------|
| `[ ]` | Pending |
| `[~]` | In progress |
| `[x]` | Complete |
| `[-]` | Cancelled with reason |

**2. Search**

For each plan item:
1. Mark it `[~]` in RESEARCH-PLAN.md before starting
2. Search using `mcp__exa__web_search_exa` - prefer specific queries over broad ones
2. Evaluate results before reading - prioritise by source quality:
   - Official documentation and specifications
   - Primary sources (author blogs, release notes, changelogs)
   - Reputable technical publications
   - Community content (forums, Stack Overflow)
3. Read selected URLs using `mcp__jina__read_url` or `mcp__jina__parallel_read_url` for batch reads

**Query refinement:** If a search returns fewer than 3 relevant results, reformulate with different keywords, synonyms, or narrower/broader scope before proceeding.

**3. Track**

Maintain a visited URL set. Never read the same URL twice. When extracting facts, record the source number immediately.

**4. Iterate**

After completing each plan item, assess:
- Are there follow-up questions raised by the findings?
- Do any claims contradict across sources?
- Are there gaps that need a new plan item?

Add new items to the plan as discovered. Continue until all items are complete or depth limit is reached.

**5. Synthesise**

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
- Mark an item `[~]` in RESEARCH-PLAN.md before starting it; mark it `[x]` before starting the next - never advance without updating the file first
