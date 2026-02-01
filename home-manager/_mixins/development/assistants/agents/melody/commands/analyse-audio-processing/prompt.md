## Analyse Audio Processing

Compare before/after metrics to evaluate processing effectiveness and detect artefacts. Provide feedback for software engineers on pipeline quality.

### Interpreting Spectral Shifts After Noise Reduction

Centroid and rolloff decreases are often legitimate effects of noise removal, not over-filtering. Distinguish between the two:

**Why noise removal shifts spectral metrics:**

- Broadband noise (preamp, room) extends to 15+ kHz with flat energy distribution
- Speech energy concentrates below 4-5 kHz
- In HF regions where speech has little energy, noise dominates the measurement
- Removing noise reveals the true spectral signature of speech alone

**Metrics that unambiguously indicate successful denoising:**

| Metric | Change | Why It's Positive |
|--------|--------|-------------------|
| Flatness decrease | e.g. 0.35 → 0.10 | Noise is spectrally flat; speech is tonal. Reveals tonality. |
| Kurtosis increase | e.g. 4 → 12 | Noise fills spectral valleys between harmonics. Removal sharpens peaks. |
| Entropy decrease | e.g. 0.45 → 0.20 | Ordered harmonic structure revealed. |

**Metrics requiring contextual interpretation:**

| Metric | Assess By |
|--------|-----------|
| Centroid shift | Compare shift magnitude across tracks with different input noise levels. Noisier inputs should show larger shifts if noise removal is the sole cause. |
| Rolloff decrease | Check if final values are within normal speech range (4-8 kHz). Values < 2 kHz warrant investigation. |

**Diagnostic pattern:** If the noisiest input shows the *smallest* spectral shift and lands at typical speech values, while cleaner inputs show larger shifts to atypical values, suspect filtering beyond noise removal.

### Processing Quality Indicators

#### Positive Changes

| Metric | Expected Change | Interpretation |
|--------|-----------------|----------------|
| Noise Floor RMS | Decrease (more negative dBFS) | Noise reduction effective |
| Speech Kurtosis | Increase | Harmonic structure revealed (not just preserved) |
| Speech Flatness | Decrease toward <0.15 | Tonality revealed by noise removal |
| Speech Entropy | Decrease toward <0.25 | Order revealed |
| Integrated Loudness | Converge to -18.0 LUFS | Normalisation hit target |
| True Peak | ≤ -1.0 dBTP | Headroom maintained per EBU R128 |
| LRA | Maintain 8-18 LU | Natural dynamics preserved |
| Crest Factor | Moderate reduction (target 9-14 dB) | Controlled compression |

#### Warning Signs (Over-Processing)

| Metric Change | Artefact Type | Perceptual Effect |
|---------------|---------------|-------------------|
| Rolloff < 2 kHz (final value) | Over-filtering | Muffled, dull, telephone-like |
| Kurtosis drops from input | Harmonic damage | Loss of vocal clarity |
| Flatness increases in speech region | Musical noise or artefacts | Metallic, synthetic quality |
| Crest < 6 dB | Over-compression | Squashed, lifeless, fatiguing |
| LRA < 6 LU | Over-compression | Unnatural dynamics |
| Centroid < 500 Hz (final value) | Spectral damage | Unnaturally dark |
| Flux increases significantly | Gate pumping or artefacts | Unnatural transitions |
| Entropy increases | Processing artefacts | Disorder introduced |
| Slope > -3 dB/oct | Over-brightening | Harsh, unnatural |

### Artefact Detection

| Artefact | Cause | Metric Signature | Spectrogram Pattern |
|----------|-------|------------------|---------------------|
| Musical noise | Aggressive noise reduction | Elevated flatness in quiet sections, scattered kurtosis | Scattered bright dots in dark regions |
| Pumping | Over-compression | Rapid flux changes, LRA collapse (<6 LU) | Rhythmic brightness variation |
| Breathing | Compression release | Noise floor rise after transients | Noise swells following speech |
| Gate pumping | Aggressive gating | Abrupt flux spikes, unnatural silence onsets | Hard edges between speech and silence |
| Comb filtering | Phase issues | Periodic notches, hollow sound | Regular vertical striations |
| Clipping | Over-limiting | True peak > 0 dBTP, flat peaks | Horizontal fuzz above speech |

### Before/After Comparison Framework

**Should improve:**

- Noise floor (silence regions): Quieter
- Loudness consistency: Converge to target (-18 LUFS ±0.5 LU)
- Peak control: True Peak ≤ -1 dBTP
- Kurtosis: Increase (harmonics revealed)
- Flatness: Decrease (tonality revealed)
- Entropy: Decrease (order revealed)

**Assess in context of input noise:**

- Centroid shift: Larger shifts expected from noisier inputs
- Rolloff shift: Some decrease expected; final value matters more than delta

**Should NOT happen:**

- Kurtosis dropping from input value
- Flatness or entropy increasing in speech regions
- LRA collapsing below 6 LU
- Crest factor below 6 dB
- Final centroid < 500 Hz or rolloff < 2 kHz
- True Peak > -1 dBTP
- New artefacts in spectrogram

### Target Compliance

| Parameter | Target | Pass | Marginal | Fail |
|-----------|--------|------|----------|------|
| Integrated Loudness | -18.0 LUFS | ±0.5 LU | ±1.0 LU | > 1.0 LU off |
| True Peak | -1.0 dBTP | ≤ -1.0 | -1.0 to 0 | > 0 dBTP |
| LRA | 8-18 LU | Within range | 6-8 or 18-22 | < 6 or > 22 |
| Crest Factor | 9-14 dB | Within range | 6-9 or 14-18 | < 6 dB |
| Noise Reduction | Effective | > 25 dB reduction | 15-25 dB | < 15 dB |
| Final Centroid | 800-3500 Hz | Within range | 500-800 Hz | < 500 Hz |
| Final Rolloff (85%) | 4-8 kHz | Within range | 2-4 kHz | < 2 kHz |
| Final Kurtosis | > 5 | > 5 | 3-5 | < 3 (degraded from input) |
| Final Flatness | < 0.25 | < 0.20 | 0.20-0.35 | > 0.35 (degraded from input) |

### Output Format

**Processing Verdict**: Pass/Marginal/Fail with one-sentence summary

**Target Compliance**: Table showing each parameter against targets

**Improvements Achieved**: What processing fixed, with metric evidence

**Noise Removal Effects**: Spectral shifts attributable to legitimate denoising (kurtosis increase, flatness decrease, expected centroid/rolloff movement)

**Degradations Detected**: Any artefacts or quality loss with severity, distinguishing between noise-removal side effects and actual damage

**Cross-Track Comparison**: If multiple tracks provided, compare spectral shift magnitudes against input noise levels to identify anomalies

**Recommendations**: Specific parameter adjustments for pipeline improvement
