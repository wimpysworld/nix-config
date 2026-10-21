# Using Guigui

Guigui is a GUI framework for Go on top of Ebitengine. Its design is inspired by immediate-mode GUIs, but it is not immediate-mode.
Widgets are **retained** Go structs that you own and keep across ticks.
The framework **reconstructs** their child tree and presentation when it runs `Build` again after a relevant state change.
Compose and SwiftUI run a view function again in the same way.
You keep the state in struct fields. The framework decides when to rebuild, lay out, and redraw.

Read this whole file before you write widget code. Most errors come from the lifecycle rules below.

> **Freshness.** Upstream verified this guidance against Guigui at commit `c1ffb301` (2026-07-10).
> Guigui is alpha, and its API can change. If this guidance disagrees with the source, **the source wins**.
> Trust the `*.go` files in the module root and the programs under `example/` over this file.
> Report drift to the user. Do not edit the installed skill.

## References

All reference paths in this skill are relative to the skill root. Load a reference when the task needs it.

| Need | Reference |
| --- | --- |
| `LinearLayout`, a shared `layout()` helper, built-in widgets, wrappers, text input edits, custom list item colours | `references/layout-and-widgets.md` |
| `Env`, event keys, `WidgetSlice`, adding only the items in view, resetting cached widget state | `references/env-events-and-lists.md` |
| A keyless widget with a stale `Draw`, auditing a widget for missing state key coverage | `references/repaint-audits.md` |

## The mental model

- A **widget** is a struct that embeds `guigui.DefaultWidget` and overrides the methods that it needs.
  `DefaultWidget` supplies no-op defaults for every method, so override only the methods that matter.
- A widget must work **from its zero value**. Declare children as plain (non-pointer) fields and refer to them as `&w.child`.
  Do not allocate them in a constructor. `var w Foo` must be usable immediately.
- The framework runs two separate cycles.
  - Each **tick** is one Ebitengine `Update`, at the app's ticks per second (TPS). The default is 60 per second.
    A tick first settles the tree. It can run **Build** (reconstruct the child tree), **Layout** (position the children), and the **`Handle*Input`** methods. Then it calls **Tick** exactly once.
  - A state change during input can cause another Build and Layout pass in the same tick before `Tick` runs.
  - Rely only on these guarantees: Build comes before Layout in a pass, input sees the current layout, and Tick runs once, after input handling.
    Do not assume a fixed count of Build or Layout passes in each tick.
  - Each **frame** is one Ebitengine `Draw`, at the display refresh rate, and it runs **Draw**.
    Ticks and frames are *not* one-to-one. There can be more or fewer frames than ticks. Put per-step logic in `Tick`, never in `Draw`.
- Never call the framework-driven methods of a widget yourself (`Build`, `Layout`, `Tick`, `Draw`, the `Handle*Input` methods, `Env`, and others).
  Set fields and register handlers, and the framework calls back.
  The one exception is **`Measure`**. A parent or composite widget calls the `Measure` of a child directly to size it. `LinearLayout` and the shared `layout()` helper do this.

## Minimal application

```go
package main

import (
	"image"
	"log"

	"github.com/guigui-gui/guigui"
	"github.com/guigui-gui/guigui/basicwidget"
)

type Root struct {
	guigui.DefaultWidget

	background basicwidget.Background
	hello      basicwidget.Text
}

func (r *Root) Build(context *guigui.Context, adder *guigui.ChildAdder) error {
	adder.AddWidget(&r.background)
	adder.AddWidget(&r.hello)

	r.hello.SetValue("Hello, Guigui")
	return nil
}

func (r *Root) Layout(context *guigui.Context, widgetBounds *guigui.WidgetBounds, layouter *guigui.ChildLayouter) {
	layouter.LayoutWidget(&r.background, widgetBounds.Bounds())
	layouter.LayoutWidget(&r.hello, widgetBounds.Bounds())
}

func main() {
	if err := guigui.Run(&Root{}, &guigui.RunOptions{
		Title:         "Example",
		WindowMinSize: image.Pt(480, 320),
	}); err != nil {
		log.Fatal(err)
	}
}
```

