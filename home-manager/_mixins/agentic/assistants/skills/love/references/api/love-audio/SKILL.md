---
name: love-audio
description: Provides an interface to create noise with the user's speakers. Use this skill when working with sound effects, music playback, audio recording, or any audio-related operations in LÖVE games.
license: MIT
metadata:
  author: Ron Dekker <rondekker.nl>
---

## When to use this skill
Provides an interface to create noise with the user's speakers. Use this skill when working with sound effects, music playback, audio recording, or any audio-related operations in LÖVE games.

## Common use cases
- Playing background music and sound effects
- Implementing dynamic audio for game events
- Recording and processing audio input
- Creating immersive 3D audio experiences
- Managing multiple audio sources simultaneously

## Functions

- `love.audio.getActiveEffects() -> effects: table`: Gets a list of the names of the currently enabled effects.
- `love.audio.getActiveSourceCount() -> count: number`: Gets the current number of simultaneously playing sources.
- `love.audio.getDistanceModel() -> model: DistanceModel`: Returns the distance attenuation model.
- `love.audio.getDopplerScale() -> scale: number`: Gets the current global scale factor for velocity-based doppler effects.
- `love.audio.getEffect(name: string) -> settings: table`: Gets the settings associated with an effect.
- `love.audio.getMaxSceneEffects() -> maximum: number`: Gets the maximum number of active effects supported by the system.
- `love.audio.getMaxSourceEffects() -> maximum: number`: Gets the maximum number of active Effects in a single Source object, that the system can support.
- `love.audio.getOrientation() -> fx: number, fy: number, fz: number, ux: number, uy: number, uz: number`: Returns the orientation of the listener.
- `love.audio.getPosition() -> x: number, y: number, z: number`: Returns the position of the listener. Please note that positional audio only works for mono (i.e. non-stereo) sources.
- `love.audio.getRecordingDevices() -> devices: table`: Gets a list of RecordingDevices on the system. The first device in the list is the user's default recording device. The list may be empty if there are no microphones connected to the system. Audio recording is currently not supported on iOS.
- `love.audio.getVelocity() -> x: number, y: number, z: number`: Returns the velocity of the listener.
- `love.audio.getVolume() -> volume: number`: Returns the master volume.
- `love.audio.isEffectsSupported() -> supported: boolean`: Gets whether audio effects are supported in the system.
- `love.audio.newQueueableSource(samplerate: number, bitdepth: number, channels: number, buffercount: number) -> source: Source`: Creates a new Source usable for real-time generated sound playback with Source:queue.
- `love.audio.newSource` - Creates a new Source from a filepath, File, Decoder or SoundData. Sources created from SoundData are always static.
  - `love.audio.newSource(filename: string, type: SourceType) -> source: Source`: No description
  - `love.audio.newSource(file: File, type: SourceType) -> source: Source`: No description
  - `love.audio.newSource(decoder: Decoder, type: SourceType) -> source: Source`: No description
  - `love.audio.newSource(data: FileData, type: SourceType) -> source: Source`: No description
  - `love.audio.newSource(data: SoundData) -> source: Source`: No description
- `love.audio.pause` - Pauses specific or all currently played Sources.
  - `love.audio.pause() -> Sources: table`: Pauses all currently active Sources and returns them.
  - `love.audio.pause(source: Source, ...: Source)`: Pauses the given Sources.
  - `love.audio.pause(sources: table)`: Pauses the given Sources.
- `love.audio.play` - Plays the specified Source.
  - `love.audio.play(source: Source)`: No description
  - `love.audio.play(sources: table)`: Starts playing multiple Sources simultaneously.
  - `love.audio.play(source1: Source, source2: Source, ...: Source)`: Starts playing multiple Sources simultaneously.
- `love.audio.setDistanceModel(model: DistanceModel)`: Sets the distance attenuation model.
- `love.audio.setDopplerScale(scale: number)`: Sets a global scale factor for velocity-based doppler effects. The default scale value is 1.
- `love.audio.setEffect` - Defines an effect that can be applied to a Source. Not all system supports audio effects. Use love.audio.isEffectsSupported to check.
  - `love.audio.setEffect(name: string, settings: table) -> success: boolean`: No description
  - `love.audio.setEffect(name: string, enabled: boolean) -> success: boolean`: No description
