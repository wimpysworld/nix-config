## Weekly Update

Write one Linear project status update for every project the user actively worked this week, then post a headline for each update in Slack. The user runs this on a Friday, and their team reads it for progress, blockers, and what is next.

This command serves work only: the `FUL` team. Skip issues from any other team.

Input: `$ARGUMENTS` is the Slack channel to post to. If it is blank, stop and ask for the channel before doing anything else.

Load the `contribution-voice` skill before writing any update body or Slack message. All of it publishes under the user's name. Resolve the user's first name at run time from the authenticated Linear identity. Never hard-code a name or an identifier.

### Process

**1. Set the window.** Monday 00:00 local time to the moment this command runs. Not a rolling seven days: a Friday afternoon re-run must not pull in last Friday.

**2. Find the work.** Gather three sets from the `FUL` team with `list_issues`:

- issues the user created in the window, any assignee
- issues assigned to the user and updated in the window
- issues assigned to the user and completed in the window

**3. Select the projects.** A project qualifies only when at least one issue from step 2 belongs to it. A project with no qualifying issue is skipped and gets no update.

Select only real work. An updated issue counts only when the user acted on it in the window: a state change, a comment, or an edit made by the user. A touch from an automation, an integration, or another person does not count. When only updated issues qualify a project, confirm that the user acted on at least one of them before you select the project. When the evidence is unclear, keep the project and flag it at the gate in step 7.

**4. Count per project.**

- completed: the user's issues in the project completed in the window
- added: issues the user created in the project in the window, any assignee
- remaining this cycle: the user's open issues in the project scheduled in the current `FUL` cycle

**5. Resolve the work order link.** Resolve the current `FUL` cycle, then find the Linear document titled `<first name>'s Cycle <n> work order` with `list_documents` filtered to the team. `list_documents` has no cycle filter, so match on the title. That living document is the source of truth for what is done and what is planned, and it satisfies "what next". When no current cycle exists, or the document does not exist, surface the problem at the gate in step 7 instead of posting a broken link.

**6. Compose one update per project.** Use the body shape in Output. After the counts line, list the counted issues under three headings, `Completed`, `Added`, and `Remaining this cycle`, so the TPM sees the work without leaving the update. One bullet per issue: the issue title, linked to the issue. Omit a heading whose count is zero, and never stub one. The Blocked line appears only when one of the user's open issues in the project is blocked, via a blocking relation or a blocked state. Omit the line otherwise, and never stub it.

**7. Ask once.** Show every Linear update body, every Slack message, and any missing-document problem from step 5. Ask for approval, then act. This publishes under the user's name to two systems, one of them a team channel, and there is no cheap undo. This is the only question the command asks.

**8. Post the Linear updates.** `save_status_update` with `type: "project"`, the project, and the agreed body. Never pass `health`: Linear then carries the previous update's health badge, and this command cannot suppress it.

**9. Post to Slack.** Load the `slack` skill and follow it.

- Resolve the channel argument to a channel ID with `slack_search_channels` first. A bare name only reaches a public channel.
- Parent message: `My weekly update for <date> 🧵`, with a British date such as `28 August 2026`. It posts as the user, so it does not name them.
- Post one thread reply for all projects. Give each project one line: `*<update-url|Project name>* - <project status>: <n> completed, <n> added, <n> remaining this cycle`. The asterisks make the linked project name bold in Slack. Put one blank line after each project line. The project status is the project's own Linear status name, never an invented name.
- End the reply with the line `Plan: *<doc-url|<first name>'s Cycle <n> work order>*`. The asterisks make the linked document title bold in Slack.
- Write each body to a file and post it with `slack-post`. To reply in the thread, pass the parent message's URL unchanged, and never hand-convert a timestamp.
- No headings, no bullet lists, no sign-off.

**10. Report** the projects updated with their update URLs, and the Slack parent and reply links. One reply serves all projects. No health column anywhere.

### Authority

Human invocation of this command is consent to create the Linear project status updates and to post the Slack parent message and its one thread reply, once the gate is passed. Nothing else. This command mutates no issue, changes no project field, and posts nowhere but the channel given.

### Output

Project update body:

```markdown
This week: <n> completed, <n> added, <n> remaining this cycle.

**Completed**

* [<issue title>](<issue url>)

**Added**

* [<issue title>](<issue url>)

**Remaining this cycle**

* [<issue title>](<issue url>)

Blocked: <issue key> waits on <the blocker, one sentence>.

Next: [<first name>'s Cycle <n> work order](<document url>)
```

Final report:

```markdown
| Project | Update |
| ------- | ------ |
| <name>  | <url>  |

Slack: <parent message url>
Reply: <the one thread reply url>
```

### Constraints

- Skip a project with no qualifying issue. Never post an empty update.
- Never hard-code a Slack channel or a channel ID.
- Never pass `health` to `save_status_update`.
- Ask once, at the gate, and nothing else.
- British spelling. No hedging language.
