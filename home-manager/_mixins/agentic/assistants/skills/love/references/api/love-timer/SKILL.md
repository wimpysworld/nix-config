---
name: love-timer
description: Provides an interface to the user's clock. Use this skill when working with time measurement, frame rate control, performance monitoring, or any time-related operations in LÖVE games.
license: MIT
metadata:
  author: Ron Dekker <rondekker.nl>
---

## When to use this skill
Provides an interface to the user's clock. Use this skill when working with time measurement, frame rate control, performance monitoring, or any time-related operations in LÖVE games.

## Common use cases
- Measuring elapsed time and performance
- Controlling game frame rate and timing
- Implementing smooth animations and transitions
- Profiling and optimizing game performance
- Handling time-based game mechanics

## Functions

- `love.timer.getAverageDelta() -> delta: number`: Returns the average delta time (seconds per frame) over the last second.
- `love.timer.getDelta() -> dt: number`: Returns the time between the last two frames.
- `love.timer.getFPS() -> fps: number`: Returns the current frames per second.
- `love.timer.getTime() -> time: number`: Returns the value of a timer with an unspecified starting time. This function should only be used to calculate differences between points in time, as the starting time of the timer is unknown.
- `love.timer.sleep(s: number)`: Pauses the current thread for the specified amount of time.
- `love.timer.step() -> dt: number`: Measures the time between two frames. Calling this changes the return value of love.timer.getDelta.

## Examples

### Measuring delta time
```lua
-- Use delta time for frame-rate independent movement
function love.update(dt)
  local moveSpeed = 200  -- pixels per second
  local distance = moveSpeed * dt
  player.x = player.x + distance
end
```

### Performance measurement
```lua
-- Measure function execution time
local startTime = love.timer.getTime()

-- Perform some operations
complexOperation()

local endTime = love.timer.getTime()
local elapsed = endTime - startTime
print("Operation took: " .. elapsed .. " seconds")
```

## Best practices
- Use delta time (dt) for all time-based calculations
- Consider using love.timer for high-precision timing
- Be mindful of performance when using frequent timing calls
- Test timing behavior on target platforms
- Use appropriate time units for different measurements

## Platform compatibility
- **Desktop (Windows, macOS, Linux)**: Full timer support
- **Mobile (iOS, Android)**: Full support
- **Web**: Full support
