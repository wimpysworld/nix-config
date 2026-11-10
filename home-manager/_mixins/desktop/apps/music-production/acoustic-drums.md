# Acoustic drums in REAPER

These three free libraries extend the studio setup on `skrye` and `zannah`.
Use Ludwig for a large vintage kit, Virtuosity for jazz, and Big Rusty for brushes, mallets and unusual percussion.

## Library locations

`$XDG_DATA_HOME` normally means `~/.local/share`.
The complete libraries remain available through these stable paths.

| Library | Path below `$XDG_DATA_HOME` | Format |
| --- | --- | --- |
| Tchackpoum Ludwig Black Cortex | `reaper-libraries/tchackpoum-ludwig-black-cortex` | Native REAPER templates and samples |
| Virtuosity Drums 0.925 | `sfz/virtuosity-drums` | SFZ programs and samples |
| Karoryfer Big Rusty Drums | `sfz/karoryfer-big-rusty-drums` | SFZ programs and samples |

The templates and presets reference immutable Nix store paths.
Keep the libraries installed while projects use those paths.
The original documentation and free-use notices remain with each library.

## Ludwig Black Cortex

Start with **Track > Insert track from template > Tchackpoum > ReaperDrummer Ludwig Black Cortex keyboard**.
The keyboard template uses separate notes for hi-hat articulations.
Send MIDI on **channel 10** to the **Black Cortex** instrument track.
The kit uses REAPER's ReaSamplOmatic5000, ReaEQ and supplied JS effects.

The template already routes audio to **Kick**, **Snare**, **Hihat**, **Tom 12**, **Tom 13**, **Tom 14**,
**Floor tom 16**, **Floor tom 18**, **Cymbales**, **Ovh**, **Room** and **Para Comp** tracks.
Use those faders for the mix.
**Room** is a generated ReaVerb room, not recorded ambience.
The kick container's **In Mic** ReaEQ controls the inside microphone before the **Kick** track.
Keep the full template when you save your own version so that its sends remain intact.

In the MIDI editor, use **File > Note/CC names > Load note/CC names from file**.
Open `MIDINoteNames/Tchackpoum/ReaperDrummer Ludwig Black Cortex.txt` in the REAPER resource directory.
The supplied Roland and Yamaha maps remain available in the same directory.

| MIDI notes | Keyboard-template sounds |
| --- | --- |
| 35, 36 | Kick |
| 37, 38, 39, 40 | Snare side stick, centre, edge, rimshot |
| 29, 33 | Fat snare, muted snare |
| 42, 46, 44, 61 | Closed hi-hat bow, fully open bow, pedal, open pedal |
| 22 | Closed hi-hat edge |
| 23, 31, 34, 30 | Open hi-hat bow stages 1, 2, 3, 4 |
| 24, 32, 27, 25, 26 | Open hi-hat edge stages 1, 2, 3, 4, fully open |
| 48, 47, 45, 43, 41 | Tom 1, tom 2, tom 3, floor tom 1, floor tom 2 |
| 50, 60, 62, 58, 65 | Corresponding tom rims |
| 49, 57, 56 | Crash 1, 2, 3 bows |
| 55, 52, 54 | Crash 1, 2, 3 edges |
| 51, 53, 59 | Ride bow, bell, edge |

The alternative **ReaperDrummer Ludwig Black Cortex** template enables the hi-hat CC controllers.
Its default pedal control is **CC1**, the modulation wheel.
For a Roland pedal, set **CC4** in each **JS Hihat Controller** in the hi-hat container.
The snare positional-sensing control uses **CC16**.
Use the supplied **JS key remapping MIDI** for controller-specific note assignments.
For electronic cymbals, use the cymbal controls for remapping so that the choke messages remain associated with their notes.

## Virtuosity Drums

Select **Virtuosity Drums - Full kit** in **LV2: sfizz** for the jazz kit and all six microphone positions.
The default mix enables the kick, snare and overhead microphones.
**Virtuosity Drums - Basic kit** uses those three microphones and fewer articulations.
The presets load `Programs-sfizz/02-full-kit.sfz` and `Programs-sfizz/01-basic-kit.sfz`.
This sfizz-specific copy fixes silent hi-hat articulations by placing the silent choke definitions before the sounding definitions.
The original `Programs` directory remains unchanged.

