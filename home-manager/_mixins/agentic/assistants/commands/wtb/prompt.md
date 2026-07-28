## Want to Buy

Announce a pull request in Slack. Post exactly `:wtb2: <pr-url> - <pr-title>` and nothing else.

Input: `$ARGUMENTS` is the pull request URL, optionally followed by a channel name. Ask for the URL only if `$ARGUMENTS` is blank. The default channel is `#eng-fulfillment-automation`; a channel given in `$ARGUMENTS` overrides it.

### Authority

Human invocation of this command is the user's consent to post that one line to Slack. Nothing else is authorised.

### Process

- Invoke `less` to reload the Communication Rules before posting. Codex uses `$less`; slash-command runtimes use `/less`.
- Load the `contribution-voice` skill and follow it. It governs the structure of text published under the user's name. The `:wtb2: <pr-url> - <pr-title>` format is fixed, so apply the skill to anything you add and never to the line itself.
- Read the title with `gh pr view`. Never use raw `gh api`; use `gh-api-safe` for raw reads.
- Load the `slack` skill and follow it. It holds the posting rules and the `slack-post` target forms.
- `:wtb2:` is a workspace emote. Reproduce it verbatim, both colons: `:wtb2` alone is text. Never substitute a Unicode emoji.
- Resolve the channel to an ID, then write the line to a temporary file and post it with `slack-post <channel-id> --body-file <file>`.
- If the pull request is a draft, post anyway and say it is a draft in the report.

### Output

Report the channel and the posted line. `slack-post` prints the channel ID and the message `ts`; include the `ts`.
