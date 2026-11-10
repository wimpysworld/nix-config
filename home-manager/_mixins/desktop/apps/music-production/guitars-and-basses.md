# Guitars and basses in REAPER

Use the native **LV2: sfizz** presets for the installed SFZ libraries.
Use Decent Sampler for libraries in its own format.
Both players receive MIDI, then send audio to the effects that follow them.

## Library locations

`$XDG_DATA_HOME` normally means `~/.local/share`.
The library links include samples, SFZ programs, supporting files and upstream documentation.
Plug-in scans discover players, not sample libraries.
The sfizz presets use immutable Nix store paths, so keep each library installed while a project uses it.

## Unreal Instruments The Slapper

The library is in `$XDG_DATA_HOME/sfz/unreal-the-slapper`.
These are percussive acoustic and electric guitars, not bass instruments.

| Native sfizz preset | File relative to the library |
| --- | --- |
| Unreal Instruments - The Slapper (acoustic) | `AG-Slapper/AG-Slapper/#AG-Slapper.sfz` |
| Unreal Instruments - The Slapper (electric) | `EG-Slapper/EG-Slapper/#EG-Slapper.sfz` |

The normal played range is MIDI **35-76**.
Use numeric notes because REAPER's octave labels depend on preferences.

| MIDI keyswitch | Articulation |
| --- | --- |
| 20, 34 | Slide out, the same articulation on either key |
| 21 | Natural harmonics |
| 22, 23 | Brush down, brush up |
| 24, 25, 26 | Thumb sustain, index sustain, middle sustain |
| 27 | Fret mute |
| 28 | Sustain legato |
| 29 | Thumping, the default |
| 30 | Ghost |
| 31 | Popping |
| 32 | Slap legato |
| 33 | Slide in |

Notes **14-16** trigger effects hits, and **17-19** trigger fret noises.
Velocity changes amplitude and filter response, not the articulation or a sample layer.
The programs vary samples on repeated notes.
Natural harmonics and brushes map only notes **35-52**.
The slide-in lower limit depends on **CC26**, while the upper limit stays at 76.
CC26 bands **1-15**, **16-31**, **32-47**, **48-63**, **64-79**, **80-95** and **96-127**
give lower limits **37**, **38**, **39**, **40**, **41**, **42** and **43**, respectively.

| CC | Control | Default |
| --- | --- | --- |
| 20 | Vibrato depth | 0 |
| 21 | Vibrato speed | 95 |
| 22 | Sustain decay | 127 |
| 23 | Long thump and pop at 65-127 | 0 |
| 24 | Release type: 2-15 basic, 16-31 ghost stop, 32-47 slide out | 13 |
| 25 | Basic-release level | 108 |
| 26 | Slide interval | 26 |

Use fret mute and ghost articulations between sustained notes for a percussive guitar part.
Use the acoustic program without an amplifier first.
Use the electric program before a clean amplifier and wah for funk rhythm.
The upstream guide recommends a real-time bounce to avoid cut-off notes.
Check the final export, especially when it uses slides or long releases.

## Karoryfer Black And Blue Basses

The library is in `$XDG_DATA_HOME/sfz/karoryfer-black-and-blue-basses`.
Select **Karoryfer - Darkblack Clean (sfizz)** for the fingered hollow-body bass.
This preset loads `Programs-sfizz/01-darkblack_keysw.sfz` and maps MIDI notes **35-76**.

| MIDI keyswitch | Darkblack articulation |
| --- | --- |
| 31 | Pluck, the default |
| 30 | Ghost |
| 29 | Staccato |
| 28 | Behind the bridge |
| 27 | Behind the bridge, open |

Keyswitch 27 also enables effects on notes **81-84**.
Notes **77-80** remain unmapped.
Plucks use velocity layers **1-31**, **32-63**, **64-95** and **96-127**.
Ghost notes use **1-63** and **64-127**.
The programs cycle through four samples for repeated notes.

Select **Karoryfer - Babyblue Clean (sfizz)** for the picked solid-body bass.
This preset loads `Programs-sfizz/03-babyblue_all.sfz` and maps MIDI notes **28-75**.
Its two velocity layers are **1-63** and **64-127**.
The lower layer cycles through four samples, and the upper layer cycles through eight.
**CC23** selects the low-string mapping on notes **28-34**.
Values **0-63** use the B string physically detuned to E.
Values **64-127** use digitally pitch-shifted B-string samples. The default is 127.

