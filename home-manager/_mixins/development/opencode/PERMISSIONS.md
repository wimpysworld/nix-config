# Permission policy

This policy is not YOLO-mode. Rather than disabling confirmation globally, it divides every operation into one of three outcomes: allow safe, read-only commands without interruption; ask before anything that changes state worth reviewing; deny access to secrets and destructive commands unconditionally.

The practical effect: agents work fluidly on navigation, inspection, and analysis without prompting. Commits, installs, and file modifications pause for approval. Credential files, cloud keys, and shell history are inaccessible regardless of what the agent requests.

OpenCode uses `.findLast()` matching: rules are evaluated top-to-bottom and the last match wins. Deny rules must appear after allow rules to take priority.

## Three-tier model

| Tier | Effect | Examples |
|------|--------|----------|
| `allow` | Executes without prompting | `git status`, `ls`, `cat`, read-only queries |
| `ask` | Prompts for confirmation | `git commit`, `npm install`, file modifications |
| `deny` | Blocked entirely | `sudo`, `git push --force`, `dd`, subshell execution |

## Tool permissions

| Tool | Permission | Notes |
|------|-----------|-------|
| `read` | `allow` with credential deny-list | `.env`, SSH keys, cloud credentials, shell history blocked |
| `glob`, `grep`, `list`, `lsp` | `allow` | Read-only navigation |
| `edit` | `allow` | All file modifications permitted |
| `bash` | Per-command rules | See categories below |
| `task` | `allow` | Sub-agent delegation |
| `skill` | `meet-the-agents`: allow, others: ask | |
| `webfetch`, `websearch`, `codesearch` | `allow` | |
| `todoread`, `todowrite` | `allow` | |
| `external_directory` | Granular | Nix store, XDG dirs allowed; sensitive dirs denied |
| `doom_loop` | `ask` | Guards against repeated identical tool calls |

## Read denials

Sensitive files are blocked at the read level, independent of bash rules:

| Category | Patterns |
|----------|----------|
| Environment files | `.env`, `.env.*`, `.env.local`, `.env.*.local` |
| Secrets directories | `**/secrets/**`, `**/.secrets/**` |
| SSH keys | `~/.ssh/**`, `**/id_rsa`, `**/id_ed25519`, `**/id_ecdsa` and variants |
| Key files | `*.pem`, `*.key` |
| GPG keys | `~/.gnupg/**` |
| Cloud credentials | `~/.aws/**`, `~/.azure/**`, `~/.config/gcloud/**` |
| VCS credentials | `~/.config/gh/hosts.yml`, `~/.git-credentials`, `~/.netrc` |
| Container secrets | `~/.docker/config.json`, `~/.kube/**` |
| Shell history | `~/.bash_history`, `~/.zsh_history`, `~/.fish_history` |

## External directory access

Triggered when accessing files outside the project directory.

| Permission | Directories |
|-----------|-------------|
| `allow` | `/tmp/*`, `/usr/share/*`, `/usr/local/share/*`, `/var/log/*` |
| `allow` | `/nix/store/*` (read-only by nature) |
| `allow` | `$XDG_CACHE_HOME/*`, `$XDG_DATA_HOME/*`, `$XDG_CONFIG_HOME/*` |
| `ask` | All other external directories (catch-all) |
| `deny` | `/etc/shadow`, `/etc/gshadow`, `/etc/sudoers`, `/root/*`, `/boot/*` |
| `deny` | `~/.ssh`, `~/.gnupg`, `~/.aws`, `~/.azure`, `~/.config/gcloud` |
| `deny` | `~/.docker`, `~/.kube`, `~/.config/gh` |
| `deny` | `~/.git-credentials`, `~/.netrc` |

## Bash command categories

