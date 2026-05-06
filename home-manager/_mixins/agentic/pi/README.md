# Pi Agent module

Installs [Pi Agent](https://github.com/badlogic/pi-mono), the `pi` coding-agent CLI, for developer-tagged Home Manager users.

The package comes from `inputs.llm-agents.packages.${system}.pi`, matching the other coding-agent packages sourced from `numtide/llm-agents.nix`.

## Behaviour

- Adds `pi` to `home.packages`
- Gates installation with `noughtyLib.userHasTag "developer"`
- Adds a `pi-npm` wrapper backed by Nixpkgs `nodejs`, with npm's global prefix redirected to `~/.pi/agent/npm-global`
- Owns Pi config files through Home Manager `home.file`:
  - `~/.pi/agent/settings.json`
  - `~/.pi/agent/mcp.json`
- Does not enable services
- Does not add secrets or token material
- Does not run `pi install` during activation

The `llm-agents` package wrapper disables Pi's version check and telemetry at runtime.

## MCP

Pi MCP support is provided by [pi-mcp-adapter](https://github.com/nicobailon/pi-mcp-adapter), installed through Pi's pinned package setting:

```json
{
  "packages": ["npm:pi-mcp-adapter@2.5.4"]
}
```

Pi installs the package into the user-owned npm prefix on first startup if it is missing. The versioned package spec is skipped by `pi update`, so updates stay explicit.

Home Manager owns `~/.pi/agent/settings.json` completely. Project-specific or mutable package settings should live outside this file.

The adapter reads the shared MCP config at `~/.config/mcp/mcp.json` automatically. That file is still rendered by `../mcp` from `mcp/servers.nix`, so Pi uses the same canonical server definitions as Claude Code and other generic MCP clients.

`~/.pi/agent/mcp.json` is Pi-specific and only carries adapter settings:

- `directTools = false`
- `disableProxyTool = false`
- `autoAuth = false`
- `sampling = false`
- `samplingAutoApprove = false`

That keeps the default surface to the adapter's single `mcp` proxy tool and prevents MCP servers from sampling through Pi. Home Manager owns the user-level `~/.pi/agent/mcp.json`; project-level `.pi/mcp.json` files can override these settings deliberately.

Upstream limitation: Pi package settings support npm, git, and local path package sources. The adapter's npm package needs runtime dependencies, so this module declares the pinned npm package source and leaves the first install to Pi's package manager rather than copying an incomplete Nix store path into Pi's package list.
