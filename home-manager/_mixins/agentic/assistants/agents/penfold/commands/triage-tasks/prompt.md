## Triage Tasks

Work the Linear issues waiting in Triage in bulk. This command orchestrates; it never researches an issue and never writes to Linear itself. One fresh sub-agent per issue does both.

Input: `$ARGUMENTS` is how many issues to process this run, or `all`. Default to 5 when blank. This is a fan-out of fan-outs: each issue spawns `research-task`, which itself fans out across Linear, GitHub, Slack, and the web, so twenty issues is easily hundreds of sub-agents. The bound is the point. Never exceed it.

Command invocation: use the current provider's command prefix. Codex uses `$command`; slash-command runtimes use `/command`. The steps below name commands without a prefix.

### Process

**1. Find the queue.** Run two bounded sweeps, both gated on the workflow status type `triage` and never on the status name. Resolve the user at run time from the authenticated Linear identity; never hard-code an identifier.

- Assigned to the user: one workspace-wide `list_issues` query with `assignee: "me"`. This is small and complete, and covers every team without listing any.
- Created by the user: one `list_issues` query per team the user belongs to, taken from that same identity's own team list. `list_issues` has no created-by filter, so filter the returned issues on `createdById`.

Never run an unfiltered workspace-wide triage query. In a large workspace it exceeds the tool's output limit, spills to a file, and still truncates with further pages outstanding. Narrow `fields` to what the report needs.

The two sweeps differ in coverage, so report them apart: the assignee sweep is workspace-wide, and the created-by sweep reaches only the teams it names. A missing team is then obvious.

**2. Report the batch.** List every issue found: key, title, team, and age. Then give the total found and how many this run will process, and carry straight on. This command asks the user nothing: a blank `$ARGUMENTS` takes the default of 5, and an empty queue is reported before the run stops.

**3. Group by parent.** `update-task` edits a parent's `Child issues` list, so two children of one parent updated at the same time clobber the parent. Put every child of one parent into one cohort and run its members in sequence. Different cohorts and unparented issues run in parallel.

**4. Spawn one fresh sub-agent per issue.** Never research an issue or write to Linear in this context. Never hand two issues to one sub-agent. Give each sub-agent the issue key and this instruction set:

1. Load and apply the `research-task` skill to the issue key.
2. Run `update-task <issue key>` in the same context. `research-task` files nothing, so `update-task` must see that research as its own session in order to have anything to merge. A sub-agent that runs only one of the two has done nothing useful.
3. Where the research concludes the issue is a duplicate, is obsolete, or should be dropped, report that as a recommendation and change nothing.
4. Return a short report only: issue key, what changed, the new status, and any recommendation. No research detail.
5. Send one progress message to the parent when research completes and `update-task` starts.
6. Hard deadline 20 minutes for the issue. On reaching it, report the issue key and what is done, then stop.

Human invocation of this command is consent to research and update the issues in the batch, and nothing else: no cancelling, no closing, no creating issues, no GitHub, no Slack. State that authority in every sub-agent packet, as `delegate-task` requires, and name `research-task` and `update-task` in it.

**5. Report.** Each issue ends in Backlog, because `update-task` promotes a `triage`-type status as part of its work. An issue whose sub-agent failed stays in Triage and is picked up by the next run, so re-running this command is safe.

### Output

```markdown
Assigned sweep: workspace-wide
Created-by sweep: <team>, <team>

| Issue | Changed | Status | Recommendation |
| ----- | ------- | ------ | -------------- |
| <KEY> | <one line> | <new status> | <or leave empty> |

Failed:
- <KEY> - <why it failed>. Still in Triage.

Left in Triage: <n>
```

### Constraints

- Orchestrate only. Never research an issue or write to Linear in this context.
- One issue per sub-agent, one sub-agent per issue.
- Members of a parent cohort run in sequence. Never run two children of one parent at once.
- Never cancel, close, or delete an issue. A duplicate, obsolete, or droppable issue is reported as a recommendation, because that call is the user's.
- Never create an issue, and never touch GitHub or Slack.
- Restate the authority in every sub-agent packet.
- Ask the user nothing. A blank `$ARGUMENTS` takes the default; an empty queue is reported, then the run stops.
- British spelling. No hedging language.
