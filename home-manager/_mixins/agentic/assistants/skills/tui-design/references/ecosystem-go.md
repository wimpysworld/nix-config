# Go ecosystem

Prefer Bubble Tea, Lipgloss, Bubbles, and Cobra for a new Go TUI.
Use tview for retained widgets or gocui for an existing lazygit-style architecture.
All reference paths are relative to the skill root.

## Contents

- [Quick recommendation](#quick-recommendation)
- [Bubble Tea](#bubble-tea)
- [Lifecycle and terminal handoff](#lifecycle-and-terminal-handoff)
- [Lipgloss](#lipgloss)
- [Bubbles](#bubbles)
- [Huh](#huh)
- [Other Charm libraries](#other-charm-libraries)
- [tview](#tview)
- [gocui](#gocui)
- [Lower-level rendering](#lower-level-rendering)
- [CLI structure](#cli-structure)
- [Output formatting](#output-formatting)
- [Testing](#testing)
- [Debugging](#debugging)
- [Apps to study](#apps-to-study)
- [Cross-platform notes](#cross-platform-notes)

## Quick recommendation

| Need | Use |
| --- | --- |
| New TUI with MVU architecture | Bubble Tea + Lipgloss + Bubbles |
| Persistent panes and contextual keys | `awesome-gocui/gocui` or `jesseduffield/gocui` |
| Tables, trees, and forms with callbacks | tview |
| One-shot forms | Huh, or gum for shell scripts |
| Markdown output | Glamour |
| Non-TUI output | pterm |
| Subcommands | Cobra or urfave/cli |
| TUI over SSH | Wish |

`gh` uses Cobra, Lipgloss, and Glamour without Bubble Tea. It is a CLI, not a full-screen TUI.

## Bubble Tea

`charmbracelet/bubbletea` uses the Elm Architecture: `Model → Update(Msg) → (Model, Cmd) → View() tea.View`.
Bubble Tea v2.0.0 became stable in February 2026 after the 2025 beta/RC series.
The pinned upstream guidance describes the v2.0.x series.

- The v2 Cursed Renderer uses ncurses-style frame differences.
- Bubble Tea owns terminal I/O. Lipgloss v2 is pure.
- Kitty keyboard support distinguishes `shift+enter`, `ctrl+i` from `tab`, and `super+space`.
- Keep legacy keyboard fallbacks.
- Use `charm.land/bubbletea/v2`, not the old GitHub import path.
- Keep bubbletea, bubbles, lipgloss, huh, and wish on the same major through `charm.land/<name>/v2`.

For new work, use v2. A working v1 app does not require immediate migration.
Migration changes `View()` from `string` to `tea.View`, key events to `tea.KeyPressMsg`, and screen/mouse options to view fields.

| Part | Contract |
| --- | --- |
| Model | One struct holds state. |
| Init | Returns the initial Cmd or `nil`. |
| Update | Changes state and returns the model and Cmd. |
| View | Returns the complete frame and declarations for screen, mouse, and cursor. |
| Cmd | Performs side effects as `func() tea.Msg`. The returned message enters Update. |

```go
type model struct {
    count int
}

func (m model) Init() tea.Cmd { return nil }

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    switch msg := msg.(type) {
    case tea.KeyPressMsg:  // KeyMsg is an interface in v2; msg.Code/msg.Text replace Type/Runes
        switch msg.String() {
        case "q", "ctrl+c":
            return m, tea.Quit
        case "+", "right", "l":
            m.count++
        case "-", "left", "h":
            m.count--
        }
    }
    return m, nil
}

func (m model) View() tea.View {
    v := tea.NewView(fmt.Sprintf("Count: %d\n\nq quit · ←/→ change", m.count))
    v.AltScreen = true  // don't pollute scrollback; required for full-screen TUIs
    return v
}

func main() {
    p := tea.NewProgram(model{})
    if _, err := p.Run(); err != nil {
        log.Fatal(err)
    }
}
```

`Program.Run()` owns normal cleanup and default panic recovery.
Do not add `defer p.RestoreTerminal()` as final cleanup.
`RestoreTerminal` resumes Bubble Tea modes after `ReleaseTerminal`. It does not restore the user's shell.
Add outer cleanup only when deliberately bypassing or disabling managed cleanup.

## Lifecycle and terminal handoff

Keep resumable work inside `Program.Run()`.

| Boundary | Bubble Tea v2 contract |
| --- | --- |
| Normal exit | Return `tea.Quit`. `Run()` restores the terminal on normal, error, and recovered-panic paths. |
| Interrupt | Raw Ctrl+C arrives as `tea.KeyPressMsg`. Return `tea.Interrupt` for `tea.ErrInterrupted`, or `tea.Quit` for an intentional zero-status exit. |
| External signal | The default handler converts SIGINT/SIGTERM into managed termination. Do not call `os.Exit` from `Update`. |
| Interactive child | Return `tea.ExecProcess(exec.Command(...), callback)`. It releases the terminal, attaches child streams, waits, restores, repaints, and reports errors. |
| Suspend | Return `tea.Suspend`. On Unix resume, handle `tea.ResumeMsg` and reload externally mutable data. Windows does not support this path. |

If child execution and restoration both fail, `ExecProcess` reports the child error.
After the callback message, reload data that the child can change. Repainting alone uses the old model.
Use an ordinary `tea.Cmd` for non-interactive I/O.
Prefer [ExecProcess](https://github.com/charmbracelet/bubbletea/blob/v2.0.8/exec.go) over manual `ReleaseTerminal()` / `RestoreTerminal()`.
The [tagged lifecycle source](https://github.com/charmbracelet/bubbletea/blob/v2.0.8/tea.go) defines signal and restoration behaviour.

V2 removed `tea.WithAltScreen()`, `tea.WithMouseCellMotion()`, and `tea.WithMouseAllMotion()`.
Set `v.AltScreen = true` and `v.MouseMode = tea.MouseModeCellMotion` or `tea.MouseModeAllMotion` in `View()`.
Use the all-motion mode for hover.

`tea.WithInput(reader)` and `tea.WithOutput(writer)` support tests and Wish.
`tea.WithColorProfile(p)` fixes the colour profile for golden tests.

```go
func fetchData() tea.Msg {
    data, err := http.Get(...)
    if err != nil { return errMsg{err} }
    return dataMsg{data}
}

// In Update, when you want to fetch:
return m, fetchData
```

The runtime executes Cmds in goroutines and sends their messages to `Update`.
Never block `Update` on I/O.
Use `tea.Batch(cmds...)` for parallel commands and `tea.Sequence(cmds...)` for ordered commands.

- Use `lipgloss.Width()`, not `len(string)`, for display width.
- V2 width handling uses `charmbracelet/x/ansi` with uniseg grapheme clusters for CJK and emoji.
- From goroutines, use `program.Send(msg)`, not direct `View()` calls.
- Use `tea.LogToFile("debug.log", "DEBUG")`, not `fmt.Println`, while the UI owns the screen.
- Do not write stdout from Cobra `PreRun` before entering the alternate screen.

## Lipgloss

`charmbracelet/lipgloss` provides immutable `Style` values that render ANSI strings. It also works without Bubble Tea.

```go
var titleStyle = lipgloss.NewStyle().
    Bold(true).
    Foreground(lipgloss.Color("#FAFAFA")).
    Background(lipgloss.Color("#7D56F4")).
    Padding(0, 1).
    BorderStyle(lipgloss.RoundedBorder()).
    BorderForeground(lipgloss.Color("63"))

fmt.Println(titleStyle.Render("Hello, world"))
```

| Helper | Purpose |
| --- | --- |
| `lipgloss.JoinHorizontal(lipgloss.Top, left, right)` | Side-by-side content |
| `lipgloss.JoinVertical(lipgloss.Left, top, middle, bottom)` | Stacked content |
| `lipgloss.Place(width, height, hPos, vPos, content)` | Position content in an area |
| `lipgloss.Width(s)` / `lipgloss.Height(s)` | Measure rendered output with ANSI and rune-width handling |

Lipgloss has no flexbox. Calculate widths from the cached `tea.WindowSizeMsg`.

```go
case tea.WindowSizeMsg:
    m.width, m.height = msg.Width, msg.Height
    m.leftPaneWidth = msg.Width / 3
    m.rightPaneWidth = msg.Width - m.leftPaneWidth
```

Lipgloss v2 does not touch the terminal. Query the background once and choose variants in the app.

```go
hasDark := lipgloss.HasDarkBackground(os.Stdin, os.Stdout)
lightDark := lipgloss.LightDark(hasDark)
fg := lightDark(lipgloss.Color("#236"), lipgloss.Color("#cef"))
```

Prefer `LightDark` for new code. `AdaptiveColor` remains in `charm.land/lipgloss/v2/compat` for migration.

| Package | Content |
| --- | --- |
| `lipgloss/table` | Styled tables, borders, and column alignment |
| `lipgloss/list` | Bullet, numbered, and tree lists with custom enumerators |
| `lipgloss/tree` | Hierarchical trees with custom indenters |

V2 removed `SetColorProfile`.
`lipgloss.Print`/`Println`/`Sprint` use `colorprofile` to downsample at write time.
For Bubble Tea golden tests, use `tea.WithColorProfile(colorprofile.Ascii)`.

## Bubbles

`charmbracelet/bubbles` provides components that receive forwarded messages through embedded models.

| Component | Purpose |
| --- | --- |
| `textinput` | Single-line input, placeholder, suggestions, validation |
| `textarea` | Multi-line input with line numbers |
| `list` | Virtualised list, filtering, pagination, custom row delegate |
| `table` | Virtualised table, selection, sorting |
| `viewport` | Scrollable content |
| `spinner` | Braille/Meter/MiniDot/Dot/Line/Pulse/Points/Globe/Moon styles |
| `progress` | Gradient progress bar with percent |
| `paginator` | Page indicators |
| `filepicker` | Filesystem browser |
| `help` | Footer hints from `key.KeyMap` |
| `key` | Declarative bindings |
| `cursor`, `stopwatch`, `timer` | Supporting utilities |

```go
type model struct {
    list list.Model
    keys keyMap
    help help.Model
}

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    var cmd tea.Cmd
    m.list, cmd = m.list.Update(msg)  // forward to child
    return m, cmd
}

func (m model) View() tea.View {
    // Bubbles still return strings; the parent wraps them in a tea.View.
    return tea.NewView(m.list.View() + "\n" + m.help.View(m.keys))
}
```

Define bindings once and derive footer hints with `help`.

```go
type keyMap struct {
    Up   key.Binding
    Down key.Binding
    Quit key.Binding
}

var keys = keyMap{
    Up:   key.NewBinding(key.WithKeys("up", "k"), key.WithHelp("↑/k", "up")),
    Down: key.NewBinding(key.WithKeys("down", "j"), key.WithHelp("↓/j", "down")),
    Quit: key.NewBinding(key.WithKeys("q", "ctrl+c"), key.WithHelp("q", "quit")),
}

// In Update (tea.KeyMsg is an interface in v2 that also matches releases; switch on presses):
case tea.KeyPressMsg:
    switch {
    case key.Matches(msg, keys.Quit):
        return m, tea.Quit
    case key.Matches(msg, keys.Up):
        // ...
    }
```

## Huh

Huh supports one-shot forms, multi-step wizards, and embedded form panes.
Huh v2, `charm.land/huh/v2`, became available in March 2026 and uses Bubble Tea v2.
Themes take an `isDark` bool, for example `huh.ThemeCharm(isDark)`, instead of detecting it.

```go
form := huh.NewForm(
    huh.NewGroup(
        huh.NewSelect[string]().
            Title("Choose your country").
            Options(huh.NewOptions("USA", "Germany", "Japan")...).
            Value(&country),
        huh.NewInput().
            Title("What's your name?").
            Value(&name).
            Validate(func(s string) error {
                if len(s) == 0 { return errors.New("required") }
                return nil
            }),
        huh.NewConfirm().
            Title("Submit?").
            Value(&confirm),
    ),
)
err := form.Run()
```

Fields: `NewInput`, `NewText`, `NewSelect[T]`, `NewMultiSelect[T]`, `NewConfirm`, `NewFilePicker`, and display-only `NewNote`.
`NewText` supports multiple lines.

- Use `form.WithAccessible(true)` for linear prompts without an alternate screen, including screen readers and limited terminals.
- For full-screen v2 forms, use `form.WithViewHook(func(v tea.View) tea.View { v.AltScreen = true; return v })`.
- For embedding, forward messages with `m.form, cmd = m.form.Update(msg)`.

## Other Charm libraries

| Library | Purpose |
| --- | --- |
| Glamour (`charmbracelet/glamour`) | Markdown-to-ANSI output with JSON stylesheets. Used by `gh` and `glow`. |
| Wish (`charmbracelet/wish`, `charm.land/wish/v2`) | SSH server with middleware for Bubble Tea apps. |
| Soft Serve | Git server with a Wish/Bubble Tea interface. |
| gum | Shell wrappers: `gum choose`, `gum input`, `gum confirm`, `gum spin`. |
| VHS | Terminal recordings from `.tape` files to GIFs. |

For Wish, use `bubbletea.MakeOptions(sess)` or the `bubbletea.Middleware` handler.
Input, output, and colour detection must use the client's PTY, not the server's terminal.
V2 removed `MakeRenderer` because Lipgloss no longer owns terminal I/O.

## tview

`rivo/tview` is a retained-mode callback framework on `gdamore/tcell`. k9s uses it.

Widgets include `Box`, `TextView`, `TextArea`, `InputField`, `Table`, `TreeView`, `List`, `Form`, `Image`, `Modal`, `Pages`, `Flex`, `Grid`, `Frame`, `DropDown`, `Button`, and `Checkbox`.
Use `Flex` for one dimension, `Grid` for two dimensions, and `Pages` for modal or replacement views.

```go
app := tview.NewApplication()
list := tview.NewList().
    AddItem("First", "First item", 'a', nil).
    AddItem("Quit", "Quit app", 'q', func() { app.Stop() })
if err := app.SetRoot(list, true).Run(); err != nil {
    panic(err)
}
```

From a goroutine, change primitives through `app.QueueUpdate(func)` or `app.QueueUpdateDraw(func)`.
A goroutine can call `app.Draw()` safely, but that schedules a repaint without synchronising data.
Inside a main-loop event handler, do not call `Draw()`, `QueueUpdate()`, or `QueueUpdateDraw()`.
Those calls deadlock, including from key handlers or `SetSelectedFunc`.

Choose tview for many concurrent widgets, callback-oriented teams, or existing tcell code.
Bubble Tea needs manual layout but suits complex state. tview supplies more widgets with less code.

## gocui

`awesome-gocui/gocui` uses views as buffers. Each `View` implements `io.Writer`.
A Manager calculates views on every redraw.
Each view has a name, position, buffer, and bindings. Calculate coordinates from `g.Size()`.

```go
g, _ := gocui.NewGui(gocui.OutputNormal, true)
defer g.Close()

g.SetManagerFunc(func(g *gocui.Gui) error {
    maxX, maxY := g.Size()
    if v, err := g.SetView("hello", maxX/2-7, maxY/2, maxX/2+7, maxY/2+2, 0); err != nil {
        if !errors.Is(err, gocui.ErrUnknownView) { return err }
        fmt.Fprintln(v, "Hello, World!")
    }
    return nil
})

g.SetKeybinding("", 'q', gocui.ModNone, func(g *gocui.Gui, v *gocui.View) error {
    return gocui.ErrQuit
})

g.MainLoop()
```

Choose gocui for persistent panes, numeric pane selection, and contextual single-letter actions like lazygit/lazydocker.
`jesseduffield/gocui`, used by lazygit, adds features beyond `awesome-gocui`.
For other new apps, prefer Bubble Tea.

## Lower-level rendering

`tcell` is a cross-platform terminfo-based replacement for termbox-go with mouse and SGR support.
Use it directly for a custom framework, renderer, or embedded requirement.
Otherwise, prefer Bubble Tea or tview.
`charmbracelet/ultraviolet` is the standalone engine below Bubble Tea v2, at a similar level to tcell.

## CLI structure

Cobra (`spf13/cobra`) supplies subcommands for kubectl, gh, hugo, helm, and docker.

```go
var rootCmd = &cobra.Command{
    Use:   "myapp",
    Short: "A short description",
}

var listCmd = &cobra.Command{
    Use:   "list",
    Short: "List items",
    Run:   func(cmd *cobra.Command, args []string) { /* ... */ },
}

func init() {
    rootCmd.AddCommand(listCmd)
}
```

Run `tea.NewProgram(...).Run()` inside Cobra's `Run`.
For piped input, test `isatty.IsTerminal(os.Stdin.Fd())` and select non-interactive behaviour where appropriate.
Since Cobra v1.2, root commands receive a `completion` subcommand, hidden when no other subcommands exist.
Do not create a replacement that hides it.
Use `myapp completion bash|zsh|fish|powershell` and `rootCmd.CompletionOptions` for customisation or disablement.
`cobra-cli completion ...` completes the generator, not your app.

Fang (`charmbracelet/fang`) adds styled help/errors, automatic `--version`, and man pages to Cobra.
`github.com/urfave/cli/v3` is a simpler alternative, used by syncthing. V3 became stable in 2025, with v2 in maintenance.
For one-shot parsing, the standard `flag` package is sufficient.

## Output formatting

| Library | Use |
| --- | --- |
| lipgloss | Standalone `fmt.Println(style.Render(...))` |
| pterm | Colour, tables, spinners, progress, charts, prompts |
| fatih/color | ANSI wrappers such as `color.Red("hello")` and `color.New(color.FgYellow, color.Bold).Println(...)` |

## Testing

Put most tests on update logic and rendered output.
Charm's crush uses more than 200 test files without teatest, with literal events and `github.com/charmbracelet/x/exp/golden`.

```go
func TestQuitKey(t *testing.T) {
    m := newModel()
    updated, cmd := m.Update(tea.KeyPressMsg{Code: 'q', Text: "q"}) // v2 rune key
    m = updated.(model)
    if cmd == nil { t.Fatal("expected quit cmd") }
}
```

V2 rune literals use `tea.KeyPressMsg{Code: 'a', Text: "a"}`.
Special keys use `tea.KeyPressMsg{Code: tea.KeyEnter}`. Modifiers use `Mod: tea.ModCtrl`.
Call a returned Cmd and assert its message, such as `tea.QuitMsg`.
`tea.BatchMsg` is an exported `[]Cmd` that tests can unpack and run.

For real program tests without a PTY, use `github.com/charmbracelet/x/exp/teatest/v2`.
The unversioned `x/exp/teatest` targets v1. Neither moved to charm.land.
Both remain pseudo-versioned experiments, with v2 recommended by maintainers for v2 apps.

```go
tm := teatest.NewTestModel(t, newModel(),
    teatest.WithInitialTermSize(80, 24), // default is 80×24 — pin it anyway
    teatest.WithProgramOptions(tea.WithColorProfile(colorprofile.Ascii)), // v2 only
)
teatest.WaitFor(t, tm.Output(), func(b []byte) bool {
    return bytes.Contains(b, []byte("ready"))
}, teatest.WithDuration(5*time.Second)) // defaults (1s timeout, 50ms poll) are tight for CI
tm.Type("hello")                        // v2: emits one KeyPressMsg per rune
tm.Send(tea.KeyPressMsg{Code: tea.KeyEnter})
tm.WaitFinished(t, teatest.WithFinalTimeout(2*time.Second))
out, _ := io.ReadAll(tm.FinalOutput(t))
teatest.RequireEqualOutput(t, out) // golden file: testdata/<TestName>.golden
```

Always pass `WithFinalTimeout`. Without it, `FinalModel`, `FinalOutput`, and `WaitFinished` can wait forever.
Golden files store escaped text. Update them with `go test ./... -update`.
Pin size and colour profile. `TERM`, `COLORTERM`, and `NO_COLOR` otherwise change emitted escapes through `colorprofile.Writer`.
On v1, use `lipgloss.SetColorProfile(termenv.Ascii)` instead of the v2 option.
The upstream guidance notes a skipped Bubble Tea example caused by profile-dependent output.

For real-terminal visual tests, VHS supports `Output golden.ascii` in a tape.
It needs `ttyd` and `ffmpeg`. `charmbracelet/vhs-action` supports CI.
Teatest deliberately avoids PTYs. Keep PTY tests limited to integration risk.

## Debugging

Use file logs while Bubble Tea owns raw mode or the alternate screen.

```go
if len(os.Getenv("DEBUG")) > 0 {
    f, _ := tea.LogToFile("debug.log", "debug")
    defer f.Close()
}
```

Run `DEBUG=1 go run .` in one terminal and `tail -f debug.log` in another.
`log.Println` in Update or Cmds writes to that file.
`tea.LogToFileWith` supports a custom logger in v1 and v2.

For breakpoints, run `dlv debug --headless --api-version=2 --listen=127.0.0.1:43000 .`.
Connect from another terminal with `dlv connect 127.0.0.1:43000`.
This separates debugger I/O from TUI I/O.

For profiling, prefer standard `net/http/pprof` on loopback rather than file-based `pprof.StartCPUProfile`.
A background server avoids terminal I/O and SIGINT/flush conflicts. Crush uses this with an environment gate.

```go
import (
    "net/http"
    _ "net/http/pprof"
)
if os.Getenv("MYAPP_PROFILE") != "" {
    go func() { http.ListenAndServe("localhost:6060", nil) }()
}
```

From another terminal, run `go tool pprof -http=:8080 http://localhost:6060/debug/pprof/profile`.
Check repeated `lipgloss.Width()` work, string construction in `View()`, and unbatched list/table rendering.
[bubbles#810](https://github.com/charmbracelet/bubbles/issues/810) documents per-frame concatenation instead of `strings.Builder`.

## Apps to study

| App | Implementation and pattern |
| --- | --- |
| lazygit / lazydocker | gocui, persistent panes |
| k9s | tview, command mode and drill-down |
| gh | Cobra + Lipgloss, CLI design |
| Crush | Production Bubble Tea v2 coding agent |
| glow | Bubble Tea Markdown reader |
| soft serve | Wish + Bubble Tea Git server |
| circumflex | Bubble Tea Hacker News reader |
| gh dash | Bubble Tea GitHub dashboard |
| superfile | Bubble Tea file manager |
| wishlist | Wish SSH directory |

For similar tasks, point to the relevant open-source app.

## Cross-platform notes

Bubble Tea, tview, and gocui support Linux, macOS, and Windows terminals, including conhost and ConEmu.
Target Windows Terminal on Windows 10+ rather than assuming full ANSI support in older `cmd.exe`.
Do not require Ctrl+Z/SIGTSTP on Windows.
Test mouse behaviour on Windows when it is a target.
For SSH, use Wish's per-session capabilities and middleware for authentication, logging, and rate limits.
