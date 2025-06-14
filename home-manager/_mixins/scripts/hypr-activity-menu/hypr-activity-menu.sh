#!/usr/bin/env bash

set +e  # Disable errexit
set +u  # Disable nounset
appname="hypr-activity-menu"
work=" Work Out"
play=" Chill Out"
record_podcast="️ Record Podcast"
create_video="󰿎 Create Video"
play_retro="️󰺵 Retro Games"
clear="󰚑 Obliterate"
logout="󰐦 Logout"
selected=$(echo -e "$work\n$play\n$record_podcast\n$create_video\n$play_retro\n$clear\n$logout" | fuzzel --dmenu --prompt "󱑞 " --lines=7 --width=17)
case $selected in
  "$clear")
    notify-desktop "$clear" "Whelp! Dropping bombs on every application!" --app-name="$appname" --icon="process-stop"
    hypr-activity clear
    ;;
  "$logout") hypr-activity logout;;
  "$work")
    notify-desktop "$work" "Time to knuckle down. Here's comes the work session." --app-name="$appname" --icon="start-here"
    hypr-activity work
    notify-desktop "Session is ready" "The desktop session is all set and ready to go." --app-name="$appname" --icon="checkmark"
    ;;
  "$play")
    notify-desktop "$play" "Time to chill out. Here's comes the play time session." --app-name="$appname" --icon="start-here"
    hypr-activity play
    notify-desktop "Session is ready" "The desktop session is all set and ready to go." --app-name="$appname" --icon="checkmark"
    ;;    
  "$record_podcast")
    notify-desktop "$record_podcast" "Get something to drink and clear your throat. Time to chat with Alan and Mark." --app-name="$appname" --icon="audio-input-microphone"
    hypr-activity record_podcast
    notify-desktop "Session is ready" "Podcast studio session is initialised." --app-name="$appname" --icon="checkmark"
    ;;
  "$create_video")
    notify-desktop "$create_video" "Lights. Camera. Action. Setting up the session to create a video." --app-name="$appname" --icon="gnome-twitch"
    hypr-activity create_video
    notify-desktop "Session is ready" "Video creation mode is engaged and ready to go." --app-name="$appname" --icon="checkmark"
    ;;
  "$play_retro")
    notify-desktop "$play_retro" "Two grown men reignite the ultimate playground fight of their pasts: which is better, the Commodore 64 or ZX Spectrum?" --app-name="$appname" --icon="input-gaming"
    hypr-activity 8bitversus
    notify-desktop "Session is ready" "Dust of your cassette tapes, retro-gaming session is ready." --app-name="$appname" --icon="checkmark"
    ;;
esac
