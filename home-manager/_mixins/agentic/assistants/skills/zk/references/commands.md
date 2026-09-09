# Commands

These examples match `zk 0.15.4`. Check the installed version and help before using different flags or behaviour.

```sh
zk --version
zk new --help
zk list --help
zk index --help
```

## Configuration

Pass both the notebook directory and working directory explicitly. This prevents the caller's directory from changing path resolution.

Home Manager configures `~/Notes`, eight-character lowercase alphanumeric IDs, `.md` files, and extensionless Markdown links.
The `default.md` template creates `title`, `date`, `tags: []`, a matching H1, and the supplied `{{content}}`.
Supply only the body through stdin, not a second frontmatter block or duplicate title heading.

In 0.15.4, global templates take precedence over notebook-local templates with the same name.
A `.zk` directory identifies a notebook. If notebook setup is missing, report it instead of running `zk init`.
That command writes local defaults, including a link format that differs from this notebook's configuration.

## Search

```sh
zk --notebook-dir "$HOME/Notes" -W "$HOME/Notes" --no-input list --quiet --no-pager --format jsonl --match 'title: Example'
zk --notebook-dir "$HOME/Notes" -W "$HOME/Notes" --no-input list --quiet --no-pager --format jsonl --match 'search terms'
zk --notebook-dir "$HOME/Notes" -W "$HOME/Notes" --no-input list --quiet --no-pager --format jsonl --tag 'example'
```

Parse JSON Lines as one object per line. No matches produce empty stdout, not an empty JSON array.
Read the relevant note files after finding candidates. Avoid a full notebook dump for a narrow task.
Do not use `list --interactive`, which opens an interactive selector.

## Create

Prepare the requested Markdown body in a temporary file outside the notebook, then run:

```sh
zk --notebook-dir "$HOME/Notes" -W "$HOME/Notes" --no-input new --title 'Example' --interactive --print-path < body.md
```

Here `--interactive` reads stdin. `--print-path` returns the new path instead of launching an editor.
Read the returned file and check that the configured template produced the expected metadata, heading, body, and filename.
Treat the returned path as data. Never evaluate it as shell code.

## Links

Replace `abcd1234.md` with the actual notebook-relative path:

```sh
zk --notebook-dir "$HOME/Notes" -W "$HOME/Notes" --no-input list --quiet --no-pager --format jsonl --link-to 'abcd1234.md'
zk --notebook-dir "$HOME/Notes" -W "$HOME/Notes" --no-input list --quiet --no-pager --format jsonl --linked-by 'abcd1234.md'
```

`--link-to` finds incoming links. `--linked-by` finds outgoing links.
Neither replaces direct checks of Markdown destinations, attachments, fragments, or links that the index cannot resolve.
`--missing-backlink` concerns reciprocal links, not a complete broken-link check.

## Edits and indexing

In 0.15.4, neither the CLI nor the LSP provides note renaming. Edit files and repair references directly.
Normal indexing uses filesystem modification times. After content edits, run:

```sh
zk --notebook-dir "$HOME/Notes" -W "$HOME/Notes" --no-input index
```

After structural changes, preserved filesystem timestamps, or suspected stale results, force reparsing:

```sh
zk --notebook-dir "$HOME/Notes" -W "$HOME/Notes" --no-input index --force
```

Inspect stderr for per-note failures even when the command exits successfully. Confirm that affected notes appear with current content and paths.
The indexed creation date uses note metadata. The indexed modification date uses filesystem time, not frontmatter `modified`.

For a content or title edit, generate frontmatter `modified` with the current London offset:

```sh
TZ=Europe/London date '+%Y-%m-%dT%H:%M:%S%:z'
```

## Upstream reference

Use the [official zk documentation](https://zk-org.github.io/zk/) for behaviour beyond these examples.
Prefer installed help for the active version. Do not depend on repository-only note conversion helpers.
