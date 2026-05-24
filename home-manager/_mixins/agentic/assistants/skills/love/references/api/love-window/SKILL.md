---
name: love-window
description: Provides an interface for modifying and retrieving information about the program's window. Use this skill when working with window operations, display settings, fullscreen modes, or any window-related operations in LÖVE games.
license: MIT
metadata:
  author: Ron Dekker <rondekker.nl>
---

## When to use this skill
Provides an interface for modifying and retrieving information about the program's window. Use this skill when working with window operations, display settings, fullscreen modes, or any window-related operations in LÖVE games.

## Common use cases
- Creating and managing game windows
- Handling window resizing and display modes
- Working with multiple monitors and display settings
- Managing window properties (title, icon, etc.)
- Handling fullscreen and windowed modes

## Functions

- `love.window.close()`: Closes the window. It can be reopened with love.window.setMode.
- `love.window.fromPixels` - Converts a number from pixels to density-independent units. The pixel density inside the window might be greater (or smaller) than the 'size' of the window. For example on a retina screen in Mac OS X with the highdpi window flag enabled, the window may take up the same physical size as an 800x600 window, but the area inside the window uses 1600x1200 pixels. love.window.fromPixels(1600) would return 800 in that case. This function converts coordinates from pixels to the size users are expecting them to display at onscreen. love.window.toPixels does the opposite. The highdpi window flag must be enabled to use the full pixel density of a Retina screen on Mac OS X and iOS. The flag currently does nothing on Windows and Linux, and on Android it is effectively always enabled. Most LÖVE functions return values and expect arguments in terms of pixels rather than density-independent units.
  - `love.window.fromPixels(pixelvalue: number) -> value: number`: No description
  - `love.window.fromPixels(px: number, py: number) -> x: number, y: number`: The units of love.graphics.getWidth, love.graphics.getHeight, love.mouse.getPosition, mouse events, love.touch.getPosition, and touch events are always in terms of pixels.
- `love.window.getDPIScale() -> scale: number`: Gets the DPI scale factor associated with the window. The pixel density inside the window might be greater (or smaller) than the 'size' of the window. For example on a retina screen in Mac OS X with the highdpi window flag enabled, the window may take up the same physical size as an 800x600 window, but the area inside the window uses 1600x1200 pixels. love.window.getDPIScale() would return 2.0 in that case. The love.window.fromPixels and love.window.toPixels functions can also be used to convert between units. The highdpi window flag must be enabled to use the full pixel density of a Retina screen on Mac OS X and iOS. The flag currently does nothing on Windows and Linux, and on Android it is effectively always enabled.
- `love.window.getDesktopDimensions(displayindex: number) -> width: number, height: number`: Gets the width and height of the desktop.
- `love.window.getDisplayCount() -> count: number`: Gets the number of connected monitors.
- `love.window.getDisplayName(displayindex: number) -> name: string`: Gets the name of a display.
- `love.window.getDisplayOrientation(displayindex: number) -> orientation: DisplayOrientation`: Gets current device display orientation.
- `love.window.getFullscreen() -> fullscreen: boolean, fstype: FullscreenType`: Gets whether the window is fullscreen.
- `love.window.getFullscreenModes(displayindex: number) -> modes: table`: Gets a list of supported fullscreen modes.
- `love.window.getIcon() -> imagedata: ImageData`: Gets the window icon.
- `love.window.getMode() -> width: number, height: number, flags: table`: Gets the display mode and properties of the window.
- `love.window.getPosition() -> x: number, y: number, displayindex: number`: Gets the position of the window on the screen. The window position is in the coordinate space of the display it is currently in.
- `love.window.getSafeArea() -> x: number, y: number, w: number, h: number`: Gets area inside the window which is known to be unobstructed by a system title bar, the iPhone X notch, etc. Useful for making sure UI elements can be seen by the user.
- `love.window.getTitle() -> title: string`: Gets the window title.
- `love.window.getVSync() -> vsync: number`: Gets current vertical synchronization (vsync).
- `love.window.hasFocus() -> focus: boolean`: Checks if the game window has keyboard focus.
- `love.window.hasMouseFocus() -> focus: boolean`: Checks if the game window has mouse focus.
- `love.window.isDisplaySleepEnabled() -> enabled: boolean`: Gets whether the display is allowed to sleep while the program is running. Display sleep is disabled by default. Some types of input (e.g. joystick button presses) might not prevent the display from sleeping, if display sleep is allowed.
- `love.window.isMaximized() -> maximized: boolean`: Gets whether the Window is currently maximized. The window can be maximized if it is not fullscreen and is resizable, and either the user has pressed the window's Maximize button or love.window.maximize has been called.
- `love.window.isMinimized() -> minimized: boolean`: Gets whether the Window is currently minimized.
- `love.window.isOpen() -> open: boolean`: Checks if the window is open.
- `love.window.isVisible() -> visible: boolean`: Checks if the game window is visible. The window is considered visible if it's not minimized and the program isn't hidden.
- `love.window.maximize()`: Makes the window as large as possible. This function has no effect if the window isn't resizable, since it essentially programmatically presses the window's 'maximize' button.
- `love.window.minimize()`: Minimizes the window to the system's task bar / dock.
- `love.window.requestAttention(continuous: boolean)`: Causes the window to request the attention of the user if it is not in the foreground. In Windows the taskbar icon will flash, and in OS X the dock icon will bounce.
- `love.window.restore()`: Restores the size and position of the window if it was minimized or maximized.
- `love.window.setDisplaySleepEnabled(enable: boolean)`: Sets whether the display is allowed to sleep while the program is running. Display sleep is disabled by default. Some types of input (e.g. joystick button presses) might not prevent the display from sleeping, if display sleep is allowed.
- `love.window.setFullscreen` - Enters or exits fullscreen. The display to use when entering fullscreen is chosen based on which display the window is currently in, if multiple monitors are connected.
  - `love.window.setFullscreen(fullscreen: boolean) -> success: boolean`: No description
  - `love.window.setFullscreen(fullscreen: boolean, fstype: FullscreenType) -> success: boolean`: If fullscreen mode is entered and the window size doesn't match one of the monitor's display modes (in normal fullscreen mode) or the window size doesn't match the desktop size (in 'desktop' fullscreen mode), the window will be resized appropriately. The window will revert back to its original size again when fullscreen mode is exited using this function.
