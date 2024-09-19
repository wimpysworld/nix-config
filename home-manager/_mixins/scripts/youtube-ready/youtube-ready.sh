#!/usr/bin/env bash

set +e  # Disable errexit
set +u  # Disable nounset
set +o pipefail  # Disable pipefail

function usage() {
    echo "Usage: $(basename "$0") video.mov [--aq] [--codec h264,h265] [--lookahead] [--multipass] [--preset p1-p7] [--qp 0-51] [--vmaf]"
    exit 1
}

if [ -z "$1" ]; then
    usage
fi

if [ ! -e "$1" ]; then
    echo "File not found: $1"
    exit 1
fi

FILE_IN="$1"
shift

CONTAINER_FLAGSNTAGS="-movflags +faststart"
# Spatial and Temporal AQ is disabled by default
# - It slows down the encoding process with a slight reduction in VMAF score
# - It is beneficial for fast moving content, such as games
VIDEO_AQ=""
VIDEO_CODEC="h264_nvenc"
# Lookahead is disabled by default
# - It speeds up H.264 encoding process with a very slightly reduced VMAF score
# - H.264 average bit rate will be higher with lookahead enabled
# - Has no effect on H.265 encoding performance or bit rate control
VIDEO_EXTRA=""
VIDEO_LOOKAHEAD=""
# Multipass is disabled by default
# - Slows down encode time with very little bitrate saving
# - Also, very slightly lower VMAF score
VIDEO_MULTIPASS=""
# Preset P4 with QP 10 results in average VMAF of 97.7 for H264 and H265
# with lows of 97.0 for both.
# - https://ottverse.com/top-rung-of-encoding-bitrate-ladder-abr-video-streaming/
VIDEO_PRESET="p4"
VIDEO_QP="10"
VMAF=0

# NVIDIA T600 file size and ecoding speed from 2min sample video 1080p@60fps:
# H.264 (QP 10)
# h264-p1 fps=536 q=9.0  size= 358M bitrate=25360.5kbits/s speed=8.94x vmaf_avg=97.78 vmaf_low=97.10
# h264-p2 fps=533 q=9.0  size= 352M bitrate=24920.0kbits/s speed=8.88x vmaf_avg=97.78 vmaf_low=97.10
# h264-p3 fps=470 q=11.0 size= 309M bitrate=21926.8kbits/s speed=7.84x vmaf_avg=97.78 vmaf_low=97.10
# h264-p4 fps=369 q=13.0 size= 266M bitrate=18857.7kbits/s speed=6.15x vmaf_avg=97.77 vmaf_low=97.04
# h264-p5 fps=369 q=13.0 size= 266M bitrate=18843.3kbits/s speed=6.15x vmaf_avg=97.77 vmaf_low=97.01
# h264-p6 fps=379 q=13.0 size= 269M bitrate=19058.7kbits/s speed=6.32x vmaf_avg=97.77 vmaf_low=97.01
# h264-p7 fps=369 q=13.0 size= 269M bitrate=19050.7kbits/s speed=6.14x vmaf_avg=97.77 vmaf_low=97.04
# H.265
# hevc-p1 fps=424 q=9.0  size= 328M bitrate=23259.7kbits/s speed=7.07x vmaf_avg=97.71 vmaf_low=96.96
# hevc-p2 fps=419 q=9.0  size= 328M bitrate=23246.9kbits/s speed=6.98x vmaf_avg=97.71 vmaf_low=96.96
# hevc-p3 fps=390 q=9.0  size= 320M bitrate=22659.7kbits/s speed= 6.5x vmaf_avg=97.72 vmaf_low=97.01
# hevc-p4 fps=351 q=9.0  size= 303M bitrate=21450.5kbits/s speed=5.86x vmaf_avg=97.73 vmaf_low=97.01
# hevc-p5 fps=346 q=9.0  size= 304M bitrate=21514.0kbits/s speed=5.77x vmaf_avg=97.73 vmaf_low=97.01
# hevc-p6 fps=297 q=9.0  size= 303M bitrate=21440.4kbits/s speed=4.95x vmaf_avg=97.73 vmaf_low=96.99
# hevc-p7 fps=212 q=9.0  size= 303M bitrate=21497.4kbits/s speed=3.54x vmaf_avg=97.74 vmaf_low=97.00

