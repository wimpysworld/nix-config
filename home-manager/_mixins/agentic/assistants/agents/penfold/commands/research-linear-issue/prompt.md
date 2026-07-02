## Research Linear Issue

Deeply research a Linear issue, everything it links to, and related work across Linear and Slack, then synthesise one analysis with recommended solutions. This is a deep-research exercise in the spirit of the `deep-research` command: aim for a complete understanding of the issue and the work already done around it, so we learn from prior contributions, respect them, and do not blindly revert or undo valuable work. Every claim must trace to a source.

Input: $ARGUMENTS. The first token is the Linear issue URL; any text after it is extra context from the user. If $ARGUMENTS is blank, ask for the Linear issue URL before starting.

### Process

**1. Anchor**

Read the target issue with the Linear MCP. Extract the problem statement, acceptance criteria, and every embedded or linked source: other Linear issues, GitHub PRs and issues, Slack links, arbitrary URLs, and attachments.

**2. Fan out**

Delegate to a wide fan-out of sub-agents, in parallel where possible. Split by source or source cluster. Cover two kinds of work: the sources linked from the issue, and a topic sweep for related work the issue does not link. Match the tool to the source type:

| Source | Tool |
|--------|------|
| Linked Linear issues | Linear MCP |
| GitHub PRs and issues | `gh` subcommands; `gh-api-safe` for raw reads |
| Linked Slack threads | Slack tooling |
| General URLs, web context | `mcp__exa__web_fetch_exa`, `mcp__exa__web_search_exa` |
| Linear topic search | Linear MCP - search other issues on the same domain, feature, or problem, not only linked ones |
| Slack topic search | Slack tooling - search recent conversations on the same topic, not only linked threads |

Derive search terms from the problem statement, feature names, symbols, and error strings in the target issue. For each related item found, capture what it decided or changed and whether it is open, merged, or abandoned, so the synthesis can respect prior work.

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

## Related work
[Prior contributions found by topic search on Linear and Slack, not linked from the issue. For each: what it decided or changed, its status, and what to respect or reuse rather than undo. Omit if none]

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
- Search Linear and Slack for related work by topic, not only the sources linked from the issue
- Note prior contributions to respect; do not recommend undoing valuable work without saying why
- Deduplicate findings raised by more than one sub-agent
- Never mutate external state in any source system
- No hedging language
- Omit any section with no content
- State each fact once; lead with conclusions
