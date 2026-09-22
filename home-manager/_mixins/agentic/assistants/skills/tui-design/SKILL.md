# TUI and CLI design

Design terminal software with predictable input, output, layout, and cleanup.

## Select references

All reference paths in this skill are relative to the skill root.

| Need | Reference |
| --- | --- |
| Go, Bubble Tea, Lipgloss, Bubbles, tview, gocui | `references/ecosystem-go.md` |
| Rust, Ratatui, crossterm, Cursive | `references/ecosystem-rust.md` |
| Python, Textual, Rich, prompt_toolkit, urwid | `references/ecosystem-python.md` |
| TypeScript/JavaScript, Ink, OpenTUI, Clack, Inquirer | `references/ecosystem-typescript.md` |
| One-shot commands, arguments, streams, exit codes, automation | `references/cli-basics.md` |
| Layouts, buffers, borders, hierarchy, colour, density, responsive behaviour, tables, themes, accessibility | `references/visual-patterns.md` |
| Keys, focus, navigation, modes, forms, mouse, confirmation, undo, OSC features | `references/interaction-patterns.md` |
| lazygit, k9s, fzf, btop, helix, yazi, atuin and other case studies | `references/exemplar-apps.md` |
| Screenshots or demo recordings | The optional `vhs-cli-demos` skill, if available |

Load only the references that the task needs.
When the request names a framework or ecosystem, load its reference before claims about APIs, lifecycle, implementation, or tests.
Use the visual and interaction references for cross-ecosystem design rules.
Use case studies as evidence, not as substitutes for those rules.

The `vhs-cli-demos` skill is not part of this import.
If it is absent, continue design work without installation.
For requested capture work, report the missing capability or use an available, authorised method.

When no language is named, ask only if the choice materially changes the answer or implementation.
Otherwise, recommend Go for single binaries, Rust for control and reliability, Python for rapid product work, or TypeScript for React/npm projects.

## Classify the product

Choose the output contract before the framework or layout.

| Product | Default contract |
| --- | --- |
| One-shot CLI | No live full-screen UI. Send results to stdout and diagnostics to stderr. Use meaningful exit codes and `references/cli-basics.md`. |
| Open, choose, exit | Prefer inline output when shell context matters. Send controls to stderr or `/dev/tty` and the selection to stdout. |
| Full-screen session | Use the alternate screen and stable panel positions. Specify restoration, resize, suspend, and redraw behaviour. |

A picker can use full-screen output when a large preview or working set needs stable space.
Select persistent panels, Miller columns, a drill-down stack, a dashboard, IDE-style panes, an overlay, or tabs.
Check the choice against `references/visual-patterns.md`.
Sketch initial, loading, empty, partial, success, error, disconnected, and too-small states before code.

## Complete the task

1. Classify the product and its stdout/stderr contract.
2. Identify the main user workflow and the 5-8 most common actions.
3. Select the ecosystem and load its reference and relevant pattern references.
4. Sketch layout and state transitions at wide, standard, narrow, and minimum sizes.
5. Use the framework's native architecture.
6. Where the framework permits, separate state, update, and event work from rendering.
7. Verify cleanup, discoverable input, output behaviour, width handling, and asynchronous work.
8. Test the smallest stable layer first, then rendered frames.
9. Add a small PTY test only when integration risk justifies it.

For design questions, recommend before explanation.
Before a new framework or abstraction, inspect the existing architecture and dependencies.
For reviews, cite concrete observations and prioritise changes by user harm.

## Preserve shared contracts

### Terminal lifecycle

- Use the alternate screen for full-screen sessions.
- Keep bounded and one-shot workflows inline where possible.
- Prefer framework-managed cleanup.
- Restore raw mode, screen buffer, cursor, and input modes on every exit, including errors and panics.
- Do not add custom signal handling when the framework already owns it.
- On resize, calculate layout from the current frame or window size.
- Combine rapid resize events only when layout work is expensive.
- Keep final shutdown separate from temporary terminal handoff.
- For an editor, shell, or supported suspend, prefer the framework's handoff API.
- Pause input, restore the shell-facing terminal, wait, re-enter modes, reload externally mutable data, and force a full redraw.
- Do not confuse redraw with a data refresh.
- Do not final-unmount an app that must resume.
- Do not assume that POSIX signals exist on Windows.
- Send logs to a file, framework console, or separate diagnostic stream, not the active TUI screen.

