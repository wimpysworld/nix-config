---
name: agentic-repo-capability
description: Use when adding or updating repository-local agent capabilities, including MCP servers, agent skills, or slash commands, or when a user asks to equip a repository with agent tooling across Claude Code, Codex, OpenCode, or Pi.
---

# Agentic Repository Capability

Add an MCP server, skill, or command to a repository through its existing agent tooling and development environment.

## Decide

Resolve the capability type before editing:

- **MCP server:** exposes tools, resources, or prompts through a local process or remote endpoint.
- **Skill:** supplies reusable guidance that clients load by name or description.
- **Command:** gives users a named, explicit invocation with optional arguments.

Use the type named by the user. If the request describes one type unambiguously, state the choice and continue. If two types fit and would produce different results, ask one focused question. Combine types only when the requested outcome needs the combination. A command with reusable doctrine needs a skill plus a thin command shim.

## Shared workflow

1. Find the repository root and read its instruction files before exploring. Honour the nearest scoped instructions for every file changed.
2. Inspect existing agent tooling, development-environment files, generated artefacts, and validation commands. Run the repository's command listing before inventing commands. Check Git status and preserve unrelated work.
3. Identify the supported clients, required client extensions, and the source of truth for each artefact. Treat a client as supported when the repository documents it, checks in its project config, or generates its files. Confirm required extensions are installed before using extension-owned project forms. Edit generator inputs instead of generated output.
4. Inspect nearby examples for naming, layout, headers, configuration style, and registration. Reuse the repository's composition system. Add a registration edit only when discovery is not automatic.
5. Add required executables through the repository's native development environment, such as a Nix dev shell, devcontainer, or package manifest. Use its normal dependency and lock-file workflow. Do not depend on an undeclared global install.
6. Load the relevant type reference and implement the smallest complete change:
   - `references/mcp.md` for MCP servers.
   - `references/skill.md` for skills.
   - `references/command.md` for commands.
7. Preserve existing configuration. Parse and merge structured files rather than replacing them. Keep unrelated keys, comments where the format supports them, ordering conventions, and local overrides.
8. Keep secrets out of tracked files, command arguments, logs, and examples. Record environment-variable names or secret-provider references only where the client supports them. Never invent a credential value.
9. Validate in the repository's native environment. Confirm executable availability, file syntax, client discovery, generated output, and cross-client consistency. Run project formatters and required evaluation or checks, then run `git diff --check`.

## Cross-client rules

- Do not treat one client's schema, path, transport name, enable flag, environment field, or argument format as portable.
- Keep the capability name and intended behaviour consistent across clients while translating each native schema.
- Configure every supported client that has a native project form for the capability. Report a client as unsupported when it has no suitable project form; do not create an invented schema.
- Preserve disabled states and project trust policy unless the user requests a change.
- Prefer relative repository paths and environment-provided executables. Use absolute paths only when the repository already requires them.

## Completion

Report the capability type, files changed, dependency source, supported clients covered, and validation results. Name any client that could not be checked and why.

## Anti-patterns

- Copying the same configuration object between clients.
- Editing generated client files instead of their source.
- Adding a package to a workstation profile when the capability belongs in the repository environment.
- Repeating `write-skill` or `write-command` doctrine in this skill.
- Claiming discovery from syntax checks alone.
- Starting a long-running MCP server as a validation step without a bounded probe.
