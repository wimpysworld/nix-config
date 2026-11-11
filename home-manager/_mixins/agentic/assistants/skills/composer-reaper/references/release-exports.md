# Release exports

Keep a lossless master and derive sharing formats from it.

| Output | Purpose |
| --- | --- |
| WAV or FLAC | Lossless master at the requested sample rate and bit depth. |
| MP3 at 320 kbps | Sharing copy when requested. |
| Waveform JSON | Optional peak data for an audio player on a website. |

## Render

Inspect REAPER's render settings or the user's saved preset before scripting the render action.
Confirm the source, time range, tail, sample rate, bit depth, normalisation, and output path.
Use the configured MCP renderer or a verified native action.
Do not invent render action IDs or assume that changing a filename sets every render option.

Check the rendered file's duration, channels, sample rate, and silence status.
Use `audio-metrics` for loudness and true-peak measurement.
Choose targets for the destination and musical material. A single `loudnorm` invocation does not prove a release-ready master.
If a requested target requires precise normalisation, measure first and use the measured values for the processing pass.

## Derive sharing files

Use available `ffmpeg` and, only for waveform data, `audiowaveform`.
Report a missing tool without installing it as part of this skill.
Pass filenames as arguments, not as text interpolated into a shell command.

For a new output directory, these commands illustrate the conversion:

```sh
ffmpeg -n -i master.wav -c:a libmp3lame -b:a 320k track.mp3
audiowaveform -i master.wav -o track.json -b 8
```

Verify that both destinations are unused before running them.
`ffmpeg -n` refuses overwrite. Do not assume that `audiowaveform` has the same protection.
Keep the source master untouched and check each command's exit status.

The upstream `06_export_release_bundle.lua` is not bundled because its shell interpolation is unsafe and its `ffmpeg -y` overwrites output.
Use the workflow above instead. Undoing a REAPER action cannot restore overwritten external files.
