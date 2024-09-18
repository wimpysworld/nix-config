#!/usr/bin/env bash

set +e  # Disable errexit
set +u  # Disable nounset
set +o pipefail  # Disable pipefail

if [ -z "$1" ]; then
  echo "Usage: $(basename "$0") <file>"
  exit 1
fi

if [ ! -e "$1" ]; then
  echo "File not found: $1"
  exit 1
fi

case "$2" in
    p1) PRESET="p1";; #fastest (lowest quality)
    p2) PRESET="p2";; #faster (lower quality)
    p3) PRESET="p3";; #fast (low quality)
    p4) PRESET="p4";; #medium (default)
    p5) PRESET="p5";; #slow (good quality)
    p6) PRESET="p6";; #slower (better quality)
    p7) PRESET="p7";; #slowest (best quality)
    *)  PRESET="p4";;
esac

VIDEO_IN="$1"
VIDEO_OUT="${VIDEO_IN%.*}-$PRESET.mp4"

# Covert input video to H.264 MP4/AAC for YouTube
ffmpeg \
  -i "$VIDEO_IN" \
  -c:v h264_nvenc \
  -preset "$PRESET" \
  -rc constqp \
  -qp 10 \
  -coder cabac \
  -b_ref_mode middle \
  -rgb_mode yuv420 \
  -pix_fmt yuv420p \
  -c:a aac \
  -b:a 384k "$VIDEO_OUT"
