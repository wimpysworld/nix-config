## Create Project

Find or create one Linear project, then stop. This command exists so an unattended caller can guarantee a project is there before it files issues into it. It never writes a full description, never touches issues, and never asks a question it can answer from its own input.

Input: $ARGUMENTS is the project name, optionally followed by a team name or key. If the name is blank, stop and ask for it. If no team is given and the workspace has more than one team, ask which team.

Authority: invocation by a human, or by another command, is consent to create the one named project. Not its issues, not its membership, not GitHub, not Slack.

### Process

**1. Find first**

Call `list_projects` with `query` set to the name and read the results. Match on the exact name. If an open project with that exact name exists, report it and stop; the work is already done.

A closed project is not a match. `list_projects` returns `status` with a `type` field: type `completed` or `cancelled` means closed. Gate on the status type, never the status name. When every same-named project is closed, create a new one. A caller rolls a perpetual project over by closing it and expects the next run to create the replacement, so without this rule `watch-ci` would file this quarter's flakes into last quarter's closed project.

Never fuzzy match, and never create a project whose name only resembles the request. A near miss creates a second project the caller cannot find on its next run.

**2. Resolve the team**

Take the team from $ARGUMENTS when it is there. Otherwise call `list_teams`: one team means use it, more than one means ask. Do not guess.

**3. Resolve the dates**

When the name ends with `: Cycle <N>`, call `list_cycles` with that team's `teamId` and find cycle `<N>`. `type` filters to `current`, `previous`, or `next`, so omit it and match on the cycle number. Set the project's `startDate` and `targetDate` to the cycle's start and end dates.

When the name carries no cycle and the caller supplied no dates, leave both unset.

**4. Create**

Call `save_project` with no `id`, so it creates:

- `name` - the given name, verbatim.
- `addTeams` - the resolved team.
- `lead` - `"me"`.
- `startDate` and `targetDate` - from step 3, when resolved.
- `description` - the one-line placeholder below.

Placeholder description, verbatim:

```markdown
Description written by `draft-project-description` once this project has issues.
```

Do not attempt the full description template. The project has no issues yet, so there is nothing to describe.

**5. Report**

Report and stop. Do not ask for approval at any point; a caller running unattended cannot answer.

### Writing to Linear

- Set a precise `targetDate` and leave `targetDateResolution` unset. `month` snaps the date to the month end, and the resolution cannot be cleared once set; the enum offers only `halfYear`, `month`, `quarter`, and `year`. The same holds for `startDateResolution`.
- `save_project` has no cycle field. Cycles belong to issues, not projects. A cycle only supplies this project's dates.
- This MCP has no favourites or star tool, and `save_project` has no members field. Report both as manual steps for the operator rather than claiming them done.

### Output Format

```markdown
## Project

* **Name** - <name>
* **URL** - <url or ID>
* **Team** - <team>
* **Lead** - <lead>
* **Dates** - <start> to <target>, or `unset`
* **Result** - found existing, created, or created because the same-named project was closed

## Manual

* <step the operator must do: add members, favourite the project. Omit when none.>
```

### Constraints

- One project per run. Never create a second.
- Never create issues, milestones, or documents.
- Never rewrite the description of a project that already exists.
- British spelling, short sentences, active voice, conclusion first. The session's Communication Rules govern the rest.
