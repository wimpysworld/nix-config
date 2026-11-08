# Tailor

Help the user run the installed `tailor` binary on their project. Teach the cycle: inspect, preview, approve, apply, follow up, commit.

## Rules

- Show the `tailor baste` result and get user approval before you run `tailor alter`. `alter` changes live GitHub settings and overwrites `always` files.
- Use `tailor alter --recut` only when the user asks for it. It overwrites customised `first-fit` files.
- Tailor never commits or pushes. Add new Nix files to Git, because flakes ignore untracked files. The user must approve a changed `.envrc` with direnv.
- Never pass `--adopt-wiki` unless the user approved the import plan in this conversation.
- `fit`, `alter`, and `baste` need a GitHub token (`GH_TOKEN`, `GITHUB_TOKEN`, or `gh auth login`). `measure` and `docket` do not.

## Commands

| Command | Purpose |
| --- | --- |
| `tailor measure` | Local health and config check. No network. |
| `tailor docket` | Show the authenticated user and the repository in scope. |
| `tailor fit <path>` | Create `.tailor.yml` with defaults. Copies no swatches. |
| `tailor baste` | Preview what `alter` will do. Writes nothing. |
| `tailor alter` | Apply files and repository settings. |

Add `--verbose` to see every result and the full adoption steps. Run commands from the project root, because Tailor does not search parent directories for `.tailor.yml`.

## New project

1. Run `tailor measure` to see the missing health files.
2. Run `tailor fit .` (or `tailor fit <path>`). Use `--license=<id>` or `--license=none` to change the `BlueOak-1.0.0` default.
3. Edit `.tailor.yml` with the user. The defaults can disable an existing wiki, Code Quality, and immutable releases, and replace an existing `Tailor` ruleset.
4. Run `tailor baste`, show the result, and get approval.
5. Run `tailor alter`.

Repository settings, labels, and variables need a GitHub remote. Without one, Tailor skips them with a warning. Run `tailor alter` again after the remote exists.

## Upgrade an existing project

1. Upgrade the `tailor` binary.
2. Run `tailor measure`. In the config check:
   - `not-configured`: a default swatch that `.tailor.yml` does not list.
   - `config-only`: a listed swatch that is no longer a default. `alter` rejects it, so remove the entry.
   - `mode-differs`: the configured mode differs from the default mode.
3. Run `tailor baste --verbose`.
4. Explain default merging to the user:
   - It runs only when the `.tailor.yml` swatch entry has `alteration: always`, or `first-fit` with `--recut`.
   - It is append-only. It adds missing swatches and settings and never changes an existing value.
   - It never turns on `languages`, `pages`, `mcp`, or the wiki. Declare new features by hand.
5. Declare languages as needed. Each one selects its bodies for `just build`, `just test`, and `just lint`:

   ```yaml
   languages:
     go: true
     shell: true
     javascript: true   # or typescript: true, never both
     rust: false
     python: false
   ```

   `true` creates owned fragments, `false` removes them, and an absent key leaves them untouched.
6. Run `tailor baste` again, show the result, and get approval.
7. Run `tailor alter`. It also removes the retired `.github/workflows/tailor.yml` and `.github/workflows/tailor-automerge.yml`.
8. Do the manual follow-ups that the output reports under `Next` and `Additional guidance`. Tailor preserves an existing `justfile` and `flake.nix`, so the output gives the exact edits. Typical edits:
   - Add `import 'just/loader.just'` to the `justfile`.
   - Append `++ import ./nix/loader.nix { inherit pkgs; }` to the flake's package list, and compose the hook that the output names.
   - Adopt `.envrc` watches, MCP client entries, or the Dependabot ownership marker when the output asks.

   Follow the output for the current release, not memory. Rerun `tailor baste --verbose` until no required edit remains.
9. Review the diff with the user, add new files to Git, and let the user commit.

## Enable the wiki

Wiki publishing works only on public repositories.

1. Set `repository.has_wiki: true` in `.tailor.yml`.
2. Run `tailor baste --verbose` and read the wiki guidance.
3. Run `tailor alter`. When the wiki is disabled, `alter` enables it first.
4. When the remote wiki is empty, the user creates and saves the first page in a browser at the repository's exact `https://github.com/<owner>/<repo>/wiki` URL. Then run `tailor alter` again.
5. When the remote wiki has content, Tailor plans an import. Show the full plan from `tailor baste --verbose`. After the user approves, the user answers the `alter` prompt (default no), or you run `tailor alter --adopt-wiki`.
6. Tailor preserves existing local `wiki/` pages and backs up any file that an approved import replaces.
7. Commit `wiki/`, `wiki/.tailor-wiki-base`, and `.github/workflows/tailor-wiki.yml`. Push to the default branch, then check the workflow run.

Access or network blockers are not proof of an empty wiki. Follow the check-and-retry guidance instead.

## Add static Pages

Pages works only on public repositories. Use the built-in static starter:

```yaml
pages:
  enabled: true
  generator: static
  path: pages
```

1. Make sure `pages.path` is missing or empty, so Tailor creates the starter (`index.html`, `style.css`, `theme.js`, `icon.svg`).
2. Optional: set `cname` for a custom domain, and `links` for footer icons. The starter `index.html` has `tailor:links`, `tailor:navigation`, `tailor:footer-navigation`, and `tailor:license` start and end markers. Tailor manages only the content between them.
3. Run `tailor baste`, get approval, then run `tailor alter`.
4. Edit `index.html` for the introduction, features, installation, and copyright holder. Replace `icon.svg` with the project icon.
5. Commit and push to the Pages branch (default: the repository default branch) to deploy.

## Out of scope

Hugo, Jekyll, MCP integrations, Ebitengine, Android, ffmpeg-statigo, and per-setting detail for the ruleset, Actions policy, variables, and immutable releases. Use `tailor baste --verbose` and the wiki.

## Further reading

- [Tailor wiki home](https://github.com/wimpysworld/tailor/wiki)
- [Commands](https://github.com/wimpysworld/tailor/wiki/Commands)
- [Configuration](https://github.com/wimpysworld/tailor/wiki/Configuration)
- [GitHub wiki](https://github.com/wimpysworld/tailor/wiki/GitHub-wiki)
- [GitHub Pages](https://github.com/wimpysworld/tailor/wiki/GitHub-Pages)
- [Repository settings](https://github.com/wimpysworld/tailor/wiki/Repository-settings)
- [Ruleset](https://github.com/wimpysworld/tailor/wiki/Ruleset)
