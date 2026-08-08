---
name: research-task
description: "Use when deeply researching an existing tracked task, including a Linear issue key or URL, a GitHub issue or pull request URL or owner/repo#123, or a local Markdown task file. Use for requests such as 'research this task', 'investigate this issue', or 'understand the work around this PR'. Follows linked and related work across Linear, GitHub, Slack, the web, and reachable data warehouses, then recommends cited solutions. Use `deep-research` for an open question with no tracked task."
---

# Research Task

Deeply research an existing task, everything it links to, and related work, then recommend cited solutions. The caller supplies the task target and optional context. This skill supplies the method.

Use `research-task` when a tracked task anchors the work. Defer an open question with no tracked task to `deep-research`.

Keep every source read-only. For GitHub issue, pull request, code, comment, review, and status reads or searches, follow the global GitHub rule: prefer dedicated `gh` reads and searches, then `gh-api-safe`; otherwise use only documented, clearly read-only GitHub MCP operations. Never use a GitHub MCP mutation or a tool whose effect is unclear.

## Input resolution

Resolve the task target before researching:

| Input | How to read it |
| --- | --- |
| Linear issue key or URL | Linear MCP |
| GitHub issue or pull request URL, or `owner/repo#123` | Provider-neutral GitHub reads, including linked context and status |
| Local Markdown task file | Read the file and derive search terms from its content |

Treat text after the target as extra context. If the target is missing, ask which task to research before starting.

## Process

1. Load and follow the `communication-rules` skill before writing anything.
2. Read the target and extract its problem statement, acceptance criteria, and every embedded or linked source.
3. Fan out to sub-agents in parallel where possible. Cover both linked sources and unlinked related work.
4. Merge the findings into the output format. Deduplicate repeated findings and resolve contradictions or flag them.

A task written by `create-task` carries its main context under `Outcome`, `Problem`, `Context`, `Scope`, `Requirements`, `Acceptance criteria`, `Validation`, `Non-goals`, `Dependencies`, and `Evidence`.

## Fan-out

Split work by source or source cluster. Match the available tool to the source:

| Source | Research path |
| --- | --- |
| Linked Linear issues | Linear MCP |
| GitHub pull requests, issues, code, and status | Provider-neutral GitHub reads and searches |
| Linked Slack threads | Slack tooling |
| General URLs and web context | Prefer Exa search and fetch tools when available; otherwise use suitable web search and page-reading tools |
| Linear topic search | Search other issues about the same domain, feature, or problem |
| GitHub topic search | Search issues, pull requests, code, and status for related work the target does not link |
| Slack topic search | Search recent conversations on the same topic, not only linked threads |
| Counts, rates, and trends | BigQuery through a reachable CLI, MCP server, or existing export |

Reach for BigQuery when the task makes a quantitative claim, when a recommendation would be stronger with a number, or when the size of a problem is unknown. Prefer a measured number over an estimate. Record the query and run date beside the number. If no client is reachable, state that limitation and continue. Absence is not a finding.

Derive search terms from the problem statement, feature names, symbols, and error strings in the target. For each related item, capture what it decided or changed and whether it is open, merged, or abandoned. Use this context to respect and reuse prior work.

Each sub-agent returns findings with source references. Never mutate external state: no comments, approvals, merges, or posts.

The caller is the sole orchestrator. Each sub-agent covers its assigned source and returns its findings directly. It never launches another agent.

## Output

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
| --- | --- | --- | --- |
[Ranked options; mark the recommendation with →]

## Open questions
[Unresolved items - omit if none]

## Next steps
[Concrete actions]
```

The report is not filed automatically. The user can capture it with `create-task` or `update-task`.

Markers: 📌 KEY (critical finding), ⚠️ CAVEAT (limitation or uncertainty), → (recommendation).

## Constraints

- Every claim traces to a source. Never present training data as a research finding.
- Search Linear, GitHub, and Slack by topic, not only through links from the task.
- Note prior contributions to respect. Do not recommend undoing valuable work without saying why.
- Measure quantitative claims through a reachable data source and cite the query and run date.
- Deduplicate findings raised by more than one sub-agent.
- Never mutate external state.
- Omit empty sections.
- State each fact once and lead with conclusions.
