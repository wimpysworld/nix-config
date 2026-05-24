---
name: love-event
description: Manages events, like keypresses. Use this skill when working with event management, event callbacks, event pumping, or any event-related operations in LÖVE games.
license: MIT
metadata:
  author: Ron Dekker <rondekker.nl>
---

## When to use this skill
Manages events, like keypresses. Use this skill when working with event management, event callbacks, event pumping, or any event-related operations in LÖVE games.

## Common use cases
- Managing game events and callbacks
- Implementing custom event handling systems
- Working with event queues and pumping
- Handling system and user-generated events
- Managing event flow and propagation

## Functions

- `love.event.clear()`: Clears the event queue.
- `love.event.poll() -> i: function`: Returns an iterator for messages in the event queue.
- `love.event.pump()`: Pump events into the event queue. This is a low-level function, and is usually not called by the user, but by love.run. Note that this does need to be called for any OS to think you're still running, and if you want to handle OS-generated events at all (think callbacks).
- `love.event.push(n: Event, a: Variant, b: Variant, c: Variant, d: Variant, e: Variant, f: Variant, ...: Variant)`: Adds an event to the event queue. From 0.10.0 onwards, you may pass an arbitrary amount of arguments with this function, though the default callbacks don't ever use more than six.
- `love.event.quit` - Adds the quit event to the queue. The quit event is a signal for the event handler to close LÖVE. It's possible to abort the exit process with the love.quit callback.
  - `love.event.quit(exitstatus: number)`: No description
  - `love.event.quit('restart': string)`: Restarts the game without relaunching the executable. This cleanly shuts down the main Lua state instance and creates a brand new one.
- `love.event.wait() -> n: Event, a: Variant, b: Variant, c: Variant, d: Variant, e: Variant, f: Variant, ...: Variant`: Like love.event.poll(), but blocks until there is an event in the queue.

## Enums

- `Event`: Arguments to love.event.push() and the like. Since 0.8.0, event names are no longer abbreviated.
  - `focus`: Window focus gained or lost
  - `joystickpressed`: Joystick pressed
  - `joystickreleased`: Joystick released
  - `keypressed`: Key pressed
  - `keyreleased`: Key released
  - `mousepressed`: Mouse pressed
  - `mousereleased`: Mouse released
  - `quit`: Quit
  - `resize`: Window size changed by the user
  - `visible`: Window is minimized or un-minimized by the user
  - `mousefocus`: Window mouse focus gained or lost
  - `threaderror`: A Lua error has occurred in a thread
  - `joystickadded`: Joystick connected
  - `joystickremoved`: Joystick disconnected
  - `joystickaxis`: Joystick axis motion
  - `joystickhat`: Joystick hat pressed
  - `gamepadpressed`: Joystick's virtual gamepad button pressed
  - `gamepadreleased`: Joystick's virtual gamepad button released
  - `gamepadaxis`: Joystick's virtual gamepad axis moved
  - `textinput`: User entered text
  - `mousemoved`: Mouse position changed
  - `lowmemory`: Running out of memory on mobile devices system
  - `textedited`: Candidate text for an IME changed
  - `wheelmoved`: Mouse wheel moved
  - `touchpressed`: Touch screen touched
  - `touchreleased`: Touch screen stop touching
  - `touchmoved`: Touch press moved inside touch screen
  - `directorydropped`: Directory is dragged and dropped onto the window
  - `filedropped`: File is dragged and dropped onto the window.
  - `jp`: Joystick pressed
  - `jr`: Joystick released
  - `kp`: Key pressed
  - `kr`: Key released
  - `mp`: Mouse pressed
  - `mr`: Mouse released
  - `q`: Quit
  - `f`: Window focus gained or lost

## Examples

### Custom event handling
```lua
-- Pump and handle events manually
function love.update(dt)
  love.event.pump()

  for name, a, b, c, d, e, f in love.event.poll() do
    if name == "quit" then
      if not love.quit or not love.quit() then
        return a or 0
      end
    end
    -- Handle other events
  end
end
```

### Event callback
```lua
-- Custom quit handler
function love.quit()
  -- Save game state before quitting
  saveGameState()
  return false  -- Allow normal quit process
end
```

## Best practices
- Use love.event.pump() regularly to process events
- Handle quit events gracefully
- Consider performance when polling events frequently
- Test event handling on different platforms
- Be mindful of event queue limits

## Platform compatibility
- **Desktop (Windows, macOS, Linux)**: Full event support
- **Mobile (iOS, Android)**: Full support
- **Web**: Full support
