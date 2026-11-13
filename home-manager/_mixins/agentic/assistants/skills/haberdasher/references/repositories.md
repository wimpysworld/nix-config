# Repositories

## Hosts

List hosts in this order everywhere: README table, website tiles, and release footer.

| Host | Platform label | Format | Takes |
| --- | --- | --- | --- |
| `apt.wimpys.world` | Debian and Ubuntu | APT | `.deb` |
| `rpm.wimpys.world` | Fedora and openSUSE | RPM | `.rpm` |
| `pkg.wimpys.world` | Arch Linux | pacman | `.pkg.tar.zst`, `.pkg.tar.xz` |
| `apk.wimpys.world` | Alpine Linux | APK | `.apk` |
| `flatpak.wimpys.world` | Flatpak | Flatpak | `.flatpak` |
| `brew.wimpys.world` | macOS (Homebrew) | Homebrew tap `wimpysworld/tap` | macOS bare binaries, or a `.zip` that holds one `.app` |
| `scoop.wimpys.world` | Windows (Scoop) | Scoop bucket `wimpysworld` | Windows bare `.exe` files, or a portable `.zip` that holds one `.exe` |
| `nix.wimpys.world` | Nix and NixOS | Nix binary cache | The project's own flake |

## Anchors and logos

- Each host page has one install section per package. Link it as `https://<host>/#<package>`, where `<package>` is the lowercase package name. WonKey is `#wonkey`.
- Each host serves `https://<host>/logo.svg` in its brand colour. The logo adapts to dark mode.

## Per-format notes

- APT, RPM, pacman, APK, and Flatpak are signed with the Wimpy's World key. Haberdasher removes upstream package signatures and signs again where the format needs it.
- Homebrew and Scoop are not signed. Clients check the `sha256` in the cask or the `hash` in the manifest.
- Homebrew and Scoop name a tool from its asset name and version it from the release tag. They take the architecture from the Mach-O or PE header, never from the file name.
- Homebrew casks remove the quarantine attribute in `postflight`, until the projects sign and notarise with a Developer ID.
- Scoop never takes a self-updating installer. It gives a GUI executable a Start Menu shortcut and a console executable a `bin` entry, from the PE subsystem field.
- Flatpak installs with one command from `https://flatpak.wimpys.world/<app-id>.flatpakref`.
- For Nix, Haberdasher skips, with one log line, a project without a flake, a package whose `meta.platforms` excludes the host, and a package whose build fails.
- The Nix page shows `github:wimpysworld/<repo>/latest` when the cache holds a build of the `latest` commit, and `github:wimpysworld/<repo>` otherwise.

Haberdasher does not publish Snap, AppImage, or the Windows installer.
