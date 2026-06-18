## Research Linear Issue

Deeply research a Linear issue and everything it links to, then synthesise one analysis with recommended solutions. Every claim must trace to a source.

Input: $ARGUMENTS. The first token is the Linear issue URL; any text after it is extra context from the user. If $ARGUMENTS is blank, ask for the Linear issue URL before starting.

### Process

**1. Anchor**

Read the target issue with the Linear MCP. Extract the problem statement, acceptance criteria, and every embedded or linked source: other Linear issues, GitHub PRs and issues, Slack links, arbitrary URLs, and attachments.

**2. Fan out**

Launch a team of sub-agents in parallel, one per source or cluster. Match the tool to the source type:

| Source | Tool |
|--------|------|
| Linear issues | Linear MCP |
| GitHub PRs and issues | `gh` subcommands; `gh-api-safe` for raw reads |
| Slack links | Slack tooling |
| General URLs, web context | `mcp__exa__web_fetch_exa`, `mcp__exa__web_search_exa` |

Each sub-agent reports findings with source references. Never mutate external state: no comments, approvals, merges, or posts.

**3. Synthesise**

Merge all findings into the output format below. Deduplicate anything raised by more than one sub-agent. Resolve contradictions or flag them.

### Output Format

```markdown
# [Issue title] - research

## Summary
[Problem and headline recommendation - one paragraph]

## Issue context
[What the target issue asks for: problem, acceptance criteria, scope]

## Linked sources researched
[Each source with a one-line note on what it contributed]

## Findings
### [Theme]
[Synthesised findings with source references]

## Recommended solutions
| Option | Approach | Trade-offs | → |
|--------|----------|------------|---|
[Ranked options; mark the recommendation with →]

## Open questions
[Unresolved items - omit if none]

## Next steps
[Concrete actions]
```

### Markers

📌 KEY (critical finding), ⚠️ CAVEAT (limitation/uncertainty), → (recommendation)

### Constraints

- Every claim traces to a source; no uncited assertions
- Deduplicate findings raised by more than one sub-agent
- Never mutate external state in any source system
- No hedging language
- Omit any section with no content
- State each fact once; lead with conclusions
