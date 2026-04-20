# Hermes on Revan

This document describes the current Hermes deployment as implemented by
[default.nix](default.nix), with related local inference capacity under
[llama-server](../llama-server/default.nix).
It is the operational source of truth for the landed setup.

## Overview

The current deployment is:

- **Agent framework**: Hermes Agent
- **Chat interface**: Telegram
- **Hermes host**: `revan`
- **Inference path**: OAuth-backed cloud providers managed by Hermes
- **Primary model**: `gpt-5.4` via the `openai-codex` provider
- **Fallback model**: `gpt-5.4` via the `copilot` provider
- **Memory provider**: Holographic
- **Deployment mode**: native NixOS service, not podman container mode

Earlier research notes in this directory were useful while choosing the stack.
They are no longer the source of truth. The Nix modules are.

## Module Layout

The deployment is split across two mixins:

- [nixos/_mixins/server/hermes/default.nix](default.nix)
  configures the Hermes service, secrets, identity, MCP servers, and host CLI
  access.
- [nixos/_mixins/server/llama-server/default.nix](../llama-server/default.nix)
  enables `llama.cpp` and `llama-swap` on inference hosts.
- [nixos/_mixins/server/llama-server/model-policy.nix](../llama-server/model-policy.nix)
  defines the model matrix, context windows, KV cache settings, and generation
  defaults.
- [nixos/_mixins/server/llama-server/README.md](../llama-server/README.md)
  captures the backend, hardware, and llama-server operational details.

Host gating is tag-based:

- Hermes is enabled on hosts tagged `hermes`
- llama-server is enabled on hosts tagged `inference`

## Current Hermes Service

Hermes is enabled through the upstream flake module:

```nix
imports = [
  inputs.hermes-agent.nixosModules.default
];

services.hermes-agent.enable = true;
```

The current service is native, not containerised. The README previously
described podman mode in detail. That is no longer accurate for the landed
implementation.

The key current settings are:

```nix
services.hermes-agent.settings = {
  model = {
    default = "gpt-5.4";
    provider = "openai-codex";
  };

  fallback_model = {
    provider = "copilot";
    model = "gpt-5.4";
  };

  memory = {
    memory_enabled = true;
    user_profile_enabled = true;
    provider = "holographic";
  };
};
```

This means the live default is `gpt-5.4` through `openai-codex`, with a second
`gpt-5.4` route through GitHub Copilot held as fallback.

The remote qwen endpoints remain available as named custom providers:

- `skrye` for `qwen3.5-35b-a3b`
- `zannah` for `qwen3-coder-next` and `qwen3.5-35b-a3b`

## Identity and State

Hermes uses its standard state directory under `/var/lib/hermes`.

Important paths:

- Hermes home: `/var/lib/hermes/.hermes`
- Auth seed target: `/var/lib/hermes/.hermes/auth.json`
- Managed env file target: `/var/lib/hermes/.hermes/.env`
- Identity file: `/var/lib/hermes/.hermes/SOUL.md`
- Himalaya config: `/var/lib/hermes/.config/himalaya/config.toml`

`SOUL.md` is currently installed by tmpfiles as a symlink to a rendered
template. That template composites the public repo copy in `traya-soul.md`.

```nix
sops.templates."hermes-soul" = {
  content = ''
    ${builtins.readFile ./traya-soul.md}
  '';
};

systemd.tmpfiles.rules = [
  "L+ ${hermesHome}/SOUL.md - - - - ${config.sops.templates."hermes-soul".path}"
];
```

That is the current implementation. It is not being declared through
`services.hermes-agent.documents`.

`USER.md` remains Hermes-managed memory and is not declared in Nix.

## Secrets and Auth

Hermes currently draws from several secret sources:

- `secrets/ai.yaml`
- `secrets/hermes.yaml`
- `secrets/hermes-auth.json`
- `secrets/mcp.yaml`
- `secrets/traya.yaml`

The live env template is rendered through `sops.templates."hermes-env"` and
currently exports:

- `TELEGRAM_BOT_TOKEN`
- `TELEGRAM_ALLOWED_USERS`
- `ANTHROPIC_API_KEY`
- `CONTEXT7_API_KEY`
- `JINA_API_KEY`
- `GH_TOKEN`
- `GITHUB_TOKEN`

The current auth seed is separate:

```nix
services.hermes-agent.authFile = config.sops.secrets."hermes/auth".path;
services.hermes-agent.environmentFiles = [
  config.sops.templates."hermes-env".path
];
```

Operationally:

- `.env` is generated state, do not edit it by hand
- `auth.json` is seeded from `secrets/hermes-auth.json`
- OpenAI device auth for `openai-codex` comes from `auth.json`, not from an
  `OPENAI_API_KEY` env var
- GitHub Copilot fallback auth is resolved from the exported GitHub token env
  vars or Hermes-managed auth state
- `ANTHROPIC_API_KEY` remains available from `secrets/ai.yaml` for future
  direct Anthropic provider use
- `traya@darth.cc` Fastmail access is rendered to the Himalaya config from
  `secrets/traya.yaml`
- `EMAIL_PASSWORD` must be a Fastmail app password, not the regular web login
  password
- live token refresh remains in Hermes state after startup

## Telegram

Telegram is the only human-facing interface in the current deployment.

What is wired now:

- `TELEGRAM_BOT_TOKEN` is injected into the managed env file
- `TELEGRAM_ALLOWED_USERS` is injected into the managed env file
- `TELEGRAM_HOME_CHANNEL` is set in `services.hermes-agent.environment`