### Rendering, data, and performance

- Never block the UI/event thread on disk, network, or subprocess work.
- Return results through commands, messages, tasks, channels, or framework events.
- Render on input, data, resize, or deliberate ticks, not an unconditional loop over unchanged state.
- Measure terminal cell width, not bytes, code points, `len()`, or JavaScript string length.
- Test CJK, combining marks, and emoji.
- Virtualise collections that can exceed a few hundred rows.
- Truncate table cells instead of wrapping them.
- Show full values in a detail view.
- Keep panel positions stable unless the user changes the layout.

### Meaning and access

- Define semantic style tokens instead of scattered colour literals.
- Honour `NO_COLOR` in automatic colour mode and preserve meaning in monochrome.
- Pair colour with text, form, position, or symbols.
- Provide ASCII fallback when Unicode support is uncertain.
- Make every action keyboard-reachable.
- Use mouse support to speed up actions, never to restrict them.
- Add familiar navigation aliases only when they do not conflict with text entry or a complete bounded keymap.
- Preserve terminal interrupt, suspend, and flow-control behaviour.
- Show complete inline controls for bounded prompts.
- For complex full-screen apps, provide contextual hints, help, and optionally a command palette.
- Provide `--no-tui` or an equivalent plain mode when automation or accessibility needs require linear output.

## Review every layout

Apply both checks even when the user asks about another part of the interface.

### Count clutter

Report:

- Border-nesting depth. More than one border between the terminal edge and content is usually excessive.
- Signals for each state. `[PASS]`, green, a checkmark, and a row marker are four signals.
- Markers on every row that distinguish nothing.
- Cells spent on borders, labels, controls, and repeated fields instead of data.

Name the exact borders, markers, labels, or fields to remove.
Use the clutter audit in `references/visual-patterns.md`.

### Test the minimum sizes

State what happens at 80×24 and in a 60-column tmux split.
Name the primary pane, hidden content, truncation, drill-down replacements, and the threshold for a too-small message.
Give every multi-column design a single-pane fallback.
Use the responsive design method in `references/visual-patterns.md`.

## Build and verify

Keep business state testable without a terminal.
For MVU or immediate-mode systems, send synthetic events to update logic and assert state.
For retained/widget systems, use the smallest widget or app test harness that owns the behaviour.

Use these test layers, with most tests in the first layer:

1. Unit-test transitions, parsing, sorting, filtering, and command construction.
2. Snapshot or golden-test frames at fixed sizes and colour profiles, including 80×24, 60 columns, and the hard minimum.
3. Use one or two PTY flows for lifecycle and real-keyboard integration, not as the main suite.

Verify:

- Normal exit, interrupt, error, and panic cleanup.
- Resize, too-small behaviour, and supported suspend/resume.
- Empty, loading, partial, error, disconnected, and large-data states.
- Keyboard access, visible focus, and accurate help.
- `NO_COLOR`, 16-colour or monochrome output, ASCII fallback, and non-TTY output.
- Wide characters, combining marks, truncation, sorting, and virtualisation.
- Clean stdout and no blocking I/O in the event/render path.

Use the ecosystem reference's exact test and debug APIs.
Never print diagnostics into an active raw-mode or alternate-screen UI.

## Review existing interfaces

Report evidence in this priority order:

1. Does the product need full-screen output, inline output, or a one-shot command?
2. Can an exit path leave raw mode, cursor state, mouse capture, or the screen buffer active?
3. Does the UI block, waste redraws, fail on resize, or calculate cell width incorrectly?
4. Can a new user find important actions without conflicts with text entry or terminal conventions?
5. What does the clutter audit count, and which elements need removal?
6. What happens at 80×24, 60 columns, and the declared minimum?
7. Do streams, exit codes, non-TTY behaviour, `NO_COLOR`, and plain mode support scripts and accessibility?
8. Do tests cover state transitions and fixed frames at the correct layers?

Tie each recommendation to a visible failure, implementation risk, or measurable reduction in clutter.

## Recommend concrete choices

Require semantic colours, terminal restoration, responsive fallback, non-blocking work, width-aware rendering, and explicit stream contracts.
Explain trade-offs for inline/full-screen output, modal/modeless input, mouse support, and destructive-action confirmation.
Use the chosen ecosystem's conventions instead of a literal translation from another framework.
For an abstract choice, cite a case study in `references/exemplar-apps.md` and explain which part applies.
