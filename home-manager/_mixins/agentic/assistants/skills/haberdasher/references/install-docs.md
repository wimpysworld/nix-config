# Install documentation

Write the README, the website, and the release footer from one list: the hosts that carry the package, from [repositories.md](repositories.md). Tailor, WonKey, and Sidra on `main` are the examples.

## README

Use this order:

1. `## Install` with the repository table.
2. One sentence: `Each repository is signed, and its page gives the setup steps and keeps <Name> up to date.`
3. `### Any platform` with the bin command, for a Go tool. Use `### Any Linux` for a Linux-only tool, and `### Linux and macOS` for a tool with no Windows build.
4. `### Updates itself` for an Electron app.
5. `### Container` when the project publishes an image.

~~~markdown
## Install

| | Platform | Repository |
| :-: | --- | --- |
| <img src="https://apt.wimpys.world/logo.svg" width="32" height="32" alt=""> | Debian and Ubuntu | [apt.wimpys.world](https://apt.wimpys.world/#<package>) |
| <img src="https://nix.wimpys.world/logo.svg" width="32" height="32" alt=""> | Nix and NixOS | [nix.wimpys.world](https://nix.wimpys.world/#<package>) |

Each repository is signed, and its page gives the setup steps and keeps <Name> up to date.

### Any platform

[bin](https://github.com/marcosnils/bin) installs and updates the release binary:

```shell
bin install github.com/wimpysworld/<repo>
```
~~~

Add one table row per host, in the order of the hosts table. Keep the logo at 32 by 32 with an empty `alt`.

When the packages declare a glibc floor, add one line after the signing sentence, for example: `The Linux packages and binaries need glibc 2.38 or later, for example Ubuntu 24.04, Debian 13, or Fedora 39.` Add the same line to the release footer.

For an Electron app, `### Updates itself` is a table with the columns Format, Get it, and How it updates:

- Snap: `https://snapcraft.io/<name>`, refreshed by snapd.
- AppImage: `https://github.com/wimpysworld/<repo>/releases/latest/download/<Product>-linux-x86_64.AppImage` and the `arm64` file, updated by the app.
- Windows installer: `https://github.com/wimpysworld/<repo>/releases/latest`, updated by the app.

## Website

Copy the install section of Tailor's `pages/index.html`, with `pages/style.css` and `pages/copy.js`, from `github.com/wimpysworld/tailor` on `main`. That is the canonical tile component. WonKey and Sidra follow it. It has one tile per host and one command tile for bin. Remove the tiles for hosts that do not carry the package.

## Release footer

Set `release.footer` in GoReleaser to a Markdown list of the same links. For an Electron app, add the same list to the release notes.

```markdown
## Install

- Debian and Ubuntu: [apt.wimpys.world](https://apt.wimpys.world/#<package>)
- Nix and NixOS: [nix.wimpys.world](https://nix.wimpys.world/#<package>)
- Any platform, with [bin](https://github.com/marcosnils/bin): `bin install github.com/wimpysworld/<repo>`
- Container: `docker run --rm ghcr.io/wimpysworld/<repo> --version`
```

Keep the bin and container lines only where they apply.
