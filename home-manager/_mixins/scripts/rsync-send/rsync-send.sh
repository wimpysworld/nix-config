#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'rsync-send: %s\n' "$*" >&2
  exit 1
}

[[ $# == 2 ]] || fail 'Usage: rsync-send DIRECTORY HOSTNAME'
source_arg=$1
host=$2
[[ $host =~ ^([a-zA-Z0-9_][a-zA-Z0-9_.-]*@)?[a-zA-Z0-9_][a-zA-Z0-9_.-]*$ ]] ||
  fail 'Use an SSH alias or hostname, optionally preceded by user@.'
[[ -n $source_arg && -d $source_arg && -r $source_arg && -x $source_arg ]] ||
  fail 'The source must be an existing readable directory.'
[[ ${HOME:-} == /* ]] || fail 'HOME must be an absolute directory.'
IFS= read -r -d '' home_lexical < <(realpath -m -s -z -- "$HOME")
IFS= read -r -d '' home_physical < <(realpath -e -z -- "$HOME")
[[ $home_lexical != / && $home_physical != / ]] || fail 'HOME must not be root.'

case $source_arg in
  /*) source_path=$source_arg ;;
  *) source_path=$PWD/$source_arg ;;
esac
case $source_path in
  "$home_lexical"/*) remainder=${source_path#"$home_lexical"/} ;;
  "$home_physical"/*) remainder=${source_path#"$home_physical"/} ;;
  *) fail 'The source must be strictly below HOME.' ;;
esac

source_path=$home_physical
while [[ -n $remainder ]]; do
  component=${remainder%%/*}
  if [[ $remainder == */* ]]; then remainder=${remainder#*/}; else remainder=; fi
  case $component in
    ''|.) continue ;;
    ..)
      [[ $source_path != "$home_physical" ]] || fail 'The source path escapes HOME.'
      source_path=${source_path%/*}
      ;;
    *)
      source_path+=/$component
      [[ ! -L $source_path ]] || fail 'Source path components must not be symlinks.'
      ;;
  esac
done
[[ $source_path == "$home_physical"/* ]] || fail 'The source must be strictly below HOME.'
IFS= read -r -d '' source_physical < <(realpath -e -z -- "$source_path")
[[ $source_physical == "$source_path" ]] || fail 'The source path resolves through a symlink.'
relative=${source_path#"$home_physical"/}

# Double quotes with these escapes work in both POSIX and fish login shells.
remote_quote() {
  local value=$1
  value=${value//\\/\\\\}
  value=${value//\$/\\$}
  value=${value//\`/\\\`}
  value=${value//\"/\\\"}
  printf '"%s"' "$value"
}

remote_helper=$(cat <<'SH'
set -eu
fail() { printf 'rsync-send: %s\n' "$*" >&2; exit 1; }
relative=$1
shift
case ${HOME:-} in /*) ;; *) fail 'Remote HOME must be absolute.' ;; esac
cd -P "$HOME" || exit 1
home=$PWD
[ "$home" != / ] || fail 'Remote HOME must not be root.'
case $relative in ''|/*|*/|*//* ) fail 'Invalid remote destination.' ;; esac
remaining=$relative
current=$home
while [ -n "$remaining" ]; do
  component=${remaining%%/*}
  case $remaining in */*) remaining=${remaining#*/} ;; *) remaining= ;; esac
  case $component in ''|.|..) fail 'Invalid remote destination component.' ;; esac
  current=$current/$component
  [ ! -L "$current" ] || fail 'Remote destination components must not be symlinks.'
  if [ ! -e "$current" ]; then mkdir "$current" || exit 1; fi
  [ -d "$current" ] && [ ! -L "$current" ] || fail 'Invalid remote directory.'
done
cd -P "$current" || exit 1
[ "$PWD" = "$home/$relative" ] || fail 'Remote destination escapes HOME.'
cd -P "$home" || exit 1
if [ "$#" -gt 0 ]; then exec rsync "$@"; fi
SH
)
remote_command="sh -c $(remote_quote "$remote_helper") sh $(remote_quote "$relative")"
ssh -- "$host" "$remote_command"
exec rsync \
  --archive \
  --block-size=131072 \
  --delete \
  --human-readable \
  --info=progress2 \
  --no-compress \
  --inplace \
  --partial \
  --stats \
  --secluded-args \
  --rsh=ssh \
  --rsync-path="$remote_command" \
  -- "$source_path/" "$host:./$relative/"
