# LSP configuration

Claude Code with LSP integration, MCP servers, permission policy, and a ccstatusline status bar.

## Why LSP matters for AI agents

Text-based pattern matching cannot reliably answer "what does this symbol resolve to?" LSP gives Claude Code answers from the language server itself: precise definitions, type signatures, all call sites, and the full call hierarchy. Edits land on the right target; renames do not silently miss callers; type errors surface before the next compile.

### How agents use LSP

The project's global agent instructions (`instructions/global.md`) direct agents to use LSP tools at specific points in the edit cycle:

- **Before editing** - `goToDefinition`, `goToImplementation`, `documentSymbol` to locate symbols and confirm scope
- **After editing** - `hover` to verify resulting types and signatures; `findReferences` to confirm no call sites are broken

Agents must invoke these tools explicitly. They are available but not automatic - the model decides when to call them.

### Contrast with OpenCode.ai

OpenCode takes a different approach: after the model writes a file, OpenCode queries the LSP server for diagnostics and injects any errors or warnings back into the model's context automatically. The model does not need to ask - the feedback loop is built into the tool execution pipeline. OpenCode also exposes an experimental opt-in `lsp` tool (enabled via `OPENCODE_EXPERIMENTAL_LSP_TOOL=true`) that gives the model on-demand access to navigation features like go-to-definition and find references.

Claude Code's design is the inverse: LSP navigation is model-invokable from the start, but diagnostic feedback after edits is not automatic - agents must call `hover` or similar tools to check their work. Neither approach is strictly superior; OpenCode's automatic diagnostic loop reduces the chance of undetected errors, while Claude Code's explicit invocation model gives agents full control over when and how they consult the language server.

## LSP integration

