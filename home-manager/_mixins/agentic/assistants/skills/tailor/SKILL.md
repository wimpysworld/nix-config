# Tailor

Help the user run the installed `tailor` binary on their project. Teach the cycle: inspect, preview, approve, apply, follow up, commit.

## Rules

- Show the `tailor baste` result and get user approval before you run `tailor alter`. `alter` changes live GitHub settings and overwrites `always` files.
- Use `tailor alter --recut` only when the user asks for it. It overwrites customised `first-fit` files.
- Tailor never commits or pushes. Add new Nix files to Git, because flakes ignore untracked files. The user must approve a changed `.envrc` with direnv.
- `tailor alter` imports an existing wiki automatically, without a prompt. Include the wiki import plan from `tailor baste --verbose` when you ask for approval. Do not pass `--adopt-wiki`, because it has no effect.
- `fit`, `alter`, `baste`, and `social --live` need a GitHub token (`GH_TOKEN`, `GITHUB_TOKEN`, or `gh auth login`). `measure`, `docket`, and `social --static` do not.

## Commands

| Command | Purpose |
| --- | --- |
| `tailor measure` | Local health and config check. No network. |
| `tailor docket` | Show the authenticated user and the repository in scope. |
| `tailor fit <path>` | Create `.tailor.yml` with defaults. Copies no swatches. |
| `tailor baste` | Preview what `alter` will do. Writes nothing. |
| `tailor alter` | Apply files and repository settings. |
| `tailor social` | Generate themed static or live social SVGs and update README markers. |

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
   - It never turns on `languages`, `pages`, `social`, `mcp`, or the wiki. Declare new features by hand.
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
3. When the remote wiki has content, show the import plan from `tailor baste --verbose` with the rest of the preview.
4. Run `tailor alter` after the user approves. When the wiki is disabled, `alter` enables it first. When the wiki has content, `alter` imports it automatically.
5. When the wiki has no pages, `alter` still creates missing starter pages and the workflow when their alteration modes permit it, and applies the other changes. `never` skips the starter pages and requires an existing compatible workflow. The user then creates and saves the first page in a browser at the repository's exact `https://github.com/<owner>/<repo>/wiki` URL. Then run `tailor alter` again to import it.
6. Tailor preserves existing local `wiki/` pages and backs up any file that an import replaces.
7. Commit `wiki/`, `wiki/.tailor-wiki-base`, and `.github/workflows/tailor-wiki.yml`. Push to the default branch, then check the workflow run.

Access or network blockers are not proof of an empty wiki. They still stop the run. Follow the check-and-retry guidance instead.

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

## Social assets

Social assets are opt-in and follow Tailor's three-state lifecycle (`enabled: true`, `false`, or omitted). Setting `enabled: false` removes only the owned `nix/og.nix`, `just/og.just`, and `.github/workflows/tailor-social.yml` files and preserves authored assets and `README.md`.

### Configure `.tailor.yml`

```yaml
social:
  enabled: true
  theme: dark
  # accent: "#F2C96B"        # optional hex override when no pages/style.css exists
  # background: "#1A1410"    # optional hex override when no pages/style.css exists
  # platforms: "Linux · macOS · Windows"
  og:
    output: pages/og.png
    include_preview: false   # default: split borderless icon card; true: framed og.image, pages/demo-still.png, or up to 8 og.terminal lines
  readme:
    header: true
    preferred_links: []      # up to 4 unique keys from pages.links
    community: auto          # auto, none, discord, matrix, slack, irc, forum, or discussions
    packages: []             # apt, rpm, pkg, apk, flatpak, brew, scoop, nix
    stats: true
    star_history:
      enabled: true
      min_stars: 25
      min_days: 30
    sponsors: auto           # auto, true, or false
  live:
    branch: social-assets
    schedule: "0 4 * * *"
```

`social:` works with or without `pages.enabled: true`. Repositories without `pages/style.css` fall back to µCSS defaults and can set optional `accent`, `background`, and `platforms` values. Tailor inherits the display title from the repository name using the Haberdasher and Vitrine rule (splitting on `-` and capitalising segments when every segment has more than 2 characters, preserving names such as `ia-get` and `WonKey`), the tagline from `repository.description` (trailing emoji removed), and the icon from `pages/icon.svg` or `pages/icon.png`. `.tailor.yml` has no `title`, `tagline`, or `icon` override keys.

