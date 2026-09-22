# TUI case studies

Use these examples to explain concrete design choices, not as substitutes for the pattern references.
All reference paths are relative to the skill root.

## Contents

- [Select a case](#select-a-case)
- [lazygit](#lazygit)
- [k9s](#k9s)
- [btop](#btop)
- [fzf](#fzf)
- [helix](#helix)
- [yazi](#yazi)
- [atuin](#atuin)
- [htop](#htop)
- [bottom](#bottom)
- [Posting](#posting)
- [Harlequin](#harlequin)
- [ranger, lf, nnn, and broot](#ranger-lf-nnn-and-broot)
- [gitui](#gitui)
- [lazydocker](#lazydocker)
- [neovim](#neovim)
- [Toolong](#toolong)
- [Glow](#glow)
- [Terminal coding assistants](#terminal-coding-assistants)
- [starship](#starship)
- [yt-dlp and aria2](#yt-dlp-and-aria2)

## Select a case

| Design question | Examples |
| --- | --- |
| Dashboard layout | btop, bottom, htop |
| Resource drill-down | k9s, lazydocker |
| Fast search | fzf, atuin |
| Million-row or large-file display | Harlequin, Toolong |
| Help and discovery | htop F-keys, helix which-key, lazygit footer |
| High-rate chat output | Claude Code, Copilot CLI, Ink `<Static>` |
| Undo | lazygit action history |
| Mouse policy | btop, helix, lazygit |
| Picker startup | fzf below 100ms, starship below 50ms |
| Setup wizard | Clack-style tools, with library differences in `references/ecosystem-typescript.md` |
| Themes | btop, bottom, helix, Posting |

For general rules, use `references/visual-patterns.md` and `references/interaction-patterns.md`.
For a comparable task, explain which part of the app's design transfers.

## lazygit

Stack: Go, gocui from jesseduffield's fork, YAML `config.yml`.
The layout has Status, Files, Branches, Commits, and Stash on the left, a large detail/diff pane, and a command log.

| Design | Transferable use |
| --- | --- |
| Branches Local/Remotes/Tags tabs | Related views within one panel, cycled by `[`/`]` |
| `z` / `Ctrl+z` undo/redo | Reversible Git operations, including rebases |
| Subtle fetch pulse | Background activity without a large alert |
| Commands and aliases | User extension through YAML |
| Command log | Show the actual Git operations |
| Confirmation defaults to No | Prevent accidental destructive actions |

Use fixed numeric panel jumps, contextual letters, and current footer hints together.
See the lazygit pattern in `references/interaction-patterns.md`.

## k9s

Stack: Go, tview, YAML, Kubernetes client-go.
The layout combines cluster/context/namespace headers, a resource list, and footer hints.
Enter opens details. Esc returns through the stack.

| Design | Transferable use |
| --- | --- |
| Resource-specific actions | `s` shell, `l` logs, `d` describe |
| Shift-letter sorting | `shift-n` name, `shift-a` age, `shift-o` selected column |
| `/` fuzzy filtering | Narrow large lists without a separate screen |
| Debounced live updates | Show changing resource state without a redraw for every event |
| `plugins.yaml` | Custom operations |
| Location header | Preserve context during navigation |

Use `:pods`, `:svc`, completion, and aliases for resource navigation.
See the k9s pattern in `references/interaction-patterns.md`.

## btop

Stack: C++. bottom (`btm`) is a related Rust monitor.
The dashboard contains CPU, memory, network, and process areas.
Users can show, hide, rearrange, and configure areas through `btop.conf`, a TOML-like `key = value` file.

| Design | Transferable use |
| --- | --- |
| Truecolour gradients | Compact metric display with capability fallback |
| Shared `update_ms`, default 2000 | One refresh clock for cheap, uniform data sources |
| Independent focus/scroll/history | Each widget remains usable on its own |
| Clickable keys and boxes, wheel scroll | Mouse addition without mandatory mouse use |
| `.theme` files | Simple `theme[key]="#hex"` mappings |
| `h`, `?`, or F1 help | Help grouped by widget |

Do not infer drag-resize from configurability. The upstream detailed guidance explicitly says that btop has no drag-resize.
Give a widget its own refresh rate only when its data source is slow or expensive.
cjbassi/gotop was archived in 2020. The maintained fork named by upstream is xxxserxxx/gotop.

## fzf

Stack: Go with direct terminal control, without a UI framework.
fzf is full-screen by default. `--height` places a bounded picker below the cursor.

Use `--preview` for file contents or command output without leaving the selection.
The pipeline example is `git branch | fzf | xargs git checkout`.
The UI uses `/dev/tty`, while stdout contains the selection.
A larger TUI can invoke fzf for a bounded selection task.

Target startup and filter updates below 100ms.
The difference between 50ms and 200ms matters when users invoke a picker repeatedly.
Show match counts, smart-case, ranking, and matched text.
See the fzf pattern in `references/interaction-patterns.md` and buffer choices in `references/visual-patterns.md`.

## helix

Stack: Rust with a custom renderer.
Helix uses selection-first modal editing and multiple cursors.
Its layout includes the editor, splits, status/diagnostics, pickers, and an optional file explorer.
The explorer merged in January 2025 and supports navigation, not file management.
Earlier versions relied on pickers instead of a tree.

| Design | Transferable use |
| --- | --- |
| Tree-sitter text objects | Syntax-aware selection |
| Space which-key | Visible `f` files, `b` buffers, `s` symbols, and other follow-ups |
| `:` completion | Find less-common commands |
| Built-in LSP | Language support without separate plugins |
| Single binary and defaults | Reduce setup before useful work |

Pair mode labels with distinct cursors and leader-key hints.
See selection-first interaction in `references/interaction-patterns.md`.

## yazi

Stack: Rust, Ratatui, Crossterm, Tokio.
The file manager uses parent/current/preview Miller columns with default ratio `[1, 4, 3]`.

| Design | Transferable use |
| --- | --- |
| Asynchronous directory and file I/O | Preserve input response on network mounts, encrypted drives, and failed USB devices |
| Sixel/kitty/iTerm2 preview | Detect supported image protocols |
| Vim keys and `:` commands | Fast navigation with less-common actions available |
| Lua plugins | Extension without recompilation |
| Tasks pane | Visible copy/transcode work |

Keep all filesystem operations off the UI thread, not only operations that are normally slow.

## atuin

Stack: Rust, Ratatui, optional self-hosted sync server.
Atuin replaces Ctrl+R with an overlay history picker.

| Design | Transferable use |
| --- | --- |
| Existing Ctrl+R binding | Improve a familiar workflow without a new entry point |
| Result metadata | Show time, exit code, directory, and hostname |
| Optional encrypted sync | Share history across machines |
| Shared CLI/TUI core | `atuin search` for scripts, interactive selection for exploration |

Keep useful metadata visible without repeating unnecessary labels.
Atuin Desktop launched in 2025, while the CLI/TUI remains a separate maintained product.

## htop

Stack: C and ncurses.
The dense layout has CPU/memory/swap meters, a sortable process list, and the F-key footer.

| Control | Use |
| --- | --- |
| F1-F10 strip | Always-visible available actions |
| F5 | Collapsible process tree |
| F4 / F3 | Filter/search |
| Column click | Sort |
| F7 / F8 | Nice/renice |

Use persistent hints, sortable tables, and optional mouse access with complete keyboard operation.
If ten actions fit visibly, do not hide them all behind help.

## bottom

Stack: Rust, Ratatui, Crossterm, executable `btm`.
The configurable dashboard uses TOML rows and column ratios.

Study the `t` process-tree toggle, battery widget, process search/filter, and focused keyboard access per widget.
Let dashboard users rearrange widgets instead of fixing one layout for every task.

## Posting

Stack: Python, Textual, httpx.
The HTTP client has a collection tree, request editor, and response pane below or beside the editor.

| Design | Transferable use |
| --- | --- |
| Actionable empty state | “No requests. Press `n` to create one.” |
| Runtime themes | Catppuccin, Gruvbox, Tokyo Night, Solarized, custom |
| Vim keys and jump mode | Reach widgets in two keys instead of long Tab sequences |
| Import/export | curl, Postman collections, OpenAPI |
| `{{token}}` variables | Environment-aware substitution |
| Complete keyboard access | Mouse remains optional |

Jump mode labels focusable widgets with letters.
Use it when forms contain many targets.

## Harlequin

Stack: Python, Textual, textual-fastdatatable.
The SQL IDE has a schema/catalogue pane, SQL editor, and results table.

| Design | Transferable use |
| --- | --- |
| Adapters | DuckDB, SQLite, Postgres, MySQL/MariaDB, ODBC, and community databases |
| Tree-sitter SQL | Syntax-aware editor display |
| Virtualised results | Support million-row queries |
| Run-on-keystroke option | Rapid exploration |
| Snippets and history | Reuse common queries |
| Modal/modeless choices | Match user editing preferences |

Separate database adapters from the interface.
Use actual virtualisation, not a fixed first-1000-row substitute.

## ranger, lf, nnn, and broot

These file browsers provide related parent/current/preview or tree navigation patterns.
Common controls include `hjkl`, `m{a-z}` bookmarks, and `'{a-z}` jumps.
Preview uses terminal graphics or ASCII.
`ranger --choosefile=/tmp/path` demonstrates selection for shell scripts.

| Tool | Implementation and distinction |
| --- | --- |
| ranger | Python, mature, extensive capabilities, slower startup |
| lf | Go, small and fast |
| nnn | C, minimal, single-digit-millisecond startup |
| broot | Rust, tree view with fuzzy filtering |

Treat startup cost as part of browsing behaviour, not only as a packaging concern.

## gitui

Stack: Rust, Ratatui, git2.
The layout uses persistent Git panels, similar to lazygit.
Study asynchronous Git operations, highlighted diffs, non-blocking fetch, and in-app push/pull progress.
Run Git work on background threads and return progress events.
Use Tree-sitter or syntect for readable diff highlighting.
Large repositories make UI-thread Git calls particularly costly.

## lazydocker

Stack: Go and jesseduffield's gocui fork.
The sidebar contains Project, Containers, Images, Volumes, and Networks.
The main pane has Logs, Stats, Env, Config, and Top tabs.

Study `[`/`]` tab cycling, live logs with optional auto-scroll, CPU/memory/network graphs, and YAML custom commands.
For related resource managers, combine a stable sidebar, detail tabs, contextual actions, and current footer hints.

## neovim

Stack: C core with Lua configuration and plugins.
Study extension boundaries and reusable interaction patterns.

| Plugin | Pattern |
| --- | --- |
| telescope.nvim | Fuzzy picker for files, buffers, LSP symbols, and Git refs |
| which-key.nvim | Leader follow-up discovery |
| lualine.nvim | Configurable status components for mode, branch, diagnostics, file, and position |
| nvim-tree.lua | File sidebar with vim navigation |
| lazy.nvim | Deferred plugin loading to reduce startup |

Use modes, leaders, command mode, registers, marks, buffers, and splits only where they fit the task.

## Toolong

Stack: Python and Textual.
The main log pane has an optional filter sidebar.
Study virtualisation without whole-file loading, live follow, fast regex filters, timestamp merge, and JSON/syslog/NGINX highlighting.
Test real large-file behaviour, not only a 10MB fixture.
The upstream scale example is 50GB of rotated logs.

## Glow

Stack: Go, Bubble Tea, Glamour.
The main pane displays Markdown, with an optional file picker.
Study light/dark/custom JSON themes and local or remote input, including GitHub URLs.
`glow README.md` supplies CLI output, while `glow` opens the TUI picker.
Glow 2.0 removed cloud stash rather than retaining an inactive backend.
Keep renderer styles reusable between the CLI and TUI.

## Terminal coding assistants

Claude Code, GitHub Copilot CLI, and Gemini CLI use TypeScript, Ink, React, and Yoga in the upstream case studies.
Their chat layout puts input below a growing output history.

Study streamed text, restrained work/error status, inline diffs, slash commands, and shell/file integration.
Use `<Static>` or an equivalent only for completed append-only history.
Keep active output and interactive input in the live region.
This prevents completed turns from re-rendering at high token rates.

## starship

Stack: Rust with direct ANSI output, without a UI framework.
The prompt runs repeatedly, so startup below 50ms is a design requirement.

| Control | Purpose |
| --- | --- |
| `scan_timeout`, 30ms | Bound scans |
| `command_timeout`, 500ms | Bound commands |
| Per-module timeout handling | Omit slow modules with a warning instead of delaying the prompt |
| TOML modules | `[character]`, `[directory]`, `[git_branch]` and other semantic sections |
| Cross-shell binary | bash, zsh, fish, pwsh, ion, nu |

Profile frequent-entry tools and prevent startup regressions.
A 100ms delay matters even when users do not name the cause.

## yt-dlp and aria2

These downloaders demonstrate useful progress without a full-screen interface.
Study parallel progress, TTY bars, simpler non-TTY percentages, and final success/failure counts with total size.
For non-interactive tools, preserve useful progress and completion output without terminal-only controls.
