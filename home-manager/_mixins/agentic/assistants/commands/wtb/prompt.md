## Want to Buy

Announce a pull request in Slack. Post exactly `:wtb2 <pr-url> - <pr-title>` and nothing else.

Input: `$ARGUMENTS` is the pull request URL, optionally followed by a channel name. Ask for the URL only if `$ARGUMENTS` is blank. The default channel is `#eng-fulfillment-automation`; a channel given in `$ARGUMENTS` overrides it.

### Authority

Human invocation of this command is the user's consent to post that one line to Slack. Nothing else is authorised.

### Process

- Invoke `less` to reload the Communication Rules before posting. Codex uses `$less`; slash-command runtimes use `/less`.
- Load the `contribution-voice` skill and follow it. It governs the structure of text published under the user's name. The `:wtb2 <pr-url> - <pr-title>` format is fixed, so apply the skill to anything you add and never to the line itself.
- Read the title with `gh pr view`. Never use raw `gh api`; use `gh-api-safe` for raw reads.
- Post the line with the Slack MCP message tool. `:wtb2` is a custom emote. Reproduce it verbatim, never as a Unicode emoji.
- The Slack MCP is attached to the work agent profile only. If it is unavailable, print the line for the operator and say why.
- If the pull request is a draft, post anyway and say it is a draft in the report.

### Output

Report the channel, the posted line, and the thread timestamp if the tool returns one.