| MIDI notes | Full-kit sounds |
| --- | --- |
| 35, 36 | Kick with alternative snare-wire resonance |
| 37, 38, 39, 40 | Snare stick shot, centre, off-centre, rimshot |
| 41, 43, 45, 47 | Low tom centre, off-centre, rimshot, cross stick |
| 48, 50 | High tom centre, off-centre |
| 42, 44, 46 | Hi-hat closed, pedal, open |
| 90, 92, 94 | Hi-hat half-open, splash, three-quarter-open |
| 49, 57 | Crash, sizzle crash |
| 51, 53 | Ride bow, bell |
| 59, 55 | Flat ride bow, crash |
| 85, 86, 87, 88 | Second snare stick shot, muted snare, half-open snare, cross stick |
| 89, 91 | Low tom muted, half-open |
| 93, 95, 96 | Snare buzz, flam, roll |

The shipped map selects hi-hat openness with separate notes.
**CC4 does not select openness in this map**.
The optional pedal maps stay in the library, but the presets do not select them.
Use **CC1**, initially 31, to change roll dynamics on note 96.
The library includes General MIDI percussion assignments, with the full chart in `VirtuosityDrums_Keymap.pdf`.
The drums are not a strict General MIDI kit: several tom notes select techniques on the same drum.

| Microphone | Volume CC | Full-kit default | Other controls |
| --- | --- | --- | --- |
| Kick | 101 | 127 | Bleed CC102, default 127 |
| Snare | 103 | 127 | Bleed CC104, default 127 |
| Overhead | 105 | 127 | Width CC106, default 127 |
| Mid | 107 | 0 | Width CC108, default 127 |
| Room | 109 | 0 | Width CC110, default 127 |
| Vintage | 111 | 0 | Mono microphone |

Raise **CC107**, **CC109** or **CC111** to add the corresponding microphone to the full-kit mix.
Keep the three microphone levels at zero when you want the default close and overhead mix.
Use **CC71** for kick damping.
The tuning controls are CC72 for kick, CC76 for snare, CC81 for low tom, CC86 for high tom and CC90 globally.

### Separate microphone tracks

The six microphone presets preserve the drum map and output stereo from sfizz.
Kick, snare and vintage recordings are mono, while overhead, mid and room recordings are stereo.
The prefix for each preset below is **Virtuosity Drums -**.

| Preset suffix | File in `Programs-sfizz` | Default volume |
| --- | --- | --- |
| Kick mic | `03-kick-mic.sfz` | CC101 = 127 |
| Snare mic | `04-snare-mic.sfz` | CC103 = 127 |
| Overhead mic | `05-oh-mic.sfz` | CC105 = 127 |
| Mid mic | `06-mid-mic.sfz` | CC107 = 100 |
| Room mic | `07-room-mic.sfz` | CC109 = 100 |
| Vintage mic | `08-vintage-mic.sfz` | CC111 = 100 |

Create a MIDI source track and six sfizz tracks, one for each microphone preset.
Send the source track to each microphone track with **Audio: None** and **MIDI: All > All**.
Do not add a full-kit instance to this routing.
Mix the microphone tracks with their faders, and save all seven tracks together as your own track template.
The kick and vintage microphone programs do not include the extra percussion instruments.

## Big Rusty Drums

Select **Karoryfer - Big Rusty Drums (full kit)** in **LV2: sfizz**.
The full kit includes oversized drums, prepared snares, brushes, mallets, cymbal stacks and mechanical noises.
**Karoryfer - Big Rusty Drums (basic kit)** is a smaller sticks-only selection.
The full-kit preset loads `Programs-sfizz/01-full.sfz`.
The basic-kit preset loads `Programs/02-basic.sfz`.
The full-kit copy omits controller display labels to avoid a crash in sfizz's LV2 wrapper.
Controller numbers, default values and audio definitions remain unchanged.
Use the numeric controller tables below instead of display labels.
The original `Programs/01-full.sfz` remains available, but do not load it in **LV2: sfizz**.

The full kit starts with sticks.
Set the following CCs before the first note when you change playing tools.

| Control | Sticks | Brushes | Mallets | Other selections |
| --- | --- | --- | --- | --- |
| CC25, snare | 0-31 | 64-95 | 96-127 | 32-47: tom on snare. 48-63: tambourine on snare. |
| CC26, toms | 0-63 | 64-95 | 96-127 | None |
| CC27, hi-hat | 0-63 | 64-127 | None | None |
| CC28, cymbals | 0-63 | 64-95 | 96-127 | None |

