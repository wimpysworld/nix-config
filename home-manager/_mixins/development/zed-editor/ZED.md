Zed Editor vs VSCode Gap Analysis
Executive Summary
📌 KEY: Zed can serve as a daily driver today, but with notable workflow adjustments required. The configuration is already well-structured with good LSP and formatter coverage across all major languages. However, several critical gaps exist in code quality tools and collaboration features that may impact your workflow.
Blocking issues for full replacement:
- No invisible character detection (gremlins equivalent)
- No Live Share equivalent for real-time collaboration
- Limited extension ecosystem for niche file types (Debian control files)
Confidence: High - based on comprehensive review of 26 configuration files
---
Gap Analysis Table
Core Editor Extensions
| Feature/Extension | VSCode | Zed | Priority | Notes/Equivalent |
|-------------------|--------|-----|----------|------------------|
| Invisible character detection | gremlins | ❌ None | High | No Zed equivalent - `show_whitespaces` only displays U+0020 (space) and U+0009 (tab), NOT NBSP or zero-width characters |
| TODO tree/tracking | todo-tree | ✅ comment | ✅ Parity | Provides TODO/FIXME/XXX tracking and navigation |
| Partial diff/compare | partial-diff | ❌ None | Low | User does not use this feature; Zed's Git diff tooling is superior. Remaining ad-hoc comparison needs covered by split panes or terminal tools |
| Code screenshots | polacode-2019 | ❌ None | Low | Use external tools like Carbon |
| EditorConfig | editorconfig | ✅ editorconfig | ✅ Parity | Both supported |
| Rainbow CSV | rainbow-csv | ✅ rainbow-csv | ✅ Parity | Both supported |
| VHS tape recorder | vhs | ✅ vhs | ✅ Parity | Both supported |
| XML | xml | ✅ xml | ✅ Parity | Both supported |
| Dockerfile syntax | better-dockerfile-syntax | ✅ dockerfile | ✅ Parity | Both supported |
| Dependency management | dependi | ✅ dependi | ✅ Parity | New extension providing version checking for Go (go.mod) and Rust (Cargo.toml) with inlay hints and security warnings |
File Type Support
| File Type | VSCode Extension | Zed Extension | Priority | Notes |
|-----------|------------------|---------------|----------|-------|
| Systemd units | systemd-unit-file | ✅ ini | ✅ Parity | The ini extension provides systemd unit file support with syntax highlighting and basic language features |
| Debian control | debian-control-vscode | ❌ None | Low | Niche, no equivalent |
| Linux desktop files | linux-desktop-file | ✅ desktop | ✅ Parity | |
| CSV syntax | better-csv-syntax | ✅ rainbow-csv | ✅ Parity | |
| INI files | (built-in) | ✅ ini | ✅ Parity | |
| Makefile | (built-in) | ✅ make | ✅ Parity | |
| JSON5 | (built-in) | ✅ json5 | ✅ Parity | |
| JSONL | (built-in) | ✅ jsonl | ✅ Parity | |
Collaboration & Remote Development
| Feature | VSCode | Zed | Priority | Notes |
|---------|--------|-----|----------|-------|
| Live Share | ms-vsliveshare.vsliveshare | ❌ Channels (different model) | Critical | Zed has "channels" but not drop-in replacement |
| Remote SSH | vscode-remote-extensionpack | ✅ installRemoteServer | ✅ Parity | Zed has built-in remote dev |
| VSCode Server | services.vscode-server | n/a | N/A | NixOS-specific helper for running VSCode remotely; not applicable to Zed which has built-in remote development |
AI & Assistant Integration
| Feature | VSCode | Zed | Priority | Notes |
|---------|--------|-----|----------|-------|
| Copilot Chat | github.copilot-chat | ✅ Built-in Agent | ✅ Superior | Zed's agent panel is more integrated |
| Claude Code | claude-code extension | ✅ External via keymap | ✅ Parity | OpenCode integration configured |
| MCP Servers | Via mcp.json | ✅ context_servers | ✅ Parity | Both configured identically |
---
Language-by-Language Breakdown
C/C++
| Aspect | VSCode | Zed | Status |
|--------|--------|-----|--------|
| LSP | cpptools-extension-pack | clangd (path_lookup) | ✅ Parity |
| CMake | cmake-tools, twxs.cmake | neocmake extension | ✅ Parity |
| Debugger | vscode-lldb | ✅ CodeLLDB, GDB | ✅ Parity |
| Formatting | clang-format | clang-format | ✅ Parity |
Dart/Flutter
| Aspect | VSCode | Zed | Status |
|--------|--------|-----|--------|
| LSP | dart-code, flutter | ✅ dart extension | ✅ Parity |
| Formatting | Built-in dart format | ✅ dart format | ✅ Parity |
| Settings | Extensive editor config | ✅ Configured | ✅ Parity |
Go
| Aspect | VSCode | Zed | Status |
|--------|--------|-----|--------|
| LSP | golang.go | ✅ gopls configured | ✅ Parity |
| Formatter | gofmt | ✅ gofmt | ✅ Parity |
| Linter | (built-in) | ✅ golangci-lint | ✅ Superior |
JavaScript/TypeScript
| Aspect | VSCode | Zed | Status |
|--------|--------|-----|--------|
| LSP | Built-in | Built-in | ✅ Parity |
| Formatter | prettier | ✅ prettier | ✅ Parity |
| All languages | CSS, HTML, JSON, JSONC, TSX | ✅ All configured | ✅ Parity |
Just
| Aspect | VSCode | Zed | Status |
|--------|--------|-----|--------|
| Syntax | vscode-just-syntax | ✅ just | ✅ Parity |
| LSP | (none) | ✅ just-ls with just-lsp | ✅ Superior |
| Formatter | just-formatter | ✅ just-formatter | ✅ Parity |
Lua/LÖVE
| Aspect | VSCode | Zed | Status |
|--------|--------|-----|--------|
| LSP | sumneko.lua | ✅ lua extension | ✅ Parity |
| GLSL | vscode-glsllint, shader | ✅ glsl | ✅ Parity |
| Debugger | second-local-lua-debugger-vscode | ✅ EmmyLua configured | ✅ Parity |
| Formatter | stylua | ✅ stylua | ✅ Parity |
| LÖVE-specific | pixelbyte-love2d | ❌ None | Low gap |
⚠️ CAVEAT: EmmyLua extension provides DAP debugging support
Markdown
| Aspect | VSCode | Zed | Status |
|--------|--------|-----|--------|
| Formatter | prettier | ✅ prettier | ✅ Parity |
| Emoji | emojisense, markdown-emoji | ✅ emoji-completions | ✅ Parity |
| Linter | rumdl | ✅ rumdl | ✅ Parity |
| Hugo | language-hugo-vscode, vscode-hugo | ❌ None | Low gap |
| Marp slides | marp-vscode | ❌ None | Low gap |
| All-in-one | markdown-all-in-one | ❌ None | Medium gap |
Nix
| Aspect | VSCode | Zed | Status |
|--------|--------|-----|--------|
| LSP | nixd | ✅ nixd | ✅ Parity |
| Formatter | nixfmt-rfc-style | ✅ nixfmt-rfc-style | ✅ Parity |
| Syntax | better-nix-syntax, nix-ide | ✅ nix | ✅ Parity |
| Diagnostics | ✅ | ✅ suppress = ["sema-extra-with"] | ✅ Parity |
Python
| Aspect | VSCode | Zed | Status |
|--------|--------|-----|--------|
| LSP | basedpyright | ✅ basedpyright | ✅ Parity |
| Debugger | ms-python.debugpy | ✅ debugpy (built-in) | ✅ Parity |
| RST support | simple-rst | ✅ rst | ✅ Parity |
| Formatter | (via ruff) | ✅ ruff | ✅ Parity |
Rust
| Aspect | VSCode | Zed | Status |
|--------|--------|-----|--------|
| LSP | rust-analyzer | ✅ Built-in | ✅ Parity |
| TOML | even-better-toml | ✅ toml, tombi, cargotom | ✅ Superior |
Shell (Bash/Fish)
| Aspect | VSCode | Zed | Status |
|--------|--------|-----|--------|
| LSP | bash-language-server | ✅ basher | ✅ Parity |
| Fish | vscode-fish | ✅ fish | ✅ Parity |
| Syntax | shell-syntax, better-shellscript-syntax | ✅ Built-in | ✅ Parity |
| Debugger | bash-debug | ❌ None | Low gap |
| Formatter | shfmt | ✅ format_on_save | ✅ Parity |
Svelte
| Aspect | VSCode | Zed | Status |
|--------|--------|-----|--------|
| LSP | svelte-vscode | ✅ svelte | ✅ Parity |
| Formatter | prettier | ✅ prettier | ✅ Parity |
YAML
| Aspect | VSCode | Zed | Status |
|--------|--------|-----|--------|
| LSP | vscode-yaml | ✅ yaml-language-server | ✅ Parity |
| Formatter | prettier | ✅ prettier | ✅ Parity |
| Key ordering | ✅ | ✅ keyOrdering = true | ✅ Parity |
Git Integration
| Aspect | VSCode | Zed | Status |
|--------|--------|-----|--------|
| GitHub Actions | vscode-github-actions, github-local-actions | ✅ github-actions | Partial |
| PR/Issues | vscode-pull-request-github | ❌ None | Medium gap |
| Git commit message | (built-in) | ✅ git-firefly | ✅ Parity |
---
Recommended Actions (Priority Order)
Critical (Would block daily use)
1. Invisible character detection - CANNOT BE FULLY RESOLVED
   - `show_whitespaces = "all"` only displays U+0020 (space) and U+0009 (tab)
   - Does NOT show: NBSP (U+00A0), zero-width spaces (U+200B-U+200D), or other unicode whitespace
   - No "gremlins" equivalent extension exists in Zed - this is a blocking gap
   - **Recommended workaround**: Add a pre-commit hook or just recipe to detect invisible characters
   - See "Invisible Character Detection Workarounds" section below for implementation
