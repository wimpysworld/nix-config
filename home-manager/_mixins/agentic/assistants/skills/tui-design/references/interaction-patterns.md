# Interaction patterns

Use predictable keys, visible focus, and discoverable actions in terminal interfaces.
All reference paths are relative to the skill root.

## Contents

- [Keybinding approaches](#keybinding-approaches)
- [Common keys](#common-keys)
- [Reserved keys](#reserved-keys)
- [Discoverability](#discoverability)
- [Modal, modeless, and contextual input](#modal-modeless-and-contextual-input)
- [Focus](#focus)
- [Search and filter](#search-and-filter)
- [Multi-select](#multi-select)
- [Mouse](#mouse)
- [Undo and redo](#undo-and-redo)
- [Confirmation](#confirmation)
- [Forms and settings](#forms-and-settings)
- [Terminal emulator requests](#terminal-emulator-requests)
- [The fzf pattern](#the-fzf-pattern)
- [The lazygit pattern](#the-lazygit-pattern)
- [The k9s pattern](#the-k9s-pattern)
- [The helix pattern](#the-helix-pattern)
- [Common pitfalls](#common-pitfalls)

## Keybinding approaches

Prefer modeless navigation with optional compatible vim aliases for new full-screen navigation tools.
A bounded prompt or form can use a smaller conventional keymap.

| Approach | Use | Benefit | Cost |
| --- | --- | --- | --- |
| Vim-style modal | Editors for vim-familiar users | Dense motions/operators, home-row input, leader namespaces | Learning, mode confusion, conflicts with conventional text editing |
| Emacs-style chords | Existing Emacs/readline conventions | No mode switch, modifier combinations, which-key discovery | Modifier strain, reserved-key conflicts, repetition cost |
| Arrow/GUI-like modeless | General tools, dashboards, monitors | Familiar arrows/Enter/Tab/Esc, easy mouse support | Fewer actions without modifiers |
| Hybrid | Navigation with arrows and optional `hjkl` | Familiar entry and faster learned navigation | Extra bindings and consistency checks |

Vim-style modes include NORMAL, INSERT, VISUAL, and COMMAND.
Examples include vim, neovim, helix, kakoune, aerc, and command modes in k9s/weechat.
`5dw` combines a count with deletion and motion.
Use this approach when repeated editing justifies the learning cost.

Emacs uses chords such as `C-x C-s` and `M-x`, with nested key tables.
Readline, shell bindings, and weechat also use chord conventions.
For new work without that history, prefer modal or modeless input according to the task.

Modeless examples include btop, htop, fzf, gum, Posting, Harlequin, and Textual apps.
Hybrid examples include lazygit, k9s, yazi, and gh dash.
Printable navigation aliases must yield while a text field owns input.

## Common keys

Use established meanings unless the task gives a clear reason to differ.

| Key | Action |
| --- | --- |
| `q` | Quit outside text entry |
| `?` | Help |
| `/` | Search/filter |
| `n` / `N` | Next/previous match |
| `Esc` | Cancel/back/dismiss |
| `Enter` / `Return` | Confirm/drill in |
| `Space` | Toggle/mark |
| `:` | Command mode |
| `gg` / `G` | Top/bottom |
| `Tab` / `Shift+Tab` | Focus cycle |
| `r` | Refresh |
| `1` to `9` | Panel or numbered tab |
| `hjkl` and arrows | Navigation when text entry does not conflict |
| `Ctrl+P` | Command palette, when present |
| `y` | Copy |
| `p` | Paste/push, according to context |
| `d` | Delete, normally with confirmation |
| `e` / `o` | Edit/open |

Keep meanings consistent.
If two bindings such as `Ctrl+S` and `:w` coexist, map both explicitly to the same operation.

## Reserved keys

| Key | Terminal meaning |
| --- | --- |
| Ctrl+C | SIGINT or raw-mode interrupt input, with clean exit |
| Ctrl+Z | SIGTSTP/suspend where supported, with terminal restoration |
| Ctrl+\ | SIGQUIT/core dump |
| Ctrl+S / Ctrl+Q | XON/XOFF on legacy serial terminals |

Do not silently replace terminal conventions with application actions.
A user-defined Ctrl+S save binding requires flow control disablement, such as `stty -ixon`.
Vim and helix do not bind it to save by default. Helix uses `Ctrl-s` for `save_selection`.
Ctrl+H can encode Backspace, depending on terminal configuration. Test before binding it.

## Discoverability

Make each action available through at least one visible or searchable route.

### Footer hints

For complex full-screen apps, show the 3-5 most useful shortcuts and update them by context.
For a one-step prompt, show complete controls beside the prompt instead.
Examples include htop's F1-F10 strip, helix's status line, and lazygit's contextual hints.

lazygit's example is `space stage  ↵ commit  p push  P pull  r refresh  ?`.
Define the keymap once and derive hints from it.

| Framework | Method |
| --- | --- |
| Bubble Tea | `bubbles/help` with `key.KeyMap` |
| Textual | `Footer` from `BINDINGS` |
| Ratatui | App helper reads the same binding map |
| Ink | Box-based hints read the same binding map |

### Help view

Use `?` or an equivalent visible action for grouped key help.
A tiny picker with its complete keymap already visible needs no extra modal.
Use `key  action  context` and group by mode, panel, or category.
lazygit groups help by panel. Textual apps can supply a key table.

### Leader keys and which-key

After Space, comma, or backslash leaders, show valid follow-up keys.
Let the user read, select an action, or cancel with Esc.
Helix's Space menu includes `f` files, `b` buffers, `s` symbols, and `a` LSP actions.
Neovim's which-key.nvim supplies the same discovery pattern.
Consider it beyond about 20 actions. Below that, help is often sufficient.

### Command palette

Add a fuzzy action palette when actions are numerous, cross contexts, or benefit from search.
A small app can stop at footer hints and help.
Once a palette exists, include every action that has a binding.
Show the binding alongside the action name.

```text
Action name              keybinding
Description / context
```

Textual defaults to Ctrl+P since v0.77, replacing Ctrl+backslash, which conflicts with SIGQUIT.
VS Code's Ctrl+Shift+P is a related model.
Helix and k9s use `:` commands with a similar discovery role, not identical palette behaviour.

## Modal, modeless, and contextual input

### Modal

Keys depend on NORMAL, INSERT, or another explicit mode.
Provide a persistent mode label, distinct cursor forms, and instructions for learning the modes.
Use a block cursor for NORMAL, a bar for INSERT, and an underline for REPLACE.
Modal input supports dense bindings and composable operators such as `d` plus motion.
Weak mode indication causes confusion.

### Modeless

Focus determines the active widget without an editing mode.
Provide visible focus through borders, titles, or selection.
Use modifiers for less-common actions.
This reduces mode learning but consumes more binding combinations and screen space for focus cues.

### Contextual

The active panel changes bindings.
For example, lazygit's `c` commits in Files, checks out in Branches, and copies in Stash.
k9s also has resource-specific actions.
Show current meanings in the footer so that contextual input stays predictable.

## Focus

Focus determines key handling, footer hints, and active styling.

| Indicator | Use |
| --- | --- |
| Border colour | Accent on the focused panel |
| Border weight | Thin to thick |
| Title | Bold plus accent |
| Background tint | Use carefully around border backgrounds |
| Selection | Reverse video when active, muted when inactive |

Combine 2-3 indicators where needed.

| Navigation | Best use |
| --- | --- |
| Tab / Shift+Tab | Small linear panel sets |
| `1` to `9` | Direct access to many panels, including lazygit and yazi |
| `Ctrl+w h/j/k/l` | Spatial arrangements |
| Mouse click | Optional faster access |

Numeric jumps suit 5+ panels. Tab is sufficient for 2-3.
Inside modal dialogs and forms, trap Tab within internal widgets.
Provide Esc to leave the focus trap.

## Search and filter

### Search

Search moves through content without hiding unmatched content.
Use `/`, Enter for the first match, and `n`/`N` for later matches.
Examples include vim, less, and lazygit.
Show `(2/15)`, highlight all matches, and distinguish the current match.
Esc cancels and restores the original position.

### Filter

Filter narrows the visible list.
Use `/` when search is not required, or a distinct key otherwise.
fzf, k9s, and Textual Input-driven lists use this pattern.
Target updates below 100ms.
Show `123/45678` and highlight matched text.
Esc clears the filter.

Smart-case treats lowercase queries as case-insensitive and mixed-case queries as case-sensitive.
The upstream examples are ripgrep, fzf, and fd.

## Multi-select

Use Space to toggle a row mark, with a `*` prefix or accent background.

| Variant | Contract |
| --- | --- |
| Visual mode `v` | Extend selection with motion, as in yazi/vim |
| Shift+Click or Shift+arrow | Select a range |
| Ctrl+A | Select all, with an alternative for GNU screen/tmux prefixes and readline |
| `*` or another printable key | Invert selection |

Avoid Ctrl+I for invert. Legacy terminals encode it identically to Tab.
Only enhanced protocols such as Kitty can distinguish them.
After selection, apply actions such as `d` or `y` to all marked items.

## Mouse

Prefer mouse support as an addition to complete keyboard access.
Textual supports hover/click/scroll. lazygit supports click selection. btop supports click focus and scrolling.
Mouse capture can interfere with terminal selection and adds implementation work.
Keyboard-only use remains important for restricted SSH and serial consoles.

Support mouse focus, tabs, list scrolling, and form buttons where useful.
Do not require the mouse for the main workflow or advanced actions.
Document Shift as the common terminal-selection bypass while mouse capture is active.
Do not assume that every emulator uses the same bypass.

## Undo and redo

For destructive tools, prefer reversible actions where practical.
lazygit uses `z` and `Ctrl+z` for Git undo/redo, including rebases and file operations.
Treat that binding as an app example, not permission to ignore the reserved-key guidance.

Use an action stack for individually reversible operations.
Use full-state snapshots when coarser undo is acceptable and simpler.
For destructive operations without undo, require confirmation.

## Confirmation

Default to No in a light y/n prompt.

```text
Delete 3 files? [y/N]
```

For high-impact actions, require the target name, as Heroku does for app deletion.

```text
This will delete the production database.
Type the database name to confirm: prod-main
```

Reserve dual confirmation for exceptional consequences.

```text
Step 1: Type "delete" to confirm
> delete

Step 2: Are you sure? [y/N]
```

Match confirmation effort to consequence.
Do not require typed names for routine actions, because repeated low-risk prompts weaken attention.

## Forms and settings

### Validation timing

Default to blur or submit so that incomplete input does not immediately show an error.
huh Input validates on focus loss and Next/Submit, not each keystroke.
Clack and Inquirer validate on Enter because one-at-a-time prompts have no blur transition.
After an error, live revalidation can clear it when the value becomes valid.
Debounce expensive/remote checks or reserve them for submit.

Textual `Input.validate_on` accepts `"blur"`, `"changed"`, and `"submitted"`, with all three enabled by default.
Use `validate_on=["blur"]` or `["submitted"]` when errors need to wait.
Keep `"changed"` only for useful, non-disruptive immediate feedback.

### Required fields

Do not assume a built-in required marker in huh, Textual, Clack, or Inquirer.
huh's `" *"` suffix indicates a validation error, not a required field.
There is no huh `Required()` API.
If needed, add `(required)` or an explained `*` to labels.
Colour can reinforce that marker, but cannot replace it.

### Conditional fields

huh `Group.WithHideFunc(func() bool)` hides or shows an entire group as form state changes.
It does not provide per-field hiding.
For dependent values, use `OptionsFunc`, `TitleFunc`, or `DescriptionFunc` with a callback and dependency pointers.

```go
huh.NewSelect[string]().
    OptionsFunc(func() []huh.Option[string] {
        return huh.NewOptions(statesForCountry(country)...)
    }, &country) // recomputed whenever `country` changes
```

Textual uses `watch_<name>(old, new)` for a `reactive()` attribute.
Set `widget.display = False` to remove layout space, or `.visible = False` to hide without reflow.

### Settings persistence

There is no universal TUI persistence or Esc-discard contract.
Choose from the operation's actual requirements.

| Pattern | Use |
| --- | --- |
| Live apply | htop F2 applies immediately and persists implicitly, without dirty/discard controls. |
| Apply / Save / Cancel | Use for grouped validation, atomic changes, expensive reloads, or remote updates. Show dirty state and define Esc behaviour. |
| `$EDITOR` | lazygit opens raw config with `e` and requires restart for changes. |

Confirm before discarding meaningful edits according to their recovery cost.

## Terminal emulator requests

OSC sequences request local emulator actions through the output stream, including over SSH, containers, and nested shells.
They do not require X11 forwarding or a remote clipboard service.

### OSC 8 hyperlinks

The sequence is `ESC ] 8 ; params ; URI ESC \`, link text, then `ESC ] 8 ; ; ESC \`.
Optional `id=` connects wrapped or split link regions for shared hover display.
Simple filters need no IDs. Full-screen apps that manage regions can use them.

Support includes iTerm2, kitty, WezTerm, Ghostty, foot, Windows Terminal 1.4+, Alacritty 0.11+, and tmux 3.4+.
Unsupported terminals normally ignore the sequence and retain visible text.
Strip it from non-TTY stdout to keep raw sequences out of files and pipes.

| Library | Support |
| --- | --- |
| Lipgloss v2 | `Style.Hyperlink(url)` |
| Rich/Textual | `link` style attribute |
| Ratatui | No native support. Escapes in Text/Span break cell-width accounting, tracked in #563/#1227. |

Ratatui workarounds include hyperrat and tui-link, with buffer-model limitations.
Over SSH, links open locally. Remote `file://` paths do not resolve locally.
For remote files, suspend and run `$EDITOR` remotely instead.
Use OSC 8 for URLs such as `https://`.

### OSC 52 clipboard writes

`ESC ] 52 ; c ; <base64 payload> ESC \` requests clipboard replacement on the local emulator.
xterm/hterm commonly limit the whole sequence to 100,000 bytes, about 74,994 decoded text bytes.
Older kitty limits were lower.
Keep payloads to tens of KB or chunk them where supported.

In tmux, `set-clipboard on` permits inner apps to set the outer clipboard.
`external`, the default since 2.6, reserves that access for tmux itself.
Forwarding needs the outer terminal's `Ms` terminfo capability.
tmux supports OSC 52 directly without `allow-passthrough`.

Prefer write-only clipboard integration.
Reads can expose local data to a malicious remote, so terminals disable or prompt for them.
kitty prompts, WezTerm ignores queries, and Alacritty disabled paste-back by default in 0.13.
Alacritty ignores writes from unfocused windows since 0.11.
Windows Terminal added a similar focus check in February 2026.
Treat writes as best-effort, especially from background work.

crossterm 0.29 added OSC 52 copy. Bubble Tea v2 provides `tea.SetClipboard`.
Provide a local fallback such as `pbcopy`, `xclip`, `wl-copy`, or Rust arboard.
Local OS APIs can be more reliable, and some terminals disable OSC 52 entirely.

### OSC 9 and 777 notifications

OSC 9 is `ESC ] 9 ; message ESC \`.
It originated in iTerm2 and is supported by kitty, WezTerm, Ghostty, iTerm2, and foot.
OSC 777 adds a title: `ESC ] 777 ; notify ; title ; body ESC \`.
Use 777 on known supporting terminals, including WezTerm, Ghostty, and foot. Otherwise prefer 9.
tmux needs DCS passthrough and `allow-passthrough on` from 3.3+ for either sequence.

Notify once when long work finishes or fails while the user is elsewhere.
Keep text short and prefer in-app status when focused.
Do not notify for routine input or immediate actions.

### Other terminal controls

OSC 11 queries background colour with `OSC 11 ; ? ST`.
See Themes in `references/visual-patterns.md`.
Bracketed paste mode 2004 surrounds pasted text with `ESC [200~ … ESC [201~`.
Enable it for free-text prompts, normally through the framework.

## The fzf pattern

The fuzzy-filter pattern also appears in telescope.nvim, atuin, zoxide, helix Space+f, Textual palettes, k9s, and lazygit.

1. Open with `/`, `Ctrl+P`, or another visible key.
2. Update results as the user types.
3. Use arrows or `Ctrl+J`/`Ctrl+K` while text entry owns printable keys.
4. Reserve bare `hjkl` for navigation mode or a view without active text entry.
5. In `--multi`, use Tab to mark rows.
6. Use Enter to confirm and Esc to cancel.
7. Add an optional right-side preview for the current result.

Target updates below 100ms.
Show match counts such as `123/45678` and highlight matches.
Use smart-case and rank exact matches before prefix, then substring matches.

| Language | Matchers |
| --- | --- |
| Go | `sahilm/fuzzy`, `lithammer/fuzzysearch` |
| Rust | nucleo, used by helix, or skim |
| Python | rapidfuzz |
| TS/JS | fuse.js or fzy.js |

See fzf in `references/exemplar-apps.md`.

## The lazygit pattern

Use 5+ fixed panels, direct `1` to `9` jumps, Tab cycling, and contextual single-letter actions.
Update the footer for each panel so that users can see the current meaning of `c` and other keys.
The benefit is dense bindings. The cost is learning several meanings for one key.
lazydocker uses the same pattern, with earlier influence from mc and Norton Commander.
See lazygit in `references/exemplar-apps.md`.

## The k9s pattern

Use command mode for many frequently used resources or actions.
Press `:`, enter a resource such as `pods`, `nodes`, `svc`, or `ingress`, complete with Tab, then press Enter.
Provide aliases such as `po` for `pods`.
Without completion and discoverable help, users cannot find available commands.
k9s shows aliases in `?`.
Related examples are helix ex-commands, weechat slash commands, and aerc.
See k9s in `references/exemplar-apps.md`.

## The helix pattern

Select first, then act: `wd` selects a word then deletes it, unlike vim's `dw`.
Helix combines multi-cursor editing, tree-sitter, and a Space which-key menu.
For other TUIs, highlight affected rows, fields, or URLs before an action.
Use multi-selection for batch changes and leader-key hints for modal discovery.
See helix in `references/exemplar-apps.md`.

## Common pitfalls

- Reserved-key conflicts.
- Invisible focus or mode state.
- No conventional visible exit when `q` is unavailable outside text entry.
- Esc that fails to return or dismiss in an established stack/modal.
- No discoverable key help for complex actions.
- Filter updates above 100ms.
- Destructive single-letter actions without confirmation or undo.
- Contextual keys without updated footer hints.
- Mouse-only actions.
- Tab order that differs from visual reading order.
- Missing multi-select for batch work.

Check each applicable case during interaction review.
