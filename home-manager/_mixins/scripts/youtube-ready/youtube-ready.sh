#!/usr/bin/env bash

set +e  # Disable errexit
set +u  # Disable nounset
set +o pipefail  # Disable pipefail

function usage() {
    echo "Usage: $(basename "$0") video.mov [--aq] [--bitrate 12M ] [--benchmark] [--codec h264_nvenc,h264_vaapi] [--lookahead] [--multipass] [--preset p1-p7] [--quality 20] [--vmaf]"
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

BENCHMARK=0
HW_ACCEL=""
# Spatial and Temporal AQ is disabled by default
# - It slows down the encoding process with a slight reduction in VMAF score
# - It is beneficial for fast moving content, such as games
VIDEO_AQ=""
VIDEO_BITRATE=""
VIDEO_CODEC="h264_nvenc"
# Lookahead is disabled by default
# - It speeds up H.264 encoding process with a very slightly reduced VMAF score
# - H.264 average bit rate will be higher with lookahead enabled
# - Has no effect on H.265 encoding performance or bit rate control
VIDEO_EXTRA=""
VIDEO_FILTER="-vf format=nv12"
VIDEO_LOOKAHEAD=""
# Multipass is disabled by default
# - Slows down encode time with very little bitrate saving
# - Also, very slightly lower VMAF score
VIDEO_MULTIPASS=""
# - https://ottverse.com/top-rung-of-encoding-bitrate-ladder-abr-video-streaming/
VIDEO_PRESET="p4"
VIDEO_QUALITY=""
VIDEO_RC_MODE=""
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
        --benchmark) BENCHMARK=1;;
        --bitrate)
            shift
            VIDEO_BITRATE="$1";;
        --codec)
            shift
            case "$1" in
                av1_nvenc|av1_vaapi|h264_nvenc|h264_vaapi|hevc_nvenc|hevc_vaapi) VIDEO_CODEC="$1";;
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
        --quality)
            shift
            VIDEO_QUALITY="$1";;
        --vmaf) VMAF=1;;
        *) usage;;
    esac
    shift
done


if [ -n "$VIDEO_QUALITY" ] && [ -n "$VIDEO_BITRATE" ]; then
    echo "Error: --quality and --bitrate are mutually exclusive"
    exit 1
fi

# Configure rate control
if [ -n "$VIDEO_QUALITY" ]; then
    case "$VIDEO_CODEC" in
        *_nvenc) VIDEO_RC_MODE="-rc constqp -qp $VIDEO_QUALITY";;
        *_vaapi) VIDEO_RC_MODE="-rc_mode CQP -qp $VIDEO_QUALITY";;
    esac
elif [ -n "$VIDEO_BITRATE" ]; then
    # check that VIDEO_BITRATE is in the for of 12M
    if ! echo "$VIDEO_BITRATE" | grep -qE "^[0-9]+[M]$"; then
        echo "Error: --bitrate must be in the format of 12M"
        exit 1
    fi
    case "$VIDEO_CODEC" in
        *_nvenc)
          VIDEO_RC_MODE="-rc cbr -cbr 1"
          # Alerts the user that lookahead hugely improves *all* NVENC encoders when using CBR
          if [ -z "$VIDEO_LOOKAHEAD" ]; then
              echo "Warning:  '--lookahead' significantly improves video quality when using NVENC CBR "
          fi
          # hevc_nvenv only accepts lower case 'm' for the bitrate
          if [ "$VIDEO_CODEC" == "hevc_nvenc" ]; then
              VIDEO_EXTRA="-b:v ${VIDEO_BITRATE,,}"
          else
              VIDEO_EXTRA="-b:v $VIDEO_BITRATE"
          fi
          ;;
        *_vaapi)
          VIDEO_RC_MODE="-rc_mode CBR"
          VIDEO_EXTRA="-b:v $VIDEO_BITRATE"
          ;;
    esac
else
    echo "Error: --quality or --bitrate is required"
    exit 1
fi