Rules cover 12 tool domains. Each follows the same pattern: version checks and read-only queries are allowed, state modifications require confirmation, destructive operations are denied.

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
| `status`, `diff`, `log`, `branch` (list/contains/merged) | `add`, `commit`, `push`, `pull`, `fetch` | `push --force`, `push -f` |
| `remote`, `show`, `stash list/show`, `tag -l/--list` | `checkout`, `switch`, `merge`, `rebase` | `reset --hard`, `clean` |
| `config --list/--get`, `reflog`, `rev-parse` | `branch -d/-D/-m/-M`, `branch --set-upstream` | `filter-branch`, `filter-repo` |
| `describe`, `shortlog`, `blame`, `ls-files/tree/remote` | `stash`, `restore`, `reset`, `revert` | `reflog expire` |
| `grep`, `worktree list`, `name-rev`, `cat-file` | `cherry-pick`, `worktree add/remove/prune` | |
| `count-objects`, `for-each-ref`, `symbolic-ref` | `tag -a/-d/-s`, `tag *` | |
| `verify-commit`, `verify-tag` | `am`, `apply`, `bisect`, `clone`, `config` | |
| | `init`, `mv`, `rm`, `submodule` | |

### GitHub CLI

| Allow | Ask | Deny |
|-------|-----|------|
| `--version`, `auth status`, `status`, `help`, `help *` | `pr create/merge/close/reopen/checkout` | `repo delete` |
| `repo view/list`, `pr view/list/status/diff/checks` | `pr review/edit/comment` | `release delete` |
| `issue view/list/status` | `issue create/close/reopen/edit/comment` | `gist delete` |
| `run view/list`, `workflow view/list` | `repo create/clone/fork/edit` | |
| `release view/list`, `gist view/list` | `release create/edit` | |
| `api`, `search` | `run rerun/cancel`, `workflow run` | |
| | `gist create/edit` | |

### Docker

| Allow | Ask | Deny |
|-------|-----|------|
| `--version`, `version`, `info` | `build`, `run`, `exec`, `stop`, `start` | `rm`, `rmi` |
| `ps`, `images`, `logs`, `inspect`, `stats` | `restart`, `kill`, `pause`, `unpause` | `system prune`, `volume prune` |
| `network ls/inspect`, `volume ls/inspect` | `pull`, `push`, `tag`, `create`, `commit`, `cp` | `container prune`, `image prune` |
| `top`, `port`, `diff`, `history`, `search` | `compose up/down` | `network prune` |
| `compose --version/config` | | `volume rm`, `network rm` |

### Systemd

| Allow | Ask | Deny |
|-------|-----|------|
| `--version`, `status`, `is-active/enabled/failed` | `start`, `stop`, `restart`, `reload` | `poweroff`, `reboot`, `halt` |
| `list-units/unit-files/dependencies/jobs` | `enable`, `disable`, `mask`, `unmask` | `suspend`, `hibernate` |
| `list-sockets`, `list-timers`, `show`, `cat`, `help` | `daemon-reload`, `daemon-reexec` | `rescue`, `emergency` |
| `journalctl`, `systemd-analyze` | `edit`, `set-property` | |
| `hostnamectl`, `timedatectl`, `loginctl` | | |
| `localectl`, `networkctl`, `resolvectl`, `busctl` | | |
| `coredumpctl` | | |

### Nix

| Allow | Ask | Deny |
|-------|-----|------|
| `--version`, `flake show/check/metadata/info` | `build`, `develop`, `run`, `shell` | `nix-collect-garbage` |
| `eval`, `search`, `path-info`, `why-depends` | `flake update/lock`, `profile` | `nix store gc/delete` |
| `derivation show`, `store ls/verify`, `hash` | `nix-shell`, `nix-build`, `nix-env` | |
| `repl`, `log`, `show-config`, `doctor` | `home-manager`, `nixos-rebuild`, `darwin-rebuild` | |
| `nix-instantiate`, `nix-store --query/-q` | | |
| `nixfmt`, `statix`, `deadnix`, `alejandra` | | |

### Go

| Allow | Ask |
|-------|-----|
| `version`, `env`, `list`, `vet`, `doc` | `build`, `run`, `test`, `generate` |
| `mod graph/why/verify/download`, `help` | `get`, `install`, `mod tidy/init/edit` |
| `ineffassign`, `ineffassign *` | `fmt`, `gofmt`, `work` |
| `actionlist`, `actionlist *` | |
| `golangci-lint run *`, `golangci-lint --version`, `golangci-lint linters` | |
| `gofumpt --version`, `gofumpt -l *` | |
| `govulncheck`, `govulncheck *` | |

