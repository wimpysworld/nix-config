## Triage Tasks

Work the Linear issues waiting in Triage in bulk. This command orchestrates; it never researches an issue and never writes to Linear itself. One fresh sub-agent per issue does both.

Input: `$ARGUMENTS` is how many issues to process this run, or `all`. Default to 5 when blank. This is a fan-out of fan-outs: each issue spawns `research-task`, which itself fans out across Linear, GitHub, Slack, and the web, so twenty issues is easily hundreds of sub-agents. The bound is the point. Never exceed it.

Command invocation: use the current provider's command prefix. Codex uses `$command`; slash-command runtimes use `/command`. The steps below name commands without a prefix.

### Process

**1. Find the queue.** List every team visible in the connected workspace, then search each team for issues whose workflow status type is `triage`, assigned to the user or created by the user. Gate on the status type, never the status name. Resolve the user at run time from the authenticated Linear identity; never hard-code an identifier. Report which teams were searched, so a missing team is obvious.

**2. Report the batch.** List every issue found: key, title, team, and age. Then give the total found and how many this run will process, and carry straight on. This command asks the user nothing: a blank `$ARGUMENTS` takes the default of 5, and an empty queue is reported before the run stops.

**3. Group by parent.** `update-task` edits a parent's `Child issues` list, so two children of one parent updated at the same time clobber the parent. Put every child of one parent into one cohort and run its members in sequence. Different cohorts and unparented issues run in parallel.

**4. Spawn one fresh sub-agent per issue.** Never research an issue or write to Linear in this context. Never hand two issues to one sub-agent. Give each sub-agent the issue key and this instruction set:

1. Run `research-task <issue key>`.
2. Run `update-task <issue key>` in the same context. `research-task` files nothing, so `update-task` must see that research as its own session in order to have anything to merge. A sub-agent that runs only one of the two has done nothing useful.
3. Where the research concludes the issue is a duplicate, is obsolete, or should be dropped, report that as a recommendation and change nothing.
4. Return a short report only: issue key, what changed, the new status, and any recommendation. No research detail.

Human invocation of this command is consent to research and update the issues in the batch, and nothing else: no cancelling, no closing, no creating issues, no GitHub, no Slack. State that authority in every sub-agent packet and name `research-task` and `update-task` in it. Sub-agents run with fresh context and defer without it.

**5. Report.** Each issue ends in Backlog, because `update-task` promotes a `triage`-type status as part of its work. An issue whose sub-agent failed stays in Triage and is picked up by the next run, so re-running this command is safe.

### Output

```markdown
Teams searched: <team>, <team>

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
- Restate the authority in every sub-agent packet. Fresh context does not inherit it.
- Ask the user nothing. A blank `$ARGUMENTS` takes the default; an empty queue is reported, then the run stops.
- British spelling. No hedging language.
