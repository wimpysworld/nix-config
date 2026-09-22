# Rust ecosystem

Prefer Ratatui, Crossterm, clap, and color-eyre for new Rust TUIs.
Ratatui forked from `tui-rs` in February 2023. Helix uses a custom renderer with related patterns.
All reference paths are relative to the skill root.

## Contents

- [Quick recommendation](#quick-recommendation)
- [Ratatui](#ratatui)
- [Lifecycle and terminal handoff](#lifecycle-and-terminal-handoff)
- [Widgets](#widgets)
- [Layout](#layout)
- [Styling](#styling)
- [Backends](#backends)
- [State management](#state-management)
- [Async with Tokio](#async-with-tokio)
- [Testing](#testing)
- [Debugging](#debugging)
- [Companion crates](#companion-crates)
- [Panic and error safety](#panic-and-error-safety)
- [Alternatives](#alternatives)
- [Pitfalls](#pitfalls)
- [Apps to study](#apps-to-study)
- [CLI design](#cli-design)

## Quick recommendation

| Need | Use |
| --- | --- |
| New TUI | Ratatui + Crossterm |
| Forms, dialogs, menus | Cursive |
| React-like declarative UI | iocraft, with hooks, JSX-style macros, and taffy |
| Argument parsing | clap derive API |
| Colour formatting | owo-colors |
| Non-TUI progress | indicatif |
| One-shot prompts | inquire, or dialoguer for a stable alternative |
| Error reports | color-eyre |
| Clack-style wizards | cliclack |

Start with `ratatui/templates` for Tokio, panic handling, and components.

## Ratatui

The upstream baseline is 0.30.2, after the 0.30.0 stable release in December 2025.
Version 0.30 split the workspace into crates and added `no_std` support.
The main `ratatui` crate still re-exports the public API.
Check Crossterm compatibility when selecting versions.

Ratatui is immediate-mode: each frame describes the complete UI from current state.
The library compares buffers and emits only changed cells.
The app owns state, timing, and its event loop. Ratatui owns rendering calculations.

```rust
use ratatui::{prelude::*, widgets::*};
use color_eyre::Result;

fn main() -> Result<()> {
    color_eyre::install()?;            // install reporting before Ratatui wraps the hook
    let mut terminal = ratatui::init();
    let result = App::default().run(&mut terminal);
    ratatui::restore();
    result
}

#[derive(Default)]
struct App {
    counter: i32,
    should_quit: bool,
}

impl App {
    fn run(&mut self, terminal: &mut DefaultTerminal) -> Result<()> {
        while !self.should_quit {
            terminal.draw(|frame| self.draw(frame))?;
            self.handle_events()?;
        }
        Ok(())
    }

    fn draw(&self, frame: &mut Frame) {
        frame.render_widget(
            Paragraph::new(format!("Counter: {}", self.counter))
                .block(Block::bordered().title("Demo")),
            frame.area(),
        );
    }

    fn handle_events(&mut self) -> Result<()> {
        if let Event::Key(key) = event::read()? {
            if key.kind == KeyEventKind::Press {
                match key.code {
                    KeyCode::Char('q') => self.should_quit = true,
                    KeyCode::Char('+') | KeyCode::Right => self.counter += 1,
                    KeyCode::Char('-') | KeyCode::Left => self.counter -= 1,
                    _ => {}
                }
            }
        }
        Ok(())
    }
}
```

`ratatui::init()` enables raw mode and enters the alternate screen.
It creates `Terminal<CrosstermBackend>` and installs a panic hook for restoration.
That hook calls the previous hook after restoration.
Install reporting hooks such as color-eyre first.
Use `ratatui::restore()` for normal shutdown.

## Lifecycle and terminal handoff

Ratatui does not own subprocesses, the app event loop, or general signal policy.
Route external lifecycle events through the event loop and managed cleanup.

| Boundary | Ratatui 0.30 contract |
| --- | --- |
| Normal exit | Prefer `ratatui::run(...)`. With `init()`/`restore()`, retain the loop result, restore, then return it. |
| SIGTERM | Send a quit event through the runtime or signal integration. Return through managed cleanup. Default SIGTERM and SIGKILL do not unwind Rust. |
| Interactive child | Pause the input reader. Restore shell modes. Run and wait for the child. Reinitialise, clear, and draw completely. |
| Unix suspend | Use the same handoff sequence. Send SIGTSTP after restoration. Reinitialise and redraw after SIGCONT. |
| Windows | Provide an alternative to Unix job-control signals. |

Retain `child_result` during re-entry.
Attempt each re-entry step independently.
If the child and re-entry both fail, report both errors.
Do not let `try_init()?`, `clear()?`, or `draw()?` discard the child failure before inspection.
An active input task can consume capability responses during reinitialisation.
The official [external-editor recipe](https://ratatui.rs/recipes/apps/spawn-vim/) demonstrates reader pause and terminal restoration.

After the child, reload externally mutable files, processes, or remote state.
Redraw alone proves only renderer recovery.

## Widgets

| Built-in | Purpose |
| --- | --- |
| `Block` | Border, title, padding |
| `Paragraph` | Text, wrap, alignment, scroll |
| `List` + `ListState` | Selectable virtualised list |
| `Table` + `TableState` | Selectable virtualised table |
| `Tabs` | Tab bar |
| `Chart` | Line/scatter plots with axes |
| `BarChart` | Horizontal/vertical bars |
| `Gauge` / `LineGauge` | Progress |
| `Sparkline` | Compact trends |
| `Canvas` | Braille sub-cell maps, plots, and forms |
| `Scrollbar` | Scroll indicator |
| `Clear` | Erase an area before a popup |
| `Calendar` | Monthly calendar |

Custom widgets implement `Widget` or `StatefulWidget` and consume `(area, buf)` without extra abstraction cost.

| Third-party widget | Purpose |
| --- | --- |
| `tui-textarea` | Multi-line editor with vim/emacs keys |
| `tui-input` | Single-line input |
| `tui-tree-widget` | Tree |
| `tui-big-text` | Banner text |
| `tui-popup` | Modal |
| `tui-logger` | Log pane |
| `throbber-widgets-tui` | Spinners |

## Layout

Layout uses Cassowary constraints, also used by iOS Auto Layout.

```rust
use ratatui::layout::{Layout, Constraint};

let [header, body, status] = Layout::vertical([
    Constraint::Length(3),    // 3 rows for header
    Constraint::Min(0),       // body fills remaining
    Constraint::Length(1),    // 1 row for status
]).areas(frame.area());

let [sidebar, main] = Layout::horizontal([
    Constraint::Percentage(30),
    Constraint::Percentage(70),
]).areas(body);
```

| Constraint | Meaning |
| --- | --- |
| `Length(n)` | Exactly n cells |
| `Min(n)` | At least n cells, with growth |
| `Max(n)` | At most n cells |
| `Percentage(p)` | Percent of available space |
| `Ratio(num, den)` | Fraction |
| `Fill(weight)` | Proportional weight |

Prefer `Fill` over `Percentage` for simple ratios.
Layouts cache by default. Split once and reuse `Rect`s within the frame.

## Styling

```rust
use ratatui::style::{Color, Modifier, Style, Stylize};

// Direct API
let style = Style::default()
    .fg(Color::Yellow)
    .bg(Color::Black)
    .add_modifier(Modifier::BOLD);

// Stylize extension trait (preferred for brevity)
let span = "Hello".bold().yellow().on_black();
```

Colours include 16 ANSI names, `Color::Indexed(u8)` for 256 colours, and `Color::Rgb(r, g, b)` for truecolour.
Use `crossterm::style::available_color_count()` for capability checks where needed.
Modifiers are `BOLD`, `DIM`, `ITALIC`, `UNDERLINED`, `SLOW_BLINK`, `RAPID_BLINK`, `REVERSED`, `HIDDEN`, and `CROSSED_OUT`.
Avoid blinking and crossed-out text because support is limited.

## Backends

| Backend | Choice |
| --- | --- |
| Crossterm | Default, pure Rust, MIT, Linux/macOS/Windows |
| Termion | Smaller Unix-only alternative |
| Termwiz | Cross-platform graphics support, including Sixel and kitty, from the WezTerm developer |
| mousefood | `embedded-graphics` over `ratatui-core` for `no_std` hardware displays |

Avoid multiple incompatible Crossterm versions. They create separate event queues and inconsistent raw-mode tracking.
Run `cargo tree -p crossterm` and verify one version.
The upstream baseline is Crossterm 0.29 from April 2025, with 0.28 as a legacy choice.
Ratatui 0.30 exposes the feature flags `crossterm_0_28` and `crossterm_0_29`.
Prefer `crossterm_0_29`. Enable only the flag that matches your dependency.

## State management

For simple apps, use one App struct.

```rust
struct App {
    items: Vec<Item>,
    list_state: ListState,
    input: String,
    mode: Mode,
    // ...
}
```

For complex state, use Elm-style messages and pure update logic.

```rust
enum Msg { Increment, Decrement, Quit }

fn update(model: &mut Model, msg: Msg) -> Option<Cmd> { /* ... */ }
fn view(model: &Model, frame: &mut Frame) { /* ... */ }
```

For larger apps, use components with `init`, `handle_events`, `update`, and `draw`.
Components communicate through `mpsc::UnboundedSender<Action>` in `ratatui/templates` with Tokio.
The `tui-realm` framework provides this pattern, subscriptions, and message-based events.

## Async with Tokio

Use one input task, a tick task where needed, and an event-driven main loop.
A `select!` loop can combine channels and other asynchronous work.

```rust
use tokio::sync::mpsc;
use crossterm::event::{Event, EventStream};
use futures::StreamExt;

let (tx, mut rx) = mpsc::unbounded_channel::<AppEvent>();

// Input task
let input_tx = tx.clone();
tokio::spawn(async move {
    let mut events = EventStream::new();
    while let Some(Ok(event)) = events.next().await {
        let _ = input_tx.send(AppEvent::Crossterm(event));
    }
});

// Tick task
let tick_tx = tx.clone();
tokio::spawn(async move {
    let mut interval = tokio::time::interval(Duration::from_millis(250));
    loop {
        interval.tick().await;
        let _ = tick_tx.send(AppEvent::Tick);
    }
});

// Main loop
loop {
    terminal.draw(|f| app.draw(f))?;
    if let Some(event) = rx.recv().await {
        app.handle(event);
        if app.should_quit { break; }
    }
}
```

For synchronous apps, use `event::poll(Duration::from_millis(250))` followed by `event::read()` without Tokio.

## Testing

Use `TestBackend` to assert rendered output without a terminal.

```rust
use ratatui::{backend::TestBackend, Terminal};

let backend = TestBackend::new(20, 5);
let mut terminal = Terminal::new(backend)?;
terminal.draw(|f| app.draw(f))?;
terminal.backend().assert_buffer_lines([
    "┌─ Demo ───────────┐",
    "│Counter: 0        │",
    "└──────────────────┘",
    "                    ",
    "                    ",
]);
```

Use `insta::assert_snapshot!(terminal.backend())` for text snapshots and `cargo insta review` for review.
This official recipe does not assert colour or style.
For styles, create an expected `Buffer::with_lines(...)`.
Apply `set_style` to the relevant regions.
Compare buffers with `assert_eq!`.

Test unusual dimensions, including 79×23, alongside 80×24 and 200×50.
Use size-specific names such as `app_79x23`.
`rstest` parameterisation is community practice, and Ratatui uses it in its own tests.
Extract `fn compute_layout(area: Rect) -> ...` for cheap layout assertions.

Cover the first draw when refactoring the event loop for tests.
Gitui's snapshot work in PR #2411 removed the initial notification and produced a blank first tick.
PR #2813, merged in April 2026, restored that event.
OpenAI Codex requires snapshots for visible TUI changes, with `cargo insta pending-snapshots` and `cargo insta accept`.

## Debugging

Do not use `println!` or `dbg!` inside an active TUI.
Raw mode stops newline processing, and redraw overwrites direct output.

| Method | Use |
| --- | --- |
| File logs | `tracing` + `tracing-subscriber` with env-filter, ANSI disabled, and `tail -f app.log` elsewhere |
| Debug pane | Toggle `show_debug: bool` and render `format!("{state:#?}")` in a separate column |
| `tui-logger` | Ready-made log widget, 0.18.x, with `log`/`slog`/`tracing` feature flags |
| Debugger | Attach from another terminal with `lldb -p <pid>` / `gdb -p`, or use an IDE |

Use `cargo flamegraph` for standard profiling.
The upstream Ratatui recipes do not provide a dedicated profiling procedure.
Raw mode turns Ctrl+C into a key event, so the flamegraph wrapper cannot rely on SIGINT forwarding.
Give the app a quit key that restores raw mode and exits normally.
Alternatively, attach with `perf record -p $(pgrep app) -- sleep 30`.
For Tokio poll/wake/busy time, use `tokio-console` through `console-subscriber`.

Check accidental O(n) work inside rendering, such as large `Vec` collection or repeated width calculations.
Cache that work outside the draw loop.
Immediate-mode widget reconstruction is intentional and usually cheap.

## Companion crates

clap derives argument parsing, validation, help, and completions.

```rust
#[derive(Parser)]
struct Cli {
    #[arg(short, long)]
    verbose: bool,

    #[command(subcommand)]
    command: Commands,
}
```

| Crate | Use |
| --- | --- |
| color-eyre | Source-aware error reports. Install before Ratatui wraps the panic hook. |
| owo-colors | Zero-allocation styling. Use `supports-colors` and `if_supports_color` for capability/`NO_COLOR` policy. |
| indicatif | Non-TUI progress, hidden on non-TTY output |
| inquire | Text, select, multi-select, confirmation |
| dialoguer | Older stable prompt alternative |
| cliclack | Clack-style Unicode wizards |
| ratatui-image | Sixel/kitty/iTerm2 images |

Direct owo-colors styling emits colour unconditionally.
Prefer it to allocating `colored` or unmaintained `ansi_term`, but enforce output policy explicitly.

## Panic and error safety

Prefer the managed lifecycle.

```rust
fn main() -> color_eyre::Result<()> {
    color_eyre::install()?;
    ratatui::run(|terminal| App::default().run(terminal))
}
```

If the app manually constructs `Terminal` and enables modes, it owns normal and panic cleanup.
Wrap the existing reporting hook only for that manual path.

```rust
color_eyre::install()?;
let report_hook = std::panic::take_hook();
std::panic::set_hook(Box::new(move |info| {
    let _ = ratatui::restore();
    report_hook(info);
}));
```

Do not add this wrapper over `ratatui::run()` or `ratatui::init()`. Those APIs already install it.
`try_init()` can fail after partial setup. `try_restore()` stops at its first error.
Neither helper is transactional.

On failure, independently attempt raw-mode disablement, alternate-screen exit, mouse/paste disablement, and cursor restoration.
`ratatui::restore()` handles default Crossterm teardown only. Custom backends need matching cleanup.
Inject setup/teardown failures in a PTY.
Verify normal exit, returned errors, and panics.

## Alternatives

Cursive is retained-mode and callback-driven, with `Dialog`, `EditView`, `SelectView`, `TextArea`, `LinearLayout`, and `StackView`.
Use it for forms and menus that need a higher-level widget API.

```rust
use cursive::{Cursive, views::TextView};

let mut siv = Cursive::default();
siv.add_layer(TextView::new("Hello, world!"));
siv.add_global_callback('q', |s| s.quit());
siv.run();
```

| Alternative | Status and use |
| --- | --- |
| iocraft | React-like hooks and JSX-style macros with taffy, the flexbox engine used by Bevy and Servo |
| Dioxus TUI / Plasmo | Abandoned. Do not start new work on it. |
| Ratzilla (`ratatui/ratzilla`) | Maintained WASM browser target for demos and playgrounds |
| `tui-rs` | Archived predecessor. Migrate to Ratatui. |

## Pitfalls

1. Preserve terminal restoration on panics and returned errors.
2. Verify a single compatible Crossterm version.
3. Avoid unconditional draw loops. Use `event::poll(timeout)` or `tokio::select!`.
4. On Windows, filter keys with `key.kind == KeyEventKind::Press` because release events also arrive.
5. Keep `ListState`, `TableState`, and `ScrollbarState` in app state.
6. Pass mutable state references when rendering.
7. Document Shift as the common bypass for terminal text selection while mouse capture is active.
8. Reuse cached layout `Rect`s within a frame.
9. Use `unicode_width::UnicodeWidthStr::width(s)`, not `String::len()`, for cells.

## Apps to study

| App | Pattern |
| --- | --- |
| gitui | Async Git client |
| bottom (`btm`) | Widget dashboard |
| yazi | Miller columns and image preview |
| atuin | History picker and sync |
| csvlens | CSV viewer |
| bandwhich | Network monitor |
| oha | HTTP load tester |
| tokio-console | Tracing-based async debugger |
| systemctl-tui | systemd manager |
| gpg-tui | Key manager |
| kdash | Kubernetes interface |
| tenere | ChatGPT interface |
| helix | Modal editor with a custom renderer |
| zellij | Terminal multiplexer |

Use the relevant app and Ratatui's `examples/` for comparable tasks.

## CLI design

Use clap for parsing, indicatif for progress, and owo-colors with explicit colour policy.
Use anyhow or color-eyre for errors, and env_logger or tracing + tracing-subscriber for logs.
Apply `references/cli-basics.md` for arguments, exit codes, and streams.
