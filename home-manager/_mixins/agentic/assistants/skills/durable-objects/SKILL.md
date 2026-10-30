# Durable Objects

## Managed tooling and authority

Home Manager supplies Wrangler on Martin's developer workstations. Use the project's pinned Wrangler when available, or the managed `wrangler` executable.
Do not install or upgrade tools automatically, including through `npx`. If a required tool or version is absent, report the dependency.
The `cf` CLI, `cloudflared`, and unbundled skills are not supplied by this integration. Upstream CLI selection guidance does not authorise their installation.
For a project that requires `cf`, stop CLI work and request separate approval rather than convert the project to Wrangler.
Use the configured `cloudflare-docs` MCP server for documentation only, or fetch official documentation directly.
The managed `wrangler` wrapper reads `CLOUDFLARE_ACCOUNT_ID` and `CLOUDFLARE_API_TOKEN` from SOPS runtime files only when their explicit environment overrides are absent.
The configured `cloudflare-api` MCP wrapper uses the same token, not a separate MCP token.
It passes `API_ACCESS_TOKEN` only to `pkgs.mcp-proxy`, which connects to `https://mcp.cloudflare.com/mcp` through the canonical stdio entry.
Project-local Wrangler does not automatically use the managed wrapper's authentication.
Use these runtime paths for task-scoped reads without repeated authentication approval, including unattended reads.
Do not read or decrypt credential files yourself, print credentials, or copy them into arguments, logs, source, or client configuration.
Do not export credentials globally or expose the R2 credentials to Wrangler or MCP.
The separate R2 keys are `CLOUDFLARE_ACCESS_KEY_ID`, `CLOUDFLARE_SECRET_ACCESS_KEY`, and `CLOUDFLARE_S3_API_ENDPOINT`.
If runtime credentials are unavailable, report the missing setup rather than run login or create replacement tokens.
Login, new tokens, and secret or credential-wiring changes require explicit approval.
Credential permissions do not grant operation authority.
Deployments, resource changes, remote tests, and unauthenticated claim deployments require explicit authority for the target account, environment, and operation.
These limits also apply to the examples and linked references below.
Resolve body references from this skill's directory and nested links from the file that contains them.

Build stateful, coordinated applications on Cloudflare's edge using Durable Objects.

## Retrieval Sources

Your knowledge of Durable Objects APIs and configuration may be outdated. **Prefer retrieval over pre-training** for any Durable Objects task.

| Resource | URL |
|----------|-----|
| Docs | https://developers.cloudflare.com/durable-objects/index.md |
| API Reference | https://developers.cloudflare.com/durable-objects/api/index.md |
| Best Practices | https://developers.cloudflare.com/durable-objects/best-practices/index.md |
| Examples | https://developers.cloudflare.com/durable-objects/examples/index.md |
| Roles and permissions | https://developers.cloudflare.com/workers/authorization/durable-objects/index.md |

Fetch the relevant doc page when implementing features.

## When to Use

- Creating new Durable Object classes for stateful coordination
- Implementing RPC methods, alarms, or WebSocket handlers
- Reviewing existing DO code for best practices
- Configuring wrangler.jsonc/toml for DO bindings and migrations
- Writing tests with Cloudflare’s Vitest integration
- Designing sharding strategies and parent-child relationships

## Reference Documentation

- `./references/rules.md` - Core rules, storage, concurrency, RPC, alarms
- [Testing reference](./references/testing.md) - Current Vitest documentation, migration choices, and test selection
- `./references/workers.md` - Workers handlers, types, wrangler config, observability

Search: `blockConcurrencyWhile`, `idFromName`, `getByName`, `setAlarm`, `sql.exec`

## Core Principles

### Use Durable Objects For

| Need | Example |
|------|---------|
| Coordination | Chat rooms, multiplayer games, collaborative docs |
| Strong consistency | Inventory, booking systems, turn-based games |
| Per-entity storage | Multi-tenant SaaS, per-user data |
| Persistent connections | WebSockets, real-time notifications |
| Scheduled work per entity | Subscription renewals, game timeouts |

### Do NOT Use For

- Stateless request handling (use plain Workers)
- Maximum global distribution needs
- High fan-out independent requests

## Quick Reference

### Wrangler Configuration

