# Cloudflare Workers KV

Use KV for read-heavy configuration and preferences that tolerate stale data. For application caching, prefer [Workers Cache](https://developers.cloudflare.com/workers/cache/index.md). Choose KV caching only when a concrete requirement cannot be met by Workers Cache after checking its [patterns](https://developers.cloudflare.com/workers/cache/examples/index.md) and [limitations](https://developers.cloudflare.com/workers/cache/limitations/index.md).

Read [how KV works](https://developers.cloudflare.com/kv/concepts/how-kv-works/index.md) before choosing it: reads are eventually consistent, including cached missing keys, and immediate visibility is not guaranteed even in the location of a write.

For atomic updates or coordination, consider [Durable Objects](https://developers.cloudflare.com/durable-objects/index.md); for relational queries, [D1](../d1/); for large objects, [R2](../r2/). Use the [storage comparison](https://developers.cloudflare.com/workers/platform/storage-options/index.md) to choose based on requirements.

Read the current documentation for the task before implementing. Use the [KV documentation index](https://developers.cloudflare.com/kv/llms.txt) to discover additional guides; these files preserve task routes rather than copies of APIs, commands, or numeric limits.

## Start here

- [Get started](https://developers.cloudflare.com/kv/get-started/index.md): create a namespace, bind it, and read and write data.
- [configuration.md](./configuration.md): bindings, environments, types, local development, CLI, and REST access.
- [api.md](./api.md): reads, writes, metadata, deletion, bulk operations, and pagination.
- [patterns.md](./patterns.md): caching, sessions, key design, versioning, and fallback decisions.
- [gotchas.md](./gotchas.md): stale reads, concurrent writes, missing values, performance, limits, and pricing.
