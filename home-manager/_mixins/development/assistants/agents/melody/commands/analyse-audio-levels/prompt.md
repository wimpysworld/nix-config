## Analyse Audio Levels

Diagnose recording-side issues from audio metrics and provide actionable remediation for voice artists.

### Issue Detection Reference

| Issue | Metric Signature | Remediation |
|-------|------------------|-------------|
| Too close (proximity) | High energy <300 Hz, skewness >2.5, elevated LF | Move back to 8-10cm (4 fingers) |
| Too far | Low signal, high noise floor, elevated flatness (>0.4) | Move closer, increase gain |
| Gain too low | RMS far below peaks, crest >25 dB, noise >-60 dBFS | Target -18 dBFS average, peaks -6 dBFS |
| Gain too high | Flat-topped peaks at 0 dBFS, harmonic distortion | Reduce input gain |
| Room reverb | Smeared transients, spectral tails after speech | Acoustic treatment, closer mic |
| Flutter echo | Horizontal striations (rapid repetitions) | Treat parallel walls |
| Mains hum | Sharp lines at 50/100/150 Hz or 60/120/180 Hz | Ground loop isolation |
| Broadband noise | Flatness >0.5, spread >3000 Hz, continuous energy | Environment control, noise gates |
| Plosives | Low-frequency spikes 20-80 Hz, vertical bursts | Pop filter, off-axis technique |
| Sibilance | Energy spikes 3-8 kHz, elevated centroid | De-esser, angle mic off-axis |
| Breath noise | Low-frequency bursts between speech | Breath technique, gate |
| Mouth clicks | Short broadband impulses, vertical lines | Hydration, manual editing |

### Source Quality Thresholds

| Parameter | Good | Acceptable | Problem |
|-----------|------|------------|---------|
| Noise Floor | < -70 dBFS | -60 to -70 dBFS | > -60 dBFS |
| Peak Headroom | -6 to -3 dBFS | -12 to -6 dBFS | Clipping at 0 dBFS |
| Crest Factor | 12-18 dB | 9-20 dB | <9 dB (compressed) or >25 dB (under-recorded) |
| Speech Centroid | 800-3500 Hz | 500-4000 Hz | <500 Hz (muffled) or >5000 Hz (thin/sibilant) |
| Speech Kurtosis | > 5 | 3-5 | < 3 (noise contamination) |
| Speech Flatness | < 0.20 | 0.20-0.35 | > 0.40 (noisy/breathy) |
| Speech Entropy | < 0.25 | 0.25-0.40 | > 0.50 (disordered) |
| Speech Skewness | 0.5-2.0 | 0-2.5 | < 0 (HF-heavy) or > 3 (LF-heavy) |

### Spectral Quality Reference

| Metric | Healthy Voice | Problem Indicators |
|--------|---------------|-------------------|
| Centroid | 800-3500 Hz | < 500 Hz muffled; > 5000 Hz thin/sibilant |
| Spread | 1000-2500 Hz | > 4000 Hz indicates noise or unvoiced content |
| Rolloff (85%) | 4-8 kHz | < 2 kHz over-filtered; > 12 kHz sibilance |
| Slope | -8 to -4 dB/oct | > -3 bright/pressed; < -15 breathy/dark |
| Kurtosis | 5-15 | < 3 noise-dominated |
| Flatness | 0.05-0.25 | > 0.50 noise-dominated |

### Visual Pattern Recognition

| Pattern | Indicates |
|---------|-----------|
| Thin horizontal lines at fixed frequencies | Mains hum (50/60 Hz harmonics) |
| Continuous haze across frequencies | Broadband noise |
| Blurred edges, energy after words | Room reverb |
| Flat waveform tops, harmonic fuzz | Clipping |
| Vertical low-frequency bursts | Plosives |
| Clear harmonic bands, dark gaps between | Good speech |
| Scattered bright dots in dark regions | High-frequency noise |

### Output Format

**Issues Detected**: Prioritised list with severity (Critical/Moderate/Minor)

**Evidence**: Metric values and visual patterns supporting each diagnosis

**Remediation Steps**: Specific actions the voice artist can take, ordered by impact

**Recording Checklist**: Summary of settings to verify before next session
