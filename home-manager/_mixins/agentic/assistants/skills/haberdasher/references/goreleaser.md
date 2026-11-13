# GoReleaser for Haberdasher

Canonical example: `.goreleaser.yaml` in `github.com/wimpysworld/tailor` (cross-platform, with a GHCR image). WonKey is the Linux-only example.

## Keep

| Block | Purpose |
| --- | --- |
| `archives` id `bare` | Bare binaries for bin, Homebrew, and Scoop |
| `archives` id `compressed` | Linux-only `tar.gz` for the AUR, when the project keeps an `aurs` block |
| `nfpms` | `deb`, `rpm`, `apk`, and `archlinux` for apt, rpm, apk, and pkg |
| `checksum` | The checksum file that Haberdasher verifies against |
| `signs` | Optional cosign bundle of the checksum file. Haberdasher verifies it when present |
| `dockers_v2` | Optional GHCR image |
| `release.footer` | Install links. See [install-docs.md](install-docs.md) |

## Leave out

Do not add `nix`, `brews`, `homebrew_casks`, or `scoops`. Haberdasher publishes Nix, Homebrew, and Scoop from the bare binaries and the flake. Keep `aurs` only if the owner wants it.

## Archives

```yaml
archives:
  - id: bare
    formats:
      - binary
    name_template: "{{ .Binary }}-{{ .Os }}-{{ .Arch }}"

  - id: compressed
    formats:
      - tar.gz
    format_overrides:
      - goos: darwin
        formats:
          - none
      - goos: windows
        formats:
          - none
    name_template: "{{ .ProjectName }}_{{ .Version }}_{{ .Arch }}"
```

The `compressed` name has no OS word, and darwin and windows produce no tarball. A Linux-only project, such as WonKey, needs no `format_overrides`. Drop `compressed` when there is no `aurs` block.

Homebrew takes the macOS bare binaries, and Scoop takes the Windows bare `.exe` files.

## nfpms

```yaml
nfpms:
  - id: packages
    vendor: Martin Wimpress
    maintainer: "Martin Wimpress <code@wimpress.io>"
    description: "<one-line description>"
    homepage: https://github.com/wimpysworld/<repo>
    license: BlueOak-1.0.0
    file_name_template: "{{ .ConventionalFileName }}"
    formats:
      - deb
      - rpm
      - apk
      - archlinux
```

Every metadata field is required. WonKey 0.2.1 had no `license` or `description`, so its APKs failed Haberdasher's check with `Incomplete native APK record`, and that stopped the whole run.

`{{ .ConventionalFileName }}` matters for bin as well as for the distributions. It gives the Alpine package an `x86_64` or `aarch64` name with no OS word.

When the repository name has capitals, set `package_name` to the lowercase name, as WonKey does. The package name is the page anchor.

## bin scoring

`bin install github.com/wimpysworld/<repo>` uses marcosnils/bin v0.29.4. It scores each asset name:

| Match | Score |
| --- | --- |
| Repository name | +1 |
| OS word | +10 |
| Architecture word | +5 |

It excludes `.deb`, `.rpm`, `.zst`, and `.txt` assets, and it prompts when two assets tie. The bare binary must be the only asset whose name carries both an OS word and an architecture word. The `archives` and `nfpms` blocks above meet that rule:

- The Alpine `.apk` uses `{{ .ConventionalFileName }}`, with no OS word.
- The AUR tarballs have no OS word.
- macOS has no tarball.

Check a release by listing its assets and confirming one top candidate per platform.

## Tailor swatches

Tailor scaffolds `.goreleaser.yaml`, `.github/workflows/build-go.yml`, and `flake.nix` once. These swatches are first-fit, so an existing project does not receive later swatch changes. Recut the project with Tailor, or edit the files by hand.

The `.goreleaser.yaml` swatch lacks `vendor`, `description`, `license`, and `archlinux`. Add them before the first Haberdasher release. The `build-go.yml` swatch already moves `latest` after a stable release.

## Nix package

`nix/package.nix` takes `{ pkgs, self, ... }` and returns one derivation with a `pname`. Tailor's version uses `0.0.0-<short revision>`, because the flake cannot see its tag. Set `meta.mainProgram`, and set `meta.platforms` for a platform-specific tool.
