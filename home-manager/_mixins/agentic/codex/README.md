# Codex

[Codex CLI](https://github.com/openai/codex) configured declaratively via Home Manager. The module writes Codex configuration, MCP servers, generated skills, and agent roles from Nix while keeping Codex's runtime state mutable.

The [Fence](../fence)-isolated entry point is `codex-fenced`.

```bash
codex                  # start interactive TUI
codex-fenced           # start Codex under Fence
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

The source package and stable binary copy are retained so plain `codex` can use
the standard Codex runtime. The fenced entry point uses the same launcher while
Fence provides the managed filesystem, network, and command policy.

## Configuration

Codex reads `~/.codex/config.toml` on this system. Home Manager writes the file as a real mutable file during activation, not as a symlink into the Nix store.

This matters because Codex edits `config.toml` at runtime to persist trust decisions and other state. A symlinked config points into the read-only Nix store, so writes fail and Codex repeatedly asks the same trust questions.

Activation merges the generated baseline into existing runtime config:

- Managed keys from Nix win over runtime values.
- Unknown runtime keys are preserved.
- Existing `[projects]` entries are preserved and updated.
- `mcp_servers` is replaced from Nix so removed MCP servers do not linger.
- Managed keys removed from the Nix baseline are deleted from runtime config.

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
| `playwright` | stdio | Conditional browser automation server; configured with `enabled = false` by default |
| `svelte` | HTTP | Svelte documentation tools |

`playwright` is emitted only when both Chromium and Firefox are enabled under the shared browser automation policy.

`jina` is intentionally not wired here. It requires `JINA_API_KEY`, and Codex startup should not warn about an MCP server that is not explicitly enabled.

## Skills

Skills inject instructions into the active conversation. Type `$` in the composer to open the picker, or type `$skill-name` directly.

Skills come from three generated sets:

- Shared skills from `assistants/skills/*/SKILL.md`, plus generated shared skills
- Standalone assistant commands from `assistants/commands/*`
- Agent command skills named `<agent>-<command>`

Every generated skill is explicitly enabled in `config.toml` with `[[skills.config]]`, so root sessions and spawned agents can use the same declarative skill set.

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

The files must be real TOML files, not symlinks. Codex's role discovery skips symlinked role files on Linux.

The unnamed default prompt is written to `AGENTS.md` from `instructions/global.md`. Traya is not exposed as a named Codex role.

Agent roles are not a TUI persona picker. `/agent` shows active live threads. The model chooses these roles only when it calls the sub-agent tools.

## Fenced Mode

Use `codex-fenced` for the Fence-isolated entry point. It runs:

```console
fence -- codex --dangerously-bypass-approvals-and-sandbox
```

Fence owns filesystem isolation, network access, and command denials for this
entry point. The Codex bypass flag prevents a second policy layer from
interfering with the shared Fence configuration.

Activation removes stale policy keys and generated rule files from both legacy
and XDG Codex homes so Fence remains the only managed permission and isolation
provider.

Use `codex-fenced` when the shared Fence policy should be the only isolation and command boundary.

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
└── default.nix          # config.toml, launcher, fenced wrapper, MCP servers

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
nixfmt --check home-manager/_mixins/agentic/codex/default.nix
just eval
```

Useful runtime checks after activation and a fresh Codex restart:

```bash
nix store ping
test -w ~/.cache/nix/fetcher-locks
fence show config
codex-fenced --version
```
