# AgentsView

AgentsView gives local and service-run agents one shared dashboard. Each
machine pushes its local AgentsView state into PostgreSQL, and the server mixin
serves a read-only web UI at `/agentsview` over the Tailnet Caddy host.

Use it when you need to inspect agent activity across machines without logging
into each host or copying local state by hand.

## Architecture

The implementation has three parts:

- [nixos/_mixins/server/agentsview/default.nix](default.nix) wires the server
  mixin, SOPS secret template, shell alias, and Caddy route.
- [nixos/_mixins/server/agentsview/module.nix](module.nix) runs
  `agentsview pg serve` as a hardened systemd service.
- [home-manager/_mixins/agentic/agentsview/default.nix](../../../../home-manager/_mixins/agentic/agentsview/default.nix)
  installs a wrapped `agentsview` CLI for developer users and pushes local data
  on a user timer.

[nixos/_mixins/server/hermes/default.nix](../hermes/default.nix) adds a fourth
producer: Hermes pushes its managed service state into the same PostgreSQL
schema with a distinct machine name.

## Central Server

Hosts tagged `agentsview` run the central dashboard:

```nix
noughtyLib.hostHasTag "agentsview"
```

The service runs:

```bash
agentsview pg serve \
  --host 127.0.0.1 \
  --port 18080 \
  --base-path /agentsview \
  --public-url https://<host>.<tailnet> \
  --no-browser \
  --no-update-check
```

It binds to localhost only. Caddy exposes it at:

```text
https://<host>.<tailnet>/agentsview/
```

The route forwards `/agentsview/*` unchanged because AgentsView already serves
with `--base-path /agentsview`.

## PostgreSQL Sharing

AgentsView uses PostgreSQL as the shared transport. Producers push local state
into the `agentsview` schema, then the server reads that schema for the
dashboard.

Configured producers:

| Producer | Scope | Machine name |
| --- | --- | --- |
| Home Manager developer profile | Local user sessions | host name |
| Hermes NixOS service | Managed Hermes sessions | `<host>-hermes` |

Both producer paths set:

```text
AGENTSVIEW_PG_SCHEMA=agentsview
AGENTSVIEW_DISABLE_UPDATE_CHECK=1
```

The server and Hermes generated TOML configs set `pg.schema`,
`pg.machine_name`, and `pg.allow_insecure`. The PostgreSQL URL stays in the
SOPS-rendered environment file.

## Local Home Manager Push

Developer users get a wrapped `agentsview` CLI. The wrapper sources
`agentsview-pg.env` when it exists, so manual CLI use and the timer share the
same database settings through upstream `AGENTSVIEW_PG_*` environment variables.

The user service runs:

```bash
agentsview pg push
```

On Linux, `agentsview-pg-push.timer` starts five minutes after boot, repeats
every fifteen minutes, adds up to two minutes of random delay, and persists
missed runs.

## Hermes Push

Hermes runs a system service push because its state lives under
`/var/lib/hermes`, not a human user's home directory.

The service sets:

```text
AGENTSVIEW_DATA_DIR=/var/lib/hermes/.agentsview
HERMES_SESSIONS_DIR=/var/lib/hermes/.hermes/sessions
HOME=/var/lib/hermes
```

Activation writes:

```text
/var/lib/hermes/.agentsview/config.toml
```

`hermes-agentsview-pg-push.timer` starts seven minutes after boot, repeats every
fifteen minutes, adds up to two minutes of random delay, and persists missed
runs.

## Secrets and Config Split

The PostgreSQL URL comes from `secrets/agentsview.yaml` as
`AGENTSVIEW_PG_URL`. The implementation never writes the URL into TOML.

Server path:

- SOPS reads `AGENTSVIEW_PG_URL`.
- A template renders `agentsview.env` as a `KEY=value` file.
- `agentsview.service` reads that file through `EnvironmentFile`.

Home Manager path:

- SOPS reads `AGENTSVIEW_PG_URL`.
- A template renders `agentsview-pg.env`.
- The wrapper and user service read that environment file.

Hermes path:

- SOPS reads the same key as `HERMES_AGENTSVIEW_PG_URL`.
- A template renders `hermes-agentsview-env`.
- `hermes-agentsview-pg-push.service` reads that environment file.

Keep non-secret config in generated TOML. Keep credentials in SOPS templates.

## Operational Checks

Check the dashboard service:

```bash
systemctl status agentsview.service
agentsview-log
```

Check the server route:

```bash
curl -I https://<host>.<tailnet>/agentsview/
```

Check local user pushes:

```bash
systemctl --user status agentsview-pg-push.timer
systemctl --user status agentsview-pg-push.service
journalctl --user -u agentsview-pg-push.service
```

Check Hermes pushes:

```bash
systemctl status hermes-agentsview-pg-push.timer
systemctl status hermes-agentsview-pg-push.service
journalctl -u hermes-agentsview-pg-push.service
```

If the dashboard loads but a machine is missing, check its push timer first,
then confirm the relevant SOPS-rendered environment file exists and contains
only variable names plus redacted secret material when viewed through safe
inspection tooling.
