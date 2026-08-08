## Weekly Update

Write one Linear project status update for every project the user worked in this week, then post a short pointer to those updates in Slack. The user runs this on a Friday, and their team reads it for progress, blockers, and what is next.

Input: `$ARGUMENTS` is the Slack channel to post to. If it is blank, stop and ask for the channel before doing anything else.

Load the `contribution-voice` skill before writing any update body or Slack message. All of it publishes under the user's name.

### Process

**1. Set the window.** Monday 00:00 local time to the moment this command runs. Not a rolling seven days: a Friday afternoon re-run must not pull in last Friday.

**2. Find the work.** Call `list_issues` with `assignee: "me"` and `updatedAt` set to the window start. Request `title`, `url`, `status`, `statusType`, `completedAt`, `estimate`, `priority`, and `project`. Ownership means assignee: an issue the user created but does not own stays out.

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

Load the `sizing` skill and use its scale; do not invent one. Order the project's open issues by priority, then by size ascending, and fill to roughly one week of capacity: about 4 XS, or 2 S, or 1 M. The scale works silently. Never explain the sizing guidelines, the scale, or the capacity arithmetic in the update body; the reader sees the issue list with a size per issue and nothing more. The list is a proposal, not a plan and not a commitment. The user trims it at the approval gate in step 7; the posted body presents the list plainly and never describes it as a proposal, a draft, or something to cut.

**6. Propose the health.** For each project propose `onTrack`, `atRisk`, or `offTrack`, with a one-line reason. Never default silently.

A goodwill collector has no schedule to be behind. The flaky CI project is one: reports accumulate there and the user fixes them as time permits, so a backlog of open reports is its normal state. Propose `onTrack` for it, always.

**7. Ask once.** Show every project update in full, the proposed health for each, and both Slack messages. Ask for approval, then act. This publishes under the user's name to two systems, one of them a team channel, and there is no cheap undo. This is the only question the command asks.

**8. Post the Linear updates.** `save_status_update` with `type: "project"`, the project, the agreed body, and the agreed health.

**9. Post to Slack.** Load the `slack` skill and follow it.

- Resolve the channel argument to a channel ID with `slack_search_channels` first. A name only reaches a public channel, so a private channel fails without this.
- Parent message: `My weekly update for <date> 👇`, with a British date such as `31 July 2026`. It posts as the user, so it does not name them.
- Reply in that message's thread with one line per project: the project name and a link to its status update, nothing else.
- Write each body to a file and post it with `slack-post`. To reply in the thread, pass the parent message's URL unchanged; never hand-convert a timestamp.
- The skill's brevity rule governs. One or two sentences, no headings, no bullet lists, no sign-off. The substance lives in Linear; Slack carries the pointer.

**10. Report** the projects updated, the health set for each, and both Slack message links.

### Authority

Human invocation of this command is consent to create the Linear project status updates and to post the two Slack messages, once the gate is passed. Nothing else. Never edit an issue, never change a project's fields, and never post anywhere but the channel given.

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
Thread: <reply url>
```

### Constraints

- One bullet per issue, one short sentence. State what changed, not what the issue is about.
- `Up Next` is a proposal, never a commitment. Never estimate in days or weeks.
- Never explain the sizing scale or the capacity assumption in an update.
- Skip a project with no matching issues. Never post an empty update.
- Never hard-code a Slack channel or a channel ID.
- Ask once, at the gate, and nothing else.
- British spelling. No hedging language.
