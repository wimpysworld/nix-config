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
- **Inference path**: Baseten Model APIs plus OAuth-backed cloud providers managed by Hermes
- **Primary model**: `zai-org/GLM-5.3-Flash` via the `custom:baseten` provider
- **Delegation model**: `gpt-5.6-sol` at high reasoning via the `openai-codex` provider
- **Auxiliary model**: `gpt-5.6-luna` at extra-high (`xhigh`) reasoning via the `openai-codex` provider
- **Memory provider**: Holographic
- **Default TTS**: local Piper using `en_GB-vctk-medium`, speaker `p276`/`11`
- **Web dashboard**: `https://revan.<tailnet>/` through Caddy/Tailscale
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
    default = "zai-org/GLM-5.3-Flash";
    provider = "custom:baseten";
  };

  providers.baseten = {
    name = "baseten";
    api = "https://inference.baseten.co/v1";
    key_env = "BASETEN_API_KEY";
    default_model = "zai-org/GLM-5.3-Flash";
    discover_models = true;
  };

  agent.reasoning_effort = "medium";

  delegation = {
    provider = "openai-codex";
    model = "gpt-5.6-sol";
    reasoning_effort = "high";
  };

  auxiliary = {
    approval = {
      provider = "openai-codex";
      model = "gpt-5.6-luna";
      reasoning_effort = "xhigh";
    };
  };

  memory = {
    memory_enabled = true;
    user_profile_enabled = true;
    provider = "holographic";
  };
};
```

This means the live default is `zai-org/GLM-5.3-Flash` through the Baseten
Model APIs endpoint. Baseten is configured as a named custom provider with
model discovery enabled, so Hermes fetches the full multi-model catalogue
from `/v1/models` at runtime. Delegated work uses `gpt-5.6-sol` at high
reasoning, and the configured auxiliary roles use `gpt-5.6-luna` at
extra-high (`xhigh`) reasoning, both through `openai-codex`.

At runtime, any Baseten model is reachable with the triple syntax
`custom:baseten:<model-id>`, for example `custom:baseten:zai-org/GLM-5.2`.

## Local Piper TTS

Hermes supports a native Piper provider. This deployment uses that provider
instead of a command wrapper, so synthesis happens inside Hermes through the
Python `piper` module.

The Hermes package is pinned to a native-Piper commit. Hermes' current native
Piper runtime reads the provider config but does not yet pass `speaker_id` into
Piper's `SynthesisConfig`, so this deployment injects `HERMES_PIPER_SPEAKER_ID=11`
through the managed `sitecustomize.py` shim. That keeps synthesis inside Hermes'
native Python provider while selecting Traya's VCTK `p276` voice without shelling
out to the `piper` CLI.

The voice assets are fixed-output Nix fetches from
`rhasspy/piper-voices` at revision
`7a6c333ec560f0e688371adc2fbb7bbe105028c6`:

- model: `en/en_GB/vctk/medium/en_GB-vctk-medium.onnx`
- config: `en/en_GB/vctk/medium/en_GB-vctk-medium.onnx.json`
- speaker: `p276`
- speaker id: `11`

The config shape is:

```nix
tts = {
  provider = "piper";
  piper = {
    voice = "${piperVctkMediumVoice}/en_GB-vctk-medium.onnx";
    voices_dir = "${piperVctkMediumVoice}";
    speaker_id = 11;
    length_scale = 1.25;
    noise_scale = 0.35;
    noise_w_scale = 0.80;
    use_cuda = false;
    normalize_audio = true;
  };
};
```

The synthesis tuning above keeps the VCTK `p276` voice a little quicker than
the upstream model defaults while preserving a soft, breathy cadence:

- `length_scale = 1.25` shortens phoneme duration from the model's slower `1.4`
  default.
- `noise_scale = 0.35` keeps acoustic texture close to the model's `0.333`
  default without roughening the voice.
- `noise_w_scale = 0.80` increases timing variation for a shy, less mechanical
  delivery.

The model and JSON config are symlinked into one Nix store directory before
use. Piper resolves `<model>.json` next to the ONNX model at runtime, so the
two fetched files must remain adjacent.

## Web Dashboard

Hermes Agent v2026.4.23 adds `hermes dashboard`, but the upstream NixOS module
still only manages `hermes gateway`. It does not expose dashboard options.

This mixin starts the dashboard as a separate service:

```nix
systemd.services.hermes-agent-dashboard.serviceConfig.ExecStart =
  "hermes dashboard --host 127.0.0.1 --port 9119 --no-open";
