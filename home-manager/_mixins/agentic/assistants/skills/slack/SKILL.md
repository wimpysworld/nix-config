---
name: slack
description: "Use when posting, replying, or sending a DM in Slack, or when the user mentions Slack, a Slack channel, a Slack thread, or a Slack message URL. Covers the `slack-post` helper, its target forms, and channel resolution. Use even if the user only says 'post this in Slack', 'reply in the thread', or 'DM them'."
user-invocable: true
---

# Slack

Read with the Slack MCP tools. Write with `slack-post`.

Do not use `slack_send_message`, `slack_send_message_draft`, `slack_schedule_message`, or `slack_update_canvas`. Read, search, and reaction tools are fine.

## slack-post

```
slack-post <target> --body-file PATH [--thread-ts TS]
slack-post <message-url> --body-file PATH
```

| Target | Result |
| --- | --- |
| `C0ABEN38TRB` | Post at the top of that channel or DM |
| `'#eng-fulfillment-automation'` | Post to a public channel by name |
| `U08V6EV65TQ` | DM that person |
| `https://acme.slack.com/archives/C.../p1785267943715149` | Reply inside that message's thread |

Pass a message URL unchanged. Never hand-convert the `p1785267943715149` path timestamp.

Where `slack-post` is missing, print the command for the operator to run.

## Rules

**Keep it short.** Slack is chat, not a document. One or two sentences is normal. No headings, no bullet lists, no sign-off. Nobody wants an essay in Slack, and a long message reads as generated even when every fact in it is right.

**Resolve a channel name to an ID first** with `slack_search_channels`. A name only reaches a public channel.

**Write the body to a file.** Quotes, backticks, and newlines survive.

**Reply in the thread when the target is a thread.**

**Apply `communication-rules` before drafting.** Read it first unless its complete, current instructions are already in this context.

**Apply `contribution-voice` before drafting.** Read it first unless its complete, current instructions are already in this context. Anything posted publishes under the user's name. Run its cut pass, then cut again for Slack.

**Report the `ts` that `slack-post` prints.**
