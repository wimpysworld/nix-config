#!/usr/bin/env bash

set +e  # Disable errexit
set +u  # Disable nounset
appname="hypr-activity-menu"
gsd="💩 Get Shit Done"
record_linuxmatters="️🎙️ Record Linux Matters"
stream_wimpysworld="📹 Stream Wimpys's World"
stream_8bitversus="️🕹️ Stream 8-bit VS"
clear="🛑 Close Everything"
selected=$(
echo -e "$gsd\n$record_linuxmatters\n$stream_wimpysworld\n$stream_8bitversus\n$clear" |
fuzzel --dmenu --prompt "󱑞 " --lines 5)
case $selected in
    "$clear")
        notify-desktop "$clear" "Whelp! Here comes the desktop Thanos snap!" --app-name="$appname"
        hypr-activity clear
        ;;
    "$gsd")
        notify-desktop "$gsd" "Time to knuckle down. Here's comes the default session." --app-name="$appname"
        hypr-activity gsd
        notify-desktop "💩 Session is ready" "The desktop session is all set and ready to go." --app-name="$appname"
        ;;
    "$record_linuxmatters")
        notify-desktop "$record_linuxmatters" "Get some Yerba Mate and clear your throat. Time to chat with Alan and Mark." --app-name="$appname"
        hypr-activity linuxmatters
        notify-desktop "🎙️ Session is ready" "Podcast studio session is initialised." --app-name="$appname"
        ;;
    "$stream_wimpysworld")
        notify-desktop "$stream_wimpysworld" "Lights. Camera. Action. Setting up the session to stream to Wimpy's World." --app-name="$appname"
        hypr-activity wimpysworld
        notify-desktop "📹 Session is ready" "Streaming session is engaged and ready to go live." --app-name="$appname"
        ;;
    "$stream_8bitversus")
        notify-desktop "$stream_8bitversus" "Two grown men reignite the ultimate playground fight of their pasts: which is better, the Commodore 64 or ZX Spectrum?" --app-name="$appname"
        hypr-activity 8bitversus
        notify-desktop "🕹️ Session is ready" "Dust of your cassette tapes, retro-gaming streaming is ready." --app-name="$appname"
        ;;
esac
