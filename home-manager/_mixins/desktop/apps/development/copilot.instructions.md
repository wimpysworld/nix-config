---
applyTo: "**"
---
## Environment
- OS: NixOS | Shell: fish
- Tools: `gh`, `git`, `curl`, `jq`, `fd`, `rg`

## Shell Tool Preferences
- Use `fd` instead of `find`
- Use `rg` instead of `grep`

## File Operations
**Always use IDE file creation/editing tools** for all file operations, regardless of target location. This applies to multi-line content, configuration files, scripts, and files outside the current workspace.

## Tool Decision Framework
Use **#mcp-google-cse/google_search** or **#context7/** when:
- Current APIs, versions, or implementations
- Syntax, parameters, or best practices uncertainty
- Time-sensitive technical information

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