3. Collaboration assessment
   - Evaluate if Zed Channels meet your collaboration needs
   - If not, keep VSCode available for pair programming sessions
Medium Priority
5. Accept remaining gaps:
    - **Note**: The dependi extension for dependency version checking was recently released and is now available
Low Priority
7. Accept these gaps or use workarounds:
   - Code screenshots → Use Carbon or silicon CLI
   - Hugo/Marp → Edit in Zed, preview externally
   - Shell debugging → Use terminal-based debugging (bashdb) or external tools
---
Invisible Character Detection Workarounds
Since Zed cannot display zero-width characters or non-breaking spaces, use these workarounds:

**Option 1: Pre-commit Hook (Recommended)**
Add to `.pre-commit-config.yaml`:

```yaml
- repo: local
  hooks:
    - id: detect-invisible-chars
      name: Detect invisible unicode characters
      entry: bash -c 'grep -rP "[\x{00A0}\x{200B}-\x{200D}\x{FEFF}]" --include="*.nix" --include="*.py" --include="*.js" --include="*.ts" --include="*.rs" . && exit 1 || exit 0'
      language: system
      pass_filenames: false
      always_run: true
```

**Option 2: Just Recipe**
Add to `justfile`:

```justfile
# Scan for invisible unicode characters
detect-gremlins:
    @echo "Scanning for invisible characters..."
    @rg -P '[\x{00A0}\x{200B}-\x{200D}\x{FEFF}]' --type-add 'nix:*.nix' -tnix -tpy -tjs -trs . || echo "No invisible characters found ✓"
```

