## Update Work Order

Apply the user's instructions to the existing cycle work order document and keep the document truthful. The user runs this mid-cycle when the plan changes, for example "add FUL-123 and FUL-321, and FUL-456 has been deprioritised".

This command serves work only: the `FUL` team by default. Skip issues from any other team.

Input: `$ARGUMENTS` is the instructions, optionally naming a cycle or team. If the instructions are blank, stop and ask for them. When no cycle is named, resolve the current cycle. Resolve the user at run time from the authenticated Linear identity; never hard-code an identifier.

Load the `contribution-voice` skill before writing any document patch or comment. All of it publishes under the user's name. Load the `sizing` skill for the size scale; never invent one, and never estimate in days or weeks. Load the `work-order-format` skill for the document contract; every patch preserves it.

### Process

**1. Locate the document.** Call `list_documents` filtered to the team and match on the title from the `work-order-format` skill. When the document does not exist, stop and tell the user to run `work-order-create`.

**2. Read the state.** Read the document and the user's cycle issues. Read the full description of every issue the instructions add. A `Dependencies` section stated in prose counts as a blocker even when no relation records it.

**3. Plan the additions.** When an added issue is not in the cycle, set its cycle. Insert the issue into an active wave - one with at least one issue not Done - only when every blocker sits in an earlier wave and no wave-mate touches the same package or files. Otherwise append a new wave at the end with its dependency line. Give each added issue a size and a one-line reason. Wire it like `work-order-create` does: `save_issue` with `links` set to one entry pointing at the document, and one comment naming its wave and constraint, upserted by `id` on a re-run.

**4. Plan the deprioritisations.** Remove the issue from its wave and append it to `## Deferred` with the date and a one-line reason. Update that issue's existing work-order comment to state the deferral. Clear the issue's cycle only when the instruction says to drop it from the cycle.

**5. Patch, never resend.** Edit the document only with `save_document` using `id` and `patch`. Never resend the full body. Never renumber an existing wave. When a wave empties, remove its section and never reuse its number.

**6. Ask once.** Show every document patch, every comment, and every cycle change. Ask for approval, then act. This is the only question the command asks.

**7. Check drift, report only.** Compare both directions: issues assigned to the user in the current cycle that the document does not mention, and issues in the document that left the cycle or the user's assignment. List them in the final report under `Drift`. Propose nothing and change nothing: drift feeds the user's next instruction.

**8. Report** the document URL, the changes, and the drift lists.

### Authority

Human invocation of this command is consent to patch the one cycle work order document, to add or update the link attachment and the comment on the issues the instructions name, and to set or clear the cycle on the issues the instructions add or drop. Nothing else. Never close an issue, never cancel an issue, never edit any other issue field, and never touch GitHub or Slack.

### Output

Final report:

```markdown
Document: <url>

Changes:

* Added: <issue key> to Wave <n>, or none
* Deferred: <issue key>, or none
* Cycle: <issue key> set or cleared, or none

Drift:

* In the cycle, not in the document: <keys, or none>
* In the document, not in the cycle: <keys, or none>
```

### Constraints

- Edit the document only by patch. Never resend the full body.
- Never renumber an existing wave, and never reuse a removed wave's number.
- Every issue in a wave runs in parallel with every other. Sequencing prose never enters a bullet.
- One comment per issue. An update edits that comment by `id`.
- Drift is report-only. It changes nothing without a new instruction.
- Never explain the sizing scale in the document or in a comment.
- Never estimate in days or weeks.
- Ask once, at the gate, and nothing else.
- British spelling. No hedging language.
