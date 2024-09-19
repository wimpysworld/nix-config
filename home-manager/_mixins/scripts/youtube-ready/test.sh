#!/usr/bin/env bash

TEST_FILE="sintel_trailer_2k_1080p24.y4m"
TEST_FILE="factory_1080p30.y4m"

for C in h264_nvenc h264_vaapi hevc_nvenc hevc_vaapi; do
#for C in h264_vaapi; do
#for C in hevc_nvenc hevc_vaapi; do
	for P in p1 p2 p3 p4 p5 p6 p7; do
	#for P in p4; do
		~/Zero/nix-config/home-manager/_mixins/scripts/youtube-ready/youtube-ready.sh "$TEST_FILE" --codec $C --preset $P --vmaf
		#~/Zero/nix-config/home-manager/_mixins/scripts/youtube-ready/youtube-ready.sh Test-Delivery.mov --codec $CODEC --preset $P --lookahead
		#~/Zero/nix-config/home-manager/_mixins/scripts/youtube-ready/youtube-ready.sh Test-Delivery.mov --codec $CODEC --preset $P --aq
		#~/Zero/nix-config/home-manager/_mixins/scripts/youtube-ready/youtube-ready.sh Test-Delivery.mov --codec $CODEC --preset $P --multipass
		#~/Zero/nix-config/home-manager/_mixins/scripts/youtube-ready/youtube-ready.sh Test-Delivery.mov --codec $CODEC --preset $P --aq --multipass
		# vaapi has no preset to break after the first run
		if [ "$C" == "h264_vaapi" ] || [ "$C" == "hevc_vaapi" ]; then
		    break
		fi
	done
done
