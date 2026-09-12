
# Deep Research

Conduct multi-round research on a topic, synthesising findings into a cited report. Every claim must trace to a source.

Use the topic from the user's request. If no topic is present, ask for it before planning.

### Depth

| Level | Rounds | Sources | Use when |
|-------|--------|---------|----------|
| Quick | 1-2 | 3-5 | Fact-checking, simple lookups |
| Standard | 3-4 | 5-10 | Feature evaluation, comparison |
| Thorough | 5+ | 10-20 | Architecture decisions, major investments |

Default to **Standard**. Escalate to Thorough if early findings reveal significant complexity. State the chosen depth and rationale before beginning.

### Plan Location

Use the platform's task or plan facility when available. Otherwise keep the checklist in working context.

When filesystem tools are available, write the disposable plan to:

```
${TMPDIR:-/tmp}/agent-research/<slug>/research-plan.md
```

- `<slug>` is a short kebab-case slug from the research topic. Strip dates, status words, and filler.
- Create the directory if it does not exist.
- Never commit the plan or write it inside the repository.

Report the plan path only when a file was created.

### Process

**1. Prepare**

Apply `communication-rules` before writing anything. Read it first unless its complete, current instructions are already in this context.

**2. Plan**

Before any search, create a research plan as a numbered checklist. Each item answers one specific question. Store it using the platform's task or plan facility, the disposable path above, or working context. Update item status as research progresses.

| Status | Meaning |
|--------|---------|
| `[ ]` | Pending |
| `[~]` | In progress |
| `[x]` | Complete |
| `[-]` | Cancelled with reason |

**3. Search**

At the root, use parallel sub-agents for Standard and Thorough depth when the platform provides them. Split work by plan item, source family, or research angle. Otherwise research the items sequentially. For Quick depth, the root uses one worker unless parallel work clearly saves time.

As a worker, research the assigned scope directly without launching agents. Loading this skill does not change that role. Preserve the chosen depth, source checks, iteration, and citations within the assigned scope. If additional specialist work is necessary, return a bounded request to the parent after completing independent assigned work. The root handles the request and continues the original task.

For each plan item:
1. Mark it `[~]` in the plan before starting.
2. Choose the available tools that can search the live web and fetch or read URLs. Prefer Exa search and fetch tools when available. Otherwise use any suitable web search and web fetch or page-reading tools. Tool names vary by platform, so never require a specific tool identifier.
3. Search with specific queries before broad ones. Use date ranges, domain filters, categories, highlights, summaries, or subpage crawling when the chosen tool supports them.
4. Evaluate results before reading. Prioritise:
   - Official documentation and specifications
   - Primary sources (author blogs, release notes, changelogs)
   - Reputable technical publications
   - Community content (forums, Stack Overflow)
5. Fetch or read selected URLs, batching requests when supported. Full page content returned by a search tool counts as a fetch. If the platform can search but cannot retrieve source content, state the limitation and support claims only with the content it returned.

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
- Mark an item `[~]` in the plan before starting it; mark it `[x]` before starting the next. Never advance without updating the plan first.
