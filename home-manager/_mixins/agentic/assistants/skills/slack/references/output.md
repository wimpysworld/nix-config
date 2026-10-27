# JSON output and downloads

`agent-slack` data commands print compact JSON to stdout. Help and authentication commands print text or status metadata.

- Empty values are pruned (`null`, `[]`, and `{}` are omitted where possible).
- `auth test` verifies the configured `SLACK_TOKEN` against the Slack API.

`message get` returns one message and an optional thread summary (`thread: { ts, length }`). `message list` returns chronological messages; in thread mode this includes the root message and all replies.

Immediate non-attachment `message send` calls return `channel_id`, `ts`, and usually `permalink` (plus `thread_ts` when replying in a thread). Attachment sends return `ok` and `files` without `ts` or `permalink`. Scheduled sends return `scheduled_message_id` and `post_at` instead.

`canvas create` returns `canvas: { id, title?, channel_id? }`. `canvas get` returns `canvas: { id, title?, markdown }`. `canvas edit` returns `ok: true` and `canvas: { id, operation }` after Slack accepts the change.

Message payloads keep canonical user IDs. Pass `--resolve-users` to include display metadata under `referenced_users`, or `--refresh-users` to refresh the 24-hour per-workspace user cache before resolving.

Use `--max-body-chars`, `--max-content-chars`, or `--limit` to keep payloads within the task's context budget.

## Downloaded files

Message reads and searches download Slack files locally. Each downloaded file entry includes an absolute local `path` plus metadata such as `name`, `mimetype`, and `mode`.

- `message get` preserves failed downloads in `message.files[]`; `message list`, `search messages`, and `search all` use `messages[].files[]`. Each failed entry carries `error` and a `path` to a local `.download-error.txt` file.
- `search files` warns and skips files whose download fails. Do not treat a skip warning as proof that no matching file exists; retry through the source message with `message get` or `message list` when possible.
- For download-then-reply workflows, use `search messages --content-type file`: `search files` results include local paths but omit the source message permalink and thread target.

Downloads use `$XDG_RUNTIME_DIR/agent-slack/tmp/downloads/` when `XDG_RUNTIME_DIR` is set, and `~/.agent-slack/tmp/downloads/` otherwise.
