# C3 (create-cloudflare)

## Contents

- [Quick Start](#quick-start)
- [Platform Decision Tree](#platform-decision-tree)
- [Framework Setup](#framework-setup)
- [Interactive Flow](#interactive-flow)
- [Installation Methods](#installation-methods)
- [In This Reference](#in-this-reference)
- [Reading Order](#reading-order)
- [Post-Creation](#post-creation)
- [See Also](#see-also)

Official CLI for scaffolding Cloudflare Workers and Pages projects with templates, TypeScript, and instant deployment.

## Quick Start

```bash
# Interactive (recommended for first-time)
npm create cloudflare@latest my-app

# Worker (API/WebSocket/Cron)
npm create cloudflare@latest my-api -- --type=hello-world --lang=ts

# Pages (static/SSG)
npm create cloudflare@latest my-site -- --framework=astro --platform=pages
```

## Platform Decision Tree

```
What are you building?

├─ API / WebSocket / Cron / Email handler
│   └─ Workers (default) - no --platform flag needed
│       npm create cloudflare@latest my-api -- --type=hello-world

├─ Static site / SSG / Documentation
│   └─ Pages - requires --platform=pages
│       npm create cloudflare@latest my-site -- --framework=astro --platform=pages

├─ Full-stack app (Next.js/Remix/SvelteKit)
│   └─ Follow the current framework guide below

└─ Clone a deployed Worker locally
    └─ npm create cloudflare@latest my-local-worker -- --type=pre-existing --existing-script=my-worker
```

**Critical:** Pages projects require `--platform=pages` flag. Without it, C3 defaults to Workers.

## Framework Setup

Fetch the [Workers framework guide](https://developers.cloudflare.com/workers/framework-guides/index.md) for the chosen framework before scaffolding or adapting an existing app. For Next.js, follow [Next.js on Workers](https://developers.cloudflare.com/workers/framework-guides/web-apps/nextjs/index.md); use the [Pages static export guide](https://developers.cloudflare.com/pages/framework-guides/nextjs/deploy-a-static-nextjs-site/index.md) only when targeting a Next.js static export on Pages.

## Interactive Flow

Prompts depend on the selected category, template, and supplied flags:

- **Project name** - Directory to create.
- **Category** - Template group, such as `hello-world`, `web-framework`, `demo`, or `remote-template`.
- **Template type** - Built-in template identifier, such as `hello-world` or `pre-existing`, not a category name.
- **Framework** - For framework starters, use `--framework=astro`, for example. This sets the category to `web-framework` without `--type`.
- **External template** - Use `--template=user/repo`, not `--type=remote-template`.
- **Platform** - `workers` (default) or `pages`, for framework templates that support both.
- **Language** - Template-dependent. Use `--lang=ts` for TypeScript or `--lang=js` for JavaScript.
- **Git and deployment** - Repository creation and deployment choices. Authentication and deployment require separate authority.

See [Core Flags](api.md#core-flags) for the current argument model and source.

## Installation Methods

```bash
# NPM
npm create cloudflare@latest

# Yarn
yarn create cloudflare

# PNPM
pnpm create cloudflare@latest
```

## In This Reference

| File | Purpose | Use When |
|------|---------|----------|
| **api.md** | Complete CLI flag reference | Scripting, CI/CD, advanced usage |
| **configuration.md** | Generated files, bindings, types | Understanding output, customization |
| **patterns.md** | Workflows, CI/CD, monorepos | Real-world integration |
| **gotchas.md** | Troubleshooting failures | Deployment blocked, errors |

## Reading Order

| Task | Read |
|------|------|
| Create first project | README only |
| Set up CI/CD | README → api → patterns |
| Debug failed deploy | gotchas |
| Understand generated files | configuration |
| Full CLI reference | api |
| Create custom template | patterns → configuration |
| Convert existing project | README → patterns |

## Post-Creation

```bash
cd my-app

# Local dev with hot reload
npm run dev

# Generate TypeScript types for bindings
npm run cf-typegen

# Deploy to Cloudflare
npm run deploy
```

## See Also

- [Workers documentation](https://developers.cloudflare.com/workers/) - Workers runtime, bindings, APIs
- [Workers AI](../workers-ai/README.md) - AI/ML models
- [Pages](../pages/README.md) - Pages-specific features
- [Wrangler documentation](https://developers.cloudflare.com/workers/wrangler/) - Wrangler CLI beyond initial setup
- [D1](../d1/README.md) - SQLite database
- [R2](../r2/README.md) - Object storage
