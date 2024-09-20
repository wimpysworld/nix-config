#!/usr/bin/env bash

#RC="--quality 20"
RC="--bitrate 20M"

#TEST_FILE="factory_1080p30.y4m"
TEST_FILE="tears_of_steel_1080p.webm"
#TEST_FILE="sintel_trailer_2k_1080p24.mkv"

for C in h264_nvenc h264_vaapi hevc_nvenc hevc_vaapi av1_nvenc av1_vaapi; do
    for P in p1 p2 p3 p4 p5 p6 p7; do
        ~/Zero/nix-config/home-manager/_mixins/scripts/youtube-ready/youtube-ready.sh "$TEST_FILE" --codec $C --preset $P $RC --vmaf --benchmark
        # vaapi has no presets or other options so break early
        if [ "$C" == "h264_vaapi" ] || [ "$C" == "hevc_vaapi" ] || [ "$C" == "av1_vaapi" ]; then
            break
        fi
        #~/Zero/nix-config/home-manager/_mixins/scripts/youtube-ready/youtube-ready.sh "$TEST_FILE" --codec $C --preset $P $RC --aq --vmaf --benchmark
        #~/Zero/nix-config/home-manager/_mixins/scripts/youtube-ready/youtube-ready.sh "$TEST_FILE" --codec $C --preset $P $RC --lookahead --vmaf --benchmark
        #~/Zero/nix-config/home-manager/_mixins/scripts/youtube-ready/youtube-ready.sh "$TEST_FILE" --codec $C --preset $P $RC --multipass --vmaf --benchmark
        #~/Zero/nix-config/home-manager/_mixins/scripts/youtube-ready/youtube-ready.sh "$TEST_FILE" --codec $C --preset $P $RC --aq --lookahead --vmaf --benchmark
        #~/Zero/nix-config/home-manager/_mixins/scripts/youtube-ready/youtube-ready.sh "$TEST_FILE" --codec $C --preset $P $RC --aq --multipass --vmaf --benchmark
        #~/Zero/nix-config/home-manager/_mixins/scripts/youtube-ready/youtube-ready.sh "$TEST_FILE" --codec $C --preset $P $RC --aq --lookahead --multipass --vmaf --benchmark
    done
done

# Collate the results into a single CSV file
echo "Filename,Codec,Rate Control,Preset,Quality,Bitrate,Adaptive Quality,Lookahead,Multipass,Encode FPS,Encode Speed,Encode Bitrate,Encode Size,VMAF Average,VMAF 1% Lows,VMAF Lowest" > $TEST_FILE.csv
# Concatenate all the .txt file in the current directory from oldest to newest to a file
cat $(ls -ltr *.txt) >> $TEST_FILE.csv
rm *.mp4.txt
