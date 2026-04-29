# Permission policy

This policy is not YOLO-mode. Rather than disabling confirmation globally, it divides every operation into one of three outcomes: allow safe, read-only commands without interruption; ask before anything that changes state worth reviewing; deny access to secrets and destructive commands unconditionally.

The practical effect: agents work fluidly on navigation, inspection, analysis, MCP calls, and workspace edits without prompting. Commits, installs, and other state-changing shell commands pause for approval. Credential files, cloud keys, and shell history are inaccessible regardless of what the agent requests.

Claude Code uses ordered allow/ask/deny lists evaluated at startup. Rules use prefix matching with `Bash(command:*)` syntax.

## Matching semantics

Rules are checked in order: deny, then ask, then allow. The first matching rule wins, so deny rules take precedence over allow rules. The `defaultMode` is `acceptEdits`, which automatically accepts file edits and common filesystem commands for the launch directory and configured `additionalDirectories`.

File read denials use `Read(pattern)` syntax and block access entirely. Absolute filesystem paths use Claude Code's `//path` form. A single leading slash is project-root-relative, not filesystem-root-relative.

## Three-tier model

| Tier | Effect | Examples |
|------|--------|----------|
| `allow` | Executes without prompting | `git status`, `ls`, `cat`, read-only queries |
| `ask` | Prompts for confirmation | `git commit`, `npm install`, non-workspace state changes |
| `deny` | Blocked entirely | `sudo`, `git push --force`, `dd`, subshell execution |

The `Agent`/`Task` tools for delegation and the `Skill` tool for skill loading are included in the allow list, so subagents and subtasks can use skills without prompting. The same workspace edit and MCP allow rules apply inside delegated work.

## Workspace edits and MCP

Claude Code is configured with these persistent `additionalDirectories`:

| Directory | Purpose |
|-----------|---------|
| `~/Chainguard` | Workspace root |
| `~/Development` | Workspace root |
| `~/Volatile` | Workspace root |
| `~/Zero` | Workspace root |
| `/tmp` | Scratch space |

`Edit(//.../**)` rules allow edits throughout those roots without approval. Claude Code applies `Edit` rules to its built-in file editing tools.

`mcp__*` is allowed, so every tool from every declaratively configured MCP server runs without approval. Project MCP servers are not enabled wholesale; MCP servers are selected through Home Manager.

## Read denials

Sensitive files are blocked at the read level, independent of bash rules:

| Category | Patterns |
|----------|----------|
| Environment files | `.env`, `.env.*`, `**/.env`, `**/.env.*` |
| Secrets directories | `secrets/**`, `.secrets/**` |
| SSH keys | `~/.ssh/**`, `*_rsa`, `*_ed25519`, `*_ecdsa`, `*.pem`, `*.key` |
| GPG keys | `~/.gnupg/**` |
| Cloud credentials | `~/.aws/**`, `~/.azure/**`, `~/.config/gcloud/**` |
| VCS credentials | `~/.config/gh/hosts.yml`, `~/.git-credentials`, `~/.netrc` |
| Container secrets | `~/.docker/config.json`, `~/.kube/**` |
| Shell history | `~/.bash_history`, `~/.zsh_history`, `~/.fish_history` |

## Bash command categories

Rules cover 13 tool domains. Each follows the same pattern: version checks and read-only queries are allowed, state modifications require confirmation, destructive operations are denied.

### Shell utilities

| Allow | Ask | Deny |
|-------|-----|------|
| `ls`, `cat`, `head`, `tail`, `wc`, `file`, `tree`, `pwd` | `sed`, `sd`, `mkdir`, `touch`, `mv`, `cp` | `sudo`, `shred`, `wipe`, `srm`, `truncate` |
| `which`, `type`, `env`, `fd`, `rg`, `grep` | `tee`, `echo`, `printf`, `curl`, `wget` | `dd` |
| `whoami`, `hostname`, `uname`, `df`, `free`, `ps` | `chmod`, `chown`, `kill`, `pkill`, `ln` | `bash -c`, `sh -c`, `fish -c`, `zsh -c`, `dash -c` |
| `stat`, `du`, `sort`, `uniq`, `cut`, `awk`, `diff` | `xdg-open` | `python -c`, `node -e`, `perl -e`, `ruby -e`, `lua -e`, `php -r` |
| `jq`, `yq`, `bc`, `man`, `tldr`, `strings` | `rm`, `rmdir` (supervised) | `sysctl`, `modprobe`, `insmod`, `rmmod` |
| `xxd`, `hexdump`, `od`, `base64`, `shellcheck` | | `grub-install`, `efibootmgr`, `fdisk`, `parted`, `mkfs`, `mount` |
| `bat`, `most`, `less`, `more`, `tr`, `tac`, `rev` | | |

Additional text processing: `column`, `fold`, `nl`, `pr`, `expand`, `paste`, `join`, `comm`.

Archive inspection (read-only): `tar -t`, `unzip -l`, `zipinfo`, `7z l`, `zcat`, `bzcat`, `xzcat`.

Network inspection: `ip addr/link/route show`, `ss`, `netstat`, `ping -c`, `traceroute`, `dig`, `host`, `nslookup`.

Process inspection: `pgrep`, `pidof`, `pstree`, `lsof`.

### Git

| Allow | Ask | Deny |
|-------|-----|------|
| `status`, `diff`, `log`, `branch`, `remote` | `add`, `commit`, `push`, `pull`, `fetch` | `push --force`, `push -f` |
| `show`, `stash list`, `tag`, `worktree list` | `checkout`, `switch`, `merge`, `rebase` | `reset --hard`, `clean` |
| `config --list/--get`, `reflog`, `rev-parse` | `stash`, `restore`, `cherry-pick`, `worktree` | `filter-branch` |
| `describe`, `shortlog`, `blame`, `ls-files/tree`, `grep` | | |

