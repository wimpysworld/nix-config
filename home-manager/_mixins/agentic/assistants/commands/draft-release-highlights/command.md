## Draft Release Highlights

Draft a user-facing `## Highlights ✨` section for a GitHub release from commits, pull requests, and recent release history.

Target argument: $ARGUMENTS. Treat `$ARGUMENTS` as an explicit `base..target` range, a single target tag or release name, or leave blank to infer the range.

This command reads local Git history and queries GitHub over the network. It writes no files and makes no GitHub mutations.

### Setup and boundaries

- Load `communication-rules`, `writing-well`, and `gh` before drafting. Do not load `contribution-voice`, because it forbids headings, bullets, and tables.
- Use only read-only `git` commands (`tag`, `log`, `diff --stat`, `show`, `rev-parse`) and read-only `gh` commands (`release list`, `release view`, `pr list`, `pr view`, `gh-api-safe`).
- Never run `gh release create`, `gh release edit`, `gh release delete`, `gh release upload`, `gh-release-notes-edit`, or raw `gh api`.

### Process

1. Resolve the GitHub repository and the comparison range:
   - Explicit `base..target`: compare `base` to `target`.
   - Single tag or release name: compare the immediately preceding release or tag to that target.
   - Blank argument: when `HEAD` sits on the latest tag or release with no newer commits, compare the previous release to the latest release. Otherwise compare the latest release or tag to `HEAD`.
   - Initial release with no prior tag: summarise user-facing capabilities up to the target ref.
   - If the repository or refs cannot be resolved, ask the user and stop.
2. Inspect the two or three latest releases in the repository (`gh release list` and `gh release view`) to align product naming, wiki or documentation links, and tone.
3. Gather changes across the range with read-only `git` and `gh` queries (`git log`, `git diff --stat`, `gh pr list`, `gh pr view`). Verify every issue or pull request number before citing it.
4. Filter changes for user impact:
   - Group related commits and pull requests into user-facing outcomes.
   - State known limits, breaking changes, and migration steps plainly.
   - Cite verifiable pull request or issue numbers, for example `(#301)`.
   - Omit routine dependency updates, internal refactors, and CI churn unless they fix a user-facing bug or a security advisory.
   - Never invent benchmarks, metrics, or claims unsupported by commits, pull requests, or code.
5. Scale the layout to the size of the release:
   - **Trivial maintenance or patch-only release**: unless the user explicitly requested highlights for that patch, say plainly that Highlights can be omitted and why.
   - **Small release**: concise plain bullets under `## Highlights ✨`.
   - **Medium release**: optional bold one-sentence summary, bold-lead-in bullets, and an optional one-line upgrade note.
   - **Large or breaking release**: short introduction, `###` subsections (for example migration steps or hardware and platform tables), and bullets.
   - Keep `## Highlights ✨` as the top heading and omit per-item emoji.
6. Apply the `communication-rules` and `writing-well` cut passes. Check for plain British English, active voice, concrete wording, and zero filler.

### Output

When drafting highlights, return only the `## Highlights ✨` section inside one fenced `markdown` block verbatim, with no preamble and no trailing commentary, so the user or `post-release-highlights` can consume it unchanged:

````markdown
## Highlights ✨

...
````

When recommending omission on a trivial patch release, return a brief plain recommendation without a fenced block.
