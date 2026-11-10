# REAPER studio instruments

This module installs the studio instruments on NixOS workstations with the `studio` tag: `skrye` and `zannah`.

For Ludwig Black Cortex, Virtuosity Drums and Big Rusty Drums, use the [acoustic drum guide](acoustic-drums.md).
That guide covers templates, presets, note maps, microphone controls and project recall.

For guitar and bass articulations, funk rhythms and wah chains, use the [guitar and bass guide](guitars-and-basses.md).

## Sample libraries

The libraries are in `$XDG_DATA_HOME/sfz`, normally `~/.local/share/sfz`.
Home Manager links each complete library, including its samples, SFZ includes and licence.
Load the entrypoint SFZ file in sfizz. Plug-in scans do not discover SFZ files.

Add **LV2: sfizz** through the track's **FX** window.
Select a `Karoryfer`, `FreePats` or `Virtuosity Drums` preset from the host preset menu.
Alternatively, open the corresponding file in sfizz.
The presets use immutable Nix store paths and load the upstream program defaults.

| Preset | File relative to the SFZ library directory |
| --- | --- |
| Karoryfer - Green guitar (keyswitch) | `karoryfer-black-and-green-guitars/Programs/01-green_keyswitch.sfz` |
| Karoryfer - Black guitar (keyswitch) | `karoryfer-black-and-green-guitars/Programs/02-black_keyswitch.sfz` |
| Karoryfer - Green guitar (twang) | `karoryfer-black-and-green-guitars/Programs/04-green_twang.sfz` |
| Karoryfer - Growlybass (clean) | `karoryfer-growlybass/growlybass_clean.sfz` |
| Karoryfer - Growlybass (dirty) | `karoryfer-growlybass/growlybass_dirty.sfz` |
| FreePats - Synthesizer percussion | `freepats-synthesizer-percussion/SynthesizerPercussion-20220718.sfz` |

Black And Green contains two electric guitars, not acoustic guitars.
In the keyswitch programs, MIDI notes 36 and 37 select twang and staccato.
Note 38 selects hammer-on for Green or behind-the-bridge for Black.
Use MIDI note numbers because octave labels differ between applications.
MIDI control change (CC) 70 controls muting.

sfizz plays the guitar samples and articulations, but ignores some feedback attack-shape and vibrato-humanisation controls.
The upstream files remain unchanged.
All eleven guitar programs and seven Growlybass programs remain available in the library directories.

## Rock instrument chains

| Sound | FX order | Starting point |
| --- | --- | --- |
| Electric guitar | sfizz, then GxAmplifier-X | Select a Green or Black preset. GxAmplifier-X supplies the amplifier and cabinet. |
| Bass | sfizz | Select Growlybass clean or dirty. Start with no extra amplifier. |
| Hammond organ | setBfree DSP Tonewheel Organ | Use the tonewheel instrument with its built-in Leslie controls. |

Find **GxAmplifier-X** and **setBfree DSP Tonewheel Organ** in the **FX** window's LV2 list.
These plug-ins use the existing profile's `lib/lv2` search path.
The guitar amplifier processes audio. Put it after sfizz on a MIDI instrument track.

After setting the sound, save the track through **Track > Save tracks as track template**.
No generated REAPER project chunks replace your saved tracks.
Native sfizz presets supply the sample selection without a custom REAPER state format.

## Electronic music starting points

These self-authored settings start from an initialised synth patch, with other oscillators and effects disabled.
They are recipes, not extra factory banks or generated host state.
Save each finished sound as a plug-in preset or track template.

| Sound | Instrument and settings | MIDI starting point |
| --- | --- | --- |
| Acid bass | JC303: saw wave, low cutoff, moderate resonance, short decay and moderate envelope modulation. Start with low output gain. | Use a one-bar pattern of short notes around MIDI 36. Add a few accents and slides. |
| Solid bass | Vital: one saw oscillator, no unison, mono voice mode, low-pass filter. Amplitude envelope: attack 0 ms, decay 150 ms, sustain 70%, release 50 ms. | Use MIDI 28-43 with gaps between notes. Lower the filter cutoff to leave space for the lead. |
| Chord stab | Surge XT: one saw oscillator, polyphonic voice mode and low-pass filter. Amplitude envelope: attack 5 ms, decay 250 ms, sustain zero, release 100 ms. | Start with a minor triad at MIDI 48, 51 and 55. Use short offbeat chords. |
| Electronic drums | LV2: sfizz, preset **FreePats - Synthesizer percussion**. The kit contains CC0 synthesised drum samples. | Start at 120 BPM with kick 48 on every beat. Add clap 63 on beats two and four. Add closed hat 52 between beats. |

JC303 comes from the pinned unstable package set because version 0.13.0 includes its 16-step sequencer.
Its native plug-in metadata still reports 0.12.3 because upstream did not update that version field.
The other plug-ins retain their existing package versions.
Use either JC303's sequencer or notes from REAPER when you create the bass line.
For its sequencer, open **Sequencer** and set **Sync Mode** to **Host**.
Keep **Length** at 16 and **Start Mode** at **Transport** for a one-bar pattern with REAPER transport control.
Keep filter sweeps in REAPER automation so that you can edit the movement with the arrangement.

### Drum note map

The FreePats kit does not use the General MIDI drum map.
Use the following MIDI note numbers, regardless of REAPER's octave-label preference.

| MIDI notes | Sounds |
| --- | --- |
| 48, 49 | Kicks |
| 50, 51 | Snares |
| 52, 53 | Closed hi-hats |
| 54 | Open hi-hat |
| 55, 56 | Cymbals |
| 57, 58 | Low toms |
| 59, 60 | Mid toms |
| 61, 62 | High toms |
| 63 | Clap |
| 64 | Shaker |
| 65 | Long shaker |
| 66 | Claves |

Geonkick remains available when you need to design a drum sound instead of using the sample kit.

### Filter and distortion effects

Find **Filther (Saike)** and **Squashman (Saike)** in the FX window's JS list.
Home Manager links their complete directories under `Effects/Saike` in the REAPER resource directory.
The directories retain the upstream helper files, images and Filther preset bank.
The configuration does not replace the whole `Effects` directory or your saved presets.

Put Filther after a bass or chord instrument for filter movement and distortion.
Start with low drive and output gain.
Raise the effect amount while you compare the bypassed level.
Automate **Cutoff** and **Reso** for the first filter, or **Filter2 Cutoff** and **Filter2 Reso** for the second.
Use **PreGain** for input drive and **PostGain** for output level.
Never automate Filther's **Toggles (DO NOT AUTOMATE)** parameter, slider 35.

Put Squashman after an instrument or on a drum bus for multiband distortion.
Start with a low **Drive 1 (dB)** value.
Reduce **Dry/Wet 1** for parallel processing.
The corresponding controls exist for bands 2-5, with **Frequency 1** through **Frequency 4** for crossover points.
Squashman's graphical interface has routing and envelope controls that are not all exposed as host parameters.
Set those controls in its interface before you save the preset.

To try the upstream Filther bank, import `Effects/Saike/Filther/Filther.jsfx.rpl` through REAPER's preset menu.
The configuration does not merge that bank into your preset files automatically.

## First use

Close REAPER before activating the Home Manager configuration.
After activation, reopen REAPER and check the new entries in the **FX** window.
If an entry is missing, check the LV2 search path in **Preferences > Plug-ins > LV2**.
Load a preset, play a MIDI item, then save and reopen the project to check recall.
Keep the sample libraries installed while projects reference their files.