Run with: `just detect-gremlins`

**Characters this detects:**
- U+00A0: Non-breaking space (NBSP)
- U+200B: Zero-width space
- U+200C: Zero-width non-joiner
- U+200D: Zero-width joiner
- U+FEFF: Zero-width no-break space (BOM)

---
Debugging Capabilities
📌 KEY: Zed has comprehensive DAP (Debug Adapter Protocol) support as a core feature. Debug adapters are available for most major languages.

| Language | Debug Adapter | Configuration |
|----------|---------------|---------------|
| C/C++ | CodeLLDB (primary), GDB (secondary) | Built-in - configure via `.zed/debug.json` |
| Python | debugpy | Built-in - zero-config or `.zed/debug.json` |
| Lua | EmmyLua extension | Installed - DAP support ready |
| Rust | CodeLLDB (primary), GDB (secondary) | Built-in - zero-config or `.zed/debug.json` |
| Go | Delve | Built-in - zero-config or `.zed/debug.json` |
| JavaScript/TypeScript | Node.js debugger | Built-in - zero-config available |
| PHP | Built-in | Built-in - configure via `.zed/debug.json` |
| Java | Java extension | Install extension |
| Ruby | Ruby extension | Install extension |
| Swift | Swift extension | Install extension |
| Shell/Bash | ❌ None | No DAP adapter available |

