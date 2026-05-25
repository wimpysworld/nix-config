---
name: love-thread
description: Allows you to work with threads. Threads are separate Lua environments, running in parallel to the main code. As their code runs separately, they can be used to compute complex operations without adversely affecting the frame rate of the main thread. However, as they are separate environments, they cannot access the variables and functions of the main thread, and communication between threads is limited. All LOVE objects (userdata) are shared among threads so you'll only have to send their references across threads. You may run into concurrency issues if you manipulate an object on multiple threads at the same time. When a Thread is started, it only loads the love.thread module. Every other module has to be loaded with require. Use this skill when working with multi-threading, parallel processing, background tasks, or any thread-related operations in LÖVE games.
license: MIT
metadata:
  author: Ron Dekker <rondekker.nl>
---

## When to use this skill
Allows you to work with threads. Threads are separate Lua environments, running in parallel to the main code. As their code runs separately, they can be used to compute complex operations without adversely affecting the frame rate of the main thread. However, as they are separate environments, they cannot access the variables and functions of the main thread, and communication between threads is limited. All LOVE objects (userdata) are shared among threads so you'll only have to send their references across threads. You may run into concurrency issues if you manipulate an object on multiple threads at the same time. When a Thread is started, it only loads the love.thread module. Every other module has to be loaded with require. Use this skill when working with multi-threading, parallel processing, background tasks, or any thread-related operations in LÖVE games.

## Common use cases
- Running CPU-intensive operations in background threads
- Implementing parallel processing for performance
- Handling long-running tasks without blocking the main game loop
- Managing inter-thread communication and synchronization
- Loading resources asynchronously

## Functions

- `love.thread.getChannel(name: string) -> channel: Channel`: Creates or retrieves a named thread channel.
- `love.thread.newChannel() -> channel: Channel`: Create a new unnamed thread channel. One use for them is to pass new unnamed channels to other threads via Channel:push on a named channel.
- `love.thread.newThread` - Creates a new Thread from a filename, string or FileData object containing Lua code.
  - `love.thread.newThread(filename: string) -> thread: Thread`: No description
  - `love.thread.newThread(fileData: FileData) -> thread: Thread`: No description
  - `love.thread.newThread(codestring: string) -> thread: Thread`: No description

## Types

- `Channel`: An object which can be used to send and receive data between different threads.
  - `love.Channel.clear()`: Clears all the messages in the Channel queue.
  - `love.Channel.demand() -> value: Variant`: Retrieves the value of a Channel message and removes it from the message queue. It waits until a message is in the queue then returns the message value.
  - `love.Channel.getCount() -> count: number`: Retrieves the number of messages in the thread Channel queue.
  - `love.Channel.hasRead(id: number) -> hasread: boolean`: Gets whether a pushed value has been popped or otherwise removed from the Channel.
  - `love.Channel.peek() -> value: Variant`: Retrieves the value of a Channel message, but leaves it in the queue. It returns nil if there's no message in the queue.
  - `love.Channel.performAtomic(func: function, ...: any) -> ret1: any, ...: any`: Executes the specified function atomically with respect to this Channel. Calling multiple methods in a row on the same Channel is often useful. However if multiple Threads are calling this Channel's methods at the same time, the different calls on each Thread might end up interleaved (e.g. one or more of the second thread's calls may happen in between the first thread's calls.) This method avoids that issue by making sure the Thread calling the method has exclusive access to the Channel until the specified function has returned.
  - `love.Channel.pop() -> value: Variant`: Retrieves the value of a Channel message and removes it from the message queue. It returns nil if there are no messages in the queue.
  - `love.Channel.push(value: Variant) -> id: number`: Send a message to the thread Channel. See Variant for the list of supported types.
  - `love.Channel.supply(value: Variant) -> success: boolean`: Send a message to the thread Channel and wait for a thread to accept it. See Variant for the list of supported types.

- `Thread`: A Thread is a chunk of code that can run in parallel with other threads. Data can be sent between different threads with Channel objects.
  - `love.Thread.getError() -> err: string`: Retrieves the error string from the thread if it produced an error.
  - `love.Thread.isRunning() -> value: boolean`: Returns whether the thread is currently running. Threads which are not running can be (re)started with Thread:start.
  - `love.Thread.start()`: Starts the thread. Beginning with version 0.9.0, threads can be restarted after they have completed their execution.
  - `love.Thread.wait()`: Wait for a thread to finish. This call will block until the thread finishes.

## Examples

### Creating a worker thread
```lua
-- Create and start a worker thread
local thread = love.thread.newThread("worker.lua")
thread:start()

-- Send data to the thread
thread:send("process", gameData)
```

### Thread communication
```lua
-- In main thread
local channel = love.thread.getChannel("results")
local result = channel:demand()  -- Wait for result

-- In worker thread
local channel = love.thread.getChannel("results")
channel:push(computedResult)
```

## Best practices
- Use threads for CPU-intensive tasks, not I/O operations
- Minimize data transfer between threads
- Handle thread errors gracefully
- Avoid excessive thread creation
- Test thread behavior on target platforms

## Platform compatibility
- **Desktop (Windows, macOS, Linux)**: Full threading support
- **Mobile (iOS, Android)**: Limited threading support
- **Web**: No threading support (single-threaded JavaScript)
