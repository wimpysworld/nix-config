---
name: love
description: Provides functions for love operations. Use this skill when working with core functionality for LÖVE games.
license: MIT
metadata:
  author: Ron Dekker <rondekker.nl>
---

## When to use this skill
Provides functions for love operations. Use this skill when working with core functionality for LÖVE games.

## Common use cases
- Basic game setup and configuration
- Accessing core framework features
- Handling cross-module functionality
- Game loop management and event handling

## Modules

This module includes the following submodules:

- [`love-audio`](../love-audio/SKILL.md) - Provides an interface to create noise with the user's speakers.
- [`love-data`](../love-data/SKILL.md) - Provides functionality for creating and transforming data.
- [`love-event`](../love-event/SKILL.md) - Manages events, like keypresses.
- [`love-filesystem`](../love-filesystem/SKILL.md) - Provides an interface to the user's filesystem.
- [`love-font`](../love-font/SKILL.md) - Allows you to work with fonts.
- [`love-graphics`](../love-graphics/SKILL.md) - The primary responsibility for the love.graphics module is the drawing of lines, shapes, text, Images and other Drawable objects onto the screen. Its secondary responsibilities include loading external files (including Images and Fonts) into memory, creating specialized objects (such as ParticleSystems or Canvases) and managing screen geometry. LÖVE's coordinate system is rooted in the upper-left corner of the screen, which is at location (0, 0). The x axis is horizontal: larger values are further to the right. The y axis is vertical: larger values are further towards the bottom. In many cases, you draw images or shapes in terms of their upper-left corner. Many of the functions are used to manipulate the graphics coordinate system, which is essentially the way coordinates are mapped to the display. You can change the position, scale, and even rotation in this way.
- [`love-image`](../love-image/SKILL.md) - Provides an interface to decode encoded image data.
- [`love-joystick`](../love-joystick/SKILL.md) - Provides an interface to the user's joystick.
- [`love-keyboard`](../love-keyboard/SKILL.md) - Provides an interface to the user's keyboard.
- [`love-math`](../love-math/SKILL.md) - Provides system-independent mathematical functions.
- [`love-mouse`](../love-mouse/SKILL.md) - Provides an interface to the user's mouse.
- [`love-physics`](../love-physics/SKILL.md) - Can simulate 2D rigid body physics in a realistic manner. This module is based on Box2D, and this API corresponds to the Box2D API as closely as possible.
- [`love-sound`](../love-sound/SKILL.md) - This module is responsible for decoding sound files. It can't play the sounds, see love.audio for that.
- [`love-system`](../love-system/SKILL.md) - Provides access to information about the user's system.
- [`love-thread`](../love-thread/SKILL.md) - Allows you to work with threads. Threads are separate Lua environments, running in parallel to the main code. As their code runs separately, they can be used to compute complex operations without adversely affecting the frame rate of the main thread. However, as they are separate environments, they cannot access the variables and functions of the main thread, and communication between threads is limited. All LOVE objects (userdata) are shared among threads so you'll only have to send their references across threads. You may run into concurrency issues if you manipulate an object on multiple threads at the same time. When a Thread is started, it only loads the love.thread module. Every other module has to be loaded with require.
- [`love-timer`](../love-timer/SKILL.md) - Provides an interface to the user's clock.
- [`love-touch`](../love-touch/SKILL.md) - Provides an interface to touch-screen presses.
- [`love-video`](../love-video/SKILL.md) - This module is responsible for decoding, controlling, and streaming video files. It can't draw the videos, see love.graphics.newVideo and Video objects for that.
- [`love-window`](../love-window/SKILL.md) - Provides an interface for modifying and retrieving information about the program's window.

## Functions

- `love.getVersion() -> major: number, minor: number, revision: number, codename: string`: Gets the current running version of LÖVE.
- `love.hasDeprecationOutput() -> enabled: boolean`: Gets whether LÖVE displays warnings when using deprecated functionality. It is disabled by default in fused mode, and enabled by default otherwise. When deprecation output is enabled, the first use of a formally deprecated LÖVE API will show a message at the bottom of the screen for a short time, and print the message to the console.
- `isVersionCompatible` - Gets whether the given version is compatible with the current running version of LÖVE.
  - `love.isVersionCompatible(version: string) -> compatible: boolean`: No description
  - `love.isVersionCompatible(major: number, minor: number, revision: number) -> compatible: boolean`: No description
