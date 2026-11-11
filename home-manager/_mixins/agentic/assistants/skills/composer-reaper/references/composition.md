# Compose a track

Turn the musical brief into reproducible note data and an editable arrangement.

## Brief and harmony

Use the supplied genre, mood, key, tempo, duration, and reference track.
If the user leaves choices open, state defaults without blocking work.
A useful starting point is 90 to 110 beats per minute and a 60 to 90 second arrangement.

Analyse supplied MIDI or audio before adding parts. Check rhythm, pitch classes, tonal centre, and ambiguous notes.
Pitch classes alone do not prove a unique key.
For a sample centred on E with G-sharp, B, and D-natural, test E Mixolydian against the actual phrase.
Do not add D-sharp unless the musical context supports the clash.

| Character | Starting progression | Guidance |
| --- | --- | --- |
| Minor | `i - VI - III - VII` | Use natural minor or the requested mode. |
| Major pop | `I - V - vi - IV` | Keep the melody consistent with the chord changes. |
| Mixolydian | `I - bVII - IV` | Keep the flattened seventh. |

Separate registers for clarity: bass around MIDI 28 to 40, chords around 48 to 67, and melody around 72 to 84.
Adjust these ranges for the instrument and brief. Use close chord voicings where appropriate.

## Arrangement and MIDI

Plan sections in bars, with markers for intro, verse, chorus, bridge, and outro as needed.
Vary note density, velocity, register, and active parts between sections.
Keep quieter sections distinct from full arrangements.

Generate notes with a small script instead of hand-writing hundreds of events.
Represent each note with pitch, start beat, length, velocity, and channel.
Use absolute arrangement beats internally, then convert to the output API's units and item-relative positions.
Validate pitch and channel ranges, positive durations, note-off events, and item boundaries.
Keep the random seed when variation must be reproducible.

The following General MIDI program numbers are zero-based MIDI values, not one-based display numbers.

| Part | Program |
| --- | --- |
| Clean electric guitar | 27 |
| Steel-string acoustic guitar | 25 |
| String ensemble | 48 |
| Warm pad | 89 |
| Electric piano | 4 |
| Fingered electric bass | 33 |
| Synth bass | 38 |
| Saw lead | 81 |
| Flute | 73 |
| Violin | 40 |

Use MIDI channel 10, encoded as index 9, for General MIDI drums.
Common drum notes are kick 36, snare 38, closed hat 42, open hat 46, crash 49, ride 51, and clap 39.
Program changes select sounds only when the destination instrument supports General MIDI.

## Output and iteration

Use the live-control reference for a healthy connected REAPER session.
Use the bridge-recovery reference for a new `.RPP` file or macOS offline rendering.
Use the release-exports reference for audio deliverables. Read these references directly from the skill's reference list.

Balance drums, bass, melody, and accompaniment before mastering.
Choose the loudness target for the destination rather than assuming a universal streaming value.
Use the `audio-metrics` skill when calculating or interpreting loudness and peak measurements.

Deliver the generator with the MIDI or project so requests such as a busier chorus remain reproducible.
State missing instruments and verification limits. General MIDI and ReaSynth renders are previews, not proof of a finished production.