`guigui.Run(root, *RunOptions)` starts the app.
`RunOptions` holds `Title`, `WindowSize`, `WindowMinSize`, `WindowMaxSize`, `WindowFloating`, `AppScale`, and an optional `RunGameOptions` that goes to Ebitengine unchanged.

## The Widget interface

Embed `guigui.DefaultWidget`, then override the methods that you need.

| Method | Signature | Override when |
|---|---|---|
| `Build` | `Build(*Context, *ChildAdder) error` | Almost always. Declare and configure children. |
| `Layout` | `Layout(*Context, *WidgetBounds, *ChildLayouter)` | The widget has children to position, which is almost always. |
| `Measure` | `Measure(*Context, Constraints) image.Point` | The widget has an intrinsic preferred size (list rows, leaf widgets). |
| `HandlePointingInput` | `HandlePointingInput(*Context, *WidgetBounds) HandleInputResult` | Custom mouse or touch handling. |
| `HandleButtonInput` | `HandleButtonInput(*Context, *WidgetBounds) HandleInputResult` | Custom keyboard or gamepad handling. Delivery needs focus or receptiveness (see "Handling input directly"). |
| `Env` | `Env(*Context, EnvKey, *EnvSource) (any, bool)` | The widget provides shared values to descendants. |
| `WriteStateKey` | `WriteStateKey(*Context, *StateKeyWriter)` | A state change outside input or events must trigger a rebuild (see below). |
| `Tick` | `Tick(*Context, *WidgetBounds) error` | Per-tick updates (animation, timers). It runs at the app's TPS. |
| `Draw` | `Draw(*Context, *WidgetBounds, *ebiten.Image)` | Custom rendering. Most widgets compose children instead. |
| `CursorShape` | `CursorShape(*Context, *WidgetBounds) (ebiten.CursorShapeType, bool)` | The widget wants a cursor that is not the default. |

### Build and Layout: the most important rule

- **`Build` runs before the framework knows any bounds.**
  Use it to add children (`adder.AddWidget(&w.child)`) and to push the current state into them (`SetText`, `SetEnabled`, handler registration).
  `Build` runs again on every rebuild, so it must be **idempotent**.
  Write it as "configure my children from my current state", not "do this once".
- **The usual order in `Build` is add first, configure second.** Make all the `adder.AddWidget(...)` calls that you need. Then push state into the children with `Set*` and `On*`.
  Configuring a child that you did not add causes no harm.
  You do not need to put each setter behind the same condition as its `AddWidget`. Unconditional configuration is simple and idiomatic.
- **Add only the children that this rebuild uses.**
  Do not call `AddWidget` for a child that is not visible now, for example the contents of a closed popup, a collapsed panel, or a hidden tab.
  The framework does not lay out, draw, or send input to a widget that is not added. This costs less than adding the widget and hiding it.
  `popup` is the canonical example. It adds its background, shadow, and content only while it opens or is open, but it still runs their setters unconditionally after that.
- **`Layout` runs after `Build`, when the bounds are known.**
  Use it only to position children with `layouter.LayoutWidget(child, bounds)` or a layout helper.
  Do not read bounds in `Build`. Do not configure widget content in `Layout`.

`widgetBounds.Bounds()` gives the rectangle of **this** widget in `Layout`, input, `Tick`, and `Draw`.
A `WidgetBounds` describes only the widget that it goes to. No API gives the bounds of another widget.
When a parent must size or place a child relative to a sibling, do it through the layout (`LinearLayout` or `layouter`). Do not try to read the rectangle of the sibling.

`widgetBounds.VisibleBounds()` gives the part that remains after ancestor clipping.
Use `Bounds()` for layout coordinates, and use `VisibleBounds()` to cull custom drawing.
For ordinary cursor hit tests, use `widgetBounds.IsHitAtCursor()`. It includes clipping and occlusion by higher layers.
Use `VisibleBounds()` as geometry only for an additional custom-shape check or for a point that is not the cursor.
In `Draw`, `dst` is a clipped subimage that still uses screen coordinates.
Draw at `Bounds().Min` or at other screen-space coordinates, not at an assumed `(0, 0)` origin.