# Set the video codec options
case "$VIDEO_CODEC" in
    av1_nvenc)
      VIDEO_EXTRA+=" -b_ref_mode middle -strict_gop 1"
      ;;
    av1_vaapi)
      HW_ACCEL="-hwaccel vaapi -hwaccel_output_format vaapi -vaapi_device /dev/dri/renderD128"
      VIDEO_FILTER+="|vaapi,hwupload"
      # Not available for the VA-API encoder
      VIDEO_AQ=""
      VIDEO_LOOKAHEAD=""
      VIDEO_MULTIPASS=""
      VIDEO_PRESET=""
      ;;
    hevc_nvenc)
      VIDEO_EXTRA+=" -level:v 4.1 -profile:v main -tag:v hvc1 -strict_gop 1"
      ;;
    hevc_vaapi)
      VIDEO_EXTRA+=" -level:v 4.1 -profile:v main -tag:v hvc1"
      HW_ACCEL="-hwaccel vaapi -hwaccel_output_format vaapi -vaapi_device /dev/dri/renderD128"
      VIDEO_FILTER+="|vaapi,hwupload"
      # Not available for the VA-API encoder
      VIDEO_AQ=""
      VIDEO_LOOKAHEAD=""
      VIDEO_MULTIPASS=""
      VIDEO_PRESET=""
      ;;
    h264_nvenc)
      VIDEO_EXTRA+=" -coder:v cabac -level:v 4.2 -profile:v high -b_ref_mode middle -strict_gop 1"
      # Enable Temporal AQ for H264; which is not available for H265
      if [ -n "$VIDEO_AQ" ]; then
          VIDEO_AQ+=" -temporal_aq 1"
      fi
      ;;
    h264_vaapi)
      HW_ACCEL="-hwaccel vaapi -hwaccel_output_format vaapi -vaapi_device /dev/dri/renderD128"
      VIDEO_EXTRA+=" -coder:v cabac -level:v 4.2 -profile:v high"
      VIDEO_FILTER+="|vaapi,hwupload"
      # Not available for the VA-API encoder
      VIDEO_AQ=""
      VIDEO_LOOKAHEAD=""
      VIDEO_MULTIPASS=""
      VIDEO_PRESET=""
      ;;
esac

FILE_EXT="mp4"
FILE_OUT="${FILE_IN%.*}-$VIDEO_CODEC.$FILE_EXT"
if [ -n "$VIDEO_PRESET" ]; then
    FILE_OUT="${FILE_OUT%.*}-$VIDEO_PRESET.$FILE_EXT"
fi
if [ -n "$VIDEO_AQ" ]; then
    FILE_OUT="${FILE_OUT%.*}-AQ.$FILE_EXT"
fi
if [ -n "$VIDEO_LOOKAHEAD" ]; then
    FILE_OUT="${FILE_OUT%.*}-LAH.$FILE_EXT"
fi
if [ -n "$VIDEO_MULTIPASS" ]; then
    FILE_OUT="${FILE_OUT%.*}-MP.$FILE_EXT"
fi

if [ -n "$VIDEO_PRESET" ]; then
    VIDEO_PRESET="-preset $VIDEO_PRESET"
fi

# Check if libfdk_aac is available
FFMPEG_CHECK=$(ffmpeg -hide_banner -h encoder=libfdk_aac 2>&1 | tail -1)
AUDIO_BITRATE="384k"
AUDIO_CUTOFF="20000"
AUDIO_CODEC="libfdk_aac"
AUDIO_EXTRA="-b:a $AUDIO_BITRATE -profile:a aac_low -cutoff $AUDIO_CUTOFF"
# Fallback to native FFmpeg AAC encoder if libfdk_aac is not available
if echo "$FFMPEG_CHECK" | grep -q "is not recognized by FFmpeg"; then
    AUDIO_CODEC="aac"
fi

# Export a video to H264/H265 with AAC-LC for YouTube
# - https://support.google.com/youtube/answer/1722171
# shellcheck disable=SC2086
echo -e "Encoding: $FILE_OUT"
ffmpeg \
    -y \
    -hide_banner \
    -loglevel quiet \
    -stats \
    $HW_ACCEL \
    -i "$FILE_IN" \
    $VIDEO_FILTER \
    -c:v "$VIDEO_CODEC" $VIDEO_EXTRA \
    $VIDEO_PRESET \
    $VIDEO_RC_MODE \
    $VIDEO_MULTIPASS \
    $VIDEO_AQ \
    $VIDEO_LOOKAHEAD \
    -c:a "$AUDIO_CODEC" $AUDIO_EXTRA \
    -movflags +faststart "$FILE_OUT" 2>&1

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
echo ""
# Remove the output file if the benchmark flag is set
if [ "$BENCHMARK" -eq 1 ]; then
  rm -f "$FILE_OUT"
  rm -f "$FILE_OUT.csv"
fi
