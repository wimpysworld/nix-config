---
name: love-joystick
description: Provides an interface to the user's joystick. Use this skill when working with game controllers, joystick input, gamepad operations, or any input device-related operations in LÖVE games.
license: MIT
metadata:
  author: Ron Dekker <rondekker.nl>
---

## When to use this skill
Provides an interface to the user's joystick. Use this skill when working with game controllers, joystick input, gamepad operations, or any input device-related operations in LÖVE games.

## Common use cases
- Handling joystick and gamepad input
- Managing multiple input devices
- Implementing controller-based game mechanics
- Handling joystick events and callbacks
- Supporting various game controller types

## Functions

- `love.joystick.getGamepadMappingString(guid: string) -> mappingstring: string`: Gets the full gamepad mapping string of the Joysticks which have the given GUID, or nil if the GUID isn't recognized as a gamepad. The mapping string contains binding information used to map the Joystick's buttons an axes to the standard gamepad layout, and can be used later with love.joystick.loadGamepadMappings.
- `love.joystick.getJoystickCount() -> joystickcount: number`: Gets the number of connected joysticks.
- `love.joystick.getJoysticks() -> joysticks: table`: Gets a list of connected Joysticks.
- `love.joystick.loadGamepadMappings` - Loads a gamepad mappings string or file created with love.joystick.saveGamepadMappings. It also recognizes any SDL gamecontroller mapping string, such as those created with Steam's Big Picture controller configure interface, or this nice database. If a new mapping is loaded for an already known controller GUID, the later version will overwrite the one currently loaded.
  - `love.joystick.loadGamepadMappings(filename: string)`: Loads a gamepad mappings string from a file.
  - `love.joystick.loadGamepadMappings(mappings: string)`: Loads a gamepad mappings string directly.
- `love.joystick.saveGamepadMappings` - Saves the virtual gamepad mappings of all recognized as gamepads and have either been recently used or their gamepad bindings have been modified. The mappings are stored as a string for use with love.joystick.loadGamepadMappings.
  - `love.joystick.saveGamepadMappings(filename: string) -> mappings: string`: Saves the gamepad mappings of all relevant joysticks to a file.
  - `love.joystick.saveGamepadMappings() -> mappings: string`: Returns the mappings string without writing to a file.
- `love.joystick.setGamepadMapping` - Binds a virtual gamepad input to a button, axis or hat for all Joysticks of a certain type. For example, if this function is used with a GUID returned by a Dualshock 3 controller in OS X, the binding will affect Joystick:getGamepadAxis and Joystick:isGamepadDown for ''all'' Dualshock 3 controllers used with the game when run in OS X. LÖVE includes built-in gamepad bindings for many common controllers. This function lets you change the bindings or add new ones for types of Joysticks which aren't recognized as gamepads by default. The virtual gamepad buttons and axes are designed around the Xbox 360 controller layout.
  - `love.joystick.setGamepadMapping(guid: string, button: GamepadButton, inputtype: JoystickInputType, inputindex: number, hatdir: JoystickHat) -> success: boolean`: No description
  - `love.joystick.setGamepadMapping(guid: string, axis: GamepadAxis, inputtype: JoystickInputType, inputindex: number, hatdir: JoystickHat) -> success: boolean`: The physical locations for the bound gamepad axes and buttons should correspond as closely as possible to the layout of a standard Xbox 360 controller.

## Types