## State changes and when the screen updates

This is the second common source of errors. A tree or content change needs a rebuild. A paint-only change needs only a redraw.

Rebuilds occur when:

- an **input handler or event handler runs** (the framework assumes that the handler can change state),
- the **state key** of a widget changes (see `WriteStateKey`), or
- you call `guigui.RequestRebuild()` explicitly.

**A rebuild is always whole-tree, never scoped.** Each of these triggers runs `Build` again on *every* widget from the root. There is no rebuild for one widget or one subtree.
`RequestRebuild()` takes no argument. A changed state key also rebuilds the whole tree, not only the widget that owns the key.
So put a `WriteStateKey` on the widget that *owns* the state that changes by itself.
A **different** widget that renders from that state still runs its own `Build` again and shows the change. The key does not need to be on the widget that displays the state.

**A rebuild runs `Build` again. It does not repaint by itself.**
Repainted pixels come from state key changes (these repaint the region of the changed widget automatically), from differences in the tree or layout, or from an explicit `RequestRedraw`.
A bare `RequestRebuild()` adds no redraw region.
For a paint-only change that alters the appearance of a widget, but not its bounds or a state key, also call `guigui.RequestRedraw(widget)`.

So a counter that changes inside the `OnUp` of a button updates with no extra work.
But a field that changes **outside** a handler will *not* repaint unless you do one of the steps below. Examples are a change from `Tick`, a goroutine result that the main goroutine applies, or an ancestor that reacts to an external model.

1. **Implement `WriteStateKey`** to hash the state that must drive rebuilds.
   The framework hashes again after each build and rebuilds when the hash changes:

   ```go
   func (w *Foo) WriteStateKey(context *guigui.Context, s *guigui.StateKeyWriter) {
       s.WriteInt(w.count)
       s.WriteBool(w.open)
       s.WriteString(w.title)
   }
   ```

   `StateKeyWriter` has `WriteBool`, `WriteInt` and `WriteUint` (and sized variants), `WriteFloat32/64`, `WriteString`, `WriteWidget`, and raw `Write`.
   A widget that writes nothing opts out. This is the default.

2. **Call `guigui.RequestRebuild()`** at the mutation site when the key mechanism cannot observe the change because of its structure.
   The framework checks keys only for widgets that are in the tree now, so you need this call in these cases:

   - The owning widget can be **out of the tree** when the change occurs.
     The framework evaluates no key for a widget that the `Build` of its parent leaves out.
     A transition that must bring the widget back, for example reopening a closed popup, needs an explicit rebuild.
   - The change has **no owner widget**. For example, app-level code changes a shared model that no widget hashes.
     A key or generation counter on the root, or on the widget that owns the model, is usually the better fix.
   - The state is **too expensive to hash** at every checkpoint, and a cheap generation counter is not possible.

   `RequestRebuild` runs `Build` again but does not repaint by itself.
   When the appearance also changes in unchanged bounds, also call `guigui.RequestRedraw(widget)`.
   For a change that is only paint, do not rebuild. Call `RequestRedraw` alone.

`guigui.RequestRedraw(widget)` forces a repaint **without** a rebuild.
Use it only when the tree structure did not change, for example for an animation frame.

**To choose, prefer `WriteStateKey` in usual cases.** Paint-only state is the exception.
For state that changes outside `Build`, ask this question: does the change alter what `Build` or `Measure` produces?
If yes, put the state in `WriteStateKey`. Examples are a child that appears or disappears, or a size that animates. The rebuild that a key change triggers is the correct response.
If no, the widget only paints differently in unchanged bounds. Examples are hover or pressed tinting, an alpha fade, a caret blink, or a thumb that slides in the widget.
Keep that state **out** of the key, and call `RequestRedraw` at the mutation site.
A state key change rebuilds the whole tree. For a paint-only change, every `Build` runs again only to make the same tree, at whole-tree cost for each animation tick or hover change.