- `love.audio.setMixWithSystem(mix: boolean) -> success: boolean`: Sets whether the system should mix the audio with the system's audio.
- `love.audio.setOrientation(fx, fy, fz: number, ux, uy, uz: number)`: Sets the orientation of the listener.
- `love.audio.setPosition(x: number, y: number, z: number)`: Sets the position of the listener, which determines how sounds play.
- `love.audio.setVelocity(x: number, y: number, z: number)`: Sets the velocity of the listener.
- `love.audio.setVolume(volume: number)`: Sets the master volume.
- `love.audio.stop` - Stops currently played sources.
  - `love.audio.stop()`: This function will stop all currently active sources.
  - `love.audio.stop(source: Source)`: This function will only stop the specified source.
  - `love.audio.stop(source1: Source, source2: Source, ...: Source)`: Simultaneously stops all given Sources.
  - `love.audio.stop(sources: table)`: Simultaneously stops all given Sources.

## Types

- `RecordingDevice`: Represents an audio input device capable of recording sounds.
  - `love.RecordingDevice.getBitDepth() -> bits: number`: Gets the number of bits per sample in the data currently being recorded.
  - `love.RecordingDevice.getChannelCount() -> channels: number`: Gets the number of channels currently being recorded (mono or stereo).
  - `love.RecordingDevice.getData() -> data: SoundData`: Gets all recorded audio SoundData stored in the device's internal ring buffer. The internal ring buffer is cleared when this function is called, so calling it again will only get audio recorded after the previous call. If the device's internal ring buffer completely fills up before getData is called, the oldest data that doesn't fit into the buffer will be lost.
  - `love.RecordingDevice.getName() -> name: string`: Gets the name of the recording device.
  - `love.RecordingDevice.getSampleCount() -> samples: number`: Gets the number of currently recorded samples.
  - `love.RecordingDevice.getSampleRate() -> rate: number`: Gets the number of samples per second currently being recorded.
  - `love.RecordingDevice.isRecording() -> recording: boolean`: Gets whether the device is currently recording.
  - `love.RecordingDevice.start(samplecount: number, samplerate: number, bitdepth: number, channels: number) -> success: boolean`: Begins recording audio using this device.
  - `love.RecordingDevice.stop() -> data: SoundData`: Stops recording audio from this device. Any sound data currently in the device's buffer will be returned.

