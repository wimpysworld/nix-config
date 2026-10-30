# Cloudflare development tools

Home Manager supplies `pkgs.wrangler` for Martin's developer workstations.
The gate matches `development/oval-tutu`: workstation, `developer` user tag, and username `martin`.
It does not require the `cg` work tag. Servers and other users do not receive Wrangler from this module.
The development hub imports this directory automatically.

Use a project's pinned Wrangler when available. Otherwise use `wrangler` from the managed Home Manager profile.
Check `wrangler --version` and `wrangler <command> --help` before using commands from newer documentation.
A project-local version can differ from the Nix package. Do not upgrade either automatically.

The shared [Cloudflare skills](../../agentic/assistants/cloudflare.md) provide product, Wrangler, Workers, and Durable Objects guidance.
The shared MCP registry adds `cloudflare-docs` at `https://docs.mcp.cloudflare.com/mcp` under existing client gates.
This documentation-only endpoint needs no account credentials.
The authenticated API endpoint `https://mcp.cloudflare.com/mcp` is not configured.

## Boundaries

- Token, API key, and login setup remain deferred. This module defines no credentials or environment exports.
- Existing Oval-Tutu credential wiring remains unchanged and separate from these tools.
- Existing server tunnels and `rclone` configuration remain unchanged.
- This module adds neither the `cf` beta CLI nor `cloudflared`.
- Upstream skills recommend `cf` for some projects. If that tool is required, request separate approval rather than install it or convert the project.
- Deployments, remote resource changes, and remote tests require explicit authority. Local execution can still use remote bindings.

Validate configuration and generated files without activation.
For CLI checks, start with an empty environment (`env -i`) and set `HOME` to a new temporary directory.
Run from a clean temporary working directory, with no inherited Cloudflare or XDG environment variables.
Limit checks to `--help` and `--version`. Do not read, source, or use existing credentials.
A temporary `HOME` alone does not prevent credential access through inherited environment variables or project files.
