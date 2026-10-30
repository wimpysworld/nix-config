# Cloudflare development tools

Home Manager supplies Wrangler and runtime credentials for Martin's developer workstations.
The gate matches `development/oval-tutu`: workstation, `developer` user tag, and username `martin`.
It does not require the `cg` work tag. Servers and other users do not receive Wrangler from this module.
The development hub imports this directory automatically.

Use a project's pinned Wrangler when available. Otherwise use `wrangler` from the managed Home Manager profile.
Only the managed wrapper loads credentials from SOPS files. A project-local Wrangler does not use this wrapper.
Check `wrangler --version` and `wrangler <command> --help` before using commands from newer documentation.
A project-local version can differ from the Nix package. Do not upgrade either automatically.

The shared [Cloudflare skills](../../agentic/assistants/cloudflare.md) provide product, Wrangler, Workers, and Durable Objects guidance.
The shared [MCP registry](../../agentic/mcp/README.md#cloudflare-api) configures authenticated account access separately from the public `cloudflare-docs` endpoint.

## Credentials

`secrets/cloudflare.yaml` contains the encrypted credentials. This module declares these SOPS secrets with mode `0400`:

| Key | Runtime use |
| --- | --- |
| `CLOUDFLARE_ACCOUNT_ID` | Managed Wrangler wrapper |
| `CLOUDFLARE_API_TOKEN` | Managed Wrangler wrapper and authenticated MCP proxy |
| `CLOUDFLARE_ACCESS_KEY_ID` | Reserved for R2, not configured into a client |
| `CLOUDFLARE_SECRET_ACCESS_KEY` | Reserved for R2, not configured into a client |
| `CLOUDFLARE_S3_API_ENDPOINT` | Reserved for R2, not configured into a client |

The wrapper reads only the account ID and API token at runtime, then executes the upstream Wrangler through an absolute path.
Non-empty environment values for `CLOUDFLARE_ACCOUNT_ID` and `CLOUDFLARE_API_TOKEN` override their managed files.
If a required value is unset and its file is unavailable or empty, the wrapper stops.
Standalone help and version flags bypass credential loading.

The module does not export Cloudflare secrets globally or put secret values in command arguments or the Nix store.
Wrangler and `cloudflare-api` share the API token. Revoking or replacing that token affects both clients.
R2 credentials are not injected into Wrangler or MCP.

## Boundaries

- Existing Oval-Tutu credential wiring remains unchanged and separate from these tools.
- Existing server tunnels and `rclone` configuration remain unchanged.
- This module adds neither the `cf` beta CLI nor `cloudflared`.
- Upstream skills recommend `cf` for some projects. If that tool is required, request separate approval rather than install it or convert the project.
- Token permissions do not grant authority for an operation. Deployments, remote resource changes, and remote tests require explicit authority.
- Local execution can still use remote bindings.

## Validation

Validate configuration and generated files without activation.
For credential-free CLI checks, start with an empty environment (`env -i`) and set `HOME` to a new temporary directory.
Invoke the managed wrapper by its absolute `/nix/store/.../bin/wrangler` path because `env -i` clears `PATH`.
Run from a clean temporary working directory, with no inherited Cloudflare or XDG environment variables.
Limit wrapper checks to standalone `--help` and `--version`. These flags do not read credentials.
Do not read, source, or use existing credentials during these checks.
A temporary `HOME` alone does not prevent credential access through inherited environment variables or project files.
Authenticated checks remain deferred until the user activates the configuration and authorises those checks.
