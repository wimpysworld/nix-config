#!/usr/bin/env bash

set +e  # Disable errexit
set +u  # Disable nounset
set +o pipefail  # Disable pipefail

function usage() {
    echo "Usage: $(basename "$0") video.mov [--aq] [--bitrate 20M ] [--benchmark] [--codec h264_nvenc,h264_vaapi] [--lookahead] [--multipass] [--preset p1-p7] [--quality 16] [--vmaf]"
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
echo -e "Encoding: $FILE_OUT"
# shellcheck disable=SC2086
ffmpeg \
    -y \
    -hide_banner \
    -loglevel quiet \
    -progress "$FILE_OUT.log" \
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

# Get the last fps= value from the log file
ENCODE_FPS=$(grep -oP "fps=\K[0-9.]+" "$FILE_OUT.log" | tail -1)
ENCODE_BITRATE=$(grep -oP "bitrate=\K[0-9.]+" "$FILE_OUT.log" | tail -1)
# Convert bitrate to megabits per second
ENCODE_BITRATE=$(echo "scale=0; $ENCODE_BITRATE / 1024" | bc)
ENCODE_SIZE=$(grep -oP "total_size=\K[0-9.]+" "$FILE_OUT.log" | tail -1)
# Convert total size to megabytes
ENCODE_SIZE=$(echo "scale=0; $ENCODE_SIZE / 1024 / 1024" | bc)
ENCODE_SPEED=$(grep -oP "speed=\K[0-9.]+" "$FILE_OUT.log" | tail -1)

if [ "$VMAF" -eq 1 ]; then
  # Get the number of processing units
  THREADS_ALL=$(nproc)
  # Calculate 75% of the number of processing units
  THREADS_VMAF=$(printf "%.0f" "$(echo "${THREADS_ALL} * 0.75" | bc)")
  echo "Analysis: $FILE_OUT ($THREADS_VMAF threads)"
  ffmpeg \
    -y \
    -hide_banner \
    -loglevel quiet \
    -stats \
    -i "$FILE_OUT" \
    -i "$FILE_IN" \
    -lavfi libvmaf="n_threads=$THREADS_VMAF:log_fmt=csv:log_path=$FILE_OUT.csv" -f null - 2>&1

  # Parse the VMAF values
  VMAF_OUTPUT=$(awk -F, '
    NR > 1 {
      sum += $13;
      count++;
      vmaf_values[count] = $13;
      if (NR == 2 || $13 < min) min = $13;
    }
    END {
      if (count > 0) {
        # Calculate the average and lowest VMAF
        print "VMAF_AVERAGE=" sprintf("%.2f", sum / count);

        # Sort the VMAF values
        asort(vmaf_values);

        # Calculate the 1% lows
        one_percent_index = int(count * 0.01);
        if (one_percent_index < 1) one_percent_index = 1;
        one_percent_low = vmaf_values[one_percent_index];

        print "VMAF_LOWS=" sprintf("%.2f", one_percent_low);
      } else {
        print "No data";
      }
    }
  ' "$FILE_OUT.csv")

  # Extract the VMAF scores from the output
  VMAF_AVERAGE=$(echo "$VMAF_OUTPUT" | grep "VMAF_AVERAGE" | cut -d'=' -f2)
  VMAF_LOWS=$(echo "$VMAF_OUTPUT" | grep "VMAF_LOWS" | cut -d'=' -f2)
  echo " - Encode FPS:   $ENCODE_FPS fps"
  echo " - Encode Speed: $ENCODE_SPEED x"
  echo " - Bitrate:      $ENCODE_BITRATE Mbps"
  echo " - Size:         $ENCODE_SIZE MB"
  echo " - VMAF Average: $VMAF_AVERAGE"
  echo " - VMAF 1% Lows: $VMAF_LOWS"
fi
echo ""
# Remove the output file if the benchmark flag is set
if [ "$BENCHMARK" -eq 1 ]; then
  if [ -n "${VIDEO_AQ}" ]; then
      VIDEO_AQ="Y"
  else
      VIDEO_AQ="N"
  fi
  if [ -n "${VIDEO_LOOKAHEAD}" ]; then
      VIDEO_LOOKAHEAD="Y"
  else
      VIDEO_LOOKAHEAD="N"
  fi
  if [ -n "${VIDEO_MULTIPASS}" ]; then
      VIDEO_MULTIPASS="Y"
  else
      VIDEO_MULTIPASS="N"
  fi
  if [ -n "${VIDEO_PRESET}" ]; then
      VIDEO_PRESET=$(echo "$VIDEO_PRESET" | cut -d' ' -f2)
  else
      VIDEO_PRESET=""
  fi
  VIDEO_RC_MODE=$(echo "$VIDEO_RC_MODE" | cut -d' ' -f2)

  DATA="$FILE_IN,$VIDEO_CODEC,$VIDEO_RC_MODE,$VIDEO_PRESET,$VIDEO_QUALITY,$VIDEO_BITRATE,$VIDEO_AQ,$VIDEO_LOOKAHEAD,$VIDEO_MULTIPASS,$ENCODE_FPS,$ENCODE_SPEED,$ENCODE_BITRATE,$ENCODE_SIZE,$VMAF_AVERAGE,$VMAF_LOWS"
  echo "$DATA" >> "$FILE_OUT.txt"
  rm -f "$FILE_OUT"
  rm -f "$FILE_OUT.csv"
  rm -f "$FILE_OUT.log"
fi