- `love.setDeprecationOutput(enable: boolean)`: Sets whether LÖVE displays warnings when using deprecated functionality. It is disabled by default in fused mode, and enabled by default otherwise. When deprecation output is enabled, the first use of a formally deprecated LÖVE API will show a message at the bottom of the screen for a short time, and print the message to the console.

## Callbacks

- `love.conf(t: table)`: If a file called conf.lua is present in your game folder (or .love file), it is run before the LÖVE modules are loaded. You can use this file to overwrite the love.conf function, which is later called by the LÖVE 'boot' script. Using the love.conf function, you can set some configuration options, and change things like the default size of the window, which modules are loaded, and other stuff.
- `love.directorydropped(path: string)`: Callback function triggered when a directory is dragged and dropped onto the window.
- `love.displayrotated(index: number, orientation: DisplayOrientation)`: Called when the device display orientation changed, for example, user rotated their phone 180 degrees.
- `love.draw()`: Callback function used to draw on the screen every frame.
- `love.errorhandler(msg: string) -> mainLoop: function`: The error handler, used to display error messages.
- `love.filedropped(file: DroppedFile)`: Callback function triggered when a file is dragged and dropped onto the window.
- `love.focus(focus: boolean)`: Callback function triggered when window receives or loses focus.
- `love.gamepadaxis(joystick: Joystick, axis: GamepadAxis, value: number)`: Called when a Joystick's virtual gamepad axis is moved.
- `love.gamepadpressed(joystick: Joystick, button: GamepadButton)`: Called when a Joystick's virtual gamepad button is pressed.
- `love.gamepadreleased(joystick: Joystick, button: GamepadButton)`: Called when a Joystick's virtual gamepad button is released.
- `love.joystickadded(joystick: Joystick)`: Called when a Joystick is connected.
- `love.joystickaxis(joystick: Joystick, axis: number, value: number)`: Called when a joystick axis moves.
- `love.joystickhat(joystick: Joystick, hat: number, direction: JoystickHat)`: Called when a joystick hat direction changes.
- `love.joystickpressed(joystick: Joystick, button: number)`: Called when a joystick button is pressed.
- `love.joystickreleased(joystick: Joystick, button: number)`: Called when a joystick button is released.
- `love.joystickremoved(joystick: Joystick)`: Called when a Joystick is disconnected.
- `love.keypressed(key: KeyConstant, scancode: Scancode, isrepeat: boolean)`: Callback function triggered when a key is pressed.
- `love.keyreleased(key: KeyConstant, scancode: Scancode)`: Callback function triggered when a keyboard key is released.
- `love.load(arg: table, unfilteredArg: table)`: This function is called exactly once at the beginning of the game.
- `love.lowmemory()`: Callback function triggered when the system is running out of memory on mobile devices. Mobile operating systems may forcefully kill the game if it uses too much memory, so any non-critical resource should be removed if possible (by setting all variables referencing the resources to '''nil'''), when this event is triggered. Sounds and images in particular tend to use the most memory.
- `love.mousefocus(focus: boolean)`: Callback function triggered when window receives or loses mouse focus.
- `love.mousemoved(x: number, y: number, dx: number, dy: number, istouch: boolean)`: Callback function triggered when the mouse is moved.
- `love.mousepressed(x: number, y: number, button: number, istouch: boolean, presses: number)`: Callback function triggered when a mouse button is pressed.
- `love.mousereleased(x: number, y: number, button: number, istouch: boolean, presses: number)`: Callback function triggered when a mouse button is released.
- `love.quit() -> r: boolean`: Callback function triggered when the game is closed.
- `love.resize(w: number, h: number)`: Called when the window is resized, for example if the user resizes the window, or if love.window.setMode is called with an unsupported width or height in fullscreen and the window chooses the closest appropriate size.
- `love.run() -> mainLoop: function`: The main function, containing the main loop. A sensible default is used when left out.
- `love.textedited(text: string, start: number, length: number)`: Called when the candidate text for an IME (Input Method Editor) has changed. The candidate text is not the final text that the user will eventually choose. Use love.textinput for that.
- `love.textinput(text: string)`: Called when text has been entered by the user. For example if shift-2 is pressed on an American keyboard layout, the text '@' will be generated.
- `love.threaderror(thread: Thread, errorstr: string)`: Callback function triggered when a Thread encounters an error.
- `love.touchmoved(id: light userdata, x: number, y: number, dx: number, dy: number, pressure: number)`: Callback function triggered when a touch press moves inside the touch screen.
- `love.touchpressed(id: light userdata, x: number, y: number, dx: number, dy: number, pressure: number)`: Callback function triggered when the touch screen is touched.
- `love.touchreleased(id: light userdata, x: number, y: number, dx: number, dy: number, pressure: number)`: Callback function triggered when the touch screen stops being touched.
- `love.update(dt: number)`: Callback function used to update the state of the game every frame.
- `love.visible(visible: boolean)`: Callback function triggered when window is minimized/hidden or unminimized by the user.
- `love.wheelmoved(x: number, y: number)`: Callback function triggered when the mouse wheel is moved.

