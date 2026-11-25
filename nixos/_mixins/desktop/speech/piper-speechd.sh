#!/usr/bin/env bash
set -euo pipefail

voices_dir="${1:?missing voices directory}"
voice="${2:-en_GB-cori-medium}"
rate="${3:-0}"
volume="${4:-100}"

if [[ ! -f "${voices_dir}/${voice}.onnx" ]]; then
  voice="en_GB-cori-medium"
fi

sample_rate="$(jq -r '.audio.sample_rate // 22050' "${voices_dir}/${voice}.onnx.json")"

# Map speech-dispatcher rate (-100..100, default 0) to Piper length_scale
# (2.0..0.5, default 1.0): smaller length_scale speaks faster.
length_scale="$(awk -v r="${rate}" 'BEGIN {
  if (r < -100) r = -100;
  if (r > 100) r = 100;
  printf "%.3f", 2 ^ (-r / 100.0);
}')"

# Map speech-dispatcher volume (0..100, default 100) to Piper volume (0.0..1.0).
piper_volume="$(awk -v v="${volume}" 'BEGIN {
  if (v < 0) v = 0;
  if (v > 100) v = 100;
  printf "%.2f", v / 100.0;
}')"

piper \
  --data-dir "${voices_dir}" \
  --model "${voice}" \
  --length-scale "${length_scale}" \
  --volume "${piper_volume}" \
  --output-raw \
  | pw-play \
    --raw \
    --rate "${sample_rate}" \
    --channels 1 \
    --format s16 \
    -
