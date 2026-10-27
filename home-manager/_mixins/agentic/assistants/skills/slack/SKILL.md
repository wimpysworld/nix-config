# Slack

Read, search, and write in Slack with `agent-slack` from `PATH`. Run `agent-slack --help` or `<subcommand> --help` before guessing a command or flag.

## Environment and authentication

On work (`cg`) hosts, Nix provides `agent-slack` on `PATH` with `SLACK_TOKEN` (`xoxp-` user token) and `AGENT_SLACK_NO_UPDATE_CHECK=1` preconfigured.

- Verify authentication with `agent-slack auth test`. Do not rely on `agent-slack auth whoami`, which checks `credentials.json` rather than `SLACK_TOKEN`.
- Never run `curl ... install.sh`, `npm i -g agent-slack`, `agent-slack auth import-*`, or `agent-slack update`.
- When `agent-slack` is missing from `PATH` (for example on a non-work host), print the exact `agent-slack` command for the operator to run.
- Because authentication uses a standard `xoxp-` user token rather than browser `xoxc`/`xoxd` session tokens, undocumented session endpoints (`message draft`, `later`, `unreads`, and `workflow preview|get|run`) are unavailable.
- For compose-only or draft requests (such as `draft-comment`), return the proposed text directly in the conversation without calling Slack.

## Safety and authority

- Read and search freely.
- Perform write actions only when explicitly requested: `message send`, `message edit`, `message delete`, `message react add|remove`, `message scheduled cancel`, `message compose`, `channel new|invite|mark`, `user dm-open`, and `canvas create|edit`.

## Reading and searching

Prefer a Slack message URL when one is available. Pass a message URL unchanged and never hand-convert the `p<digits>` path timestamp.

```bash
# Single message and thread summary
agent-slack message get "https://workspace.slack.com/archives/C0ABEN38TRB/p1785267943715149"

# Full thread root and replies
agent-slack message list "https://workspace.slack.com/archives/C0ABEN38TRB/p1785267943715149"

# Recent channel history
agent-slack message list "#eng-fulfillment-automation" --limit 20

# Search messages or files
agent-slack search messages "query" --channel "#eng-fulfillment-automation" --limit 20
agent-slack search files "query" --limit 10
agent-slack search all "query" --after 2026-01-01

# Resolve channels, users, and canvases
agent-slack channel list --limit 100
agent-slack channel list --all --limit 100
agent-slack user get "@handle"
agent-slack user list --limit 200
agent-slack canvas get "https://workspace.slack.com/docs/T123/F456"
```

Use output limits such as `--limit`, `--max-body-chars`, and `--max-content-chars` to avoid unnecessary context.

## Sending and mutating

```bash
agent-slack message send <target> "$(cat <file>)" [--thread-ts <ts>]
agent-slack message send <message-url> "$(cat <file>)"
```

| Target | Result |
| --- | --- |
| `C0ABEN38TRB` | Post at the top of that channel or DM |
| `'#eng-fulfillment-automation'` | Post to a channel by name |
| `U08V6EV65TQ` | DM that person |
| `https://acme.slack.com/archives/C.../p1785267943715149` | Reply inside that message's thread |

Other explicit write commands:

```bash
# Edit, delete, or react to a message
agent-slack message edit <message-url> "$(cat <file>)"
agent-slack message delete <message-url>
agent-slack message react add <message-url> eyes
agent-slack message react remove <message-url> eyes

# Create or edit a canvas from Markdown
agent-slack canvas create --file <path> --title "Title" [--channel <channel>]
agent-slack canvas edit <canvas-url-or-id> --file <path>
```

Use `--no-unfurl` with `message send` when the user wants link and media previews suppressed. Inside auto-converted lists, use Slack's `<URL|label>` syntax because CommonMark `[label](URL)` links are not converted into labelled link elements.

## House rules

**Keep it short.** Slack is chat, not a document. One or two sentences is normal. Use no headings, no bullet lists unless genuinely needed, and no sign-off. Nobody wants an essay in Slack, and a long message reads as generated even when every fact in it is right.

**Reply in the thread when the target is a thread.** Passing a message URL to `agent-slack message send <message-url> <text>` automatically replies in that message's thread. Pass `--thread-ts <ts>` when targeting a channel ID or name.

**Resolve a channel name when needed.** `agent-slack` resolves `#name` or `name` through message search and `conversations.list`. When targeting a quiet or private channel where name lookup can miss, resolve its ID first with `agent-slack channel list`.

**Write the body to a file.** Write the message body to a temporary file and pass `"$(cat <file>)"` to `agent-slack message send` so quotes, backticks, and newlines survive.

**Apply `communication-rules` before drafting.** Read it first unless its complete, current instructions are already in this context.

**Apply `contribution-voice` before drafting.** Read it first unless its complete, current instructions are already in this context. Anything posted publishes under the user's name. Run its cut pass, then cut again for Slack.

**Report the `ts` and `permalink` that `agent-slack message send` prints.**

## References

- Read [references/targets.md](references/targets.md) when choosing between a message URL, channel, or user target, or when resolving multiple workspaces.
- Read [references/output.md](references/output.md) when handling returned message or canvas metadata, resolved users, or downloaded and failed attachments.