```

Port `9119` is the upstream dashboard default and avoids the existing service
on `8080`. The dashboard binds to localhost only. Caddy exposes it on the
Tailnet virtual host root, while path-based services such as Syncthing keep
their existing routes.

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
- `secrets/cloudflare.yaml`
- `secrets/hermes-auth.json`
- `secrets/linear.yaml`
- `secrets/mcp.yaml`
- `secrets/traya.yaml`

The live env template is rendered through `sops.templates."hermes-env"` and
currently exports:

- `TELEGRAM_BOT_TOKEN`
- `TELEGRAM_ALLOWED_USERS`
- `WEBHOOK_ENABLED`
- `WEBHOOK_PORT`
- `WEBHOOK_SECRET`
- `BASETEN_API_KEY`
- `CONTEXT7_API_KEY`
- `JINA_API_KEY`
- `LINEAR_API_KEY`
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
- `BASETEN_API_KEY` authenticates the Baseten custom provider and comes from
  `secrets/ai.yaml`
- `LINEAR_API_KEY` comes from the `wimpysworld` key in `secrets/linear.yaml`
- `traya@darth.cc` Fastmail access is rendered to the Himalaya config from
  `secrets/traya.yaml`
- `EMAIL_PASSWORD` must be a Fastmail app password, not the regular web login
  password
- `WEBHOOK_SECRET` must be a dedicated HMAC secret in `secrets/hermes.yaml`
- `CLOUDFLARE_TUNNEL_TOKEN_HERMES` must be a dedicated Cloudflare Tunnel
  connector token in `secrets/cloudflare.yaml`
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

## Webhooks

The Hermes webhook platform is enabled on localhost:

```nix
services.hermes-agent.settings.platforms.webhook = {
  enabled = true;
  extra = {
    host = "127.0.0.1";
    port = 8644;
    secret = "\${WEBHOOK_SECRET}";
  };
};
```

The public endpoint is exposed through a dedicated remotely-managed Cloudflare
Tunnel connector, not by opening port `8644` directly. The connector service is
`cloudflared-hermes` and uses `CLOUDFLARE_TUNNEL_TOKEN_HERMES` from
`secrets/cloudflare.yaml`.

The LibreChat tunnel configuration is the reusable pattern, but the LibreChat
tunnel token is not reused. Keep a separate Hermes tunnel token so webhook
routing and token rotation stay isolated from LibreChat.

In Cloudflare, publish the chosen webhook hostname to:

```text
http://127.0.0.1:8644
```

After deployment, the local health check should return OK:

```bash
curl http://127.0.0.1:8644/health
```

### GitHub Notifications

GitHub Notifications remain polling-based. GitHub does not provide a standard
webhook for a user's personal Notifications inbox, and repository,
organisation, or GitHub App webhooks only cover activity in explicitly
configured scopes.

Do not add a production `github-notifications` webhook route unless the design
is intentionally hybrid. A webhook can reduce latency for configured
repositories or organisations, but it cannot replace the Notifications REST API
poller as the source of truth.

The `github-notifications` route is left absent in the Nix config. Do not use a
`null` tombstone here: Hermes v2026.4.30 validates route values at startup and a
rendered `null` entry prevents the webhook listener from binding.

## Kanban and Sanctuary

Traya's live operational state belongs in Hermes Kanban.
The `traya-ops` board is the source of truth for task and state tracking,
including active work, blocked work, waiting-on-Martin items, recurring
automation follow-up, and durable hand-offs that must survive session loss.
Read and update that board only through the Hermes Kanban CLI tool
(`hermes kanban ...`). Do not read or mutate Kanban database files, runtime
snapshots, API internals, or markdown exports directly.

Traya-owned report files and continuity records live under
`/var/lib/hermes/workspace/trayas-sanctuary`.
Use sanctuary for Git-backed artefacts such as:

- persisted morning briefing markdown
- daily self-reflection markdown
- plans and decisions
- runbooks and policies
- durable research notes and historical summaries that are not better housed in a task repo

When creating Traya-owned operational files:

- write live tasks, blockers, and follow-up state to `traya-ops` Kanban cards
- write human-facing reports under tracked sanctuary paths such as `docs/`,
  `plans/`, `notes/briefings/`, `notes/reflections/`, and `notes/research/`
- keep raw evidence, local snapshots, generated audio, logs, locks, cursors,
  and scratch files under ignored `runtime/` paths only when they are not task state
- do not use sanctuary `status/work/*`, runtime queues, or ad-hoc markdown
  ledgers as live operational state once a Kanban card can represent the work
- keep cloned repos and task-specific code outside sanctuary under `/var/lib/hermes/workspace`
- do not leave continuity artefacts in the workspace root unless a task explicitly requires it

If work belongs to a specific repo, do the work there and track the task in Kanban.
Promote only durable reports, decisions, research notes, or final continuity summaries into sanctuary.

The runtime-local-first rule still applies.
Hermes should keep functioning from local Kanban and local sanctuary files even if GitHub is unavailable.
The private GitHub repo `the-cauldron/trayas-sanctuary` is for report durability and audit trail, not as the only live copy.

## MCP Servers

The current declared MCP servers are:

- `exa`
- `context7`
- `linear`
- `nixos`
- `openhue`

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

  linear = {
    url = "https://mcp.linear.app/mcp";
    headers.Authorization = "Bearer \${LINEAR_API_KEY}";
  };

  nixos = {
    command = "${pkgs.mcp-nixos}/bin/mcp-nixos";
    args = [ ];
  };

  openhue = {
    command = "${pkgs.openhue-cli}/bin/openhue";
    args = [ "mcp" ];
    env.HOME = config.services.hermes-agent.stateDir;
  };
};
```

Notes:

- Linear uses its read-write endpoint with API-key bearer authentication. No
  tool filters are set, so Hermes exposes every tool that the server provides.
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

- the Hermes module selects the primary and role providers
- `custom:baseten` handles the primary `zai-org/GLM-5.3-Flash` route
- `openai-codex` handles delegated work with `gpt-5.6-sol` at high reasoning
- `openai-codex` handles configured auxiliary roles with `gpt-5.6-luna` at extra-high (`xhigh`) reasoning
- there is no cloud fallback provider configured

The Baseten provider points at the OpenAI-compatible Model APIs endpoint
`https://inference.baseten.co/v1`. Authentication uses `BASETEN_API_KEY` from
the managed env file, and `discover_models = true` keeps the model picker
populated from the live catalogue. Baseten honours top-level
`reasoning_effort`, which matches how Hermes sends effort for custom
providers.

The local llama-server stack remains available in the repo, but it is not the
active primary route in the current deployment.

The important current routing values are:

- primary model: `zai-org/GLM-5.3-Flash` at medium reasoning
- delegation model: `gpt-5.6-sol` at high reasoning
- auxiliary model: `gpt-5.6-luna` at extra-high (`xhigh`) reasoning
- Baseten multi-model catalogue: reachable as `custom:baseten:<model-id>`
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
- `custom:baseten` primary with `zai-org/GLM-5.3-Flash` and multi-model discovery
- `openai-codex` delegation with `gpt-5.6-sol` at high reasoning
- `openai-codex` auxiliary roles with `gpt-5.6-luna` at extra-high (`xhigh`) reasoning
- Holographic memory
- Linear MCP with read-write, unfiltered tool access

## What Is Deliberately Deferred

The following are still future work, not part of the current implementation:

- additional MCP servers such as Jina or GitHub
- richer routing policies beyond the current primary model and the role models
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
  remote model
- expanding the inference host layout as the `llama-server` model policy evolves
- turning the reserved Sith identities into active subordinate agents once Traya
  is stable

Any future update to this README should start from the live Nix modules, not
from older research notes.
