#!/usr/bin/env bash

set +e  # Disable errexit
set +u  # Disable nounset
HOSTNAME=$(hostname -s)
if [ -x "$HOME/.nix-profile/bin/hyprctl" ]; then
    HYPRCTL="$HOME/.nix-profile/bin/hyprctl"
elif [ -x /run/current-system/sw/bin/hyprctl ]; then
    HYPRCTL="/run/current-system/sw/bin/hyprctl"
else
    HYPRCTL="hyprctl"
fi

function app_is_running() {
    local APP=""
    # split the app by space and keep the first part
    if [[ "$1" == *" "* ]]; then
        APP="${1%% *}"
    else
        APP="$1"
    fi
    if pidof -q "$APP" &>/dev/null; then
        return 0
    fi
    return 1
}

function start_app() {
    local APP="$1"
    if ! app_is_running "$APP"; then
        echo " - Starting $APP"
        $HYPRCTL dispatch exec "$APP" &>/dev/null
    else
        echo " - Found: $APP"
    fi
}

function move_app() {
    local WORKSPACE="$1"
    local KEY_TYPE="$2"
    local KEY_VALUE="$3"
    local CLIENT_ADDRESS=""

    echo " - Attempting to move app identified by $KEY_TYPE '$KEY_VALUE' to workspace $WORKSPACE"

    for i in {1..30}; do # Wait up to 15 seconds (30 * 0.5s)
        # Attempt to find the client address using hyprctl and jq
        CLIENT_ADDRESS=$($HYPRCTL clients -j | jq -r --arg kt "$KEY_TYPE" --arg kv "$KEY_VALUE" '.[] | select(.[$kt] != null and .[$kt] == $kv) | .address' | head -n 1)

        if [[ -n "$CLIENT_ADDRESS" ]]; then
            echo " - Found client with $KEY_TYPE '$KEY_VALUE', address: $CLIENT_ADDRESS"
            $HYPRCTL dispatch movetoworkspacesilent "$WORKSPACE,address:$CLIENT_ADDRESS" &>/dev/null
            echo " - Moved client with $KEY_TYPE '$KEY_VALUE' (Address: $CLIENT_ADDRESS) to workspace $WORKSPACE"
            return 0
        else
            echo " - Waiting for client ($KEY_TYPE: $KEY_VALUE): attempt $i/30"
            sleep 0.5
        fi
    done

    echo " - Client with $KEY_TYPE '$KEY_VALUE' not found after 5 seconds. Could not move to workspace $WORKSPACE."
    return 1
}

function activity_work() {
    $HYPRCTL dispatch workspace 1 &>/dev/null

    # Order is import and optimised based on app startup times
    start_app "gitkraken --no-show-splash-screen"
    start_app joplin-desktop
    start_app fractal
    start_app cider
    start_app brave
    start_app wavebox
    start_app slack
    start_app halloy
    start_app telegram-desktop
    start_app code
    start_app heynote
    start_app kitty
    start_app discord

    move_app 5 initialClass GitKraken
    move_app 2 class wavebox
    move_app 3 class org.squidowl.halloy
    move_app 3 class org.gnome.Fractal
    move_app 3 initialTitle Telegram
    # Move slack to workspace 2 here to give wavebox time to settle
    move_app 2 class Slack
    move_app 4 initialClass code
    move_app 6 class Heynote
    move_app 6 class "@joplin/app-desktop"
    move_app 8 class Cider
    move_app 9 initialClass kitty
    # Move discord last because it doesn't honor silent move
    move_app 3 initialClass discord
}

function activity_play() {
    $HYPRCTL dispatch workspace 1 &>/dev/null

    # Order is import and optimised based on app startup times
    start_app "gitkraken --no-show-splash-screen"
    start_app joplin-desktop
    start_app fractal
    start_app cider
    start_app brave
    start_app halloy
    start_app telegram-desktop
    start_app code
    start_app heynote
    start_app kitty
    start_app discord

    # GitKraken takes ages to start, so we move it last
    move_app 5 initialClass GitKraken
    move_app 2 initialTitle Telegram
    move_app 3 class org.gnome.Fractal
    move_app 3 class org.squidowl.halloy
    move_app 4 initialClass code
    move_app 6 class Heynote
    move_app 6 class "@joplin/app-desktop"
    move_app 8 class Cider
    move_app 9 initialClass kitty
    # Move discord last because it doesn't honor silent move
    move_app 2 initialClass discord
}