- `Joystick`: Represents a physical joystick.
  - `love.Joystick.getAxes() -> axisDir1: number, axisDir2: number, axisDirN: number`: Gets the direction of each axis.
  - `love.Joystick.getAxis(axis: number) -> direction: number`: Gets the direction of an axis.
  - `love.Joystick.getAxisCount() -> axes: number`: Gets the number of axes on the joystick.
  - `love.Joystick.getButtonCount() -> buttons: number`: Gets the number of buttons on the joystick.
  - `love.Joystick.getDeviceInfo() -> vendorID: number, productID: number, productVersion: number`: Gets the USB vendor ID, product ID, and product version numbers of joystick which consistent across operating systems. Can be used to show different icons, etc. for different gamepads.
  - `love.Joystick.getGUID() -> guid: string`: Gets a stable GUID unique to the type of the physical joystick which does not change over time. For example, all Sony Dualshock 3 controllers in OS X have the same GUID. The value is platform-dependent.
  - `love.Joystick.getGamepadAxis(axis: GamepadAxis) -> direction: number`: Gets the direction of a virtual gamepad axis. If the Joystick isn't recognized as a gamepad or isn't connected, this function will always return 0.
  - `love.Joystick.getGamepadMapping(axis: GamepadAxis) -> inputtype: JoystickInputType, inputindex: number, hatdirection: JoystickHat`: Gets the button, axis or hat that a virtual gamepad input is bound to.
  - `love.Joystick.getGamepadMappingString() -> mappingstring: string`: Gets the full gamepad mapping string of this Joystick, or nil if it's not recognized as a gamepad. The mapping string contains binding information used to map the Joystick's buttons an axes to the standard gamepad layout, and can be used later with love.joystick.loadGamepadMappings.
  - `love.Joystick.getHat(hat: number) -> direction: JoystickHat`: Gets the direction of the Joystick's hat.
  - `love.Joystick.getHatCount() -> hats: number`: Gets the number of hats on the joystick.
  - `love.Joystick.getID() -> id: number, instanceid: number`: Gets the joystick's unique identifier. The identifier will remain the same for the life of the game, even when the Joystick is disconnected and reconnected, but it '''will''' change when the game is re-launched.
  - `love.Joystick.getName() -> name: string`: Gets the name of the joystick.
  - `love.Joystick.getVibration() -> left: number, right: number`: Gets the current vibration motor strengths on a Joystick with rumble support.
  - `love.Joystick.isConnected() -> connected: boolean`: Gets whether the Joystick is connected.
  - `love.Joystick.isDown(buttonN: number) -> anyDown: boolean`: Checks if a button on the Joystick is pressed. LÖVE 0.9.0 had a bug which required the button indices passed to Joystick:isDown to be 0-based instead of 1-based, for example button 1 would be 0 for this function. It was fixed in 0.9.1.
  - `love.Joystick.isGamepad() -> isgamepad: boolean`: Gets whether the Joystick is recognized as a gamepad. If this is the case, the Joystick's buttons and axes can be used in a standardized manner across different operating systems and joystick models via Joystick:getGamepadAxis, Joystick:isGamepadDown, love.gamepadpressed, and related functions. LÖVE automatically recognizes most popular controllers with a similar layout to the Xbox 360 controller as gamepads, but you can add more with love.joystick.setGamepadMapping.
  - `love.Joystick.isGamepadDown(buttonN: GamepadButton) -> anyDown: boolean`: Checks if a virtual gamepad button on the Joystick is pressed. If the Joystick is not recognized as a Gamepad or isn't connected, then this function will always return false.
  - `love.Joystick.isVibrationSupported() -> supported: boolean`: Gets whether the Joystick supports vibration.
  - `love.Joystick.setVibration(left: number, right: number) -> success: boolean`: Sets the vibration motor speeds on a Joystick with rumble support. Most common gamepads have this functionality, although not all drivers give proper support. Use Joystick:isVibrationSupported to check.

## Enums

- `GamepadAxis`: Virtual gamepad axes.
  - `leftx`: The x-axis of the left thumbstick.
  - `lefty`: The y-axis of the left thumbstick.
  - `rightx`: The x-axis of the right thumbstick.
  - `righty`: The y-axis of the right thumbstick.
  - `triggerleft`: Left analog trigger.
  - `triggerright`: Right analog trigger.

- `GamepadButton`: Virtual gamepad buttons.
  - `a`: Bottom face button (A).
  - `b`: Right face button (B).
  - `x`: Left face button (X).
  - `y`: Top face button (Y).
  - `back`: Back button.
  - `guide`: Guide button.
  - `start`: Start button.
  - `leftstick`: Left stick click button.
  - `rightstick`: Right stick click button.
  - `leftshoulder`: Left bumper.
  - `rightshoulder`: Right bumper.
  - `dpup`: D-pad up.
  - `dpdown`: D-pad down.
  - `dpleft`: D-pad left.
  - `dpright`: D-pad right.

- `JoystickHat`: Joystick hat positions.
  - `c`: Centered
  - `d`: Down
  - `l`: Left
  - `ld`: Left+Down
  - `lu`: Left+Up
  - `r`: Right
  - `rd`: Right+Down
  - `ru`: Right+Up
  - `u`: Up

- `JoystickInputType`: Types of Joystick inputs.
  - `axis`: Analog axis.
  - `button`: Button.
  - `hat`: 8-direction hat value.

## Examples

### Handling joystick input
```lua
function love.joystickpressed(joystick, button)
  if button == 1 then
    -- Handle primary action button
    player.jump()
  elseif button == 2 then
    -- Handle secondary action button
    player.attack()
  end
end
```

### Getting joystick axis values
```lua
function love.update(dt)
  local joysticks = love.joystick.getJoysticks()
  for i, joystick in ipairs(joysticks) do
    local leftX = joystick:getAxis(1)  -- Left stick X axis
    local leftY = joystick:getAxis(2)  -- Left stick Y axis

    -- Apply movement based on joystick input
    player.move(leftX, leftY)
  end
end
```

## Best practices
- Support both keyboard and joystick input for accessibility
- Handle joystick connection/disconnection gracefully
- Test with various controller types
- Consider controller dead zones and sensitivity
- Provide controller configuration options

## Platform compatibility
- **Desktop (Windows, macOS, Linux)**: Full joystick support
- **Mobile (iOS, Android)**: Limited to touch-based virtual controllers
- **Web**: Browser-based gamepad API support
