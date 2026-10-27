# Target selection

Prefer a Slack message URL whenever one is available:

```text
https://<workspace>.slack.com/archives/<channel_id>/p<digits>[?thread_ts=...]
```

A URL supplies the workspace, channel, and message timestamp. Pass it unchanged and never hand-convert the `p<digits>` path timestamp. With a URL target:

- `message get`, `edit`, `delete`, and `react` operate on that message.
- `message list` returns the thread root and all replies.
- `message send` replies in that message's thread. `message compose` does the same unless `--thread-ts` overrides the URL-derived thread.
- `channel mark` marks through that message timestamp; `--ts` overrides the timestamp. It rejects `--workspace` because the URL supplies it.

Use a channel name (`#general` or `general`) or a `C...`, `G...`, or `D...` channel ID only when no URL is available:

- `message get`, `edit`, `delete`, and `react` require `--ts`.
- `message list` reads channel history unless `--thread-ts` or `--ts` selects a thread.
- `message send` posts at the top of the channel unless `--thread-ts` selects a thread.
- `channel mark` requires `--ts`.

`message send` also accepts a `U...` or `W...` user ID as a target and opens or reuses that user's direct-message channel. Treat `U`- and `W`-prefixed user IDs equivalently.

Use `user dm-open <users...>` with one to eight other user IDs or `@handles` to open or reuse a DM or group-DM channel ID, then pass that `D...` or `G...` channel ID to message operations. The authenticated caller is implicit.

Non-URL targets do not carry workspace identity. When multiple workspaces are configured, pass `--workspace <url-or-name>` or set `SLACK_WORKSPACE_URL` for channel, user, and canvas targets.
