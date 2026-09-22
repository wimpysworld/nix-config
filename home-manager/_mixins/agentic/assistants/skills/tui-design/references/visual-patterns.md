# Visual patterns

Choose terminal layouts from the task, content, and minimum usable size.
All reference paths are relative to the skill root.

## Contents

- [Seven layouts](#seven-layouts)
- [Screen buffers](#screen-buffers)
- [Borders](#borders)
- [Colour](#colour)
- [Typography](#typography)
- [Density](#density)
- [The clutter audit](#the-clutter-audit)
- [Responsive design](#responsive-design)
- [Visual hierarchy](#visual-hierarchy)
- [Tables and lists](#tables-and-lists)
- [Headers, status, and footers](#headers-status-and-footers)
- [Progress and states](#progress-and-states)
- [Themes](#themes)
- [Common pitfalls](#common-pitfalls)

## Seven layouts

### Persistent multi-panel

Use fixed panels when users compare related views or monitor data at a glance.
Examples are lazygit's five left panels and right detail pane, btop's four areas, and htop's header/list/footer.
Avoid fixed panels when each view needs full attention or cannot fit at smaller sizes.

Indicate focus with a border colour and another visible signal.
Update footer hints for the current panel.
Make numeric jumps such as `1` to `5` work without a return to a menu.

### Miller columns

Use parent → current → preview for hierarchical data such as filesystems, JSON, or Kubernetes resources.
`h`/`l` or arrows move through the hierarchy.
Yazi defaults to `[1, 4, 3]`. Related tools include ranger, broot, nnn, and lf.

Make the current column widest.
Update previews on selection, with debounce for expensive work.
Below 80 columns, provide a single-pane fallback.
For non-hierarchical data, omit an unused parent column.

### Drill-down stack

Use a stack for many resource types and full-screen detail views.
Examples include k9s, lazydocker, and gh dash.
Avoid stacks deeper than about three levels.
For side-by-side comparison, prefer multiple panels.

Show the location, for example `cluster/namespace/pods/my-pod-7d9f`.
Make `Esc` return one level.
Save view state on push and restore it on pop.

### Widget dashboard

Use a configurable grid for monitoring.
Each widget needs its own data, focus, and scroll state.
Examples include bottom, btop, glances, and gtop.
Avoid configuration overhead for a deliberately fixed experience.

Define a TOML/YAML layout schema early.
Allow independent scrolling and expansion.
Check each app's format instead of assuming that all use TOML.
Do not assume mouse drag-resize. btop supports click focus and scroll, not drag-resize.

### IDE three-panel

Use sidebar → main content → detail/output for compose, execute, and inspect workflows.
Examples are Posting, Harlequin, and helix.
For browsing without composition, prefer simpler panels.
Provide a narrow fallback.

Allow sidebar collapse, often with `Ctrl+B`.
Cycle main tabs with `[`/`]` or `Ctrl+Tab` where supported.
Place resizable output below or beside the main pane.

### Overlay or popup

Use a short-lived picker for open → choose → output → exit and shell pipelines.
Examples are fzf, atuin's Ctrl+R replacement, zoxide+fzf, and gum.
Avoid cramped popups for long sessions or persistent state across invocations.
Target startup below 100ms.
Choose the buffer separately from the interaction pattern.

### Tabs within a panel

Use tabs for related views of one selected object.
Examples are lazygit Local/Remotes/Tags and lazydocker Logs/Stats/Env/Config/Top.
Use separate panels for unrelated content.
Beyond 5-6 tabs, consider nested tabs or another layout.

Distinguish the active tab with bold, underline, and accent colour.
Show direct keys such as `Logs [1]`, `Stats [2]`, `Env [3]`.
Cycle left to right with `[`/`]` or `Ctrl+Tab` where supported.

## Screen buffers

The alternate screen has no scrollback. On exit, the terminal restores its previous buffer.
Inline output appears below the shell prompt and can enter scrollback.

Prefer the alternate screen for long editor, file-manager, and dashboard sessions.
Prefer inline output for bounded prompts, confirmations, progress, and pickers that need shell context.
A large preview or deep picker workflow can justify full-screen output.
Choose from the working set and exit contract, not the product name.

### Framework mechanics

| Framework | API |
| --- | --- |
| Bubble Tea v2 | Inline by default. Set `v := tea.NewView(...)` and `v.AltScreen = true`. Per-frame declarations permit runtime switches. |
| Ink 7 | Inline by default. `alternateScreen: true` restores prior output on exit. CI and piped stdout ignore it. |
| Textual | `app.run(inline=True)` since 0.55. Set height through Screen CSS. Windows does not support inline mode. |
| Ratatui | `Viewport::Inline(height)` with `Terminal::with_options`. `Terminal::insert_before` adds permanent lines above the live area. |

Textual's inline height example is:

```css
Screen { &:inline { height: 50vh; } }
```

### The fzf viewport

fzf defaults to full-screen output.
`--height 40%` creates a bounded picker below the cursor, as shell bindings commonly request.
The UI uses `/dev/tty`, with stderr fallback. stdout contains the selection.
That separation permits `vim $(fzf)`.

### Exit contract

Inside command substitution or a pipe, stdout is captured data.
Send controls to stderr or `/dev/tty`.
Send the result to stdout.
gum uses `tea.WithOutput(os.Stderr)` and removes ANSI from non-TTY results.
This permits `CHOICE=$(gum choose a b c)`.

On exit, erase the transient UI or replace it with a short completion line.
An example is `✓ deployed api-server in 12s`.
Use Textual `inline_no_clear` or fzf `--no-clear` only when the last frame must remain.
Do not leave a partial inactive interface.

| Workflow | Mode |
| --- | --- |
| Pick, confirm, progress | Inline, with clean removal or a completion line |
| Explore, monitor, edit | Alternate screen, with restoration |
| Logs and live status | Height-limited inline, such as `--height 40%` or `Viewport::Inline` |

## Borders

### Unicode forms

The box-drawing block is U+2500 to U+257F.

| Form | Characters and use |
| --- | --- |
| Single | `─ │ ┌ ┐ └ ┘ ├ ┤ ┬ ┴ ┼`, a common default |
| Heavy | `━ ┃ ┏ ┓ ┗ ┛ ┣ ┫ ┳ ┻ ╋`, limited emphasis |
| Double | `═ ║ ╔ ╗ ╚ ╝ ╠ ╣ ╦ ╩ ╬`, deliberate retro style |
| Rounded | `╭ ╮ ╰ ╯` with single edges, common in Charm apps |

Use borders for dynamic boundaries, focus, or adjacent panels.
Skip decorative borders around static content or content already bounded by the terminal.
Prefer whitespace when it separates content sufficiently.

### Background mismatch

A border cell has foreground and background colours.
The line uses the foreground. The background fills the rest of the cell.
Different panel and parent backgrounds can expose a step around the border.

```text
parent_bg has black background
panel has dark blue background
border characters: render in panel's blue background
        ^^^ creates a visible "step" between border and content
```

Use matching panel and border backgrounds.
Alternatively, use one-eighth blocks such as `▏▎▍`, as Textual themes do.

### ASCII fallback

For legacy SSH, conhost, `TERM=dumb`, or uncertain Unicode support, provide ASCII borders.

| Unicode | ASCII |
| --- | --- |
| `─│┌┐└┘├┤┬┴┼` | `-\|+++++++++` |
| Heavy | `=\|+++` or bold ASCII |
| `╭╮╰╯` | `+` |

Check `$LANG`, `$LC_ALL`, and terminal capabilities.
Provide `--ascii` or `MYAPP_ASCII=1` as explicit overrides.

## Colour

### Capability levels

Design for monochrome, 16 ANSI colours, and 256/truecolour.
ANSI colours are user-theme values, not fixed RGB constants.
Red can be `#ef5350`, `#dc322f`, or `#f38ba8` in Material, Solarized, or Catppuccin.
Define colour by meaning.

### Semantic tokens

```text
status.success    → green
status.warning    → yellow
status.error      → red
status.info       → blue or cyan

text.primary      → default fg
text.muted        → dim or gray
text.emphasis     → bold + accent

bg.base           → default bg
bg.surface        → slightly elevated
bg.overlay        → modal/popup bg

accent.primary    → brand color
accent.secondary  → complementary

border.default    → muted
border.focus      → accent.primary

git.staged        → green
git.modified      → yellow
git.untracked     → red or cyan
git.added         → green (foreground)
git.deleted       → red (foreground)
```

Map tokens through Lipgloss v2 `LightDark`, Textual CSS variables, or Ratatui palette indirection.
Lipgloss v1/compat uses `AdaptiveColor`.
Separate mappings permit Catppuccin variants or light/dark changes without renderer changes.

| Colour | Meaning |
| --- | --- |
| Green | Success, added, online |
| Red | Error, deleted, danger, offline |
| Yellow | Warning, modified, pending |
| Cyan/blue | Information, paths, links, hints |
| Magenta | Special attention without alarm |
| Dim/grey | Secondary, disabled, metadata, time |
| Bold | Title, primary content, emphasis |

### Accessibility

About 8% of males have red-green colour vision deficiency.
Pair colour with letters, symbols, or position.
lazygit uses `M`, `A`, `D`, and `??`. Delta uses `+` and `-`.
Give errors a consistent position or column.
Prefer blue/orange, blue/yellow, or high-contrast neutral pairs to red/green alone.

### NO_COLOR

Follow [no-color.org](https://no-color.org), the informal standard from 2018.
Non-empty `NO_COLOR` suppresses automatic colour.
A documented explicit choice such as `--color=always` can override it.
ripgrep, bat, eza, delta, fd, gh, and cargo honour it.

Library support varies.
owo-colors needs `supports-colors` and `if_supports_color` to check capability and environment settings.
Keep policy at app level.
For tool-specific variables and precedence, use `references/cli-basics.md`.

## Typography

Terminal font size is fixed.

| Attribute | Purpose and limit |
| --- | --- |
| Bold | Titles, selection, primary content, focused title |
| Dim | Metadata, time, disabled and secondary text |
| Italic | Light emphasis, with limited support |
| Underline | Links and shortcuts |
| Reverse video | Reliable selection, including VT100-era terminals |
| Strikethrough | Cancelled/deleted items, with limited support |
| Blink | Avoid for accessibility and support reasons |

Prefer reverse video for a selected row, cell, or cursor position.
Use bold plus accent for the focused title.

## Density

| Strategy | Use | Methods |
| --- | --- | --- |
| High density | Live monitors and row comparisons, such as htop/btop/k9s | Tight rows, one-line records, compact headers, `GiB`, `1.2k`, `99.9%`, sparklines |
| Low density | Prose, forms, decisions, such as gum/huh/glow/Posting | Spaced fields, single columns, labels above narrow fields, modal margins |
| Mixed | Complex apps | Dense tables/status, spaced settings/forms |

Use whitespace before adding borders to moderate-density layouts.

## The clutter audit

Count the causes of clutter and name exact removals.

| Check | Action |
| --- | --- |
| Border depth | Count from terminal edge to content. Usually keep at most one border. Remove redundant nested and full-screen frames. |
| Signals per state | `[PASS]` + green + `✅` + `▶` is four signals. Keep textual/symbolic meaning with optional colour reinforcement. |
| Repeated markers | A `▶` on every row distinguishes nothing. Reserve markers for selections, failures, or exceptions. |
| Controls versus data | Compare cells spent on borders, titles, padding, labels, and repeated fields with cells that show data. |
| Removal test | Remove decoration if no information is lost. Prefer a blank row when it separates content better. |

Repeated full dates waste space when only the log time changes.
Report counts and named elements, not a vague instruction to simplify.
Apply this audit to every new or reviewed layout.

## Responsive design

Test a 220-column window, an 80×24 SSH session, and a 60-column tmux split.
Include a small laptop display in the target conditions.
Do not assume that the author's terminal size is sufficient.

### Breakpoints

| Width | Behaviour |
| --- | --- |
| >120 columns | Full panels and optional preview |
| 80-120 columns | Main view, with details/logs on demand where needed |
| 60-80 columns | One column or primary pane. Collapse Miller columns and multi-column grids. |
| Below app minimum | State required dimensions without broken output or panic. |

lazygit's `--screen-mode full` is user-selected, not automatic responsive layout.
Do not claim an 80-column minimum for an app that intentionally supports 60 columns.
Name the tested minimum in the too-small message.
The upstream example is:

```text
terminal too small — need 48×12
```

A drill-down layout often adapts better than a fixed grid because only one main view needs space.

### Mechanics

- Use percentages, ratios, `Min`/`Max`/`Fill`, Textual `fr`, or Ink/Yoga flex.
- Derive geometry from the current frame or latest window dimensions.
- Invalidate cached rectangles on size changes.
- Hide previews first, then secondary columns, then low-priority fields.
- Preserve the main task and discoverable controls.
- Use detail-on-Enter for hidden fields.
- Truncate table cells with space for an ellipsis.
- Recalculate layout on resize.
- Combine rapid resize events only when layout work is expensive.

POSIX resize commonly starts with `SIGWINCH`. Windows and framework events differ.
Use 80×24 as a compatibility baseline, not a universal minimum.
Test the smaller app-specific minimum too.
`tmux split-window -h` provides a narrow-terminal test.
In reviews, name hidden panes at 80×24, the remaining content at 60 columns, and the exact minimum.

## Visual hierarchy

| Signal | Use |
| --- | --- |
| Position | Main content top/left, status below |
| Colour and weight | Bold accent titles, dim secondary text |
| Reverse video | Selection |
| Indentation | Trees with `├─ └─`, often 2 cells |
| Whitespace | Separation and emphasis |
| Symbols | `▶` expandable, `▼` expanded, `●` active, `○` inactive, `•` bullet |
| Borders | Focused panel |

Combine 2-3 signals where needed.
Examples are reverse + bold selection, accent border + bold title, or yellow + `[!]` with a blank row.

## Tables and lists

### Alignment

Right-align numbers and left-align text.
Keep categorical fields consistently left-aligned or centred.
Use fixed-width ISO dates such as `2026-04-28 14:30`.

### Truncation

Use tail truncation such as `/usr/local/share/...` when the prefix matters.
Use middle truncation such as `/usr/.../file.txt` when the basename matters.
Upstream associates tail truncation with eza/k9s and middle truncation with bat/helix.
Wrap prose, not dense table cells.
Reserve one cell for an ellipsis, or three for `...`.
Keep meaningful content instead of only `...`.

### Sort and filter

Show `▲`/`▼` after the sort header, for example `Size ▼`.
Allow key or click changes.
For filters, show `123/45678` and highlight matches.
Target updates below 100ms.

### Wide tables

Prefer detail-on-Enter for hidden fields.
Assign column priorities and hide low-priority fields as width decreases.
Horizontal scroll is another option, as htop uses for process columns.

### Virtualisation

Virtualise lists that can exceed a few hundred rows.

| Tool | Behaviour |
| --- | --- |
| k9s | Thousands of pods |
| Toolong | Multi-GB logs |
| Textual `DataTable` | Virtualised by default |
| Ratatui `List` + `ListState` | Efficient offsets |
| Bubbles `list` | Virtualised rows |
| Ink | Explicit windowed slice or viewport for mutable rows |

Ink `<Static>` is only for completed append-only history.
It does not virtualise selectable or filtered collections.
Rendering every row behind a viewport becomes expensive at 10k+ items.

## Headers, status, and footers

```text
┌─────────────────────────────────────────┐
│ Header (top)                            │ ← persistent context: app, dataset, mode
├─────────────────────────────────────────┤
│                                         │
│   Main area (middle)                    │ ← the panels
│                                         │
├─────────────────────────────────────────┤
│ Status / mode line                      │ ← ephemeral feedback
│ Footer hint bar                         │ ← contextual shortcuts
└─────────────────────────────────────────┘
```

Merge status/footer or omit the header when the task permits.
Bounded inline prompts often need neither.

| Area | Content |
| --- | --- |
| Header | App, dataset, branch, cluster/namespace, path, mode. Show time/host/version only when useful. |
| Status | Temporary Saved, changed-count, or connection feedback. Fade or replace with idle state. |
| Mode | Block cursor for NORMAL, bar for INSERT, underline for REPLACE, plus label/colour. |
| Footer | 3-5 contextual `key action` hints separated by `·` or `\|` |

htop uses `F1Help F2Setup F3Search F4Filter F5Tree F6SortBy F7Nice- F8Nice+ F9Kill F10Quit`.
lazygit's Files hints include `space stage ↵ commit p push P pull r refresh ?`.
Derive hints from the keymap, as described in `references/interaction-patterns.md`.

## Progress and states

### Spinners

Braille frames are a common indeterminate default.

```text
⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏
```

cli-spinners' `dots` uses ten frames at about 80ms per frame.
The package supplies about 70+ styles.
Delay display by about 150-200ms.
Finish with `✓`, `✗`, or clean removal.
Suppress animation on non-TTY output.

### Determinate progress

Block characters provide eight steps per cell.

```text
▏▎▍▌▋▊▉█
```

A 40-cell bar has 320 sub-cell states.

```text
[████████▎             ] 41%
```

Show percent, meaningful current/total counts, and ETA for long tasks.

### Multiple tasks

```text
package-a [████████████████████] 100% ✓
package-b [████████▎           ]  41%
package-c [██▎                 ]  10%
```

Use indicatif `MultiProgress`, Rich `Progress`, or listr2 `concurrent`.
Bubbles supplies a single `progress` component, so compose multiple bars explicitly.
Docker pulls, npm/cargo builds, and installers use this pattern.

### Pulse or fade

Use a subtle pulse for background work that needs little attention, as lazygit does for automatic fetch.

### Empty, loading, error, and disconnected states

| State | Contract |
| --- | --- |
| Empty | Name the next action, for example “No requests. Press `n` to create one.” |
| Loading | Use skeleton text or Loading with a delayed spinner. Avoid sub-200ms flashes. |
| Error | Explain failure and recovery, for example “Connection refused. Press `r` to retry.” |
| Disconnected | Prefer last-known-good data with stale/reconnecting status to an unexplained blank screen. |

k9s exposes `apiServerTimeout` and `maxConnRetry` for recovery.
The dim stale-view treatment is a recommendation, not a documented universal convention.
Do not let temporary missing data change saved configuration.
Upstream cites a btop bug where an unavailable GPU permanently changes saved widget settings.

### Timeouts and cancellation

After a second or two, show elapsed time for a slow operation.
Where safe, provide cancellation such as `Esc`.
This is a recommendation, not a settled lazygit, gh, or general TUI convention.
There is no sourced universal TUI timeout.
If borrowing web guidance, identify it: an indicator at 1s and determinate progress after 3s.
Prioritise elapsed time and cancellation over an arbitrary automatic timeout.

## Themes

Define semantic tokens and separate palette mappings.
Expose theme selection through config, environment, or a runtime command.

| Format | Examples |
| --- | --- |
| TOML | bottom, helix, starship, Alacritty since 0.13 |
| TOML-like | btop `btop.conf`, with `key = value` |
| YAML | lazygit `config.yml`, lazydocker, k9s `plugins.yaml` |
| Flags/Git config | bat flags, fzf `FZF_DEFAULT_OPTS`/`FZF_DEFAULT_OPTS_FILE`, delta `[delta]` in `.gitconfig` |
| TCSS | Textual, with live reload |
| JSON | Less common terminal configuration |

### Community palettes

For themeable apps, supply popular palettes or document imports.

| Palette | Variants |
| --- | --- |
| Catppuccin | Latte, Frappé, Macchiato, Mocha |
| Dracula | Standard palette |
| Nord | Standard palette |
| Gruvbox | Light/dark, soft/medium/hard contrast |
| Tokyo Night | Standard palette family |
| Rose Pine | Main, Moon, Dawn |
| Solarized | Light/dark |
| base16 | Shared specification with many themes |

Small tools need semantic colours and light/dark safety, not every palette.

### Icons and Nerd Fonts

No terminal protocol query proves that a Nerd Font is active.
kitty, WezTerm, iTerm2, Alacritty, Windows Terminal, and Ghostty do not expose such a query.
A configured name does not prove installation or per-glyph fallback.
`has-nerd-font` uses bundled-font and config heuristics, with a `NERD_FONT=1` override.
Do not invent reliable detection.
Use explicit icon selection where the app controls that policy.

| Tool | Policy |
| --- | --- |
| eza | `--icons=WHEN`: always/automatic/never. Automatic checks stdout TTY, not the font. |
| lazygit | `gui.nerdFontsVersion: '2' \| '3' \| ""`. Empty is the default, without icons. |
| yazi | Icons are enabled in the default theme. Override icon tables in `theme.toml` when needed. |

Pin the Nerd Font generation as well as enablement.
V3 moved Material Design Icons from `F500–FD46` to `F0001+` to avoid CJK collisions.
That change explains lazygit's explicit 2/3 choice.

Starship supplies `nerd-font-symbols`, `no-nerd-font`, and `plain-text-symbols` presets.
These support Nerd Font → Unicode → ASCII fallback.
Many other tools only support icons on/off, not all three levels.

### Light and dark

Use OSC `]11;?` background queries where supported.
Check `$COLORFGBG` on terminals that set it.
Lipgloss v2 `LightDark`, v1/compat `AdaptiveColor`, and Textual runtime themes help select colours.
When both modes exist, default to auto.
Provide an override such as `--theme dark`.

## Common pitfalls

- Hardcoded colours that conflict with the user's theme.
- Decorative borders without information or focus purpose.
- Colour-only status or emoji without text fallback.
- Misaligned CJK/emoji tables without `unicode_width` or string-width.
- Excessive bold text.
- Inconsistent header capitalisation.
- Poor light/dark contrast.
- Hidden important status.
- No visible keyboard focus.

Check these defects alongside clutter and minimum-size tests.
