#!/usr/bin/env bash

set +e  # Disable errexit
set +u  # Disable nounset
appname="hypr-activity-menu"
gsd=" Get Shit Done"
record_linuxmatters="️ Linux Matters"
stream_wimpysworld="󰄀 Wimpys's World"
stream_8bitversus="️󰺵 8-bit VS"
clear="󰅜 Close Everything"
selected=$(echo -e "$gsd\n$record_linuxmatters\n$stream_wimpysworld\n$stream_8bitversus\n$clear" | fuzzel --dmenu --prompt "󱑞 " --lines=5 --width=20)
case $selected in
  "$clear")
    notify-desktop "$clear" "Whelp! Here comes the desktop Thanos snap!" --app-name="$appname" --icon="process-stop"
    hypr-activity clear
    ;;
  "$gsd")
    notify-desktop "$gsd" "Time to knuckle down. Here's comes the default session." --app-name="$appname" --icon="start-here"
    hypr-activity gsd
    notify-desktop "Session is ready" "The desktop session is all set and ready to go." --app-name="$appname" --icon="checkmark"
    ;;
  "$record_linuxmatters")
    notify-desktop "$record_linuxmatters" "Get some Yerba Mate and clear your throat. Time to chat with Alan and Mark." --app-name="$appname" --icon="audio-input-microphone"
    hypr-activity linuxmatters
    notify-desktop "Session is ready" "Podcast studio session is initialised." --app-name="$appname" --icon="checkmark"
    ;;
  "$stream_wimpysworld")
    notify-desktop "$stream_wimpysworld" "Lights. Camera. Action. Setting up the session to stream to Wimpy's World." --app-name="$appname" --icon="gnome-twitch"
    hypr-activity wimpysworld
    notify-desktop "Session is ready" "Streaming session is engaged and ready to go live." --app-name="$appname" --icon="checkmark"
    ;;
  "$stream_8bitversus")
    notify-desktop "$stream_8bitversus" "Two grown men reignite the ultimate playground fight of their pasts: which is better, the Commodore 64 or ZX Spectrum?" --app-name="$appname" --icon="input-gaming"
    hypr-activity 8bitversus
    notify-desktop "Session is ready" "Dust of your cassette tapes, retro-gaming streaming is ready." --app-name="$appname" --icon="checkmark"
    ;;
esac