function activity_podcast() {
    $HYPRCTL dispatch workspace 1 &>/dev/null
    firefox -CreateProfile linuxmatters-stage
    firefox -CreateProfile linuxmatters-studio

    start_app audacity
    start_app telegram-desktop
    start_app "nautilus -w $HOME/Audio"

    disrun firefox \
        -P linuxmatters-stage \
        -no-remote \
        --new-window https://github.com/restfulmedia/linuxmatters_backstage
    disrun firefox \
        -P linuxmatters-studio \
        -no-remote \
        --new-window https://talky.io/linux-matters-studio

    move_app 7 title "Talky — Mozilla Firefox"
    move_app 7 initialTitle Telegram
    move_app 7 title Audio
    move_app 9 class Audacity
    move_app 9 title "restfulmedia/linuxmatters_backstage: Show notes prep, backlog and archive — Mozilla Firefox"
    $HYPRCTL dispatch workspace 7 &>/dev/null
    $HYPRCTL dispatch workspace 9 &>/dev/null
}

function activity_video() {
    $HYPRCTL dispatch workspace 1 &>/dev/null
    start_app "obs --disable-shutdown-check --collection 'Wimpys World' --profile Dev-Local --scene Collage"
    start_app discord

    firefox -CreateProfile wimpysworld-studio
    disrun firefox \
        -P wimpysworld-studio \
        -no-remote \
        --new-window https://dashboard.twitch.tv/u/wimpysworld/stream-manager \
        --new-tab https://wimpysworld.live \
        --new-tab https://streamelements.com \
        --new-tab https://botrix.live

    firefox -CreateProfile wimpysworld-stage
    disrun firefox \
        -P wimpysworld-stage \
        -no-remote \
        --new-window https://wimpysworld.com \
        --new-tab https://github.com/wimpysworld

    start_app chatterino
    start_app rhythmbox

    move_app 7 class com.obsproject.Studio
    move_app 9 title "Twitch — Mozilla Firefox"
    move_app 9 initialClass discord
    case "$HOSTNAME" in
        phasma) move_app 7 class com.chatterino.;;
        vader) move_app 9 class com.chatterino.;;
    esac

    move_app 8 class rhythmbox
    move_app 10 title "Wimpy's World — Mozilla Firefox"

    $HYPRCTL dispatch workspace 7 &>/dev/null
    $HYPRCTL dispatch workspace 9 &>/dev/null
}

function activity_retro() {
    $HYPRCTL dispatch workspace 1 &>/dev/null
    start_app "obs --disable-shutdown-check --collection 8-bit-VS --profile 8-bit-VS-Local --scene Hosts"
    start_app discord
    start_app chatterino
    firefox -CreateProfile 8bitversus-studio
    disrun firefox \
        -P 8bitversus-studio \
        -no-remote \
        --new-window https://dashboard.twitch.tv/u/8bitversus/stream-manager

    move_app 9 initialTitle "Mozilla Firefox"
    move_app 9 initialClass discord

    move_app 7 class com.obsproject.Studio
    move_app 7 class com.chatterino.

    $HYPRCTL dispatch workspace 9 &>/dev/null
    $HYPRCTL dispatch workspace 7 &>/dev/null
}

function activity_clear() {
    $HYPRCTL dispatch workspace 1 &>/dev/null
    # Stop virtual cameras
    if pidof -q obs; then
        obs-cmd virtual-camera stop
    fi
    if [ -e /tmp/virtualcam.pid ]; then
       virtualcam stop
       rm -f /tmp/virtualcam.pid
    fi

    $HYPRCTL clients -j | jq -r ".[].address" | xargs -I {} sh -c 'hyprctl dispatch movetoworkspacesilent 1,"address:{}" &>/dev/null; sleep 0.1'
    $HYPRCTL clients -j | jq -r ".[].address" | xargs -I {} sh -c 'hyprctl dispatch closewindow "address:{}" &>/dev/null; sleep 0.1'
    # Halloy sometimes doesn't close properly, so we force kill it
    if pidof -q halloy; then
        pkill halloy
    fi
}

OPT="help"
if [ -n "$1" ]; then
    OPT="$1"
fi

case "$OPT" in
    retro) activity_retro;;
    clear) activity_clear;;
    podcast) activity_podcast;;
    logout)
        margins=""
        if [ "$(hostname -s)" == "vader" ]; then
            margins="--margin-top 960 --margin-bottom 960"
        elif [ "$(hostname -s)" == "phasma" ]; then
            margins="--margin-left 540 --margin-right 540"
        fi
        sleep 1
        # shellcheck disable=SC2086
        wlogout --buttons-per-row 5 $margins
        ;;
    play) activity_play;;
    work) activity_work;;
    video) activity_video;;
    *)
        echo "Usage: $(basename "$0") {clear|logout|work|play|retro|podcast|video}";
        exit 1;;
esac
