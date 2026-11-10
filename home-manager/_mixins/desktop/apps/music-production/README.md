# REAPER studio instruments

This module installs the studio instruments on NixOS workstations with the `studio` tag: `skrye` and `zannah`.

## Sample libraries

The libraries are in `$XDG_DATA_HOME/sfz`, normally `~/.local/share/sfz`.
Home Manager links each complete library, including its samples, SFZ includes and licence.
Load the entrypoint SFZ file in sfizz. Plug-in scans do not discover SFZ files.

Add **LV2: sfizz** through the track's **FX** window.
Select a `Karoryfer` preset from the host preset menu, or open the corresponding file in sfizz.
The presets use immutable Nix store paths and load the upstream program defaults.

| Preset | File relative to the SFZ library directory |
| --- | --- |
| Karoryfer - Green guitar (keyswitch) | `karoryfer-black-and-green-guitars/Programs/01-green_keyswitch.sfz` |
| Karoryfer - Black guitar (keyswitch) | `karoryfer-black-and-green-guitars/Programs/02-black_keyswitch.sfz` |
| Karoryfer - Green guitar (twang) | `karoryfer-black-and-green-guitars/Programs/04-green_twang.sfz` |
| Karoryfer - Growlybass (clean) | `karoryfer-growlybass/growlybass_clean.sfz` |
| Karoryfer - Growlybass (dirty) | `karoryfer-growlybass/growlybass_dirty.sfz` |

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
No generated REAPER track templates or project chunks replace your saved tracks.
Native sfizz presets supply the sample selection without a custom REAPER state format.

## First use

Close REAPER before activating the Home Manager configuration.
After activation, reopen REAPER and check the new entries in the **FX** window.
If an entry is missing, check the LV2 search path in **Preferences > Plug-ins > LV2**.
Load a preset, play a MIDI item, then save and reopen the project to check recall.
Keep the sample libraries installed while projects reference their files.
