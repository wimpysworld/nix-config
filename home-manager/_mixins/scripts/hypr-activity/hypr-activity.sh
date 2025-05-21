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
    local CLASS="$1"
    if $HYPRCTL clients | grep "$CLASS" &>/dev/null; then
        return 0
    fi
    return 1
}

function wait_for_app() {
    local COUNT=0
    local SLEEP=1
    local LIMIT=5
    local CLASS="$1"
    echo " - Waiting for $CLASS..."
    while ! app_is_running "$CLASS"; do
        sleep "$SLEEP"
        ((COUNT++))
        if [ "$COUNT" -ge "$LIMIT" ]; then
            echo " - Failed to find $CLASS"
            break
        fi
    done
}

function start_app() {
    local APP="$1"
    local WORKSPACE="$2"
    local CLASS="$3"
    if ! app_is_running "$CLASS"; then
        echo -n " - Starting $APP on workspace $WORKSPACE: "
        if [ "$WORKSPACE" == "10" ]; then
            $HYPRCTL dispatch exec "[workspace $WORKSPACE silent; float; size 1596 1076]" "$APP"
        else
            $HYPRCTL dispatch exec "[workspace $WORKSPACE silent]" "$APP"
        fi
        if [ "$APP" == "audacity" ]; then
            sleep 5
        fi
        wait_for_app "$CLASS"
    else
        echo " - $APP is already running"
    fi
    echo -n " - Moving $CLASS to $WORKSPACE: "
    $HYPRCTL dispatch movetoworkspacesilent "$WORKSPACE,$CLASS"
    $HYPRCTL dispatch movetoworkspacesilent "$WORKSPACE,$APP" &>/dev/null
    if [ "$APP" == "gitkraken" ]; then
        $HYPRCTL dispatch movetoworkspacesilent "$WORKSPACE,GitKraken" &>/dev/null
    fi
}

function activity_gsd() {
    start_app brave 1 "class: brave-browser"
    start_app wavebox 2 "class: wavebox"
    start_app discord 2 " - Discord"
    start_app telegram-desktop 3 "initialTitle: Telegram"
    start_app fractal 3 "class: org.gnome.Fractal"
    start_app halloy 3 "class: org.squidowl.halloy"
    start_app code 4 "initialTitle: Visual Studio Code"
    start_app "gitkraken --no-show-splash-screen" 5 "title: GitKraken Desktop"
    start_app joplin-desktop 6 "class: @joplin/app-desktop"
    start_app heynote 6 "class: Heynote"
    if [ "$HOSTNAME" == "phasma" ] || [ "$HOSTNAME" == "vader" ]; then
        start_app "obs --disable-shutdown-check --collection VirtualCam --profile VirtualCam --scene Work-VirtualCam --startvirtualcam" 7 "class: com.obsproject.Studio"
    fi
    start_app Cider 8 "class: Cider"
}

function activity_linuxmatters() {
    start_app audacity 9 "class: audacity"
    firefox -CreateProfile linuxmatters-stage
    start_app "firefox \
        -P linuxmatters-stage \
        -no-remote \
        --new-window https://github.com/restfulmedia/linuxmatters_backstage" 9 "title: restfulmedia/linuxmatters_backstage"
    if [ "$HOSTNAME" == "phasma" ] || [ "$HOSTNAME" == "vader" ]; then
        start_app "obs --disable-shutdown-check --collection VirtualCam --profile VirtualCam --scene Podcast-VirtualCam --startvirtualcam" 9 "class: com.obsproject.Studio"
    fi
    $HYPRCTL dispatch workspace 9 &>/dev/null
    firefox -CreateProfile linuxmatters-studio
    start_app "firefox \
        -P linuxmatters-studio \
        -no-remote \
        --new-window https://talky.io/linux-matters-studio" 7 "title: Talky — Mozilla Firefox"
    start_app telegram-desktop 7 "initialTitle: Telegram"
    start_app "nautilus -w $HOME/Audio" 7 "title: Audio"
    $HYPRCTL dispatch workspace 7 &>/dev/null
}

function activity_wimpysworld() {
    # Workspace 7
    $HYPRCTL dispatch workspace 7 &>/dev/null
    start_app "obs --disable-shutdown-check --collection 'Wimpys World' --profile Dev-Local --scene Collage" 7 "class: com.obsproject.Studio"
    # Workspace 8
    start_app rhythmbox 8 "class: rhythmbox"
    # Workspace 9
    $HYPRCTL dispatch workspace 9 &>/dev/null
    firefox -CreateProfile wimpysworld-studio
    start_app "firefox \
        -P wimpysworld-studio \
        -no-remote \
        --new-window https://dashboard.twitch.tv/u/wimpysworld/stream-manager \
        --new-tab https://wimpysworld.live \
        --new-tab https://streamelements.com \
        --new-tab https://botrix.live" 9 "title: Twitch — Mozilla Firefox"
    case "$HOSTNAME" in
        phasma)
            start_app discord 9 " - Discord"
            start_app chatterino 7 "chatterino"
            ;;
        vader)
            start_app discord 9 " - Discord"
            start_app chatterino 9 "chatterino"
            ;;
    esac
    # Workspace 10
    firefox -CreateProfile wimpysworld-stage
    start_app "firefox \
        -P wimpysworld-stage \
        -no-remote \
        --new-window https://wimpysworld.com \
        --new-tab https://github.com/wimpysworld" 10 "title: Wimpy's World — Mozilla Firefox"
}

function activity_8bitversus() {
    firefox -CreateProfile 8bitversus-studio
    start_app "firefox \
        -P 8bitversus-studio \
        -no-remote \
        --new-window https://dashboard.twitch.tv/u/8bitversus/stream-manager" 9 "title: Twitch — Mozilla Firefox"
    start_app discord 9 " - Discord"
    $HYPRCTL dispatch workspace 9 &>/dev/null
    start_app "obs --disable-shutdown-check --collection 8-bit-VS --profile 8-bit-VS-Local --scene Hosts" 7 "class: com.obsproject.Studio"
    start_app chatterino 7 "chatterino"
    $HYPRCTL dispatch workspace 7 &>/dev/null
}

function activity_clear() {
    if pidof -q obs; then
        obs-cmd virtual-camera stop
    fi
    sleep 0.25
    $HYPRCTL clients -j | jq -r ".[].address" | xargs -I {} sh -c 'hyprctl dispatch closewindow "address:{}"; sleep 0.1'
    sleep 0.25
    $HYPRCTL dispatch workspace 1 &>/dev/null
}

OPT="help"
if [ -n "$1" ]; then
    OPT="$1"
fi

case "$OPT" in
    8bitversus) activity_8bitversus;;
    clear) activity_clear;;
    gsd) activity_gsd;;
    linuxmatters) activity_linuxmatters;;
    wimpysworld) activity_wimpysworld;;
    *) echo "Usage: $(basename "$0") {clear|gsd|8bitversus|linuxmatters|wimpysworld}";
      exit 1;;
esac
