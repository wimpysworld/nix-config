# Haberdasher

Make a project's GitHub releases publishable by Haberdasher, then document one consistent set of install routes.

Haberdasher is at `~/Development/wimpysworld/Haberdasher` and `github.com/wimpysworld/Haberdasher`. When this skill and its `AGENTS.md` disagree, its `AGENTS.md` wins.

## How Haberdasher reads a release

- It publishes only the GitHub "Latest" release of each source, including assets added to it later. It keeps every version already published and never backfills.
- It derives formats from asset file types, never from settings. `haberdasher.yaml` is only a list of repositories, with no per-project options.
- It derives package identity from package metadata, not file names or tags. Architectures come from package metadata, from Mach-O headers for Homebrew, and from PE headers for Scoop.
- It verifies each asset against the release checksum file or the GitHub asset digest. It verifies the cosign bundle of the checksum file when one exists.
- It rejects changed bytes for an identity that it already published. Fix a bad release with a new version, never by replacing assets.
- One invalid package stops the whole run, so complete package metadata is essential.

The hosts, anchors, and per-format inputs are in [references/repositories.md](references/repositories.md).

## Checklist

### 1. Classify the project

| Type | Builder | Reference |
| --- | --- | --- |
| Go command-line tool | GoReleaser | [references/goreleaser.md](references/goreleaser.md) |
| Go tool with cgo and native libraries, for example a static FFmpeg library | GoReleaser on native runners | [references/goreleaser.md#cgo-on-native-runners](references/goreleaser.md#cgo-on-native-runners) |
| Electron desktop app | electron-builder | [references/electron-builder.md](references/electron-builder.md) |

Other types have no proven path yet. Ask the owner before you invent one.

### 2. Produce the release outputs

- Go: bare binaries, Linux packages from nfpm with full metadata, and an optional GHCR image.
- Go with cgo: the same bare binaries and packages, built on one native runner per target. Leave out `apk` unless a musl build of the native library exists.
- Electron: Linux packages, a Flatpak bundle, a macOS `.zip` that holds one `.app`, and a portable Windows `.zip` that holds one `.exe`.

Leave out every builder feature that publishes to Homebrew, Scoop, or Nix. Haberdasher publishes those formats.

### 3. Release workflow

After a stable release, move the `latest` tag. Skip pre-releases, which have a `-` in the tag.

For a Go project, add this step after GoReleaser, as in Tailor's `.github/workflows/builder.yml`:

```yaml
- name: Move latest tag
  if: ${{ !contains(github.ref_name, '-') }}
  env:
    RELEASE_TAG: ${{ github.ref_name }}
  run: |
    git tag --force latest "${RELEASE_TAG}^{commit}"
    git push --force origin refs/tags/latest
```

For a cgo project, the publish job moves `latest` after its GoReleaser step.

For an Electron project whose flake fetches release assets by hash, the `nix-hash` job moves `latest` instead. See [references/electron-builder.md](references/electron-builder.md).

### 4. Flake

- Go: put the derivation in `nix/package.nix`. Tailor's flake swatch exposes it under its `pname` and as `default` when that file exists.
- Set `meta.platforms` when the tool does not build everywhere. WonKey sets `pkgs.lib.platforms.linux`.
- For a cgo tool with a native library, follow [references/goreleaser.md#nix-package-for-cgo](references/goreleaser.md#nix-package-for-cgo).
- In the dev shell, use `tailor.url = "github:wimpysworld/tailor/latest";` with no `follows`.
- Tell consumers to use `github:wimpysworld/<repo>/latest` with no `follows`.

Haberdasher builds `packages.<system>` of the project's own flake at the release tag. When `latest` is at or ahead of the release tag, it builds the `latest` commit instead. A flake cannot see its tag, so the version that the page shows comes from the tag. The cache serves `x86_64-linux` only.

A `follows` on the consumer's input changes the derivation, so the cache misses and the consumer builds from source.

### 5. Add the source to Haberdasher

1. Add `wimpysworld/<repo>` to `sources` in Haberdasher's `haberdasher.yaml`.
2. Run `just plan`. It is read-only and lists what the run will publish.
3. Cut the project's release.
4. Run `just publish`.

When a run stops on a stale lock, run `just unlock`, then rerun `just publish`. Recover from any interrupted run with a full rerun.

### 6. Install documentation

Write the README `## Install` section, the website install tiles, and the release footer from the same list of hosts. Follow [references/install-docs.md](references/install-docs.md).

### 7. Verify

- `just plan` lists every expected format for the new source, and nothing unexpected.
- Every `https://<host>/#<package>` link opens the right tab on that page.
- For a Go tool, bin scoring leaves exactly one candidate per platform. See [references/goreleaser.md](references/goreleaser.md).
- The Nix cache serves the store path that a `latest` input locks:

```sh
nix path-info --store https://nix.wimpys.world <store-path>
```

## Rules

- Link only the hosts that carry the package. Sidra has no APK. WonKey has no Homebrew, Scoop, or Flatpak.
- Never mention the AUR in documentation, even when GoReleaser keeps an `aurs` block.
- Never write versioned download URLs in documentation. Use `releases/latest` forms.
- Never add per-distribution install commands to a README. The repository pages own the setup steps.
- Never add per-project settings to Haberdasher. Change the project's release instead.

## Anti-patterns

- Fitting a Go project while `.tailor.yml` has no `repository.description` or `license`. The `.goreleaser.yaml` swatch then omits the package description or licence, and Haberdasher rejects the APK.
- Shipping macOS tarballs or OS-named Linux tarballs beside bare binaries. bin then prompts on a tie.
- Letting a portable Electron build update itself.
- Consumer flake inputs with `follows`.
