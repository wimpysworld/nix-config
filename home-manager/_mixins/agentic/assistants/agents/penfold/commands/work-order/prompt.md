## Work Order

Write the user's personal work order for one Linear cycle as a Linear document, then wire that document to every issue it orders. The user runs this at the start of a cycle to fix the order of their own work, and re-runs it when the plan changes.

This command serves work only: the `FUL` team by default. Skip issues from any other team.

Input: `$ARGUMENTS` is the cycle number, optionally followed by a team name or key. If the cycle number is blank, stop and ask for it. Resolve the user at run time from the authenticated Linear identity; never hard-code an identifier.

Load the `contribution-voice` skill before writing the document body or any comment. All of it publishes under the user's name. Load the `sizing` skill for the size scale; never invent one, and never estimate in days or weeks.

### Process

**1. Schedule first, when asked.** When the user names issues to pull into the cycle, set the cycle on each one before ordering anything, and set the state to Todo only when the user asks for it. Change no other field. An issue scheduled here joins the gather in step 2.

**2. Gather the work.** Call `list_issues` with the resolved team, `assignee: "me"`, and the cycle. Request `title`, `url`, `status`, `estimate`, `priority`, `project`, and `description`. Read every description in full. The ordering evidence lives in the issue bodies, not in the fields.

**3. Order the issues into waves.** A wave is a set of issues the user can work at the same time. Derive the order from four sources:

- Recorded blocking relations. An issue that is blocked starts no earlier than the wave after its blocker.
- Each description's `Dependencies` section. A blocker stated in prose counts as a blocker even when no relation records it. Read every `Dependencies` section before ordering: missing one forced a published correction.
- File overlap named in the descriptions. Two issues that edit the same package stay separate pull requests, placed in the same wave or in sequence. Never merge them into one.
- The user's stated priority theme for the cycle, for example "CI fixes first". Ask for the theme when the user gave none.

**4. Write the document.** Title it `<user first name>'s Cycle <n> work order`. Never a bare team-wide title: the document orders one person's work, and a team-wide title misleads every other reader. Parent the document on the cycle: `save_document` takes `cycle` set to the number and `team` set to disambiguate it.

The body lists each wave, the issues in it with a size and a one-line reason, the hard sequencing constraints, and any timing caveat.

**5. Upsert, never duplicate.** Before creating anything, call `list_documents` filtered to the team and find this cycle's work order. `list_documents` has no cycle filter, so match on the title. When the document exists, patch it: `save_document` with `id` and `patch`. When it does not, create it. Never create a second document for one cycle. The document slug ID is durable and survives a retitle, so the links already on the issues keep working.

**6. Wire the document to every ordered issue.** For each issue in the order:

- `save_issue` with `links` set to one entry pointing at the document. `links` is append-only and upserts by URL, so a re-run adds no duplicate.
- `save_comment` with one comment naming the issue's wave and its constraint, ending with a link to the document. One comment per issue. On a re-run, update that comment by passing its `id`; never add a second.

**7. Ask once.** Show the full document body, every per-issue comment, and every scheduling change from step 1. Ask for approval, then act. This publishes under the user's name across the whole cycle's issues, and there is no cheap undo. This is the only question the command asks.

**8. Report** the document URL, the waves and their issues, and the issues that changed cycle or state.

### Authority

Human invocation of this command is consent to create or patch the one cycle work order document, to add the link attachment and the comment on each ordered issue, and to set the cycle and state on the issues approved at the gate. Nothing else. Never close an issue, never cancel an issue, never edit any other issue field, and never touch GitHub or Slack.

### Output

Document body:

```markdown
## Wave 1

* <Issue key> <Issue title> - <size on the `sizing` scale>. <One-line reason it is in this wave.>

## Wave 2

* <Issue key> <Issue title> - <size>. <One-line reason.>

## Sequencing

* <Issue key> lands before <Issue key>: <the constraint>.

## Timing

* <Caveat that changes when the work starts or finishes. Omit the section when there is none.>
```

Per-issue comment:

```markdown
Wave <n> of the cycle <n> work order. <The constraint that puts it there, in one sentence.>

<document url>
```

Final report:

```markdown
Document: <url>

| Wave | Issues |
| ---- | ------ |
| 1    | <keys> |

Scheduled: <issues moved into the cycle, or none>
```

### Constraints

- One document per cycle. A re-run patches it; it never creates a second.
- Title the document with the user's first name. Never a team-wide title.
- One comment per issue. A re-run updates that comment by `id`.
- Never explain the sizing scale in the document or in a comment. The reader sees a size per issue and nothing more.
- Never estimate in days or weeks.
- Set the cycle and the state only on issues the user named, only in the resolved team.
- Ask once, at the gate, and nothing else.
- British spelling. No hedging language.
