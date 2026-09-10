#!/usr/bin/env bash

fail() {
  printf 'fuzzel-notes: %s\n' "$1" >&2
  exit 1
}

valid_index() {
  [[ "$1" =~ ^(0|[1-9][0-9]*)$ && ${#1} -le 9 ]] && (( $1 < $2 ))
}

new_note() {
  local directory choice title filename_title result status candidate
  local -a paths=("$notebook") names=('Notes (root)')
  while IFS= read -r -d '' directory; do
    directory=${directory%/}
    [[ -d "$directory" && ! -L "$directory" ]] || continue
    paths+=("$directory")
    names+=("${directory##*/}")
  done < <(printf '%s\0' "$notebook"/*/ | sort -z)
  if ! choice=$(printf '%s\0' "${names[@]}" | jq -Rrs '
    split("\u0000")[:-1][] | gsub("[\u0000-\u001f\u007f-\u009f]"; " ")
  ' | fuzzel --dmenu --index --only-match --no-sort --width=56 --prompt='Folder  '); then
    exit 0
  fi
  valid_index "$choice" "${#paths[@]}" || exit 0
  directory=${paths[choice]}
  cd -- "$directory" || fail 'The selected folder is no longer available.'
  [[ "$(pwd -P)" == "$directory" ]] || fail 'The selected folder changed.'

  rendered=$(mktemp -d)
  trap 'rm -rf -- "$rendered"' EXIT
  while true; do
    if ! title=$(fuzzel --dmenu --width=56 --prompt='Title  ' </dev/null); then
      exit 0
    fi
    [[ "$title" =~ [^[:space:]] ]] || continue
    filename_title=$title
    while [[ "$filename_title" == *.[mM][dD] ]]; do
      filename_title=${filename_title%???}
    done
    # Kong uses backslash escapes for commas in --extra map values.
    filename_title=${filename_title//\\/\\\\}
    filename_title=${filename_title//,/\\,}
    status=0
    zk --notebook-dir "$notebook" -W "$directory" --no-input new \
      --dry-run --group fuzzel --title "$title" \
      --extra "filename-title=$filename_title" \
      > "$rendered/body" 2> "$rendered/path" || status=$?
    IFS= read -r -d '' result < <(cat "$rendered/path"; printf '\0')
    result=${result%$'\n'}
    if (( status != 0 )); then
      [[ "$result" == 'zk: error: new note: '*': note already exists' ]] || fail 'Could not render the new note.'
      result=${result#'zk: error: new note: '}
      result=${result%': note already exists'}
    fi
    [[ "$result" == "$directory/"* ]] || fail 'The new note is outside the selected folder.'
    candidate=${result#"$directory/"}
    [[ -n "$candidate" && "$candidate" != */* && "$candidate" == *.md ]] || fail 'The new note has an invalid filename.'
    if [[ -e "$candidate" || -L "$candidate" ]]; then
      if ! choice=$(printf '%s\n' 'Open existing' 'Choose another title' |
        fuzzel --dmenu --index --only-match --no-sort --width=56 --prompt='Note exists  '); then
        exit 0
      fi
      valid_index "$choice" 2 || exit 0
      (( choice == 1 )) && continue
      path=$(realpath -e -- "$candidate") || fail 'The existing note is not available.'
      [[ "$path" == "$notebook/"* && -f "$path" ]] || fail 'The existing note is outside the notebook or is not a regular file.'
      return
    fi
    (( status == 0 )) || fail 'The existing note changed. Select New again.'
    (set -o noclobber; cat "$rendered/body" > "$candidate") || fail 'Could not create the note without overwriting a file.'
    path="$directory/$candidate"
    return
  done
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
      {action: "open", path, title: ((.title // .path) | clean),
       tags: ((.tags // []) | map(clean) | join(" "))}
    end)
  | group_by(.title)
  | map(if length > 1 then map(. + {label: (.title + " [" + (.path | split("/") | last | rtrimstr(".md") | clean) + "]")})
        else map(. + {label: .title}) end)
  | add // []
  | sort_by([(.title | ascii_downcase), .path])
  | [{action: "fixed", path: "scratch.md", label: "󰂺 Scratch", title: "Scratch", tags: ""},
     {action: "fixed", path: "todo.md", label: " ToDo", title: "ToDo", tags: ""},
     {action: "new", label: " New", title: "New", tags: ""}]
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
action=$(jq -r --argjson i "$selected" '.[$i].action' <<< "$entries")
if [[ "$action" == new ]]; then
  new_note
  rm -rf -- "$rendered"
  trap - EXIT
  exec setsid --fork "$MANUSCRIPT" -- "$path" </dev/null >/dev/null 2>&1
fi
IFS= read -r -d '' relative < <(jq -j --argjson i "$selected" '.[$i].path, "\u0000"' <<< "$entries")
[[ "$relative" != /* ]] || fail 'The selected note is outside the notebook.'
path=$(realpath -m -- "$notebook/$relative")
[[ "$path" == "$notebook/"* ]] || fail 'The selected note is outside the notebook.'

if [[ "$action" == fixed && ! -e "$path" ]]; then
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
exec setsid --fork "$MANUSCRIPT" -- "$path" </dev/null >/dev/null 2>&1