Keep **CC100** at its default of **0**, because sfizz does not reproduce the unison layer's filter routing.
The clean presets use the audible centre voices.
**CC105** selects polyphonic mode at **0-63** or monophonic mode at **64-127**.
Use **CC107** for Darkblack's release.
The vibrato controls are CC21 for depth, CC24 for swell and CC112 for speed.
CC114 controls tremolo, CC115 controls delay and CC116 controls fade.

The clean sfizz copies omit the ARIA filter definitions, which leave the original programs filtered at 250 Hz in sfizz.
They also omit inactive filter labels for **CC90-95** and the unsupported **CC113** wobble label.
Use Filther or ReaEQ after sfizz when you want tone control.
**CC25** preroll and some **CC112/117** modulation still have partial or unsupported behaviour.
All eleven original programs remain unchanged in `Programs` for players that support their ARIA controls.

## Karoryfer Pastabass

The library is in `$XDG_DATA_HOME/sfz/karoryfer-pastabass`.
These four basic programs map MIDI notes **33-101**.
They have no keyswitches or library-specific CC controls.
Select the program for the string type and playing method that you need.

The prefix for each preset below is **Karoryfer - Pastabass**.

| Preset suffix | File relative to the library | Sound | Velocity layers |
| --- | --- | --- | --- |
| (spaghetti) | `Pastabass/spaghetti.sfz` | Roundwound strings | 1-42, 43-85, 86-127 |
| (linguine) | `Pastabass/linguine.sfz` | Flatwound strings, picked, bridge pickup | 1-47, 48-95, 96-127 |
| (tagliatelle) | `Pastabass/tagliatelle.sfz` | Flatwound strings, picked and muted, combined pickups | 1-42, 43-85, 86-127 |
| (fetuccine) | `Pastabass/fetuccine.sfz` | Flatwound strings, fingered, neck pickup | 1-47, 48-95, 96-120, 121-127 |

Use fetuccine for a fingered disco line, or tagliatelle for short muted notes.
The final fetuccine velocity band selects its hardest layer, so reserve that band for accents.
The spelling `fetuccine` matches the upstream filename.

## Project16 Rickenbacker 4001

The library is in `$XDG_DATA_HOME/sfz/project16-rickenbacker-4001`.
Each program maps MIDI notes **24-63**, with five velocity layers.
The layer boundaries are **1-35**, **36-61**, **62-87**, **88-113** and **114-127**.
These programs have no keyswitches or library-specific CC controls.
Load a different program to change the articulation.

The prefix for each preset below is **Project16 - Rickenbacker**.

| Preset suffix | File relative to the library |
| --- | --- |
| (fingered 1) | `Fingered and Picked/Fingered1.sfz` |
| (picked 1) | `Fingered and Picked/Picked1.sfz` |
| (fingered 2) | `Fingered and Picked/Fingered2.sfz` |
| (picked 2) | `Fingered and Picked/Picked2.sfz` |
| (fingered 1 muted) | `Muted/Fingered1_Muted.sfz` |
| (picked 1 muted) | `Muted/Picked1_Muted.sfz` |
| (fingered 2 muted) | `Muted/Fingered2_Muted.sfz` |
| (picked 2 muted) | `Muted/Picked2_Muted.sfz` |
| (slap 1 long) | `Slapped/Slap1_Long.sfz` |
| (slap 1 short) | `Slapped/Slap1_Short.sfz` |
| (slap 2 long) | `Slapped/Slap2_Long.sfz` |
| (slap 2 short) | `Slapped/Slap2_Short.sfz` |

The presets expose all twelve programs, including both fingered and picked variants and their muted versions.
Use a short slap program for clipped funk notes, or a long program for sustained accents.
These names select separate sampled programs, not keyswitch states.

## Wah and clean guitar effects

Guitarix already supplies the following effects in REAPER's LV2 list.
No separate wah bundle is required.
Use the exact names below in the **FX** window.

