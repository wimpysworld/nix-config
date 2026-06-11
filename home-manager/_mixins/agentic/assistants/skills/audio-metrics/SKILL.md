---
name: audio-metrics
description: "Load for objective audio analysis from ffmpeg metrics - spectral statistics, spectrograms, loudness, EBU R128, LUFS, LU, RMS, dBFS, dBTP, true peak, crest factor, dynamic range, and noise floor. Covers the aspectralstats, astats, ebur128, and loudnorm filters: what each metric measures, how ffmpeg computes it, its units and range, and the external loudness standards and platform targets. Use when reading or producing ffmpeg audio measurements, even when the user names only a metric, filter, or standard."
user-invocable: true
---

# Audio Metrics Reference

Objective definitions of the audio metrics ffmpeg computes. Each entry states what the metric measures, how ffmpeg computes it, its units, scale, and source filter. Definitions only: no perceptual interpretation, no quality judgement, no threshold-to-meaning mapping.

Verified against FFmpeg filter docs (https://ffmpeg.org/ffmpeg-filters.html) and source on `release/8.1` and `master` (`libavfilter/af_aspectralstats.c`, `af_astats.c`, `af_loudnorm.c`, `doc/filters.texi`). Where the fact-sheet flagged a derivation as medium-confidence, this skill marks it `Confidence: medium`.

## aspectralstats - per-frame spectral statistics

Statistics run over the half-spectrum magnitude array `magnitude[n] = hypotf(re, im)` of length `size = win_size/2`; FFT output is pre-scaled by `1/win_size`; `scale = max_freq/size` with `max_freq = sample_rate/2`. Metadata keys emit per channel as `lavfi.aspectralstats.<N>.<key>`.

| Metric | Measures | ffmpeg computation | Units | Range/scale | Confidence |
| --- | --- | --- | --- | --- | --- |
| mean | Arithmetic mean of magnitude bins | `sum(mag[n]) / size` | magnitude (linear) | >= 0 | high |
| variance | Population variance of magnitudes about `mean` | `sum((mag[n]-mean)^2) / size` | magnitude^2 | >= 0 | high |
| centroid | Magnitude-weighted mean frequency | `Sum(mag[n]*n*scale) / Sum mag[n]` | Hz | 0 .. max_freq | high |
| spread | Magnitude-weighted std-dev of frequency about centroid | `sqrt( Sum(mag[n]*(n*scale-centroid)^2) / Sum mag[n] )` | Hz | >= 0 | high |
| skewness | Third standardised spectral moment about centroid | `Sum(mag[n]*(n*scale-centroid)^3) / (Sum mag[n] * spread^3)` | dimensionless | signed | high |
| kurtosis | Fourth standardised spectral moment about centroid | `Sum(mag[n]*(n*scale-centroid)^4) / (Sum mag[n] * spread^4)` | dimensionless | >= 0 | high |
| entropy | Magnitude-weighted log-spread, normalised by `log(N)` | `-Sum(mag[n]*ln(mag[n]+eps)) / ln(size)` | dimensionless | unbounded; not a 0-1 probability entropy (magnitudes are raw, not normalised to sum 1) | medium |
| flatness | Geometric mean / arithmetic mean of magnitudes | `exp(mean(ln(mag[n]+eps))) / mean(mag[n]+eps)` | dimensionless ratio | 0 .. 1 (linear, not dB) | high |
| crest | Spectral crest: peak bin / mean bin of the magnitude spectrum | `max(mag[n]) / mean(mag[n])` | dimensionless ratio | >= 1 | high |
| flux | L2 distance between this frame's and the previous frame's magnitude spectrum | `sqrt( Sum(mag[n] - prev_mag[n])^2 )` | magnitude (linear) | >= 0; per-frame; not normalised | high |
| slope | Linear-regression slope of magnitude vs normalised bin index | `Sum(((n-m)/m)*(mag[n]-mean_mag)) / Sum((n-m)/m)^2`, `m = size*0.5` | magnitude per normalised-bin | signed | medium |
| decrease | Relative spectral decrease from the first bin | `Sum_{n>=1}((mag[n]-mag[0])/n) / Sum_{n>=1} mag[n]` | dimensionless | signed | medium |
| rolloff | Frequency below which 85% of cumulative magnitude lies | smallest `n` with `Sum_{0..n} mag >= 0.85*Sum mag`, returns `n*scale` | Hz | 0 .. max_freq | high |

Source notes:

- entropy: ffmpeg applies `ln` to raw magnitudes (not a normalised PMF) and divides by `ln(size)`; the result is not a conventional normalised Shannon entropy and is not bounded to `[0,1]`.
- slope/decrease: docs are terse; the exact normalisation (`m = size*0.5`, normalised index) is taken from source.
- Division-by-zero guards return `1.f` (centroid, spread, skewness, kurtosis, entropy) or `0.f` (flatness, crest, slope, decrease).

## astats - time-domain level statistics

Samples are normalised to `[-1, 1]`; `LINEAR_TO_DB(x) = 20*log10(x)`. Metadata key `lavfi.astats.<N>.<Key>`. The `length` option (default 0.05 s) sets the short window for `Noise_floor`, `RMS_peak`, and `RMS_trough`.

| Metric | Measures | ffmpeg computation | Units | Range/scale | Confidence |
| --- | --- | --- | --- | --- | --- |
| RMS level | RMS amplitude of samples | `20*log10( sqrt(Sum x^2 / N) )` | dBFS | <= 0 (0 = full scale) | high |
| Peak level | Largest absolute sample | `20*log10( max(-nmin, nmax) )` | dBFS | <= 0 | high |
| Crest factor | Peak amplitude / RMS amplitude (time domain) | `max(-nmin, nmax) / sqrt(Sum x^2/N)`; returns 1 if RMS=0 | linear ratio, dimensionless (not dB) | >= 1 | high |
| Dynamic range | Span between loudest and quietest non-zero sample | `20*log10( 2*max(\|min\|,\|max\|) / min_non_zero )` | dB | >= 0 | high |
| Noise floor | Minimum local peak over the sliding window | `20*log10(noise_floor)`, min of per-window local peaks over `length` seconds | dBFS | <= 0 | high |
| Flat factor | Run-length flatness at the min/max levels | `20*log10( (min_runs+max_runs)/(min_count+max_count) )` | dB-scaled | >= 0 | medium |
| Peak count | Number of occasions (not samples) the signal hit Min or Max level | `min_count + max_count` | count (integer) | >= 0 | high |

Source quirk (low impact): per-channel metadata `Crest_factor` numerator uses raw `min`/`max` while the console-log path uses normalised `nmin`/`nmax`; they agree for float/double formats. Both paths are peak/RMS linear ratios, never dB.

## ebur128 - loudness

Logged values are labelled `M`, `S`, `I`, `LRA`, `TPK`/`FTPK`. Read-only metadata exports `integrated`, `range`, `lra_low`, `lra_high`, `true_peak`. Loudness uses K-weighting plus mean-square per ITU-R BS.1770; true peak uses libswresample oversampling.

| Metric | Measures | Computation / window | Units | Range/scale | Confidence |
| --- | --- | --- | --- | --- | --- |
| Integrated loudness (I) | Gated programme loudness over the whole input | BS.1770 K-weighted mean-square, two-stage gating | LUFS | typ. <= 0 | high |
| Loudness Range (LRA) | Statistical spread of short-term loudness | distribution of 3 s short-term values; `lra_low`/`lra_high` in LUFS | LU | >= 0 | high |
| True Peak | Inter-sample peak on the oversampled signal | peak of the up-sampled signal via libswresample | dBTP | typ. <= 0 | high |
| Momentary (M) | Loudness over a 400 ms window | BS.1770 loudness, 400 ms sliding | LUFS (or LU if relative) | - | high |
| Short-term (S) | Loudness over a 3 s window | BS.1770 loudness, 3 s sliding | LUFS (or LU) | - | high |

Gating (BS.1770-2 onward, adopted by EBU R128 / Tech 3341): absolute gate -70 LUFS, then a relative gate -10 LU below the absolute-gated mean. (From the named standards, not the ffmpeg docs.)

## loudnorm - EBU R128 normalisation (FFmpeg 8.1)

JSON stats print at filter teardown when `print_format=json`. Two measurement states: `r128_in` (raw input) and `r128_out` (post-processing output). Output is exactly these 10 keys; no gain/offset field exists in 8.1 (any blog or master claim of extra fields does not apply). 8.1 is byte-identical to master for options, struct, JSON, and decision regions.

| Field | Measures | I/O/Control | Units | Range/scale | Confidence |
| --- | --- | --- | --- | --- | --- |
| `input_i` | Integrated loudness of input | Input (measured) | LUFS | negative-going; `%.2f` | high |
| `input_tp` | Max sample peak across channels of input, `20*log10(tp_in)` | Input (measured) | dBTP | typ. <= 0 | high (sample peak, not oversampled true-peak meter) |
| `input_lra` | Loudness range of input | Input (measured) | LU | >= 0 | high |
| `input_thresh` | Relative gating threshold of input | Input (measured) | LUFS | negative-going | high |
| `output_i` | Integrated loudness of processed output | Output (measured) | LUFS | negative-going | high |
| `output_tp` | Max sample peak across channels of output | Output (measured) | dBTP | typ. <= 0; `%+.2f` | high |
| `output_lra` | Loudness range of processed output | Output (measured) | LU | >= 0 | high |
| `output_thresh` | Relative gating threshold of output | Output (measured) | LUFS | negative-going | high |
| `normalization_type` | Which path ran | Control (decision) | string | `linear` or `dynamic` | high |
| `target_offset` | `target_i - output_i`: residual gap to target integrated loudness; feed back as `offset` on a second pass | Control (residual) | LU | signed, ~0 | high |

loudnorm default targets and valid option ranges (AVOption table, 8.1; `{default}, min, max`):

- `I` / `i`: -24.0, range -70.0 .. -5.0 (integrated loudness target, LUFS)
- `LRA` / `lra`: 7.0, range 1.0 .. 50.0 (loudness range target, LU)
- `TP` / `tp`: -2.0, range -9.0 .. 0.0 (max true peak, dBTP)
- `linear`: 1 (bool, default on) - linear normalisation attempted only if all four `measured_*` values are supplied
- `dual_mono`: 0; `print_format`: `none|json|summary`

Method: K-weighted loudness per ITU-R BS.1770 / EBU R128 via the bundled `ebur128`. Dynamic mode (default unless linear preconditions are met) applies a per-frame Gaussian-smoothed gain envelope plus a true-peak limiter and forces the input to 192000 Hz internally. Linear mode applies a single static gain `offset` to all samples. `normalization_type` reports which ran. loudnorm's reported `*_tp` is sample-peak; the standalone `ebur128` filter's True Peak is oversampled.

## Disambiguations

- Spectral crest vs crest factor: `aspectralstats.crest` = `max(magnitude)/mean(magnitude)` over the frequency-domain magnitude spectrum (per-frame spectral peakiness). `astats` Crest factor = `peak_sample/RMS` in the time domain. Different domains; both are linear dimensionless ratios >= 1, never dB. Do not conflate.
- Kurtosis baseline: `aspectralstats.kurtosis` is Pearson kurtosis (4th-power moment / `Sum mag * spread^4`). No `-3` and no `-0` subtraction. It is not excess kurtosis.
- Flatness scale: a 0-1 linear ratio (geometric mean / arithmetic mean of magnitudes), not dB. `1.0` = flat spectrum, toward `0` = peaky.
- Entropy scale/basis: `-Sum(mag*ln(mag+eps)) / ln(N)`, natural log, normalised by `ln(N)` with `N` = bins. Magnitudes are raw (not a PMF), so this is not a conventional 0-1 normalised entropy and is not bounded to `[0,1]`.
- Flux normalisation: L2 norm between consecutive frames, per-frame, not normalised by bin count or energy. The first frame compares against a zeroed previous frame.
- True-peak provenance: `ebur128` True Peak is oversampled (per BS.1770 Annex 2). `loudnorm` `*_tp` is sample peak (`20*log10(sample_peak)`), not oversampled.

## Standards and platform targets

External reference targets, not interpretation. Each row marks whether it is a formal standard or a platform norm.

| Target | Exact value | Tolerance / extras | Publisher | Classification |
| --- | --- | --- | --- | --- |
| ITU-R BS.1770 | measurement method only (LKFS, dBTP) | 4x oversampling, K-weighting; defines method, not targets | ITU-R | standard |
| EBU R128 integrated | -23.0 LUFS | +/-1.0 LU (live); +/-0.5 LU non-live programme (since v3.0) | EBU | standard (Recommendation) |
| EBU R128 true peak ceiling | -1 dBTP | production max; meas. tol. +/-0.3 dB; meter per BS.1770/Tech 3341 | EBU / ITU-R | standard |
| ATSC A/85 (US TV) | -24 LKFS | +/-2 dB; CALM-Act-mandated for US commercials | ATSC | standard (US, legally mandated for commercials) |
| Spotify | -14 LUFS | playback ref (Loud -11 / Normal -14 / Quiet -19); mastering <= -1 dBTP | Spotify | platform-norm |
| Apple Podcasts | -16 LKFS | +/-1 dB; true peak <= -1 dBFS; per BS.1770-5 | Apple | platform-norm |
| Apple Music (Sound Check) | -16 LUFS | proprietary normalisation | Apple | platform-norm |
| YouTube | ~ -14 LUFS | observed normalisation reference; no formal spec | YouTube | platform-norm |
| ACX / Audible (audiobook) | -23 to -18 dB RMS | peak <= -3 dB; noise floor <= -60 dB RMS; submission gate (RMS/dBFS) | ACX (Amazon) | platform-norm (binding submission spec) |
| AES TD1004 / TD1008 (streaming) | -16 to -20 LUFS | max peak -1.0 dBTP; TD1008 (2021): -18 speech/mixed, -16 music | AES | recommendation (technical document) |

Provenance: formal standards are ITU-R BS.1770, EBU R128, and ATSC A/85 (A/85 is legally enforced in the US via the CALM Act for commercials). Platform norms are Spotify, Apple (Podcasts and Music), YouTube, and ACX. AES TD1004/TD1008 is an AES technical document/recommendation, not a formal standard.

Standards URLs:

- ITU-R BS.1770: https://www.itu.int/rec/R-REC-BS.1770/en
- EBU R128: https://tech.ebu.ch/publications/r128 (PDF: https://tech.ebu.ch/docs/r/r128.pdf)
- EBU Tech 3341: https://tech.ebu.ch/publications/tech3341
- EBU Tech 3342: https://tech.ebu.ch/publications/tech3342
- ATSC A/85: https://www.atsc.org/.../A85-2013.pdf
- AES TD1004: https://aes.org/.../AESTD1004_1_15_10.pdf
- Spotify: https://support.spotify.com/us/artists/article/loudness-normalization/
- Apple Podcasts: https://podcasters.apple.com/support/893-audio-requirements
- ACX: https://help.acx.com/s/article/what-are-the-acx-audio-submission-requirements

## Producing the metrics

Canonical ffmpeg invocations. `-f null -` discards output and keeps the filter's printed stats.

```bash
# Per-frame spectral statistics (aspectralstats)
ffmpeg -i in.wav -af aspectralstats -f null -

# Time-domain level statistics (astats)
ffmpeg -i in.wav -af astats -f null -

# Loudness: integrated, LRA, true peak, momentary, short-term (ebur128)
ffmpeg -i in.wav -af ebur128 -f null -

# Loudness measurement as machine-readable JSON (loudnorm, measurement pass)
ffmpeg -i in.wav -af loudnorm=print_format=json -f null -
```

To collect per-frame `aspectralstats` or `astats` metadata for downstream parsing, route the metadata to a log with `ametadata`:

```bash
ffmpeg -i in.wav -af aspectralstats,ametadata=mode=print:file=spectral.log -f null -
ffmpeg -i in.wav -af astats=metadata=1,ametadata=mode=print:file=levels.log -f null -
```

Spectrogram image (`showspectrumpic`): renders the signal as a 2-D image. The x axis is time, the y axis is frequency, and magnitude is mapped to colour. `scale` selects the magnitude mapping (`lin`, `log`, `sqrt`, `cbrt`); `fscale` selects the frequency-axis mapping (`lin` or `log`).

```bash
ffmpeg -i in.wav -lavfi showspectrumpic=s=1280x480:scale=log:fscale=log spectrogram.png
```
