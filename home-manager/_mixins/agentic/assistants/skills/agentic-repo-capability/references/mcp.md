# MCP capability

Add a repository-local MCP server to every supported client's native project configuration.

## Contents

- [Define the contract](#define-the-contract)
- [Add the executable](#add-the-executable)
- [Configure each client](#configure-each-client)
- [Secrets](#secrets)
- [Validate](#validate)

## Define the contract

Resolve these fields before editing:

- Stable lowercase capability name.
- Local `stdio` process or remote endpoint.
- Executable and ordered arguments for a local process.
- URL, headers, and authentication method for a remote endpoint.
- Non-secret environment values and required secret variable names.
- Whether the server starts enabled.

Check the server's current documentation or CLI help for its transport and launch contract. Do not infer a launch command from the package name.

## Add the executable

For a local process, add the package to the repository's native development environment. Follow the existing package and lock-file policy. Verify the exact executable from that environment, for example with the repository's dev-shell runner and `command -v <executable>`.

Use a bare executable name when the development environment supplies it on `PATH`. Keep wrapper scripts only when the server needs stable setup that the client schemas cannot express.

## Configure each client

Merge into existing files. The examples below show equivalent local `stdio` intent, not interchangeable schemas.

### Claude Code

Project file: `.mcp.json`.

```json
{
  "mcpServers": {
    "example": {
      "type": "stdio",
      "command": "example-mcp",
      "args": ["--flag"],
      "env": {
        "NON_SECRET_SETTING": "value"
      }
    }
  }
}
```

Claude Code uses `mcpServers`, a string `command`, a separate `args` array, and `env`. Do not add an `enabled` field unless current Claude Code documentation supports it for the selected form.

### Codex

Project file: `.codex/config.toml`.

```toml
[mcp_servers.example]
command = "example-mcp"
args = ["--flag"]
enabled = true
env = { NON_SECRET_SETTING = "value" }
```

Codex uses `mcp_servers` TOML tables. Keep `command` separate from `args`. Use the current Codex remote-server fields for an HTTP endpoint; never place local and remote fields in one table.

### OpenCode

Project file: `opencode.json`.

```json
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "example": {
      "type": "local",
      "command": ["example-mcp", "--flag"],
      "enabled": true,
      "environment": {
        "NON_SECRET_SETTING": "value"
      }
    }
  }
}
```

OpenCode uses `mcp`, calls a local process `type: "local"`, places the executable and arguments in one `command` array, and uses `environment`. Use `type: "remote"` and the current remote fields for an endpoint.

### Pi

Pi core has no MCP support. Use the native Pi project override `.pi/mcp.json` only when `pi-mcp-adapter` is installed. Do not claim `.agents/mcp` support.

```json
{
  "mcpServers": {
    "example": {
      "type": "stdio",
      "command": "example-mcp",
      "args": ["--flag"],
      "env": {
        "NON_SECRET_SETTING": "value"
      },
      "enabled": true,
      "directTools": false
    }
  },
  "settings": {
    "directTools": false
  }
}
```

The adapter uses top-level `mcpServers` and accepts optional top-level `settings`. `.pi/mcp.json` is its native Pi-specific project path and overrides global MCP configuration. The adapter shallow-merges servers by name, so a project server replaces the global entry with the same name. Include the complete server definition in every project override, including its command or URL, arguments, environment, enable state, and Pi-specific fields. Do not write a partial entry that only sets `directTools`.

### Other clients

Inspect repository instructions and current client documentation. Configure a client only when it has a verified project form or generator.

## Secrets

- Keep tokens, API keys, passwords, and private URLs out of tracked configuration.
- Prefer inherited runtime environment variables or the repository's secret provider.
- Confirm that a client expands any `${VARIABLE}` form before checking it in. If it does not, omit the secret value and document the runtime requirement through the repository's established mechanism.
- Do not print the resolved environment while validating.

## Validate

1. Parse JSON and TOML with the repository's formatter, linter, or a standard parser already available in its environment.
2. Confirm the executable resolves inside the native development environment.
3. Run a bounded server help, version, or protocol probe that cannot remain resident.
4. Use each installed client's MCP list or diagnostic command to confirm project discovery. For Pi, confirm `pi-mcp-adapter` is installed and loads `.pi/mcp.json`. Account for trust prompts without changing trust policy.
5. Compare names, executable, ordered arguments, transport, enable state, and non-secret environment semantics across clients.
6. Run repository evaluation and checks required by its instructions.

Syntax, executable availability, and client discovery are separate checks. Do not claim one from another.
