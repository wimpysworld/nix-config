# Layout and widgets

Position children with `LinearLayout`, and compose the built-in `basicwidget` widgets.
All reference paths are relative to the skill root.

## Contents

- [Layout with LinearLayout](#layout-with-linearlayout)
- [Share one layout between Layout and Measure](#share-one-layout-between-layout-and-measure)
- [Composition and built-in widgets](#composition-and-built-in-widgets)
- [Keep in-progress edits separate from model synchronisation](#keep-in-progress-edits-separate-from-model-synchronisation)
- [Custom list item content must colour itself](#custom-list-item-content-must-colour-itself)

## Layout with LinearLayout

`LinearLayout` is the main layout tool. Make a slice of `LinearLayoutItem`, then call `LayoutWidgets`.
The framework calls `Layout` often. Reuse the backing slice across ticks with `slices.Delete(s, 0, len(s))` to prevent an allocation on each tick.

```go
func (w *Panel) Layout(context *guigui.Context, widgetBounds *guigui.WidgetBounds, layouter *guigui.ChildLayouter) {
	u := basicwidget.UnitSize(context) // scale-aware base unit; size things in multiples of it

	w.items = slices.Delete(w.items, 0, len(w.items))
	w.items = append(w.items,
		guigui.LinearLayoutItem{Widget: &w.header, Size: guigui.FixedSize(u)},
		guigui.LinearLayoutItem{Widget: &w.body, Size: guigui.FlexibleSize(1)}, // takes remaining space
		guigui.LinearLayoutItem{Widget: &w.footer},                            // zero Size = intrinsic (its Measure)
	)
	(guigui.LinearLayout{
		Direction: guigui.LayoutDirectionVertical,
		Items:     w.items,
		Gap:       u / 2,
		Padding:   guigui.Padding{Start: u / 2, Top: u / 2, End: u / 2, Bottom: u / 2},
	}).LayoutWidgets(context, widgetBounds.Bounds(), layouter)
}
```

Sizing for each item (`LinearLayoutItem.Size`):

- `guigui.FixedSize(px)` is an exact pixel length along the layout direction.
- `guigui.FlexibleSize(weight)` shares the remaining space in proportion to the weight, after the layout places the fixed and intrinsic items.
  A bare `LinearLayoutItem{Size: guigui.FlexibleSize(1)}` with no `Widget` is a spacer.
- **Zero `Size{}`** sizes the item with the `Measure` of its widget (intrinsic size).

To nest layouts, an item can hold a sub-layout instead of a widget: `LinearLayoutItem{Size: ..., Layout: &subLayout}`, where `subLayout` is another `guigui.LinearLayout`.
The cross-axis always fills the available extent.

Size items in multiples of `basicwidget.UnitSize(context)`, not in raw pixels, so that layouts scale correctly on high-DPI displays and at different app scales.

## Share one layout between Layout and Measure

A composite widget usually needs the *same* `LinearLayout` in two places. `Layout` gives it to `LayoutWidgets`, and `Measure` asks it for a size.
Make it once in an unexported helper, conventionally named `layout`, and call that helper from both methods.
The structure then has a single source of truth, and `Measure` always agrees with what `Layout` does:

```go
func (w *Field) layout(context *guigui.Context) guigui.LinearLayout {
	u := basicwidget.UnitSize(context)
	w.items = slices.Delete(w.items, 0, len(w.items))
	w.items = append(w.items,
		guigui.LinearLayoutItem{Widget: &w.input, Size: guigui.FlexibleSize(1)},
		guigui.LinearLayoutItem{Widget: &w.button, Size: guigui.FixedSize(u)},
	)
	return guigui.LinearLayout{
		Direction: guigui.LayoutDirectionHorizontal,
		Gap:       u / 4,
		Items:     w.items,
	}
}

func (w *Field) Layout(context *guigui.Context, widgetBounds *guigui.WidgetBounds, layouter *guigui.ChildLayouter) {
	w.layout(context).LayoutWidgets(context, widgetBounds.Bounds(), layouter)
}

func (w *Field) Measure(context *guigui.Context, constraints guigui.Constraints) image.Point {
	return w.layout(context).Measure(context, constraints)
}
```

`LinearLayout` is a plain value, so a return by value costs little. The helper still reuses the `items` slice across ticks.

## Composition and built-in widgets

Compose a widget from child widgets that are fields, and add them in `Build`.
The `basicwidget` package has the standard catalogue: `Background`, `Button`, `Text`, `TextInput`, `NumberInput`, `Checkbox`, `Toggle`, `RadioButton`, `Slider`, `Select`/`Combobox`, `List[T]`, `Table[T]`, `Panel`, `Popup`, `PopupMenu`, `ContextMenuArea[T]`, `SegmentedControl`, `Form`, `Image`, `Divider`, `Expander`, and more.
Configure them with their `Set*` methods in `Build`, and subscribe to their `On*` callbacks.

```go
r.createButton.SetText("Create")
r.createButton.OnDown(func(context *guigui.Context) {
	r.addItem(r.textInput.Value())
})
context.SetEnabled(&r.createButton, r.canAdd())
```

For button actions, use `OnDown` by default. Use `OnUp` only when release behaviour is necessary.

Use `guigui.WidgetWithSize[*T]` or `guigui.WidgetWithPadding[*T]` when a child needs only an intrinsic-size override or padding.
These wrappers create their zero-value child when it is first needed, forward layout and focus, and expose the child through `Widget()`.
Use `guigui.LayerWidget[*T]` for floating content that must escape ancestor clipping or be above other input targets.
Add and lay out the wrapper, then call `BringToFrontLayer(context)` during `Build`. Higher layers draw first and receive input first.

A widget instance can have only one parent in a build.
Do not use the same content widget in two places, for example in two lists, or in a source view and a popup.
Make different widget instances that render the same data. A shared model is correct.
A shared widget corrupts its parent chain, env lookup, bounds, and focus and input behaviour.

## Keep in-progress edits separate from model synchronisation

For an editable `basicwidget.TextInput`, call `SetValue(modelValue)` during `Build` as usual.
It keeps an active user edit, and it does not overwrite the live buffer on every whole-tree rebuild.
Use `ForceSetValue` only for an explicit replacement or reset.
It replaces the buffer immediately and can call `OnValueChanged` synchronously as a committed change.
If a forced seed must not count as user input, guard the callback with a short-lived `seeding` flag.

When you replace a subtree or change to a different record, commit or deliberately discard active edits before you reset the widget.
If you do not, the model and the retained edit buffer can diverge with no error.

## Custom list item content must colour itself

`basicwidget.ListItem[T].Content` accepts any widget. This lets a row have an icon, more than one column, or an editable field.
Setting `Content` replaces the built-in text widget of the item, so the list stops colouring the contents of the row.
The list still paints the selection highlight behind the row.
A custom row that ignores its state keeps its default text colour and becomes unreadable on the accent background.

The list publishes the state of each row as a `basicwidget.ListItemColorType` under `basicwidget.EnvKeyListItemColorType`.
The values are `Default`, `Highlighted`, `SelectedInUnfocusedList`, `Hovered`, `ItemDisabled`, and `ListDisabled`.
Read the value and apply `TextColor(context)`:

```go
func (r *row) Layout(context *guigui.Context, widgetBounds *guigui.WidgetBounds, layouter *guigui.ChildLayouter) {
	colorType := basicwidget.ListItemColorTypeDefault
	if v, ok := context.Env(r, basicwidget.EnvKeyListItemColorType); ok {
		if ct, ok := v.(basicwidget.ListItemColorType); ok {
			colorType = ct
		}
	}
	var style basicwidget.TextStyle
	style.SetColor(colorType.TextColor(context))
	r.text.SetBaseStyle(&style)

	r.layout(context).LayoutWidgets(context, widgetBounds.Bounds(), layouter)
}
```

The rules in that example:

- **Read the value in `Layout` (or `Draw`), not in `Build`.**
  This is the deliberate exception to the rule that setters belong in `Build`.
  The value comes from the content widget of the list, so it exists only after the build phase.
- **Guard the lookup *and* the type assertion.** A missing value is normal, not an error.
  The lookup returns `(nil, false)` for a row that is scrolled out of the viewport, and for the same widget outside a list.
  `basicwidget.Popup` also returns `(nil, true)` to stop the colour type of a row from leaking into popup content.
  So `ok` alone does not mean that you have a `ListItemColorType`.
  Always use the comma-ok form, never a bare `v.(basicwidget.ListItemColorType)`.
- **A fallback to `Default` is the simplest correct choice.** It maps to the ordinary text colour.
  You can also leave the colour `nil` and not change the style. This suits a widget that has its own palette when it is outside a list.
- **The colour type controls more than text.** `BackgroundColor(context)` returns the matching fill (`nil` for `Default`).
  `Draw` can branch on `Highlighted` to change a border or fill.
  A monochrome icon needs rendering again with `ebiten.ColorModeDark` on a highlighted row, because the accent background needs a light foreground.

Use `basicwidget.ListItemTextPadding(context)` as the padding of the row, so that custom content aligns with ordinary text items.
The in-tree implementations to copy are `example/gallery/selects.go` (`selectItem`: icon and text) and `example/biglist` (`itemWidget`: variable row heights).

For the full widget list and runnable demos, read `basicwidget/` and the programs under `example/`.
Start with `example/counter` and `example/todo`. `example/gallery` uses most widgets.
