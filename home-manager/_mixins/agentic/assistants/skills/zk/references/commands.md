# Commands

- [Configuration](#configuration)
- [Search](#search)
- [Create](#create)
- [Links](#links)
- [Edits and indexing](#edits-and-indexing)
- [Upstream reference](#upstream-reference)

These examples match `zk 0.15.4`. Check the installed version and help before using different flags or behaviour.

```sh
zk --version
zk new --help
zk list --help
zk index --help
```

## Configuration

Pass both the notebook directory and working directory explicitly. This prevents the caller's directory from changing path resolution.

Home Manager configures `~/Notes`, readable title-based filenames, `.md` files, and relative Markdown links that keep the `.md` extension.
The filename template is `{{#if (slug title)}}{{slug title}}{{else}}untitled{{/if}}`.
The slug uses lowercase words and hyphens, transliterates Unicode, and removes punctuation. An empty slug becomes `untitled.md`.
These rules apply to new filenames, not existing names or the note's title.
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

Check the intended folder and filename for collisions before creation. Prefer a meaningful title over the `untitled.md` fallback.
If a path exists, read the note to distinguish an update from a distinct note.
Never overwrite it or silently change the requested title to avoid a collision.

Prepare the requested Markdown body in a temporary file outside the notebook, then run:

```sh
zk --notebook-dir "$HOME/Notes" -W "$HOME/Notes" --no-input new --title 'Example' --interactive --print-path < body.md
```

Here `--interactive` reads stdin. `--print-path` returns the new path instead of launching an editor.
Read the returned file and check that the configured template produced the expected metadata, heading, body, and filename.
In 0.15.4, a collision can return an existing path with exit status zero and discard stdin. Success does not prove creation.
Treat the returned path as data. Never evaluate it as shell code.
For a requested folder, create the directory if needed and set `-W` to its absolute path, such as `"$HOME/Notes/Reference"`.
Keep `--notebook-dir "$HOME/Notes"` unchanged.
For a distinct note, use a meaningful alternative filename while preserving the requested title and configured metadata.
Report the collision. If the intended destination is unclear, ask the user before creating that note.
Do not add opaque IDs to avoid a collision.

## Links

Replace `guides/example-guide.md` with the actual notebook-relative path:

```sh
zk --notebook-dir "$HOME/Notes" -W "$HOME/Notes" --no-input list --quiet --no-pager --format jsonl --link-to 'guides/example-guide.md'
zk --notebook-dir "$HOME/Notes" -W "$HOME/Notes" --no-input list --quiet --no-pager --format jsonl --linked-by 'guides/example-guide.md'
```

`--link-to` finds incoming links. `--linked-by` finds outgoing links.
Neither replaces direct checks of Markdown destinations, attachments, fragments, or links that the index cannot resolve.
`--missing-backlink` concerns reciprocal links, not a complete broken-link check.
Write note destinations relative to the containing note, such as `../guides/example-guide.md` or `../Project%20Notes.md`.
Preserve filename case and Unicode when encoding destinations. Keep heading fragments separate from the encoded path.
Existing extensionless links can remain when unaffected. Do not rewrite the whole notebook to enforce the new-link convention.

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
