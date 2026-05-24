---
name: love-system
description: Provides access to information about the user's system. Use this skill when working with system operations, platform detection, system information retrieval, or any system-related operations in LÖVE games.
license: MIT
metadata:
  author: Ron Dekker <rondekker.nl>
---

## When to use this skill
Provides access to information about the user's system. Use this skill when working with system operations, platform detection, system information retrieval, or any system-related operations in LÖVE games.

## Common use cases
- Retrieving system and platform information
- Detecting operating system and hardware capabilities
- Accessing system-specific features
- Handling platform-specific behavior
- Managing system resources and capabilities

## Functions

- `love.system.getClipboardText() -> text: string`: Gets text from the clipboard.
- `love.system.getOS() -> osString: string`: Gets the current operating system. In general, LÖVE abstracts away the need to know the current operating system, but there are a few cases where it can be useful (especially in combination with os.execute.)
- `love.system.getPowerInfo() -> state: PowerState, percent: number, seconds: number`: Gets information about the system's power supply.
- `love.system.getProcessorCount() -> processorCount: number`: Gets the amount of logical processor in the system.
- `love.system.hasBackgroundMusic() -> backgroundmusic: boolean`: Gets whether another application on the system is playing music in the background. Currently this is implemented on iOS and Android, and will always return false on other operating systems. The t.audio.mixwithsystem flag in love.conf can be used to configure whether background audio / music from other apps should play while LÖVE is open.
- `love.system.openURL(url: string) -> success: boolean`: Opens a URL with the user's web or file browser.
- `love.system.setClipboardText(text: string)`: Puts text in the clipboard.
- `love.system.vibrate(seconds: number)`: Causes the device to vibrate, if possible. Currently this will only work on Android and iOS devices that have a built-in vibration motor.

## Enums

- `PowerState`: The basic state of the system's power supply.
  - `unknown`: Cannot determine power status.
  - `battery`: Not plugged in, running on a battery.
  - `nobattery`: Plugged in, no battery available.
  - `charging`: Plugged in, charging battery.
  - `charged`: Plugged in, battery is fully charged.

## Examples

### Platform detection
```lua
-- Detect current platform
local platform = love.system.getOS()
if platform == "Windows" then
  -- Windows-specific code
elseif platform == "OS X" then
  -- macOS-specific code
elseif platform == "Linux" then
  -- Linux-specific code
end
```

### System information
```lua
-- Get system information
local cpuCores = love.system.getProcessorCount()
local ramMB = love.system.getMemoryUsage() / (1024 * 1024)

print("CPU Cores: " .. cpuCores)
print("Memory Usage: " .. string.format("%.2f", ramMB) .. " MB")
```

## Best practices
- Use system information for platform-specific optimizations
- Handle platform differences gracefully
- Consider performance when accessing system information frequently
- Test on target platforms for compatibility
- Be mindful of privacy when accessing system information

## Platform compatibility
- **Desktop (Windows, macOS, Linux)**: Full system support
- **Mobile (iOS, Android)**: Limited system information access
- **Web**: Very limited system access due to browser restrictions
