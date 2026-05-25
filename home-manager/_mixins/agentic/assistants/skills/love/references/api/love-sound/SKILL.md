---
name: love-sound
description: This module is responsible for decoding sound files. It can't play the sounds, see love.audio for that. Use this skill when working with sound operations, audio decoding, sound data manipulation, or any sound-related operations in LÖVE games.
license: MIT
metadata:
  author: Ron Dekker <rondekker.nl>
---

## When to use this skill
This module is responsible for decoding sound files. It can't play the sounds, see love.audio for that. Use this skill when working with sound operations, audio decoding, sound data manipulation, or any sound-related operations in LÖVE games.

## Common use cases
- Decoding sound files and formats
- Managing sound data and audio buffers
- Performing sound transformations and effects
- Working with compressed audio formats
- Handling sound metadata and properties

## Functions

- `love.sound.newDecoder` - Attempts to find a decoder for the encoded sound data in the specified file.
  - `love.sound.newDecoder(file: File, buffer: number) -> decoder: Decoder`: No description
  - `love.sound.newDecoder(filename: string, buffer: number) -> decoder: Decoder`: No description
- `love.sound.newSoundData` - Creates new SoundData from a filepath, File, or Decoder. It's also possible to create SoundData with a custom sample rate, channel and bit depth. The sound data will be decoded to the memory in a raw format. It is recommended to create only short sounds like effects, as a 3 minute song uses 30 MB of memory this way.
  - `love.sound.newSoundData(filename: string) -> soundData: SoundData`: No description
  - `love.sound.newSoundData(file: File) -> soundData: SoundData`: No description
  - `love.sound.newSoundData(decoder: Decoder) -> soundData: SoundData`: No description
  - `love.sound.newSoundData(samples: number, rate: number, bits: number, channels: number) -> soundData: SoundData`: No description

## Types

- `Decoder`: An object which can gradually decode a sound file.
  - `love.Decoder.clone() -> decoder: Decoder`: Creates a new copy of current decoder. The new decoder will start decoding from the beginning of the audio stream.
  - `love.Decoder.decode() -> soundData: SoundData`: Decodes the audio and returns a SoundData object containing the decoded audio data.
  - `love.Decoder.getBitDepth() -> bitDepth: number`: Returns the number of bits per sample.
  - `love.Decoder.getChannelCount() -> channels: number`: Returns the number of channels in the stream.
  - `love.Decoder.getDuration() -> duration: number`: Gets the duration of the sound file. It may not always be sample-accurate, and it may return -1 if the duration cannot be determined at all.
  - `love.Decoder.getSampleRate() -> rate: number`: Returns the sample rate of the Decoder.
  - `love.Decoder.seek(offset: number)`: Sets the currently playing position of the Decoder.

- `SoundData`: Contains raw audio samples. You can not play SoundData back directly. You must wrap a Source object around it.
  - `love.SoundData.getBitDepth() -> bitdepth: number`: Returns the number of bits per sample.
  - `love.SoundData.getChannelCount() -> channels: number`: Returns the number of channels in the SoundData.
  - `love.SoundData.getDuration() -> duration: number`: Gets the duration of the sound data.
  - `love.SoundData.getSample(i: number) -> sample: number`: Gets the value of the sample-point at the specified position. For stereo SoundData objects, the data from the left and right channels are interleaved in that order.
  - `love.SoundData.getSampleCount() -> count: number`: Returns the number of samples per channel of the SoundData.
  - `love.SoundData.getSampleRate() -> rate: number`: Returns the sample rate of the SoundData.
  - `love.SoundData.setSample(i: number, sample: number)`: Sets the value of the sample-point at the specified position. For stereo SoundData objects, the data from the left and right channels are interleaved in that order.

## Examples

### Decoding sound data
```lua
-- Decode a sound file
local soundData = love.sound.newSoundData("effect.wav")

-- Play the sound
local source = love.audio.newSource(soundData)
love.audio.play(source)
```

### Sound data manipulation
```lua
-- Create and modify sound data
local sampleRate = 44100
local bitDepth = 16
local channels = 1
local duration = 1.0  -- 1 second

local soundData = love.sound.newSoundData(
  sampleRate * duration,
  sampleRate,
  bitDepth,
  channels
)

-- Generate a simple sine wave
for i = 0, soundData:getSampleCount() - 1 do
  local time = i / sampleRate
  local value = math.sin(time * 440 * 2 * math.pi)  -- 440Hz sine wave
  soundData:setSample(i, value)
end

-- Create and play the sound
local source = love.audio.newSource(soundData)
love.audio.play(source)
```

## Best practices
- Use appropriate sound formats for different use cases
- Consider memory usage when working with large sound files
- Handle sound decoding errors gracefully
- Test sound formats on target platforms
- Be mindful of performance with real-time sound processing

## Platform compatibility
- **Desktop (Windows, macOS, Linux)**: Full sound support
- **Mobile (iOS, Android)**: Full support with some format limitations
- **Web**: Good support but some formats may not be available
