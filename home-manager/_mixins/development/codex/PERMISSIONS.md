# Permission policy

This policy is full-auto inside trusted workspaces, not `danger-full-access`.
Codex can edit files and use MCP tools without prompting, but it still runs in
the `workspace-write` sandbox and generated exec rules block the most dangerous
command prefixes.

The practical effect: Codex works fluidly on local development tasks,
repository edits, MCP lookups, and Nix evaluation. It cannot write outside the
configured workspace roots, and commands such as `sudo`, disk formatting,
destructive Git operations, subshell bypasses, and Nix store deletion are
blocked by policy.

Codex uses `~/.codex/rules/default.rules`, generated from Nix. Rules are
written as `prefix_rule()` calls and use Codex's native decision precedence:

```text
forbidden > prompt > allow
```

Codex is configured with:

```toml
approval_policy = "never"
sandbox_mode = "workspace-write"
allow_login_shell = false
```

`approval_policy = "never"` means Codex should not stop for interactive
approval prompts during normal local work. The prompt rules remain in the
generated policy to document the intended ask tier and to keep the command
taxonomy aligned with Claude Code and OpenCode. The unconditional guardrails are
the `forbidden` rules and the workspace sandbox.

## Matching semantics

Rules match command prefixes. A rule can match a literal token sequence or a
token with a list of alternatives.

Example generated rules:

```starlark
prefix_rule(
    pattern = ["nixfmt"],
    decision = "allow",
    justification = "Nix formatting is an approved project maintenance command.",
)

prefix_rule(
    pattern = ["git", ["add", "commit", "push"]],
    decision = "prompt",
    justification = "Git state changes and network sync require approval.",
)

prefix_rule(
    pattern = ["sudo"],
    decision = "forbidden",
    justification = "Privilege escalation is not permitted.",
)
```

## Three-tier model

| Tier | Effect | Examples |
|------|--------|----------|
| `allow` | Approved explicitly by policy | `nix-instantiate`, `nixfmt` |
| `prompt` | Supervisory tier retained for parity | `git commit`, `npm install`, `nix build` |
| `forbidden` | Blocked entirely | `sudo`, `git push --force`, `dd`, shell `-c` |

Codex also has its own built-in trusted command behaviour. Common read-only
inspection commands can run inside the sandbox without needing explicit rules.

## Tool permissions

| Surface | Permission | Notes |
|---------|------------|-------|
| File edits | Allowed inside writable roots | `workspace-write` controls the filesystem boundary |
| MCP tools | Allowed | Only explicitly configured MCP servers are wired |
| Skills | Allowed | Generated skills are enabled in `config.toml` |
| Agent roles | Allowed via model tools | Role files are real TOML files, not symlinks |
| Shell commands | Per-prefix rules plus sandbox | Dangerous prefixes are forbidden |
| Network | Enabled in sandbox | Required for Nix, GitHub CLI, package managers, MCP-backed flows |

## Sandbox roots

Codex writes are confined to the current workspace, `/tmp`, and explicit
writable roots:

```text
~/Chainguard
~/Development
~/Volatile
~/Zero
~/.cache/nix
```

`~/.cache/nix` is writable because Nix creates flake fetcher locks there before
talking to the daemon. Without it, `just eval` fails under Codex with a
read-only filesystem error.

The shell environment sets:

```toml
[shell_environment_policy.set]
NIX_REMOTE = "daemon"
```

This makes Nix use the daemon store rather than trying to write directly to
`/nix/store`.

## No split read-deny profile

Unlike Claude Code and OpenCode, Codex does not currently use a custom
read-deny filesystem profile.

That is deliberate. On Linux, Codex split permission profiles currently clash
with normal Unix-socket access:

- Without `permissions.<profile>.network`, Codex installs restricted network
  seccomp and Nix cannot connect to its daemon socket.
- With `permissions.<profile>.network.enabled = true`, Codex enters managed
  proxy mode, which blocks new `AF_UNIX` and `socketpair` creation inside
  commands.
- Nix, Determinate Nix, Tokio-based tools, and other local developer tooling
  need normal Unix socket behaviour.

Secret handling for Codex therefore relies on three boundaries:

| Boundary | Coverage |
|----------|----------|
| Workspace sandbox | Writes are limited to configured roots |
| Environment filtering | Credential environment variables are removed |
| Repository discipline | Plaintext secrets should not live in trusted writable roots |

Encrypted SOPS files under this repository are normal project files and are
available to Codex like any other tracked source file.

## Environment filtering

Subprocesses inherit the `core` environment baseline, with common credentials
removed:

```text
AWS_* AZURE_* GOOGLE_* GCLOUD_* GH_TOKEN GITHUB_TOKEN
ANTHROPIC_API_KEY OPENAI_API_KEY GEMINI_API_KEY
*_API_KEY *_SECRET *_TOKEN
SSH_AUTH_SOCK SSH_AGENT_PID GPG_AGENT_INFO
```

This prevents most accidental credential leakage into shell commands while
preserving enough environment for development tools to run normally.

## MCP servers

Codex only wires MCP servers selected in the Nix configuration:

