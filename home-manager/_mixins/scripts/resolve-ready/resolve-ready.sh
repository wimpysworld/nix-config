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
    hq) PROFILE="dnxhr_hq";; # high quality
    sq) PROFILE="dnxhr_sq";; # standard quality
    *)  PROFILE="dnxhr_lb";; # low bandwidth
esac

VIDEO_IN="$1"
VIDEO_OUT="${VIDEO_IN%.*}.mov"

# Covert input video to DNxHR LB 8-bit mov
ffmpeg -i "$VIDEO_IN" -c:v dnxhd -profile:v "$PROFILE" -c:a alac -pix_fmt yuv422p "$VIDEO_OUT"