- `Source`: A Source represents audio you can play back. You can do interesting things with Sources, like set the volume, pitch, and its position relative to the listener. Please note that positional audio only works for mono (i.e. non-stereo) sources. The Source controls (play/pause/stop) act according to the following state table.
  - `love.Source.clone() -> source: Source`: Creates an identical copy of the Source in the stopped state. Static Sources will use significantly less memory and take much less time to be created if Source:clone is used to create them instead of love.audio.newSource, so this method should be preferred when making multiple Sources which play the same sound.
  - `love.Source.getActiveEffects() -> effects: table`: Gets a list of the Source's active effect names.
  - `love.Source.getAirAbsorption() -> amount: number`: Gets the amount of air absorption applied to the Source. By default the value is set to 0 which means that air absorption effects are disabled. A value of 1 will apply high frequency attenuation to the Source at a rate of 0.05 dB per meter.
  - `love.Source.getAttenuationDistances() -> ref: number, max: number`: Gets the reference and maximum attenuation distances of the Source. The values, combined with the current DistanceModel, affect how the Source's volume attenuates based on distance from the listener.
  - `love.Source.getChannelCount() -> channels: number`: Gets the number of channels in the Source. Only 1-channel (mono) Sources can use directional and positional effects.
  - `love.Source.getCone() -> innerAngle: number, outerAngle: number, outerVolume: number`: Gets the Source's directional volume cones. Together with Source:setDirection, the cone angles allow for the Source's volume to vary depending on its direction.
  - `love.Source.getDirection() -> x: number, y: number, z: number`: Gets the direction of the Source.
  - `love.Source.getDuration(unit: TimeUnit) -> duration: number`: Gets the duration of the Source. For streaming Sources it may not always be sample-accurate, and may return -1 if the duration cannot be determined at all.
  - `love.Source.getEffect(name: string, filtersettings: table) -> filtersettings: table`: Gets the filter settings associated to a specific effect. This function returns nil if the effect was applied with no filter settings associated to it.
  - `love.Source.getFilter() -> settings: table`: Gets the filter settings currently applied to the Source.
  - `love.Source.getFreeBufferCount() -> buffers: number`: Gets the number of free buffer slots in a queueable Source. If the queueable Source is playing, this value will increase up to the amount the Source was created with. If the queueable Source is stopped, it will process all of its internal buffers first, in which case this function will always return the amount it was created with.
  - `love.Source.getPitch() -> pitch: number`: Gets the current pitch of the Source.
  - `love.Source.getPosition() -> x: number, y: number, z: number`: Gets the position of the Source.
  - `love.Source.getRolloff() -> rolloff: number`: Returns the rolloff factor of the source.
  - `love.Source.getType() -> sourcetype: SourceType`: Gets the type of the Source.
  - `love.Source.getVelocity() -> x: number, y: number, z: number`: Gets the velocity of the Source.
  - `love.Source.getVolume() -> volume: number`: Gets the current volume of the Source.
  - `love.Source.getVolumeLimits() -> min: number, max: number`: Returns the volume limits of the source.
  - `love.Source.isLooping() -> loop: boolean`: Returns whether the Source will loop.
  - `love.Source.isPlaying() -> playing: boolean`: Returns whether the Source is playing.
  - `love.Source.isRelative() -> relative: boolean`: Gets whether the Source's position, velocity, direction, and cone angles are relative to the listener.
  - `love.Source.pause()`: Pauses the Source.
  - `love.Source.play() -> success: boolean`: Starts playing the Source.
  - `love.Source.queue(sounddata: SoundData) -> success: boolean`: Queues SoundData for playback in a queueable Source. This method requires the Source to be created via love.audio.newQueueableSource.
  - `love.Source.seek(offset: number, unit: TimeUnit)`: Sets the currently playing position of the Source.
  - `love.Source.setAirAbsorption(amount: number)`: Sets the amount of air absorption applied to the Source. By default the value is set to 0 which means that air absorption effects are disabled. A value of 1 will apply high frequency attenuation to the Source at a rate of 0.05 dB per meter. Air absorption can simulate sound transmission through foggy air, dry air, smoky atmosphere, etc. It can be used to simulate different atmospheric conditions within different locations in an area.
  - `love.Source.setAttenuationDistances(ref: number, max: number)`: Sets the reference and maximum attenuation distances of the Source. The parameters, combined with the current DistanceModel, affect how the Source's volume attenuates based on distance. Distance attenuation is only applicable to Sources based on mono (rather than stereo) audio.
  - `love.Source.setCone(innerAngle: number, outerAngle: number, outerVolume: number)`: Sets the Source's directional volume cones. Together with Source:setDirection, the cone angles allow for the Source's volume to vary depending on its direction.
  - `love.Source.setDirection(x: number, y: number, z: number)`: Sets the direction vector of the Source. A zero vector makes the source non-directional.
  - `love.Source.setEffect(name: string, enable: boolean) -> success: boolean`: Applies an audio effect to the Source. The effect must have been previously defined using love.audio.setEffect.
  - `love.Source.setFilter(settings: table) -> success: boolean`: Sets a low-pass, high-pass, or band-pass filter to apply when playing the Source.
  - `love.Source.setLooping(loop: boolean)`: Sets whether the Source should loop.
  - `love.Source.setPitch(pitch: number)`: Sets the pitch of the Source.
  - `love.Source.setPosition(x: number, y: number, z: number)`: Sets the position of the Source. Please note that this only works for mono (i.e. non-stereo) sound files!
  - `love.Source.setRelative(enable: boolean)`: Sets whether the Source's position, velocity, direction, and cone angles are relative to the listener, or absolute. By default, all sources are absolute and therefore relative to the origin of love's coordinate system 0, 0. Only absolute sources are affected by the position of the listener. Please note that positional audio only works for mono (i.e. non-stereo) sources. 
  - `love.Source.setRolloff(rolloff: number)`: Sets the rolloff factor which affects the strength of the used distance attenuation. Extended information and detailed formulas can be found in the chapter '3.4. Attenuation By Distance' of OpenAL 1.1 specification.
  - `love.Source.setVelocity(x: number, y: number, z: number)`: Sets the velocity of the Source. This does '''not''' change the position of the Source, but lets the application know how it has to calculate the doppler effect.
  - `love.Source.setVolume(volume: number)`: Sets the current volume of the Source.
  - `love.Source.setVolumeLimits(min: number, max: number)`: Sets the volume limits of the source. The limits have to be numbers from 0 to 1.
  - `love.Source.stop()`: Stops a Source.
  - `love.Source.tell(unit: TimeUnit) -> position: number`: Gets the currently playing position of the Source.

