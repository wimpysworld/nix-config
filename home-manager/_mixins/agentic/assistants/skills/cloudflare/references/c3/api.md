# C3 CLI Reference

## Invocation

```bash
npm create cloudflare@latest [name] [-- flags]  # NPM requires --
yarn create cloudflare [name] [flags]
pnpm create cloudflare@latest [name] [-- flags]
```

## Core Flags

| Flag | Values | Description |
|------|--------|-------------|
| `--type` | `hello-world`, `web-app`, `demo`, `pre-existing`, `remote-template` | Application type |
| `--platform` | `workers` (default), `pages` | Target platform (only for framework templates that support both Pages and Workers) |
| `--framework` | Examples: `next`, `remix`, `astro`, `react-router`, `solid`, `svelte`, `qwik`, `vue`, `angular`, `hono` | Web framework (requires `--type=web-app`) |
| `--lang` | `ts`, `js`, `python` | Language (for `--type=hello-world`) |
| `--ts` / `--no-ts` | - | TypeScript for web apps |

## Deployment Flags

| Flag | Description |
|------|-------------|
| `--deploy` / `--no-deploy` | Deploy immediately (prompts interactive, skips in CI) |
| `--git` / `--no-git` | Initialize git (default: yes) |
| `--open` | Open browser after deploy |

## Advanced Flags

| Flag | Description |
|------|-------------|
| `--template=user/repo` | GitHub template or local path |
| `--existing-script=my-worker` | Name of a deployed Worker to clone locally (sets `--type=pre-existing`, ignores `--deploy`) |
| `--category=<category>` | Template category: `hello-world`, `web-framework`, `demo`, or `remote-template`. With `--platform=pages`, only `web-framework` and `remote-template` are available. With `--experimental`, only `web-framework` is available. |
| `--experimental` | Enable experimental features |
| `--wrangler-defaults` | Skip wrangler prompts |

## Environment Variables

```bash
CLOUDFLARE_API_TOKEN=xxx    # For deployment
CLOUDFLARE_ACCOUNT_ID=xxx   # Account ID
CREATE_CLOUDFLARE_TELEMETRY_DISABLED=1 # Disable C3 telemetry
```

## Exit Codes

`0` success, `1` user abort, `2` error

## Examples

For framework apps, follow [Framework Setup](README.md#framework-setup).

```bash
# TypeScript Worker
npm create cloudflare@latest my-api -- --type=hello-world --lang=ts --no-deploy

# Astro blog
npm create cloudflare@latest my-blog -- --type=web-app --framework=astro --ts --deploy

# CI: non-interactive
npm create cloudflare@latest my-api -- --type=hello-world --lang=ts --no-git --no-deploy

# GitHub template
npm create cloudflare@latest -- --template=cloudflare/templates/worker-openapi

# Clone a deployed Worker into a local project
npm create cloudflare@latest my-local-worker -- --type=pre-existing --existing-script=my-worker
```
