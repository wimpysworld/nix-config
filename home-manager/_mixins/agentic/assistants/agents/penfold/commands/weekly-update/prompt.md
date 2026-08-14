## Weekly Update

Write one Linear project status update for every project the user worked in this week, then post a short pointer to those updates in Slack. The user runs this on a Friday, and their team reads it for progress, blockers, and what is next.

This command serves work only: the `FUL` team. Skip issues from any other team.

Input: `$ARGUMENTS` is the Slack channel to post to. If it is blank, stop and ask for the channel before doing anything else.

Load the `contribution-voice` skill before writing any update body or Slack message. All of it publishes under the user's name.

### Process

**1. Set the window.** Monday 00:00 local time to the moment this command runs. Not a rolling seven days: a Friday afternoon re-run must not pull in last Friday.

**2. Find the work.** Call `list_issues` with `team: "FUL"`, `assignee: "me"`, and `updatedAt` set to the window start. Request `title`, `url`, `status`, `statusType`, `completedAt`, `estimate`, `priority`, `cycle`, and `project`. Ownership means assignee: an issue the user created but does not own stays out.

**3. Group by project.** A project with no matching issue is skipped and gets no update.

**4. Compose one update per project.** The body is markdown. One bullet per issue updated or completed in the window, one short sentence each, stating what moved rather than what the issue is about. The bullet marker is an emoji chosen by the issue's status:

| Status                     | Marker |
| -------------------------- | ------ |
| `completed`                | ✅     |
| `started`                  | 🚧     |
| `started`, named In Review | 👀     |
| `cancelled`                | ❌     |
| `cancelled`, named Duplicate | ♻️   |
| `backlog`                  | 📋     |
| `unstarted`                | 🔜     |
| `triage`                   | 🆕     |

Take the marker from `statusType`. In Review and Duplicate are the two exceptions: each shares a type with its neighbours and is told apart only by name, so match the name first, then fall back to the type.

**5. Propose what is next.** Add an `Up Next` section only when open issues remain in that project. Omit it otherwise, and never stub it.

Pick the target cycle from the `FUL` team. When the run falls on the last Thursday, Friday, Saturday, or Sunday of the current cycle, the target is the next cycle. Otherwise the target is the current cycle. When no cycle exists, skip the cycle logic and build the list from the backlog alone, as below.

Start the list with what is scheduled: the project's open issues assigned to the user in the target cycle. Then propose additions from the user's backlog, that is, the project's open issues assigned to the user and not in the target cycle, when the scheduled work leaves capacity free.

Load the `sizing` skill and use its scale; do not invent one. Order the backlog candidates by priority, then by size ascending, and fill the capacity that the scheduled work leaves, roughly one week in total: about 4 XS, or 2 S, or 1 M. The scale works silently. Never explain the sizing guidelines, the scale, or the capacity arithmetic in the update body; the reader sees the issue list with a size per issue and nothing more. The additions are a proposal until the gate in step 7 approves them, and the user trims or extends the list there. The posted body presents one plain list of scheduled work and never describes it as a proposal, a draft, or something to cut.

**6. Propose the health.** For each project propose `onTrack`, `atRisk`, or `offTrack`, with a one-line reason. Never default silently.

A goodwill collector has no schedule to be behind. The flaky CI project is one: reports accumulate there and the user fixes them as time permits, so a backlog of open reports is its normal state. Propose `onTrack` for it, always.

**7. Ask once.** Show every project update in full, the proposed health for each, the proposed cycle additions marked as such, and every Slack message. Ask for approval, then act. This publishes under the user's name to two systems, one of them a team channel, and there is no cheap undo. This is the only question the command asks.

**8. Schedule the approved additions.** Set each approved addition's cycle to the target cycle, and change nothing else on the issue. Scheduling runs before posting, so the posted `Up Next` states only scheduled work.

**9. Post the Linear updates.** `save_status_update` with `type: "project"`, the project, the agreed body, and the agreed health.

**10. Post to Slack.** Load the `slack` skill and follow it.

- Resolve the channel argument to a channel ID with `slack_search_channels` first. A name only reaches a public channel, so a private channel fails without this.
- Parent message: `My weekly update for <date> 🧵`, with a British date such as `31 July 2026`. It posts as the user, so it does not name them.
- Reply in that message's thread with one reply per project, in this structure: `<health emoji> <update-url|Project name>: <status and impact>. <decision, blocker, or next action>.` Two sentences at most, about 50 words. The health emoji is ✅ for `onTrack`, ⚠️ for `atRisk`, and 🛑 for `offTrack`.
- Remove background, work history, implementation detail, evidence, and subtasks from the reply. Linear carries that information.
- Write each body to a file and post it with `slack-post`. To reply in the thread, pass the parent message's URL unchanged; never hand-convert a timestamp.
- The skill's brevity rule governs. No headings, no bullet lists, no sign-off. The substance lives in Linear; Slack carries the headline.

**11. Report** the projects updated, the health set for each, the issues scheduled into the target cycle, and both Slack message links.

### Authority

Human invocation of this command is consent to create the Linear project status updates, to set the cycle on the additions approved at the gate, and to post the Slack parent message and its thread replies, once the gate is passed. Nothing else. Never edit any other issue field, never change a project's fields, and never post anywhere but the channel given.

### Output

Project update body:

```markdown
✅ <What moved on this issue, in one sentence.>
🚧 <One sentence.>
👀 <One sentence.>

## Up Next

* <Issue title> - <size on the `sizing` scale>
```

Final report:

```markdown
| Project | Health                     | Update |
| ------- | -------------------------- | ------ |
| <name>  | <onTrack\|atRisk\|offTrack> | <url>  |

Slack: <parent message url>
Replies: <one reply url per project>
Scheduled: <issues added to the target cycle, or none>
```

### Constraints

- One bullet per issue, one short sentence. State what changed, not what the issue is about.
- `Up Next` additions are a proposal until the gate approves them. Never estimate in days or weeks.
- Set only the cycle field, only on additions approved at the gate, only in the `FUL` team.
- Never explain the sizing scale or the capacity assumption in an update.
- Skip a project with no matching issues. Never post an empty update.
- Never hard-code a Slack channel or a channel ID.
- Ask once, at the gate, and nothing else.
- British spelling. No hedging language.