# Parse options
while [ -n "$1" ]; do
    case "$1" in
        --aq) VIDEO_AQ="-spatial_aq 1";;
        --codec)
            shift
            case "$1" in
                265|h265|H265|hevc|HEVC) VIDEO_CODEC="hevc_nvenc";;
                264|h264|H264) VIDEO_CODEC="h264_nvenc";;
                *) usage;;
            esac
            ;;
        --lookahead) VIDEO_LOOKAHEAD="-rc-lookahead 8";;
        --multipass) VIDEO_MULTIPASS="-2pass 1 -multipass fullres";;
        --preset)
            shift
            case "$1" in
                p1|p2|p3|p4|p5|p6|p7) VIDEO_PRESET="$1";;
                *) usage;;
            esac
            ;;
        --qp)
            shift
            VIDEO_QP="$1";;
        --vmaf) VMAF=1;;
        *) usage;;
    esac
    shift
done

# Set the video codec options
case "$VIDEO_CODEC" in
    hevc_nvenc)
      CONTAINER_FLAGSNTAGS+=" -tag:v hvc1"
      ;;
    h264_nvenc)
      VIDEO_EXTRA="-coder cabac -b_ref_mode middle"
      # Enable Temporal AQ for H264; which is not available for H265
      if [ -n "$VIDEO_AQ" ]; then
          VIDEO_AQ+=" -temporal_aq 1"
      fi
      ;;
esac

FILE_OUT="${FILE_IN%.*}-$VIDEO_CODEC-$VIDEO_PRESET.mp4"
if [ -n "$VIDEO_AQ" ]; then
    FILE_OUT="${FILE_OUT%.*}-AQ.mp4"
fi
if [ -n "$VIDEO_LOOKAHEAD" ]; then
    FILE_OUT="${FILE_OUT%.*}-LAH.mp4"
fi
if [ -n "$VIDEO_MULTIPASS" ]; then
    FILE_OUT="${FILE_OUT%.*}-MP.mp4"
fi

# Check if libfdk_aac is available
FFMPEG_CHECK=$(ffmpeg -hide_banner -h encoder=libfdk_aac 2>&1 | tail -1)

AUDIO_BITRATE="384k"
AUDIO_CODEC="libfdk_aac"
AUDIO_EXTRA="-profile:a aac_low -cutoff 20000"
# Fallback to native FFmpeg AAC encoder if libfdk_aac is not available
if echo "$FFMPEG_CHECK" | grep -q "is not recognized by FFmpeg"; then
    AUDIO_CODEC="aac"
fi

# Export a video to H264/H265 with AAC-LC for YouTube
# - https://support.google.com/youtube/answer/1722171
# TODO: Add VA-API support: https://www.tauceti.blog/posts/linux-ffmpeg-amd-5700xt-hardware-video-encoding-hevc-h265-vaapi/
# shellcheck disable=SC2086
echo -e "\nEncoding: $FILE_OUT (qp: $VIDEO_QP)"
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
    $VIDEO_MULTIPASS \
    $VIDEO_AQ \
    $VIDEO_LOOKAHEAD \
    -strict_gop 1 \
    -rgb_mode yuv420 \
    -pix_fmt yuv420p \
    -c:a "$AUDIO_CODEC" $AUDIO_EXTRA \
    -b:a "$AUDIO_BITRATE" \
    $CONTAINER_FLAGSNTAGS "$FILE_OUT" 2>&1

if [ "$VMAF" -eq 1 ]; then
  # Get the number of processing units
  THREADS_ALL=$(nproc)
  # Calculate 75% of the number of processing units
  THREADS_VMAF=$(printf "%.0f" "$(echo "${THREADS_ALL} * 0.75" | bc)")
  echo "VMAF quality comparison ($THREADS_VMAF threads)"
  ffmpeg \
    -y \
    -hide_banner \
    -loglevel quiet \
    -stats \
    -i "$FILE_OUT" \
    -i "$FILE_IN" \
    -lavfi libvmaf="n_threads=$THREADS_VMAF:log_fmt=csv:log_path=$FILE_OUT.csv" -f null - 2>&1

  # Get the accurate file size of FILE_OUT in Megabytes and print it
  FILE_SIZE=$(stat -c%s "$FILE_OUT")
  FILE_SIZE_MB=$(echo "scale=0; $FILE_SIZE / 1024 / 1024" | bc)
  echo " - File size:    $FILE_SIZE_MB MB"
  awk -F, '
    NR > 1 {
      sum += $13;
      count++;
      if (NR == 2 || $13 < min) min = $13;
    }
    END {
      if (count > 0) {
        print " - VMAF Average: " sprintf("%.2f", sum / count);
        print " - VMAF Lowest:  " sprintf("%.2f", min);
      } else {
        print "No data";
      }
    }
  ' "$FILE_OUT.csv"
fi
