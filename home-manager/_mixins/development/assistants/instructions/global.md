## Environment

- OS: NixOS
- Shell: `fish` (interactive), `bash` (scripts)
- Tools: `gh`, `git`, `curl`, `jq`, `fd`, `rg`

## Shell

- Terminal/interactive commands: use `fish` syntax only
- Shell scripts (\*.sh files): use `bash` exclusively

## Shell Tool Preferences

- Use `curl` for HTTP requests
- Use `fd` instead of `find`
- Use `gh` for GitHub operations
- Use `rg` instead of `grep`

## Constraints

- Do not use bash syntax, heredocs, or subshells on the command line - fish is the only interactive shell available
- Never suggest or generate bash-specific patterns on the command line

## File Operations

**Always use IDE file creation/editing tools** for all file operations, regardless of target location.

- This applies to multi-line content, configuration files, scripts, and files outside the current workspace.

## Tool Usage

At the start of every task, enumerate what tools are available to you. Use tools early and often - reach for them before relying on training data. A tool that fetches current information or searches live sources will outperform recalled knowledge for anything version-sensitive, API-specific, or environment-dependent.

- **Web search tools** (Exa, Context7): current APIs, versions, syntax, best practices
- **Nix-specific tools** (nixos MCP): NixOS options, Home Manager, nix-darwin, Nixpkgs, Nix builtins - always verify option paths and package names before providing examples
- **Training knowledge**: conceptual explanations and well-established patterns only

## Response Standards

- British English spelling
- Syntax-highlighted code blocks with file paths
- Clear rationale for recommendations
- Use hyphens or commas, never emdashes