- `love.window.setIcon(imagedata: ImageData) -> success: boolean`: Sets the window icon until the game is quit. Not all operating systems support very large icon images.
- `love.window.setMode(width: number, height: number, flags: table) -> success: boolean`: Sets the display mode and properties of the window. If width or height is 0, setMode will use the width and height of the desktop.  Changing the display mode may have side effects: for example, canvases will be cleared and values sent to shaders with canvases beforehand or re-draw to them afterward if you need to.
- `love.window.setPosition(x: number, y: number, displayindex: number)`: Sets the position of the window on the screen. The window position is in the coordinate space of the specified display.
- `love.window.setTitle(title: string)`: Sets the window title.
- `love.window.setVSync(vsync: number)`: Sets vertical synchronization mode.
- `love.window.showMessageBox` - Displays a message box dialog above the love window. The message box contains a title, optional text, and buttons.
  - `love.window.showMessageBox(title: string, message: string, type: MessageBoxType, attachtowindow: boolean) -> success: boolean`: Displays a simple message box with a single 'OK' button.
  - `love.window.showMessageBox(title: string, message: string, buttonlist: table, type: MessageBoxType, attachtowindow: boolean) -> pressedbutton: number`: Displays a message box with a customized list of buttons.
- `love.window.toPixels` - Converts a number from density-independent units to pixels. The pixel density inside the window might be greater (or smaller) than the 'size' of the window. For example on a retina screen in Mac OS X with the highdpi window flag enabled, the window may take up the same physical size as an 800x600 window, but the area inside the window uses 1600x1200 pixels. love.window.toPixels(800) would return 1600 in that case. This is used to convert coordinates from the size users are expecting them to display at onscreen to pixels. love.window.fromPixels does the opposite. The highdpi window flag must be enabled to use the full pixel density of a Retina screen on Mac OS X and iOS. The flag currently does nothing on Windows and Linux, and on Android it is effectively always enabled. Most LÖVE functions return values and expect arguments in terms of pixels rather than density-independent units.
  - `love.window.toPixels(value: number) -> pixelvalue: number`: No description
  - `love.window.toPixels(x: number, y: number) -> px: number, py: number`: The units of love.graphics.getWidth, love.graphics.getHeight, love.mouse.getPosition, mouse events, love.touch.getPosition, and touch events are always in terms of pixels.
- `love.window.updateMode(width: number, height: number, settings: table) -> success: boolean`: Sets the display mode and properties of the window, without modifying unspecified properties. If width or height is 0, updateMode will use the width and height of the desktop.  Changing the display mode may have side effects: for example, canvases will be cleared. Make sure to save the contents of canvases beforehand or re-draw to them afterward if you need to.

## Enums

- `DisplayOrientation`: Types of device display orientation.
  - `unknown`: Orientation cannot be determined.
  - `landscape`: Landscape orientation.
  - `landscapeflipped`: Landscape orientation (flipped).
  - `portrait`: Portrait orientation.
  - `portraitflipped`: Portrait orientation (flipped).

- `FullscreenType`: Types of fullscreen modes.
  - `desktop`: Sometimes known as borderless fullscreen windowed mode. A borderless screen-sized window is created which sits on top of all desktop UI elements. The window is automatically resized to match the dimensions of the desktop, and its size cannot be changed.
  - `exclusive`: Standard exclusive-fullscreen mode. Changes the display mode (actual resolution) of the monitor.
  - `normal`: Standard exclusive-fullscreen mode. Changes the display mode (actual resolution) of the monitor.

- `MessageBoxType`: Types of message box dialogs. Different types may have slightly different looks.
  - `info`: Informational dialog.
  - `warning`: Warning dialog.
  - `error`: Error dialog.

## Examples

### Creating a window
```lua
-- Set window properties in love.conf
function love.conf(t)
  t.window.title = "My Awesome Game"
  t.window.width = 800
  t.window.height = 600
  t.window.fullscreen = false
end
```

### Handling window resize
```lua
function love.resize(w, h)
  -- Update game view to match new window size
  gameWidth, gameHeight = w, h
  -- Recalculate any UI elements or camera settings
end
```

## Best practices
- Set window properties in love.conf() for best results
- Handle window resize events gracefully
- Test different display modes on target platforms
- Consider aspect ratio when designing for multiple resolutions
- Be mindful of fullscreen performance implications

## Platform compatibility
- **Desktop (Windows, macOS, Linux)**: Full window management support
- **Mobile (iOS, Android)**: Limited window control, mostly fullscreen
- **Web**: Browser window management with some limitations
