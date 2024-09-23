#!/usr/bin/env bash

set +e  # Disable errexit
set +u  # Disable nounset
set +o pipefail  # Disable pipefail

function usage() {
    echo "Usage: $(basename "$0") sample.yuv [--bitrate 20M ] [--quality 16]"
    exit 1
}

if [ -z "$1" ]; then
    usage
fi

if [ ! -e "$1" ]; then
    echo "File not found: $1"
    exit 1
fi

TEST_FILE="$1"
shift

EXHAUSTIVE=0
CODECS=(h264_nvenc hevc_nvenc av1_nvenc)
PRESETS=(p4)
RC=""

# Parse options
while [ -n "$1" ]; do
    case "$1" in
        --bitrate)
            shift
            if [ -n "$RC" ]; then
                echo "Error: --bitrate and --quality are mutually exclusive"
                exit 1
            fi
            # check that bitrate is in the for of nnM
            if ! echo "$1" | grep -qE "^[0-9]+[M]$"; then
                echo "Error: --bitrate must be in the format of nnM, where nn is the target bitrate."
                exit 1
            fi
            RC="--bitrate $1";;
        --exhaustive)
            EXHAUSTIVE=1
            CODECS=(h264_nvenc h264_vaapi hevc_nvenc hevc_vaapi av1_nvenc av1_vaapi)
            PRESETS=(p1 p2 p3 p4 p5 p6 p7)
            ;;
        --quality)
            shift
            if [ -n "$RC" ]; then
                echo "Error: --bitrate and --quality are mutually exclusive"
                exit 1
            fi
            RC="--quality $1";;
        *) usage;;
    esac
    shift
done

# Configure rate control
if [ -z "$RC" ]; then
    echo "Error: --quality or --bitrate is required"
    exit 1
fi

# shellcheck disable=SC2086
for CODEC in "${CODECS[@]}"; do
    for PRESET in "${PRESETS[@]}"; do
        youtube-ready "$TEST_FILE" --codec $CODEC --preset $PRESET $RC --vmaf --benchmark
        # vaapi based codecs have no presets or other options, so break early
        if [[ "$CODEC" == *_vaapi* ]]; then
            break
        fi
        if [ "$EXHAUSTIVE" -eq 1 ]; then
            youtube-ready "$TEST_FILE" --codec $CODEC --preset $PRESET $RC --aq --vmaf --benchmark
            youtube-ready "$TEST_FILE" --codec $CODEC --preset $PRESET $RC --lookahead --vmaf --benchmark
            youtube-ready "$TEST_FILE" --codec $CODEC --preset $PRESET $RC --multipass --vmaf --benchmark
            youtube-ready "$TEST_FILE" --codec $CODEC --preset $PRESET $RC --aq --lookahead --vmaf --benchmark
            youtube-ready "$TEST_FILE" --codec $CODEC --preset $PRESET $RC --aq --multipass --vmaf --benchmark
            youtube-ready "$TEST_FILE" --codec $CODEC --preset $PRESET $RC --aq --lookahead --multipass --vmaf --benchmark
        fi
    done
done

# Collate the results into a single CSV file
echo "Filename,Codec,Rate Control,Preset,Quality,Bitrate,Adaptive Quality,Lookahead,Multipass,Encode FPS,Encode Speed,Encode Bitrate,Encode Size,VMAF Average,VMAF 1% Lows" > "$TEST_FILE.csv"
# Concatenate all the .txt file in the current directory from oldest to newest to a file
# shellcheck disable=SC2046
cat $(ls -1tr ./*.txt) >> "$TEST_FILE.csv"
rm ./*.mp4.txt
echo "Results saved to $TEST_FILE.csv"