| Effect | Controls | Use |
| --- | --- | --- |
| GxWah | **Wah**, range 0-1 | Manual Crybaby-style sweep |
| GxAutoWah | Enable control only | Automatic wah that responds to the incoming audio |
| GxWahwah | **WAH**, **MODE**, **MODEL**, **FREQ**, **WET_DRY** | Manual, automatic or alien mode, with seven wah models |
| Gxgcb_95 | **WAH**, range 0-1, and **VOLUME** | Alternative pedal sweep |
| GxCompressor | **RATIO**, **THRESHOLD**, **ATTACK**, **RELEASE**, **KNEE** | Control note peaks |
| GxChorus-Stereo | **Level**, **Delay**, **Depth**, **Freq** | Stereo modulation |
| GxPhaser | **Dry/Wet**, **LEVEL**, **SPEED** | Slow phaser movement |

GxWahwah's **MODE** values are 0 for manual, 1 for auto and 2 for alien.
Its **MODEL** values select Colorsound Wah (0), Dallas Wah (1), Foxx Wah (2), Jen Wah (3),
Maestro Wah (4), SelmerWah (5) and Vox Wah V847 (6).
Set **MODE** to manual before automating **WAH**.
For a first sweep, set **WET_DRY** to 100 and move **WAH** between 0.2 and 0.8.
These values are a recipe, not a supplied preset.

Add an envelope through the FX window's **Param** menu for the selected wah parameter.
Use MIDI learn on that parameter when you want an expression pedal.
MIDI CC1 in sfizz controls the instrument, not the next effect's wah position.
Use a host envelope or an explicit MIDI-learn assignment for the effect.

### Funk and disco recipes

These chains are starting points that use the installed effects.
They do not replace your presets or create generated REAPER project state.

| Sound | FX order | Starting point |
| --- | --- | --- |
| Tight rhythm guitar | sfizz, GxCompressor, GxWah, GxAmplifier-X | Use a short articulation and a clean amplifier setting. Automate the wah on offbeats. |
| Automatic wah guitar | sfizz, GxAutoWah, GxAmplifier-X, GxCompressor | Keep the amplifier clean. Change MIDI velocities to vary the automatic sweep. |
| Wide clean guitar | sfizz, GxAmplifier-X, GxChorus-Stereo | Use low chorus Level and Depth. Keep the rhythm notes short. |
| Phaser guitar | sfizz, GxPhaser, GxAmplifier-X | Start at SPEED 0.5 Hz and Dry/Wet 25. Match the bypassed level. |
| Fingered disco bass | sfizz, ReaComp | Use short root notes with octave answers. Keep the compressor attack long enough to retain each note's onset. |
| Slap funk bass | sfizz, ReaComp | Alternate the library's slap and pop articulations. Add quiet dead notes between accents. |
| Filtered bass | sfizz, Filther (Saike), ReaComp | Start with low PreGain and moderate Reso. Automate Cutoff, then match the level with PostGain. |

Put each effect after the player, because the effects process audio rather than MIDI.
Start at a low track level before adding resonant filters or an amplifier.
GxAutoWah has no exposed sensitivity control, so adjust its input level and playing dynamics.
For tighter rhythm parts, use short notes, leave rests and vary velocities instead of filling every sixteenth note.
Avoid overlapping bass notes unless you want a chord or an intentional transition.

## Player controls and project recall

Select sfizz library presets from REAPER's host preset menu.
Use MIDI control change (CC) lanes and keyswitch notes for the library's SFZ controls.
sfizz does not display custom Sforzando panels or supply ARIA-only effects.
Keep keyswitches and initial CC values before the first musical note in the MIDI item.

Decent Sampler comes from the pinned unstable package set.
Find **DecentSampler** in REAPER's VST3 or VST2 list, not the LV2 list.
Load a `.dspreset` or `.dslibrary` through the player's interface.
Keep the library's sample directories beside the preset when the preset uses relative paths.
The player exposes **Main Volume** and **Main Tuning** before an instrument is loaded.
The loaded instrument determines its other controls.
The three account-gated libraries are not installed: MDM Strat, Fresh Guitar 2.0 and Crafter 6 Steel.
Their official Pianobook pages require a login before download.
Their program names and controls need verification from the downloaded archives before presets or library links can be added.

The REAPER agent can work with MIDI notes, CC events and effects parameters that REAPER exposes.
Inspect each effect's parameter names before creating automation.
A custom graphical control is not proof that the host exposes that control.
Use the plug-in interface for file selection or controls that are absent from the host parameter list.
Do not write guessed plug-in state into a REAPER project.

After setting the sound, save the track through **Track > Save tracks as track template** under a new name.
Save the project, close it, and reopen it to check the samples, articulations and automation.