For a brush kit, set **CC25-28 to 80**.
For mallets, set **CC25, CC26 and CC28 to 112** and choose sticks or brushes separately for the hi-hat.
The basic kit does not use these sticking selectors.

| MIDI notes | Sounds | Basic kit |
| --- | --- | --- |
| 35, 36 | Undamped kick, normal kick | 36 only |
| 37, 38, 39, 40 | Snare side stick, centre, edge, rimshot | Yes |
| 41, 43, 45, 47 | Toms, largest to smallest | 43, 45, 47 |
| 42, 54, 44, 56 | Closed hi-hat tip, closed shank, pedal chick, splash | Yes |
| 46, 58 | Variable hi-hat tip, shank | Yes |
| 49, 50 | Crash, crash choke | Yes |
| 51, 52, 53, 55 | Ride bow, crash, bell, choke | Yes |
| 57, 59 | China, choke | No |
| 60, 61, 62, 63 | Sizzle ride bow, crash, bell, choke | No |
| 64, 65, 67, 69 | Sizzle crash bow, crash, bell, choke | No |
| 71, 72 | Stack centre, edge | No |
| 73, 74, 75, 76 | Snare long stir, short stir, flutter, brush dig | No |
| 78, 79, 80, 81 | Floor-tom long stir, short stir, flutter, brush dig | No |
| 77 | Stop snare and floor-tom stirs | No |
| 24, 25, 30, 32, 34 | Pedal mechanical noises and hi-hat return | 34 only |
| 26, 31 | Snare and floor-tom release noises | No |
| 83-96 | Percussive clicks | No |

**CC4** controls openness on notes **46** and **58**.
The shipped keyboard map uses 0-25 closed, 26-51 loose, 52-76 quarter-open, 77-102 half-open and 103-127 open.
Its default is 127.
This direction differs from a conventional pedal map.

| Microphone controls | Default values |
| --- | --- |
| Kick close CC70, overhead CC71 | 100, 0 |
| Snare bottom CC80, top CC81, overhead CC82 | 100, 40, 60 |
| Hi-hat close CC15, overhead CC16 | 100, 100 |
| Tom close/overhead pairs CC30/31, 34/35, 38/39, 42/43 | 100, 70 |
| Cymbal close/overhead pairs CC100/101, 104/105, 108/109, 112/113, 116/117, 124/125 | 40, 100 |

sfizz plays the normal kit, but the kick overhead **CC71** and snare **Epic CC85** are almost silent.
Do not use those two controls for the mix.
sfizz also omits the authored limiter and some brush-stir envelope shapes.
Use a REAPER limiter after the instrument when you need peak protection.
The library's original files remain unchanged.

### Separate drum buses

These presets are stereo instruments with the same note map, not one multi-output plug-in.
The prefix for every name below is **Karoryfer - Big Rusty Drums**.

| Preset suffix | File in `Programs` | Output |
| --- | --- | --- |
| (kick bus) | `03-kick.sfz` | Kick |
| (snare bus) | `04-snare.sfz` | Snare |
| (tom bus) | `05-toms.sfz` | Toms |
| (hi-hat bus) | `06-hihat.sfz` | Hi-hat |
| (cymbal bus) | `07-cymbals.sfz` | Cymbals |
| (noise and click bus) | `08-noises.sfz` | Pedal noises and percussive clicks |

Create one MIDI source track and one sfizz track per bus.
On the source track, add a send to each bus with **Audio: None** and **MIDI: All > All**.
Keep the MIDI item on the source track so that notes and CCs reach every bus.
Do not add a full-kit instance to this routing, because it duplicates the drum audio.
Mix and process the six stereo tracks, then save all seven tracks together as your own track template.

## First use and project recall

Close REAPER before activating the Home Manager configuration.
After activation, reopen REAPER.
Use **Options > Show REAPER resource path in explorer/finder** to find the installed templates, effects and note names.
Do not copy the whole resource directory over an existing REAPER setup.

For SFZ libraries, add **LV2: sfizz** through the track's **FX** window.
Select the kit from the host preset menu, or open its SFZ file in sfizz.
Plug-in scans do not discover SFZ files.
Use MIDI control change (CC) lanes for the library's controls.
sfizz does not show the authored Sforzando panel or run ARIA-only effects.

Create a MIDI item and enter notes from the selected kit's map.
Use note numbers because REAPER's octave labels depend on preferences.
Start with a low track level and check the output meter.
Save the project, close it, and reopen it to check sample paths, controller settings and routing.
Save custom kit tracks through **Track > Save tracks as track template** under a different name.