That means the current service expects:

- a valid bot token
- an explicit allowlist
- a configured Telegram home channel ID

Discord is no longer part of this design.

## Sanctuary

Traya-owned continuity state now lives under `/var/lib/hermes/workspace/trayas-sanctuary`.

Use the sanctuary as the canonical home for:

- durable plans and decisions
- human-facing status ledgers
- persisted morning briefing markdown
- Traya-owned research notes that are not better housed in a task repo

Use `runtime/` inside sanctuary for local-only operational state such as:

- worker queues
- raw inbox snapshots
- generated audio
- logs, locks, and scratch files

The runtime-local-first rule still applies.
Hermes should keep functioning from the local sanctuary even if GitHub is unavailable.
The private GitHub repo `the-cauldron/trayas-sanctuary` is for durability and audit trail, not as the only live copy.

## MCP Servers

The current declared MCP servers are:

- `exa`
- `context7`
- `nixos`
- `cloudflare`

They are configured directly in
[default.nix](default.nix).

Current declaration:

```nix
services.hermes-agent.mcpServers = {
  exa.url = "https://mcp.exa.ai/mcp";

  context7 = {
    url = "https://mcp.context7.com/mcp";
    headers.Authorization = "Bearer \${CONTEXT7_API_KEY}";
  };

  nixos = {
    command = "${pkgs.mcp-nixos}/bin/mcp-nixos";
    args = [ ];
  };

  cloudflare.url = "https://docs.mcp.cloudflare.com/mcp";
};
```

Notes:

- `JINA_API_KEY` is already provisioned in the env template, but there is no
  live Jina MCP server declaration in the module yet.
- The README should stay aligned with the declared set above, not the broader
  future MCP wish list.

## Host Access and Runtime Tools

The Hermes user and group are pinned to `1984`. The interactive user is added
to the `hermes` group on Hermes hosts.

The module also installs a wrapped Bash and a broad toolset for Hermes, which
currently includes `git`, `gh`, `ripgrep`, `fd`, `jq`, `yq`, `just`, `uv`,
`nodejs`, `ffmpeg`, `poppler-utils`, and other CLI tools needed by the agent.

This is done in two places:

- `users.users.hermes.packages`
- `services.hermes-agent.extraPackages`

The wrapped shell is also injected into the systemd unit path so the service
sees the same runtime toolchain.

## Inference Integration

Hermes currently talks to cloud providers through Hermes-managed provider
integrations rather than the local llama-server path.

Current source of truth:

- the Hermes module selects the primary and fallback providers
- `openai-codex` handles the primary `gpt-5.4` route
- `copilot` handles the fallback `gpt-5.4` route
- named custom providers preserve remote qwen routes on `skrye` and `zannah`

The local llama-server stack remains available in the repo, but it is not the
active primary or fallback route in the current deployment.

The important current routing values are:

- primary model: `gpt-5.4`
- fallback model: `gpt-5.4`
- fallback provider: `copilot`
- named custom qwen routes: `skrye:qwen3.5-35b-a3b`, `zannah:qwen3.5-35b-a3b`
- Holographic memory enabled

For local backend and model policy detail, use the llama-server docs:

- [nixos/_mixins/server/llama-server/README.md](../llama-server/README.md)
- [nixos/_mixins/server/llama-server/model-policy.nix](../llama-server/model-policy.nix)

## Day-to-Day Operations

Common service checks:

```bash
sudo systemctl status hermes-agent.service --no-pager -l
sudo journalctl -u hermes-agent.service -n 100 --no-pager -o cat
```

Because Hermes state is service-owned, the safest interactive CLI pattern is:

```bash
sg hermes -c 'export HERMES_HOME=/var/lib/hermes/.hermes && hermes model'
```

Use the same pattern for other host-side Hermes CLI commands when you need to
inspect the managed state directly.

The current deployment has already shown that relying on ambient shell state is
fragile. `HERMES_HOME` should be set explicitly for manual CLI work.

## What Is Landed

The following are in place now:

- Hermes upstream NixOS module import
- host gating by `hermes` tag
- native Hermes systemd service
- fixed Hermes service UID and GID
- host user access via the `hermes` group
- `SOUL.md` linked into Hermes home
- managed `.env` rendering through sops-nix
- auth seeding through `authFile`
- Telegram token and allowlist injection
- `openai-codex` primary with `gpt-5.4`
- `copilot` fallback with `gpt-5.4`
- named custom qwen providers on `skrye` and `zannah`
- Holographic memory
- four live MCP servers: Exa, Context7, NixOS, Cloudflare

## What Is Deliberately Deferred

The following are still future work, not part of the current implementation:

- additional MCP servers such as Jina or GitHub
- richer routing policies beyond the current primary model and fallback
- multi-agent activation for Skrye or Zannah as separate Hermes instances
- broader GitHub automation policy
- any return to podman container mode
- any Discord integration

## Expansion Notes

The current shape leaves room for later growth without pretending it already
exists.

The most likely future areas are:

- adding more MCP servers from the secrets already provisioned
- widening model routing once the Hermes config grows beyond a single primary
  remote model and a single cloud fallback
- expanding the inference host layout as the `llama-server` model policy evolves
- turning the reserved Sith identities into active subordinate agents once Traya
  is stable

Any future update to this README should start from the live Nix modules, not
from older research notes.