```jsonc
// wrangler.jsonc
{
  "durable_objects": {
    "bindings": [{ "name": "MY_DO", "class_name": "MyDurableObject" }]
  },
  "migrations": [{ "tag": "v1", "new_sqlite_classes": ["MyDurableObject"] }]
}
```

### Basic Durable Object Pattern

```typescript
import { DurableObject } from "cloudflare:workers";

export interface Env {
  MY_DO: DurableObjectNamespace<MyDurableObject>;
}

export class MyDurableObject extends DurableObject<Env> {
  constructor(ctx: DurableObjectState, env: Env) {
    super(ctx, env);
    ctx.blockConcurrencyWhile(async () => {
      this.ctx.storage.sql.exec(`
        CREATE TABLE IF NOT EXISTS items (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          data TEXT NOT NULL
        )
      `);
    });
  }

  async addItem(data: string): Promise<number> {
    const result = this.ctx.storage.sql.exec<{ id: number }>(
      "INSERT INTO items (data) VALUES (?) RETURNING id",
      data
    );
    return result.one().id;
  }
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const stub = env.MY_DO.getByName("my-instance");
    const id = await stub.addItem("hello");
    return Response.json({ id });
  },
};
```

## Critical Rules

1. **Model around coordination atoms** - One DO per chat room/game/user, not one global DO
2. **Use `getByName()` for deterministic routing** - Same input = same DO instance
3. **Prefer SQLite for new classes** - For projects that use migrations, declare new SQLite classes with `new_sqlite_classes`. Inspect existing classes' storage backends before selecting APIs. Preserve existing backends, including key-value (KV) storage, unless the user explicitly authorises a migration. Before any authorised migration, verify the supported path in the current documentation.
4. **Initialize in constructor** - Use `blockConcurrencyWhile()` for schema setup only
5. **Prefer RPC methods for direct calls** (compatibility date >= 2024-04-03). Retain `fetch()` handlers for HTTP request/response flows and WebSocket upgrades.
6. **Persist first, cache second** - Always write to storage before updating in-memory state
7. **One alarm per DO** - `setAlarm()` replaces any existing alarm

## Authorization

Durable Objects do not have separate roles or permissions; access follows the Worker that implements them. Retrieve the current [Durable Objects authorization guidance](https://developers.cloudflare.com/workers/authorization/durable-objects/index.md) before granting observability or Data Studio access, and scope the Workers role to the intended Worker or Workers product.

## Anti-Patterns (NEVER)

- Single global DO handling all requests (bottleneck)
- Using `blockConcurrencyWhile()` on every request (kills throughput)
- Storing critical state only in memory (lost on eviction/crash)
- Using `await` between related storage writes (breaks atomicity)
- Holding `blockConcurrencyWhile()` across `fetch()` or external I/O

## Stub Creation

```typescript
// Deterministic - preferred for most cases
const stub = env.MY_DO.getByName("room-123");

// From existing ID string
const id = env.MY_DO.idFromString(storedIdString);
const stub = env.MY_DO.get(id);

// New unique ID - store mapping externally
const id = env.MY_DO.newUniqueId();
const stub = env.MY_DO.get(id);
```

## Storage Operations

```typescript
// SQL (synchronous, recommended)
this.ctx.storage.sql.exec("INSERT INTO t (c) VALUES (?)", value);
const rows = this.ctx.storage.sql.exec<Row>("SELECT * FROM t").toArray();

// KV (async)
await this.ctx.storage.put("key", value);
const val = await this.ctx.storage.get<Type>("key");
```

## Alarms

```typescript
// Schedule (replaces existing)
await this.ctx.storage.setAlarm(Date.now() + 60_000);

// Handler
async alarm(): Promise<void> {
  // Process scheduled work
  // Optionally reschedule: await this.ctx.storage.setAlarm(...)
}

// Cancel
await this.ctx.storage.deleteAlarm();
```

## Testing

Read the [testing reference](./references/testing.md) before configuring a suite or writing Durable Object tests. It routes to current setup, APIs, and examples and identifies the behavior to cover.

## Skill feedback

If the user reports that this skill gave incorrect or outdated guidance, or is missing information, read [references/skill-feedback.md](references/skill-feedback.md).