Caveat: paint-only state that only the `Build` of an ancestor sets is still correct in the key. An example is a flag that a parent pushes down on each build.
The post-build snapshot detects that path, and the widget repaints with no extra rebuild.
The rebuild cost applies only to state that changes during `Tick` or input handling.

A state key rebuilds only when its hashed bytes *change*.
A value that stays the same across ticks costs nothing in each tick, for example an `isPlaying` flag that stays `true` for the whole animation.
Use the two together. Drive the per-frame animation with `RequestRedraw` on each tick.
Let a `WriteStateKey` cause the one rebuild at the on or off transition, for example when the animation ends and a button must change from stop back to play.

For a large mutable model, hash a cheap monotonic generation counter in `WriteStateKey`. Do not serialise every collection.
Increment the generation for every change that affects the UI.
State that you leave out of the key on purpose still needs an explicit `RequestRebuild` at each mutation site.

The order of preference:

1. `WriteStateKey` by default.
2. `RequestRedraw` for paint-only state.
3. `RequestRebuild` only when the key mechanism cannot observe the change because of its structure.

A widget with its own `Draw` and no `WriteStateKey` has one more gap. It does not repaint values that the `Build` of a parent pushes into it.
Read `references/repaint-audits.md` for that failure and for the audit procedure.

## Context utilities

`*guigui.Context` (an argument to most methods) also has per-widget state setters. Call all of them from `Build`:

- `context.SetEnabled(w, bool)` / `IsEnabled(w)`
- `context.SetVisible(w, bool)` / `IsVisible(w)`
- `context.SetFocused(w, bool)` / `IsFocused(w)`
- `context.SetOpacity(w, float64)`

## Handling input directly

Override `HandlePointingInput` or `HandleButtonInput` and return a result:

```go
func (w *Foo) HandlePointingInput(context *guigui.Context, widgetBounds *guigui.WidgetBounds) guigui.HandleInputResult {
	if widgetBounds.IsHitAtCursor() && inpututil.IsMouseButtonJustReleased(ebiten.MouseButtonLeft) {
		// react...
		return guigui.HandleInputByWidget(w) // consume; ancestors won't see it
	}
	return guigui.HandleInputResult{} // not handled; let others try
}
```

The framework delivers pointer and button input in **post-order** (innermost or topmost widget first). A child can consume an event before its ancestors.
Return `guigui.HandleInputByWidget(w)` to consume the event.
Return `guigui.AbortHandlingInputByWidget(w)` to stop propagation without a claim on the event.
Return the zero `guigui.HandleInputResult{}` to pass the event on.
`widgetBounds.IsHitAtCursor()` reports whether this widget is the topmost widget under the cursor.

The framework does not deliver `HandleButtonInput` to every widget.
It runs only when the widget is focused, has a focused ancestor or descendant, or is button-input-receptive through `context.SetButtonInputReceptive(w, true)`.
Focus enables a whole path: the focused widget, its ancestors, and its descendants all receive button input.
Receptiveness applies only to the widget itself. It gives delivery to that one widget, not to its ancestors or descendants. The framework goes through the ancestors only to reach the receptive widget.
An override of `HandleButtonInput` on a widget that is never focused and never receptive does nothing, with no error.
Focus the widget (`context.SetFocused`) or make it receptive.

Rich content in a button or list item can take pointing input before the interactive parent.
If that content is decorative, call `context.SetPassthrough(content, true)` in `Build`.
The decorative subtree then receives no input, and the container handles the click.

A popup that looks modal does not isolate keyboard shortcuts automatically.
Make its content button-input-receptive, and handle the keys that it needs, such as Escape.
Return `AbortHandlingInputByWidget` for all other keys, so that input does not go to widgets or global shortcut handlers behind the popup.

## Checklist when adding a widget