### Hybrid storage model

- **`--static` on `main` (offline, no token)**: renders `hero`, `link-*`, `pkg-*`, static `community`, and the static `sponsors` call-to-action (CTA) in `pages/social/*.svg`, plus `pages/og.png`.
- **`--live` on the orphan `social-assets` branch (requires a GitHub token)**: fetches changing GitHub and Discord counts for `stats`, `stars`, live `sponsors` (`@handles`), and live `community`. `.github/workflows/tailor-social.yml` runs this on schedule, pushes to `social-assets`, and updates `README.md` with commit-pinned `raw.githubusercontent.com` URLs (`[skip ci]`).
- **Star CTA fallback**: when a repository is below `star_history.min_stars` or `min_days`, `stars-{dark,light}.svg` renders a themed "Star this repository" CTA card with drifting stars and a `STAR` pill. Once the repository meets both thresholds, `stars-{dark,light}.svg` switches automatically to the animated star-history chart.

### Generate static assets locally

1. Run `tailor baste`, get approval, then run `tailor alter` to create `nix/og.nix`, `just/og.just`, and `.github/workflows/tailor-social.yml`. Add `nix/og.nix` to Git so the Nix flake sees it. `tailor alter` and `tailor alter --recut` never overwrite `pages/og.png`.
2. Add the desired `<!-- tailor:social-<name>:start -->` / `<!-- tailor:social-<name>:end -->` markers to `README.md`.
3. Run `tailor social --static --update-readme` to render `pages/social/*.svg` and populate the static README blocks. Add `--dry-run` to preview. `--static` is the default when `--live` is omitted.
4. Run `just og` to render `pages/og.png` (`1280 x 640`, `< 1 MB`). `just og` refuses to overwrite existing artwork; pass `just og --force` to regenerate. `tailor measure` accepts both `1280 x 640` and bespoke `1200 x 630` PNGs under 1 MB.
5. Update existing `pages/index.html` landing pages manually: new static Pages starters include Open Graph and Twitter Card tags automatically, but existing `first-fit` `pages/index.html` files stay untouched. Set `og:image` to `https://<domain>/og.png` (from `pages.cname` or `https://<owner>.github.io/<repo>/og.png`), `og:image:width="1280"`, `og:image:height="640"`, `og:image:alt`, and `twitter:card="summary_large_image"` (replacing older `icon.png` or `summary` tags).
6. Remind the user to upload `pages/og.png` manually in GitHub under **Settings > General > Social preview**.
7. Commit and push the generated assets, `README.md`, and `.github/workflows/tailor-social.yml`. When using live README markers (`stats`, `stars`, `sponsors`), tell the user they can trigger **Actions > Tailor Social > Run workflow** once to create the orphan `social-assets` branch and populate the commit-pinned live URLs immediately instead of waiting for the daily schedule.

### Canonical `README.md` layout

When `social.enabled: true`, replace the legacy `<h1 align="center">` + `256x256` icon header and the Markdown Haberdasher install table with standalone Tailor social marker blocks.

- **Top of `README.md`**: place `header`, `links` (preferred social pills), `community`, and `stats` in that order, then a short introduction for the project and `## Features`:

  ```markdown
  <!-- tailor:social-header:start -->
  <!-- tailor:social-header:end -->

  <!-- tailor:social-links:start -->
  <!-- tailor:social-links:end -->

  <!-- tailor:social-community:start -->
  <!-- tailor:social-community:end -->

  <!-- tailor:social-stats:start -->
  <!-- tailor:social-stats:end -->
  ```

- **`## Install` section**: open with a concise sentence that introduces the first-party, signed package repositories on `wimpys.world`. Place the `<!-- tailor:social-packages:start -->` and `<!-- tailor:social-packages:end -->` Haberdasher button block right after that sentence. Put secondary install methods (`Any platform (bin)` and `Container (GHCR)`) in collapsible `<details>` disclosures below the block. Keep authentication notes visible when needed.
- **Bottom of `README.md`**: place `stars` and `sponsors` after `## Support and contributing` (or the equivalent closing section).