Claude Code [v2.0.74+ supports LSP](https://github.com/anthropics/claude-code/releases/tag/v2.0.74) via its plugin system. A plugin directory containing `.lsp.json` maps file extensions to language server binaries. This module collects server definitions from language modules via a module option, merges them, and writes the result to `~/.claude/plugins/nix-lsp/.lsp.json`.

### The `claude-code.lspServers` option

Defined in this module as `attrsOf (attrsOf anything)`, default `{}`. Language modules contribute fragments via `config.claude-code.lspServers`, which the module system merges automatically. The merged attribute set is serialised to `.lsp.json` with `builtins.toJSON`.

The file is only written when at least one fragment is present (`lspServers != {}`).

### Wrapper chain

```
claude binary (from claudePackage)
  └── claudePackageWithLsp   [this module, when lspServers != {}]
        --set ENABLE_LSP_TOOL 1
        --add-flags "--plugin-dir ~/.claude/plugins/nix-lsp"
          └── HM claude-code module wrapper
                --mcp-config ~/.config/claude/claude_desktop_config.json
```

The LSP wrapper is built as a `symlinkJoin` derivation wrapping `claudePackage`. The HM module then wraps `programs.claude-code.package` (which receives `claudePackageWithLsp`) for MCP. Both wrappers use `wrapProgram`; stacked invocations compose cleanly.

## Language servers

15 LSP fragments across 11 language modules. All `command` values are Nix store paths - no PATH dependency.

| Key | Module | `command` | `args` | Extensions |
|-----|--------|-----------|--------|------------|
| `go` | `go/` | `lib.getExe pkgs.gopls` | - | `.go` |
| `rust` | `rust/` | `lib.getExe pkgs.rust-analyzer` | - | `.rs` |
| `semgrep` | `semgrep/` | `${pkgs.semgrep}/bin/semgrep` | `lsp` | 57 extensions covering 30+ languages (see `semgrep/default.nix`) |
| `python` | `python/` | `${pkgs.basedpyright}/bin/basedpyright-langserver` | `--stdio` | `.py` `.pyi` `.pyw` |
| `typescript` | `javascript/` | `lib.getExe pkgs.typescript-language-server` | `--stdio` | `.ts` `.tsx` `.js` `.jsx` `.mjs` `.mts` `.cjs` `.cts` |
| `json` | `javascript/` | `${pkgs.vscode-langservers-extracted}/bin/vscode-json-language-server` | `--stdio` | `.json` `.jsonc` |
| `html` | `javascript/` | `${pkgs.vscode-langservers-extracted}/bin/vscode-html-language-server` | `--stdio` | `.html` |
| `css` | `javascript/` | `${pkgs.vscode-langservers-extracted}/bin/vscode-css-language-server` | `--stdio` | `.css` `.scss` `.less` |
| `svelte` | `svelte/` | `lib.getExe pkgs.svelte-language-server` | `--stdio` | `.svelte` |
| `lua` | `love/` | `lib.getExe pkgs.lua-language-server` | - | `.lua` |
| `nix` | `nix/` | `lib.getExe pkgs.nixd` | - | `.nix` |
| `yaml` | `yaml/` | `lib.getExe pkgs.yaml-language-server` | `--stdio` | `.yaml` `.yml` |
| `bash` | `shell/` | `lib.getExe pkgs.bash-language-server` | `start` | `.sh` `.bash` `.zsh` |
| `cpp` | `c/` | `${pkgs.clang-tools}/bin/clangd` | - | `.c` `.h` `.cpp` `.hpp` `.cc` `.cxx` |
| `dart` | `dart/` | `${pkgs.dart}/bin/dart` | `language-server` | `.dart` |

<details>
<summary>Example .lsp.json (Nix store paths removed; semgrep omitted for brevity)</summary>

```json
{
  "bash": {
    "args": ["start"],
    "command": "bash-language-server",
    "extensionToLanguage": { ".bash": "shellscript", ".sh": "shellscript", ".zsh": "shellscript" }
  },
  "cpp": {
    "command": "clangd",
    "extensionToLanguage": { ".c": "c", ".cc": "cpp", ".cpp": "cpp", ".cxx": "cpp", ".h": "c", ".hpp": "cpp" }
  },
  "css": {
    "args": ["--stdio"],
    "command": "vscode-css-language-server",
    "extensionToLanguage": { ".css": "css", ".less": "less", ".scss": "scss" }
  },
  "dart": {
    "args": ["language-server"],
    "command": "dart",
    "extensionToLanguage": { ".dart": "dart" }
  },
  "go": {
    "command": "gopls",
    "extensionToLanguage": { ".go": "go" }
  },
  "html": {
    "args": ["--stdio"],
    "command": "vscode-html-language-server",
    "extensionToLanguage": { ".html": "html" }
  },
  "json": {
    "args": ["--stdio"],
    "command": "vscode-json-language-server",
    "extensionToLanguage": { ".json": "json", ".jsonc": "jsonc" }
  },
  "lua": {
    "command": "lua-language-server",
    "extensionToLanguage": { ".lua": "lua" }
  },
  "nix": {
    "command": "nixd",
    "extensionToLanguage": { ".nix": "nix" }
  },
  "python": {
    "args": ["--stdio"],
    "command": "basedpyright-langserver",
    "extensionToLanguage": { ".py": "python", ".pyi": "python", ".pyw": "python" }
  },
  "rust": {
    "command": "rust-analyzer",
    "extensionToLanguage": { ".rs": "rust" }
  },
  "svelte": {
    "args": ["--stdio"],
    "command": "svelteserver",
    "extensionToLanguage": { ".svelte": "svelte" }
  },
  "typescript": {
    "args": ["--stdio"],
    "command": "typescript-language-server",
    "extensionToLanguage": { ".cjs": "javascript", ".cts": "typescript", ".js": "javascript", ".jsx": "javascriptreact", ".mjs": "javascript", ".mts": "typescript", ".ts": "typescript", ".tsx": "typescriptreact" }
  },
  "yaml": {
    "args": ["--stdio"],
    "command": "yaml-language-server",
    "extensionToLanguage": { ".yaml": "yaml", ".yml": "yaml" }
  }
}
```

</details>

### Conditional guards

One entry is conditionally included, inheriting the guard already on its parent module - no additional conditions required:

- **`lua`** - only on hosts `phasma` and `vader` (`love/` module is `lib.mkIf (noughtyLib.isHost ["phasma" "vader"])`)

All other servers, including `semgrep`, are unconditionally enabled - no guard.

On hosts where the parent module is disabled, its `claude-code.lspServers` fragment is never evaluated, so the key is absent from `.lsp.json`.

### Python note

`basedpyright-langserver` is the LSP server binary. `lib.getExe pkgs.basedpyright` resolves to the `basedpyright` CLI binary instead, so the fragment uses an explicit store path.

## Adding a new language server

In the language module that already owns the LSP binary:

```nix
config.claude-code.lspServers = {
  <key> = {
    command = lib.getExe pkgs.<lsp-package>;  # or explicit bin path
    args = [ "--stdio" ];                      # omit if not needed
    extensionToLanguage = {
      ".ext" = "languageid";
    };
  };
};
```

If the module is guarded with `lib.mkIf`, place the fragment inside that same guard. The module system merges all fragments from enabled modules; no changes to `claude-code/default.nix` are needed.

Verify the generated file after `home-manager switch`:

```bash
cat ~/.claude/plugins/nix-lsp/.lsp.json | jq 'keys'
```

## LSP capabilities

Once loaded, Claude Code exposes nine LSP operations as model-invokable tools: `goToDefinition`, `findReferences`, `hover`, `documentSymbol`, `workspaceSymbol`, `goToImplementation`, `prepareCallHierarchy`, `incomingCalls`, `outgoingCalls`. These activate only when Claude Code opens a file whose extension matches a registered server.

Confirm the plugin loaded in a session with `/plugins`.
