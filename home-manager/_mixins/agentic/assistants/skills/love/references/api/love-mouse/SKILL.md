---
name: love-mouse
description: Provides an interface to the user's mouse. Use this skill when working with mouse operations, cursor management, mouse events, or any mouse-related operations in LÖVE games.
license: MIT
metadata:
  author: Ron Dekker <rondekker.nl>
---

## When to use this skill
Provides an interface to the user's mouse. Use this skill when working with mouse operations, cursor management, mouse events, or any mouse-related operations in LÖVE games.

## Common use cases
- Handling mouse clicks and movements
- Managing mouse cursor visibility and appearance
- Implementing drag-and-drop functionality
- Working with mouse wheel events
- Handling touch input that emulates mouse events

## Functions

- `love.mouse.getCursor() -> cursor: Cursor`: Gets the current Cursor.
- `love.mouse.getPosition() -> x: number, y: number`: Returns the current position of the mouse.
- `love.mouse.getRelativeMode() -> enabled: boolean`: Gets whether relative mode is enabled for the mouse. If relative mode is enabled, the cursor is hidden and doesn't move when the mouse does, but relative mouse motion events are still generated via love.mousemoved. This lets the mouse move in any direction indefinitely without the cursor getting stuck at the edges of the screen. The reported position of the mouse is not updated while relative mode is enabled, even when relative mouse motion events are generated.
- `love.mouse.getSystemCursor(ctype: CursorType) -> cursor: Cursor`: Gets a Cursor object representing a system-native hardware cursor. Hardware cursors are framerate-independent and work the same way as normal operating system cursors. Unlike drawing an image at the mouse's current coordinates, hardware cursors never have visible lag between when the mouse is moved and when the cursor position updates, even at low framerates.
- `love.mouse.getX() -> x: number`: Returns the current x-position of the mouse.
- `love.mouse.getY() -> y: number`: Returns the current y-position of the mouse.
- `love.mouse.isCursorSupported() -> supported: boolean`: Gets whether cursor functionality is supported. If it isn't supported, calling love.mouse.newCursor and love.mouse.getSystemCursor will cause an error. Mobile devices do not support cursors.
- `love.mouse.isDown(button: number, ...: number) -> down: boolean`: Checks whether a certain mouse button is down. This function does not detect mouse wheel scrolling; you must use the love.wheelmoved (or love.mousepressed in version 0.9.2 and older) callback for that. 
- `love.mouse.isGrabbed() -> grabbed: boolean`: Checks if the mouse is grabbed.
- `love.mouse.isVisible() -> visible: boolean`: Checks if the cursor is visible.
- `love.mouse.newCursor` - Creates a new hardware Cursor object from an image file or ImageData. Hardware cursors are framerate-independent and work the same way as normal operating system cursors. Unlike drawing an image at the mouse's current coordinates, hardware cursors never have visible lag between when the mouse is moved and when the cursor position updates, even at low framerates. The hot spot is the point the operating system uses to determine what was clicked and at what position the mouse cursor is. For example, the normal arrow pointer normally has its hot spot at the top left of the image, but a crosshair cursor might have it in the middle.
  - `love.mouse.newCursor(imageData: ImageData, hotx: number, hoty: number) -> cursor: Cursor`: No description
  - `love.mouse.newCursor(filename: string, hotx: number, hoty: number) -> cursor: Cursor`: No description
  - `love.mouse.newCursor(fileData: FileData, hotx: number, hoty: number) -> cursor: Cursor`: No description
- `love.mouse.setCursor` - Sets the current mouse cursor.
  - `love.mouse.setCursor(cursor: Cursor)`: No description
  - `love.mouse.setCursor()`: Resets the current mouse cursor to the default.
- `love.mouse.setGrabbed(grab: boolean)`: Grabs the mouse and confines it to the window.
- `love.mouse.setPosition(x: number, y: number)`: Sets the current position of the mouse. Non-integer values are floored.
- `love.mouse.setRelativeMode(enable: boolean)`: Sets whether relative mode is enabled for the mouse. When relative mode is enabled, the cursor is hidden and doesn't move when the mouse does, but relative mouse motion events are still generated via love.mousemoved. This lets the mouse move in any direction indefinitely without the cursor getting stuck at the edges of the screen. The reported position of the mouse may not be updated while relative mode is enabled, even when relative mouse motion events are generated.
- `love.mouse.setVisible(visible: boolean)`: Sets the current visibility of the cursor.
- `love.mouse.setX(x: number)`: Sets the current X position of the mouse. Non-integer values are floored.
- `love.mouse.setY(y: number)`: Sets the current Y position of the mouse. Non-integer values are floored.

## Types

- `Cursor`: Represents a hardware cursor.
  - `love.Cursor.getType() -> ctype: CursorType`: Gets the type of the Cursor.

## Enums

- `CursorType`: Types of hardware cursors.
  - `image`: The cursor is using a custom image.
  - `arrow`: An arrow pointer.
  - `ibeam`: An I-beam, normally used when mousing over editable or selectable text.
  - `wait`: Wait graphic.
  - `waitarrow`: Small wait cursor with an arrow pointer.
  - `crosshair`: Crosshair symbol.
  - `sizenwse`: Double arrow pointing to the top-left and bottom-right.
  - `sizenesw`: Double arrow pointing to the top-right and bottom-left.
  - `sizewe`: Double arrow pointing left and right.
  - `sizens`: Double arrow pointing up and down.
  - `sizeall`: Four-pointed arrow pointing up, down, left, and right.
  - `no`: Slashed circle or crossbones.
  - `hand`: Hand symbol.

## Examples

### Handling mouse click
```lua
function love.mousepressed(x, y, button, istouch)
  if button == 1 then  -- Left mouse button
    print("Clicked at: " .. x .. ", " .. y)
    -- Handle left click logic
  end
end
```

### Custom cursor
```lua
function love.load()
  -- Hide default cursor
  love.mouse.setVisible(false)

  -- Load custom cursor image
  cursorImage = love.graphics.newImage("cursor.png")
end

function love.draw()
  -- Draw custom cursor at mouse position
  local x, y = love.mouse.getPosition()
  love.graphics.draw(cursorImage, x, y)
end
```

## Best practices
- Handle both mouse and touch input for cross-platform compatibility
- Use appropriate cursor visibility for different game states
- Consider mouse acceleration and sensitivity on different platforms
- Handle mouse events efficiently to avoid performance issues
- Test mouse input on target platforms as behavior may vary

## Platform compatibility
- **Desktop (Windows, macOS, Linux)**: Full mouse support
- **Mobile (iOS, Android)**: Mouse events emulated from touch input
- **Web**: Full mouse support in browser environment
