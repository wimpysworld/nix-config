#!/usr/bin/env bash

set +e  # Disable errexit
set +u  # Disable nounset
set +o pipefail  # Disable pipefail

PID_FILE="/tmp/virtualcam.pid"
VIDEO_DEVICE_NR="13"
CARD_LABEL="OBS Virtual Camera"
SOURCE_DEVICE="/dev/video0"
TARGET_DEVICE="/dev/video${VIDEO_DEVICE_NR}"
LOG_FILE="/tmp/virtualcam.log"
# The Waybar custom/virtualcam module refreshes on SIGRTMIN+10.
WAYBAR_SIGNAL=10

# Only the Waybar main process handles the signal. Its children, for example
# module scripts, would end on an unhandled real-time signal.
refresh_waybar() {
    systemctl --user kill --kill-whom=main --signal="RTMIN+$WAYBAR_SIGNAL" waybar.service \
        >/dev/null 2>&1 || true
}

notify_error() {
    fyi --urgency=critical --app-name="Virtual Camera" "$1" "$2" >/dev/null 2>&1 || true
}

# Print the PID of the running ffmpeg process. Remove a stale PID file.
running_pid() {
    local pid
    [ -f "$PID_FILE" ] || return 1
    pid=$(cat "$PID_FILE")
    if [ -n "$pid" ] && ps -p "$pid" > /dev/null 2>&1; then
        echo "$pid"
        return 0
    fi
    rm -f "$PID_FILE"
    return 1
}

start() {
    if [ -f "$PID_FILE" ]; then
        echo "Virtual camera is already running (PID: $(cat "$PID_FILE"))."
        exit 1
    fi

    if [ ! -e "$TARGET_DEVICE" ]; then
        echo "Virtual camera device $TARGET_DEVICE is not present."
        echo "Starting virtual camera..."
        # Ensure sudo credentials are fresh
        sudo true
        # Attempt to remove if already loaded, ignore errors
        sudo rmmod v4l2loopback 2>/dev/null
        sudo modprobe v4l2loopback devices=1 video_nr="$VIDEO_DEVICE_NR" card_label="$CARD_LABEL" exclusive_caps=1    
    fi

    if [ ! -e "$TARGET_DEVICE" ]; then
        echo "Error: Virtual camera device $TARGET_DEVICE was not created."
        echo "Make sure v4l2loopback module is installed and loaded correctly."
        notify_error "󰗟 Virtual camera failed to start" "The device $TARGET_DEVICE is not present."
        exit 1
    fi

    # Start ffmpeg in the background
    ffmpeg -f v4l2 -threads 1 -input_format yuyv422 -framerate 60 -video_size 1920x1080 -i "$SOURCE_DEVICE" -c:v copy -f v4l2 "$TARGET_DEVICE" > "$LOG_FILE" 2>&1 &
    FFMPEG_PID=$!
    echo $FFMPEG_PID > "$PID_FILE"
    sleep 1

    if ! ps -p "$FFMPEG_PID" > /dev/null; then
        echo "Error: ffmpeg process (PID: $FFMPEG_PID) failed to start or exited prematurely."
        cat "$LOG_FILE"
        rm "$PID_FILE"
        notify_error "󰗟 Virtual camera failed to start" "$(tail -n 5 "$LOG_FILE")"
        exit 1
    fi

    echo "Virtual camera started (PID: $FFMPEG_PID)."
    echo "Output logged to $LOG_FILE"
    refresh_waybar
}

stop() {
    if [ ! -f "$PID_FILE" ]; then
        echo "Virtual camera is not running."
        exit 1
    fi

    echo "Stopping virtual camera..."
    FFMPEG_PID=$(cat "$PID_FILE")
    if ! kill "$FFMPEG_PID"; then
        rm "$PID_FILE"
        notify_error "󰄀 Virtual camera failed to stop" "Could not stop the ffmpeg process (PID: $FFMPEG_PID)."
        refresh_waybar
        exit 1
    fi
    rm "$PID_FILE"
    echo "Virtual camera stopped."
    refresh_waybar
}

# Print the elapsed time as mm:ss while the camera runs. Print nothing and
# exit 1 when it is off.
status() {
    local pid
    local elapsed
    pid=$(running_pid) || exit 1
    elapsed=$(ps -o etimes= -p "$pid" | tr -d ' ')
    [ -n "$elapsed" ] || exit 1
    printf '%02d:%02d\n' "$((elapsed / 60))" "$((elapsed % 60))"
}

toggle() {
    if running_pid > /dev/null; then
        stop
    else
        start
    fi
}

case "$1" in
    start)
        start
        ;;
    stop)
        stop
        ;;
    status)
        status
        ;;
    toggle)
        toggle
        ;;
    *)
        echo "Usage: $0 {start|stop|status|toggle}"
        exit 1
        ;;
esac

exit 0