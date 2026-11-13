# electron-builder for Haberdasher

Canonical example: the `build` section of `package.json`, `.github/workflows/builder.yml`, `src/autoUpdate.ts`, `src/update.ts`, and `nix/` in `github.com/wimpysworld/sidra`.

## Targets

| Platform | Targets | Consumer |
| --- | --- | --- |
| Linux | `deb`, `rpm`, `pacman`, `flatpak` | apt, rpm, pkg, flatpak |
| Linux | `AppImage`, `snap` | Self-updating, outside Haberdasher |
| macOS | `zip` | brew |
| macOS | `dmg` | Direct download and the Nix package |
| Windows | `zip` | scoop |
| Windows | `nsis` | Self-updating installer, outside Haberdasher |

- Set `deb.maintainer`, `rpm.vendor`, and a `pacman` description, so every package carries complete metadata.
- Set `mac.identity` to `"-"` for an ad-hoc signature.
- The macOS `.zip` must hold exactly one `.app`. The Windows `.zip` must hold exactly one `.exe`.
- Haberdasher skips the installer that the release's `latest.yml` names, so the NSIS installer never reaches Scoop.
- Give the AppImage a version-free `artifactName`, for example `${productName}-${os}-${arch}.${ext}`. The `releases/latest/download/` links then stay valid.

Electron apps do not offer bin.

## Updates

Only the AppImage and the NSIS install update themselves. Every other build must not, because its repository updates it.

- Gate self-update on `process.env.APPIMAGE` on Linux.
- On Windows, gate it on `Uninstall <productName>.exe` beside the executable. The portable `.zip` has no uninstaller, so it must not self-update.
- Exclude Snap and Flatpak.

Point the update notification at the repository page that matches the install type, as `updatePageUrl()` in Sidra's `src/update.ts` does:

| Install | Page |
| --- | --- |
| Snap | `https://snapcraft.io/<name>` |
| Flatpak (`FLATPAK_ID`) | `https://flatpak.wimpys.world/#<name>` |
| Nix (resources under `/nix/store/`) | `https://nix.wimpys.world/#<name>` |
| Linux `package-type` `deb`, `rpm`, `pacman` | apt, rpm, or pkg page |
| macOS | `https://brew.wimpys.world/#<name>` |
| Windows portable | `https://scoop.wimpys.world/#<name>` |
| Anything else | The GitHub release |

Check for Nix before `package-type`, because the Nix package unpacks the release `.deb` and keeps its package type.

## Nix flake and the `nix-hash` job

Sidra's flake repackages release assets: `nix/linux.nix` unpacks the `.deb` per architecture, and `nix/darwin.nix` unpacks the arm64 `.dmg`. The flake reads `version` from `package.json`. Each file holds a `url` with `${version}` and a `hash`.

The hashes exist only after the release, so the `nix-hash` job runs after the release job:

1. Prefetch each asset with `nix store prefetch-file` and rewrite `url` and `hash` together.
2. For a stable release, create a detached worktree at the release tag, apply the same rewrite, commit, and move `latest` to that commit with `git tag --force latest HEAD` and `git push --force origin refs/tags/latest`.
3. Open a pull request with the same changes against `main`.

Haberdasher then builds the `latest` commit, because it is ahead of the release tag. Keep `url` versioned with `${version}`, so a stale hash fails instead of serving an older release.