1. Embed `guigui.DefaultWidget`. Keep children as plain fields. Make sure that the zero value is usable.
2. In `Build`, first add the children that this rebuild uses with `adder.AddWidget(&w.child)`. Skip children that are not visible, such as the contents of a closed popup.
   Then configure children from the current state, idempotently. Register `On…` handlers here. Configuring a child that you did not add is correct.
3. In `Layout`, position children with a `LinearLayout` (reuse the items slice) or `layouter.LayoutWidget`. Size in multiples of `UnitSize`.
4. Add `Measure` if the widget has an intrinsic size, especially for list rows. For a composite, share one `layout()` helper between `Layout` and `Measure`.
5. Read shared models through `context.Env`. Send events up with a generated `EventKey`, an `On…` setter, and `DispatchEvent`.
6. If a field can change outside input or event handlers, put it in `WriteStateKey` (preferred) or call `RequestRebuild` when you change it.
   If the change is paint-only (unchanged bounds and children), keep it out of the key and call `RequestRedraw` alone.
7. If the widget has its own `Draw`, put every field that `Draw` reads into `WriteStateKey`, even when only the `Build` of an ancestor sets those fields.
   The framework rebuilds a keyless widget but never repaints it (see `references/repaint-audits.md`).

## Verify your work

This skill is a primer. It does not list every widget method, and it can drift from an alpha API. Before you consider a change complete:

- **Look up real signatures. Do not guess.** When you need a `basicwidget` method (`SetText`, `OnUp`, or a `Set*` or `On*` method that you do not fully remember), search the package:
  `rg -n "func \\(.*Button\\)" basicwidget/`. The catalogue in this skill is not complete on purpose.
- **Copy from a working example.** These examples compile and show canonical usage. Adapt them instead of inventing code:
  `example/counter` (state and buttons), `example/todo` (Env, events, dynamic list), `example/gallery` (most widgets), and `example/biglist` (custom list item content).
- **Build and vet.** Run `go build ./...` and `go vet ./...`.
  Guigui code that misuses the lifecycle often still compiles. Also run the program, or the relevant `example/`, and confirm that it renders and reacts.
- **Prefer a headless run.** A headless run is the better default even when a display is available.
  It opens no window, never takes the keyboard focus, and the same script runs again identically.
  - A Guigui app is an `ebiten.Game`, because `guigui.Run` gives the root tree to `ebiten.RunGameWithOptions`.
    So the **`run-ebitengine-app-headless`** skill applies to it unchanged, if that skill is available.
  - That skill builds the app with `-tags ebitenginevmguest` and runs it as an `exp/vmhost` guest.
    It steps ticks, injects pointer and keyboard input, and reads rendered frames back as pixels or PNG files.
  - That skill is in the Ebitengine repository (`skills/run-ebitengine-app-headless/`), and it is not part of this import.
    If it is not installed, do not install it. Use another authorised method, or tell the user that the capability is not available.
  - Use it for screenshots, golden-image comparisons of a rendering change, and deterministic repros across many ticks.
  - Guigui details to script around (`doc.go` documents every environment variable):
    - Pin the values that the host platform otherwise selects, so that two runs are comparable:
      `GUIGUI_COLOR_MODE` (`light`/`dark`), `GUIGUI_KEY_BINDING_MODE` (`command`/`control-default`/`control-emacs`), and `GUIGUI_DEBUG=devicescale=1`.
    - Injected runes do **not** reach a text input. Text comes through `exp/textinput` IME sessions, not `ebiten.AppendInputChars`.
      Paste the text instead. `GUIGUI_DEBUG=emulateclipboard` together with `GUIGUI_DEBUG_CLIPBOARD_TEXT` gives the app an in-process clipboard.
    - The framework reads shortcut modifiers as the virtual `ebiten.KeyMeta`/`KeyControl`. These register only when you inject a physical key such as `KeyMetaLeft`.
    - `GUIGUI_DEBUG=showbuildlogs,showinputlogs` logs what rebuilt and which widget consumed the input. Use it when "nothing happens" with no other evidence.
