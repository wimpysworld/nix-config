## Post Release Highlights

Merge a `## Highlights ✨` section into an existing GitHub release notes body and update that body only.

Target argument: $ARGUMENTS. Accept an optional tag, `owner/repo`, or an inline fenced Highlights block.

This command reads from and mutates GitHub over the network, writes the merged body to a temporary file (`mktemp`), and speaks as the user. Treat explicit human invocation of this command as consent to update the target GitHub release notes body only. Never create, delete, publish, or modify the tag, title, draft status, prerelease status, or release assets. Never use raw `gh api`.

### Setup

- Load `gh` before resolving the release or running any GitHub command.
- If drafting fresh, also load `communication-rules` and `writing-well`.
- Run each command separately. Do not chain commands with `&&`, `;`, or `|`.

### Process

1. Resolve `<owner/repo>` and `<tag>` from `$ARGUMENTS`, the conversation context, or the current Git repository. If either value is missing or ambiguous, ask the user and stop.
2. Resolve the Highlights draft:
   - If a reviewed `## Highlights ✨` fenced block for this release already exists in the conversation or in `$ARGUMENTS`, use it verbatim after stripping only the outer Markdown fence lines.
   - If no prior draft exists, resolve `draft-release-highlights` from the available command sources and follow its body inline without its generated launch wrapper. Show the drafted `## Highlights ✨` block to the user and wait for explicit confirmation before updating GitHub.
3. Fetch the live release with:
   `gh release view <tag> --repo <owner/repo> --json body,url,tagName,isDraft,isPrerelease`
   If the release does not exist, stop and report that rather than creating one.
4. Merge the draft idempotently into a temporary file created with `mktemp`:
   - Confirm that the draft starts with `## Highlights ✨`.
   - If the live body already contains a `## Highlights ✨`, `## Highlights :sparkles:`, or `## Highlights` heading, replace only that section up to (but not including) the next `## ` heading or the end of the file.
   - Otherwise prepend the Highlights block plus one blank line above the existing body, or write only the Highlights block when the live body is empty.
   - Preserve the rest of the live body (`## Changelog`, `## What's Changed`, `## Install`, `**Full Changelog**`) verbatim.
   - If the merged body matches the live body (ignoring trailing newline differences), remove the temporary file, report that the release already matches, and stop without writing.
5. Update the GitHub release notes body:
   - Check whether `gh-release-notes-edit` is available on `PATH`.
   - When `gh-release-notes-edit` is available, run `gh-release-notes-edit <owner/repo> <tag> --notes-file <tmpfile>`. On success, remove the temporary file.
   - When `gh-release-notes-edit` is unavailable or denied by Fence, do not run raw `gh api` or `gh release edit`. Keep the merged body in the temporary file, print the unfenced fallback command below, and stop.
6. Verify the update with:
   `gh release view <tag> --repo <owner/repo> --json url,tagName,body`
   Confirm that `## Highlights ✨` is live and that the existing changelog and footer stayed intact.

### Output

On a completed update or no-op match, report:

```markdown
Release: <release-url>
Tag: <tag>
Result: <updated|already up to date>
Verification: <live Highlights and existing sections confirmed intact, or unchanged>
```

When `gh-release-notes-edit` is unavailable or denied, output the fallback command for an unfenced shell:

```bash
gh release edit <tag> --repo <owner/repo> --notes-file <tmpfile>
```
