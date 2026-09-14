## Plan Work Order

Shortlist the most impactful open issues from the projects the user names, fitted to a capacity target calculated live from Linear. The user runs this at the end of a cycle, and hands the shortlist to `work-order-create` for the next cycle.

This command serves work only: the `FUL` team by default. Skip issues from any other team.

This command is read-only. It changes nothing in Linear, posts nowhere, and asks no gate question.

Input: `$ARGUMENTS` is one or more project names, optionally followed by a priority theme for the next cycle, for example "CI fixes first". If no project is named, stop and ask for one. Resolve the user at run time from the authenticated Linear identity; never hard-code an identifier.

Load the `sizing` skill for the size scale; never estimate in days or weeks.

### Process

**1. Calculate the capacity target, live, on every run.**

- The window is the four most recent complete Monday weeks, starting Monday 00:00 local time. Show the current partial week separately and exclude it from the average.
- Fetch the user's completed `FUL` issues in the window with `list_issues`: `assignee: "me"`, `state: "completed"`, and an `updatedAt` filter wide enough to cover the whole window. Request `estimate` and `completedAt`. Bucket the issues by `completedAt` into Monday weeks.
- Sum the estimate points per week. A completion with no estimate counts zero and goes in the data note: these are legacy issues from before sizing was adopted, and they age out of the window.
- The weekly target is the mean of the four weekly sums multiplied by 0.6.
- Read the next cycle's start and end dates from Linear with `list_cycles`, and derive the cycle length in weeks from the dates. The cycle target is the weekly target multiplied by the cycle weeks, rounded to the nearest whole point.

**2. Subtract the carry-over.** The user's open issues in the named projects that are already started count as committed carry-over. List them with their points, and subtract their points from the cycle target before fitting new work.

**3. Score the candidates.** The candidates are the user's other open issues in the named projects. Score impact in this order: the user's stated theme, then Linear priority, then what the issue unblocks through its blocking relations, then the project's status and target date. Give every pick a one-line reason that names its strongest criterion.

**4. Fit.** Order the candidates by impact score and fill the remaining target with their sizes. Candidates that do not fit go below the line as alternates, still in impact order. An unestimated candidate never enters the fit list; list unestimated candidates separately for the user to size first.

**5. Report** per the output template.

### Authority

Invocation grants no mutations because none occur. The command only reads Linear. It creates nothing, patches nothing, comments nowhere, and never touches GitHub or Slack.

### Output

Final report, in this order:

```markdown
Capacity:

| Week starting | Points |
| ------------- | ------ |
| <Monday date> | <n>    |
| Mean          | <n>    |

Current partial week: <n> points, excluded from the mean.

Weekly target: <mean> x 0.6 = <n>. Cycle <n>: <start> to <end>, <n> weeks. Cycle target: <n> points.

Carry-over, already started and committed:

* <Issue key> <Issue title> - <size>, <points> points.

Remaining target after carry-over: <n> points.

Fit, in impact order:

* <Issue key> <Issue title> - <size>. <One-line reason naming its strongest criterion.>

Alternates, did not fit:

* <Issue key> <Issue title> - <size>. <One-line reason.>

Needs a size before it can be fitted:

* <Issue key> <Issue title>.

Data note: <n> completions in the window carry no estimate and counted zero: <keys>. These pre-date sizing and age out of the window.

Handoff: run `work-order-create <cycle number>` with <fitted issue keys>.
```

### Constraints

- Read-only, and no gate. The only question is for a missing project name.
- Calculate the capacity live on every run. Never reuse a remembered number.
- The four-week window and the 0.6 factor are the method's only constants. Never hard-code a velocity, a point value, or a cycle length.
- An unestimated issue never enters the fit list.
- Never estimate in days or weeks.
- British spelling. No hedging language.