- **Check the lifecycle, not only the compile.** If a change does not show, read "State changes and when the screen updates" again.
  A clean build with a stale screen is the signature of a missing rebuild trigger.
- **A reduced repro that passes is not proof that the real app works.**
  A widget in an isolated debug harness can render and behave correctly while the full application still fails.
  Popups, overlay layers, the surrounding shell, and real pointer-input timing are all different. Confirm a UI fix in the real app, not only in a harness.

## Common pitfalls

- **Reading bounds in `Build`.** Bounds are not known there. Move the read to `Layout`.
- **Configuring content in `Layout`.** Setters belong in `Build`. `Layout` only positions.
- **Registering handlers once or outside `Build`.** Each rebuild clears the handlers. Register them in `Build` every time.
- **Resetting the cached state of a widget in `Tick`.** Zeroing a child to drop stale state belongs in `Build`, which is the rebuild boundary.
  `Tick` runs after `Layout`, so a tree change there does not agree with the frame layout for one `Draw`.
  Never zero the struct of the application root (see `references/env-events-and-lists.md`).
- **Expecting a field write to repaint.** Only handler-driven or state-key-driven changes rebuild automatically.
  In other cases, call `RequestRebuild`, or only `RequestRedraw` if the change is paint-only.
- **A custom `Draw` on a widget with no `WriteStateKey`.** The fields that the `Build` of the parent gives to it arrive.
  But when the tree and all bounds stay the same, the framework never repaints the region. The value-only repaint compares key hashes, and a keyless widget always has the same hash.
  The stale region is intermittent, because any focus change repaints the whole screen (see `references/repaint-audits.md`).
- **Allocating a new items slice in every `Layout`.** Reuse it with `slices.Delete(s, 0, len(s))`. `Layout` runs frequently.
- **Hard-coded pixel sizes.** Use `basicwidget.UnitSize(context)` so that layouts scale with DPI and app scale.
- **Children in a plain value slice.** `append` to a `[]Row` moves its elements. This changes widget identity or causes a panic.
  Use `guigui.WidgetSlice[*T]` for a variable number of children (see `references/env-events-and-lists.md`).
- **One widget for each item in a large collection.** The framework builds, lays out, and hashes again everything in the tree on every frame, on screen or not.
  Add only the range in view (see `references/env-events-and-lists.md`).
- **One widget in more than one container.** A widget has one parent chain. Use different widget instances with shared data.
- **Forcing the value of a text input on every Build.** `ForceSetValue` overwrites an active edit and can emit a committed change synchronously.
  Use `SetValue` for normal model synchronisation, and force only explicit resets (see `references/layout-and-widgets.md`).
- **Decorative content that consumes the click of its container.** Make rich button or list content passthrough, so that the interactive ancestor handles input.
- **Custom list item content with its default text colour.** A `ListItem[T].Content` widget replaces the built-in text of the item.
  Nothing recolours it, and a highlighted row becomes unreadable.
  Read `basicwidget.EnvKeyListItemColorType` in `Layout` (see `references/layout-and-widgets.md`).
- **Resolving env through a widget that is new.** A widget that no `Build` added yet has no parent.
  The lookup returns `(nil, false)` with no error, and code that expects a non-nil value crashes.
  Resolve shared state through the widget whose `Build` runs now, not through a child that can be new (see `references/env-events-and-lists.md`).
- **Overriding `HandleButtonInput` on a widget that is never focused.** Only focused widgets (and their ancestors and descendants) or button-input-receptive widgets get button input.
  Focus the widget or call `context.SetButtonInputReceptive` (see "Handling input directly").
- **Scrolling a panel past its content.** `basicwidget.Panel` clamps the scroll offset to `[min(viewport − content, 0), 0]`.
  It discards positive offsets. When the content fits the viewport, the offset stays at the origin.
  `SetScrollOffset` and `ForceSetScrollOffset` cannot move content to a positive offset. For example, centring has an effect only on an axis that overflows.
