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

# Result in bitrate of ~20 Mb/s for 1080p@60fps for both codecs
case "$2" in
    265|h265|H265|hevc|HEVC)
      VIDEO_QP="12"
      VIDEO_CODEC="hevc_nvenc"
      VIDEO_EXTRA=""
      CONTAINER_FLAGSNTAGS="-movflags +faststart -tag:v hvc1"
      ;;
    264|h264|H264|*)
      VIDEO_QP="10"
      VIDEO_CODEC="h264_nvenc"
      VIDEO_EXTRA="-temporal-aq 1 -coder cabac -b_ref_mode middle"
      CONTAINER_FLAGSNTAGS="-movflags +faststart"
      ;;
esac

# Encoding speed at p4:
# NVIDIA T600 file size and ecoding speed from 2min sample video 1080p@60fps:
# H.264
# h264-p1 fps=285 q=9.0  Lsize=  456397kB bitrate=31629.0kbits/s speed=4.76x
# h264-p2 fps=286 q=9.0  Lsize=  449052kB bitrate=31120.0kbits/s speed=4.77x
# h264-p3 fps=328 q=11.0 Lsize=  376852kB bitrate=26116.4kbits/s speed=5.46x
# h264-p4 fps=371 q=13.0 Lsize=  315248kB bitrate=21847.2kbits/s speed=6.18x (deminishing returns)
# h264-p5 fps=369 q=13.0 Lsize=  315132kB bitrate=21839.1kbits/s speed=6.16x
# h264-p6 fps=248 q=13.0 Lsize=  309255kB bitrate=21431.8kbits/s speed=4.13x
# h264-p7 fps=245 q=13.0 Lsize=  309237kB bitrate=21430.6kbits/s speed=4.08x
# H.265
# hevc-p1 fps=391 q=11.0 Lsize=  312001kB bitrate=21622.2kbits/s speed=6.52x
# hevc-p2 fps=388 q=11.0 Lsize=  311778kB bitrate=21606.7kbits/s speed=6.46x
# hevc-p3 fps=361 q=11.0 Lsize=  305195kB bitrate=21150.5kbits/s speed=6.02x
# hevc-p4 fps=331 q=11.0 Lsize=  289800kB bitrate=20083.6kbits/s speed=5.51x (deminishing returns)
# hevc-p5 fps=331 q=11.0 Lsize=  289800kB bitrate=20083.6kbits/s speed=5.51x
# hevc-p6 fps=294 q=11.0 Lsize=  288778kB bitrate=20012.8kbits/s speed= 4.9x
# hevc-p7 fps=219 q=11.0 Lsize=  290136kB bitrate=20106.8kbits/s speed=3.65x
case "$3" in
    p1) VIDEO_PRESET="p1";; #fastest (lowest quality)
    p2) VIDEO_PRESET="p2";; #faster (lower quality)
    p3) VIDEO_PRESET="p3";; #fast (low quality)
    p4) VIDEO_PRESET="p4";; #medium (default)
    p5) VIDEO_PRESET="p5";; #slow (good quality)
    p6) VIDEO_PRESET="p6";; #slower (better quality)
    p7) VIDEO_PRESET="p7";; #slowest (best quality)
    *)  VIDEO_PRESET="p4";;
esac

AUDIO_EXTRA=""
AUDIO_CODEC="aac"
AUDIO_BITRATE="384k"
if [ "$AUDIO_CODEC" = "libfdk_aac" ]; then
    AUDIO_EXTRA=" -profile:a aac_low"
fi

FILE_IN="$1"
FILE_OUT="${FILE_IN%.*}-$VIDEO_CODEC-$VIDEO_PRESET.mp4"

# Export a video to H264/H265 with AAC-LC for YouTube
# - https://support.google.com/youtube/answer/1722171
# shellcheck disable=SC2086
echo -e "\nEncoding: $FILE_OUT"
ffmpeg \
    -y \
    -hide_banner \
    -loglevel quiet \
    -stats \
    -i "$FILE_IN" \
    -c:v "$VIDEO_CODEC" $VIDEO_EXTRA \
    -preset "$VIDEO_PRESET" \
    -rc constqp \
    -qp "$VIDEO_QP" \
    -rc-lookahead 30 \
    -2pass 1 \
    -multipass fullres \
    -spatial-aq 1 \
    -strict_gop 1 \
    -rgb_mode yuv420 \
    -pix_fmt yuv420p \
    -c:a "${AUDIO_CODEC}" $AUDIO_EXTRA \
    -b:a "$AUDIO_BITRATE" \
    $CONTAINER_FLAGSNTAGS "$FILE_OUT"