### GitHub CLI

| Allow | Ask | Deny |
|-------|-----|------|
| `repo view`, `pr view/list`, `issue view/list` | `pr create/merge/checkout` | `repo delete` |
| `status`, `api`, `help`, `help *` | `issue create`, `release create` | |
| | `repo create/clone` | |

### Docker

| Allow | Ask | Deny |
|-------|-----|------|
| `ps`, `images`, `logs`, `inspect`, `info`, `stats` | `build`, `run`, `exec`, `stop`, `start` | `system prune`, `volume prune` |
| `network ls`, `volume ls`, `--version` | `compose up/down`, `pull`, `push` | `container prune`, `image prune` |

### Systemd

| Allow | Ask | Deny |
|-------|-----|------|
| `status`, `is-active/enabled/failed` | `start`, `stop`, `restart`, `reload` | `poweroff`, `reboot`, `halt` |
| `list-units/unit-files/dependencies/jobs` | `enable`, `disable`, `mask`, `unmask` | `suspend`, `hibernate` |
| `show`, `cat`, `journalctl`, `systemd-analyze` | `daemon-reload`, `edit` | |
| `hostnamectl`, `timedatectl`, `loginctl` | | |
| `localectl`, `networkctl`, `resolvectl`, `busctl` | | |

### Nix

| Allow | Ask | Deny |
|-------|-----|------|
| `flake show/check/metadata/info` | `build`, `develop`, `flake update` | `nix-collect-garbage` |
| `eval`, `search`, `path-info`, `why-depends` | `nix-shell`, `nix-env` | |
| `derivation show`, `store ls/verify`, `hash` | `home-manager switch` | |
| `repl`, `log`, `show-config`, `doctor` | `nixos-rebuild`, `darwin-rebuild` | |
| `nix-instantiate`, `nix-store --query/-q` | | |
| `nixfmt`, `statix`, `deadnix`, `alejandra` | | |

### Go

| Allow | Ask |
|-------|-----|
| `version`, `env`, `list`, `vet`, `doc` | `build`, `run`, `test`, `generate` |
| `mod graph`, `mod why` | `get`, `mod tidy`, `install` |
| `ineffassign`, `ineffassign *` | |
| `actionlist`, `actionlist *` | |
| `golangci-lint run *`, `golangci-lint --version`, `golangci-lint linters` | |
| `gofumpt --version`, `gofumpt -l *` | |
| `govulncheck`, `govulncheck *` | |

### JavaScript/TypeScript

| Allow | Ask | Deny |
|-------|-----|------|
| `node/npm/pnpm --version`, `npx --version` | `npm install/run/test/publish` | `npm cache clean --force` |
| `npm ls/outdated/view/info` | `pnpm install/run` | |
| `tsc --version`, `tsc --noEmit` | `yarn add/install` | |
| | `vite` | |

### Rust

| Allow | Ask |
|-------|-----|
| `cargo --version/check/clippy/doc/tree/metadata` | `cargo build/test/run/install/publish/update` |
| `cargo fmt --check`, `rustc/rustup --version` | `rustup update/default` |
| `rustup show/target list/component list` | |

### Python

| Allow | Ask | Deny |
|-------|-----|------|
| `python/python3 --version`, `pip --version` | `python`, `python3`, `pytest`, `mypy`, `ruff` | `python -c`, `python3 -c`, `python2 -c` |
| `pip list/show/freeze/check` | `pip install/uninstall` | |
| `pytest --version`, `pytest --collect-only` | `uv pip install`, `uv sync/run` | |
| `mypy/ruff --version`, `ruff check` | | |
| `uv --version`, `uv pip list` | | |

### Build tools

| Allow | Ask |
|-------|-----|
| `autoconf/automake/make/cmake/meson/ninja --version` | `./configure`, `make`, `cmake`, `meson`, `ninja` |
| `clang/clang++/gcc/g++ --version` | `clang`, `clang++`, `gcc`, `g++`, `ar`, `ranlib` |
| `make -n` (dry run), `cmake -E capabilities` | `clang-tidy`, `clang-format` |
| `ldd`, `pkg-config`, `objdump`, `nm`, `readelf` | `autoreconf`, `autoconf`, `automake` |

### FFmpeg

| Allow | Ask |
|-------|-----|
| `ffmpeg -version/-formats/-codecs/-encoders/-decoders` | `ffmpeg` (file processing) |
| `ffmpeg -bsfs/-protocols/-pix_fmts/-layouts/-filters` | |
| `ffprobe` | |

### Additional domains

| Domain | Allow | Ask | Deny |
|--------|-------|-----|------|
| Hugo | `version`, `env` | All other `hugo` commands | - |
| ImageMagick | `identify`, version checks | `convert`, `magick`, `mogrify`, `compare`, `composite` | - |
| Just | `--version`, `--list`, `--summary`, `eval`, `build` | All other `just` commands | - |
| Lua/LÖVE | `lua -v`, `love --version` | `lua`, `love`, `luarocks install/remove` | - |
| Svelte | `svelte-check --help` | `svelte-kit sync/build`, `svelte-check` | - |
| Wails | `--version`, `doctor` | `build`, `dev`, `init` | - |
| Cloudflare | `wrangler --version`, `whoami` | `dev`, `deploy`, `publish`, `secret`, `kv`, `r2`, `d1` | `wrangler delete` |