### JavaScript/TypeScript

| Allow | Ask | Deny |
|-------|-----|------|
| `node/npm/pnpm/yarn --version`, `npx --version` | `npm install/ci/run/test/start/exec/publish` | `npm cache clean --force` |
| `npm ls/list/outdated/view/info/search/explain` | `npm uninstall/update/link`, `npx` | `pnpm store prune` |
| `npm audit/doctor/config list/get/help` | `pnpm install/run/test/exec/dlx/add/remove` | `yarn cache clean` |
| `npm pack --dry-run` | `yarn install/add/remove/run` | |
| `pnpm ls/list/outdated/audit/why` | `tsc`, `vite` | |
| `yarn list/info/why` | | |
| `tsc --version`, `tsc --noEmit` | | |

### Rust

| Allow | Ask |
|-------|-----|
| `cargo --version/version/check/clippy/doc/tree/metadata` | `cargo build/test/run/bench/install/uninstall` |
| `cargo search/fmt --check/verify-project` | `cargo publish/update/add/remove` |
| `cargo locate-project/pkgid/read-manifest` | `cargo init/new/fmt/fix/generate` |
| `rustc --version/--print`, `rustup --version` | `rustup update/default/toolchain/override` |
| `rustup show/target list/component list/which` | |

### Python

| Allow | Ask | Deny |
|-------|-----|------|
| `python/python3 --version/-V`, `pip --version/-V` | `python`, `python3` | `python -c`, `python3 -c`, `python2 -c` |
| `pip list/show/freeze/check/index versions/search/help` | `pip install/uninstall/download` | |
| `uv --version`, `uv pip list/show/freeze/check` | `uv pip install/uninstall`, `uv sync/run/venv` | |
| `pytest --version`, `pytest --collect-only` | `uv lock/add/remove` | |
| `mypy/ruff/black/isort --version` | `pytest`, `mypy`, `ruff`, `black`, `isort` | |
| `ruff check/rule`, `black --check`, `isort --check/--diff` | | |

### Build tools

| Allow | Ask |
|-------|-----|
| `autoconf/automake/make/cmake/meson/ninja --version` | `./configure`, `configure`, `autoreconf`, `autoconf`, `automake` |
| `clang/clang++/clang-tidy/clang-format/clangd --version` | `make`, `cmake`, `meson`, `ninja` |
| `gcc/g++ --version`, `ar/ranlib --version` | `clang`, `clang++`, `gcc`, `g++`, `ar`, `ranlib` |
| `make -n` (dry run), `cmake -E capabilities` | `clang-tidy`, `clang-format` |
| `ldd`, `pkg-config/pkgconf`, `objdump`, `nm`, `readelf` | |

### FFmpeg

| Allow | Ask |
|-------|-----|
| `ffmpeg -version/-formats/-codecs/-encoders/-decoders` | `ffmpeg` (file processing) |
| `ffmpeg -bsfs/-protocols/-pix_fmts/-layouts/-sample_fmts` | |
| `ffmpeg -filters/-hwaccels`, `ffprobe` | |

### Additional domains

| Domain | Allow | Ask | Deny |
|--------|-------|-----|------|
| Hugo | `version`, `env`, `list`, `config` | All other `hugo` commands | - |
| ImageMagick | `identify`, version checks | `convert`, `magick`, `mogrify`, `compare`, `composite` | - |
| Just | `--version`, `--list`, `-l`, `--summary`, `--evaluate`, `--show`, `eval`, `build` | All other `just` commands | - |
| Lua/LÖVE | `lua -v`, `love --version` | `lua`, `love`, `luarocks` | - |
| Svelte | `svelte-check --help/--version` | `svelte-kit sync`, `svelte-check`, `svelte-kit` | - |
| Wails | `--version`, `doctor` | `build`, `dev`, `init`, `generate` | - |
| Cloudflare | `wrangler --version`, `whoami` | All other `wrangler` commands | `wrangler delete` |