| Server | Permission | Notes |
|--------|------------|-------|
| `cloudflare` | Allowed | Cloudflare documentation and tools |
| `context7` | Allowed | Uses `CONTEXT7_API_KEY` when present |
| `exa` | Allowed | Web search and fetch |
| `nixos` | Allowed | NixOS, Home Manager, nix-darwin reference |
| `svelte` | Allowed | Svelte documentation tools |

`jina` is not configured, so Codex does not warn at startup about a missing
`JINA_API_KEY`.

## Bash command categories

Codex rules cover the same broad command domains as Claude Code and OpenCode.
The `prompt` tier documents operations that deserve supervision in tools that
can ask interactively. The `forbidden` tier is the hard stop.

### Shell utilities

| Allow | Prompt | Forbidden |
|-------|--------|-----------|
| Built-in trusted read-only commands | `sed`, `sd`, `mkdir`, `touch`, `mv`, `cp` | `sudo`, `dd`, `shred`, `wipe`, `srm`, `truncate` |
| `nixfmt` | `tee`, `echo`, `printf`, `curl`, `wget` | `bash -c`, `sh -c`, `fish -c`, `zsh -c`, `dash -c` |
| `nix-instantiate` | `chmod`, `chown`, `kill`, `pkill`, `ln` | `python -c`, `node -e`, `perl -e`, `ruby -e`, `lua -e`, `php -r` |
| | `rm`, `rmdir`, `xdg-open` | `sysctl`, `modprobe`, `insmod`, `rmmod` |
| | | `grub-install`, `efibootmgr`, `fdisk`, `parted`, `mkfs`, `mount`, `umount` |

`allow_login_shell = false` rejects login-shell requests before command policy
evaluation. Shell `-c` and `-lc` prefixes are also forbidden so compound shell
commands cannot bypass per-command policy.

### Git

| Prompt | Forbidden |
|--------|-----------|
| `add`, `commit`, `push`, `pull`, `fetch` | `push --force`, `push -f` |
| `checkout`, `switch`, `merge`, `rebase` | `reset --hard`, `clean` |
| `stash`, `restore`, `cherry-pick`, `worktree` | `filter-branch` |

Read-only Git queries rely on Codex's built-in trusted command behaviour.

### GitHub CLI

| Prompt | Forbidden |
|--------|-----------|
| `gh pr create`, `gh pr merge`, `gh pr checkout` | `gh repo delete` |
| `gh issue create` | |
| `gh release create` | |
| `gh repo create`, `gh repo clone` | |

### Docker

| Prompt | Forbidden |
|--------|-----------|
| `build`, `run`, `exec`, `stop`, `start` | `system prune`, `volume prune` |
| `pull`, `push` | |
| `docker-compose up/down`, `docker compose up/down` | |

### Systemd

| Prompt | Forbidden |
|--------|-----------|
| `start`, `stop`, `restart`, `reload` | `poweroff`, `reboot`, `halt` |
| `enable`, `disable`, `mask`, `unmask` | `suspend`, `hibernate` |
| `daemon-reload`, `edit` | |

### Nix

| Allow | Prompt | Forbidden |
|-------|--------|-----------|
| `nix-instantiate`, `nixfmt` | `nix build`, `nix develop`, `nix run`, `nix shell` | `nix-collect-garbage` |
| | `nix flake update`, `nix flake lock` | `nix store gc`, `nix store delete` |
| | `nix profile`, `nix-shell`, `nix-build`, `nix-env` | |
| | `home-manager`, `nixos-rebuild`, `darwin-rebuild` | |

`just eval` works because the sandbox permits Nix daemon access and writable
Nix fetcher locks.

### Language and build tools

| Domain | Prompt | Forbidden |
|--------|--------|-----------|
| Go | `go build`, `go run`, `go test`, `go generate`, `go get`, `go install`, `go mod tidy` | - |
| JavaScript | `npm install/run/test/publish`, `pnpm install/run`, `yarn add/install`, `vite` | `npm cache clean --force` |
| Rust | `cargo build/test/run/install/publish/update`, `rustup update/default` | - |
| Python | `python`, `python3`, `pytest`, `mypy`, `ruff`, `pip install/uninstall`, `uv sync/run` | `python -c`, `python3 -c`, `python2 -c` |
| Build systems | `./configure`, `make`, `cmake`, `meson`, `ninja`, compilers, `clang-tidy`, `clang-format` | - |

### Additional domains

| Domain | Prompt | Forbidden |
|--------|--------|-----------|
| FFmpeg | `ffmpeg` | - |
| Hugo | `hugo` | - |
| ImageMagick | `convert`, `magick`, `mogrify`, `compare`, `composite` | - |
| Lua/LÖVE | `lua`, `love`, `luarocks install/remove` | - |
| Svelte | `svelte-kit sync/build`, `svelte-check` | - |
| Wails | `wails build/dev/init/generate` | - |
| Cloudflare | `wrangler dev/deploy/publish/secret/kv/r2/d1` | `wrangler delete` |

## Verification

After changing the policy, run:

```bash
nixfmt --check home-manager/_mixins/development/codex/default.nix
just eval
```

After activation and a fresh Codex restart, useful runtime checks are:

```bash
nix store ping
test -w ~/.cache/nix/fetcher-locks
rg -n 'default_permissions|\[permissions|permissions\.|network_access|NIX_REMOTE' ~/.codex/config.toml
```
