# Env, events, and dynamic lists

Pass shared state down with `Env`, send events up with event keys, and manage a variable number of children.
All reference paths are relative to the skill root.

## Contents

- [Passing shared state down: Env](#passing-shared-state-down-env)
- [Env lookups on a new widget find nothing](#env-lookups-on-a-new-widget-find-nothing)
- [Sending events up: the event-key pattern](#sending-events-up-the-event-key-pattern)
- [Dynamic lists of children](#dynamic-lists-of-children)
- [Add only the items in view](#add-only-the-items-in-view)
- [Resetting the cached state of a widget](#resetting-the-cached-state-of-a-widget)

## Passing shared state down: Env

`Env` is the dependency injection of Guigui.
A value that an ancestor provides is visible to every descendant, with no need to pass it through constructors.
Generate a key once at package scope:

```go
var envKeyModel = guigui.GenerateEnvKey()

// Ancestor provides the value:
func (r *Root) Env(context *guigui.Context, key guigui.EnvKey, source *guigui.EnvSource) (any, bool) {
	switch key {
	case envKeyModel:
		return &r.model, true
	default:
		return nil, false
	}
}

// Any descendant reads it (typically in Build):
func (c *Child) Build(context *guigui.Context, adder *guigui.ChildAdder) error {
	v, ok := context.Env(c, envKeyModel)
	if !ok {
		return nil
	}
	model := v.(*Model)
	// ... use model to configure children ...
	return nil
}
```

`context.Env(self, key)` goes up the parent chain and calls the `Env` of each ancestor until one returns `true`.
Use it for app-wide models and view state. Use explicit fields and setters for wiring from a parent to a direct child.

`Env` is not only for your own values. `basicwidget` also uses it to push presentation state down to descendant widgets.
A `List` publishes the state of each row through `basicwidget.EnvKeyListItemColorType`, so that custom row content can colour itself (see `references/layout-and-widgets.md`).
When you compose a custom widget inside a built-in container, check whether that container exposes an `EnvKey…` that your widget must honour.

## Env lookups on a new widget find nothing

`context.Env(widget, key)` resolves the value through the parent pointers of `widget`.
A widget gets its parent pointer only when the `Build` of an ancestor adds it with `adder.AddWidget`.
A widget that no `Build` added yet has no parent, so the lookup returns `(nil, false)`. There is no panic and no error, only a missing value.

This has two results:

- **Env lookups on the widget itself, in its own `Build` or `Layout`, are safe.**
  When your `Build` runs, the `Build` of the parent already added you, so your parent chain is complete.
- **The `Build` of a parent must not resolve env *through* a child that can be new.**
  The classic sequence is an add-item handler that grows a `WidgetSlice` pool and selects the new element.
  On the next `Build` of the owner, that element still has no parent. It gets a parent later in the same build pass, when the container that holds it builds.
  Each env lookup through the element fails, and code that expects a non-nil result panics.

```go
// An event handler grows the pool and selects the new element:
w.addButton.OnDown(func(context *guigui.Context) {
	w.rowContents.SetLen(w.rowContents.Len() + 1)
	w.selectedRow = w.rowContents.Len() - 1
})

// BAD — the owner's next Build resolves env through the fresh element:
content := w.rowContents.At(w.selectedRow)
v, _ := context.Env(content, envKeyModel) // fresh element: parent is nil → (nil, false)
model, _ := v.(*Model)                    // model is nil → panics on first use
```

Resolve shared state through the widget whose `Build` runs. Its own env is always available there. Give data to children through their plain fields:

```go
// GOOD — inside (w *Editor) Build:
v, ok := context.Env(w, envKeyModel)
if !ok {
	return nil
}
model := v.(*Model)
// ... configure w.rowContents elements from model via their Set* methods ...
```

A widget can keep a helper that resolves a model through its own env, for example `func (c *Content) model(context) *Model` that uses `context.Env(c, …)`.
Make that helper return nil when the lookup fails, and guard every call site.
The lookup can fail correctly while the widget is not in the tree, or not in it yet.

## Sending events up: the event-key pattern

A child must not know the type of its parent. To notify the parent, declare an `EventKey`, expose an `On…` setter, and dispatch:

```go
var eventItemDeleted = guigui.GenerateEventKey()

func (w *Item) OnDeleted(f func(context *guigui.Context, id int)) {
	guigui.SetEventHandler(w, eventItemDeleted, f)
}

func (w *Item) Build(context *guigui.Context, adder *guigui.ChildAdder) error {
	adder.AddWidget(&w.deleteButton)
	w.deleteButton.SetText("Delete")
	w.deleteButton.OnDown(func(context *guigui.Context) {
		guigui.DispatchEvent(w, eventItemDeleted, w.id)
	})
	return nil
}
```

The parent calls `child.OnDeleted(func(context, id){ ... })` during its own `Build`.
The framework **clears handlers and registers them again on every rebuild**, so always register them in `Build`.
`basicwidget` buttons expose `OnDown` and `OnUp` in the same way.

A handler that you register again does not need a new closure each time.
In a large tree, keep hot handlers in widget fields. Initialise each one once, when it is nil, and give the same function to `On...` during every `Build`.
A cached closure must capture only the stable widget receiver, or another stable key.
Never keep the `Context` argument, or a model or item from `Build` whose meaning can change.
Use the context that the callback receives, and resolve current data from the receiver or `Env` when the event runs.

## Dynamic lists of children

For a variable number of children, use `guigui.WidgetSlice[*T]`. Set its length to match the data, then add and configure each element.
`All()` iterates over index and widget pairs. `At(i)` gives random access.

```go
func (l *List) Build(context *guigui.Context, adder *guigui.ChildAdder) error {
	l.rows.SetLen(l.model.Count())
	for _, row := range l.rows.All() {
		adder.AddWidget(row)
	}
	for i, row := range l.rows.All() {
		item := l.model.At(i)
		row.SetText(item.Text)
		row.OnActivated(func(context *guigui.Context) {
			l.model.Activate(item.ID)
		})
	}
	return nil
}
```

Use `WidgetSlice`, **not** a hand-written `[]Row` that you `append` to.
The identity of a widget is the address of its embedded `DefaultWidget`.
Guigui forbids a move or copy of a widget by value, and it panics with *"illegal use of DefaultWidget copied by value"*.
An `append` to a value slice reallocates and moves its elements.
This triggers that guard, or it changes widget identities with no error, and each row loses its focus, scroll position, and animation state.
`WidgetSlice[*T]` keeps every element at a stable address across `SetLen`, so identity stays the same after a resize.

Give the row a `Measure` that returns its intrinsic height, so that the parent layout can size it.
Lay rows out with `FixedSize(rowHeight)` items in a vertical `LinearLayout`.
`basicwidget.List[T]` and `Table[T]` handle scrolling lists for you. Prefer them for large collections.

`WidgetSlice` keeps widget addresses, not the logical identity of the data in each slot.
For data that users can filter or reorder, track selection and per-item state by a stable item value or key.
Configure every slot again from current data in `Build`, and validate the selection after a deletion.
After a rebuild, a row index can refer to a different item.

## Add only the items in view

A tree costs what it holds, not what it shows.
A rebuild runs `Build` again on every widget in the tree, and a layout pass runs `Layout` again on every widget.
The framework hashes the `WriteStateKey` of every widget again each time that it checks for changes. Only `Draw` skips what is off screen.
A collection with one widget for each data item in the tree pays for the full data set on every frame, while only one screen of items is visible.
Each item also usually has its own children.
A few hundred items are enough to make scrolling, or the open animation of a popup, stutter.

`basicwidget.List[T]` and `Table[T]` already add only the items near the viewport. This is another reason to prefer them.
When they do not fit, for example for a grid of thumbnails, write the same structure yourself:

- **Calculate the visible range in `Layout`, store it, and hash it.**
  `Build` cannot read bounds, so `Layout` calculates the range from `widgetBounds.VisibleBounds()` and keeps it in a field that `WriteStateKey` writes.
  Scrolling changes the range, the changed key triggers a rebuild, and that `Build` adds the new range. You need no scroll callback.
  Extend the range by one row on each side, so that a scroll shorter than a row cannot show a gap.
- **Position the range that the last `Build` added, not the range that `Layout` calculated now.**
  Keep that range in a second field, and set it in `Build`.
  `Layout` runs before the rebuild that its new range requests, so the two ranges are different between those steps.
  If `Layout` positions the new range, the items that are in the tree stay unpositioned. They keep the empty bounds that every layout pass resets them to.
- **Make `Measure` include every item.** The scroll extent comes from the full content size.
  If `Measure` includes only the added range, the content becomes smaller, and the visible range becomes smaller with it.

The test is not "is this item on screen". The test is "does something under this item still need to be in the tree".
A widget stays in the tree only while *every* ancestor continues to add it.
The framework draws a popup on its own layer, independently of the position of its parent.
So a popup that an item opened stays on screen after that item scrolls out of the viewport, but only while the full chain from the root down to the popup is still added.
If you skip one link, the full subtree goes, popup included. Make the added range larger to keep such a chain complete.
`basicwidget` makes this exception for layout only.
A list item skips its own `Layout` while it is out of view, unless it has a content widget, which can hold something visible.
Its container limits the tree by height alone, so the container drops an item that is far enough out of view, whatever the item holds.
A popup that opens from inside a list item disappears with the item.

## Resetting the cached state of a widget

A widget collects state that `Build` does not derive again from its inputs, for example a selected index, a scroll offset, a cache keyed by IDs, or an in-progress edit.
When the data behind the widget changes completely, for example a document reloads or a different record opens, that state points at the old data and does not correct itself.
To drop it, assign the zero value to the widget at the start of **`Build`**, before you add the child again:

```go
func (r *Root) Build(context *guigui.Context, adder *guigui.ChildAdder) error {
	if doc := r.model.Document(); doc != r.lastDoc {
		r.lastDoc = doc     // a fresh object means the data was replaced
		r.editor = Editor{} // discard the child's accumulated state
	}
	// ... add and configure children ...
}
```

For the framework, this is safe. Every widget must be usable from its zero value.
The field keeps its address, `copyCheck` pins it again, identity stays the same, and the next Build adds and configures the new child again.
But it drops only in-memory state.
A widget that owns an external resource (a live connection, a goroutine, an open file) must release it *before* zeroing.
Guigui has no teardown hook, and a bare reset leaks the resource.
Trigger the reset on object identity (or a generation counter), not on a name or path.
Then a reload that gives a new object at the same path still triggers it.

Reset in `Build`, not in `Tick`.
`Tick` runs after the Layout of that tick, so a tree change there does not agree with the frame layout, which is already calculated, for one Draw.
Never zero the struct of the **application root** widget in this way.
The framework marks the root once at startup and never marks it again, so wiping its embedded `DefaultWidget` removes the mark.
Reset the *children* of the root, not the root value itself.
