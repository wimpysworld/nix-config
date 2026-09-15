#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'regreet-output-setup: %s\n' "$*" >&2
  exit 1
}

[[ $# -ge 5 ]] || fail 'Expected primary output, width, height, refresh and session command.'
primary=$1
width=$2
height=$3
refresh=$4
shift 4

query_outputs() {
  local outputs
  outputs=$(timeout --kill-after=1s 5s wlr-randr --json) || return 1
  jq -ce '
    if type == "array" and
      all(.[]; (.name | type == "string") and
        (.name | length > 0 and all(explode[]; . > 32)) and
        (.enabled | type == "boolean") and (.modes | type == "array")) and
      ((map(.name) | unique | length) == length)
    then sort_by(.name) else error("Invalid output data") end
  ' <<<"$outputs"
}

outputs=$(query_outputs) || fail 'Could not query outputs.'
[[ $(jq 'length' <<<"$outputs") -gt 0 ]] || fail 'No connected outputs.'
selected=$(jq -r --arg primary "$primary" '
  (map(select(.name == $primary))[0] //
   map(select(.enabled))[0] // .[0]).name
' <<<"$outputs")
if [[ $selected != "$primary" ]]; then
  printf 'regreet-output-setup: Primary %s is absent. Using %s.\n' "$primary" "$selected" >&2
fi

mode=$(jq -er --arg selected "$selected" --arg primary "$primary" \
  --argjson width "$width" --argjson height "$height" --argjson refresh "$refresh" '
  .[] | select(.name == $selected) | .modes |
  map(select((.width | type == "number") and (.height | type == "number") and
    (.refresh | type == "number") and .width > 0 and .height > 0 and .refresh >= 0)) |
  sort_by(.width, .height, .refresh) |
  ((if $selected == $primary then map(select(.width == $width and .height == $height and
      ((.refresh * 1000 | round) == ($refresh * 1000 | round))))[0] else null end) //
    map(select(.current))[0] // map(select(.preferred))[0] // .[0]) |
  if . == null then error("No supported mode") else
    "\(.width)x\(.height)" +
    (if .refresh > 0 then "@\(.refresh * 1000 | round / 1000)Hz" else "" end)
  end
' <<<"$outputs") || fail "No usable mode for $selected."
printf 'regreet-output-setup: Using %s mode %s at 0,0, scale 1.\n' "$selected" "$mode" >&2

args=(--output "$selected" --on --mode "$mode" --pos "0,0" --scale 1)
while IFS= read -r output; do
  [[ $output == "$selected" ]] || args+=(--output "$output" --off)
done < <(jq -r '.[].name' <<<"$outputs")

timeout --kill-after=1s 5s wlr-randr "${args[@]}" || fail 'Could not apply the single-output layout.'
outputs=$(query_outputs) || fail 'Could not verify outputs.'
jq -e --arg selected "$selected" '
  map(select(.enabled)) |
  length == 1 and .[0].name == $selected and
  .[0].position == {x: 0, y: 0} and .[0].scale == 1
' <<<"$outputs" >/dev/null || fail 'The single-output layout was not confirmed.'

exec "$@"