Press F4 (`debugger: start`) for zero-configuration debugging, or define custom profiles in `.zed/debug.json`. Zed also reads `.vscode/launch.json` for VSCode compatibility.

---
Features Where Zed Excels
| Feature | Zed Advantage | Notes |
|---------|---------------|-------|
| Performance | Native, GPU-accelerated | Noticeably faster than VSCode |
| AI Integration | Built-in agent panel | More integrated than Copilot Chat extension |
| Just support | LSP + formatter out of box | VSCode requires manual setup |
| Rust tooling | Native, first-class | rust-analyzer deeply integrated |
| Remote development | Built-in, no extension needed | installRemoteServer = true |
| TOML support | Multiple extensions (cargotom, tombi) | Superior Cargo.toml integration |
| Go linting | golangci-lint extension | Better than VSCode's default |
| MCP context servers | Native support | Clean context_servers configuration |
| Direnv | Built-in load_direnv | No extension needed |
| Git branch display | In title bar | Clean, always visible |
| Debugging | Native DAP support | No extensions needed for most languages |
---
Summary Statistics
| Category | Parity | Zed Superior | Gap |
|----------|--------|--------------|-----|
| Languages | 39 | 4 | 6 |
| Core features | 9 | 1 | 3 |
| File types | 7 | 0 | 1 |
| Collaboration | 1 | 0 | 1 |
| Git Integration | 2 | 0 | 1 |
| **Total** | **58** | **5** | **12** |

Overall assessment: ~86% feature parity (63 of 74 features fully supported), with Zed excelling in performance and modern features but lacking in code quality tooling, shell debugging, and collaboration.
---
Potential Extension Projects
The following extensions would be interesting contributions to the Zed ecosystem and could address notable gaps identified above:
**Carbon - Code Screenshot Generator**
Create a Zed extension that generates beautiful code screenshots, inspired by [carbon.now.sh](https://carbon.now.sh) and the VSCode Polacode extension. This would allow generating shareable images of code snippets directly within the editor, with customisable themes, backgrounds, and padding.
**Gremlins - Invisible Character Detection**
Develop a Zed extension that highlights invisible unicode characters (non-breaking spaces, zero-width spaces, BOM markers) in the editor. This would address the critical gap where Zed's `show_whitespaces` cannot display characters like NBSP or zero-width characters, providing visual indicators similar to the VSCode Gremlins extension.

These are potential future contributions, not immediate priorities, but would significantly improve the Zed experience for developers working with code quality sensitive to invisible character issues or those sharing code snippets.
