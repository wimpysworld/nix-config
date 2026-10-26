#!/usr/bin/env bash

fail() {
  printf 'fuzzel-connections: %s\n' "$1" >&2
  exit 1
}

if ! menu=$(jq -r '.[] | [.label, .keywords] | join("\t")' "$FUZZEL_CONNECTIONS"); then
  fail 'Could not read the connections list.'
fi
if ! selected=$(printf '%s\n' "$menu" | fuzzel --config="$FUZZEL_CONNECTIONS_CONFIG" \
  --dmenu --index --only-match --no-sort --with-nth=1 --match-nth=2 --width=56 \
  --prompt='󰖟 '); then
  exit 0
fi

# Arbitrary input must never become a URL, so accept only a listed index.
[[ "$selected" =~ ^(0|[1-9][0-9]*)$ && ${#selected} -le 9 ]] || exit 0
count=$(jq 'length' "$FUZZEL_CONNECTIONS")
(( selected < count )) || exit 0
url=$(jq -r --argjson i "$selected" '.[$i].url' "$FUZZEL_CONNECTIONS")
exec setsid --fork xdg-open "$url"
