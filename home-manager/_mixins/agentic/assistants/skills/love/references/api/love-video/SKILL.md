---
name: love-video
description: This module is responsible for decoding, controlling, and streaming video files. It can't draw the videos, see love.graphics.newVideo and Video objects for that. Use this skill when working with video operations, video decoding, video streaming, or any video-related operations in LÖVE games.
license: MIT
metadata:
  author: Ron Dekker <rondekker.nl>
---

## When to use this skill
This module is responsible for decoding, controlling, and streaming video files. It can't draw the videos, see love.graphics.newVideo and Video objects for that. Use this skill when working with video operations, video decoding, video streaming, or any video-related operations in LÖVE games.

## Common use cases
- Playing video files and streams
- Managing video playback and control
- Handling video decoding and processing
- Implementing video-based game elements
- Working with video metadata and properties

## Functions

- `love.video.newVideoStream` - Creates a new VideoStream. Currently only Ogg Theora video files are supported. VideoStreams can't draw videos, see love.graphics.newVideo for that.
  - `love.video.newVideoStream(filename: string) -> videostream: VideoStream`: No description
  - `love.video.newVideoStream(file: File) -> videostream: VideoStream`: No description

## Types

- `VideoStream`: An object which decodes, streams, and controls Videos.
  - `love.VideoStream.getFilename() -> filename: string`: Gets the filename of the VideoStream.
  - `love.VideoStream.isPlaying() -> playing: boolean`: Gets whether the VideoStream is playing.
  - `love.VideoStream.pause()`: Pauses the VideoStream.
  - `love.VideoStream.play()`: Plays the VideoStream.
  - `love.VideoStream.rewind()`: Rewinds the VideoStream. Synonym to VideoStream:seek(0).
  - `love.VideoStream.seek(offset: number)`: Sets the current playback position of the VideoStream.
  - `love.VideoStream.tell() -> seconds: number`: Gets the current playback position of the VideoStream.

## Examples

### Playing a video
```lua
-- Load and play a video file
local video = love.graphics.newVideo("intro.mp4")
video:play()

function love.draw()
  if video:isPlaying() then
    love.graphics.draw(video, 0, 0)
  end
end
```

### Video control
```lua
-- Control video playback
function love.keypressed(key)
  if key == "space" then
    if video:isPlaying() then
      video:pause()
    else
      video:play()
    end
  elseif key == "escape" then
    video:stop()
  end
end
```

## Best practices
- Preload videos during loading screens
- Consider performance implications of video playback
- Use appropriate video formats and codecs
- Handle video loading and playback errors gracefully
- Test video playback on target platforms

## Platform compatibility
- **Desktop (Windows, macOS, Linux)**: Full video support
- **Mobile (iOS, Android)**: Limited video format support
- **Web**: Browser-based video support with format limitations
