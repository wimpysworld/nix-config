#!/usr/bin/env bash

set +e  # Disable errexit
set +u  # Disable nounset
set +o pipefail  # Disable pipefail

PID_FILE="/tmp/virtualcam.pid"
VIDEO_DEVICE_NR="13"
CARD_LABEL="OBS Virtual Camera"
SOURCE_DEVICE="/dev/video0"
TARGET_DEVICE="/dev/video${VIDEO_DEVICE_NR}"

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
        exit 1
    fi

    # Start ffmpeg in the background
    ffmpeg -f v4l2 -threads 1 -input_format yuyv422 -framerate 60 -video_size 1920x1080 -i "$SOURCE_DEVICE" -c:v copy -f v4l2 "$TARGET_DEVICE" > /tmp/virtualcam.log 2>&1 &
    FFMPEG_PID=$!
    echo $FFMPEG_PID > "$PID_FILE"
    sleep 1

    if ! ps -p "$FFMPEG_PID" > /dev/null; then
        echo "Error: ffmpeg process (PID: $FFMPEG_PID) failed to start or exited prematurely."
        cat /tmp/virtualcam.log
        rm "$PID_FILE"
        exit 1
    fi

    echo "Virtual camera started (PID: $FFMPEG_PID)."
    echo "Output logged to /tmp/virtualcam.log"
}

stop() {
    if [ ! -f "$PID_FILE" ]; then
        echo "Virtual camera is not running."
        exit 1
    fi

    echo "Stopping virtual camera..."
    FFMPEG_PID=$(cat "$PID_FILE")
    kill "$FFMPEG_PID"
    rm "$PID_FILE"
    echo "Virtual camera stopped."
}

status() {
    if [ -f "$PID_FILE" ]; then
        FFMPEG_PID=$(cat "$PID_FILE")
        if ps -p "$FFMPEG_PID" > /dev/null; then
            echo "Virtual camera is running (PID: $FFMPEG_PID)."
            if lsmod | grep -q "v4l2loopback"; then
                echo "v4l2loopback module is loaded."
            else
                echo "Warning: v4l2loopback module is NOT loaded, but PID file exists."
            fi
            if [ -e "$TARGET_DEVICE" ]; then
                echo "Virtual device $TARGET_DEVICE exists."
            else
                echo "Warning: Virtual device $TARGET_DEVICE does NOT exist."
            fi
        else
            echo "Virtual camera is not running (stale PID file found)."
            rm "$PID_FILE" # Clean up stale PID file
            if lsmod | grep -q "v4l2loopback"; then
                echo "v4l2loopback module is loaded."
            fi
        fi
    else
        echo "Virtual camera is not running."
        if lsmod | grep -q "v4l2loopback"; then
            echo "v4l2loopback module is loaded (but ffmpeg process not managed by this script)."
        else
            echo "v4l2loopback module is not loaded."
        fi
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
    *)
        echo "Usage: $0 {start|stop|status}"
        exit 1
        ;;
esac

exit 0