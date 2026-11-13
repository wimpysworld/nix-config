# GoReleaser for Haberdasher

Canonical example: `.goreleaser.yaml` in `github.com/wimpysworld/tailor` (cross-platform, with a GHCR image). WonKey is the Linux-only example. `github.com/linuxmatters/jive-encoder` is the cgo example.

Contents: Keep, Leave out, Archives, nfpms, bin scoring, Tailor swatches, Nix package, cgo on native runners, Nix package for cgo.

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

From Tailor 0.6.6, the `.goreleaser.yaml` swatch includes `archlinux` and renders `description` from `repository.description` and `license` from `license` in `.tailor.yml`. Set both in `.tailor.yml` before the first fit, because an empty value omits the field and Haberdasher then rejects the APK. Projects fitted by an older Tailor lack these fields. Add them by hand. The swatch sets no `vendor`. The `build-go.yml` swatch already moves `latest` after a stable release.

## Nix package

`nix/package.nix` takes `{ pkgs, self, ... }` and returns one derivation with a `pname`. Tailor's version uses `0.0.0-<short revision>`, because the flake cannot see its tag. Set `meta.mainProgram`, and set `meta.platforms` for a platform-specific tool.

## cgo on native runners

Use this route when the tool links a native library through cgo, for example the static FFmpeg library of `ffmpeg-statigo`. jive-encoder, jive-vocals, and jive-visualiser follow it.

The cross-compiling template does not fit:

- Tailor's swatch sets `CGO_ENABLED=0`.
- GoReleaser OSS has no `--single-target` for `release`, and `builds.targets` is not templated.
- Prebuilt builds and split and merge are GoReleaser Pro only.

### `.goreleaser.yaml`

Declare one build per target. Each build has one entry in `targets` and runs only when `TARGET` names it:

```yaml
builds:
  - &build
    id: linux_amd64
    main: ./cmd/<tool>
    binary: <tool>
    env:
      - CGO_ENABLED=1
    targets:
      - linux_amd64_v1
    skip: '{{ ne (index .Env "TARGET") "linux_amd64" }}'
  - <<: *build
    id: linux_arm64
    targets:
      - linux_arm64_v8.0
    skip: '{{ ne (index .Env "TARGET") "linux_arm64" }}'
```

Repeat the pattern for `darwin_amd64` and `darwin_arm64`. Also set:

- `git.ignore_tags: [latest]`, so that GoReleaser never takes `latest` as the release tag.
- `release.extra_files` with `glob: ./artifacts/*`, so that the publish job releases the runner outputs.
- `checksum.disable: true` when the project forbids checksum generation. Haberdasher then verifies against the GitHub asset digests.
- `nfpms` formats `deb`, `rpm`, and `archlinux`, with no `apk` unless a musl build of the native library exists.

### glibc floor

The packages need the glibc of the build runner. `ubuntu-24.04` gives `GLIBC_2.38` and `GLIBCXX_3.4.29`. Declare the floor in `nfpms.overrides`:

```yaml
overrides:
  deb:
    dependencies:
      - libc6 (>= 2.38)
      - libstdc++6 (>= 11)
      - libgcc-s1
  rpm:
    dependencies:
      - libc.so.6(GLIBC_2.38)(64bit)
      - libstdc++.so.6(GLIBCXX_3.4.29)(64bit)
      - libgcc_s.so.1()(64bit)
  archlinux:
    dependencies:
      - glibc>=2.38
      - gcc-libs
```

Add the floor note to the install documentation. See [install-docs.md](install-docs.md).

### Workflow

1. A build matrix runs on one native runner per target (`ubuntu-24.04`, `ubuntu-24.04-arm`, `macos-15-intel`, `macos-15`). Each job sets `TARGET` to `<os>_<arch>`.
2. Each build job runs `goreleaser release --clean --skip=publish,announce` on a tag, and `goreleaser release --clean --snapshot` otherwise.
3. Each build job copies the bare binary and packages from `dist/artifacts.json` and uploads them as a workflow artefact.
4. One publish job, on a tag only, downloads all artefacts into `./artifacts` with `merge-multiple: true`.
5. The publish job runs `goreleaser release --clean --skip=nfpm` with `TARGET` unset, so every build skips.
6. The publish job then runs the "Move latest tag" step.

When the publish job omits `--skip=nfpm`, GoReleaser fails with "no linux binaries found".

Before you rename or replace a job, run `gh ruleset list` and keep every job name that a ruleset requires.

## Nix package for cgo

- `github:` flakes omit Git submodules. In `nix/package.nix`, fetch the submodule source with `fetchFromGitHub` and the prebuilt static library with `fetchurl`, both by hash. Copy the submodule into place in `postPatch`.
- Link the library from the Nix store through `CGO_LDFLAGS`. Go 1.26.11 and later reject an in-tree archive with `.llvmbc` LTO sections, with "disallowed LTO section".
- Do not bump the project's nixpkgs lock as part of packaging. The newer Go in the dev shell then breaks in-tree builds until the library is rebuilt without embedded bitcode.
- Set `meta.platforms` to the systems that have a prebuilt library.
- Expose the package only where it can evaluate. Guard the Tailor package hook with `pkgs.lib.meta.availableOn pkgs.stdenv.hostPlatform package`, so that `nix flake check --all-systems` passes when `meta.platforms` is narrower than the flake's systems.
- Guard x86_64-only dev shell packages, such as `intel-media-driver` and `vpl-gpu-rt`, with `pkgs.stdenv.hostPlatform.isx86_64`.

jive-encoder's `nix/package.nix` and `flake.nix` are the examples.
