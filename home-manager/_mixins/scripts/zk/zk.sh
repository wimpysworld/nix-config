#!/usr/bin/env bash

# Only bare creation commands use the terminal flow. Native options pass through.
if [[ $# != 1 ]]; then
  exec "$ZK_NATIVE" "$@"
fi
case "$1" in
  new|scratch|todo) ;;
  *) exec "$ZK_NATIVE" "$@" ;;
esac

fail() {
  printf 'zk: %s\n' "$1" >&2
  exit 1
}

pick() {
  fzf --read0 --print0 --no-multi --no-expect --no-print-query \
    --layout=reverse --prompt="$1" --delimiter=$'\t' --with-nth=2..
}

render_note() {
  local title=$1 filename_title=$2 result status=0
  while [[ "$filename_title" == *.[mM][dD] ]]; do
    filename_title=${filename_title%???}
  done
  # Kong uses backslash escapes for commas in --extra map values.
  filename_title=${filename_title//\\/\\\\}
  filename_title=${filename_title//,/\\,}
  "$ZK_NATIVE" --notebook-dir "$notebook" -W "$directory" --no-input new \
    --dry-run --group terminal --title "$title" \
    --extra "filename-title=$filename_title" \
    > "$rendered/body" 2> "$rendered/path" || status=$?
  IFS= read -r -d '' result < <(cat "$rendered/path"; printf '\0')
  result=${result%$'\n'}
  if (( status != 0 )); then
    if [[ "$result" != 'zk: error: new note: '*': note already exists' ]]; then
      cat "$rendered/path" >&2
      fail 'Could not render the new note.'
    fi
    result=${result#'zk: error: new note: '}
    result=${result%': note already exists'}
  fi
  [[ "$result" == "$directory/"* ]] || fail 'The new note is outside the selected folder.'
  candidate=${result#"$directory/"}
  [[ -n "$candidate" && "$candidate" != */* && "$candidate" == *.md ]] || fail 'The new note has an invalid filename.'
  if [[ ! -e "$candidate" && ! -L "$candidate" ]]; then
    (( status == 0 )) || fail 'The existing note changed. Try again.'
  fi
}

create_note() {
  (set -o noclobber; cat "$rendered/body" > "$candidate") || fail 'Could not create the note without overwriting a file.'
}

open_note() {
  local path
  path=$(realpath -e -- "$directory/$candidate") || fail 'The note is not available.'
  [[ "$path" == "$notebook/"* && -f "$path" ]] || fail 'The note is outside the notebook or is not a regular file.'
  rm -rf -- "$rendered"
  trap - EXIT
  exec "$FRESH" -- "$path"
}

notebook="$HOME/Notes"
[[ -d "$notebook/.zk" ]] || fail 'The notebook at ~/Notes is not set up.'
notebook=$(realpath -e -- "$notebook")
directory=$notebook
rendered=$(mktemp -d)
trap 'rm -rf -- "$rendered"' EXIT

if [[ "$1" != new ]]; then
  cd -- "$directory" || fail 'The notebook is no longer available.'
  candidate="$1.md"
  if [[ ! -e "$candidate" && ! -L "$candidate" ]]; then
    title=Scratch
    [[ "$1" != todo ]] || title=ToDo
    render_note "$title" "$1"
    [[ "$candidate" == "$1.md" ]] || fail 'The fixed note has an unexpected filename.'
    [[ -e "$candidate" || -L "$candidate" ]] || create_note
  fi
  open_note
fi

paths=("$notebook")
printf '0\tNotes (root)\0' > "$rendered/folders"
while IFS= read -r -d '' folder; do
  folder=${folder%/}
  [[ -d "$folder" && ! -L "$folder" ]] || continue
  printf '%s\t%s\0' "${#paths[@]}" "${folder##*/}" >> "$rendered/folders"
  paths+=("$folder")
done < <(printf '%s\0' "$notebook"/*/ | sort -z)
if ! pick 'Folder > ' < "$rendered/folders" > "$rendered/choice"; then
  exit 0
fi
IFS= read -r -d '' choice < "$rendered/choice" || exit 0
choice=${choice%%$'\t'*}
[[ "$choice" =~ ^(0|[1-9][0-9]*)$ && ${#choice} -le 9 ]] || exit 0
(( choice < ${#paths[@]} )) || exit 0
directory=${paths[choice]}
cd -- "$directory" || fail 'The selected folder is no longer available.'
[[ "$(pwd -P)" == "$directory" ]] || fail 'The selected folder changed.'

while true; do
  printf 'Title: ' >&2
  IFS= read -r title || exit 0
  [[ "$title" =~ [^[:space:]] ]] || continue
  render_note "$title" "$title"
  if [[ -e "$candidate" || -L "$candidate" ]]; then
    if ! printf '0\tOpen existing\0001\tChoose another title\0' |
      pick 'Note exists > ' > "$rendered/choice"; then
      exit 0
    fi
    IFS= read -r -d '' choice < "$rendered/choice" || exit 0
    case "$choice" in
      0$'\t'*) ;;
      1$'\t'*) continue ;;
      *) exit 0 ;;
    esac
  else
    create_note
  fi
  open_note
done
