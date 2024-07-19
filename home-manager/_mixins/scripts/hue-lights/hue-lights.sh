#!/usr/bin/env bash

set +e  # Disable errexit
set +u  # Disable nounset
set +o pipefail  # Disable pipefail

#ID  NAME        STATUS  BRIGHTNESS  REACHABLE
#1   Office 4    on      254         true
#2   Office 3    on      254         true
#3   Office 2    on      254         true
#4   Office 1    on      254         true
#5   Small Lamp  on      -           true
#6   Big Lamp    on      -           true

LIGHTS="${1}"
HOST="$(hostnamectl hostname)"

if [[ "${HOST}" != *"vader"* ]]; then
  exit
fi

if pidof obs; then
    RESOLUTION=$(obs-cli profile get | cut -d' ' -f2)
    case ${RESOLUTION} in
        864p60|936p60|Gaming)
            if [ "${LIGHTS}" == "default" ]; then
                LIGHTS="gaming"
            fi
            ;;
    esac
fi

case ${LIGHTS} in
    off|on)
        hueadm light 1 "${LIGHTS}"
        hueadm light 2 "${LIGHTS}"
        hueadm light 3 "${LIGHTS}"
        hueadm light 4 "${LIGHTS}"
        hueadm light 5 "${LIGHTS}"
        hueadm light 6 "${LIGHTS}"
        ;;
    coding|default)
        hueadm light 1 clear
        hueadm light 2 clear
        hueadm light 3 clear
        hueadm light 4 clear
        hueadm light 6 on
        hueadm light 5 on
        hueadm light 4 clear
        hueadm light 4 '#ffffff' bri=254
        hueadm light 3 clear
        hueadm light 3 '#ffffff' bri=254
        hueadm light 2 clear
        hueadm light 2 '#0000ff' bri=254
        hueadm light 1 clear
        hueadm light 1 '#0000ff' bri=254
        ;;
    focus|white)
        hueadm light 1 clear
        hueadm light 2 clear
        hueadm light 3 clear
        hueadm light 4 clear
        hueadm light 6 on
        hueadm light 5 on
        hueadm light 4 clear
        hueadm light 4 '#ffffff' bri=254
        hueadm light 3 clear
        hueadm light 3 '#ffffff' bri=254
        hueadm light 2 clear
        hueadm light 2 '#ffffff' bri=254
        hueadm light 1 clear
        hueadm light 1 '#ffffff' bri=254
        ;;
    detsys)
        hueadm light 1 clear
        hueadm light 2 clear
        hueadm light 3 clear
        hueadm light 4 clear
        hueadm light 6 on
        hueadm light 5 on
        hueadm light 4 clear
        hueadm light 1 '#CD1E8B' bri=254
        hueadm light 1 clear
        hueadm light 2 '#EA741F' bri=254
        hueadm light 3 clear
        hueadm light 3 '#1E9FD9' bri=254
        hueadm light 4 clear
        hueadm light 4 '#EDEDEF' bri=254
        ;;
    gaming)
        hueadm light 1 clear
        hueadm light 2 clear
        hueadm light 3 clear
        hueadm light 4 clear
        hueadm light 6 on
        hueadm light 5 on
        hueadm light 4 clear
        hueadm light 4 '#ffffff' bri=254
        hueadm light 3 clear
        hueadm light 3 '#ffffff' bri=254
        hueadm light 2 clear
        hueadm light 2 '#D22260' bri=254
        hueadm light 1 clear
        hueadm light 1 '#D22260' bri=254
        ;;
    Chelsea-Cucumber)
        key-lights off &
        hueadm light 6 off
        hueadm light 5 on
        hueadm light 4 '#00ff00' bri=254 transitiontime=2
        hueadm light 3 '#00ff00' bri=254 transitiontime=8
        hueadm light 2 '#00ff00' bri=254 transitiontime=4
        hueadm light 1 '#00ff00' bri=254 transitiontime=6
        hueadm light 1 lselect
        sleep 0.1
        hueadm light 3 lselect
        sleep 0.1
        hueadm light 2 lselect
        sleep 0.1
        hueadm light 4 lselect
        sleep 11
        hue-lights default &
        key-lights default &
        ;;
    Christmas-Tree)
        key-lights on 1 1 &
        hueadm light 6 off
        hueadm light 5 off
        hueadm light 4 white bri=254
        hueadm light 3 green bri=192 transitiontime=2
        hueadm light 2 red bri=192 transitiontime=2
        hueadm light 1 blue bri=192 transitiontime=2
        hueadm light 1 colorloop
        sleep 0.1
        hueadm light 3 colorloop
        sleep 0.1
        hueadm light 2 colorloop
        sleep 0.1
        hueadm light 4 colorloop
        sleep 28
        hue-lights default &
        key-lights default &
        ;;
    Deep-Thought)
        key-lights on 10 200 &
        hueadm light 6 off
        hueadm light 5 on
        hueadm light 4 '#ffffff' bri=200
        hueadm light 3 '#ffffff' bri=200
        hueadm light 2 '#ffffff' bri=64
        hueadm light 1 '#ffffff' bri=64
        sleep 19
        hue-lights default &
        key-lights default &
        ;;
    Fireball)
        key-lights on 25 200 &
        hueadm light 6 off
        hueadm light 5 on
        hueadm light 4 '#CE5C00' bri=254 transitiontime=2
        hueadm light 3 '#CC0000' bri=254 transitiontime=4
        hueadm light 2 '#F57900' bri=254 transitiontime=6
        hueadm light 1 '#CC0000' bri=254 transitiontime=8
        hueadm light 1 lselect
        sleep 0.1
        hueadm light 3 lselect
        sleep 0.1
        hueadm light 2 lselect
        sleep 0.1
        hueadm light 4 lselect
        sleep 5
        hue-lights default &
        key-lights default &
        ;;
    Interference)
        key-lights off &
        hueadm light 6 off
        hueadm light 5 off
        hueadm light 4 '#002150' bri=128
        hueadm light 3 '#002150' bri=128
        hueadm light 2 '#002150' bri=128
        hueadm light 1 '#002150' bri=128
        hueadm light 1 lselect
        sleep 0.1
        hueadm light 3 lselect
        sleep 0.1
        hueadm light 2 lselect
        sleep 0.1
        hueadm light 4 lselect
        sleep 8.5
        hue-lights default &
        key-lights default &
        ;;
    Kraken)
        key-lights off &
        hueadm light 6 on
        hueadm light 5 on
        hueadm light 4 '#179287' bri=128
        hueadm light 3 '#179287' bri=128
        hueadm light 2 '#179287' bri=128
        hueadm light 1 '#179287' bri=128
        sleep 19
        hue-lights default &
        key-lights default &
        ;;
    Love-It)
        key-lights off &
        hueadm light 6 off
        hueadm light 5 on
        hueadm light 4 '#F500ED' bri=254
        hueadm light 3 '#F500ED' bri=254
        hueadm light 2 '#F500ED' bri=254
        hueadm light 1 '#F500ED' bri=254
        sleep 13
        hue-lights default &
        key-lights default &
        ;;
    Oh-Balls)
        key-lights off &
        hueadm light 6 off
        hueadm light 5 on
        hueadm light 4 '#FC4FEC' bri=254
        hueadm light 3 '#EDD400' bri=254
        hueadm light 2 '#EF2929' bri=254
        hueadm light 1 '#0000ff' bri=254
        hueadm light 1 lselect
        sleep 0.1
        hueadm light 3 lselect
        sleep 0.1
        hueadm light 2 lselect
        sleep 0.1
        hueadm light 4 lselect
        sleep 6
        hue-lights default &
        key-lights default &
        ;;
    Twitch-Bits|Twitch-Donation|Twitch-Follow)
        key-lights on 10 200 &
        hueadm light 6 off
        hueadm light 5 on
        hueadm light 4 '#FCE94F' bri=254
        hueadm light 3 '#ffffff' bri=192
        hueadm light 2 '#FCE94F' bri=254
        hueadm light 1 '#ffffff' bri=192
        hueadm light 1 lselect
        sleep 0.1
        hueadm light 3 lselect
        sleep 0.1
        hueadm light 2 lselect
        sleep 0.1
        hueadm light 4 lselect
        sleep 5
        hue-lights default &
        key-lights default &
        ;;
    Twitch-Sub)
        key-lights on 10 200 &
        hueadm light 6 off
        hueadm light 5 on
        hueadm light 4 '#ffffff' bri=254 transitiontime=1
        hueadm light 3 '#ffffff' bri=254 transitiontime=1
        hueadm light 2 '#ffffff' bri=254 transitiontime=1
        hueadm light 1 '#ffffff' bri=254 transitiontime=1
        sleep 0.5
        hueadm light 4 '#FCE94F' bri=254
        hueadm light 3 '#ffffff' bri=192
        hueadm light 2 '#FCE94F' bri=254
        hueadm light 1 '#ffffff' bri=192
        hueadm light 1 lselect
        sleep 0.1
        hueadm light 3 lselect
        sleep 0.1
        hueadm light 2 lselect
        sleep 0.1
        hueadm light 4 lselect
        sleep 6.5
        hue-lights default &
        key-lights default &
        ;;
    Twitch-Host|Twitch-Raid)
        key-lights on 5 150 &
        hueadm light 6 off
        hueadm light 5 on
        LOOP=0
        while [ ${LOOP} -le 4 ]; do
            hueadm light 4 '#0000ff' bri=254
            hueadm light 3 '#0000ff' bri=254
            hueadm light 2 '#ff0000' bri=254
            hueadm light 1 '#ff0000' bri=254
            sleep 0.4
            hueadm light 4 '#ff0000' bri=254
            hueadm light 3 '#ff0000' bri=254
            hueadm light 2 '#0000ff' bri=254
            hueadm light 1 '#0000ff' bri=254
            sleep 0.4
            LOOP=$(( LOOP + 1 ))
        done
        hue-lights default &
        key-lights default &
        ;;
    Words)
        key-lights on 5 200 &
        hueadm light 6 off
        hueadm light 5 on
        hueadm light 4 '#ff0000' bri=254
        hueadm light 3 '#ff0000' bri=192
        hueadm light 2 '#ff0000' bri=128
        hueadm light 1 '#ff0000' bri=64
        hueadm light 1 lselect
        sleep 0.1
        hueadm light 3 lselect
        sleep 0.1
        hueadm light 2 lselect
        sleep 0.1
        hueadm light 4 lselect
        sleep 1.5
        hue-lights default &
        key-lights default &
        ;;
esac
