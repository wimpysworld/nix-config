# Personal fleet reference

Martin's personal Tailor preferences, fleet architecture, operational rules, and repository exceptions.

## Typography

Use **Work Sans** for regular, UI, and heading text, and **Fira Code** for monospace, code, and terminal text across websites, Open Graph (OG) cards, `ntrecord` demos, and SVG font stacks.

- Put `"Work Sans"` first in sans-serif stacks and `"Fira Code"` first in monospace stacks.

## Social links

- Set `social.readme.preferred_links` to `[bluesky, mastodon, linkedin]` in that exact order for the three primary README social pills.
- Trim `pages.links` on each landing page to links relevant to that project. Remove `steam` and `itchio` from non-gaming projects, and remove `twitch` and `youtube` when unused.

## Fleet connecting tissue

- **Tailor** (`wimpysworld/tailor`): manages `.tailor.yml`, community health files, dev tooling (`nix/`, `just/`), static GitHub Pages, and `social` assets (`pages/og.png`, `pages/social/*.svg`, the orphan `social-assets` branch, and `README.md` markers).
- **Haberdasher** (`wimpysworld/Haberdasher`, `haberdasher.yaml`): builds and publishes signed package repositories (`apt`, `rpm`, `pkg`, `apk`, `flatpak`, `brew`, `scoop`, `nix`) at `<host>.wimpys.world` and emits `haberdasher.json` for Vitrine.
- **Vitrine** (`flexiondotorg/flexiondotorg`, `vitrine.yaml`): merges Haberdasher projects with non-Haberdasher projects (such as `glyph-party`, `nix-config`, `nothing-but-nix`, `deb-get`, `extra-life`, and `quickemu-project/quickemu`) to generate Martin's GitHub profile (`flexiondotorg/flexiondotorg` `README.md`) and website assets (`wimpys.world`).
- **Linux Matters websites** (`linuxmatters/website`): external Hugo site hosting `jive-vocals`, `jive-encoder`, `jive-visualiser`, and `ffmpeg-statigo` under `content/jive/<name>/`, with shared `static/jive/style.css` (`#feb81e` amber) and `layouts/partials/jive/footer.html` ("Fitted by Tailor" colophon).

## Operational rules

- **Custom domains**: for any new `*.wimpys.world` GitHub Pages subdomain, create a DNS-only (`proxied: false`) Cloudflare `CNAME` to `wimpysworld.github.io`. Run `tailor alter` a second time after GitHub approves TLS to enforce HTTPS.
- **Social preview upload**: GitHub exposes no API for **Settings > General > Social preview**. Always upload `pages/og.png` manually.
- **Fence bootstrap**: when Fence blocks `gh workflow run`, run `tailor social --live --output-dir <tmp>` locally and push the single-commit orphan `social-assets` branch directly.
- **Terminal demos**: record CLI and TUI demos with `ntrecord` using `Fira Code` and a dark background matching `pages/style.css`. Replace legacy `vhs` tapes and GIFs, and keep `demo.webp <= 512 KiB` for SVG window-chrome framing. Skip `ntrecord` for GUI apps, video tools, web apps, GitHub Actions, and `nix-config`.
- **Flakes**: never add `tailor` to a project's `flake.nix`, because `nix-config` provisions it globally. Always run `git add nix/og.nix` before `just og` or `nix develop`, because Nix flakes ignore untracked files.

## Special-case repositories

| Repository | Rules and exceptions |
| --- | --- |
| `wimpysworld/sidra` | GUI app. Preserve bespoke `1200 x 630` `pages/images/og.png` (never overwrite). Set `demo: false` and `packages: [apt, rpm, pkg, flatpak, brew, scoop, nix]`. |
| `wimpysworld/vectorator` | Dual-branch (`main` is Wayfire 0.11, `wayfire-0.10` is Wayfire 0.10). Migrate `main` first, then cherry-pick cleanly onto `wayfire-0.10` without touching `flake.nix` or C++. Set `packages: [apt, rpm, pkg]`. |
| `wimpysworld/glyph-party` | Web app with custom `.github/workflows/deploy-pages.yml` (`npm run build` on `v*` tags). Keep `pages.enabled: false` and `packages: []`. Never touch app code or `deploy-pages.yml`. |
| `wimpysworld/nix-config` | Bespoke `flake.nix` and `justfile` (`first-fit`, never recut). Copy `pages/icon.png` from `assets/logo.png`. `builder.yml` ignores `pages/**`, `README.md`, and `tailor-social.yml`. Set `packages: []` and `pages.cname: nix-config.wimpys.world`. |
| `wimpysworld/nothing-but-nix` | GitHub Action. Preserve the Marketplace URL as `repository.homepage` alongside `pages.cname: nothing-but-nix.wimpys.world`. Preserve bespoke crimson hatchet and Nix snowflake `pages/icon.svg`. Set `packages: []`. |
| `wimpysworld/nyala` | Keep hero `<video>` and `pages/images/nyala-poster.png` (as `og.image`). Set `demo: false`. |
| `wimpysworld/stream-sprout` | Uses `pages/icon.png` (no `icon.svg`). Set `packages: [apt, rpm, pkg, apk, nix]`. |
| `linuxmatters/jive-{vocals,encoder,visualiser}`, `linuxmatters/ffmpeg-statigo` | External Hugo pages in `linuxmatters/website`. Leave `pages.enabled` unset. Set `social.accent: "#feb81e"` and set `pages.links` for social pills, community, and sponsors. |
