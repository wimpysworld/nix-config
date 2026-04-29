# Codex

[Codex CLI](https://github.com/openai/codex) configured declaratively via Home Manager. The module writes Codex configuration, MCP servers, generated skills, agent roles, sandbox settings, and command policy from Nix while keeping Codex's runtime state mutable.

```bash
codex                  # start interactive TUI
/skills                # list all skills
$skill-name            # invoke a skill by name in the composer
```

## Runtime Layout

Codex is installed through a small launcher package, not by running the Nix store binary directly. During activation, the real Codex binary is copied to stable user-owned locations:

```text
~/.local/share/codex/bin/codex
~/.codex/bin/codex
${XDG_CONFIG_HOME}/codex/bin/codex
```

The launcher tries those paths in order. This avoids two Linux sandbox failure modes:

- Codex re-execs `std::env::current_exe()` when entering the sandbox. A Nix store path can disappear after a Home Manager generation switch.
- `CODEX_HOME` and `.codex` paths are protected inside the Codex Linux sandbox. The primary stable binary therefore lives outside Codex home at `~/.local/share/codex/bin/codex`.

The source package is deliberately unwrapped by clearing `postFixup`. Wrapping changes the executable path and breaks the sandbox re-exec assumptions.

On Linux, `bubblewrap` and `ripgrep` are added to `home.packages`. Codex's sandbox prefers the first usable `bwrap` on `PATH`, and `rg` is used by Codex when expanding filesystem glob policies.

## Configuration

Codex reads `~/.codex/config.toml` on this system. Home Manager writes the file as a real mutable file during activation, not as a symlink into the Nix store.

This matters because Codex edits `config.toml` at runtime to persist trust decisions and other state. A symlinked config points into the read-only Nix store, so writes fail and Codex repeatedly asks the same trust questions.

Activation merges the generated baseline into existing runtime config:

- Managed keys from Nix win over runtime values.
- Unknown runtime keys are preserved.
- Existing `[projects]` entries are preserved and updated.
- `mcp_servers` is replaced from Nix so removed MCP servers do not linger.
- Stale `default_permissions` and `permissions` keys are deleted when absent from the Nix baseline.

Both legacy `~/.codex` and XDG Codex homes are seeded because Codex, Home Manager, and older runtime state can disagree about which home exists first.

## MCP Servers

MCP servers are imported from `../mcp/servers.nix` and translated into Codex's native `config.toml` schema.

Configured servers:

| Server | Transport | Notes |
|--------|-----------|-------|
| `cloudflare` | HTTP | Shared Cloudflare docs/tools server |
| `context7` | HTTP | Uses `CONTEXT7_API_KEY` via `bearer_token_env_var` |
| `exa` | HTTP | Web search and fetch |
| `nixos` | stdio | Shared NixOS/Home Manager/nix-darwin reference server |
| `svelte` | HTTP | Svelte documentation tools |

`jina` is intentionally not wired here. It requires `JINA_API_KEY`, and Codex startup should not warn about an MCP server that is not explicitly enabled.

## Skills

Skills inject instructions into the active conversation. Type `$` in the composer to open the picker, or type `$skill-name` directly.

Skills come from three generated sets:

- Shared skills from `assistants/skills/*/SKILL.md`
- Standalone assistant commands from `assistants/commands/*`
- Agent command skills named `<agent>-<command>`

Every generated skill is explicitly enabled in `config.toml` with `[[skills.config]]`. Codex does not prompt when loading instruction-only skills, so root sessions and spawned agents can use them without an approval round trip.

The `approval_policy.granular.skill_approval` setting is not used. Codex documents that field as controlling skill-script approval prompts; setting it to `false` auto-rejects those prompts rather than allowing skill use.

Skills are written as real files via the shared assistants activation. Codex's scanner does not reliably follow symlinked skill files on Linux.

SKILL.md frontmatter requires `name:` and `description:` fields. Quote any `description:` value containing `: `, or Codex fails to parse the skill.

### Command Skills

Codex no longer supports user-defined slash commands. The `/` commands are built into the binary. Custom commands are deployed as skills instead.

Each agent command becomes a skill named `<agent>-<command>`. When the command has `header.codex.toml` with `spawn-agent = true`, the generated skill tells Codex to launch that specialist with `spawn_agent` and keep the parent thread as the orchestrator. Commands without that flag still embed the agent persona plus the command task prompt.

```text
$garfield-create-conventional-commit
$donatello-implement-code
$penfold-deep-research
```

Standalone commands become unprefixed skills:

```text
$ready
$onboard
$orientate
$collaborate
$botsnack
```

## Agents

Agent role files live in `~/.codex/agents/*.toml`. They define roles available to Codex's `spawn_agent` tool, alongside built-in roles such as `explorer` and `worker`.

Agent files are composed from `prompt.md`, `description.txt`, and `header.codex.toml`. The Codex header carries role-local config such as `model = "gpt-5.5"` and `model_reasoning_effort = "high"`.

The generated `default.toml` role is a Traya alias, so omitted `agent_type` values use Traya's orchestrator prompt instead of Codex's built-in default role.

The files must be real TOML files, not symlinks. Codex's role discovery skips symlinked role files on Linux.

The `traya` role is written by an activation-time TOML writer instead of an inline Nix string. That avoids malformed TOML when long developer instructions contain multiline text, quotes, or secret-provided bond content.

Agent roles are not a TUI persona picker. `/agent` shows active live threads. The model chooses these roles only when it calls the sub-agent tools.

## Sandbox

The module uses the legacy workspace-write sandbox:

```toml
sandbox_mode = "workspace-write"

[sandbox_workspace_write]
network_access = true
```

Do not use Codex `default_permissions` split profiles here on Linux. Current Codex split permission profiles cannot combine custom filesystem rules with normal Unix-socket network access:

- Without `permissions.<profile>.network`, Codex installs restricted network seccomp and Nix cannot connect to its daemon socket.
- With `permissions.<profile>.network.enabled = true`, Codex enters managed proxy mode. On Linux, that mode blocks new `AF_UNIX` and `socketpair` creation inside commands.
- Determinate Nix, the Nix daemon, Tokio-based CLIs, and similar developer tools need normal local Unix socket support.

Writable roots:

```text
~/Chainguard
~/Development
~/Volatile
~/Zero
~/.cache/nix
```

`~/.cache/nix` is required because Nix writes flake fetcher lock files there before it talks to the daemon. Without this writable root, `just eval` fails with a read-only filesystem error under `~/.cache/nix/fetcher-locks`.

Activation creates `~/.cache/nix/fetcher-locks` so the mount target exists before Codex starts.

Outbound network is enabled for sandboxed commands so tools such as `gh`, `nix`, and package managers can reach upstream services directly.

## Nix And Determinate Nix

Subprocesses get:

```toml
[shell_environment_policy.set]
NIX_REMOTE = "daemon"
```

`NIX_REMOTE=daemon` makes Nix use the daemon store rather than trying to write directly to `/nix/store`. With Determinate Nix this still resolves to the normal local daemon store protocol. `nix store ping` should report the daemon store and trusted access.

Determinate Nixd has its own socket for Determinate-specific APIs, but normal Nix store operations still use the Nix daemon store path.

## Approval Policy And Rules

Codex runs with:

```toml
approval_policy = "never"
allow_login_shell = false
```

This matches the desired local workflow: trusted workspaces should not prompt for every edit or MCP call. Dangerous command prefixes are still blocked by generated exec policy rules in `~/.codex/rules/default.rules`.

Rules are rendered from Nix as `prefix_rule()` calls. Decision precedence is:

```text
forbidden > prompt > allow
```

Allow rules cover narrow maintenance commands:

| Category | Commands |
|----------|----------|
| Nix evaluation and formatting | `nix-instantiate`, `nixfmt` |

Prompt rules mirror the Claude Code and OpenCode ask lists for mutating shell commands, network fetches, process termination, service changes, Docker state changes, builds, package managers, Git/GitHub mutations, Nix builds and rebuilds, and Cloudflare deployments.

With `approval_policy = "never"`, prompt rules do not become interactive prompts in non-interactive contexts. They still document the intended policy shape and keep parity with the other assistants.

### Forbidden Commands

Forbidden rules are unconditional. They block high-risk commands regardless of approval mode.

| Category | Commands |
|----------|----------|
| Privilege escalation | `sudo` |
| Disk operations | `dd`, `fdisk`, `parted`, `mkfs`, `mkswap`, `mount`, `umount` |
| Kernel modification | `sysctl`, `modprobe`, `insmod`, `rmmod` |
| Boot and firmware | `grub-install`, `efibootmgr` |
| Subshell bypasses | `bash -c`, `sh -c`, `python -c`, `node -e`, `perl -e`, etc. |
| System power | `systemctl poweroff/reboot/halt/suspend/hibernate` |
| Destructive git | `git push --force`, `git reset --hard`, `git clean`, `git filter-branch` |
| Mass deletion | `docker system prune`, `docker volume prune` |
| Secure deletion | `shred`, `wipe`, `srm`, `truncate` |
| Nix store deletion | `nix-collect-garbage`, `nix store gc`, `nix store delete` |

`allow_login_shell = false` rejects login-shell requests before command policy evaluation. The rules file also blocks shell `-c` and `-lc` prefixes so compound shell commands cannot bypass per-command policy.

## Environment

`shell_environment_policy` uses the `core` inheritance baseline and removes common credential variables from every subprocess environment:

```text
AWS_* AZURE_* GOOGLE_* GCLOUD_* GH_TOKEN GITHUB_TOKEN
ANTHROPIC_API_KEY OPENAI_API_KEY GEMINI_API_KEY
*_API_KEY *_SECRET *_TOKEN
SSH_AUTH_SOCK SSH_AGENT_PID GPG_AGENT_INFO
```

This keeps authentication material out of command environments by default while preserving core process variables such as `PATH` and `HOME`.

## Project Trust

The `[projects]` block pre-seeds trust for the development roots so Codex does not ask "Do you trust this directory?" on every launch.

Codex matches the current working directory or git repository root exactly against `[projects]` keys. Parent directory entries are not inherited. `~/Zero/nix-config` therefore needs its own trust entry even though `~/Zero` is already trusted.

Current seeded entries:

```text
~/Chainguard
~/Development
~/Volatile
~/Zero
~/Zero/nix-config
```

Codex can append new trust decisions at runtime. The merge script preserves unknown project entries while keeping the managed baseline up to date.

## File Layout

```text
codex/
├── README.md
└── default.nix          # config.toml, launcher, sandbox, rules, MCP servers

assistants/
├── agents/<name>/
│   ├── prompt.md
│   ├── description.txt
│   └── commands/<cmd>/
│       ├── prompt.md
│       └── description.txt
├── commands/<name>/
│   ├── prompt.md
│   └── description.txt
├── skills/<name>/
│   └── SKILL.md
├── compose.nix
└── default.nix
```

Source for agents, commands, and skills lives under `assistants/`. The assistants mixin writes Codex-ready real files under `~/.codex/` during activation.

## Verification

After changing this module, run:

```bash
nixfmt --check home-manager/_mixins/development/codex/default.nix
just eval
```

Useful runtime checks after activation and a fresh Codex restart:

```bash
nix store ping
test -w ~/.cache/nix/fetcher-locks
rg -n 'default_permissions|\[permissions|permissions\.|network_access|NIX_REMOTE' ~/.codex/config.toml
```
