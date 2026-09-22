# Python ecosystem

Use Textual for full-screen apps, Rich for output, and prompt_toolkit for input-focused shells and REPLs.
All reference paths are relative to the skill root.

## Contents

- [Quick recommendation](#quick-recommendation)
- [Textual](#textual)
- [Lifecycle and terminal handoff](#lifecycle-and-terminal-handoff)
- [Widgets](#widgets)
- [Layout and TCSS](#layout-and-tcss)
- [Events and messages](#events-and-messages)
- [Reactive state](#reactive-state)
- [Async and workers](#async-and-workers)
- [Modal screens](#modal-screens)
- [Testing](#testing)
- [Debugging](#debugging)
- [Development tools](#development-tools)
- [Textual apps](#textual-apps)
- [Pitfalls](#pitfalls)
- [Rich](#rich)
- [prompt_toolkit](#prompt_toolkit)
- [Other libraries](#other-libraries)
- [Argument parsing](#argument-parsing)

## Quick recommendation

| Need | Use |
| --- | --- |
| Full-screen TUI | Textual |
| Tables, panels, syntax output | Rich |
| REPL or shell | prompt_toolkit |
| One or two prompts | questionary or InquirerPy |
| Typed argument parsing | Typer |
| Decorator parsing without type hints | Click |
| Fast progress bars | tqdm |
| Animated, redirect-safe progress | alive-progress |

## Textual

`Textualize/textual` combines an App subclass, an App → Screen → Widgets tree, TCSS, reactive attributes, and asyncio messages/events.
Textualize closed in mid-2025. Will McGugan continues Textual and Rich as open source.
The pinned upstream guidance describes four later major releases, with 8.x current in mid-2026.
Pin the major version and read upgrade notes.
Breaking changes include `Static.renderable` → `Static.content` in 6.0 and `Select.BLANK` → `Select.NULL` in 8.0.

```python
from textual.app import App, ComposeResult
from textual.widgets import Header, Footer, Button, Label

class HelloApp(App):
    CSS_PATH = "hello.tcss"
    BINDINGS = [
        ("q", "quit", "Quit"),
        ("d", "toggle_dark", "Toggle dark mode"),
    ]

    def compose(self) -> ComposeResult:
        yield Header()
        yield Label("Hello, world!", id="greeting")
        yield Button("Click me", id="go", variant="success")
        yield Footer()

    def on_button_pressed(self, event: Button.Pressed) -> None:
        self.query_one("#greeting", Label).update("Button pressed!")

    def action_toggle_dark(self) -> None:
        self.theme = "textual-light" if self.theme == "textual-dark" else "textual-dark"

if __name__ == "__main__":
    HelloApp().run()
```

`compose()` defines the widget tree once on mount.
`BINDINGS` supplies keys and automatic Footer entries.
`action_*` methods handle binding actions. `on_*` methods handle child events.

## Lifecycle and terminal handoff

Use App actions and messages, not widget-level raw-mode changes.
`App.run()` / `run_async()` cleanup restores terminal mode through the driver.

| Boundary | Textual 8 contract |
| --- | --- |
| Normal exit | Call `self.exit(result, return_code=...)`. The lifecycle stops the driver in `finally`. |
| Process status | `return_code` is metadata. After `app.run()`, call `sys.exit(app.return_code)` to expose it. |
| SIGTERM | Desktop drivers have no general SIGTERM-to-`App.exit` contract. Use platform event-loop integration to schedule `self.exit(...)` when required. |
| Interactive child | Run an argv-based subprocess inside `with self.suspend():`. Input/output pauses, the child gets restored terminal modes, and Textual resumes with a refresh. |
| Foreground suspend | `suspend_process` sends SIGTSTP and resumes application mode on Unix. It does nothing on Windows and Textual Web. |

Do not restore terminal state from a low-level signal handler. SIGKILL permits no cleanup.
After a child or resume, reload externally mutable data. A layout refresh does not reread it.
Handle `SuspendNotSupported` with a non-terminal alternative. Textual Web cannot give a local terminal to a child.
[App.suspend()](https://textual.textualize.io/guide/app/#suspending-the-application) is a context manager for temporary handoff.
`suspend_process` is Unix job control. Neither replaces final exit.

## Widgets

| Category | Widgets |
| --- | --- |
| Display | `Label`, `Static`, `Digits`, `Pretty`, `Markdown`, `MarkdownViewer`, `RichLog`, `Log`, `Sparkline`, `Rule`, `Placeholder` |
| Input | `Input`, `MaskedInput`, `TextArea`, `Button`, `Switch`, `Checkbox`, `RadioButton`, `RadioSet`, `Select`, `OptionList` |
| Structure | `Header`, `Footer`, `LoadingIndicator`, `ProgressBar`, `TabbedContent`, `TabPane`, `Tabs`, `Collapsible` |
| Data | `DataTable`, `Tree`, `DirectoryTree`, `ListView` + `ListItem` |

`TextArea` supports multiple lines and optional tree-sitter highlighting.
Since Textual 5.0, the `syntax` extras require Python 3.10+.

Prefer `DataTable` for tables. It supports thousands of virtualised rows, sorting, and cell/row/column cursors.
Use `add_columns`, `add_rows`, `zebra_stripes`, and `on_data_table_row_selected`.
Cursor types are `cell`, `row`, `column`, and `none`.

## Layout and TCSS

```css
Screen {
    layout: vertical;
}

#sidebar {
    width: 30;
    border: tall $accent;
}

#main {
    width: 1fr;
    layout: vertical;
}

DataTable {
    height: 1fr;
}

.error {
    color: $error;
    text-style: bold;
}
```

| Concept | API |
| --- | --- |
| Layout | `vertical`, `horizontal`, `grid` |
| Containers | `Vertical`, `Horizontal`, `Grid`, `VerticalScroll`, `Center`, `Middle` |
| Size | Cells (`width: 30`), percent (`width: 50%`), `auto`, fractions (`width: 1fr`) |
| Grid | `grid-size: 3 4`, `grid-columns`, `grid-rows`, `grid-gutter`, `column-span`, `row-span` |
| Dock | `dock` accepts `top`, `right`, `bottom`, or `left` for Header/Footer and fixed edges |
| Overflow | `overflow-x: auto` for scrollbars |
| Selectors | Type, `#dialog`, `.error`, `:focus`, `:hover`, `:disabled`, `:dark`, `:light` |
| Theme variables | `$primary`, `$panel`, `$text`, `$accent`, `$error` |

Type selectors match subclasses, unlike web CSS. Nesting is supported.
Use `textual run --dev` to reload `.tcss` changes live.

## Events and messages

Use naming conventions for simple handlers.

```python
def on_button_pressed(self, event: Button.Pressed) -> None:
    if event.button.id == "submit":
        ...
```

For many widgets of one type, prefer `@on` with a CSS selector.

```python
from textual import on

@on(Button.Pressed, "#submit")
def handle_submit(self) -> None:
    ...

@on(Button.Pressed, ".danger")
def handle_danger(self, event: Button.Pressed) -> None:
    ...
```

Messages propagate up the tree. `event.stop()` stops propagation.
Parents set child attributes. Children notify parents through messages.

## Reactive state

```python
from textual.reactive import reactive

class Counter(Widget):
    count: reactive[int] = reactive(0)

    def watch_count(self, old: int, new: int) -> None:
        # called automatically when count changes
        self.refresh()

    def validate_count(self, value: int) -> int:
        # called before assignment; can clamp or transform
        return max(0, min(10, value))

    def compute_display(self) -> str:
        # derived attribute; auto-updates when count changes
        return f"Count: {self.count}"

    def render(self) -> str:
        return self.display
```

Assignment order is validate → assign → compute → watch.

| Modifier | Effect |
| --- | --- |
| `init=False` | Skip the watcher on initial assignment |
| `always_update=True` | Update even if the value is unchanged |
| `layout=True` | Recalculate layout, not only rendering |
| `bindings=True` | Re-evaluate `BINDINGS` |
| `recompose=True` | Re-run `compose()` and rebuild children |

## Async and workers

Handlers can use `async def`. `@work` makes methods background workers.

```python
import httpx
from textual import work

@work(exclusive=True)
async def fetch_data(self, url: str) -> None:
    async with httpx.AsyncClient() as client:
        response = await client.get(url)
        response.raise_for_status()
    self.query_one("#result").update(response.text)

# For blocking code:
@work(thread=True)
def compute_heavy(self) -> None:
    result = expensive_sync_thing()
    self.call_from_thread(self.update_result, result)
```

From a thread, use `call_from_thread(fn, *args)` to change the UI. An asyncio task does not need that transfer.
Use `set_interval(secs, callable)` for periodic UI updates.

## Modal screens

```python
from textual.screen import ModalScreen

class ConfirmDialog(ModalScreen[bool]):
    def compose(self) -> ComposeResult:
        yield Label("Are you sure?")
        yield Button("Yes", id="yes", variant="error")
        yield Button("No", id="no")

    @on(Button.Pressed, "#yes")
    def confirm(self) -> None:
        self.dismiss(True)

    @on(Button.Pressed, "#no")
    def cancel(self) -> None:
        self.dismiss(False)

# In your app — must run in a worker:
@work
async def action_delete(self) -> None:
    if await self.push_screen_wait(ConfirmDialog()):
        await self.do_delete()
```

`push_screen_wait` returns the result from `dismiss(value)`.
Call it inside a worker so that the wait does not block the app.
A plain handler raises `NoActiveWorker`.

## Testing

Use Pilot with `app.run_test()` for input and widget assertions.

```python
async def test_button_click():
    app = HelloApp()
    async with app.run_test(size=(80, 24)) as pilot:
        await pilot.press("tab", "enter")
        await pilot.click("#submit")
        await pilot.pause()
        assert app.query_one("#result", Static).content == "Done"
```

Use `pytest-textual-snapshot` for SVG snapshots.

```python
def test_homepage(snap_compare):
    assert snap_compare("path/to/app.py", press=["tab", "enter", "a"])
```

Snapshots live under `__snapshots__/`. Failures produce HTML difference pages.

- `run_test()` is headless, defaults to `size=(80, 24)`, and disables notifications and tooltips.
- For toast or tooltip assertions, pass `notifications=True` or `tooltips=True`.
- There is no `App.messages` capture API.
- Record messages with a test App handler, such as `@on(SomeWidget.Changed)`, or the `run_test` parameter `message_hook`.
- Before message assertions, call `await pilot.pause()` because propagation is asynchronous.
- For forms, configure `Input` with `validators=[...]` and `validate_on`.
- Drive input with Pilot and inspect `Input.Submitted`/`Changed` messages through `event.validation_result`.
- Assert `is_valid`, `failure_descriptions`, `input.is_valid`, or the `-invalid`/`-valid` CSS classes.

## Debugging

The CLI needs the separate `textual-dev` package, installed with `pip install textual-dev`.
Installing `textual` alone does not supply the `textual` command.
Do not write directly to stdout inside an active Textual app.

| Tool | Purpose |
| --- | --- |
| `textual console` | Separate process for logs and routed `print()`/`self.log(...)` output |
| `textual run --dev myapp.py` | Route logs to the console and reload TCSS |
| `textual keys` | Inspect actual key events |
| `textual diagnose` | Report Python, terminal, and Textual versions, not performance |

There is no built-in FPS/frame-timing overlay.
For profiling without code changes, use `py-spy record -o profile.svg --pid <pid>`.
If expected work is absent, add `--idle`. py-spy otherwise omits idle threads while asyncio waits.

`DataTable.add_rows()` loops over `add_row()`. It does not batch bookkeeping costs.
Replacing a manual loop with `add_rows()` does not fix slow bulk insertion.
Synchronous work inside `async def` still blocks the UI when it does not yield.
Move that work to `@work(thread=True)`, not only `@work`.

## Development tools

`textual serve app.py` exposes the same app over HTTP/WebSocket in a browser.
The code can run in a terminal, over SSH, or in a browser with browser screen-reader support.
Prefer self-hosted `textual serve` over `textual-web`, whose hosted future was uncertain after Textualize closed.

## Textual apps

| App | Purpose |
| --- | --- |
| Toad | Agentic coding UI with ACP for Claude Code, Gemini CLI, and others |
| Posting | HTTP client |
| Harlequin | SQL IDE |
| Toolong | Multi-GB log viewer |
| Memray | Bloomberg memory profiler |
| Dolphie | MySQL/MariaDB monitor |
| elia | LLM chat |
| frogmouth | Markdown browser |
| Trogon | Generated TUI for Click/Typer |

## Pitfalls

1. Reactive assignments in `__init__` can trigger watchers before mount and cause `NoMatches` on DOM queries.
2. Initialise in `on_mount`, or use `set_reactive(MyClass.attr, value)` to skip watchers.
3. To rebuild children, use `reactive(..., recompose=True)` or `await self.remove_children()` followed by `await self.mount(...)`.
4. Use `self.log(...)` and `textual console`, not direct screen output.
5. For exact targeting, use class selectors. `Button { ... }` also matches `MyButton(Button)`.
6. Inside Textual, use its `ProgressBar`, not Rich `Live`/`Progress`, which compete for the screen.
7. From synchronous background threads, use `self.call_from_thread`, not direct attribute assignments.
8. Set `can_focus = True` on custom widgets that need key events.

## Rich

`Textualize/rich` formats output in immediate mode without input handling or an event loop.
Textual uses Rich internally.

```python
from rich.console import Console
from rich.table import Table
from rich.panel import Panel
from rich.progress import track

console = Console()

# Markup syntax (like BBCode)
console.print("[bold red]Error:[/] file not found")

# Tables
table = Table(title="Users")
table.add_column("Name", style="cyan")
table.add_column("Email", style="green")
table.add_row("Alice", "alice@example.com")
console.print(table)

# Panels
console.print(Panel.fit("Hello, world!", title="Greeting", border_style="blue"))

# Progress
for item in track(items, description="Processing..."):
    do_work(item)
```

Components include `Console`, markup, `Table`, `Panel`, `Columns`, `Tree`, Pygments-backed `Syntax`, `Markdown`, multi-task `Progress`, `Live`, and `RichHandler`.
Use `from rich.traceback import install; install()` for tracebacks with highlighted source context.
There is no `rich.install()`. `rich.pretty.install()` formats REPL results only.

Prefer Rich + Click/Typer for print-and-exit tools and Textual for interactive sessions.
pip vendors Rich. Textual, Harlequin, Posting, and many Typer tools use it.
Poetry uses cleo. Sphinx does not depend on Rich.

## prompt_toolkit

Use prompt-style input for completion, history, and highlighting.

```python
from prompt_toolkit import prompt
from prompt_toolkit.completion import WordCompleter

cmd_completer = WordCompleter(["help", "list", "quit"])
text = prompt("> ", completer=cmd_completer)
```

The full-screen `Application` combines HSplit/VSplit/FloatContainer, UIControl, and KeyBindings.
Users include IPython, ptpython, mycli, pgcli, litecli, pyvim, and pymux.
Prefer prompt_toolkit when command typing, history, completion, and multi-line editing are the main interactions.
For one-off questions, questionary supplies a smaller API on prompt_toolkit.

```python
import questionary

answer = questionary.text("What's your name?").ask()
choice = questionary.select(
    "Pick a color",
    choices=["red", "green", "blue"],
).ask()
```

## Other libraries

| Library | Use and limit |
| --- | --- |
| Urwid | Mature retained TUI library, active again with v3.0.x in 2025 and v4.0 in 2026. Prefer Textual for new work. |
| Blessed | Cross-platform curses wrapper through `jinxed`, for custom games or animations. Not the default. |
| curses | Unix-only standard library, appropriate for strict zero-dependency needs. |
| InquirerPy | Inquirer.js-style alternative to questionary. |
| tqdm | Fast progress for ML/data scripts. Use `with logging_redirect_tqdm():` for mixed logs. |
| alive-progress | More animation, with slightly higher cost than tqdm. |
| asciimatics | Animation and form-oriented TUI library. |

## Argument parsing

Use Typer for new projects with type hints. It derives validation, help, and completion through Click.
Use standard-library argparse when no dependency is required.
Click supplies decorator-based parsing without a type-hint requirement.

```python
import click

@click.command()
@click.option("--name", default="world", help="Who to greet")
@click.option("--count", default=1, type=int)
def hello(name: str, count: int) -> None:
    """Say hello."""
    for _ in range(count):
        click.echo(f"Hello, {name}!")
```

```python
import typer

app = typer.Typer()

@app.command()
def hello(name: str = "world", count: int = 1) -> None:
    """Say hello."""
    for _ in range(count):
        typer.echo(f"Hello, {name}!")

if __name__ == "__main__":
    app()
```

Trogon generates a Textual interface from Click or Typer.
Its integration begins with `from trogon import Trogon`.
