#!/usr/bin/env bash
# Gate: the rsync-send package postCheck runs these isolated behavioural tests.
set -euo pipefail
script=$(realpath -- "${1:?Pass the rsync-send source script.}")
fixture=$(mktemp -d)
export HOME=$fixture/local REMOTE_HOME=$fixture/remote
export LOG=$fixture/log LOGIN_SHELL=sh
export XDG_CONFIG_HOME=$fixture/config
unset BASH_ENV ENV
mkdir -p "$HOME" "$REMOTE_HOME" "$fixture/bin" "$LOG"
export REAL_MKDIR
REAL_MKDIR=$(command -v mkdir)
for tool in bash sh cat realpath ln chmod; do
  ln -s "$(command -v "$tool")" "$fixture/bin/$tool"
done
export PATH=$fixture/bin

printf '#!%s\n' "$BASH" > "$fixture/bin/ssh"
cat >> "$fixture/bin/ssh" <<'SH'
set -euo pipefail
printf '%s\0' "$@" > "$LOG/ssh"
[[ ${SSH_FAIL:-0} == 0 ]] || exit 21
[[ $# == 3 && $1 == -- ]] || exit 22
HOME=$REMOTE_HOME "$LOGIN_SHELL" -c "$3"
SH
printf '#!%s\n' "$BASH" > "$fixture/bin/rsync"
cat >> "$fixture/bin/rsync" <<'SH'
set -euo pipefail
if [[ ${1:-} == --server ]]; then
  printf '%s' "$PWD" > "$LOG/remote-cwd"
  exit 0
fi
printf '%s\0' "$@" > "$LOG/rsync"
for arg; do
  case $arg in --rsync-path=*) command=${arg#*=} ;; esac
done
[[ -n ${command:-} ]] || exit 23
HOME=$REMOTE_HOME "$LOGIN_SHELL" -c "$command --server mock"
SH
printf '#!%s\n' "$BASH" > "$fixture/bin/mkdir"
cat >> "$fixture/bin/mkdir" <<'SH'
set -euo pipefail
[[ ${MKDIR_FAIL:-0} == 0 ]] || exit 24
exec "$REAL_MKDIR" "$@"
SH
chmod +x "$fixture/bin/ssh" "$fixture/bin/rsync" "$fixture/bin/mkdir"

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
run() { bash "$script" "$@"; }
reject() {
  : > "$LOG/ssh"
  : > "$LOG/rsync"
  if run "$@" > "$LOG/output" 2>&1; then fail "Accepted invalid input: $*"; fi
  [[ ! -s $LOG/rsync ]] || fail 'Started rsync after a rejected input.'
}
reject_local() {
  reject "$@"
  [[ ! -s $LOG/ssh ]] || fail 'Started SSH after a rejected local input.'
}
check_transfer() {
  local source=$1 host=$2 relative=$3
  run "$source" "$host"
  local -a args ssh_args
  mapfile -d '' -t args < "$LOG/rsync"
  mapfile -d '' -t ssh_args < "$LOG/ssh"
  [[ ${ssh_args[1]} == "$host" ]] || fail 'Changed the SSH host.'
  local -a expected=(--archive --block-size=131072 --delete --human-readable
    --info=progress2 --no-compress --inplace --partial --stats --secluded-args --rsh=ssh)
  [[ ${#args[@]} == 15 ]] || fail 'Unexpected rsync argument count.'
  local i
  for i in "${!expected[@]}"; do
    [[ ${args[i]} == "${expected[i]}" ]] || fail "Incorrect mirror flag: ${args[i]}"
  done
  [[ ${args[11]} == --rsync-path=* && ${args[12]} == -- ]] || fail 'Missing argument protection.'
  [[ ${args[13]} == "$HOME/$relative/" ]] || fail 'Incorrect source path.'
  [[ ${args[14]} == "$host:./$relative/" ]] || fail 'Incorrect deletion destination.'
  [[ -d $REMOTE_HOME/$relative ]] || fail 'Remote parents were not created.'
  [[ $(cat "$LOG/remote-cwd") == "$REMOTE_HOME" ]] || fail 'Remote rsync did not start in HOME.'
}

mkdir -p "$HOME/Test/fiddle" "$HOME/space parent/child" "$fixture/outside"
ln -s "$fixture/outside" "$HOME/Test/fiddle/internal-link"
printf 'untouched\n' > "$HOME/Test/fiddle/a quoted ' file"
reject_local
reject_local "$HOME/Test/fiddle"
reject_local "$HOME/Test/fiddle" wibble extra
reject_local '' wibble
reject_local "$HOME" wibble
reject_local "$HOME/" wibble
reject_local / wibble
reject_local "$fixture/outside" wibble
reject_local "$HOME/missing" wibble
mkdir "$HOME/unreadable"
chmod 000 "$HOME/unreadable"
if [[ ! -r $HOME/unreadable ]]; then reject_local "$HOME/unreadable" wibble; fi
chmod 700 "$HOME/unreadable"
reject_local "$HOME/Test/fiddle/a quoted ' file" wibble
reject_local "$HOME/Test/.." wibble
reject_local "$HOME/../local/Test" wibble
ln -s "$HOME/Test" "$HOME/link"
ln -s "$fixture/outside" "$HOME/escape"
reject_local "$HOME/link/fiddle" wibble
reject_local "$HOME/link/../Test" wibble
reject_local "$HOME/escape" wibble
for host in -option 'host;id' 'user@-host' 'ssh://host' 'host:path' 'host/name' 'a b' 'a@b@c' "\$(id)" ''; do
  reject_local "$HOME/Test" "$host"
done
check_transfer "$HOME/Test/fiddle///" wibble Test/fiddle
check_transfer "$HOME/Test/./fiddle" someone@ssh-alias Test/fiddle
check_transfer "$HOME/space parent/child" host.example 'space parent/child'
(cd "$HOME"; check_transfer Test/fiddle 127.0.0.1 Test/fiddle)
[[ -L $HOME/Test/fiddle/internal-link ]] || fail 'Changed an internal source symlink.'
[[ $(cat "$HOME/Test/fiddle/a quoted ' file") == untouched ]] || fail 'Changed a source file.'

odd=$'a space\'"$`\\;()[]*?\nlast\n'
mkdir -p "$HOME/$odd/nested"
check_transfer "$HOME/$odd/nested" wibble "$odd/nested"
if [[ -n ${TEST_FISH:-} ]]; then
  printf '#!%s\n' "$BASH" > "$fixture/bin/fish-login"
  cat >> "$fixture/bin/fish-login" <<'SH'
exec "$TEST_FISH" --no-config "$@"
SH
  chmod +x "$fixture/bin/fish-login"
  LOGIN_SHELL=$fixture/bin/fish-login check_transfer "$HOME/$odd/nested" fish-alias "$odd/nested"
else
  fail 'TEST_FISH must name fish for the remote quoting test.'
fi

mkdir -p "$HOME/bad-parent/child" "$HOME/bad-leaf" "$HOME/remote-file"
ln -s "$fixture/outside" "$REMOTE_HOME/bad-parent"
ln -s "$REMOTE_HOME" "$REMOTE_HOME/bad-leaf"
printf 'file\n' > "$REMOTE_HOME/remote-file"
reject "$HOME/bad-parent/child" wibble
reject "$HOME/bad-leaf" wibble
reject "$HOME/remote-file" wibble
REMOTE_HOME=/ reject "$HOME/Test/fiddle" wibble
REMOTE_HOME=relative reject "$HOME/Test/fiddle" wibble
SSH_FAIL=1 reject "$HOME/Test/fiddle" wibble
mkdir -p "$HOME/mkdir-fails/child"
MKDIR_FAIL=1 reject "$HOME/mkdir-fails/child" wibble

# Exercise the helper boundary independently of the local path checks.
check_transfer "$HOME/Test/fiddle" wibble Test/fiddle
mapfile -d '' -t ssh_args < "$LOG/ssh"
helper_prefix=${ssh_args[2]%sh \"Test/fiddle\"}
for bad in '' / . .. '../outside' 'Test/../..' 'Test//fiddle' 'Test/'; do
  if HOME=$REMOTE_HOME sh -c "${helper_prefix}sh '$bad'" > "$LOG/output" 2>&1; then
    fail "Remote helper accepted unsafe destination: $bad"
  fi
done

# A symlink at the home boundary is supported, but not below that boundary.
ln -s "$HOME" "$fixture/home-alias"
HOME=$fixture/home-alias run "$fixture/home-alias/Test/fiddle" wibble
ln -s "$REMOTE_HOME" "$fixture/remote-alias"
REMOTE_HOME=$fixture/remote-alias run "$HOME/Test/fiddle" wibble
printf 'PASS: rsync-send behavioural checks (POSIX and fish, no real transfer).\n'
