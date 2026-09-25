## Audit Tasks

Assess a Linear project's Backlog and Todo issues, then apply only changes that the user explicitly approves.

Input: `$ARGUMENTS` is one required Linear project name or URL, including a project's `/issues` URL.
On Codex, use the user's accompanying text as the argument.
If the argument is absent, invalid, or ambiguous, ask for one project and stop.

### Authority and execution

This command preserves caller context, not a Penfold persona or coordinator authority.
Only the coordinator dispatches one Penfold research worker per issue.
If a worker receives the whole command, return a bounded dispatch request to the parent and stop.
Load `delegate-task`, `task-tracker` and its Linear reference, `sizing`, `communication-rules`, and `contribution-voice` before dependent work.
Use authorised read-only tools for network research, including the Linear MCP for Linear reads.
The first phase makes no external writes, including comments, documents, fields, estimates, priorities, or statuses.
Local report files are the sole write exception before approval.
Load `review-report-path` to allocate an exclusive run for `audit-tasks.md` and issue-specific source files outside the repository.
Do not invoke `update-task`, `triage-tasks`, or generated command launch wrappers.
Never search private Slack without separate user consent.

### 1. Resolve and enumerate

Resolve the project against the connected Linear workspace, then show its name, URL, teams, and audit timestamp.
Confirm an ambiguous match before proceeding, and never infer a workspace from the current repository.
Read the current project description and relevant scope documents, including explicit exclusions.
Resolve each team's live workflow statuses, priority taxonomy, and estimate configuration.
Interpret Backlog and Todo as status types `backlog` and `unstarted`, not literal status names.
Read every page of non-archived project issues in those types, with project and status filters.
Deduplicate by issue ID across pages and parent/child discovery, retaining each eligible parent and child once.
Read related parents and children as context without adding inactive or out-of-project issues to the audit queue.
Exclude completed, cancelled, duplicate, started, and triage issues from the target queue.
Report query failures and incomplete pagination as coverage gaps, never as an empty or complete queue.
If the complete queue is empty, report that result and stop.
Record each target's ID, URL, team, parent, status, estimate, priority, and `updatedAt` as the initial baseline.

### 2. Dispatch read-only assessment

Dispatch one fresh Penfold worker for each target, with at most five audit workers active at once.
Keep at most twelve workers active globally across all tools and workflows, and wait for capacity before dispatch.
If Penfold or delegation is unavailable, report the blocker rather than silently substituting another assessor.
Supply the issue, project scope with sources, live taxonomies, baseline, parent/child context, authorised tools, and an exclusive source-file path.
Give each packet a ten-minute deadline, the rules below, and an explicit prohibition on delegation and external writes.
At the deadline, require partial evidence and unresolved questions, not an unsupported decision.

Each Penfold worker must:
- Re-read the issue and select comments that establish decisions, changed requirements, completion claims, or contradictory evidence.
- Follow material links into code, pull requests, deployment records, and telemetry with available authorised read-only tools.
- Use BigQuery only when an actual authorised query tool or query connection exists, not merely a dashboard or catalogue.
- Keep research bounded to this issue and its material dependencies, without broad unrelated searches.
- Record citation URLs and observation dates for material facts, plus units and time windows for measurements.
- Distinguish merged code from deployed fixes, and check the affected environment before claiming that a fix resolves the issue.
- Recheck apparent conflicts against current project scope and subsequent decisions, rather than trusting stale issue text.
- Decide current relevance: Yes for supported remaining in-scope work, No for supported obsolete, duplicate, resolved, or excluded work.
- Return Unknown when missing access, contradictory evidence, or unverified deployment prevents a decision. Absence of evidence is never No.
- Size only remaining work with `sizing`, using the live estimate mapping, never days or weeks.
- Leave parent tracking issues unestimated, and avoid counting child work again in the parent.
- Propose priority from the live taxonomy using impact, dependencies, and urgency, with a short reason.
- Use the highest supported child priority for a tracking parent. Treat incomplete child evidence as a gap.
- For No, propose cancellation, never completion. Use N/A for size and priority unless evidence supports an explicit change.
- Keep unknown estimates or priorities unresolved rather than inventing values or treating them as zero.
- Draft one factual comment of one to three sentences, with material citation links and dates, without claiming that proposed changes occurred.
- Return the decision, reasons, exact proposed field values, verbatim draft comment, source map, access gaps, and latest baseline.
- Preserve relevant comment IDs, timestamps, and content for the approval conflict check. Launch no agents.

### 3. Present evidence and exact proposals

Reconcile parent/child conclusions and scope conflicts, requesting bounded Penfold rechecks where necessary.
Move every unresolved assessment to a separate Unknown/access-gaps list, with issue links and the evidence needed to decide.
Show only supported Yes/No decisions in this table, and label all new values as proposals:

| Issue | Description | Relevant? (Yes/No) | New size | New priority |
| --- | --- | --- | --- | --- |
| [KEY](issue-url) | Short description | Yes or No | Proposed size, unestimated, or N/A | Proposed priority or N/A |

Below the table, give concise dated evidence with citations for each issue.
Show each issue's exact old-to-new estimate, priority, and status values, including IDs or numeric mappings needed for writes.
Mark unchanged fields explicitly, and distinguish an approved estimate removal (`null`) from N/A, which means no estimate change.
Show each verbatim proposed comment and the reason for each proposed cancellation.
Preserve the detailed source map in the report, and provide its path when the evidence exceeds the response budget.
Never hide proposed comments or changes in an unread file. Present them in manageable batches before requesting approval.
Ask one explicit gate: "Do you approve these exact estimates, priorities, statuses, and verbatim comments for the named issues or confirmed batch?"
Accept approval only for the shown issue-specific changes. A partial approval covers only named issues and approved operations.
If approval is declined or absent, stop without external writes.

### 4. Apply only approved changes

The coordinator performs this narrow write phase, not the read-only research workers.
Before each mutation, re-read the issue, `updatedAt`, project scope, relevant comments, and applicable taxonomy.
If state, scope, comments, membership, taxonomy, or `updatedAt` conflicts with the approved baseline, skip the issue and report why.
Skip issues that are archived or no longer in `backlog` or `unstarted`, including completed or cancelled issues.
Apply the Linear reference's workspace guard when Git evidence was used.
Serialise all writes for a parent and its children, including comments, and track changes made by this approved batch.
Send only approved changed fields, and post only the approved verbatim comment. Never rewrite descriptions, labels, relations, or assignees.
Recheck before the comment write, allowing only baseline changes that the current approved operations caused.
Do not repeat an identical existing comment. After an uncertain write response, verify the result before any retry.
Report applied, failed, or skipped operations per issue with URLs, including partial success and comments not posted.
Leave conflicts for fresh review and approval. Never add claims, silently change proposals, or roll back unrelated edits.
