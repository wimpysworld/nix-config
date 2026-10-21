# Repaints and state key audits

Find a stale region on a keyless widget, and audit a widget for missing state key coverage.
Read "State changes and when the screen updates" in `SKILL.md` first. All reference paths are relative to the skill root.

## A keyless widget that draws state from the Build of its parent

This is the most difficult gap in the order of preference, and the inverse of the caveat in `SKILL.md`.
The widget has **no** `WriteStateKey`, and its own `Draw` renders fields that the `Build` of a parent pushes into it through setters on each rebuild.

The rebuild part works correctly. The parent runs again, calls the setters, and the widget holds the new values.
A rebuild also repaints what it changes *visibly*.
After build and layout, the framework compares the children of each widget and their bounds with the previous frame, and it repaints each difference.
For this reason, structural changes need no key, for example a popup that opens, a child that appears, or anything that moves.

But a change of value only makes the same tree with the same bounds, so that comparison finds nothing.
The only remaining path from "the state of this widget changed during the build" to a repaint of its region is the post-build snapshot that compares `WriteStateKey` hashes.
A widget that writes no key always has the same hash, so the framework never sees the change.
The screen keeps the old pixels while the struct holds the new state.
Children that the `Build` of that widget configures are not affected, because their own keys change.
So the failure looks illogical: the `Text` next to the thumbnail updates, but the thumbnail does not.

The symptom is a stale region that corrects itself.
A focus change repaints the whole screen, so a click anywhere that moves focus fixes it.
Only changes that keep focus leave it visible. Examples are value changes from arrow keys or key repeat in a focused input, undo and redo shortcuts, and results that a goroutine applies.
One stale region with correct neighbours, which the next click fixes, is the signature of this bug.

The fix is a `WriteStateKey` that hashes exactly what `Draw` reads.
When `Draw` also renders shared data from `Env` (a document, a map, a model), also hash the generation counter of that model, so that edits to the model repaint the widget.

## Auditing a widget for missing key coverage

Use this procedure when you review a widget, or when you look for the cause of a stale screen. The defect pattern has three parts:

1. A setter stores a field on the widget.
2. The field reaches the screen through the `Build`, `Layout`, `Measure`, or `Draw` of the widget, directly or through helpers that they call.
3. The field is not written into `WriteStateKey`, and no `RequestRebuild` or `RequestRedraw` occurs at the mutation site.

There are two types.
A field that `Build` reads does not get its **rebuild** when code sets it outside a build pass.
A field that `Draw` reads does not get its **repaint** even when code sets it during a build pass (see the previous section).

Before you report a defect, exclude the cases that are safe by construction:

- **The setter forwards to the setter of a child widget** (`w.text.SetValue(v)`), and it does not store the value. The key of the child covers it.
- **The change occurs in a `DispatchEvent` handler, or in an input handler that returns `HandleInputByWidget`.**
  Both force a whole-tree rebuild. This is why most callback-driven state needs no key.
  Handlers that change state and return an empty `HandleInputResult{}` do not get this rebuild.
- **Only `On…` callbacks read the field.** That is behaviour, not screen state. The change that the callback makes triggers its own update.
- **Only `CursorShape` reads the field.** The framework evaluates the cursor shape again on every frame, with no rebuild.
- **The value comes from `Env` or from the state of other widgets during `Build`.** It can change only during a build pass.

Be suspicious of one argument for clearance: "this is safe because every caller also changes something else that rebuilds at the same time".
For example, the caller sets a field immediately before it opens a popup (`Popup.SetOpen` requests a rebuild itself).
Another example is a field that a caller always sets together with a sibling field that *is* in the key.
This coupling works, but it is not visible at the widget, and it fails with no error when a future call site changes what it sets together with the setter.
When the audit depends on such coupling, add the field to the key. One more hashed int costs little and removes the risk.
