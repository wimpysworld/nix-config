## Research Task

Deeply research a task, everything it links to, and related work across Linear, GitHub, Slack, and any data warehouse that is reachable, then synthesise one analysis with recommended solutions. Aim for a complete understanding of the task and the work already done around it, so we learn from prior contributions, respect them, and do not blindly revert or undo valuable work. Every claim must trace to a source.

`research-task` anchors on an existing task; `deep-research` is for an open question with no task yet.

Input: $ARGUMENTS. The first token names the task: a Linear issue key or URL, a GitHub issue or PR URL or `owner/repo#123` shorthand, or a path to a local markdown task file. Any text after the first token is extra context from the user. If $ARGUMENTS is blank, ask which task to research before starting.

Keep every source read-only. For GitHub issue, PR, code, comment, review, and status reads or searches, follow the global GitHub rule: prefer dedicated `gh` reads and searches, then `gh-api-safe`; otherwise use only documented, clearly read-only GitHub MCP operations. Never use a GitHub MCP mutation or a tool whose effect is unclear.

### Process

**1. Anchor**

Detect the input type from the first token and read the target:

| Input | How to read it |
|-------|----------------|
| Linear issue key or URL | Linear MCP |
| GitHub issue or PR URL, or `owner/repo#123` | Read through the provider-neutral GitHub path, including linked context and status |
| Path to a local markdown task file | Read the file and derive search terms from its content |

Extract the problem statement, acceptance criteria, and every embedded or linked source: other Linear issues, GitHub PRs and issues, Slack links, arbitrary URLs, and attachments. A task written by `create-task` carries these under `Outcome`, `Problem`, `Context`, `Scope`, `Requirements`, `Acceptance criteria`, `Validation`, `Non-goals`, `Dependencies`, and `Evidence`.

**2. Fan out**

Delegate to a wide fan-out of sub-agents, in parallel where possible. Split by source or source cluster. Cover two kinds of work: the sources linked from the target, and a topic sweep for related work the target does not link. Match the tool to the source type:

| Source | Tool |
|--------|------|
| Linked Linear issues | Linear MCP |
| GitHub PRs, issues, code, and status | Provider-neutral GitHub reads and searches |
| Linked Slack threads | Slack tooling |
| General URLs, web context | `mcp__exa__web_fetch_exa`, `mcp__exa__web_search_exa` |
| Linear topic search | Linear MCP - search other issues on the same domain, feature, or problem, not only linked ones |
| GitHub topic search | Search issues, PRs, code, and status for related work the target does not link |
| Slack topic search | Slack tooling - search recent conversations on the same topic, not only linked threads |
| Counts, rates, trends | BigQuery, when a client is available - a CLI, an MCP server, or an existing export |

Reach for BigQuery when the task makes a quantitative claim, when a recommendation would be stronger with a number, or when the size of a problem is unknown. Prefer a measured number over an estimate. Record the query and the date it ran beside the number, so the claim traces to its source like every other claim here. When no client is reachable, say so plainly and move on; absence is not a finding.

Derive search terms from the problem statement, feature names, symbols, and error strings in the target. For each related item found, capture what it decided or changed and whether it is open, merged, or abandoned, so the synthesis can respect prior work.

Each sub-agent reports findings with source references. Never mutate external state: no comments, approvals, merges, or posts.

**3. Synthesise**

Merge all findings into the output format below. Deduplicate anything raised by more than one sub-agent. Resolve contradictions or flag them.

### Output Format

```markdown
# [Task title] - research

## Summary
[Problem and headline recommendation - one paragraph]

## Task context
[What the target asks for: problem, acceptance criteria, scope]

## Linked sources researched
[Each source with a one-line note on what it contributed]

## Related work
[Prior contributions found by topic search on Linear, GitHub, and Slack, not linked from the target. For each: what it decided or changed, its status, and what to respect or reuse rather than undo. Omit if none]

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

The synthesis is not filed anywhere automatically. The user captures it with `create-task` or `update-task`.

### Markers

📌 KEY (critical finding), ⚠️ CAVEAT (limitation/uncertainty), → (recommendation)

### Constraints

- Every claim traces to a source; no uncited assertions
- Search Linear, GitHub, and Slack for related work by topic, not only the sources linked from the target
- Note prior contributions to respect; do not recommend undoing valuable work without saying why
- Where a BigQuery dataset is reachable, measure the number and cite the query and its run date; where none is, say so and carry on
- Deduplicate findings raised by more than one sub-agent
- Never mutate external state in any source system
- No hedging language
- Omit any section with no content
- State each fact once; lead with conclusions
