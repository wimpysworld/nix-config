## Prune Tasks

Keep only a Linear project's Backlog and Todo issues that still occur often enough, with enough impact, to be worth doing. Propose Cancel or Defer for the rest, then apply only the changes that the user approves.

This command does not ask whether work is in scope, and it does not size or prioritise. Use `audit-tasks` for that question.

Input: `$ARGUMENTS` is one required Linear project name or URL, including a project's `/issues` URL.
On Codex, use the user's accompanying text as the argument.
If the argument is absent, invalid, or ambiguous, ask for one project and stop.

### Authority and execution

This command preserves caller context, not a Penfold persona or coordinator authority.
Only the coordinator dispatches one Penfold research worker per issue.
If a worker receives the whole command, return a bounded dispatch request to the parent and stop.
Load `delegate-task`, `task-tracker` and its Linear reference, `communication-rules`, `contribution-voice`, and `review-report-path` before dependent work.
Invoking this command is consent to search Slack read-only for frequency evidence.
After the gate only, it is consent to post the approved comments, set the approved statuses, and prepend the approved Deferred sections.
It grants nothing else: never close or complete issues, create issues, write to GitHub or Slack, or change the project.
Before the gate, make no external writes. Local report files are the sole write exception.
Use `review-report-path` to allocate an exclusive run for `prune-tasks.md` and issue-specific source files outside the repository.
Do not invoke `audit-tasks`, `update-task`, `triage-tasks`, or generated command launch wrappers.

### 1. Resolve and enumerate

Resolve the project against the connected Linear workspace, then show its name, URL, teams, and run timestamp.
Confirm an ambiguous match before proceeding, and never infer a workspace from the current repository.
Resolve each team's live workflow statuses, including its canceled-type status and any status named Deferred.
Interpret Backlog and Todo as status types `backlog` and `unstarted`, not literal status names.
The queue therefore includes Deferred issues of type `backlog`, so each run re-checks earlier deferrals.
Read every page of non-archived project issues in those types, with project and status filters, and deduplicate by issue ID.
Report query failures and incomplete pagination as coverage gaps, never as an empty or complete queue.
If the complete queue is empty, report that result and stop.
Record each target's key, URL, status, and `updatedAt` as the baseline.

### 2. Dispatch read-only assessment

Dispatch one fresh Penfold worker per target, with at most five prune workers active at once.
The cap is five because ten parallel workers exhaust the GitHub API rate limit. Never exceed it.
Keep at most twelve workers active globally across all tools and workflows, and wait for capacity before dispatch.
If Penfold or delegation is unavailable, report the blocker rather than substituting another assessor.
Supply the issue, baseline, run date, decision rule, exclusive source-file path, and a ten-minute deadline.
Restate in each packet: read-only, no external writes, no delegation, and a budget of about 25 tool calls.
Restate the authorised read tools: the Linear MCP; `gh` subcommands first, then `gh-api-safe`, never raw `gh api`; BigQuery only when an actual query tool exists; Slack search through `agent-slack`.
Each worker loads `gh` and `slack` before using those tools. At the budget or deadline, it returns partial evidence and its gaps.

Each Penfold worker returns this form in under 250 words:

- **Verdict:** Keep, Defer, or Cancel, with a one-sentence reason.
- **Still relevant:** whether the defect or gap still exists on `main`, citing the file and line, or the merged pull request that fixed or removed it. Say "fixed", "no longer occurs for another reason", or "still occurs".
- **Frequency:** occurrences in the last 30 and 90 days and the last-seen date. Give each count with its source and how the worker searched.
- **Impact:** what the issue blocks when it occurs, and how badly.
- **Duplicate or merge candidate:** an issue link, or none.
- **Resume condition:** for Defer, the observable event that makes the issue worth doing again.
- **Draft comment:** one to three factual sentences with citation links. Never claim that a proposed change occurred.
- **Evidence:** URLs, one fact each.
- **Gaps:** expired logs, rate limits, or missing data, each with the search attempted.

Absence of evidence is never a Cancel on its own. An expired log (HTTP 410) or a missing data row is a gap, not a zero count.

### 3. Apply the decision rule

The coordinator re-applies this rule to every verdict and overrides a worker verdict that its own evidence fails:

- **Keep** only when the issue is still pertinent and occurred in the last 30 days with material impact.
- **Cancel** when the cause is gone, the issue is a duplicate, or the impact is negligible.
- **Defer** when the gap is real but quiet for 30 days or more. Every Defer needs a resume condition.
- **Unknown** when gaps prevent a decision. List these separately with the evidence needed to decide.

A cleanup with zero impact is Cancel, not Keep. State every override and its reason.

### 4. Present evidence and exact proposals

Show one table of supported verdicts, and label each verdict as a proposal:

| Issue | Verdict | Frequency (30d / 90d, last seen) | Resume condition |
| --- | --- | --- | --- |
| [KEY](issue-url) | Keep, Defer, or Cancel | Counts with source | Defer only, otherwise N/A |

Below the table, give dated evidence for each issue, then each verbatim proposed comment and exact target status.
For a Defer whose description is out of date, show the verbatim proposed `## Deferred (<date>)` section.
List the Unknown issues after that, with issue links, gaps, and the evidence needed.
Write the full evidence to the report file and give its path. Never hide a proposed comment or change in an unread file.
Ask one explicit gate: "Do you approve these verbatim comments, statuses, and Deferred sections for the Cancel group, the Defer group, or the named issues?"
Accept approval per verdict group or per named issue. Approval covers only the named group or issues and their shown operations.
If approval is declined or absent, stop without external writes.

### 5. Apply only approved changes

The coordinator performs this write phase, not the research workers. Serialise all writes.
Before each write, re-read the issue, its comments, and `updatedAt`.
Skip and report an issue that conflicts with the baseline or that left `backlog` or `unstarted`.
Allow only baseline changes that the current approved operations caused.

- **Cancel:** post the approved comment, then set the team's canceled-type status.
- **Defer:** post the approved comment, then set the team's Deferred status from the live workflow. If the team has no such status, keep the issue in Backlog and say so.
- **Deferred section:** when approved, prepend `## Deferred (<date>)`, state what changed, and end it with "The text below is the original."
- **Keep:** change nothing.

Never edit the original description text, labels, relations, assignee, estimate, or priority.
Do not repeat an identical existing comment. After an uncertain write response, verify the result before any retry.

### 6. Report

Report applied, skipped, and failed operations per issue with URLs, including partial success and comments not posted.
Then list what remains open in the project's Backlog and Todo statuses, and give the Deferred issues as a separate count.
When nothing remains open in Backlog or Todo, recommend that the user completes the project. Do not complete it.
