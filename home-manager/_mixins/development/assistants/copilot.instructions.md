---
applyTo: "**"
description: "Remind the dummy about our environment 🎗️"
---

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

- Do not use bash syntax, heredocs, or subshells on the command line-fish is the only interactive shell available
- Never suggest or generate bash-specific patterns on the command line

## File Operations

**Always use IDE file creation/editing tools** for all file operations, regardless of target location.

- This applies to multi-line content, configuration files, scripts, and files outside the current workspace.

## Tool Decision Framework

Use **#mcp-google-cse/google_search** or **#context7/** when:

- Current APIs, versions, or implementations
- Syntax, parameters, or best practices uncertainty
- Time or version-sensitive technical information

Use **#nixos/** for:

- NixOS options, Home Manager, nix-darwin, Nixpkgs searches, Nix builtins
- Always verify option paths and package names before providing examples

Use **training knowledge** when:

- Conceptual explanations
- Well-established patterns

## Response Standards

- British English spelling
- Syntax-highlighted code blocks with file paths
- Clear rationale for recommendations