Supported marker names: `header`, `links`, `community`, `stats`, `packages`, `stars`, `sponsors`.

- Tailor writes centred theme-aware `<picture><source media="(prefers-color-scheme: dark)" srcset="..."><img src="..." alt="..."></picture>` markup (wrapped in `<a href="...">` when linked) between each pair, including the animated SVG hero in `header`.
- Each opening and closing marker must sit alone on its own line, appear at most once per section, and never overlap another marker block.
- Tailor skips absent markers and leaves all surrounding prose untouched.

## Project icon

Store every project's canonical icon as a real file at `pages/icon.svg`, even when GitHub Pages is disabled. When a project uses a photographic or raster mark, store a square `pages/icon.png` instead as a fallback. One icon supplies the static Pages header, footer, and favicon, the social hero SVG and `og.png`, the repository `README.md`, and Haberdasher package pages (which check `pages/icon.svg` first and `pages/icon.png` second).

- **Use a real file, never a symlink**: commit the file directly at `pages/icon.svg` or `pages/icon.png` (or copy it there when packaging needs a second path). GitHub's Contents API returns symlink target text instead of image bytes, and Windows checkouts break symlinks.
- **Keep it square and self-contained**: prefer a `1:1` SVG with an explicit `viewBox` (no external fonts, images, or scripts) or a square PNG when a photograph is required. Keep it readable on both light and dark surfaces, with no wide horizontal wordmark.
- **Replace the starter placeholder**: replace Tailor's default blue `pages/icon.svg` with the project's own mark. Haberdasher ignores the placeholder bytes.
- **Enable static Pages later**: Tailor only creates the static starter in a missing or empty `pages/` directory. When `pages/icon.svg` or `pages/icon.png` already exists before you enable static Pages, preserve it alongside `pages/index.html`.

## House typography

Use **Work Sans** for regular, UI, and heading text, and **Fira Code** for monospace, code, and terminal text.

- **Landing pages and SVG font stacks**: put `"Work Sans"` first in sans-serif stacks and `"Fira Code"` first in monospace stacks.
- **Open Graph cards**: `nix/og.nix` bundles Work Sans and static Fira Code.
- **Terminal demos**: `nix/ntrecord.nix` bundles static Fira Code for `ntrecord`.

## Version numbering

Keep the `v` prefix on Git tags only. Omit the `v` prefix from every etched binary version and package version.

- **Use `v` on Git tags**: `just release x.y.z` creates `v<x.y.z>`. Go modules, GitHub Actions release triggers (`tags: ["v*.*.*"]`), and GoReleaser expect `v`-prefixed tags.
- **Omit `v` everywhere else**:
  - **Go binaries**: Declare `var version = "dev"` in `cmd/<app>/main.go` and expose `--version` without hardware or network access. GoReleaser injects `-trimpath` and `-s -w -X main.version={{ .Version }}` (with `git.ignore_tags: [latest]`), Nix injects `-X main.version=${version}` from `nix/version`, and local `just build` injects `${VERSION#v}` from `git describe --tags --match 'v*.*.*' --always --dirty`.
  - **Rust binaries**: Read `option_env!("BUILD_VERSION").unwrap_or(env!("CARGO_PKG_VERSION"))` with a `build.rs` `cargo:rerun-if-env-changed=BUILD_VERSION` directive. Set `BUILD_VERSION={{ .Version }}` in GoReleaser, `BUILD_VERSION = version;` in `nix/package.nix`, and `BUILD_VERSION="${VERSION#v}"` in local `just build`. Keep `Cargo.toml`'s `[package] version` in sync with the bare release tag (`x.y.z`, no `v`).
  - **Packages and Nix**: GoReleaser `{{ .Version }}`, Linux packages (`.deb`, `.rpm`, `.apk`, `.pkg.tar.zst`, AUR), and the workflow-written `nix/version` (`${RELEASE_TAG#v}`) all use bare `x.y.z`.

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
