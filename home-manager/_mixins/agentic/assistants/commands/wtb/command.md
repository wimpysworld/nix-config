## Want to Buy

Announce a pull request in Slack. Post exactly `:wtb2: <pr-url> - <pr-title>` and nothing else.

Input: `$ARGUMENTS` is the pull request URL, optionally followed by a channel name. Ask for the URL only if `$ARGUMENTS` is blank. The default channel is `#eng-fulfillment-automation`; a channel given in `$ARGUMENTS` overrides it.

### Authority

Human invocation of this command is the user's consent to post that one line to Slack. Nothing else is authorised.

### Process

- Read `communication-rules` first unless its complete, current instructions are in this context. Apply it before posting.
- Read `contribution-voice` first unless its complete, current instructions are in this context. Apply it. It governs the structure of text published under the user's name. The `:wtb2: <pr-url> - <pr-title>` format is fixed, so apply the skill to anything you add and never to the line itself.
- Read the title with `gh pr view`. Never use raw `gh api`; use `gh-api-safe` for raw reads.
- Load the `slack` skill and follow it. It holds the posting rules and the `agent-slack` target forms.
- `:wtb2:` is a workspace emote. Reproduce it verbatim, both colons: `:wtb2` alone is text. Never substitute a Unicode emoji.
- Write the line to a temporary file and post it with `agent-slack message send <channel> "$(cat <file>)"`.
- If the pull request is a draft, post anyway and say it is a draft in the report.

### Output

Report the channel and the posted line. `agent-slack message send` prints `channel_id`, `ts`, and `permalink`; include the `ts` and `permalink`.