## Enums

- `DistanceModel`: The different distance models. Extended information can be found in the chapter "3.4. Attenuation By Distance" of the OpenAL 1.1 specification.
  - `none`: Sources do not get attenuated.
  - `inverse`: Inverse distance attenuation.
  - `inverseclamped`: Inverse distance attenuation. Gain is clamped. In version 0.9.2 and older this is named '''inverse clamped'''.
  - `linear`: Linear attenuation.
  - `linearclamped`: Linear attenuation. Gain is clamped. In version 0.9.2 and older this is named '''linear clamped'''.
  - `exponent`: Exponential attenuation.
  - `exponentclamped`: Exponential attenuation. Gain is clamped. In version 0.9.2 and older this is named '''exponent clamped'''.

- `EffectType`: The different types of effects supported by love.audio.setEffect.
  - `chorus`: Plays multiple copies of the sound with slight pitch and time variation. Used to make sounds sound "fuller" or "thicker".
  - `compressor`: Decreases the dynamic range of the sound, making the loud and quiet parts closer in volume, producing a more uniform amplitude throughout time.
  - `distortion`: Alters the sound by amplifying it until it clips, shearing off parts of the signal, leading to a compressed and distorted sound.
  - `echo`: Decaying feedback based effect, on the order of seconds. Also known as delay; causes the sound to repeat at regular intervals at a decreasing volume.
  - `equalizer`: Adjust the frequency components of the sound using a 4-band (low-shelf, two band-pass and a high-shelf) equalizer.
  - `flanger`: Plays two copies of the sound; while varying the phase, or equivalently delaying one of them, by amounts on the order of milliseconds, resulting in phasing sounds.
  - `reverb`: Decaying feedback based effect, on the order of milliseconds. Used to simulate the reflection off of the surroundings.
  - `ringmodulator`: An implementation of amplitude modulation; multiplies the source signal with a simple waveform, to produce either volume changes, or inharmonic overtones.

- `EffectWaveform`: The different types of waveforms that can be used with the '''ringmodulator''' EffectType.
  - `sawtooth`: A sawtooth wave, also known as a ramp wave. Named for its linear rise, and (near-)instantaneous fall along time.
  - `sine`: A sine wave. Follows a trigonometric sine function.
  - `square`: A square wave. Switches between high and low states (near-)instantaneously.
  - `triangle`: A triangle wave. Follows a linear rise and fall that repeats periodically.

- `FilterType`: Types of filters for Sources.
  - `lowpass`: Low-pass filter. High frequency sounds are attenuated.
  - `highpass`: High-pass filter. Low frequency sounds are attenuated.
  - `bandpass`: Band-pass filter. Both high and low frequency sounds are attenuated based on the given parameters.

- `SourceType`: Types of audio sources. A good rule of thumb is to use stream for music files and static for all short sound effects. Basically, you want to avoid loading large files into memory at once.
  - `static`: The whole audio is decoded.
  - `stream`: The audio is decoded in chunks when needed.
  - `queue`: The audio must be manually queued by the user.

- `TimeUnit`: Units that represent time.
  - `seconds`: Regular seconds.
  - `samples`: Audio samples.

## Examples

### Playing a sound effect
```lua
-- Load and play a sound effect
local sound = love.audio.newSource("explosion.wav", "static")
love.audio.play(sound)
```

### Background music with volume control
```lua
-- Load background music and set volume
local music = love.audio.newSource("background.mp3", "stream")
music:setVolume(0.5)
music:setLooping(true)
love.audio.play(music)
```

## Best practices
- Use "static" sources for short sound effects and "stream" sources for long music tracks
- Preload audio files during loading screens to avoid delays
- Consider using audio effects (reverb, echo) sparingly for performance
- Test audio on target platforms as format support may vary
- Use appropriate audio formats: OGG/Vorbis for music, WAV for sound effects

## Platform compatibility
- **Desktop (Windows, macOS, Linux)**: Full audio support including 3D audio and effects
- **Mobile (iOS, Android)**: Full support but some effects may be limited
- **Web**: Limited to basic audio playback, no recording or advanced effects

## Performance considerations
- Too many simultaneous audio sources can cause performance issues
- Complex audio effects impact CPU usage
- Streaming audio uses less memory than static audio
- Audio position calculations for 3D audio can be CPU-intensive