## Types

- `Data`: The superclass of all data.
  - `love.Data.clone() -> clone: Data`: Creates a new copy of the Data object.
  - `love.Data.getFFIPointer() -> pointer: cdata`: Gets an FFI pointer to the Data. This function should be preferred instead of Data:getPointer because the latter uses light userdata which can't store more all possible memory addresses on some new ARM64 architectures, when LuaJIT is used.
  - `love.Data.getPointer() -> pointer: light userdata`: Gets a pointer to the Data. Can be used with libraries such as LuaJIT's FFI.
  - `love.Data.getSize() -> size: number`: Gets the Data's size in bytes.
  - `love.Data.getString() -> data: string`: Gets the full Data as a string.

- `Object`: The superclass of all LÖVE types.
  - `love.Object.release() -> success: boolean`: Destroys the object's Lua reference. The object will be completely deleted if it's not referenced by any other LÖVE object or thread. This method can be used to immediately clean up resources without waiting for Lua's garbage collector.
  - `love.Object.type() -> type: string`: Gets the type of the object as a string.
  - `love.Object.typeOf(name: string) -> b: boolean`: Checks whether an object is of a certain type. If the object has the type with the specified name in its hierarchy, this function will return true.

## Examples

### Basic game structure
```lua
-- Main game structure with core LÖVE callbacks
function love.load()
  -- Initialize game resources
  player = {x = 100, y = 100, speed = 200}

  -- Load assets
  playerImage = love.graphics.newImage("player.png")
end

function love.update(dt)
  -- Update game state using delta time
  if love.keyboard.isDown("right") then
    player.x = player.x + player.speed * dt
  end
  if love.keyboard.isDown("left") then
    player.x = player.x - player.speed * dt
  end
end

function love.draw()
  -- Draw game elements
  love.graphics.draw(playerImage, player.x, player.y)
  love.graphics.print("Hello World!", 400, 300)
end

function love.keypressed(key)
  -- Handle key presses
  if key == "escape" then
    love.event.quit()
  end
end
```

### Version compatibility check
```lua
-- Check LÖVE version compatibility
function love.load()
  local major, minor, revision = love.getVersion()
  print("Running LÖVE " .. major .. "." .. minor .. "." .. revision)

  -- Check if current version supports required features
  if love.isVersionCompatible(11, 3) then
    print("Version 11.3+ features are available")
  else
    print("Warning: Some features may not be available")
  end
end
```

## Best practices
- Always check if functions are supported on the target platform
- Handle errors gracefully for cross-platform compatibility
- Use callbacks appropriately for event-driven programming
- Consider performance implications for frequently called functions

## Platform compatibility
Most functions are supported across all platforms, but some may have limitations:
- Desktop (Windows, macOS, Linux): Full support
- Mobile (iOS, Android): Some limitations may apply
- Web: Limited support for certain features
