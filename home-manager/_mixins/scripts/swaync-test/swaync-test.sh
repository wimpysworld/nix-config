#!/usr/bin/env bash

usage() {
  printf '%s\n' \
    'Usage: swaync-test TEST [IMAGE]' \
    '' \
    'Tests:' \
    '  text       Markup, wrapping and line spacing' \
    '  actions    Open, Mark read, Archive and Undo actions' \
    '  media      Previous, Pause and Next symbols' \
    '  progress   Update one notification from 0% to 100%' \
    '  reply      Inline reply entry and send button' \
    '  critical   Critical styling (dismiss manually)' \
    '  image PATH Image proportions and spacing (PNG or JPEG)' \
    '  keyboard   Action notification with keyboard instructions' \
    '' \
    'Use --help or --list to show this list without sending notifications.' \
    'Actions print identifiers only. They do not control applications.' \
    'Action tests wait until you select an action or close the notification.' \
    'Hover over a notification to keep it visible, or open the SwayNC panel.' \
    'fyi cannot report reply text. The reply test checks appearance and interaction only.'
}

test_name=${1:---help}
case "$test_name" in
  --help|-h|--list|text|actions|media|progress|reply|critical|keyboard)
    if (( $# > 1 )); then
      printf 'Unexpected argument: %s\n' "$2" >&2
      exit 2
    fi
    ;;
  image)
    if (( $# != 2 )) || [[ ! -f "$2" || ! -r "$2" ]]; then
      printf '%s\n' 'Usage: swaync-test image PATH (a readable PNG or JPEG file)' >&2
      exit 2
    fi
    ;;
  *)
    printf 'Unknown test: %s. Use swaync-test --help.\n' "$test_name" >&2
    exit 2
    ;;
esac

notify() {
  fyi --app-name='SwayNC test' --urgency=normal --expire-time=15000 "$@"
}

case "$test_name" in
  --help|-h|--list)
    usage
    ;;
  text)
    notify 'Text and wrapping' \
      $'<b>Bold text</b>, <i>italic text</i> and <u>underlined text</u>.\nThis longer paragraph tests wrapping, line spacing and readability against the notification background. Expand the notification if the body is truncated.'
    ;;
  actions|keyboard)
    if [[ "$test_name" == keyboard ]]; then
      printf '%s\n' \
        'Open the SwayNC panel with your normal shortcut, or run this in another terminal:' \
        '  swaync-client --open-panel' \
        'Use Up/Down to select this notification, 1 to 3 for its actions, and Enter for Open.'
    fi
    notify --expire-time=0 \
      --action='default:Open' --action='read:Mark read' \
      --action='archive:Archive' --action='undo:Undo' \
      'Action buttons' 'Check button spacing, hover states and text alignment.'
    ;;
  media)
    notify --expire-time=0 \
      --action='previous:⏮︎' --action='pause:⏸︎' --action='next:⏭︎' \
      'Media symbols' 'Check that all three symbols are centred and readable.'
    ;;
  progress)
    result=$(notify --print-id --expire-time=0 --hint=int:value:0 'Progress test' '0% complete')
    if [[ ! "$result" =~ ^id=([1-9][0-9]*)$ ]]; then
      printf 'Unexpected notification ID: %s\n' "$result" >&2
      exit 1
    fi
    notification_id=${BASH_REMATCH[1]}
    for percent in 20 40 60 80 100; do
      sleep 1
      notify --replaces="$notification_id" --expire-time=0 --hint="int:value:$percent" \
        'Progress test' "$percent% complete"
    done
    notify --replaces="$notification_id" --expire-time=5000 --hint=int:value:100 \
      'Progress test' 'Complete'
    ;;
  reply)
    printf '%s\n' 'fyi cannot report reply text. This test checks appearance and interaction only.'
    notify --expire-time=0 --action='inline-reply:Send' \
      --hint='string:x-kde-reply-placeholder-text:Type a test reply…' \
      'Inline reply test' 'Enter some text, then select Send.'
    ;;
  critical)
    printf '%s\n' 'Dismiss the critical notification manually.'
    notify --urgency=critical --expire-time=0 'Critical notification test' \
      'Check the critical border, text contrast and close-button spacing.'
    ;;
  image)
    image_path=$(realpath -- "$2")
    notify --icon="$image_path" 'Image test' 'Check image proportions and spacing around the text.'
    ;;
esac
