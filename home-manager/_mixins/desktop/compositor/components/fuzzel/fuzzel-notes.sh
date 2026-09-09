#!/usr/bin/env bash

fail() {
  printf 'fuzzel-notes: %s\n' "$1" >&2
  exit 1
}

notebook="$HOME/Notes"
[[ -d "$notebook/.zk" ]] || fail 'The notebook at ~/Notes is not set up.'
notebook=$(realpath -e -- "$notebook")

if ! notes=$(zk --notebook-dir "$notebook" -W "$notebook" --no-input \
  list --quiet --no-pager --format jsonl 2>/dev/null); then
  fail 'Could not read the notebook index.'
fi

if ! entries=$(jq -sc '
  def clean: gsub("[\u0000-\u001f\u007f-\u009f]"; " ");
  map(select(.path != "scratch.md" and .path != "todo.md") |
    if (.path | type) != "string" or (.path | contains("\u0000")) then
      error("Invalid note path")
    else
      {path, title: ((.title // .path) | clean),
       tags: ((.tags // []) | map(clean) | join(" "))}
    end)
  | group_by(.title)
  | map(if length > 1 then map(. + {label: (.title + " [" + (.path | split("/") | last | rtrimstr(".md") | clean) + "]")})
        else map(. + {label: .title}) end)
  | add // []
  | sort_by([(.title | ascii_downcase), .path])
  | [{path: "scratch.md", label: "󰂺 Scratch", title: "Scratch", tags: ""},
     {path: "todo.md", label: " ToDo", title: "ToDo", tags: ""}]
    + map(.label = ("󰈙 " + .label))
' <<< "$notes" 2>/dev/null); then
  fail 'Could not parse the notebook index.'
fi

menu=$(jq -r '.[] | [.label, (.title + " " + .tags)] | join("\t")' <<< "$entries")
if ! selected=$(printf '%s\n' "$menu" | fuzzel --dmenu --index --only-match \
  --no-sort --match-mode=fzf --with-nth=1 --match-nth=2 --width=56 --prompt='󰈞 '); then
  exit 0
fi

# The execute-input binding can bypass --only-match and return a non-index.
[[ "$selected" =~ ^(0|[1-9][0-9]*)$ && ${#selected} -le 9 ]] || exit 0
count=$(jq 'length' <<< "$entries")
(( selected < count )) || exit 0
IFS= read -r -d '' relative < <(jq -j --argjson i "$selected" '.[$i].path, "\u0000"' <<< "$entries")
[[ "$relative" != /* ]] || fail 'The selected note is outside the notebook.'
path=$(realpath -m -- "$notebook/$relative")
[[ "$path" == "$notebook/"* ]] || fail 'The selected note is outside the notebook.'

if [[ "$selected" -le 1 && ! -e "$path" ]]; then
  title=$(jq -r --argjson i "$selected" '.[$i].title' <<< "$entries")
  [[ ! -L "$notebook/$relative" ]] || fail "$title is a broken symbolic link."
  (
    set -o noclobber
    printf '%s\n' '---' "title: \"$title\"" \
      "date: $(TZ=Europe/London date '+%Y-%m-%dT%H:%M:%S%:z')" \
      'tags: []' '---' '' "# $title" '' > "$path"
  ) || fail "Could not create $title without overwriting a file."
fi
[[ -f "$path" ]] || fail 'The selected note is not a regular file.'
exec setsid --fork "$ZED" -- "$path" </dev/null >/dev/null 2>&1
