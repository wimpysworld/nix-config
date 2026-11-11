# Music tools around REAPER

Use tools that the user already has. Check current documentation, platform support, and input requirements before generating integration code.
Do not install software, buy services, or upload recordings as an implicit step.

| Task | Examples | Integration |
| --- | --- | --- |
| Stem separation | Ultimate Vocal Remover, Demucs, RX Music Rebalance, SpectraLayers | Export audio, separate stems, then import aligned tracks. |
| Reference mastering | Matchering, Ozone, smart:limit | Compare loudness-matched results and retain the original mix. |
| Melody to MIDI | Basic Pitch | Convert recorded humming, then inspect note timing and pitch. |
| Chord generation | Scaler, Captain Plugins, Orb Producer Suite | Route or export MIDI to the chosen instrument. |
| Vocal synthesis | Synthesizer V, ACE Studio | Render the requested melody and lyrics, then import the audio. |
| Dialogue repair | RX, Clarity Vx, Supertone Clear, Enhance Speech | Work on copies and compare repaired sections. |
| Guitar amplification | Neural Amp Modeler, TONEX | Use available captures or plugins on a direct guitar signal. |

These examples are not dependencies or guarantees of availability.

For stem separation, preserve the source start position, sample rate, and duration.
Group the imported stems so subsequent edits remain aligned.
Check separation artefacts before applying further processing.

For mastering, preserve headroom and compare at matched loudness.
Do not treat a fixed peak level or service preset as a complete mastering decision.

For external commands, use structured argument arrays where available.
Quote filesystem paths correctly when a shell is unavoidable.
Check exit status and output files before importing results into REAPER.
